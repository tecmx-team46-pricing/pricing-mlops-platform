# Platform-Model Operating Contract

## Responsabilidades

| Repo | Responsabilidad |
|---|---|
| `pricing-mlops-platform` | Infraestructura, identidades, RBAC, Storage, Azure ML, Function App, runtime MLOps, pipeline/job YAML y runbooks. |
| `pricing-mlops` | Repo funcional/data science: validacion, curated/features, scoring, drift, reportes y artefactos. |

`pricing-mlops` no crea infraestructura ni contiene el runtime de Azure Functions/Event Grid. Ese repo registra los componentes funcionales de Azure ML; plataforma los referencia desde el pipeline/job AML.

## Variables Publicadas Por Plataforma

```text
AZURE_SUBSCRIPTION_ID
AZURE_TENANT_ID
AZURE_RESOURCE_GROUP
AZURE_STORAGE_ACCOUNT
AZURE_STORAGE_DFS_ENDPOINT
AZURE_ML_WORKSPACE
AZURE_FUNCTION_APP
AZURE_CLIENT_ID
MLOPS_ENVIRONMENT
MLOPS_RUN_OWNER
MLOPS_COMPUTE_TARGET=azure-ml
MLOPS_CONTAINER_RAW_MASKED=raw-masked
MLOPS_CONTAINER_CURATED=curated
MLOPS_CONTAINER_RUNS=runs
MLOPS_CONTAINER_SNAPSHOTS=snapshots
MLOPS_CONTAINER_DRIFT_LOGS=drift-logs
MLOPS_CONTAINER_REPORTS=reports
MLOPS_CONTAINER_ARTIFACTS=artifacts
MLOPS_ALLOWED_EVENT_CONTAINER=raw-masked
MLOPS_ALLOWED_EVENT_PREFIX=incoming/
MLOPS_DEFAULT_OWNER=team46
MLOPS_RUN_INDEX_TABLE=mlopsruns
MLOPS_ARTIFACT_SINKS=azure_blob,sql_metadata
MLOPS_OPTIONAL_ARTIFACT_SINKS=azure_ml
MLOPS_SQL_ENABLED=true
MLOPS_SQL_SERVER=sql-pricing-mlops-staging-<suffix>.database.windows.net
MLOPS_SQL_DATABASE=pricing_mlops_audit
MLOPS_SQL_SCHEMA=dbo
MLOPS_SQL_RUN_LOG_TABLE=model_run_log
MLOPS_SQL_SNAPSHOT_TABLE=model_output_snapshot_metadata
MODEL_REPO_GITHUB=tecmx-team46-pricing/pricing-mlops
MODEL_REPO_REF=<commit-sha|tag|branch>
```

No se publican account keys, connection strings ni secretos.

`AZURE_STORAGE_ACCOUNT` apunta al Storage MLOps principal, no al Storage runtime interno de Azure ML ni al Storage host de Function.

En `staging`, `AZURE_ML_WORKSPACE` apunta al workspace activo `mlw-pricing-mlops-stg-v2-<suffix>`. El workspace legacy `mlw-pricing-mlops-staging-<suffix>` no es la ruta operativa normal.

## Input Compartido

```text
raw-masked/samples/sample_pricing_v1.csv
```

`raw-unmasked` no es input del repo modelo y no existe en `staging`.

## Orquestacion

```text
mlops/scripts/run_model_flow_function.sh
-> POST /api/model-flow
-> Azure ML pipeline job
-> componentes registrados `pricing_mlops_*`
-> Storage outputs
```

`MODEL_REPO_REF` se resuelve en publish/build time desde GitHub y queda registrado en `model_source.json`; Azure ML recibe esa metadata y ejecuta componentes registrados, no un clone vivo de GitHub. Para reproducibilidad, usar commit SHA o tag. `MODEL_REPO_PATH` es solo fallback local/dev con `ALLOW_LOCAL_MODEL_SOURCE=true`; no es la ruta normal para `staging` ni `validation`.

El flujo automatico es:

```text
raw-masked/incoming/*.csv BlobCreated
-> Event Grid
-> Function trigger model-flow-blob-created
-> Azure ML pipeline job
-> Storage outputs
-> Table mlopsruns o JSON fallback en runs
```

La Function devuelve `azure_ml_job_name`, `run_id`, `correlation_id` y `expected_output_prefix`.

## Metadata SQL

Azure SQL audit es un sink de metadata. El componente `publish_outputs` escribe:

| Tabla | Contenido |
|---|---|
| `dbo.model_run_log` | Run id, ambiente, owner, status, row count, drift, input, modelo/ref/commit y manifest URI. |
| `dbo.model_output_snapshot_metadata` | Run id, snapshot URI, row count, drift y version de schema. |
| `dbo.data_quality_log` | Reservada para checks de calidad por run. |

Los CSVs, reportes y JSON funcionales siguen viviendo en Blob Storage. SQL usa Microsoft Entra auth desde la identidad administrada del job AML.

## Layout De Outputs

```text
<container>/environment=<env>/compute=azure-ml/trigger=<manual|event-grid>/owner=<owner>/run_date=<yyyymmdd>/run_id=<run_id>/<artifact>
```

Artefactos esperados:

| Container | Archivo |
|---|---|
| `runs` | `model_run_log.json` |
| `runs` | `summaries/operational_decision_summary.csv` |
| `snapshots` | `snapshots/baseline_recommendation_snapshot.csv` |
| `snapshots` | `snapshots/current_auth_history_snapshot_real.csv` |
| `drift-logs` | `logs/auth_recommendation_validity_log.csv` |
| `drift-logs` | `logs/auth_history_drift_log.csv` |
| `reports` | `reports/auth_recommendation_validity_report.md` |
| `artifacts` | `manifest/artifact_manifest.json` |

Azure ML puede generar snapshots de codigo, logs, environments y artifacts runtime fuera de este layout. Esos artifacts internos no son outputs funcionales del modelo y no forman parte del contrato entre plataforma y repo modelo.

## Limites

- GitHub Actions no es orquestador operativo.
- Si la Function esta bloqueada, abrir una tarea explicita antes de reintroducir un fallback directo a AML.
- Sandboxes personales no son ambientes de GitHub Actions.
- `prod` no existe.
- Los datos MLOps no usan account keys ni connection strings. Cualquier excepcion tecnica que Azure ML requiera para runtime interno debe limitarse al Storage runtime Azure ML.
