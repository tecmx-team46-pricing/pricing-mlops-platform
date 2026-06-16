#!/usr/bin/env bash
set -euo pipefail

ENVIRONMENT="${1:-staging}"
EXPECTED_SUBSCRIPTION_NAME="${AZURE_SUBSCRIPTION_NAME:-<azure-subscription-name>}"
RESOURCE_GROUP="${AZURE_RESOURCE_GROUP:-}"
FUNCTION_APP="${AZURE_FUNCTION_APP:-}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MLOPS_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
PLATFORM_ROOT="$(cd "${MLOPS_ROOT}/.." && pwd)"
WORKSPACE_ROOT="$(cd "${PLATFORM_ROOT}/.." && pwd)"
MODEL_REPO_GITHUB="${MODEL_REPO_GITHUB:-tecmx-team46-pricing/pricing-mlops}"
MODEL_REPO_REF="${MODEL_REPO_REF:-}"
MODEL_REPO_PATH="${MODEL_REPO_PATH:-${PRICING_MLOPS_REPO:-}}"
ALLOW_LOCAL_MODEL_SOURCE="${ALLOW_LOCAL_MODEL_SOURCE:-false}"
ALLOW_DIRTY_LOCAL_MODEL_SOURCE="${ALLOW_DIRTY_LOCAL_MODEL_SOURCE:-false}"
DRY_RUN="${DRY_RUN:-false}"
KEEP_PACKAGE="${KEEP_PACKAGE:-false}"
FUNCTION_PACKAGE_MODE="${FUNCTION_PACKAGE_MODE:-remote-build}"
SKIP_FUNCTION_DEPENDENCY_INSTALL="${SKIP_FUNCTION_DEPENDENCY_INSTALL:-false}"
FUNCTION_DEPENDENCY_PYTHON_VERSION="${FUNCTION_DEPENDENCY_PYTHON_VERSION:-3.11}"
FUNCTION_DEPENDENCY_PLATFORM="${FUNCTION_DEPENDENCY_PLATFORM:-manylinux2014_x86_64}"
FUNCTION_DEPENDENCY_IMPLEMENTATION="${FUNCTION_DEPENDENCY_IMPLEMENTATION:-cp}"
FUNCTION_DEPENDENCY_ABI="${FUNCTION_DEPENDENCY_ABI:-cp311}"

if [[ "${ENVIRONMENT}" != "staging" && "${ENVIRONMENT}" != "validation" ]]; then
  echo "Unsupported environment for Function publish: ${ENVIRONMENT}" >&2
  echo "Allowed environments: staging, validation" >&2
  exit 1
fi

if [[ "${FUNCTION_PACKAGE_MODE}" != "remote-build" && "${FUNCTION_PACKAGE_MODE}" != "vendored" ]]; then
  echo "Unsupported Function package mode: ${FUNCTION_PACKAGE_MODE}" >&2
  echo "Allowed modes: remote-build, vendored" >&2
  exit 1
fi

required_files=(
  "${MLOPS_ROOT}/functions/function_app.py"
  "${MLOPS_ROOT}/functions/host.json"
  "${MLOPS_ROOT}/functions/requirements.txt"
  "${MLOPS_ROOT}/azureml/pricing-mlops-pipeline.yml"
  "${MLOPS_ROOT}/azureml/environment.yml"
  "${MLOPS_ROOT}/azureml/conda.yml"
  "${MLOPS_ROOT}/configs/drift_thresholds.json"
  "${MLOPS_ROOT}/components/platform_publish_outputs.py"
)

for file in "${required_files[@]}"; do
  if [[ ! -f "${file}" ]]; then
    echo "Required file not found: ${file}" >&2
    exit 1
  fi
done

if [[ "${DRY_RUN}" != "true" ]]; then
  if [[ -z "${RESOURCE_GROUP}" ]]; then
    echo "AZURE_RESOURCE_GROUP is required. Use the single principal Resource Group for this environment." >&2
    exit 1
  fi

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
  if [[ "${ALLOW_LOCAL_MODEL_SOURCE}" != "true" ]]; then
    echo "MODEL_REPO_PATH is a local/dev fallback and requires ALLOW_LOCAL_MODEL_SOURCE=true." >&2
    echo "For staging/validation publish, prefer MODEL_REPO_REF=<commit-sha-or-tag> from ${MODEL_REPO_GITHUB}." >&2
    exit 1
  fi
  if [[ ! -d "${MODEL_REPO_PATH}" ]]; then
    echo "MODEL_REPO_PATH does not exist: ${MODEL_REPO_PATH}" >&2
    exit 1
  fi
  if ! git -C "${MODEL_REPO_PATH}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "MODEL_REPO_PATH must be a git worktree so the model commit can be recorded: ${MODEL_REPO_PATH}" >&2
    exit 1
  fi
  if [[ -n "$(git -C "${MODEL_REPO_PATH}" status --short)" && "${ALLOW_DIRTY_LOCAL_MODEL_SOURCE}" != "true" ]]; then
    echo "MODEL_REPO_PATH has uncommitted changes. Commit them or set ALLOW_DIRTY_LOCAL_MODEL_SOURCE=true for local/dev dry-runs." >&2
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
  MODEL_COMMIT_SHA="$(git -C "${MODEL_REPO_PATH}" rev-parse HEAD)"
  MODEL_SOURCE_KIND="local"
