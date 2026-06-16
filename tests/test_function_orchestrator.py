import importlib.util
import json
import shutil
from pathlib import Path

import azure.functions as func
from azure.ai.ml import load_job
import yaml


ROOT = Path(__file__).resolve().parents[1]
FUNCTION_APP_PATH = ROOT / "mlops" / "functions" / "function_app.py"
PIPELINE_JOB_FILE = ROOT / "mlops" / "azureml" / "pricing-mlops-pipeline.yml"
PIPELINE_ENVIRONMENT = "azureml:pricing-auth-monitoring-env:1"
FUNCTIONAL_COMPONENT_VERSION = "0.1.1"
FUNCTIONAL_COMPONENTS = {
    "validate_prepare": "pricing_mlops_validate_prepare",
    "build_monitoring_inputs": "pricing_mlops_build_monitoring_inputs",
    "calculate_recommendation_validity": "pricing_mlops_calculate_recommendation_validity",
    "calculate_auth_history_drift": "pricing_mlops_calculate_auth_history_drift",
    "calculate_operational_decision": "pricing_mlops_calculate_operational_decision",
}


def _load_function_app():
    spec = importlib.util.spec_from_file_location("platform_function_app", FUNCTION_APP_PATH)
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


def test_pipeline_template_uses_packaged_model_source():
    job_definition = yaml.safe_load(PIPELINE_JOB_FILE.read_text(encoding="utf-8"))

    assert job_definition["type"] == "pipeline"
    assert job_definition["inputs"]["monitoring_config_version"] == "2026-05-07"
    assert job_definition["inputs"]["monitoring_config_path"] == "configs/drift_thresholds.json"
    assert set(job_definition["jobs"].keys()) == {
        "validate_prepare",
        "build_monitoring_inputs",
        "calculate_recommendation_validity",
        "calculate_auth_history_drift",
        "calculate_operational_decision",
        "publish_outputs",
    }
    for job_name, component_name in FUNCTIONAL_COMPONENTS.items():
        assert job_definition["jobs"][job_name]["component"] == (
            f"azureml:{component_name}:{FUNCTIONAL_COMPONENT_VERSION}"
        )
        assert job_definition["jobs"][job_name]["compute"] == "azureml:serverless"
    assert job_definition["jobs"]["publish_outputs"]["component"]["code"] == "../platform-components"
    assert job_definition["jobs"]["publish_outputs"]["compute"] == "azureml:serverless"
    assert "job_identity_client_id" in job_definition["inputs"]
    assert "python platform_publish_outputs.py" in (
        job_definition["jobs"]["publish_outputs"]["component"]["command"]
    )
    for job_name in FUNCTIONAL_COMPONENTS:
        job = job_definition["jobs"][job_name]
        assert "command" not in job
        assert "code" not in job
    publish_job = job_definition["jobs"]["publish_outputs"]
    command = publish_job["component"]["command"]
    assert "pip install" not in command
    assert publish_job["component"]["environment"] == PIPELINE_ENVIRONMENT
    assert "MLOPS_USE_MANAGED_IDENTITY_CREDENTIAL=true" in command
    assert "AZURE_ML_JOB_IDENTITY_CLIENT_ID=${{inputs.job_identity_client_id}}" in command
    assert "job_identity_client_id" in publish_job["component"]["inputs"]
    assert publish_job["inputs"]["job_identity_client_id"] == "${{parent.inputs.job_identity_client_id}}"
    for job in job_definition["jobs"].values():
        assert "pip install" not in command
        assert job["inputs"]["job_identity_client_id"] == "${{parent.inputs.job_identity_client_id}}"
    expected_flow = {
        "build_monitoring_inputs": "${{parent.jobs.validate_prepare.outputs.flow_token}}",
        "calculate_recommendation_validity": "${{parent.jobs.build_monitoring_inputs.outputs.flow_token}}",
        "calculate_auth_history_drift": (
            "${{parent.jobs.calculate_recommendation_validity.outputs.flow_token}}"
        ),
        "calculate_operational_decision": "${{parent.jobs.calculate_auth_history_drift.outputs.flow_token}}",
        "publish_outputs": "${{parent.jobs.calculate_operational_decision.outputs.flow_token}}",
    }
    for job_name, token_path in expected_flow.items():
        assert job_definition["jobs"][job_name]["inputs"]["previous_step_token"] == {
            "type": "uri_folder",
            "path": token_path,
        }

    for job in job_definition["jobs"].values():
        assert "depends_on" not in job
        assert job["identity"] == {"type": "user_identity"}

    assert "flow_token" in job_definition["jobs"]["validate_prepare"]["outputs"]
    assert "component-state/${{inputs.run_id}}/operational_decision" in (
        job_definition["jobs"]["publish_outputs"]["component"]["command"]
    )
    publish_command = job_definition["jobs"]["publish_outputs"]["component"]["command"]
    assert "--monitoring-config-version ${{inputs.monitoring_config_version}}" in publish_command
    assert "--monitoring-config-path configs/drift_thresholds.json" in publish_command
    assert (
        job_definition["jobs"]["publish_outputs"]["inputs"]["monitoring_config_version"]
        == "${{parent.inputs.monitoring_config_version}}"
    )


