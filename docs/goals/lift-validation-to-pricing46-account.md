# Goal: Levantar Validation En Azure Para pricing46mlops

## Objetivo

Levantar el setup actual de Pricing MLOps en la cuenta `pricing46mlops@outlook.com`
usando los mismos repos GitHub:

- `tecmx-team46-pricing/pricing-mlops-platform`
- `tecmx-team46-pricing/pricing-mlops`

El ambiente objetivo inicial es `validation`. El objetivo final es que el endpoint
Azure ML de monitoreo AUTH corra end-to-end en la nueva cuenta y publique artefactos
bajo `environment=validation/...`.

Resultado de ejecucion 2026-06-21: el nombre base `pricing-auth-monitoring` no estaba
disponible en `eastus2` por colision regional de Azure ML. Para esta cuenta se uso el
endpoint operativo `pricing-auth-monitoring-v46/blue`, manteniendo el deployment `blue`
y el pipeline component `pricing_mlops_auth_monitoring_pipeline:0.1.18`.

## Decisiones Bloqueadas

- GitHub destino: mismos repos actuales, no repos nuevos.
- Ambiente objetivo: `validation`.
- Limpieza: conservadora.
- No borrar recursos ni variables legacy de Tecmx.
- No versionar datos reales en git.
- Endpoint operativo validation para esta cuenta: `pricing-auth-monitoring-v46/blue`.
- Si `pricing46mlops@outlook.com` no tiene subscription activa, detener el goal despues
  del preflight de Azure y pedir activar una subscription.

## Alcance

Incluido:

- Preparar `validation` como ambiente operativo Azure ML en `pricing-mlops-platform`.
- Configurar OIDC y variables GitHub environment `validation` en ambos repos.
- Registrar componentes, pipeline component y endpoint desde `pricing-mlops`.
- Subir inputs masked a Storage de la nueva cuenta.
- Invocar el batch endpoint y esperar `Completed`.
- Verificar artefactos en `runs`, `snapshots`, `drift-logs`, `reports` y `artifacts`.
- Documentar conteos, run id, job name, workspace, storage y diferencias conocidas contra Notebook 4.

Fuera de alcance:

- Crear repos nuevos.
- Crear ambiente `prod`.
- Borrar recursos de la subscription Tecmx.
- Migrar historico completo de Storage.
- Hacer paridad fina con Notebook 4.

## Preflight Azure

Ejecutar localmente:

```bash
az logout
az login --use-device-code
az account list --query "[].{name:name,id:id,tenantId:tenantId,user:user.name,state:state,isDefault:isDefault}" -o table
```

Validar que aparezca una subscription activa asociada a `pricing46mlops@outlook.com`.

Si no aparece una subscription `Enabled`, detener el goal y pedir activar o crear una
subscription Azure para `pricing46mlops@outlook.com`.

Si aparece una subscription activa:

```bash
az account set --subscription "<new-subscription-id-or-name>"
az account show --query "{name:name,id:id,tenantId:tenantId,user:user.name}" -o json
```

Exportar:

```bash
export AZURE_LOCATION=eastus2
export AZURE_SUBSCRIPTION_NAME="<new-subscription-name>"
export AZURE_SUBSCRIPTION_ID="<new-subscription-id>"
export AZURE_TENANT_ID="<new-tenant-id>"
```

## Platform Deployment

Repo:

```bash
cd /Users/me/Developer/tecmx-team46-pricing/pricing-mlops-platform
```

Validar IaC:

```bash
az bicep build --file infra/foundation/main.bicep
az bicep build --file infra/workloads/pricing-mlops/main.bicep
az bicep build-params --file infra/parameters/validation.bicepparam
```

Ejecutar what-if:

```bash
scripts/what-if.sh validation
```

Si el what-if solo crea/actualiza recursos esperados para `validation`, desplegar:

```bash
scripts/deploy.sh validation
```

