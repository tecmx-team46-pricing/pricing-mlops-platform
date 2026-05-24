from __future__ import annotations

import json
import logging
import os
import re
import uuid
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import unquote, urlparse

import azure.functions as func

app = func.FunctionApp(http_auth_level=func.AuthLevel.FUNCTION)

ALLOWED_ENVIRONMENTS = {"staging", "validation"}
SAFE_OWNER_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$")
SAFE_BLOB_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_./=-]{0,255}$")
MAX_PAYLOAD_BYTES = 4096
APP_ROOT = Path(__file__).resolve().parent
COMMAND_JOB_FILE_CANDIDATES = (
    APP_ROOT / "azureml" / "pricing-mlops-job.yml",
    APP_ROOT.parent / "azureml" / "pricing-mlops-job.yml",
)
PIPELINE_JOB_FILE_CANDIDATES = (
    APP_ROOT / "azureml" / "pricing-mlops-pipeline.yml",
    APP_ROOT.parent / "azureml" / "pricing-mlops-pipeline.yml",
)
MODEL_SOURCE_FILE_CANDIDATES = (
    APP_ROOT / "model_source.json",
    APP_ROOT.parent / "model_source.json",
)
COMMAND_JOB_FILE = next(
    (path for path in COMMAND_JOB_FILE_CANDIDATES if path.exists()),
    COMMAND_JOB_FILE_CANDIDATES[0],
)
PIPELINE_JOB_FILE = next(
    (path for path in PIPELINE_JOB_FILE_CANDIDATES if path.exists()),
    PIPELINE_JOB_FILE_CANDIDATES[0],
)
MODEL_SOURCE_FILE = next(
    (path for path in MODEL_SOURCE_FILE_CANDIDATES if path.exists()),
    MODEL_SOURCE_FILE_CANDIDATES[0],
)
JOB_FILE = PIPELINE_JOB_FILE if os.getenv("MLOPS_USE_AML_PIPELINE", "true").lower() == "true" else COMMAND_JOB_FILE


@app.function_name(name="model-flow")
@app.route(route="model-flow", methods=["POST"])
def model_flow(req: func.HttpRequest) -> func.HttpResponse:
    correlation_id = _correlation_id(req)
    if len(req.get_body() or b"") > MAX_PAYLOAD_BYTES:
        return _json_response(
            {"accepted": False, "error": "payload too large", "correlation_id": correlation_id},
            413,
        )

    try:
        payload = req.get_json()
    except ValueError:
        payload = {}

    try:
        request = _orchestration_request(payload)
    except ValueError as exc:
        return _json_response(
            {"accepted": False, "error": str(exc), "correlation_id": correlation_id},
            400,
        )

    try:
        result = submit_azure_ml_job(request)
    except Exception as exc:
        logging.exception("AML job submission failed correlation_id=%s", correlation_id)
        return _json_response(
            {
                "accepted": False,
                "error": "failed to submit Azure ML job",
                "correlation_id": correlation_id,
            },
            500,
        )

    result["correlation_id"] = correlation_id
    return _json_response(result, 202)


@app.function_name(name="model-flow-blob-created")
@app.event_grid_trigger(arg_name="event")
def model_flow_blob_created(event: func.EventGridEvent) -> None:
    event_payload = event.get_json()
    try:
        request = _event_orchestration_request(event_payload)
        result = submit_azure_ml_job(request)
        logging.info(
            "Accepted Event Grid model flow event_id=%s run_id=%s job=%s",
            getattr(event, "id", None),
            result["run_id"],
            result["azure_ml_job_name"],
        )
    except ValueError as exc:
        logging.warning(
            "Rejected Event Grid model flow event_id=%s error=%s",
            getattr(event, "id", None),
            exc,
        )
    except Exception:
        logging.exception("Event Grid model flow submission failed event_id=%s", getattr(event, "id", None))
        raise


