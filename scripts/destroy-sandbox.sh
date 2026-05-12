#!/usr/bin/env bash
set -euo pipefail

RESOURCE_GROUP_NAME="${1:-}"

if [[ -z "${RESOURCE_GROUP_NAME}" ]]; then
  echo "Usage: scripts/destroy-sandbox.sh rg-pricing-mlops-sbx-<owner>-<yyyymmdd>" >&2
  exit 1
fi

case "${RESOURCE_GROUP_NAME}" in
  rg-pricing-mlops-sbx-*) ;;
  *)
    echo "Refusing to delete non-sandbox resource group: ${RESOURCE_GROUP_NAME}" >&2
    exit 1
    ;;
esac

az group delete \
  --name "${RESOURCE_GROUP_NAME}" \
  --yes \
  --no-wait

echo "Delete started for ${RESOURCE_GROUP_NAME}."
