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


def test_function_app_discovers_platform_job_template():
    function_app = _load_function_app()

    assert function_app.JOB_FILE == JOB_FILE


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
    assert request["run_id"] == "20260517T000000Z-function"
    assert request["expected_output_prefix"] == (
        "environment=staging/compute=azure-ml/owner=team46/"
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


def test_apply_job_inputs_updates_loaded_azure_ml_defaults(tmp_path):
    function_app = _load_function_app()
    job_file = _copy_job_package(tmp_path)
    job = load_job(source=job_file)

    function_app._apply_job_inputs(job, {"run_id": "run-from-function"})

    assert job._to_dict()["inputs"]["run_id"] == "run-from-function"
    assert job.component.inputs["run_id"]["default"] == "run-from-function"


def _copy_job_package(tmp_path):
    package_root = tmp_path / "package"
    azureml_dir = package_root / "azureml"
    source_dir = package_root / "pricing-mlops-source"
    azureml_dir.mkdir(parents=True)
    source_dir.mkdir()
    shutil.copy(JOB_FILE, azureml_dir / "pricing-mlops-job.yml")
    shutil.copy(ROOT / "mlops" / "azureml" / "environment.yml", azureml_dir / "environment.yml")
    return azureml_dir / "pricing-mlops-job.yml"


def _set_required_env(monkeypatch):
    monkeypatch.setenv("AZURE_SUBSCRIPTION_ID", "<test-subscription-id>")
    monkeypatch.setenv("AZURE_RESOURCE_GROUP", "rg-pricing-mlops-staging")
    monkeypatch.setenv("AZURE_ML_WORKSPACE", "mlw-pricing-mlops-stg-v2-<suffix>")
    monkeypatch.setenv("AZURE_STORAGE_ACCOUNT", "<mlops-storage-account>")
