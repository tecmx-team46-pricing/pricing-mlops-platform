from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
PREFLIGHT_SCRIPT = ROOT / "mlops" / "scripts" / "preflight_pipeline_e2e.sh"
REGISTER_ENVIRONMENT_SCRIPT = ROOT / "mlops" / "scripts" / "register_azureml_environment.sh"


def test_pipeline_e2e_preflight_checks_resources_and_required_blobs():
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


def test_register_environment_script_registers_versioned_azureml_environment():
    script = REGISTER_ENVIRONMENT_SCRIPT.read_text(encoding="utf-8")

    assert "AZURE_SUBSCRIPTION_ID" in script
    assert "AZURE_RESOURCE_GROUP" in script
    assert "AZURE_ML_WORKSPACE" in script
    assert "mlops/azureml/environment.yml" in script
    assert "az ml environment create" in script
    assert "--file" in script
