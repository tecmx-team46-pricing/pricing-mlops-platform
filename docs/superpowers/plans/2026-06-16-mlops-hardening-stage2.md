# MLOps Hardening Stage 2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Harden the AUTH monitoring MVP without breaking the working `/api/model-flow` Azure ML path.

**Architecture:** Keep the Function as the HTTP orchestrator, keep Azure ML as the execution engine, and move fragile runtime behavior into versioned or reproducible platform contracts. Make each hardening step independently testable before running Azure.

**Tech Stack:** Azure Functions Python, Azure ML v2 pipeline jobs, Azure Blob Storage, Bash deployment scripts, pytest, Bicep.

---

### Task 1: Reproducible Function Packaging

**Files:**
- Modify: `mlops/scripts/publish_orchestrator_function.sh`
- Test: `tests/test_publish_orchestrator_function.py`

- [ ] **Step 1: Write the failing test**

Add a test that runs the publish script with `FUNCTION_PACKAGE_MODE=vendored` and `SKIP_FUNCTION_DEPENDENCY_INSTALL=true`, then asserts `.python_packages/lib/site-packages/.dependency-install-skipped` is included under the generated package root.

- [ ] **Step 2: Run test to verify it fails**

Run: `python -m pytest tests/test_publish_orchestrator_function.py::test_publish_can_prepare_vendored_function_package -q`

Expected: FAIL because the script does not create `.python_packages`.

- [ ] **Step 3: Implement vendored package mode**

Add `FUNCTION_PACKAGE_MODE=remote-build|vendored`. In vendored mode, install dependencies into `.python_packages/lib/site-packages` using Linux Python 3.11 wheels before zipping. In non-dry deployments, disable remote build and deploy the vendored ZIP with `az functionapp deployment source config-zip` without `--build-remote true`.

- [ ] **Step 4: Run test to verify it passes**

Run: `python -m pytest tests/test_publish_orchestrator_function.py -q`

Expected: all publish script tests pass.

### Task 2: Versioned Azure ML Runtime Contract

**Files:**
- Create or modify: `mlops/azureml/environment.yml`
- Modify: `mlops/azureml/pricing-mlops-pipeline.yml`
- Test: `tests/test_function_orchestrator.py`

- [ ] **Step 1: Write failing test**

Assert the pipeline no longer invokes `python -m pip install -e .` in every component and instead references a stable environment contract.

- [ ] **Step 2: Implement minimal environment contract**

Move runtime dependencies into the Azure ML environment definition and update component commands to execute scripts directly.

- [ ] **Step 3: Verify locally and with Azure ML dry load**

Run tests and `azure.ai.ml.load_job` against the pipeline YAML.

### Task 3: Versioned Decision Configuration

**Files:**
- Create or modify: `mlops/configs/auth_monitoring_decision_rules.json`
- Modify: `mlops/azureml/pricing-mlops-pipeline.yml`
- Modify: `mlops/components/platform_publish_outputs.py`
- Test: `tests/test_platform_publish_outputs.py`

- [ ] **Step 1: Write failing tests**

Assert the published run metadata includes config version, config hash, and decision rules artifact URI.

- [ ] **Step 2: Implement metadata pass-through**

Pass config version/hash through the Function request, pipeline inputs, and publish step.

### Task 4: Artifact Contract Validation

**Files:**
- Create: `mlops/schemas/auth_monitoring_artifact_manifest.schema.json`
- Create: `mlops/schemas/operational_decision_summary.schema.json`
- Modify: `tests/test_platform_publish_outputs.py`

- [ ] **Step 1: Write failing schema tests**

Validate required notebook-derived artifacts and summary files against JSON schemas or CSV header contracts.

- [ ] **Step 2: Implement contract validation in publish step**

Fail fast before publishing incomplete or incompatible artifacts.

### Task 5: Observability Metadata

**Files:**
- Modify: `mlops/functions/function_app.py`
- Modify: `mlops/components/platform_publish_outputs.py`
- Test: `tests/test_function_orchestrator.py`, `tests/test_platform_publish_outputs.py`

- [ ] **Step 1: Write failing tests**

Assert run metadata captures platform commit, model commit, pipeline template version, input blob paths, expected output prefix, and AML job name.

- [ ] **Step 2: Implement metadata fields**

Add stable fields to orchestrator metadata and published `model_run_log.json`.

### Task 6: Azure E2E Verification

**Files:**
- Modify: `mlops/scripts/run_model_flow_function.sh`
- Modify: `mlops/docs/function-orchestrator.md`

- [ ] **Step 1: Add verification checks**

Ensure the script verifies `/api/model-flow`, waits for `Completed`, and lists required blobs in `runs`, `snapshots`, `drift-logs`, `reports`, and `artifacts`.

- [ ] **Step 2: Run the E2E path in Azure**

Run the Function endpoint against sample blobs and verify final artifacts.
