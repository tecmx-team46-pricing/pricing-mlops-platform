#!/usr/bin/env bash
set -euo pipefail

EXPECTED_SUBSCRIPTION_NAME="${AZURE_SUBSCRIPTION_NAME:-Tecmx}"
RESOURCE_GROUP="${AZURE_RESOURCE_GROUP:-rg-pricing-mlops-main}"
WORKSPACE="${AZURE_ML_WORKSPACE:-mlw-pmlops-06152240}"
ENDPOINT_NAME="${AZURE_ML_BATCH_ENDPOINT:-pricing-auth-monitoring}"
DEPLOYMENT_NAME="${AZURE_ML_BATCH_DEPLOYMENT:-blue}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MLOPS_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

ENDPOINT_FILE="${MLOPS_ROOT}/azureml/auth-monitoring-batch-endpoint.yml"
DEPLOYMENT_FILE="${MLOPS_ROOT}/azureml/auth-monitoring-batch-deployment.yml"
MANIFEST_FILE="${AUTH_MONITORING_PIPELINE_MANIFEST:-${MLOPS_ROOT}/manifests/auth-monitoring-pipeline-component.json}"

require_file() {
  local path="$1"
  if [[ ! -f "${path}" ]]; then
    echo "Required file not found: ${path}" >&2
    exit 1
  fi
}

json_value() {
  local path="$1"
  local key="$2"
  python - "${path}" "${key}" <<'PY'
import json
import sys
from pathlib import Path

data = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
print(data.get(sys.argv[2], ""))
PY
}

pipeline_component_from_manifest() {
  if [[ -n "${AZURE_ML_PIPELINE_COMPONENT:-}" ]]; then
    echo "${AZURE_ML_PIPELINE_COMPONENT}"
    return
  fi
  require_file "${MANIFEST_FILE}"
  json_value "${MANIFEST_FILE}" pipeline_component
}

component_name() {
  local component_id="$1"
  local rest="${component_id#azureml:}"
  echo "${rest%:*}"
}

component_version() {
  local component_id="$1"
  echo "${component_id##*:}"
}

render_deployment_file() {
  local component_id="$1"
  local output_file="$2"
  python - "${DEPLOYMENT_FILE}" "${output_file}" "${component_id}" <<'PY'
import sys
from pathlib import Path

source = Path(sys.argv[1])
target = Path(sys.argv[2])
component_id = sys.argv[3]

lines = source.read_text(encoding="utf-8").splitlines()
rendered = [
    f"component: {component_id}" if line.startswith("component: ") else line
    for line in lines
]
target.write_text("\n".join(rendered) + "\n", encoding="utf-8")
PY
}

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

PIPELINE_COMPONENT="$(pipeline_component_from_manifest)"
if [[ ! "${PIPELINE_COMPONENT}" =~ ^azureml:[A-Za-z0-9_][A-Za-z0-9_.-]*:[A-Za-z0-9_.-]+$ ]]; then
  echo "Invalid Azure ML pipeline component reference: ${PIPELINE_COMPONENT}" >&2
  echo "Expected format: azureml:<component-name>:<version>" >&2
  exit 1
fi

COMPONENT_NAME="$(component_name "${PIPELINE_COMPONENT}")"
COMPONENT_VERSION="$(component_version "${PIPELINE_COMPONENT}")"
echo "Validating pipeline component exists: ${PIPELINE_COMPONENT}"
az ml component show \
  --resource-group "${RESOURCE_GROUP}" \
  --workspace-name "${WORKSPACE}" \
  --name "${COMPONENT_NAME}" \
  --version "${COMPONENT_VERSION}" \
  --only-show-errors \
  >/dev/null

echo "Creating/updating batch endpoint ${ENDPOINT_NAME}"
az ml batch-endpoint create \
  --resource-group "${RESOURCE_GROUP}" \
  --workspace-name "${WORKSPACE}" \
  --name "${ENDPOINT_NAME}" \
  --file "${ENDPOINT_FILE}" \
  --only-show-errors

TMP_DEPLOYMENT_FILE="$(mktemp)"
trap 'rm -f "${TMP_DEPLOYMENT_FILE}"' EXIT
render_deployment_file "${PIPELINE_COMPONENT}" "${TMP_DEPLOYMENT_FILE}"

echo "Creating/updating batch deployment ${DEPLOYMENT_NAME} with ${PIPELINE_COMPONENT}"
az ml batch-deployment create \
  --resource-group "${RESOURCE_GROUP}" \
  --workspace-name "${WORKSPACE}" \
  --endpoint "${ENDPOINT_NAME}" \
  --file "${TMP_DEPLOYMENT_FILE}" \
  --only-show-errors

echo "Batch endpoint ready: ${ENDPOINT_NAME}/${DEPLOYMENT_NAME}"
