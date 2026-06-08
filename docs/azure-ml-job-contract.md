# Azure ML Pipeline/Job Contract

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

El pipeline activo muestra tres nodos:

| Nodo | Responsabilidad |
|---|---|
| `validate_prepare` | Lee input masked, valida y prepara datos intermedios. |
| `score_evaluate` | Ejecuta scoring controlado, evaluacion y drift basico. |
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