@app.function_name(name="health")
@app.route(route="health", methods=["GET"])
def health(req: func.HttpRequest) -> func.HttpResponse:
    return _json_response({"status": "ok", "role": "azure-ml-orchestrator"}, 200)


def _orchestration_request(payload: dict[str, object]) -> dict[str, str]:
    model_source = _model_source_metadata()
    request = {
        "subscription_id": _required("AZURE_SUBSCRIPTION_ID", payload),
        "resource_group": _required("AZURE_RESOURCE_GROUP", payload),
        "workspace": _required("AZURE_ML_WORKSPACE", payload),
        "storage_account": _required("AZURE_STORAGE_ACCOUNT", payload),
        "environment": _value("MLOPS_ENVIRONMENT", payload, "staging"),
        "run_owner": _value("MLOPS_RUN_OWNER", payload, "team46"),
        "trigger_type": _value("MLOPS_TRIGGER_TYPE", payload, "manual"),
        "compute_target": "azure-ml",
        "input_container": _value("MLOPS_CONTAINER_RAW_MASKED", payload, "raw-masked"),
        "input_blob_path": _value("MLOPS_INPUT_BLOB_PATH", payload, "samples/sample_pricing_v1.csv"),
        "model_repo": _value("MODEL_REPO_GITHUB", payload, model_source["model_repo"]),
        "model_ref": _value("MODEL_REPO_REF", payload, model_source["model_ref"]),
        "model_commit_sha": _value("MODEL_REPO_COMMIT_SHA", payload, model_source["model_commit_sha"]),
    }
    _validate_request(request)
    request["run_id"] = _value("MLOPS_RUN_ID", payload, _new_run_id())
    request["expected_output_prefix"] = _expected_output_prefix(request)
    return request


def _event_orchestration_request(event_payload: dict[str, object]) -> dict[str, str]:
    container, blob_path = _blob_from_event(event_payload)
    payload = {
        "environment": "staging",
        "run_owner": os.getenv("MLOPS_DEFAULT_OWNER", "team46"),
        "trigger_type": "event-grid",
        "container_raw_masked": container,
        "input_blob_path": blob_path,
        "run_id": _new_run_id("event-grid"),
    }
    request = _orchestration_request(payload)
    _validate_event_request(request)
    return request


def _required(name: str, payload: dict[str, object]) -> str:
    value = _value(name, payload, "")
    if not value:
        raise ValueError(f"{name} is required")
    return value


def _value(name: str, payload: dict[str, object], default: str) -> str:
    value = _payload_value(name, payload) or os.getenv(name) or default
    return str(value)


def _payload_value(env_name: str, payload: dict[str, object]) -> object | None:
    keys = [env_name.lower()]
    if env_name.startswith("MLOPS_"):
        keys.append(env_name.removeprefix("MLOPS_").lower())
    for key in keys:
        if key in payload:
            return payload[key]
    return None


def _validate_request(request: dict[str, str]) -> None:
    if request["environment"] not in ALLOWED_ENVIRONMENTS:
        raise ValueError("environment must be staging or validation")
    if request["input_container"] == "raw-unmasked":
        raise ValueError("raw-unmasked is not an allowed input container")
    if request["input_container"] != os.getenv("MLOPS_ALLOWED_EVENT_CONTAINER", "raw-masked"):
        raise ValueError("input container must be raw-masked")
    if not SAFE_OWNER_RE.fullmatch(request["run_owner"]):
        raise ValueError("run_owner must contain only letters, numbers, underscores, or hyphens")
    input_blob_path = request["input_blob_path"]
    if not input_blob_path or input_blob_path.startswith("/") or ".." in input_blob_path:
        raise ValueError("input_blob_path must be a relative blob path")
    if not SAFE_BLOB_RE.fullmatch(input_blob_path):
        raise ValueError("input_blob_path contains unsupported characters")
    if len(input_blob_path) > 255:
        raise ValueError("input_blob_path is too long")
    if not input_blob_path.lower().endswith(".csv"):
        raise ValueError("input_blob_path must point to a csv file")


