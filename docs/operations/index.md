# Operations

## Preflight

```bash
az login
az account set --subscription "<azure-subscription-name>"
az account show --query "{name:name,id:id}" -o table
```

## Validacion Local

```bash
scripts/validate-mlops-contracts.py
az bicep build --file infra/foundation/main.bicep
az bicep build --file infra/workloads/pricing-mlops/main.bicep
az bicep build-params --file infra/parameters/staging.bicepparam
az bicep build-params --file infra/parameters/validation.bicepparam
az bicep build-params --file infra/parameters/data-lab.bicepparam
az bicep build-params --file infra/parameters/sandbox-local.bicepparam
```

## What-if y Deploy

```bash
scripts/what-if.sh staging
scripts/deploy.sh staging
```

Ambientes aceptados por scripts:

```text
staging
validation
data-lab
sandbox-local
```

`sandbox-local` es local/admin only. GitHub Actions solo expone `staging` y `validation` para operacion manual.

## Operacion Del Flujo ML

La operacion diaria del flujo vive en este repo bajo `mlops/scripts/`. El repo `pricing-mlops` contiene el codigo data science y registra los componentes funcionales que Azure ML ejecuta.

Publicar o actualizar el codigo de la Function:

```bash
MODEL_REPO_REF=<commit-sha-or-tag> \
mlops/scripts/publish_orchestrator_function.sh staging
```

Dry-run sin desplegar a Azure:

```bash
DRY_RUN=true KEEP_PACKAGE=true \
MODEL_REPO_REF=<commit-sha-or-tag> \
mlops/scripts/publish_orchestrator_function.sh staging
```

`MODEL_REPO_REF` se resuelve desde `MODEL_REPO_GITHUB` en build/publish time y el commit real queda escrito en `model_source.json`. Para desarrollo local se permite `MODEL_REPO_PATH=../pricing-mlops` solo con `ALLOW_LOCAL_MODEL_SOURCE=true`; si ese repo local tiene cambios sin commit, el script falla salvo que se use `ALLOW_DIRTY_LOCAL_MODEL_SOURCE=true` para una prueba local deliberada. Esa metadata se inyecta al job; la ejecucion funcional usa los componentes Azure ML registrados.

Ejecutar el flujo remoto:

```bash
AZURE_FUNCTION_APP=func-pricing-mlops-staging-<suffix> \
AZURE_RESOURCE_GROUP=rg-pricing-mlops-staging \
AZURE_ML_WORKSPACE=mlw-pricing-mlops-stg-v2-<suffix> \
mlops/scripts/run_model_flow_function.sh staging team46 samples/sample_pricing_v1.csv
```

Ese script llama la Function, espera el job AML por ARM/REST y verifica metadata de los outputs. No usa GitHub Actions ni `az ml`. En Azure ML > Jobs, el pipeline debe mostrar los nodos `validate_prepare`, `build_monitoring_inputs`, `calculate_recommendation_validity`, `calculate_auth_history_drift`, `calculate_operational_decision` y `publish_outputs`.

## Operacion AUTH Monitoring

La ruta operativa no corre notebooks completos. Usa componentes Azure ML registrados desde `pricing-mlops` y deja el notebook como referencia metodologica.

Este repo de plataforma conserva el template `mlops/azureml/pricing-mlops-pipeline.yml`, la Function y `publish_outputs`; el registro de componentes `pricing_mlops_*` ocurre en el repo funcional.

Preflight con blobs requeridos:

```bash
MLOPS_BASELINE_SNAPSHOT_BLOB_PATH=<baseline-snapshot.csv> \
MLOPS_CURRENT_AUTH_HISTORY_BLOB_PATH=<current-auth-history.csv> \
mlops/scripts/preflight_pipeline_e2e.sh staging
```

Ejecutar por Function:

```bash
MLOPS_BASELINE_SNAPSHOT_BLOB_PATH=<baseline-snapshot.csv> \
MLOPS_CURRENT_AUTH_HISTORY_BLOB_PATH=<current-auth-history.csv> \
mlops/scripts/run_model_flow_function.sh staging team46 <current-auth-history.csv>
```

El contrato de nodos, inputs y outputs esta en [Pipeline Azure ML](../reference/azure-ml-pipeline.md).

El trigger automatico se habilita por Event Grid sobre `raw-masked/incoming/*.csv`. Para probarlo:

```bash
timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
az storage blob upload \
  --account-name <mlops-storage-account> \
  --container-name raw-masked \
  --name "incoming/pricing_test_${timestamp}.csv" \
  --file ../pricing-mlops/data/samples/masked/sample_pricing.csv \
  --auth-mode login \
  --overwrite true
```

La Function rechaza eventos fuera de `raw-masked/incoming/`, `samples/`, paths absolutos, `..`, extensiones distintas de `.csv` y cualquier referencia a `raw-unmasked`.

## Portal

| Necesidad | Ruta |
|---|---|
| Function | Function App `func-pricing-mlops-staging-<suffix>` > Functions / Log stream |
| Azure ML jobs | Machine Learning workspace `mlw-pricing-mlops-stg-v2-<suffix>` > Jobs |
| Outputs funcionales | Storage MLOps `<mlops-storage-account>` > Containers |
| SQL audit | SQL server `sql-pricing-mlops-staging-<suffix>` > SQL databases > `pricing_mlops_audit` > Query editor (preview) |
| Artifacts runtime AML | Storage runtime Azure ML `stamlpmlopsstg<suffix>` para el workspace v2 activo; el workspace legacy conserva artifacts anteriores en `<mlops-storage-account>` |
| Function host state | Storage `stfn<generated-suffix>` |
| Costos | Cost Management > Cost analysis > filtrar `rg-pricing-mlops-staging` |
| RBAC | Resource > Access control (IAM) |