Extraer outputs recientes:

```bash
FOUNDATION_DEPLOYMENT="$(az deployment sub list --query "sort_by([?starts_with(name, 'pricing-mlops-foundation-validation-')], &properties.timestamp)[-1].name" -o tsv)"
WORKLOAD_DEPLOYMENT="$(az deployment sub list --query "sort_by([?starts_with(name, 'pricing-mlops-workload-validation-')], &properties.timestamp)[-1].name" -o tsv)"

az deployment sub show --name "${FOUNDATION_DEPLOYMENT}" --query properties.outputs -o json
az deployment sub show --name "${WORKLOAD_DEPLOYMENT}" --query properties.outputs -o json
```

Valores esperados para GitHub/model repo:

```text
AZURE_CLIENT_ID                  = foundation.outputs.githubActionsClientId for platform repo
AZURE_TENANT_ID                  = az account show tenantId
AZURE_SUBSCRIPTION_ID            = az account show id
AZURE_RESOURCE_GROUP             = workload.outputs.workloadResourceGroupName
AZURE_STORAGE_ACCOUNT            = workload.outputs.storageAccountName
AZURE_STORAGE_DFS_ENDPOINT       = workload.outputs.storageDfsEndpoint
AZURE_ML_WORKSPACE               = workload.outputs.azureMlWorkspaceName
AZURE_ML_JOB_IDENTITY_CLIENT_ID  = workload.outputs.azureMlJobIdentityClientId
AZURE_ML_BATCH_ENDPOINT          = pricing-auth-monitoring-v46
MODEL_AZURE_CLIENT_ID            = foundation.outputs.modelGithubActionsClientId
```

Valores reales 2026-06-21:

```text
AZURE_SUBSCRIPTION_ID            = f6112ad6-1b90-49e6-bde2-afd043668808
AZURE_TENANT_ID                  = 088c80da-a185-48a2-9387-1a2088e0cc7b
AZURE_RESOURCE_GROUP             = rg-pricing-mlops-validation
AZURE_STORAGE_ACCOUNT            = stpmlopsugiklytqusfr2
AZURE_STORAGE_DFS_ENDPOINT       = https://stpmlopsugiklytqusfr2.dfs.core.windows.net
AZURE_ML_WORKSPACE               = mlw-pricing-mlops-val-v2-ugikly
AZURE_ML_JOB_IDENTITY_CLIENT_ID  = 761830c9-385d-47a7-b708-17139f2cb8c6
AZURE_ML_BATCH_ENDPOINT          = pricing-auth-monitoring-v46
AZURE_ML_COMPUTE                 = cpu-cluster
PLATFORM_AZURE_CLIENT_ID         = f68065d0-79b3-4bd5-84b7-41c402beacae
MODEL_AZURE_CLIENT_ID            = 2e2a6871-ce87-4cb6-af02-2d41d8a31026
```

## GitHub Environment Variables

Confirmar environments:

```bash
gh api -X PUT repos/tecmx-team46-pricing/pricing-mlops-platform/environments/validation
gh api -X PUT repos/tecmx-team46-pricing/pricing-mlops/environments/validation
```

Configurar `pricing-mlops-platform`:

```bash
gh variable set AZURE_CLIENT_ID --env validation --repo tecmx-team46-pricing/pricing-mlops-platform --body "<platform-github-actions-client-id>"
gh variable set AZURE_TENANT_ID --env validation --repo tecmx-team46-pricing/pricing-mlops-platform --body "${AZURE_TENANT_ID}"
gh variable set AZURE_SUBSCRIPTION_ID --env validation --repo tecmx-team46-pricing/pricing-mlops-platform --body "${AZURE_SUBSCRIPTION_ID}"
gh variable set AZURE_STORAGE_ACCOUNT --env validation --repo tecmx-team46-pricing/pricing-mlops-platform --body "<validation-storage-account>"
```

Configurar `pricing-mlops`:

