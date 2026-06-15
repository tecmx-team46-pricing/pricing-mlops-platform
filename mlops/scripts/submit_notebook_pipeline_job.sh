#!/usr/bin/env bash
set -euo pipefail

ENVIRONMENT="${1:-staging}"
RUN_OWNER="${2:-team46}"
INPUT_BLOB_PATH="${3:-${MLOPS_CURRENT_AUTH_HISTORY_BLOB_PATH:-samples/sample_pricing_v1.csv}}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MLOPS_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
PLATFORM_ROOT="$(cd "${MLOPS_ROOT}/.." && pwd)"
MODEL_REPO_PATH="${MODEL_REPO_PATH:-${PRICING_MLOPS_REPO:-${PLATFORM_ROOT}/../pricing-mlops}}"
JOB_FILE="${MLOPS_ROOT}/azureml/pricing-mlops-notebook-pipeline.yml"

SUBSCRIPTION_ID="${AZURE_SUBSCRIPTION_ID:-}"
RESOURCE_GROUP="${AZURE_RESOURCE_GROUP:-}"
AZURE_ML_WORKSPACE="${AZURE_ML_WORKSPACE:-}"
AZURE_STORAGE_ACCOUNT="${AZURE_STORAGE_ACCOUNT:-}"
JOB_TEMPLATE="${MLOPS_JOB_TEMPLATE:-notebook}"
BASELINE_SNAPSHOT_CONTAINER="${MLOPS_BASELINE_SNAPSHOT_CONTAINER:-${MLOPS_CONTAINER_ARTIFACTS:-artifacts}}"
BASELINE_SNAPSHOT_BLOB_PATH="${MLOPS_BASELINE_SNAPSHOT_BLOB_PATH:-}"
CURRENT_HISTORY_CONTAINER="${MLOPS_CURRENT_HISTORY_CONTAINER:-${MLOPS_CONTAINER_RAW_MASKED:-raw-masked}}"
CURRENT_HISTORY_BLOB_PATH="${MLOPS_CURRENT_AUTH_HISTORY_BLOB_PATH:-${INPUT_BLOB_PATH}}"
RUN_ID="${MLOPS_RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)-notebook-direct}"

if [[ "${JOB_TEMPLATE}" != "notebook" ]]; then
  echo "This script is only for MLOPS_JOB_TEMPLATE=notebook." >&2
  exit 1
fi

if [[ -z "${SUBSCRIPTION_ID}" ]]; then
  SUBSCRIPTION_ID="$(az account show --query id -o tsv)"
fi

require_value() {
  local name="$1"
  local value="$2"
  if [[ -z "${value}" ]]; then
    echo "${name} is required." >&2
    exit 1
  fi
}

require_value AZURE_RESOURCE_GROUP "${RESOURCE_GROUP}"

if [[ -z "${AZURE_ML_WORKSPACE}" ]]; then
  echo "AZURE_ML_WORKSPACE is required for direct AUTH monitoring submit." >&2
  exit 1
fi

if [[ -z "${AZURE_STORAGE_ACCOUNT}" ]]; then
  echo "AZURE_STORAGE_ACCOUNT is required for direct AUTH monitoring submit." >&2
  exit 1
fi

if [[ -z "${BASELINE_SNAPSHOT_BLOB_PATH}" ]]; then
  echo "MLOPS_BASELINE_SNAPSHOT_BLOB_PATH is required for AUTH monitoring." >&2
  exit 1
fi

if [[ -z "${CURRENT_HISTORY_BLOB_PATH}" ]]; then
  echo "MLOPS_CURRENT_AUTH_HISTORY_BLOB_PATH or input_blob_path is required." >&2
  exit 1
fi

if [[ ! -d "${MODEL_REPO_PATH}" ]]; then
  echo "MODEL_REPO_PATH does not exist: ${MODEL_REPO_PATH}" >&2
  exit 1
fi

