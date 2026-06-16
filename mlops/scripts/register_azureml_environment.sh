#!/usr/bin/env bash
set -euo pipefail

SUBSCRIPTION_ID="${AZURE_SUBSCRIPTION_ID:-}"
RESOURCE_GROUP="${AZURE_RESOURCE_GROUP:-}"
AZURE_ML_WORKSPACE="${AZURE_ML_WORKSPACE:-}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLATFORM_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
ENVIRONMENT_FILE="${PLATFORM_ROOT}/mlops/azureml/environment.yml"

require_value() {
  local name="$1"
  local value="$2"
  if [[ -z "${value}" ]]; then
    echo "${name} is required." >&2
    exit 1
  fi
}

require_value AZURE_SUBSCRIPTION_ID "${SUBSCRIPTION_ID}"
require_value AZURE_RESOURCE_GROUP "${RESOURCE_GROUP}"
require_value AZURE_ML_WORKSPACE "${AZURE_ML_WORKSPACE}"

if [[ ! -f "${ENVIRONMENT_FILE}" ]]; then
  echo "Azure ML environment file not found: ${ENVIRONMENT_FILE}" >&2
  exit 1
fi

az account set --subscription "${SUBSCRIPTION_ID}"

echo "Registering Azure ML environment from mlops/azureml/environment.yml"
az ml environment create \
  --subscription "${SUBSCRIPTION_ID}" \
  --resource-group "${RESOURCE_GROUP}" \
  --workspace-name "${AZURE_ML_WORKSPACE}" \
  --file "${ENVIRONMENT_FILE}"

echo "Azure ML environment registered."