```bash
gh variable set AZURE_CLIENT_ID --env validation --repo tecmx-team46-pricing/pricing-mlops --body "<model-github-actions-client-id>"
gh variable set AZURE_TENANT_ID --env validation --repo tecmx-team46-pricing/pricing-mlops --body "${AZURE_TENANT_ID}"
gh variable set AZURE_SUBSCRIPTION_ID --env validation --repo tecmx-team46-pricing/pricing-mlops --body "${AZURE_SUBSCRIPTION_ID}"
gh variable set AZURE_RESOURCE_GROUP --env validation --repo tecmx-team46-pricing/pricing-mlops --body "<validation-resource-group>"
gh variable set AZURE_ML_WORKSPACE --env validation --repo tecmx-team46-pricing/pricing-mlops --body "<validation-azure-ml-workspace>"
gh variable set AZURE_STORAGE_ACCOUNT --env validation --repo tecmx-team46-pricing/pricing-mlops --body "<validation-storage-account>"
gh variable set AZURE_STORAGE_DFS_ENDPOINT --env validation --repo tecmx-team46-pricing/pricing-mlops --body "https://<validation-storage-account>.dfs.core.windows.net"
gh variable set AZURE_ML_JOB_IDENTITY_CLIENT_ID --env validation --repo tecmx-team46-pricing/pricing-mlops --body "<validation-aml-job-identity-client-id>"
gh variable set AZURE_ML_BATCH_ENDPOINT --env validation --repo tecmx-team46-pricing/pricing-mlops --body "pricing-auth-monitoring-v46"
```

Verificar:

```bash
gh variable list --env validation -R tecmx-team46-pricing/pricing-mlops-platform
gh variable list --env validation -R tecmx-team46-pricing/pricing-mlops
```

## Model Repo Azure ML Deployment

Repo:

```bash
cd /Users/me/Developer/tecmx-team46-pricing/pricing-mlops
```

Validar local:

```bash
python -m compileall src scripts tests
python -m pytest
```

Registrar assets en Azure ML validation:

```bash
AZURE_SUBSCRIPTION_ID="${AZURE_SUBSCRIPTION_ID}" \
AZURE_RESOURCE_GROUP="<validation-resource-group>" \
AZURE_ML_WORKSPACE="<validation-azure-ml-workspace>" \
python scripts/azureml/register_assets.py --config configs/azureml_auth_monitoring.yml
```

Desplegar endpoint:

```bash
AZURE_SUBSCRIPTION_ID="${AZURE_SUBSCRIPTION_ID}" \
AZURE_RESOURCE_GROUP="<validation-resource-group>" \
AZURE_ML_WORKSPACE="<validation-azure-ml-workspace>" \
AZURE_ML_BATCH_ENDPOINT="pricing-auth-monitoring-v46" \
python scripts/azureml/deploy_endpoint.py --config configs/azureml_auth_monitoring.yml
```

Confirmar endpoint:

```bash
az ml batch-endpoint show \
  --resource-group "<validation-resource-group>" \
  --workspace-name "<validation-azure-ml-workspace>" \
  --name pricing-auth-monitoring-v46 \
  --query "{name:name,auth_mode:auth_mode,provisioning_state:provisioning_state}" \
  -o json
```

Infra fixes aplicados durante ejecucion:

- `validation.bicepparam` habilita Azure ML v2, OIDC model repo y ACR asociado.
- Bicep crea `cpu-cluster` como `AmlCompute` `STANDARD_DS2_V2`, autoscale `0..1`.
- `cpu-cluster` usa la user-assigned identity `id-pricing-mlops-aml-validation`.
- La identidad AML tiene `Storage Blob Data Contributor` en Storage funcional y runtime.
- La identidad AML tiene `Reader` y `Key Vault Secrets Officer` sobre el Key Vault compartido.

## Inputs Y Corrida End To End

