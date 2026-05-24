#!/usr/bin/env bash
set -euo pipefail

ENVIRONMENT="${1:-staging}"
RUN_OWNER="${2:-team46}"
INPUT_BLOB_PATH="${3:-samples/sample_pricing_v1.csv}"

EXPECTED_SUBSCRIPTION_NAME="${AZURE_SUBSCRIPTION_NAME:-<azure-subscription-name>}"
SUBSCRIPTION_ID="${AZURE_SUBSCRIPTION_ID:-}"
RESOURCE_GROUP="${AZURE_RESOURCE_GROUP:-rg-pricing-mlops-${ENVIRONMENT}}"
AZURE_ML_WORKSPACE="${AZURE_ML_WORKSPACE:-}"
AZURE_FUNCTION_APP="${AZURE_FUNCTION_APP:-}"
AZURE_STORAGE_ACCOUNT="${AZURE_STORAGE_ACCOUNT:-<mlops-storage-account>}"
RAW_MASKED_CONTAINER="${MLOPS_CONTAINER_RAW_MASKED:-raw-masked}"

case "${ENVIRONMENT}" in
  staging|validation) ;;
  *)
    echo "Unsupported environment: ${ENVIRONMENT}" >&2
    echo "Allowed environments: staging, validation" >&2
    exit 1
    ;;
esac

if [[ ! "${RUN_OWNER}" =~ ^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$ ]]; then
  echo "run_owner must contain only letters, numbers, underscores, or hyphens." >&2
  exit 1
fi