def test_function_app_discovers_platform_job_template():
    function_app = _load_function_app()

    assert function_app.PIPELINE_JOB_FILE == PIPELINE_JOB_FILE
    assert function_app.JOB_FILE == PIPELINE_JOB_FILE


def test_orchestration_request_builds_expected_prefix(monkeypatch):
    function_app = _load_function_app()
    _set_required_env(monkeypatch)

    request = function_app._orchestration_request(
        {
            "environment": "staging",
            "run_owner": "team46",
            "input_blob_path": "samples/sample_pricing_v1.csv",
            "mlops_run_id": "20260517T000000Z-function",
        }
    )

    assert request["compute_target"] == "azure-ml"
    assert request["trigger_type"] == "manual"
    assert request["baseline_snapshot_container"] == "artifacts"
    assert request["baseline_snapshot_blob_path"] == ""
    assert request["current_history_container"] == "raw-masked"
    assert request["current_history_blob_path"] == "samples/sample_pricing_v1.csv"
    assert request["run_id"] == "20260517T000000Z-function"
    assert request["expected_output_prefix"] == (
        "environment=staging/compute=azure-ml/trigger=manual/owner=team46/"
        "run_date=20260517/run_id=20260517T000000Z-function"
    )


def test_model_flow_submits_aml_job(monkeypatch):
    function_app = _load_function_app()
    _set_required_env(monkeypatch)
    submitted = {}

    def fake_submit(request):
        submitted.update(request)
        return {
            "accepted": True,
            "azure_ml_job_name": "test_job",
            "run_id": request["run_id"],
            "expected_output_prefix": request["expected_output_prefix"],
        }

    monkeypatch.setattr(function_app, "submit_azure_ml_job", fake_submit)
    request = func.HttpRequest(
        method="POST",
        url="/api/model-flow",
        body=json.dumps(
            {
                "environment": "staging",
                "run_owner": "team46",
                "input_blob_path": "samples/sample_pricing_v1.csv",
                "baseline_snapshot_blob_path": "baseline/baseline_recommendation_snapshot.csv",
                "mlops_run_id": "20260517T000000Z-function",
            }
        ).encode(),
        headers={"content-type": "application/json"},
    )

    response = function_app.model_flow(request)
    body = json.loads(response.get_body())

    assert response.status_code == 202
    assert body["accepted"] is True
    assert body["azure_ml_job_name"] == "test_job"
    assert body["correlation_id"]
    assert submitted["run_id"] == "20260517T000000Z-function"
    assert submitted["baseline_snapshot_blob_path"] == "baseline/baseline_recommendation_snapshot.csv"
    assert submitted["current_history_blob_path"] == "samples/sample_pricing_v1.csv"


def test_model_flow_hides_submit_exception_by_default(monkeypatch):
    function_app = _load_function_app()
    _set_required_env(monkeypatch)

    def fake_submit(_request):
        raise RuntimeError("specific failure")

    monkeypatch.setattr(function_app, "submit_azure_ml_job", fake_submit)
    request = func.HttpRequest(
        method="POST",
        url="/api/model-flow",
        body=json.dumps({"environment": "staging", "run_owner": "team46"}).encode(),
        headers={"content-type": "application/json"},
    )

    response = function_app.model_flow(request)
    body = json.loads(response.get_body())

    assert response.status_code == 500
    assert body["error"] == "failed to submit Azure ML job"
    assert "exception" not in body


def test_model_flow_includes_submit_exception_when_debug_enabled(monkeypatch):
    function_app = _load_function_app()
    _set_required_env(monkeypatch)
    monkeypatch.setenv("MLOPS_DEBUG_ERRORS", "true")

    def fake_submit(_request):
        raise RuntimeError("specific failure")

    monkeypatch.setattr(function_app, "submit_azure_ml_job", fake_submit)
    request = func.HttpRequest(
        method="POST",
        url="/api/model-flow",
        body=json.dumps({"environment": "staging", "run_owner": "team46"}).encode(),
        headers={"content-type": "application/json"},
    )

    response = function_app.model_flow(request)
    body = json.loads(response.get_body())

    assert response.status_code == 500
    assert body["exception"] == "RuntimeError: specific failure"


def test_event_grid_request_accepts_incoming_csv(monkeypatch):
    function_app = _load_function_app()
    _set_required_env(monkeypatch)

    request = function_app._event_orchestration_request(
        {
            "url": (
                "https://<mlops-storage-account>.blob.core.windows.net/"
                "raw-masked/incoming/pricing.csv"
            )
        }
    )

    assert request["environment"] == "staging"
    assert request["run_owner"] == "team46"
    assert request["trigger_type"] == "event-grid"
    assert request["input_container"] == "raw-masked"
    assert request["input_blob_path"] == "incoming/pricing.csv"
    assert "/trigger=event-grid/" in request["expected_output_prefix"]


