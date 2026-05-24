# Platform-Model Operating Contract

## Responsabilidades

| Repo | Responsabilidad |
|---|---|
| `pricing-mlops-platform` | Infraestructura, identidades, RBAC, Storage, Azure ML, Function y runbooks. |
| `pricing-mlops` | Validacion, curated/features, scoring, drift, reportes y artefactos. |

`pricing-mlops` no crea infraestructura.

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
```

No se publican account keys, connection strings ni secretos.

`AZURE_STORAGE_ACCOUNT` apunta al Storage MLOps principal, no al Storage runtime interno de Azure ML ni al Storage host de Function.

## Input Compartido

```text
raw-masked/samples/sample_pricing_v1.csv
```

`raw-unmasked` no es input del repo modelo y no existe en `staging`.

## Orquestacion

```text
scripts/run_model_flow_function.sh
-> POST /api/model-flow
-> Azure ML command job
-> Storage outputs
```

La Function devuelve `azure_ml_job_name`, `run_id`, `correlation_id` y `expected_output_prefix`.

## Layout De Outputs

```text
<container>/environment=<env>/compute=azure-ml/owner=<owner>/run_date=<yyyymmdd>/run_id=<run_id>/<artifact>
```

Artefactos esperados:

| Container | Archivo |
|---|---|
| `runs` | `model_run_log.json` |
| `snapshots` | `model_output_snapshot.csv` |
| `drift-logs` | `model_drift_log.json` |
| `reports` | `report.md` |
| `artifacts` | `curated_pricing.csv` |
| `curated` | `curated_pricing.csv` |

Azure ML puede generar snapshots de codigo, logs, environments y artifacts runtime fuera de este layout. Esos artifacts internos no son outputs funcionales del modelo y no forman parte del contrato entre plataforma y repo modelo.

## Limites

- GitHub Actions no es orquestador operativo.
- Si la Function esta bloqueada, abrir una tarea explicita antes de reintroducir un fallback directo a AML.
- Sandboxes personales no son ambientes de GitHub Actions.
- `prod` no existe.
- Los datos MLOps no usan account keys ni connection strings. Cualquier excepcion tecnica que Azure ML requiera para runtime interno debe limitarse al Storage runtime Azure ML.
