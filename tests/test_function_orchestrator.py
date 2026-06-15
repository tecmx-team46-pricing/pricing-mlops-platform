import importlib.util
import json
import shutil
from pathlib import Path

import azure.functions as func
from azure.ai.ml import load_job
import yaml


ROOT = Path(__file__).resolve().parents[1]
FUNCTION_APP_PATH = ROOT / "mlops" / "functions" / "function_app.py"
JOB_FILE = ROOT / "mlops" / "azureml" / "pricing-mlops-job.yml"
PIPELINE_JOB_FILE = ROOT / "mlops" / "azureml" / "pricing-mlops-pipeline.yml"
NOTEBOOK_PIPELINE_JOB_FILE = ROOT / "mlops" / "azureml" / "pricing-mlops-notebook-pipeline.yml"


def _load_function_app():
    spec = importlib.util.spec_from_file_location("platform_function_app", FUNCTION_APP_PATH)
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


def test_job_template_uses_packaged_model_source():
    job_definition = yaml.safe_load(JOB_FILE.read_text(encoding="utf-8"))

    assert job_definition["code"] == "../pricing-mlops-source"
    assert "python -m pip install -e ." in job_definition["command"]
    assert "python scripts/run_azure_ml_flow.py" in job_definition["command"]


def test_pipeline_template_uses_packaged_model_source():
    job_definition = yaml.safe_load(PIPELINE_JOB_FILE.read_text(encoding="utf-8"))

    assert job_definition["type"] == "pipeline"
    assert set(job_definition["jobs"].keys()) == {
        "validate_prepare",
        "score_evaluate",
        "publish_outputs",
    }
    for job_name in ("validate_prepare", "score_evaluate"):
        assert job_definition["jobs"][job_name]["component"]["code"] == "../pricing-mlops-source"
        assert job_definition["jobs"][job_name]["compute"] == "azureml:serverless"
    assert job_definition["jobs"]["publish_outputs"]["component"]["code"] == "../platform-components"
    assert job_definition["jobs"]["publish_outputs"]["compute"] == "azureml:serverless"
    assert "scripts/components/validate_prepare.py" in (
        job_definition["jobs"]["validate_prepare"]["component"]["command"]
    )
    assert "--trigger-type ${{inputs.trigger_type}}" in (
        job_definition["jobs"]["score_evaluate"]["component"]["command"]
    )
    assert "--model-commit-sha ${{inputs.model_commit_sha}}" in (
        job_definition["jobs"]["score_evaluate"]["component"]["command"]
    )
    assert "python platform_publish_outputs.py" in (
        job_definition["jobs"]["publish_outputs"]["component"]["command"]
    )
    assert job_definition["jobs"]["score_evaluate"]["depends_on"] == ["validate_prepare"]
    assert job_definition["jobs"]["publish_outputs"]["depends_on"] == ["score_evaluate"]
    assert "component-state/${{inputs.run_id}}/prepared" in (
        job_definition["jobs"]["score_evaluate"]["component"]["command"]
    )
    assert "component-state/${{inputs.run_id}}/run_artifacts" in (
        job_definition["jobs"]["publish_outputs"]["component"]["command"]
    )


def test_notebook_pipeline_template_uses_packaged_operational_notebook_source():
    job_definition = yaml.safe_load(NOTEBOOK_PIPELINE_JOB_FILE.read_text(encoding="utf-8"))

    assert job_definition["type"] == "pipeline"
    assert set(job_definition["jobs"].keys()) == {
        "validate_prepare",
        "run_notebook_monitor",
        "publish_outputs",
    }
    for job_name in ("validate_prepare", "run_notebook_monitor"):
        assert job_definition["jobs"][job_name]["component"]["code"] == "../pricing-mlops-source"
        assert job_definition["jobs"][job_name]["compute"] == "azureml:serverless"
    assert job_definition["jobs"]["publish_outputs"]["component"]["code"] == "../platform-components"
    assert job_definition["jobs"]["publish_outputs"]["compute"] == "azureml:serverless"
    notebook_command = job_definition["jobs"]["run_notebook_monitor"]["component"]["command"]
    assert "python scripts/components/run_notebook_monitor.py" in notebook_command
    assert "notebooks/operational/${{inputs.notebook_name}}" in notebook_command
    assert "--baseline-snapshot-container ${{inputs.baseline_snapshot_container}}" in notebook_command
    assert "--baseline-snapshot-blob-path ${{inputs.baseline_snapshot_blob_path}}" in notebook_command
    assert "--current-history-container ${{inputs.current_history_container}}" in notebook_command
    assert "--current-history-blob-path ${{inputs.current_history_blob_path}}" in notebook_command
    assert "--run-artifacts-prefix component-state/${{inputs.run_id}}/notebook_artifacts" in notebook_command
    assert job_definition["jobs"]["run_notebook_monitor"]["depends_on"] == ["validate_prepare"]
    assert job_definition["jobs"]["publish_outputs"]["depends_on"] == ["run_notebook_monitor"]
    assert "python platform_publish_outputs.py" in (
        job_definition["jobs"]["publish_outputs"]["component"]["command"]
    )