def _validate_event_request(request: dict[str, str]) -> None:
    if request["environment"] != "staging":
        raise ValueError("Event Grid flow only supports staging")
    prefix = os.getenv("MLOPS_ALLOWED_EVENT_PREFIX", "incoming/")
    input_blob_path = request["input_blob_path"]
    if not input_blob_path.startswith(prefix):
        raise ValueError(f"Event Grid input must be under {prefix}")
    if input_blob_path.startswith("samples/") or "/samples/" in input_blob_path:
        raise ValueError("Event Grid input cannot use samples/")


def _new_run_id(suffix: str = "function") -> str:
    return datetime.now(timezone.utc).strftime(f"%Y%m%dT%H%M%SZ-{suffix}")


def _expected_output_prefix(request: dict[str, str]) -> str:
    run_date = request["run_id"][:8]
    return (
        f"environment={request['environment']}/"
        f"compute={request['compute_target']}/"
        f"trigger={request['trigger_type']}/"
        f"owner={request['run_owner']}/"
        f"run_date={run_date}/"
        f"run_id={request['run_id']}"
    )


def _correlation_id(req: func.HttpRequest) -> str:
    header_value = req.headers.get("x-correlation-id") if req.headers else None
    if header_value and SAFE_BLOB_RE.fullmatch(header_value[:64]):
        return header_value[:64]
    return str(uuid.uuid4())


def _blob_from_event(event_payload: dict[str, object]) -> tuple[str, str]:
    url = str(event_payload.get("url") or event_payload.get("data", {}).get("url") or "")
    if not url:
        raise ValueError("Event Grid payload does not include a blob url")
    parsed = urlparse(url)
    path_parts = [unquote(part) for part in parsed.path.lstrip("/").split("/", 1)]
    if len(path_parts) != 2 or not path_parts[0] or not path_parts[1]:
        raise ValueError("Event Grid blob url must include container and blob path")
    return path_parts[0], path_parts[1]


