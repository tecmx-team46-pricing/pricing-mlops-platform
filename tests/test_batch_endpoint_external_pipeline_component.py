import json
from pathlib import Path

import yaml


ROOT = Path(__file__).resolve().parents[1]
AZUREML_DIR = ROOT / "mlops" / "azureml"
MANIFEST_FILE = ROOT / "mlops" / "manifests" / "auth-monitoring-pipeline-component.json"
SCRIPTS_DIR = ROOT / "mlops" / "scripts"


def test_auth_monitoring_deployment_targets_external_pipeline_component():
    endpoint = yaml.safe_load((AZUREML_DIR / "auth-monitoring-batch-endpoint.yml").read_text())
    deployment = yaml.safe_load((AZUREML_DIR / "auth-monitoring-batch-deployment.yml").read_text())
    manifest = json.loads(MANIFEST_FILE.read_text())

    assert endpoint["name"] == "pricing-auth-monitoring"
    assert endpoint["auth_mode"] == "aad_token"
    assert deployment["endpoint_name"] == endpoint["name"]
    assert deployment["name"] == "blue"
    assert deployment["type"] == "pipeline"
    assert deployment["component"] == manifest["pipeline_component"]
    assert deployment["component"].startswith("azureml:pricing_mlops_auth_monitoring_pipeline:")
    assert deployment["settings"]["default_compute"] == "serverless"
    assert deployment["settings"]["continue_on_step_failure"] is False


def test_pipeline_component_manifest_is_owned_by_model_repo():
    manifest = json.loads(MANIFEST_FILE.read_text())

    assert manifest["owner_repo"] == "tecmx-team46-pricing/pricing-mlops"
    assert manifest["pipeline_component"].startswith("azureml:")
    assert manifest["pipeline_component"].count(":") == 2


def test_deploy_script_promotes_component_without_registering_internal_steps():
    deploy_script = (SCRIPTS_DIR / "deploy_auth_monitoring_batch_endpoint.sh").read_text()
    invoke_script = (SCRIPTS_DIR / "invoke_auth_monitoring_batch_endpoint.sh").read_text()

    assert "az ml component show" in deploy_script
    assert "az ml component create" not in deploy_script
    assert "pricing_mlops_validate_prepare" not in deploy_script
    assert "pricing_mlops_build_monitoring_inputs" not in deploy_script
    assert "pricing_mlops_calculate_recommendation_validity" not in deploy_script
    assert "pricing_mlops_calculate_auth_history_drift" not in deploy_script
    assert "pricing_mlops_calculate_operational_decision" not in deploy_script
    assert "az ml batch-endpoint create" in deploy_script
    assert "az ml batch-deployment create" in deploy_script
    assert "AZURE_ML_PIPELINE_COMPONENT" in deploy_script
    assert "auth-monitoring-pipeline-component.json" in deploy_script

    assert "az ml batch-endpoint invoke" in invoke_script
    assert "--deployment-name" in invoke_script
    assert "--experiment-name pricing-mlops-batch-endpoint" in invoke_script
    assert "--set" in invoke_script
    assert "functionapp" not in invoke_script
