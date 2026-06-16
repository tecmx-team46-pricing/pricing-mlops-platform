#!/usr/bin/env bash
set -euo pipefail

EXPECTED_SUBSCRIPTION_NAME="${AZURE_SUBSCRIPTION_NAME:-Tecmx}"
RESOURCE_GROUP="${AZURE_RESOURCE_GROUP:-rg-pricing-mlops-main}"
WORKSPACE="${AZURE_ML_WORKSPACE:-mlw-pmlops-06152240}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MLOPS_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
COMPONENT_FILE="${MLOPS_ROOT}/azureml/platform-publish-outputs-component.yml"

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

echo "Registering platform publish component from ${COMPONENT_FILE}"
az ml component create \
  --resource-group "${RESOURCE_GROUP}" \
  --workspace-name "${WORKSPACE}" \
  --file "${COMPONENT_FILE}" \
  --only-show-errors

echo "Platform publish component registered."