if [[ -z "${INPUT_BLOB_PATH}" || "${INPUT_BLOB_PATH}" == /* || "${INPUT_BLOB_PATH}" == *..* ]]; then
  echo "input_blob_path must be a relative blob path." >&2
  exit 1
fi

ACTIVE_SUBSCRIPTION_NAME="$(az account show --query name -o tsv 2>/dev/null || true)"
if [[ -z "${ACTIVE_SUBSCRIPTION_NAME}" ]]; then
  echo "Run az login and select the subscription first." >&2
  exit 1
fi

if [[ "${ACTIVE_SUBSCRIPTION_NAME}" != "${EXPECTED_SUBSCRIPTION_NAME}" ]]; then
  echo "Active subscription is '${ACTIVE_SUBSCRIPTION_NAME}', expected '${EXPECTED_SUBSCRIPTION_NAME}'." >&2
  echo "Run: az account set --subscription \"${EXPECTED_SUBSCRIPTION_NAME}\"" >&2
  exit 1
fi

if [[ -z "${SUBSCRIPTION_ID}" ]]; then
  SUBSCRIPTION_ID="$(az account show --query id -o tsv)"
fi

if [[ -z "${AZURE_FUNCTION_APP}" ]]; then
  AZURE_FUNCTION_APP="$(az resource list \
    --resource-group "${RESOURCE_GROUP}" \
    --resource-type Microsoft.Web/sites \
    --query "[?contains(name, 'func-pricing-mlops')].name | [0]" -o tsv)"
fi

if [[ -z "${AZURE_FUNCTION_APP}" ]]; then
  echo "Function App not found. Set AZURE_FUNCTION_APP or deploy platform first." >&2
  exit 1
fi

if [[ -z "${AZURE_ML_WORKSPACE}" ]]; then
  AZURE_ML_WORKSPACE="$(az functionapp config appsettings list \
    --resource-group "${RESOURCE_GROUP}" \
    --name "${AZURE_FUNCTION_APP}" \
    --query "[?name=='AZURE_ML_WORKSPACE'].value | [0]" -o tsv)"
fi

if [[ -z "${AZURE_ML_WORKSPACE}" ]]; then
  AZURE_ML_WORKSPACE="$(az resource list \
    --resource-group "${RESOURCE_GROUP}" \
    --resource-type Microsoft.MachineLearningServices/workspaces \
    --query "[?contains(name, '-v2-')].name | [0]" -o tsv)"
fi

if [[ -z "${AZURE_ML_WORKSPACE}" ]]; then
  AZURE_ML_WORKSPACE="$(az resource list \
    --resource-group "${RESOURCE_GROUP}" \
    --resource-type Microsoft.MachineLearningServices/workspaces \
    --query "[0].name" -o tsv)"
fi

if [[ -z "${AZURE_ML_WORKSPACE}" ]]; then
  echo "Azure ML workspace not found. Set AZURE_ML_WORKSPACE." >&2
  exit 1
fi

FUNCTION_KEY="$(az rest \
  --method post \
  --url "https://management.azure.com/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP}/providers/Microsoft.Web/sites/${AZURE_FUNCTION_APP}/host/default/listkeys?api-version=2023-12-01" \
  --query functionKeys.default -o tsv)"

if [[ -z "${FUNCTION_KEY}" ]]; then
  echo "Unable to resolve Function key." >&2
  exit 1
fi

RUN_ID="$(date -u +%Y%m%dT%H%M%SZ)-function"
CORRELATION_ID="${RUN_ID}"
ENDPOINT="https://${AZURE_FUNCTION_APP}.azurewebsites.net/api/model-flow"
PAYLOAD_FILE="$(mktemp)"
RESPONSE_FILE="$(mktemp)"
trap 'rm -f "${PAYLOAD_FILE}" "${RESPONSE_FILE}"' EXIT

python - <<'PY' "${PAYLOAD_FILE}" "${ENVIRONMENT}" "${RUN_OWNER}" "${INPUT_BLOB_PATH}" "${RUN_ID}"
import json
import sys

payload = {
    "environment": sys.argv[2],
    "run_owner": sys.argv[3],
    "input_blob_path": sys.argv[4],
    "run_id": sys.argv[5],
}
with open(sys.argv[1], "w", encoding="utf-8") as handle:
    json.dump(payload, handle)
PY

echo "Endpoint: ${ENDPOINT}"
echo "Input: ${RAW_MASKED_CONTAINER}/${INPUT_BLOB_PATH}"
echo "Run owner: ${RUN_OWNER}"
echo "Run id: ${RUN_ID}"

HTTP_CODE="$(curl -sS -o "${RESPONSE_FILE}" -w "%{http_code}" \
  -X POST "${ENDPOINT}" \
  -H "Content-Type: application/json" \
  -H "x-functions-key: ${FUNCTION_KEY}" \
  -H "x-correlation-id: ${CORRELATION_ID}" \
  --data @"${PAYLOAD_FILE}")"

if [[ "${HTTP_CODE}" != "202" ]]; then
  echo "Function orchestration failed with HTTP ${HTTP_CODE}" >&2
  python -m json.tool "${RESPONSE_FILE}" >&2 || cat "${RESPONSE_FILE}" >&2
  exit 1
fi

AZURE_ML_JOB_NAME="$(python - <<'PY' "${RESPONSE_FILE}"
import json
import sys
print(json.load(open(sys.argv[1], encoding="utf-8"))["azure_ml_job_name"])
PY
)"
EXPECTED_OUTPUT_PREFIX="$(python - <<'PY' "${RESPONSE_FILE}"
import json
import sys
print(json.load(open(sys.argv[1], encoding="utf-8"))["expected_output_prefix"])
PY
)"

echo "Azure ML job: ${AZURE_ML_JOB_NAME}"
echo "Expected output prefix: ${EXPECTED_OUTPUT_PREFIX}"

for attempt in {1..80}; do
  if ! JOB_STATUS="$(az rest \
      --method get \
      --url "https://management.azure.com/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP}/providers/Microsoft.MachineLearningServices/workspaces/${AZURE_ML_WORKSPACE}/jobs/${AZURE_ML_JOB_NAME}?api-version=2024-04-01" \
      --query properties.status -o tsv 2>/dev/null)"; then
    echo "Azure ML job status: unavailable from ARM, retrying"
    if [[ "${attempt}" == "80" ]]; then
      echo "Timed out waiting for Azure ML job status." >&2
      exit 1
    fi
    sleep 15
    continue
  fi
  echo "Azure ML job status: ${JOB_STATUS:-unknown}"
  if [[ "${JOB_STATUS}" == "Completed" ]]; then
    break
  fi
  if [[ "${JOB_STATUS}" == "Failed" || "${JOB_STATUS}" == "Canceled" || "${JOB_STATUS}" == "CancelRequested" || "${JOB_STATUS}" == "NotResponding" ]]; then
    echo "Azure ML job ended with status ${JOB_STATUS}." >&2
    exit 1
  fi
  if [[ "${attempt}" == "80" ]]; then
    echo "Timed out waiting for Azure ML job execution." >&2
    exit 1
  fi
  sleep 15
done

echo "Verifying output blobs:"
for item in \
  "runs:${EXPECTED_OUTPUT_PREFIX}/model_run_log.json" \
  "snapshots:${EXPECTED_OUTPUT_PREFIX}/model_output_snapshot.csv" \
  "drift-logs:${EXPECTED_OUTPUT_PREFIX}/model_drift_log.json" \
  "reports:${EXPECTED_OUTPUT_PREFIX}/report.md" \
  "artifacts:${EXPECTED_OUTPUT_PREFIX}/curated_pricing.csv" \
  "curated:${EXPECTED_OUTPUT_PREFIX}/curated_pricing.csv"; do
  container="${item%%:*}"
  blob="${item#*:}"
  az storage blob show \
    --account-name "${AZURE_STORAGE_ACCOUNT}" \
    --container-name "${container}" \
    --name "${blob}" \
    --auth-mode login \
    --query "{container:container,name:name,size:properties.contentLength,lastModified:properties.lastModified}" -o json
done

RAW_UNMASKED_STATUS="$(az rest \
  --method get \
  --url "https://management.azure.com/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP}/providers/Microsoft.Storage/storageAccounts/${AZURE_STORAGE_ACCOUNT}/blobServices/default/containers/raw-unmasked?api-version=2023-05-01" \
  --query name -o tsv 2>/dev/null || true)"

if [[ -n "${RAW_UNMASKED_STATUS}" ]]; then
  echo "Unexpected raw-unmasked container exists in ${ENVIRONMENT}." >&2
  exit 1
fi

echo "Function orchestration completed successfully."
