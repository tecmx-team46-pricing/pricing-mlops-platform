from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SUBMIT_SCRIPT = ROOT / "mlops" / "scripts" / "submit_notebook_pipeline_job.sh"
PREFLIGHT_SCRIPT = ROOT / "mlops" / "scripts" / "preflight_notebook_pipeline_e2e.sh"


def test_direct_notebook_submit_script_documents_required_contract():
    script = SUBMIT_SCRIPT.read_text(encoding="utf-8")

    assert "require_value AZURE_RESOURCE_GROUP" in script
    assert "rg-pricing-mlops-${ENVIRONMENT}" not in script
    assert "pricing-mlops-notebook-pipeline.yml" in script
    assert "MLOPS_JOB_TEMPLATE=notebook" in script
    assert "MLOPS_BASELINE_SNAPSHOT_BLOB_PATH" in script
    assert "MLOPS_CURRENT_AUTH_HISTORY_BLOB_PATH" in script
    assert "az ml job create" in script
    assert "validate_prepare,run_notebook_monitor,publish_outputs" in script


def test_notebook_e2e_preflight_checks_resources_and_required_blobs():
    script = PREFLIGHT_SCRIPT.read_text(encoding="utf-8")

    assert "AZURE_SUBSCRIPTION_ID" in script
    assert "require_value AZURE_RESOURCE_GROUP" in script
    assert "rg-pricing-mlops-${ENVIRONMENT}" not in script
    assert "AZURE_ML_WORKSPACE" in script
    assert "AZURE_FUNCTION_APP" in script
    assert "AZURE_STORAGE_ACCOUNT" in script
    assert "MLOPS_BASELINE_SNAPSHOT_BLOB_PATH" in script
    assert "MLOPS_CURRENT_AUTH_HISTORY_BLOB_PATH" in script
    assert "az ml workspace show" in script
    assert "az functionapp show" in script
    assert "az storage blob show" in script