## SQL Audit

Runbook completo: [Auditoria SQL](sql-audit.md).

Conexion local con Microsoft Entra:

```bash
sqlcmd \
  -S sql-pricing-mlops-staging-<suffix>.database.windows.net \
  -d pricing_mlops_audit \
  -G
```

Consulta rapida:

```sql
select top 10
  run_id,
  environment,
  status,
  row_count,
  trigger_type,
  model_commit_sha
from dbo.model_run_log
order by started_at_utc desc;
```

SQL guarda metadata y referencias. Los artifacts funcionales siguen en Blob Storage.

## Seguridad Actual

- Storage MLOps principal tiene account keys deshabilitadas.
- Storage runtime Azure ML prefiere identity-based access; si Azure ML exige shared keys en una recreacion futura, esa excepcion debe quedar limitada al Storage runtime, nunca al Storage MLOps principal.
- Function usa Function key como control temporal.
- Function App usa HTTPS-only, TLS minimo 1.2, FTPS disabled, remote debugging off y detailed errors off.
- No se versionan secrets, account keys ni connection strings.
- `raw-unmasked` no existe en `staging`.

Pendiente: migrar el endpoint a Entra ID/Easy Auth o API Management si el equipo aprueba ese modelo.

## Limpieza De Recursos Legacy

El inventario activo esta en [Inventario legacy](legacy-resources.md). No borrar recursos Azure legacy sin aprobacion explicita.

La ruta Container Apps/ACR del PoC anterior no forma parte del IaC activo. En `staging`, los recursos legacy ya fueron eliminados:

- `job-pricing-mlops-staging`
- `cae-pricing-mlops-staging`
- `acr-pricing-mlops-legacy-<suffix>`
- `id-pricing-mlops-job-staging-legacy-legacy`

Si reaparecen en otro ambiente, borrarlos solo despues de confirmar que Function + AML + Storage siguen operando.

Orden seguro:

```bash
az containerapp job delete --resource-group rg-pricing-mlops-staging --name job-pricing-mlops-staging --yes
az containerapp env delete --resource-group rg-pricing-mlops-staging --name cae-pricing-mlops-staging --yes
az acr delete --resource-group rg-pricing-mlops-staging --name acr-pricing-mlops-legacy-<suffix> --yes
az identity delete --resource-group rg-pricing-mlops-staging --name id-pricing-mlops-job-staging-legacy-legacy
```

No borrar ``; es el ACR asociado al runtime de Azure ML, no el ACR legacy de Container Apps.

## Retencion Recomendada

No borrar containers internos actuales de Azure ML automaticamente. Primero clasificar:

| Clase | Ejemplos | Retencion recomendada |
|---|---|---|
| Inputs masked | `raw-masked` | Conservacion explicita por dataset aprobado. |
| Outputs funcionales | `runs`, `snapshots`, `drift-logs`, `reports`, `artifacts`, `curated` | Conservar ultimos N runs o ultimos X dias segun necesidad academica/operativa. |
| AML runtime artifacts | `azureml`, `azureml-environments`, `azureml-blobstore-*`, `snapshotzips`, `revisions`, `aml-environment-image-build` | Conservar X dias despues de confirmar que ningun job activo depende de ellos. |
| Logs diagnosticos | `insights-logs-*`, `insights-metrics-*` | Conservar X dias para troubleshooting y costo bajo. |

Despues del cutover a workspace v2, los containers AML internos que quedaron en `<mlops-storage-account>` son candidatos a limpieza futura solo con aprobacion explicita. Mantenerlos mientras el workspace legacy exista o pueda usarse para rollback.

## Clasificacion Actual De Containers

En `<mlops-storage-account>`, conservar como funcionales MLOps:

```text
raw-masked
curated
baseline
runs
snapshots
drift-logs
reports
artifacts
```

`input` queda como container reservado/historico de IaC; revisarlo antes de cualquier borrado.

En `<mlops-storage-account>`, no borrar mientras exista el workspace legacy:

```text
<legacy-workspace-guid>-*
aml-environment-image-build
azureml
azureml-blobstore-<legacy-workspace-guid>
azureml-environments
revisions
snapshotzips
```

Logs diagnosticos en `<mlops-storage-account>`, candidatos a lifecycle despues de acordar retencion:

```text
insights-logs-auditevent
insights-metrics-pt1m
```

En `stamlpmlopsstg<suffix>`, los containers AML runtime esperados para el workspace v2 activo incluyen:

```text
azureml
azureml-blobstore-<active-workspace-guid>
<active-workspace-guid>-*
revisions
snapshots
snapshotzips
```

Propuesta de lifecycle pendiente de aprobacion:

| Clase | Accion propuesta |
|---|---|
| `raw-masked` | Conservar explicitamente por dataset aprobado. |
| Outputs funcionales | Conservar ultimos N runs o X dias, segun necesidad academica/operativa. |
| AML runtime artifacts en `stamlpmlopsstg<suffix>` | Retener X dias despues de confirmar que ningun job activo depende de ellos. |
| AML legacy en `<mlops-storage-account>` | Retener hasta retirar workspace legacy y pedir aprobacion explicita de borrado. |
| Logs diagnosticos | Retener X dias para troubleshooting de bajo costo. |
