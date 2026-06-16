import importlib.util
import json
from pathlib import Path

from jsonschema import Draft202012Validator


ROOT = Path(__file__).resolve().parents[1]
PUBLISH_COMPONENT = ROOT / "mlops" / "components" / "platform_publish_outputs.py"
SCHEMAS_DIR = ROOT / "mlops" / "schemas"


def _load_publish_component():
    spec = importlib.util.spec_from_file_location("platform_publish_outputs", PUBLISH_COMPONENT)
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


def test_generated_model_run_log_matches_schema(tmp_path):
    module = _load_publish_component()
    config_path = tmp_path / "configs" / "drift_thresholds.json"
    config_path.parent.mkdir(parents=True)
    config_path.write_text('{"version":"2026-05-07"}\n', encoding="utf-8")

    module._ensure_run_log(
        tmp_path,
        run_id="20260616T000000Z-schema",
        input_blob_path="samples/auth_monitoring_sample.csv",
        environment="staging",
        run_owner="team46",
        compute_target="azure-ml",
        trigger_type="manual",
        model_repo="tecmx-team46-pricing/pricing-mlops",
        model_ref="feature/monitoring",
        model_commit_sha="abc123",
        monitoring_config_version="2026-05-07",
        monitoring_config_path=config_path,
    )

    _validate_json("model_run_log.schema.json", json.loads((tmp_path / "model_run_log.json").read_text()))


def test_auth_history_drift_row_matches_schema():
    _validate_json(
        "model_drift_log.schema.json",
        {
            "drift_run_id": "20260616T000000Z-schema",
            "monitoring_stage": "auth_history_pre_model",
            "variable_name": "P50_PRICE",
            "variable_type": "price",
            "drift_metric": "PSI",
            "drift_value": 0.03,
            "p_value": 1.0,
            "threshold_yellow": 0.1,
            "threshold_red": 0.25,
            "drift_status": "Green",
            "recommended_action": "No action required",
            "monitoring_scope": "AUTH_ONLY",
        },
    )


def _validate_json(schema_name: str, payload: dict) -> None:
    schema = json.loads((SCHEMAS_DIR / schema_name).read_text(encoding="utf-8"))
    Draft202012Validator.check_schema(schema)
    Draft202012Validator(schema).validate(payload)
