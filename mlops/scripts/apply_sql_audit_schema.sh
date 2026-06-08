#!/usr/bin/env bash
set -euo pipefail

ENVIRONMENT="${1:-staging}"
RESOURCE_GROUP="${AZURE_RESOURCE_GROUP:-rg-pricing-mlops-${ENVIRONMENT}}"
SQL_SERVER="${MLOPS_SQL_SERVER:-}"
SQL_DATABASE="${MLOPS_SQL_DATABASE:-pricing_mlops_audit}"
AML_IDENTITY_NAME="${AZURE_ML_JOB_IDENTITY_NAME:-id-pricing-mlops-aml-${ENVIRONMENT}}"
FUNCTION_APP_NAME="${AZURE_FUNCTION_APP:-}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MLOPS_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

if [[ "${ENVIRONMENT}" != "staging" && "${ENVIRONMENT}" != "validation" ]]; then
  echo "Unsupported environment for SQL audit schema: ${ENVIRONMENT}" >&2
  echo "Allowed environments: staging, validation" >&2
  exit 1
fi

if [[ -z "${SQL_SERVER}" ]]; then
  SQL_SERVER="$(az sql server list \
    --resource-group "${RESOURCE_GROUP}" \
    --query "[?contains(name, 'sql-pricing-mlops-${ENVIRONMENT}')].fullyQualifiedDomainName | [0]" \
    -o tsv)"
fi

if [[ -z "${FUNCTION_APP_NAME}" ]]; then
  FUNCTION_APP_NAME="$(az functionapp list \
    --resource-group "${RESOURCE_GROUP}" \
    --query "[?contains(name, 'func-pricing-mlops')].name | [0]" \
    -o tsv)"
fi

if [[ -z "${SQL_SERVER}" ]]; then
  echo "Azure SQL server not found. Set MLOPS_SQL_SERVER or deploy enableSqlAudit first." >&2
  exit 1
fi

if ! command -v sqlcmd >/dev/null 2>&1; then
  echo "sqlcmd is required to apply Azure SQL migrations with Entra auth." >&2
  echo "Install sqlcmd, then rerun this script. No schema changes were applied." >&2
  exit 2
fi

for migration in \
  "${MLOPS_ROOT}/sql/001_create_audit_tables.sql" \
  "${MLOPS_ROOT}/sql/002_create_managed_identity_users.sql"; do
  echo "Applying SQL migration: ${migration}"
  sqlcmd \
    -S "${SQL_SERVER}" \
    -d "${SQL_DATABASE}" \
    -G \
    -b \
    -i "${migration}" \
    -v AmlIdentityName="${AML_IDENTITY_NAME}" FunctionIdentityName="${FUNCTION_APP_NAME}"
done

echo "Azure SQL audit schema applied: server=${SQL_SERVER} database=${SQL_DATABASE}"
