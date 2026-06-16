from pathlib import Path

import yaml


ROOT = Path(__file__).resolve().parents[1]
WORKFLOW_FILE = ROOT / ".github" / "workflows" / "azureml-components.yml"


def test_azureml_components_workflow_registers_components_on_main_push():
    workflow = yaml.safe_load(WORKFLOW_FILE.read_text(encoding="utf-8"))
    triggers = workflow[True]
    push = triggers["push"]
    jobs = workflow["jobs"]
    register_steps = jobs["register-components"]["steps"]
    step_text = "\n".join(str(step) for step in register_steps)

    assert push["branches"] == ["main"]
    assert "mlops/azureml/components/**" in push["paths"]
    assert ".github/workflows/azureml-components.yml" in push["paths"]
    assert workflow["permissions"] == {"contents": "read", "id-token": "write"}
    assert jobs["register-components"]["environment"] == "staging"
    assert "azure/login@v2" in step_text
    assert "repository': 'tecmx-team46-pricing/pricing-mlops'" in step_text
    assert "path': 'mlops/azureml/pricing-mlops-source'" in step_text
    assert "mlops/scripts/register_azureml_environment.sh" in step_text
    assert "mlops/scripts/register_azureml_components.sh" in step_text
