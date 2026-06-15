#!/usr/bin/env python
from __future__ import annotations

import argparse
import json
from pathlib import Path
import sys
import tempfile
import time


def main() -> int:
    parser = argparse.ArgumentParser(description="Publish Pricing MLOps artifacts from platform-owned code.")
    parser.add_argument("--run-dir", default="")
    parser.add_argument("--storage-account", required=True)
    parser.add_argument("--run-artifacts-container", required=True)
    parser.add_argument("--run-artifacts-prefix", required=True)
    parser.add_argument("--environment", required=True)
    parser.add_argument("--run-owner", required=True)
    parser.add_argument("--run-id", required=True)
    parser.add_argument("--input-container", default="raw-masked")
    parser.add_argument("--input-blob-path", required=True)
    parser.add_argument("--compute-target", default="azure-ml")
    parser.add_argument("--trigger-type", default="manual")
    parser.add_argument("--model-repo", default="")
    parser.add_argument("--model-ref", default="")
    parser.add_argument("--model-commit-sha", default="")
    parser.add_argument("--curated-container", default="curated")
    parser.add_argument("--runs-container", default="runs")
    parser.add_argument("--snapshots-container", default="snapshots")
    parser.add_argument("--drift-logs-container", default="drift-logs")
    parser.add_argument("--reports-container", default="reports")
    parser.add_argument("--artifacts-container", default="artifacts")
    args = parser.parse_args()

    try:
        published = publish_outputs(
            run_dir=Path(args.run_dir) if args.run_dir else None,
            storage_account=args.storage_account,
            run_artifacts_container=args.run_artifacts_container,
            run_artifacts_prefix=args.run_artifacts_prefix,
            environment=args.environment,
            run_owner=args.run_owner,
            run_id=args.run_id,
            input_blob_path=args.input_blob_path,
            compute_target=args.compute_target,
            trigger_type=args.trigger_type,
            containers={
                "curated": args.curated_container,
                "runs": args.runs_container,
                "snapshots": args.snapshots_container,
                "drift_logs": args.drift_logs_container,
                "reports": args.reports_container,
                "artifacts": args.artifacts_container,
            },
        )
    except Exception as exc:
        print(f"platform publish_outputs failed: {exc}", file=sys.stderr)
        return 1
    print(json.dumps(published, indent=2, sort_keys=True))
    return 0


def publish_outputs(
    *,
    run_dir: Path | None,
    storage_account: str,
    run_artifacts_container: str,
    run_artifacts_prefix: str,
    environment: str,
    run_owner: str,
    run_id: str,
    input_blob_path: str,
    compute_target: str,
    trigger_type: str,
    containers: dict[str, str],
) -> dict[str, str]:
    from azure.identity import DefaultAzureCredential, ManagedIdentityCredential
    from azure.storage.blob import BlobServiceClient

    credential = (
        ManagedIdentityCredential()
        if _truthy_env("MLOPS_USE_MANAGED_IDENTITY_CREDENTIAL")
        else DefaultAzureCredential(exclude_interactive_browser_credential=True)
    )
    blob_service = BlobServiceClient(
        account_url=f"https://{storage_account}.blob.core.windows.net",
        credential=credential,
    )
    if run_dir is not None:
        return _publish_from_dir(
            blob_service=blob_service,
            run_dir=run_dir,
            environment=environment,
            run_owner=run_owner,
            run_id=run_id,
            input_blob_path=input_blob_path,
            compute_target=compute_target,
            trigger_type=trigger_type,
            containers=containers,
        )
    with tempfile.TemporaryDirectory(prefix="pricing-mlops-platform-publish-") as tmpdir:
        materialized = Path(tmpdir)
        _download_tree(
            blob_service=blob_service,
            target_dir=materialized,
            container=run_artifacts_container,
            prefix=run_artifacts_prefix.strip("/"),
        )
        return _publish_from_dir(
            blob_service=blob_service,
            run_dir=materialized,
            environment=environment,
            run_owner=run_owner,
            run_id=run_id,
            input_blob_path=input_blob_path,
            compute_target=compute_target,
            trigger_type=trigger_type,
            containers=containers,
        )


