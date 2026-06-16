#!/usr/bin/env bash
set -euo pipefail

ENVIRONMENT="${1:-staging}"
SUBSCRIPTION_ID="${AZURE_SUBSCRIPTION_ID:-}"
RESOURCE_GROUP="${AZURE_RESOURCE_GROUP:-}"
AZURE_ML_WORKSPACE="${AZURE_ML_WORKSPACE:-}"
AZURE_FUNCTION_APP="${AZURE_FUNCTION_APP:-}"
AZURE_STORAGE_ACCOUNT="${AZURE_STORAGE_ACCOUNT:-}"
BASELINE_SNAPSHOT_CONTAINER="${MLOPS_BASELINE_SNAPSHOT_CONTAINER:-${MLOPS_CONTAINER_ARTIFACTS:-artifacts}}"
BASELINE_SNAPSHOT_BLOB_PATH="${MLOPS_BASELINE_SNAPSHOT_BLOB_PATH:-}"
CURRENT_HISTORY_CONTAINER="${MLOPS_CURRENT_HISTORY_CONTAINER:-${MLOPS_CONTAINER_RAW_MASKED:-raw-masked}}"
CURRENT_HISTORY_BLOB_PATH="${MLOPS_CURRENT_AUTH_HISTORY_BLOB_PATH:-}"

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
require_value AZURE_FUNCTION_APP "${AZURE_FUNCTION_APP}"
require_value AZURE_STORAGE_ACCOUNT "${AZURE_STORAGE_ACCOUNT}"
require_value MLOPS_BASELINE_SNAPSHOT_BLOB_PATH "${BASELINE_SNAPSHOT_BLOB_PATH}"
require_value MLOPS_CURRENT_AUTH_HISTORY_BLOB_PATH "${CURRENT_HISTORY_BLOB_PATH}"

az account set --subscription "${SUBSCRIPTION_ID}"

echo "Azure account:"
az account show --query "{name:name,id:id,user:user.name}" -o table

echo "Checking Azure ML workspace: ${AZURE_ML_WORKSPACE}"
az ml workspace show \
  --subscription "${SUBSCRIPTION_ID}" \
  --resource-group "${RESOURCE_GROUP}" \
  --name "${AZURE_ML_WORKSPACE}" \
  --query "{name:name,location:location,storage_account:storage_account}" -o json

echo "Checking Function App: ${AZURE_FUNCTION_APP}"
az functionapp show \
  --subscription "${SUBSCRIPTION_ID}" \
  --resource-group "${RESOURCE_GROUP}" \
  --name "${AZURE_FUNCTION_APP}" \
  --query "{name:name,state:state,defaultHostName:defaultHostName}" -o json

echo "Checking Storage account: ${AZURE_STORAGE_ACCOUNT}"
az storage account show \
  --subscription "${SUBSCRIPTION_ID}" \
  --resource-group "${RESOURCE_GROUP}" \
  --name "${AZURE_STORAGE_ACCOUNT}" \
  --query "{name:name,location:location,provisioningState:provisioningState,statusOfPrimary:statusOfPrimary}" -o json

echo "Checking baseline snapshot blob: ${BASELINE_SNAPSHOT_CONTAINER}/${BASELINE_SNAPSHOT_BLOB_PATH}"
az storage blob show \
  --account-name "${AZURE_STORAGE_ACCOUNT}" \
  --container-name "${BASELINE_SNAPSHOT_CONTAINER}" \
  --name "${BASELINE_SNAPSHOT_BLOB_PATH}" \
  --auth-mode login \
  --query "{container:container,name:name,size:properties.contentLength,lastModified:properties.lastModified}" -o json

echo "Checking current history blob: ${CURRENT_HISTORY_CONTAINER}/${CURRENT_HISTORY_BLOB_PATH}"
az storage blob show \
  --account-name "${AZURE_STORAGE_ACCOUNT}" \
  --container-name "${CURRENT_HISTORY_CONTAINER}" \
  --name "${CURRENT_HISTORY_BLOB_PATH}" \
  --auth-mode login \
  --query "{container:container,name:name,size:properties.contentLength,lastModified:properties.lastModified}" -o json

echo "Notebook pipeline E2E preflight passed."
