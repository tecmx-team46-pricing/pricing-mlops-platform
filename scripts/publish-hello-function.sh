#!/usr/bin/env bash
set -euo pipefail

ENVIRONMENT="${1:-sandbox-local}"
EXPECTED_SUBSCRIPTION_NAME="${AZURE_SUBSCRIPTION_NAME:-<azure-subscription-name>}"
SOURCE_DIR="src/functions/pricing-mlops-hello"

case "${ENVIRONMENT}" in
  staging)
    RESOURCE_GROUP_NAME="rg-pricing-mlops-staging"
    ;;
  sandbox-local)
    RESOURCE_GROUP_NAME="rg-pricing-mlops-sbx-local"
    ;;
  validation)
    RESOURCE_GROUP_NAME="rg-pricing-mlops-validation"
    ;;
  *)
    echo "Unsupported environment: ${ENVIRONMENT}" >&2
    echo "Allowed environments: staging, sandbox-local, validation" >&2
    exit 1
    ;;
esac

if [[ ! -d "${SOURCE_DIR}" ]]; then
  echo "Function source not found: ${SOURCE_DIR}" >&2
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

FUNCTION_APP_NAME="$(az functionapp list \
  --resource-group "${RESOURCE_GROUP_NAME}" \
  --query "[?starts_with(name, 'func-pricing-mlops')].name | [0]" \
  --output tsv)"

if [[ -z "${FUNCTION_APP_NAME}" ]]; then
  echo "No Pricing MLOps Function App found in ${RESOURCE_GROUP_NAME}." >&2
  echo "Run scripts/deploy.sh ${ENVIRONMENT} first." >&2
  exit 1
fi

PACKAGE_DIR="$(mktemp -d)"
PACKAGE_FILE="${PACKAGE_DIR}/pricing-mlops-hello.zip"
trap 'rm -rf "${PACKAGE_DIR}"' EXIT

(
  cd "${SOURCE_DIR}"
  zip -qr "${PACKAGE_FILE}" host.json package.json health
)

az functionapp deployment source config-zip \
  --resource-group "${RESOURCE_GROUP_NAME}" \
  --name "${FUNCTION_APP_NAME}" \
  --src "${PACKAGE_FILE}"

echo "Published ${SOURCE_DIR} to ${FUNCTION_APP_NAME}."