def _download_tree(blob_service, target_dir: Path, container: str, prefix: str) -> None:
    blobs = list(blob_service.get_container_client(container).list_blobs(name_starts_with=f"{prefix}/"))
    if not blobs:
        raise FileNotFoundError(f"no run artifacts found at {container}/{prefix}")
    for item in blobs:
        blob_name = item.name
        relative_path = blob_name.removeprefix(f"{prefix}/")
        if not relative_path or relative_path == blob_name:
            continue
        target = target_dir / relative_path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(_download_with_retry(blob_service.get_blob_client(container, blob_name), blob_name))


def _download_with_retry(blob, label: str, attempts: int = 6, delay_seconds: int = 10) -> bytes:
    for attempt in range(1, attempts + 1):
        try:
            return blob.download_blob().readall()
        except Exception:
            if attempt == attempts:
                raise
            print(f"waiting for run artifact: {label} attempt={attempt}")
            time.sleep(delay_seconds)
    raise RuntimeError(f"run artifact was not available: {label}")


def _publish_from_dir(
    *,
    blob_service,
    run_dir: Path,
    environment: str,
    run_owner: str,
    run_id: str,
    input_blob_path: str,
    compute_target: str,
    trigger_type: str,
    containers: dict[str, str],
) -> dict[str, str]:
    run_dir = Path(run_dir)
    if not run_dir.exists():
        raise FileNotFoundError(f"run directory not found: {run_dir}")
    _ensure_run_log(run_dir, run_id, input_blob_path)
    prefix = _partition_prefix(
        environment=environment,
        compute_target=compute_target,
        trigger_type=trigger_type,
        run_owner=run_owner,
        run_id=run_id,
    )
    published: dict[str, str] = {}
    for path in sorted(run_dir.rglob("*")):
        if not path.is_file():
            continue
        relative_path = path.relative_to(run_dir).as_posix()
        container = containers[_container_key(relative_path)]
        blob_path = f"{prefix}/{relative_path}"
        with path.open("rb") as handle:
            blob_service.get_blob_client(container=container, blob=blob_path).upload_blob(
                handle,
                overwrite=True,
            )
        published[relative_path] = f"azureblob://{container}/{blob_path}"
    return published


def _ensure_run_log(run_dir: Path, run_id: str, input_blob_path: str) -> None:
    run_log = run_dir / "model_run_log.json"
    if run_log.exists():
        return
    run_log.write_text(
        json.dumps(
            {
                "run_id": run_id,
                "status": "succeeded",
                "input_blob_path": input_blob_path,
            },
            indent=2,
            sort_keys=True,
        )
        + "\n",
        encoding="utf-8",
    )


def _partition_prefix(
    *,
    environment: str,
    compute_target: str,
    trigger_type: str,
    run_owner: str,
    run_id: str,
) -> str:
    return "/".join(
        [
            f"environment={environment}",
            f"compute={compute_target}",
            f"trigger={trigger_type}",
            f"owner={run_owner}",
            f"run_date={run_id[:8] if len(run_id) >= 8 else 'unknown'}",
            f"run_id={run_id}",
        ]
    )


def _container_key(relative_path: str) -> str:
    if relative_path == "model_run_log.json" or relative_path.startswith("summaries/"):
        return "runs"
    if relative_path.startswith("snapshots/"):
        return "snapshots"
    if relative_path.startswith("logs/"):
        return "drift_logs"
    if relative_path.startswith("reports/"):
        return "reports"
    if relative_path.startswith("curated/"):
        return "curated"
    return "artifacts"


def _truthy_env(name: str) -> bool:
    import os

    return os.getenv(name, "").strip().lower() in {"1", "true", "yes"}


if __name__ == "__main__":
    raise SystemExit(main())
