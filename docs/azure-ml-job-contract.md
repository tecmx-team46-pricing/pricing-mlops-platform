# Pipeline Azure ML

Esta pagina describe el contrato entre la Function y Azure ML. La Function inyecta parametros de corrida; Azure ML ejecuta el snapshot funcional y publica outputs bajo una convencion auditable.

## Ruta Activa

La ruta preferida del flujo esta definida en:

```text
mlops/azureml/pricing-mlops-pipeline.yml
```

El fallback operativo queda en:

```text
mlops/azureml/pricing-mlops-job.yml
```

## Pipeline

El pipeline activo muestra los pasos derivados del notebook de monitoreo:

| Nodo | Responsabilidad |
|---|---|
| `validate_prepare` | Lee input masked, valida y prepara datos intermedios. |
| `build_monitoring_inputs` | Prepara snapshots normalizados para monitoreo. |
| `calculate_recommendation_validity` | Calcula validez de recomendacion. |
| `calculate_auth_history_drift` | Calcula drift AUTH history contra baseline. |
| `calculate_operational_decision` | Genera semaforo operacional y manifest final. |
| `publish_outputs` | Publica outputs funcionales al Storage MLOps. |

## Snapshot Del Repo Funcional

Los componentes usan:

```yaml
code: ../pricing-mlops-source
```

Esa ruta existe dentro del paquete preparado por `mlops/scripts/publish_orchestrator_function.sh`. Azure ML sube ese snapshot al someter el pipeline/job; la Function no clona GitHub cada vez que recibe un evento.

Usar un commit SHA o tag en `MODEL_REPO_REF` es la opcion mas reproducible. Un branch puede funcionar, pero puede moverse despues.

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
```

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
