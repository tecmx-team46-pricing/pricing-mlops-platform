# Pipeline Azure ML

Esta pagina describe el contrato entre la Function y Azure ML. La Function inyecta parametros de corrida; Azure ML ejecuta componentes registrados y publica outputs bajo una convencion auditable.

## Ruta Activa

La ruta preferida del flujo esta definida en:

```text
mlops/azureml/pricing-mlops-pipeline.yml
```

## Pipeline

El pipeline activo muestra los pasos derivados del notebook de monitoreo AUTH:

| Nodo | Responsabilidad |
|---|---|
| `validate_prepare` | Lee input masked, valida y prepara datos intermedios. |
| `build_monitoring_inputs` | Prepara snapshots normalizados para monitoreo. |
| `calculate_recommendation_validity` | Calcula validez de recomendacion. |
| `calculate_auth_history_drift` | Calcula drift AUTH history contra baseline. |
| `calculate_operational_decision` | Genera semaforo operacional y manifest final. |
| `publish_outputs` | Publica outputs funcionales al Storage MLOps. |

Los pasos funcionales usan componentes Azure ML registrados desde el repo `pricing-mlops`; este repo solo referencia esos assets desde `mlops/azureml/pricing-mlops-pipeline.yml`. La version activa en el template es `0.1.2` para los componentes `pricing_mlops_*`.

`publish_outputs` sigue siendo componente inline de plataforma porque publica a Storage MLOps, tags/metadata y SQL audit sin recalcular metricas.

## Version Del Repo Funcional

Durante el publish de la Function, plataforma resuelve `MODEL_REPO_GITHUB` + `MODEL_REPO_REF` y escribe:

```text
model_source.json
```

Ese archivo registra `model_source`, `model_repo`, `model_ref` y `model_commit_sha`. Para operacion reproducible, usar un commit SHA o tag en `MODEL_REPO_REF`; un branch puede moverse despues. La Function no clona GitHub por evento.

## Inputs Inyectados Por La Function

```text
storage_account
environment
run_owner
run_id
input_blob_path
trigger_type
model_repo
model_ref
model_commit_sha
monitoring_config_version
```

`monitoring_config_version` corresponde a `mlops/configs/drift_thresholds.json`; `publish_outputs` registra esa version y el SHA-256 del archivo en `model_run_log.json`.

## Outputs Funcionales

Los outputs finales se publican con esta convencion:

```text
<container>/environment=<env>/compute=azure-ml/trigger=<manual|event-grid>/owner=<owner>/run_date=<yyyymmdd>/run_id=<run_id>/<artifact>
```

## Referencia Operativa

La fuente tecnica viva se mantiene en:

```text
mlops/docs/azure-ml-job-contract.md
```

Siguiente lectura recomendada: [Contratos de datos](data-contracts.md), para entender que evidencia debe producir cada corrida.