def test_event_grid_request_rejects_samples(monkeypatch):
    function_app = _load_function_app()
    _set_required_env(monkeypatch)

    try:
        function_app._event_orchestration_request(
            {
                "url": (
                    "https://<mlops-storage-account>.blob.core.windows.net/"
                    "raw-masked/samples/sample_pricing_v1.csv"
                )
            }
        )
    except ValueError as exc:
        assert "incoming/" in str(exc)
    else:
        raise AssertionError("Event Grid samples path should be rejected")


def test_event_grid_request_rejects_raw_unmasked(monkeypatch):
    function_app = _load_function_app()
    _set_required_env(monkeypatch)

    try:
        function_app._event_orchestration_request(
            {
                "url": (
                    "https://<mlops-storage-account>.blob.core.windows.net/"
                    "raw-unmasked/incoming/pricing.csv"
                )
            }
        )
    except ValueError as exc:
        assert "raw-unmasked" in str(exc)
    else:
        raise AssertionError("raw-unmasked should be rejected")


def test_apply_job_inputs_updates_loaded_pipeline_defaults(tmp_path):
    function_app = _load_function_app()
    job = load_job(source=_copy_pipeline_package(tmp_path))

    function_app._apply_job_inputs(
        job,
        {
            "run_id": "run-from-function",
            "trigger_type": "event-grid",
            "model_commit_sha": "abc123",
            "monitoring_config_version": "2026-05-07",
            "job_identity_client_id": "managed-client-id",
        },
    )

    assert job._to_dict()["inputs"]["run_id"] == "run-from-function"
    assert job._to_dict()["inputs"]["trigger_type"] == "event-grid"
    assert job._to_dict()["inputs"]["model_commit_sha"] == "abc123"
    assert job._to_dict()["inputs"]["monitoring_config_version"] == "2026-05-07"
    assert job._to_dict()["inputs"]["job_identity_client_id"] == "managed-client-id"
    assert set(job._to_dict()["jobs"].keys()) == {
        "validate_prepare",
        "build_monitoring_inputs",
        "calculate_recommendation_validity",
        "calculate_auth_history_drift",
        "calculate_operational_decision",
        "publish_outputs",
    }


def test_apply_job_identity_sets_managed_identity_on_pipeline_nodes(tmp_path, monkeypatch):
    function_app = _load_function_app()
    job = load_job(source=_copy_pipeline_package(tmp_path))
    monkeypatch.setenv("AZURE_ML_JOB_IDENTITY_CLIENT_ID", "managed-client-id")
    monkeypatch.setenv("MLOPS_USE_MANAGED_JOB_IDENTITY", "true")

    function_app._apply_job_identity(job)

    for node in job._to_dict()["jobs"].values():
        assert node["identity"] == {
            "type": "managed_identity",
            "client_id": "managed-client-id",
        }


def test_apply_job_identity_removes_user_identity_by_default(tmp_path, monkeypatch):
    function_app = _load_function_app()
    job = load_job(source=_copy_pipeline_package(tmp_path))
    monkeypatch.setenv("AZURE_ML_JOB_IDENTITY_CLIENT_ID", "managed-client-id")
    monkeypatch.delenv("MLOPS_USE_MANAGED_JOB_IDENTITY", raising=False)

    function_app._apply_job_identity(job)

    for node in job._to_dict()["jobs"].values():
        assert "identity" not in node


def _copy_pipeline_package(tmp_path):
    package_root = tmp_path / "package"
    azureml_dir = package_root / "azureml"
    source_dir = package_root / "pricing-mlops-source"
    platform_dir = package_root / "platform-components"
    azureml_dir.mkdir(parents=True)
    source_dir.mkdir()
    platform_dir.mkdir()
    shutil.copy(PIPELINE_JOB_FILE, azureml_dir / "pricing-mlops-pipeline.yml")
    shutil.copy(ROOT / "mlops" / "azureml" / "environment.yml", azureml_dir / "environment.yml")
    shutil.copy(
        ROOT / "mlops" / "components" / "platform_publish_outputs.py",
        platform_dir / "platform_publish_outputs.py",
    )
    return azureml_dir / "pricing-mlops-pipeline.yml"


def _set_required_env(monkeypatch):
    monkeypatch.setenv("AZURE_SUBSCRIPTION_ID", "<test-subscription-id>")
    monkeypatch.setenv("AZURE_RESOURCE_GROUP", "rg-pricing-mlops-staging")
    monkeypatch.setenv("AZURE_ML_WORKSPACE", "mlw-pricing-mlops-stg-v2-<suffix>")
    monkeypatch.setenv("AZURE_STORAGE_ACCOUNT", "<mlops-storage-account>")