else
  if [[ -z "${MODEL_REPO_REF}" ]]; then
    echo "MODEL_REPO_REF is required when publishing from GitHub model source." >&2
    echo "Use a commit SHA or tag for strict reproducibility; branches are allowed but move over time." >&2
    exit 1
  fi
  git init -q "${MODEL_SOURCE_DIR}"
  git -C "${MODEL_SOURCE_DIR}" remote add origin "https://github.com/${MODEL_REPO_GITHUB}.git"
  if ! git -C "${MODEL_SOURCE_DIR}" fetch -q --depth 1 origin "${MODEL_REPO_REF}"; then
    if ! git -C "${MODEL_SOURCE_DIR}" fetch -q --depth 1 origin "refs/heads/${MODEL_REPO_REF}"; then
      git -C "${MODEL_SOURCE_DIR}" fetch -q --depth 1 origin "refs/tags/${MODEL_REPO_REF}"
    fi
  fi
  git -C "${MODEL_SOURCE_DIR}" checkout -q FETCH_HEAD
  MODEL_COMMIT_SHA="$(git -C "${MODEL_SOURCE_DIR}" rev-parse HEAD)"
  rm -rf "${MODEL_SOURCE_DIR}/.git" "${MODEL_SOURCE_DIR}/.github"
  MODEL_SOURCE_KIND="github"
fi

required_model_source_files=(
  "${MODEL_SOURCE_DIR}/pyproject.toml"
  "${MODEL_SOURCE_DIR}/scripts/components/validate_prepare.py"
  "${MODEL_SOURCE_DIR}/scripts/components/build_monitoring_inputs.py"
  "${MODEL_SOURCE_DIR}/scripts/components/calculate_recommendation_validity.py"
  "${MODEL_SOURCE_DIR}/scripts/components/calculate_auth_history_drift.py"
  "${MODEL_SOURCE_DIR}/scripts/components/calculate_operational_decision.py"
  "${MODEL_SOURCE_DIR}/src/pricing_mlops/__init__.py"
)

for file in "${required_model_source_files[@]}"; do
  if [[ ! -f "${file}" ]]; then
    echo "Required model source file not found: ${file}" >&2
    exit 1
  fi
done

mkdir -p "${PACKAGE_ROOT}/azureml" "${PACKAGE_ROOT}/configs" "${PACKAGE_ROOT}/pricing-mlops-source" "${PACKAGE_ROOT}/platform-components"
cp "${MLOPS_ROOT}/functions/function_app.py" "${PACKAGE_ROOT}/function_app.py"
cp "${MLOPS_ROOT}/functions/host.json" "${PACKAGE_ROOT}/host.json"
cp "${MLOPS_ROOT}/functions/requirements.txt" "${PACKAGE_ROOT}/requirements.txt"
cp "${MLOPS_ROOT}/azureml/pricing-mlops-pipeline.yml" "${PACKAGE_ROOT}/azureml/pricing-mlops-pipeline.yml"
cp "${MLOPS_ROOT}/azureml/environment.yml" "${PACKAGE_ROOT}/azureml/environment.yml"
cp "${MLOPS_ROOT}/azureml/conda.yml" "${PACKAGE_ROOT}/azureml/conda.yml"
cp "${MLOPS_ROOT}/configs/drift_thresholds.json" "${PACKAGE_ROOT}/configs/drift_thresholds.json"
cp "${MLOPS_ROOT}/components/platform_publish_outputs.py" "${PACKAGE_ROOT}/platform-components/platform_publish_outputs.py"
python - <<'PY' "${PACKAGE_ROOT}/model_source.json" "${MODEL_SOURCE_KIND}" "${MODEL_REPO_GITHUB}" "${MODEL_REPO_REF}" "${MODEL_COMMIT_SHA}"
import json
import sys