def test_function_app_discovers_platform_job_template():
    function_app = _load_function_app()

    assert function_app.COMMAND_JOB_FILE == JOB_FILE
    assert function_app.PIPELINE_JOB_FILE == PIPELINE_JOB_FILE
    assert function_app.NOTEBOOK_PIPELINE_JOB_FILE == NOTEBOOK_PIPELINE_JOB_FILE
    assert function_app.JOB_FILE == PIPELINE_JOB_FILE


def test_function_app_can_select_notebook_pipeline_template(monkeypatch):
    monkeypatch.setenv("MLOPS_JOB_TEMPLATE", "notebook")
    function_app = _load_function_app()

    assert function_app.JOB_FILE == NOTEBOOK_PIPELINE_JOB_FILE


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
                "baseline_snapshot_blob_path": "runs/baseline/model_output_snapshot.csv",
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
    assert submitted["baseline_snapshot_blob_path"] == "runs/baseline/model_output_snapshot.csv"
    assert submitted["current_history_blob_path"] == "samples/sample_pricing_v1.csv"


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


def test_apply_job_inputs_updates_loaded_azure_ml_defaults(tmp_path):
    function_app = _load_function_app()
    job_file = _copy_job_package(tmp_path)
    job = load_job(source=job_file)

    function_app._apply_job_inputs(job, {"run_id": "run-from-function"})

    assert job._to_dict()["inputs"]["run_id"] == "run-from-function"
    assert job.component.inputs["run_id"]["default"] == "run-from-function"


def test_apply_job_inputs_updates_loaded_pipeline_defaults(tmp_path):
    function_app = _load_function_app()
    job = load_job(source=_copy_pipeline_package(tmp_path))

    function_app._apply_job_inputs(
        job,
        {
            "run_id": "run-from-function",
            "trigger_type": "event-grid",
            "model_commit_sha": "abc123",
        },
    )

    assert job._to_dict()["inputs"]["run_id"] == "run-from-function"
    assert job._to_dict()["inputs"]["trigger_type"] == "event-grid"
    assert job._to_dict()["inputs"]["model_commit_sha"] == "abc123"
    assert set(job._to_dict()["jobs"].keys()) == {
        "validate_prepare",
        "score_evaluate",
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


def test_apply_job_identity_sets_managed_identity_on_command_job(tmp_path, monkeypatch):
    function_app = _load_function_app()
    job_file = _copy_job_package(tmp_path)
    job = load_job(source=job_file)
    monkeypatch.setenv("AZURE_ML_JOB_IDENTITY_CLIENT_ID", "managed-client-id")
    monkeypatch.setenv("MLOPS_USE_MANAGED_JOB_IDENTITY", "true")

    function_app._apply_job_identity(job)

    assert job._to_dict()["identity"] == {
        "type": "managed_identity",
        "client_id": "managed-client-id",
    }


def test_apply_job_identity_keeps_user_identity_by_default(tmp_path, monkeypatch):
    function_app = _load_function_app()
    job = load_job(source=_copy_pipeline_package(tmp_path))
    monkeypatch.setenv("AZURE_ML_JOB_IDENTITY_CLIENT_ID", "managed-client-id")
    monkeypatch.delenv("MLOPS_USE_MANAGED_JOB_IDENTITY", raising=False)

    function_app._apply_job_identity(job)

    for node in job._to_dict()["jobs"].values():
        assert node["identity"] == {"type": "user_identity"}


def _copy_job_package(tmp_path):
    package_root = tmp_path / "package"
    azureml_dir = package_root / "azureml"
    source_dir = package_root / "pricing-mlops-source"
    azureml_dir.mkdir(parents=True)
    source_dir.mkdir()
    shutil.copy(JOB_FILE, azureml_dir / "pricing-mlops-job.yml")
    shutil.copy(ROOT / "mlops" / "azureml" / "environment.yml", azureml_dir / "environment.yml")
    return azureml_dir / "pricing-mlops-job.yml"


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
