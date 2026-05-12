#!/usr/bin/env bash
set -euo pipefail

ENVIRONMENT="${1:-staging}"
LOCATION="${AZURE_LOCATION:-eastus2}"
EXPECTED_SUBSCRIPTION_NAME="${AZURE_SUBSCRIPTION_NAME:-<azure-subscription-name>}"
DEPLOYMENT_NAME="pricing-mlops-${ENVIRONMENT}-$(date +%Y%m%d%H%M%S)"
PARAMETER_FILE="infra/parameters/${ENVIRONMENT}.bicepparam"

case "${ENVIRONMENT}" in
  staging|sandbox-david|validation) ;;
  *)
    echo "Unsupported environment: ${ENVIRONMENT}" >&2
    echo "Allowed environments: staging, sandbox-david, validation" >&2
    exit 1
    ;;
esac

if [[ ! -f "${PARAMETER_FILE}" ]]; then
  echo "Parameter file not found: ${PARAMETER_FILE}" >&2
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

az deployment sub create \
  --name "${DEPLOYMENT_NAME}" \
  --location "${LOCATION}" \
  --parameters "${PARAMETER_FILE}"