path, source_kind, repo, ref, sha = sys.argv[1:6]
with open(path, "w", encoding="utf-8") as handle:
    json.dump(
        {
            "model_source": source_kind,
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
  "${MODEL_SOURCE_DIR}/" \
  "${PACKAGE_ROOT}/pricing-mlops-source/"

required_package_paths=(
  "${PACKAGE_ROOT}/function_app.py"
  "${PACKAGE_ROOT}/host.json"
  "${PACKAGE_ROOT}/requirements.txt"
  "${PACKAGE_ROOT}/azureml/pricing-mlops-pipeline.yml"
  "${PACKAGE_ROOT}/azureml/environment.yml"
  "${PACKAGE_ROOT}/azureml/conda.yml"
  "${PACKAGE_ROOT}/configs/drift_thresholds.json"
  "${PACKAGE_ROOT}/pricing-mlops-source/pyproject.toml"
  "${PACKAGE_ROOT}/pricing-mlops-source/scripts/components/validate_prepare.py"
  "${PACKAGE_ROOT}/pricing-mlops-source/scripts/components/build_monitoring_inputs.py"
  "${PACKAGE_ROOT}/pricing-mlops-source/scripts/components/calculate_recommendation_validity.py"
  "${PACKAGE_ROOT}/pricing-mlops-source/scripts/components/calculate_auth_history_drift.py"
  "${PACKAGE_ROOT}/pricing-mlops-source/scripts/components/calculate_operational_decision.py"
  "${PACKAGE_ROOT}/platform-components/platform_publish_outputs.py"
  "${PACKAGE_ROOT}/pricing-mlops-source/src/pricing_mlops/__init__.py"
  "${PACKAGE_ROOT}/model_source.json"
)

for path in "${required_package_paths[@]}"; do
  if [[ ! -e "${path}" ]]; then
    echo "Required package path not found: ${path}" >&2
    exit 1
  fi
done

if [[ "${FUNCTION_PACKAGE_MODE}" == "vendored" ]]; then
  SITE_PACKAGES_DIR="${PACKAGE_ROOT}/.python_packages/lib/site-packages"
  mkdir -p "${SITE_PACKAGES_DIR}"
  if [[ "${SKIP_FUNCTION_DEPENDENCY_INSTALL}" == "true" ]]; then
    touch "${SITE_PACKAGES_DIR}/.dependency-install-skipped"
  else
    python -m pip install \
      --disable-pip-version-check \
      --platform "${FUNCTION_DEPENDENCY_PLATFORM}" \
      --python-version "${FUNCTION_DEPENDENCY_PYTHON_VERSION}" \
      --implementation "${FUNCTION_DEPENDENCY_IMPLEMENTATION}" \
      --abi "${FUNCTION_DEPENDENCY_ABI}" \
      --only-binary=:all: \
      --ignore-installed \
      --no-warn-conflicts \
      --target "${SITE_PACKAGES_DIR}" \
      -r "${PACKAGE_ROOT}/requirements.txt"
  fi
fi

(cd "${PACKAGE_ROOT}" && zip -qr "${PACKAGE_PATH}" .)

if [[ "${DRY_RUN}" == "true" ]]; then
  echo "Model source: ${MODEL_SOURCE_KIND}"
  echo "Model repo: ${MODEL_REPO_GITHUB}"
  echo "Model ref: ${MODEL_REPO_REF}"
  echo "Model commit: ${MODEL_COMMIT_SHA}"
  echo "Function package mode: ${FUNCTION_PACKAGE_MODE}"
  echo "Package prepared: ${PACKAGE_PATH}"
  echo "Package root: ${PACKAGE_ROOT}"
  unzip -Z1 "${PACKAGE_PATH}" | sort
  exit 0
fi

if [[ "${FUNCTION_PACKAGE_MODE}" == "vendored" ]]; then
  az functionapp config appsettings set \
    --resource-group "${RESOURCE_GROUP}" \
    --name "${FUNCTION_APP}" \
    --settings SCM_DO_BUILD_DURING_DEPLOYMENT=false

  az functionapp deployment source config-zip \
    --resource-group "${RESOURCE_GROUP}" \
    --name "${FUNCTION_APP}" \
    --src "${PACKAGE_PATH}"
else
  az functionapp config appsettings set \
    --resource-group "${RESOURCE_GROUP}" \
    --name "${FUNCTION_APP}" \
    --settings SCM_DO_BUILD_DURING_DEPLOYMENT=true

  az functionapp deployment source config-zip \
    --resource-group "${RESOURCE_GROUP}" \
    --name "${FUNCTION_APP}" \
    --src "${PACKAGE_PATH}" \
    --build-remote true
fi

echo "Published Function App: ${FUNCTION_APP}"
