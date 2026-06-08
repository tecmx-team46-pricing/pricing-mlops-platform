#!/usr/bin/env python3
from __future__ import annotations

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]

SCHEMAS = {
    "model_run_log.schema.json": {
        "run_id",
        "run_timestamp",
        "git_commit_hash",
        "code_version",
        "config_version",
        "dataset_version",
        "logic_version",
        "output_version",
        "environment",
        "status",
        "executed_by",
    },
    "model_drift_log.schema.json": {
        "drift_id",
        "run_id",
        "baseline_version",
        "variable_name",
        "variable_type",
        "drift_metric",
        "drift_value",
        "threshold_green",
        "threshold_yellow",
        "threshold_red",
        "drift_status",
        "revenue_weighted_impact",
        "recommended_action",
    },
    "model_output_snapshot.schema.json": {
        "run_id",
        "record_id",
        "business_group",
        "vp_area",
        "disty_segment",
        "part_number",
        "recommended_target_price",
        "recommended_floor_price",
        "recommended_start_price",
        "pricing_strategy",
    },
}


def load_json(path: Path) -> dict:
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def validate_schema(name: str, expected_required: set[str]) -> None:
    path = ROOT / "mlops" / "schemas" / name
    schema = load_json(path)
    required = set(schema.get("required", []))
    properties = set(schema.get("properties", {}).keys())

    missing_required = expected_required - required
    missing_properties = expected_required - properties

    if missing_required:
        raise SystemExit(f"{name} missing required fields: {sorted(missing_required)}")
    if missing_properties:
        raise SystemExit(f"{name} missing properties: {sorted(missing_properties)}")


def validate_thresholds() -> None:
    config = load_json(ROOT / "mlops" / "configs" / "drift_thresholds.json")
    metrics = config.get("metrics", {})
    actions = config.get("actions", {})

    for metric_name, thresholds in metrics.items():
        green_max = thresholds.get("green_max")
        yellow_max = thresholds.get("yellow_max")
        if not isinstance(green_max, (int, float)):
            raise SystemExit(f"{metric_name}.green_max must be numeric")
        if not isinstance(yellow_max, (int, float)):
            raise SystemExit(f"{metric_name}.yellow_max must be numeric")
        if green_max >= yellow_max:
            raise SystemExit(f"{metric_name}: green_max must be lower than yellow_max")

    expected_actions = {
        "green": "no_action",
        "yellow": "business_review",
        "red": "recalibrate_or_retrain",
    }
    if actions != expected_actions:
        raise SystemExit(f"Unexpected drift actions: {actions}")


def validate_storage_layout() -> None:
    layout = load_json(ROOT / "mlops" / "configs" / "storage_layout.json")
    containers = set(layout.get("containers", {}).keys())
    expected = {"input", "baseline", "runs", "snapshots", "drift-logs", "reports", "artifacts"}
    missing = expected - containers
    if missing:
        raise SystemExit(f"storage_layout.json missing containers: {sorted(missing)}")


def validate_azure_ml_runtime_storage_contract() -> None:
    workload_main = (ROOT / "infra" / "workloads" / "pricing-mlops" / "main.bicep").read_text(
        encoding="utf-8"
    )
    architecture_doc = (ROOT / "docs" / "architecture.md").read_text(encoding="utf-8")

    required_workload_terms = {
        "azureMlRuntimeStorageAccountName",
        "azureMlRuntimeStorage",
        "azureMlRuntimeStorageAccountName string",
    }
    missing_workload_terms = {
        term for term in required_workload_terms if term not in workload_main
    }
    if missing_workload_terms:
        raise SystemExit(
            "main.bicep missing Azure ML runtime storage contract terms: "
            f"{sorted(missing_workload_terms)}"
        )

    required_doc_terms = {
        "Storage runtime Azure ML",
        "azure-ml-runtime",
        "workspace v2",
    }
    missing_doc_terms = {term for term in required_doc_terms if term not in architecture_doc}
    if missing_doc_terms:
        raise SystemExit(
            "docs/architecture.md missing Azure ML runtime storage documentation: "
            f"{sorted(missing_doc_terms)}"
        )


def validate_sql_audit_cost_controls() -> None:
    sql_audit_module = (
        ROOT / "infra" / "workloads" / "pricing-mlops" / "modules" / "sql-audit.bicep"
    ).read_text(encoding="utf-8")

    required_terms = {
        "param minCapacity string = '0.5'",
        "@allowed([",
        "'0.5'",
        "param autoPauseDelay int = 15",
        "minCapacity: json(minCapacity)",
    }
    missing_terms = {term for term in required_terms if term not in sql_audit_module}
    if missing_terms:
        raise SystemExit(
            "sql-audit.bicep missing low-cost serverless defaults: "
            f"{sorted(missing_terms)}"
        )


def main() -> None:
    for schema_name, expected_required in SCHEMAS.items():
        validate_schema(schema_name, expected_required)

    validate_thresholds()
    validate_storage_layout()
    validate_azure_ml_runtime_storage_contract()
    validate_sql_audit_cost_controls()
    print("MLOps contracts OK")


if __name__ == "__main__":
    main()
