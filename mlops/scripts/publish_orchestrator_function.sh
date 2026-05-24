#!/usr/bin/env bash
set -euo pipefail

ENVIRONMENT="${1:-staging}"
EXPECTED_SUBSCRIPTION_NAME="${AZURE_SUBSCRIPTION_NAME:-<azure-subscription-name>}"
RESOURCE_GROUP="${AZURE_RESOURCE_GROUP:-rg-pricing-mlops-${ENVIRONMENT}}"
FUNCTION_APP="${AZURE_FUNCTION_APP:-}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MLOPS_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
PLATFORM_ROOT="$(cd "${MLOPS_ROOT}/.." && pwd)"
WORKSPACE_ROOT="$(cd "${PLATFORM_ROOT}/.." && pwd)"
PRICING_MLOPS_REPO="${PRICING_MLOPS_REPO:-${WORKSPACE_ROOT}/pricing-mlops}"
DRY_RUN="${DRY_RUN:-false}"
KEEP_PACKAGE="${KEEP_PACKAGE:-false}"

if [[ "${ENVIRONMENT}" != "staging" && "${ENVIRONMENT}" != "validation" ]]; then
  echo "Unsupported environment for Function publish: ${ENVIRONMENT}" >&2
  echo "Allowed environments: staging, validation" >&2
  exit 1
fi

required_files=(
  "${MLOPS_ROOT}/functions/function_app.py"
  "${MLOPS_ROOT}/functions/host.json"
  "${MLOPS_ROOT}/functions/requirements.txt"
  "${MLOPS_ROOT}/azureml/pricing-mlops-job.yml"
  "${MLOPS_ROOT}/azureml/environment.yml"
  "${PRICING_MLOPS_REPO}/pyproject.toml"
  "${PRICING_MLOPS_REPO}/scripts/run_azure_ml_flow.py"
  "${PRICING_MLOPS_REPO}/src/pricing_mlops/__init__.py"
)

for file in "${required_files[@]}"; do
  if [[ ! -f "${file}" ]]; then
    echo "Required file not found: ${file}" >&2
    exit 1
  fi
done

if [[ "${DRY_RUN}" != "true" ]]; then
  if [[ -z "${FUNCTION_APP}" ]]; then
    FUNCTION_APP="$(az resource list \
      --resource-group "${RESOURCE_GROUP}" \
      --resource-type Microsoft.Web/sites \
      --query "[?contains(name, 'func-pricing-mlops')].name | [0]" -o tsv)"
  fi

  if [[ -z "${FUNCTION_APP}" ]]; then
    echo "Function App not found. Set AZURE_FUNCTION_APP or deploy platform first." >&2
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
fi

PACKAGE_DIR="$(mktemp -d)"
PACKAGE_ROOT="${PACKAGE_DIR}/package"
PACKAGE_PATH="${PACKAGE_DIR}/pricing-mlops-function.zip"

if [[ "${KEEP_PACKAGE}" != "true" ]]; then
  trap 'rm -rf "${PACKAGE_DIR}"' EXIT
fi

mkdir -p "${PACKAGE_ROOT}/azureml" "${PACKAGE_ROOT}/pricing-mlops-source"
cp "${MLOPS_ROOT}/functions/function_app.py" "${PACKAGE_ROOT}/function_app.py"
cp "${MLOPS_ROOT}/functions/host.json" "${PACKAGE_ROOT}/host.json"
cp "${MLOPS_ROOT}/functions/requirements.txt" "${PACKAGE_ROOT}/requirements.txt"
cp "${MLOPS_ROOT}/azureml/pricing-mlops-job.yml" "${PACKAGE_ROOT}/azureml/pricing-mlops-job.yml"
cp "${MLOPS_ROOT}/azureml/environment.yml" "${PACKAGE_ROOT}/azureml/environment.yml"

rsync -a \
  --exclude '.git/' \
  --exclude '.github/' \
  --exclude '.venv/' \
  --exclude 'azureml/' \
  --exclude 'docs/' \
  --exclude 'notebooks/' \
  --exclude 'references/' \
  --exclude 'reports/' \
  --exclude 'tests/' \
  --exclude '__pycache__/' \
  --exclude '.pytest_cache/' \
  --exclude 'runs/' \
  --exclude 'src/*.egg-info/' \
  --exclude '*.pyc' \
  "${PRICING_MLOPS_REPO}/" \
  "${PACKAGE_ROOT}/pricing-mlops-source/"

(cd "${PACKAGE_ROOT}" && zip -qr "${PACKAGE_PATH}" .)

if [[ "${DRY_RUN}" == "true" ]]; then
  echo "Package prepared: ${PACKAGE_PATH}"
  echo "Package root: ${PACKAGE_ROOT}"
  unzip -Z1 "${PACKAGE_PATH}" | sort
  exit 0
fi

az functionapp deployment source config-zip \
  --resource-group "${RESOURCE_GROUP}" \
  --name "${FUNCTION_APP}" \
  --src "${PACKAGE_PATH}" \
  --build-remote true

echo "Published Function App: ${FUNCTION_APP}"
