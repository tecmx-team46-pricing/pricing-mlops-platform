# Azure ML Tooling Decision

## Decision

La ruta activa adopta Azure ML Pipeline YAML con tres command components visibles:

```text
validate_prepare -> score_evaluate -> publish_outputs
```

Se conserva `pricing-mlops-job.yml` como fallback operativo de un solo job para reducir riesgo si el pipeline multi-componente falla.

## Tooling

| Herramienta | Decision | Razon |
|---|---|---|
| Azure ML Pipeline/component job | Adoptado | Representa validacion/preparacion, scoring/evaluacion y publicacion como nodos separados sin mover logica ML a la Function. |
| Azure ML Designer v2 | No manual | Puede visualizar pipelines, pero no sera la referencia operativa ni paso manual de operacion. |
| Data Assets | Preparado | Utiles para baseline/input versionado, pero no bloquean el MVP event-driven. |
| Model Monitoring | Futuro | Requiere mas historial y politicas; el MVP conserva drift logs propios. |
| Batch Endpoints | Futuro | Buena ruta para scoring batch estable, pero agrega superficie operativa. |
| Online Endpoints | No | No hay caso de serving online y elevaria costo/complejidad. |
| Model Registry | Pendiente | Se evaluara cuando haya versionamiento formal de modelos. |
| AutoML | Opcional futuro | No necesario para el baseline deterministico actual. |
| Prompt Flow | No prioritario | No aplica al flujo tabular de pricing. |
| Responsible AI | Pendiente | Relevante en madurez futura; fuera del alcance MVP actual. |

## Codigo Modelo

La plataforma resuelve el codigo modelo en build/package con:

- `MODEL_REPO_GITHUB=tecmx-team46-pricing/pricing-mlops`
- `MODEL_REPO_REF=<commit-sha|tag|branch>`
- `MODEL_REPO_PATH=<ruta local>` solo para desarrollo con `ALLOW_LOCAL_MODEL_SOURCE=true`

El paquete escribe `model_source.json` con `model_source`, `model_repo`, `model_ref` y `model_commit_sha`. La Azure Function lee ese archivo e inyecta la metadata al pipeline/job. La Function no clona GitHub por evento. Un commit SHA o tag debe preferirse para reproducibilidad; un branch se permite para velocidad operativa, pero el publish resuelve y registra el SHA real.