Subir inputs masked al Storage nuevo. Usar nombres sin espacios ni parentesis:

```bash
az storage blob upload \
  --account-name "<validation-storage-account>" \
  --auth-mode login \
  --container-name baseline \
  --name auth-monitoring/input6mothback/masked_output_recommendations_2.csv \
  --file "data/inbox/input6mothback/masked_output_recommendations (2).csv" \
  --overwrite true

az storage blob upload \
  --account-name "<validation-storage-account>" \
  --auth-mode login \
  --container-name raw-masked \
  --name auth-monitoring/input-avance4-current/masked_current_auth_dataset.csv \
  --file data/inbox/input_avance4_current/masked_current_auth_dataset.csv \
  --overwrite true
```

Invocar endpoint:

```bash
RUN_ID="$(date -u +%Y%m%dT%H%M%SZ)-validation-pricing46"

AZURE_RESOURCE_GROUP="<validation-resource-group>" \
AZURE_ML_WORKSPACE="<validation-azure-ml-workspace>" \
AZURE_STORAGE_ACCOUNT="<validation-storage-account>" \
AZURE_ML_JOB_IDENTITY_CLIENT_ID="<validation-aml-job-identity-client-id>" \
AZURE_ML_BATCH_ENDPOINT=pricing-auth-monitoring-v46 \
AZURE_ML_WAIT_FOR_COMPLETION=true \
AZURE_ML_WAIT_TIMEOUT_SECONDS=7200 \
AZURE_ML_WAIT_INTERVAL_SECONDS=30 \
MLOPS_ENVIRONMENT=validation \
MLOPS_RUN_OWNER=team46 \
MLOPS_RUN_ID="${RUN_ID}" \
MLOPS_BASELINE_SNAPSHOT_CONTAINER=baseline \
MLOPS_BASELINE_SNAPSHOT_BLOB_PATH=auth-monitoring/input6mothback/masked_output_recommendations_2.csv \
MLOPS_INPUT_BLOB_PATH=auth-monitoring/input-avance4-current/masked_current_auth_dataset.csv \
MLOPS_CURRENT_HISTORY_CONTAINER=raw-masked \
MLOPS_CURRENT_AUTH_HISTORY_BLOB_PATH=auth-monitoring/input-avance4-current/masked_current_auth_dataset.csv \
MODEL_REPO_REF=feature/lift-validation-pricing46-account \
MODEL_REPO_COMMIT_SHA="$(git rev-parse --short HEAD)" \
scripts/invoke_auth_monitoring_batch_endpoint.sh
```

## Verificacion De Artefactos

Esperado:

```text
azure_ml_job_status=Completed
expected_output_prefix=environment=validation/compute=azure-ml/trigger=batch-endpoint/owner=team46/run_date=<yyyymmdd>/run_id=<run_id>
```

Listar artefactos:

```bash
PREFIX="environment=validation/compute=azure-ml/trigger=batch-endpoint/owner=team46/run_date=${RUN_ID:0:8}/run_id=${RUN_ID}"

for container in runs snapshots drift-logs reports artifacts; do
  az storage blob list \
    --account-name "<validation-storage-account>" \
    --auth-mode login \
    --container-name "${container}" \
    --prefix "${PREFIX}" \
    --query "length(@)" \
    -o tsv
done
```

Descargar summaries:

```bash
mkdir -p /tmp/pricing46-validation

az storage blob download \
  --account-name "<validation-storage-account>" \
  --auth-mode login \
  --container-name runs \
  --name "${PREFIX}/summaries/run_readiness_summary.csv" \
  --file /tmp/pricing46-validation/run_readiness_summary.csv \
  --overwrite true

az storage blob download \
  --account-name "<validation-storage-account>" \
  --auth-mode login \
  --container-name runs \
  --name "${PREFIX}/summaries/operational_decision_summary.csv" \
  --file /tmp/pricing46-validation/operational_decision_summary.csv \
  --overwrite true
```

