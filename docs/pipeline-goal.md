# Goal Pipeline AUTH Monitoring

Este goal convierte el notebook de monitoreo AUTH en una primera infraestructura operable de pipeline, sin ejecutar el notebook completo como una caja negra. El notebook queda como referencia del analista y como evidencia metodologica; Azure ML ejecuta pasos explicitos que materializan la logica operacional.

## Estado Actual

Hay tres rutas de Azure ML:

| Ruta | Template | Uso |
|---|---|---|
| AUTH monitoring | `mlops/azureml/pricing-mlops-pipeline.yml` | Pipeline principal multi-step para validar vigencia de recomendaciones AUTH. |
| Alias notebook | `mlops/azureml/pricing-mlops-notebook-pipeline.yml` | Compatibilidad temporal con `MLOPS_JOB_TEMPLATE=notebook`. |
| Fallback command job | `mlops/azureml/pricing-mlops-job.yml` | Ruta de contingencia de un solo job para incidentes o pruebas antiguas. |

La ruta principal ya no depende del selector. El selector conserva compatibilidad con:

```text
MLOPS_JOB_TEMPLATE=notebook
```

## Steps Azure ML

El pipeline AUTH monitoring debe verse en Azure ML Studio con estos nodos:

```text
validate_prepare
-> build_monitoring_inputs
-> calculate_recommendation_validity
-> calculate_auth_history_drift
-> calculate_operational_decision
-> publish_outputs
```

Responsabilidades:

| Step | Repo | Responsabilidad |
|---|---|---|
| `validate_prepare` | `pricing-mlops` | Valida el CSV masked de entrada y produce estado preparado. |
| `build_monitoring_inputs` | `pricing-mlops` | Construye snapshots de entrada para monitoreo AUTH desde baseline y current history. |
| `calculate_recommendation_validity` | `pricing-mlops` | Evalua si las recomendaciones siguen dentro de bandas AUTH actuales. |
| `calculate_auth_history_drift` | `pricing-mlops` | Calcula drift estadistico sobre historia AUTH. |
| `calculate_operational_decision` | `pricing-mlops` | Abstrae el semaforo y la accion operacional. |
| `publish_outputs` | `pricing-mlops-platform` | Publica el arbol final a Storage MLOps. |

Los steps funcionales escriben estado intermedio bajo:

```text
artifacts/component-state/<run_id>/<step>/
```

El step de plataforma publica la evidencia funcional final en:

```text
<container>/environment=<env>/compute=azure-ml/trigger=<trigger>/owner=<owner>/run_date=<yyyymmdd>/run_id=<run_id>/
```

## Entradas Requeridas

Para AUTH monitoring se requieren dos blobs:

| Input | Variable | Default |
|---|---|---|
| Baseline recommendation snapshot | `MLOPS_BASELINE_SNAPSHOT_BLOB_PATH` | Requerido, sin default seguro. |
| Current AUTH history snapshot | `MLOPS_CURRENT_AUTH_HISTORY_BLOB_PATH` | Puede usar el input del request para pruebas, pero debe apuntar al snapshot real en operacion. |

El preflight minimo es:

```bash
MLOPS_BASELINE_SNAPSHOT_BLOB_PATH=<path-en-artifacts-o-snapshots> \
MLOPS_CURRENT_AUTH_HISTORY_BLOB_PATH=<path-en-raw-masked> \
mlops/scripts/preflight_notebook_pipeline_e2e.sh staging
```

## Frontera Entre Repos

`pricing-mlops` conserva el codigo data science, componentes y notebooks controlados. No publica directo a Azure Blob, Azure ML tags ni SQL.

`pricing-mlops-platform` conserva IaC, Function, templates Azure ML, scripts operativos y `mlops/components/platform_publish_outputs.py`.

## Plan Para Cerrar La Etapa

1. Mantener el branch `feature/avance4-pipeline-abstraction` en ambos repos hasta completar la validacion.
2. Confirmar que `MODEL_REPO_REF` apunta a un commit del repo `pricing-mlops` que contiene los componentes AUTH monitoring.
3. Publicar Function usando el template activo `mlops/azureml/pricing-mlops-pipeline.yml`.
4. Ejecutar preflight con blobs reales de baseline y current history.
5. Someter un job directo con `mlops/scripts/submit_notebook_pipeline_job.sh` para prevalidacion o por Function para operacion normal.
6. Verificar en Azure ML Studio que aparecen los seis nodos.
7. Verificar Storage MLOps: `runs`, `snapshots`, `drift-logs`, `reports` y `artifacts`.
8. Comparar artefactos clave contra la copia transicional del notebook.

## No Objetivos De Esta Etapa

- No ejecutar notebooks completos dentro del pipeline como fuente operacional principal.
- No mover datos unmasked a `staging`.
- No crear grupos complejos ni ambientes nuevos.
- No convertir GitHub Actions en orquestador ML.
- No hacer retraining automatico; el semaforo decide accion operacional y revision.
