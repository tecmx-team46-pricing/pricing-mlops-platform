# Contratos De Datos

La definicion tecnica de artefactos vive en `pricing-mlops`, porque ese repo produce y publica los outputs del pipeline.

Platform mantiene solamente el contrato de contenedores y permisos:

| Container | Tipo de evidencia |
|---|---|
| `runs` | `model_run_log.json` y summaries. |
| `snapshots` | Baseline/current snapshots. |
| `drift-logs` | Logs de validity y drift. |
| `reports` | Reportes operativos. |
| `artifacts` | Manifests y artefactos auxiliares. |

Para cambiar columnas, schemas, thresholds o reglas del semaforo, actualizar `pricing-mlops` y registrar una nueva version del pipeline component.