Validar:

```bash
python - <<'PY'
import csv
from pathlib import Path

base = Path("/tmp/pricing46-validation")
for name in ("run_readiness_summary.csv", "operational_decision_summary.csv"):
    rows = list(csv.DictReader((base / name).open(newline="", encoding="utf-8-sig")))
    print(name, rows[0] if rows else {})
PY
```

## Criterios De Aceptacion

- `validation` desplegado por Bicep en la subscription de `pricing46mlops@outlook.com`.
- GitHub environments `validation` existen en ambos repos.
- Variables OIDC/Azure configuradas sin secretos en ambos repos.
- Azure ML workspace existe y tiene compute `cpu-cluster`, environment, componentes, pipeline component y endpoint.
- `pricing-auth-monitoring-v46/blue` corre con `AZURE_ML_WAIT_FOR_COMPLETION=true`.
- Job Azure ML termina `Completed`.
- Hay blobs publicados en `runs`, `snapshots`, `drift-logs`, `reports` y `artifacts`.
- `run_readiness_summary.csv` contiene `run_readiness_status`.
- `operational_decision_summary.csv` contiene `recommended_operational_action`.
- El reporte final incluye:
  - `azure_ml_job_name`
  - `run_id`
  - `expected_output_prefix`
  - Storage account
  - Azure ML workspace
  - endpoint link
  - conteos principales
  - diferencias conocidas contra Notebook 4

## Rollback Y No Borrado

- No borrar recursos Tecmx.
- Si el deploy falla antes de publicar datos, dejar recursos `validation` para inspeccion salvo que el usuario pida borrarlos.
- Si se requiere limpiar la cuenta nueva, hacerlo solo con aprobacion explicita y sobre resource groups `rg-pricing-mlops-validation` y `rg-pricing-mlops-platform-shared`.
- No ejecutar `az group delete` ni `az deployment sub delete` como parte automatica del goal.

## Diferencia Contra Notebook 4

Esta migracion valida operacion end-to-end, no paridad exacta 1:1 con Notebook 4. El pipeline Azure ML usa el snapshot simplificado generado por componentes; Notebook 4 puede usar un snapshot preparado mas rico. Diferencias moderadas de semaforo o metricas son aceptables si los conteos principales y artefactos existen.

## Resultado De Corrida 2026-06-21

```text
azure_ml_job_name=pipelinejob-90d52dc8-487b-46a6-aea7-93e1a8d403a6
run_id=20260621T214242Z-validation-pricing46
status=Completed
endpoint=pricing-auth-monitoring-v46/blue
workspace=mlw-pricing-mlops-val-v2-ugikly
storage_account=stpmlopsugiklytqusfr2
expected_output_prefix=environment=validation/compute=azure-ml/trigger=batch-endpoint/owner=team46/run_date=20260621/run_id=20260621T214242Z-validation-pricing46
studio_url=https://ml.azure.com/runs/pipelinejob-90d52dc8-487b-46a6-aea7-93e1a8d403a6?wsid=/subscriptions/f6112ad6-1b90-49e6-bde2-afd043668808/resourcegroups/rg-pricing-mlops-validation/workspaces/mlw-pricing-mlops-val-v2-ugikly&tid=088c80da-a185-48a2-9387-1a2088e0cc7b
```

Conteos principales:

```text
baseline_recommendation_snapshot_rows=8314
current_auth_history_snapshot_real_rows=10068
new_combo_without_baseline_recommendation_rows=1754
artifact_manifest_count=15
```

Resumen operacional:

```text
run_readiness_status=Red
recommended_operational_action=REVIEW_RED_YELLOW_CASES_AND_RUN_RECOMMENDATION_REFRESH
recommendation_validity_global_status=Red
auth_history_drift_status=Yellow
price_drift_status=Yellow
recommendation_coverage_status=Green
catalog_bin_coverage_status=Green
```
