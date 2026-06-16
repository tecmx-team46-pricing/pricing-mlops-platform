#!/usr/bin/env bash
set -euo pipefail

SUBSCRIPTION_ID="${AZURE_SUBSCRIPTION_ID:-}"
RESOURCE_GROUP="${AZURE_RESOURCE_GROUP:-}"
AZURE_ML_WORKSPACE="${AZURE_ML_WORKSPACE:-}"
DRY_RUN="${DRY_RUN:-false}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLATFORM_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
COMPONENTS_DIR="${PLATFORM_ROOT}/mlops/azureml/components"
MODEL_SOURCE_DIR="${MODEL_REPO_PATH:-${PLATFORM_ROOT}/mlops/azureml/pricing-mlops-source}"

require_value() {
  local name="$1"
  local value="$2"
  if [[ -z "${value}" ]]; then
    echo "${name} is required." >&2
    exit 1
  fi
}

require_file() {
  local path="$1"
  if [[ ! -f "${path}" ]]; then
    echo "Required file not found: ${path}" >&2
    exit 1
  fi
}

require_value AZURE_SUBSCRIPTION_ID "${SUBSCRIPTION_ID}"
require_value AZURE_RESOURCE_GROUP "${RESOURCE_GROUP}"
require_value AZURE_ML_WORKSPACE "${AZURE_ML_WORKSPACE}"

required_model_files=(
  "${MODEL_SOURCE_DIR}/pyproject.toml"
  "${MODEL_SOURCE_DIR}/scripts/components/validate_prepare.py"
  "${MODEL_SOURCE_DIR}/scripts/components/build_monitoring_inputs.py"
  "${MODEL_SOURCE_DIR}/scripts/components/calculate_recommendation_validity.py"
  "${MODEL_SOURCE_DIR}/scripts/components/calculate_auth_history_drift.py"
  "${MODEL_SOURCE_DIR}/scripts/components/calculate_operational_decision.py"
  "${MODEL_SOURCE_DIR}/src/pricing_mlops/__init__.py"
)

for file in "${required_model_files[@]}"; do
  require_file "${file}"
done

component_files=(
  "${COMPONENTS_DIR}/validate_prepare.yml"
  "${COMPONENTS_DIR}/build_monitoring_inputs.yml"
  "${COMPONENTS_DIR}/calculate_recommendation_validity.yml"
  "${COMPONENTS_DIR}/calculate_auth_history_drift.yml"
  "${COMPONENTS_DIR}/calculate_operational_decision.yml"
)

for component_file in "${component_files[@]}"; do
  require_file "${component_file}"
done

if [[ "${DRY_RUN}" != "true" ]]; then
  az account set --subscription "${SUBSCRIPTION_ID}"
fi

for component_file in "${component_files[@]}"; do
  echo "Registering Azure ML component from ${component_file#${PLATFORM_ROOT}/}"
  if [[ "${DRY_RUN}" == "true" ]]; then
    echo "DRY_RUN: register component with --subscription ${SUBSCRIPTION_ID} --resource-group ${RESOURCE_GROUP} --workspace-name ${AZURE_ML_WORKSPACE} --file ${component_file}"
  else
    az ml component create \
      --subscription "${SUBSCRIPTION_ID}" \
      --resource-group "${RESOURCE_GROUP}" \
      --workspace-name "${AZURE_ML_WORKSPACE}" \
      --file "${component_file}"
  fi
done

echo "Azure ML components registered."
