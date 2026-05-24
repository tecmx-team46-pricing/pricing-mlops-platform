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
MODEL_REPO_GITHUB="${MODEL_REPO_GITHUB:-tecmx-team46-pricing/pricing-mlops}"
MODEL_REPO_REF="${MODEL_REPO_REF:-PoC/model-flow-template}"
MODEL_REPO_PATH="${MODEL_REPO_PATH:-${PRICING_MLOPS_REPO:-}}"
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
  "${MLOPS_ROOT}/azureml/pricing-mlops-pipeline.yml"
  "${MLOPS_ROOT}/azureml/environment.yml"
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
MODEL_SOURCE_DIR="${PACKAGE_DIR}/model-source"

if [[ "${KEEP_PACKAGE}" != "true" ]]; then
  trap 'rm -rf "${PACKAGE_DIR}"' EXIT
fi
mkdir -p "${MODEL_SOURCE_DIR}"

if [[ -n "${MODEL_REPO_PATH}" ]]; then
  if [[ ! -d "${MODEL_REPO_PATH}" ]]; then
    echo "MODEL_REPO_PATH does not exist: ${MODEL_REPO_PATH}" >&2
    exit 1
  fi
  rsync -a \
    --exclude '.git/' \
    --exclude '.github/' \
    --exclude '.venv/' \
    --exclude 'azureml/' \
    --exclude 'docs/' \
    --exclude 'notebooks/' \
    --exclude 'references/' \
    --exclude 'reports/' \
    --exclude 'data/samples/unmasked/' \
    --exclude 'tests/' \
    --exclude '__pycache__/' \
    --exclude '.pytest_cache/' \
    --exclude 'runs/' \
    --exclude 'src/*.egg-info/' \
    --exclude '*.pyc' \
    "${MODEL_REPO_PATH}/" \
    "${MODEL_SOURCE_DIR}/"
  MODEL_COMMIT_SHA="$(git -C "${MODEL_REPO_PATH}" rev-parse HEAD 2>/dev/null || echo unknown)"
else
  git init -q "${MODEL_SOURCE_DIR}"
  git -C "${MODEL_SOURCE_DIR}" remote add origin "https://github.com/${MODEL_REPO_GITHUB}.git"
  git -C "${MODEL_SOURCE_DIR}" fetch -q --depth 1 origin "${MODEL_REPO_REF}"
  git -C "${MODEL_SOURCE_DIR}" checkout -q FETCH_HEAD
  MODEL_COMMIT_SHA="$(git -C "${MODEL_SOURCE_DIR}" rev-parse HEAD)"
  rm -rf "${MODEL_SOURCE_DIR}/.git" "${MODEL_SOURCE_DIR}/.github"
fi

for file in \
  "${MODEL_SOURCE_DIR}/pyproject.toml" \
  "${MODEL_SOURCE_DIR}/scripts/run_azure_ml_flow.py" \
  "${MODEL_SOURCE_DIR}/src/pricing_mlops/__init__.py"; do
  if [[ ! -f "${file}" ]]; then
    echo "Required model source file not found: ${file}" >&2
    exit 1
  fi
done

mkdir -p "${PACKAGE_ROOT}/azureml" "${PACKAGE_ROOT}/pricing-mlops-source"
cp "${MLOPS_ROOT}/functions/function_app.py" "${PACKAGE_ROOT}/function_app.py"
cp "${MLOPS_ROOT}/functions/host.json" "${PACKAGE_ROOT}/host.json"
cp "${MLOPS_ROOT}/functions/requirements.txt" "${PACKAGE_ROOT}/requirements.txt"
cp "${MLOPS_ROOT}/azureml/pricing-mlops-job.yml" "${PACKAGE_ROOT}/azureml/pricing-mlops-job.yml"
cp "${MLOPS_ROOT}/azureml/pricing-mlops-pipeline.yml" "${PACKAGE_ROOT}/azureml/pricing-mlops-pipeline.yml"
cp "${MLOPS_ROOT}/azureml/environment.yml" "${PACKAGE_ROOT}/azureml/environment.yml"
python - <<'PY' "${PACKAGE_ROOT}/model_source.json" "${MODEL_REPO_GITHUB}" "${MODEL_REPO_REF}" "${MODEL_COMMIT_SHA}"
import json
import sys

path, repo, ref, sha = sys.argv[1:5]
with open(path, "w", encoding="utf-8") as handle:
    json.dump(
        {
            "model_repo": repo,
            "model_ref": ref,
            "model_commit_sha": sha,
        },
        handle,
        indent=2,
        sort_keys=True,
    )
    handle.write("\n")
PY

rsync -a \
  "${MODEL_SOURCE_DIR}/" \
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