for component in build_monitoring_inputs.py calculate_recommendation_validity.py calculate_auth_history_drift.py calculate_operational_decision.py; do
  if [[ ! -f "${MODEL_REPO_PATH}/scripts/components/${component}" ]]; then
    echo "MODEL_REPO_PATH does not include ${component}: ${MODEL_REPO_PATH}" >&2
    exit 1
  fi
done

MODEL_COMMIT_SHA="$(git -C "${MODEL_REPO_PATH}" rev-parse HEAD 2>/dev/null || echo unknown)"
JOB_WORKDIR="$(mktemp -d)"
trap 'rm -rf "${JOB_WORKDIR}"' EXIT

mkdir -p "${JOB_WORKDIR}/azureml"
rsync -a \
  --exclude '.git/' \
  --exclude '.github/' \
  --exclude '.venv/' \
  --exclude 'azureml/' \
  --exclude 'docs/' \
  --exclude 'notebooks/' \
  --exclude 'references/' \
  --exclude 'reports/' \
  --exclude 'data/samples/unmasked/' \
  --exclude 'tests/' \
  --exclude '__pycache__/' \
  --exclude '.pytest_cache/' \
  --exclude 'runs/' \
  --exclude 'src/*.egg-info/' \
  --exclude '*.pyc' \
  "${MODEL_REPO_PATH}/" \
  "${JOB_WORKDIR}/pricing-mlops-source/"
cp "${JOB_FILE}" "${JOB_WORKDIR}/azureml/pricing-mlops-notebook-pipeline.yml"
cp "${MLOPS_ROOT}/azureml/environment.yml" "${JOB_WORKDIR}/azureml/environment.yml"

echo "Submitting AUTH monitoring pipeline direct to Azure ML"
echo "Nodes: validate_prepare,build_monitoring_inputs,calculate_recommendation_validity,calculate_auth_history_drift,calculate_operational_decision,publish_outputs"
echo "Run id: ${RUN_ID}"
echo "Input: ${CURRENT_HISTORY_CONTAINER}/${CURRENT_HISTORY_BLOB_PATH}"
echo "Baseline snapshot: ${BASELINE_SNAPSHOT_CONTAINER}/${BASELINE_SNAPSHOT_BLOB_PATH}"

az ml job create \
  --subscription "${SUBSCRIPTION_ID}" \
  --resource-group "${RESOURCE_GROUP}" \
  --workspace-name "${AZURE_ML_WORKSPACE}" \
  --file "${JOB_WORKDIR}/azureml/pricing-mlops-notebook-pipeline.yml" \
  --set \
    inputs.storage_account="${AZURE_STORAGE_ACCOUNT}" \
    inputs.environment="${ENVIRONMENT}" \
    inputs.run_owner="${RUN_OWNER}" \
    inputs.run_id="${RUN_ID}" \
    inputs.input_blob_path="${INPUT_BLOB_PATH}" \
    inputs.baseline_snapshot_container="${BASELINE_SNAPSHOT_CONTAINER}" \
    inputs.baseline_snapshot_blob_path="${BASELINE_SNAPSHOT_BLOB_PATH}" \
    inputs.current_history_container="${CURRENT_HISTORY_CONTAINER}" \
    inputs.current_history_blob_path="${CURRENT_HISTORY_BLOB_PATH}" \
    inputs.trigger_type="${MLOPS_TRIGGER_TYPE:-manual-direct}" \
    inputs.model_repo="${MODEL_REPO_GITHUB:-tecmx-team46-pricing/pricing-mlops}" \
    inputs.model_ref="${MODEL_REPO_REF:-local-direct}" \
    inputs.model_commit_sha="${MODEL_COMMIT_SHA}" \
    inputs.job_identity_client_id="${AZURE_ML_JOB_IDENTITY_CLIENT_ID:-}" \
  --query "{name:name,status:status,studio_url:studio_url}" -o json