def _model_source_metadata() -> dict[str, str]:
    defaults = {
        "model_repo": "tecmx-team46-pricing/pricing-mlops",
        "model_ref": "unknown",
        "model_commit_sha": "unknown",
    }
    if not MODEL_SOURCE_FILE.exists():
        return defaults
    try:
        metadata = json.loads(MODEL_SOURCE_FILE.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        logging.warning("Unable to read model source metadata from %s", MODEL_SOURCE_FILE)
        return defaults
    return {
        "model_repo": str(metadata.get("model_repo") or defaults["model_repo"]),
        "model_ref": str(metadata.get("model_ref") or defaults["model_ref"]),
        "model_commit_sha": str(metadata.get("model_commit_sha") or defaults["model_commit_sha"]),
    }


def _json_response(body: dict[str, object], status_code: int) -> func.HttpResponse:
    return func.HttpResponse(
        json.dumps(body, sort_keys=True),
        status_code=status_code,
        mimetype="application/json",
    )


def submit_azure_ml_job(request: dict[str, str]) -> dict[str, str | bool]:
    from azure.ai.ml import MLClient, load_job

    _record_run_metadata(request, "submitting")
    credential = _azure_credential()
    client = MLClient(
        credential,
        request["subscription_id"],
        request["resource_group"],
        request["workspace"],
    )
    job = load_job(source=JOB_FILE)
    _apply_job_inputs(job, {
        "storage_account": request["storage_account"],
        "environment": request["environment"],
        "run_owner": request["run_owner"],
        "run_id": request["run_id"],
        "input_blob_path": request["input_blob_path"],
        "trigger_type": request["trigger_type"],
        "model_repo": request["model_repo"],
        "model_ref": request["model_ref"],
        "model_commit_sha": request["model_commit_sha"],
    })
    _apply_job_identity(job)
    created = client.jobs.create_or_update(job)
    result = {
        "accepted": True,
        "azure_ml_job_name": created.name,
        "run_id": request["run_id"],
        "expected_output_prefix": request["expected_output_prefix"],
    }
    _record_run_metadata({**request, "azure_ml_job_name": created.name}, "submitted")
    return result


def _apply_job_inputs(job, values: dict[str, str]) -> None:
    for key, value in values.items():
        if hasattr(job, "_job_inputs") and key in job._job_inputs:
            job._job_inputs[key] = value
        if key not in job.inputs:
            continue
        node_input = job.inputs[key]
        node_input._data = value
        node_input._original_data = value
        if hasattr(node_input, "_meta") and isinstance(node_input._meta, dict):
            node_input._meta["default"] = value
        if getattr(job, "component", None) is not None and key in job.component.inputs:
            job.component.inputs[key]["default"] = value


def _apply_job_identity(job) -> None:
    job_identity_client_id = os.getenv("AZURE_ML_JOB_IDENTITY_CLIENT_ID", "").strip()
    if not job_identity_client_id or not hasattr(job, "jobs"):
        return

    from azure.ai.ml.entities import ManagedIdentityConfiguration

    managed_identity = ManagedIdentityConfiguration(client_id=job_identity_client_id)
    for node in job.jobs.values():
        if hasattr(node, "identity"):
            node.identity = managed_identity


def _record_run_metadata(request: dict[str, str], status: str) -> None:
    table_name = os.getenv("MLOPS_RUN_INDEX_TABLE", "mlopsruns")
    entity = {
        "PartitionKey": request["environment"],
        "RowKey": request["run_id"],
        "run_id": request["run_id"],
        "environment": request["environment"],
        "owner": request["run_owner"],
        "trigger_type": request["trigger_type"],
        "input_blob_path": request["input_blob_path"],
        "status": status,
        "submitted_at": datetime.now(timezone.utc).isoformat(),
        "expected_output_prefix": request["expected_output_prefix"],
        "model_repo": request["model_repo"],
        "model_ref": request["model_ref"],
        "model_commit_sha": request["model_commit_sha"],
    }
    if request.get("azure_ml_job_name"):
        entity["azure_ml_job_name"] = request["azure_ml_job_name"]

    try:
        from azure.data.tables import TableServiceClient, UpdateMode

        account_url = f"https://{request['storage_account']}.table.core.windows.net"
        table_client = TableServiceClient(
            endpoint=account_url,
            credential=_azure_credential(),
        ).get_table_client(table_name)
        table_client.upsert_entity(entity=entity, mode=UpdateMode.REPLACE)
    except Exception:
        logging.exception("Unable to write run metadata to Azure Table; falling back to run metadata blob")
        try:
            _record_run_metadata_blob(request, entity)
        except Exception:
            logging.exception("Unable to write fallback run metadata blob; continuing without orchestrator metadata")


def _record_run_metadata_blob(request: dict[str, str], entity: dict[str, str]) -> None:
    from azure.storage.blob import BlobServiceClient

    account_url = f"https://{request['storage_account']}.blob.core.windows.net"
    blob_service = BlobServiceClient(account_url=account_url, credential=_azure_credential())
    blob_path = f"{request['expected_output_prefix']}/orchestrator_metadata.json"
    blob_service.get_blob_client(container=os.getenv("MLOPS_CONTAINER_RUNS", "runs"), blob=blob_path).upload_blob(
        json.dumps(entity, indent=2, sort_keys=True),
        overwrite=True,
    )


def _azure_credential():
    from azure.identity import DefaultAzureCredential, ManagedIdentityCredential

    if os.getenv("MSI_ENDPOINT") or os.getenv("IDENTITY_ENDPOINT"):
        return ManagedIdentityCredential()
    return DefaultAzureCredential()
