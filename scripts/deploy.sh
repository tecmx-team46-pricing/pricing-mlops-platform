#!/usr/bin/env bash
set -euo pipefail

ENVIRONMENT="${1:-staging}"
LOCATION="${AZURE_LOCATION:-eastus2}"
EXPECTED_SUBSCRIPTION_NAME="${AZURE_SUBSCRIPTION_NAME:-<azure-subscription-name>}"
FOUNDATION_DEPLOYMENT_NAME="pricing-mlops-foundation-${ENVIRONMENT}-$(date +%Y%m%d%H%M%S)"
WORKLOAD_DEPLOYMENT_NAME="pricing-mlops-workload-${ENVIRONMENT}-$(date +%Y%m%d%H%M%S)"
PARAMETER_FILE="infra/parameters/${ENVIRONMENT}.bicepparam"
FOUNDATION_TEMPLATE="infra/foundation/main.bicep"
WORKLOAD_TEMPLATE="infra/workloads/pricing-mlops/main.bicep"
EXTRA_PARAMETERS=()
PARAMETERS_JSON=""

if [[ "${GITHUB_ACTIONS:-false}" == "true" ]]; then
  EXTRA_PARAMETERS+=(enableGithubActionsIdentity=false)
fi

if [[ -n "${ENABLE_HELLO_FUNCTION:-}" ]]; then
  EXTRA_PARAMETERS+=(enableHelloFunction="${ENABLE_HELLO_FUNCTION}")
fi

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

if [[ ! -f "${FOUNDATION_TEMPLATE}" ]]; then
  echo "Foundation template not found: ${FOUNDATION_TEMPLATE}" >&2
  exit 1
fi

if [[ ! -f "${WORKLOAD_TEMPLATE}" ]]; then
  echo "Pricing MLOps workload template not found: ${WORKLOAD_TEMPLATE}" >&2
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

PARAMETERS_JSON="$(mktemp)"
trap 'rm -f "${PARAMETERS_JSON}"' EXIT
az bicep build-params --file "${PARAMETER_FILE}" --outfile "${PARAMETERS_JSON}" >/dev/null

echo "Deploying foundation: ${ENVIRONMENT}"
az deployment sub create \
  --name "${FOUNDATION_DEPLOYMENT_NAME}" \
  --template-file "${FOUNDATION_TEMPLATE}" \
  --location "${LOCATION}" \
  --parameters "${PARAMETERS_JSON}" "${EXTRA_PARAMETERS[@]}"

echo "Deploying Pricing MLOps workload: ${ENVIRONMENT}"
az deployment sub create \
  --name "${WORKLOAD_DEPLOYMENT_NAME}" \
  --template-file "${WORKLOAD_TEMPLATE}" \
  --location "${LOCATION}" \
  --parameters "${PARAMETERS_JSON}" "${EXTRA_PARAMETERS[@]}"
