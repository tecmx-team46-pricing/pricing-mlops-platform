#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
import subprocess
import uuid
from datetime import datetime, timezone
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def utc_now() -> datetime:
    return datetime.now(timezone.utc)


def git_commit() -> str:
    try:
        return subprocess.check_output(
            ["git", "rev-parse", "HEAD"],
            cwd=ROOT,
            text=True,
            stderr=subprocess.DEVNULL,
        ).strip()
    except Exception:
        return "unknown"


def load_json(path: Path) -> dict:
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def classify(value: float, green_max: float, yellow_max: float) -> str:
    if value <= green_max:
        return "green"
    if value <= yellow_max:
        return "yellow"
    return "red"


def action_for(status: str, actions: dict[str, str]) -> str:
    return actions[status]


def write_json(path: Path, payload: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as handle:
        json.dump(payload, handle, indent=2, sort_keys=True)
        handle.write("\n")


def write_jsonl(path: Path, records: list[dict]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as handle:
        for record in records:
            handle.write(json.dumps(record, sort_keys=True))
            handle.write("\n")


def build_sample_outputs(run_id: str) -> list[dict]:
    return [
        {
            "run_id": run_id,
            "record_id": "sample-001",
            "business_group": "BG-A",
            "vp_area": "North",
            "disty_segment": "Strategic",
            "part_number": "PART-001",
            "recommended_target_price": 128.5,
            "recommended_floor_price": 118.0,
            "recommended_start_price": 135.0,
            "pricing_strategy": "protect_margin",
            "revenue": 25000.0,
        },
        {
            "run_id": run_id,
            "record_id": "sample-002",
            "business_group": "BG-B",
            "vp_area": "West",
            "disty_segment": "Long Tail",
            "part_number": "PART-002",
            "recommended_target_price": 42.8,
            "recommended_floor_price": 39.5,
            "recommended_start_price": 45.0,
            "pricing_strategy": "market_follow",
            "revenue": 8700.0,
        },
    ]


def build_sample_drift(run_id: str, thresholds_config: dict) -> list[dict]:
    metric_values = {
        "price_relative_change": ("historical_price", "price", 0.04),
        "quantity_relative_change": ("quantity", "quantity", 0.18),
        "recommended_price_relative_change": ("recommended_target_price", "output", 0.06),
        "revenue_weighted_impact": ("portfolio", "output", 0.035),
    }
    actions = thresholds_config["actions"]
    records = []

    for metric_name, (variable_name, variable_type, drift_value) in metric_values.items():
        thresholds = thresholds_config["metrics"][metric_name]
        status = classify(drift_value, thresholds["green_max"], thresholds["yellow_max"])
        records.append(
            {
                "drift_id": f"{run_id}-{metric_name}",
                "run_id": run_id,
                "baseline_version": "baseline-demo-2026-05",
                "variable_name": variable_name,
                "variable_type": variable_type,
                "drift_metric": metric_name,
                "drift_value": drift_value,
                "threshold_green": thresholds["green_max"],
                "threshold_yellow": thresholds["yellow_max"],
                "threshold_red": thresholds["yellow_max"],
                "drift_status": status,
                "revenue_weighted_impact": drift_value if metric_name == "revenue_weighted_impact" else 0.0,
                "recommended_action": action_for(status, actions),
            }
        )

    return records


def worst_status(records: list[dict]) -> str:
    priority = {"green": 0, "yellow": 1, "red": 2}
    return max((record["drift_status"] for record in records), key=lambda status: priority[status])


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate an MVP MLOps staging run package.")
    parser.add_argument("--environment", default="staging", choices=["staging", "validation"])
    parser.add_argument("--output-dir", default=str(ROOT / "outputs" / "runs"))
    parser.add_argument("--executed-by", default=os.getenv("GITHUB_ACTOR", os.getenv("USER", "local")))
    parser.add_argument("--git-commit", default=os.getenv("GITHUB_SHA", git_commit()))
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    now = utc_now()
    run_id = f"run-{now.strftime('%Y%m%d%H%M%S')}-{uuid.uuid4().hex[:8]}"
    run_dir = Path(args.output_dir) / run_id
    thresholds = load_json(ROOT / "mlops" / "configs" / "drift_thresholds.json")
    outputs = build_sample_outputs(run_id)
    drift_records = build_sample_drift(run_id, thresholds)
    final_status = worst_status(drift_records)

    run_log = {
        "run_id": run_id,
        "run_timestamp": now.isoformat().replace("+00:00", "Z"),
        "git_commit_hash": args.git_commit,
        "code_version": "mvp-demo",
        "config_version": thresholds["version"],
        "dataset_version": "sample-masked-dataset",
        "logic_version": "pricing-flow-v0",
        "output_version": f"snapshot-{run_id}",
        "environment": args.environment,
        "status": "succeeded",
        "executed_by": args.executed_by,
        "storage_uri": "",
        "comments": f"Demo run generated with overall drift status {final_status}.",
    }

    write_json(run_dir / "model_run_log.json", run_log)
    write_jsonl(run_dir / "model_output_snapshot.jsonl", outputs)
    write_jsonl(run_dir / "model_drift_log.jsonl", drift_records)

    summary = "\n".join(
        [
            f"# MLOps Run {run_id}",
            "",
            f"- Environment: `{args.environment}`",
            f"- Status: `{run_log['status']}`",
            f"- Drift status: `{final_status}`",
            f"- Recommended action: `{thresholds['actions'][final_status]}`",
            f"- Git commit: `{args.git_commit}`",
            "",
        ]
    )
    (run_dir / "summary.md").write_text(summary, encoding="utf-8")
    print(f"Generated {run_dir}")


if __name__ == "__main__":
    main()
