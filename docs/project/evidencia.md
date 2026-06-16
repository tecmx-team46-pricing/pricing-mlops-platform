# Evidencia Del MVP

La evidencia de esta etapa se divide por ownership:

| Repo | Evidencia |
|---|---|
| `pricing-mlops-platform` | Bicep compila, parametros compilan, recursos base existen en Azure. |
| `pricing-mlops` | Componentes/pipeline endpoint se registran, se invoca un job y se publican artefactos. |

## Evidencia Que Debe Producir El Flujo ML

Una corrida valida publica evidencia en rutas versionadas:

```text
runs/.../model_run_log.json
runs/.../summaries/operational_decision_summary.csv
snapshots/.../snapshots/baseline_recommendation_snapshot.csv
snapshots/.../snapshots/current_auth_history_snapshot_real.csv
drift-logs/.../logs/auth_recommendation_validity_log.csv
drift-logs/.../logs/auth_history_drift_log.csv
reports/.../reports/auth_recommendation_validity_report.md
artifacts/.../manifest/artifact_manifest.json
```

La convencion funcional de ruta es:

```text
environment=<env>/compute=azure-ml/trigger=<trigger>/owner=<owner>/run_date=<yyyymmdd>/run_id=<run_id>/
```

## Como Leer La Evidencia

1. [Arquitectura](../architecture/overview.md) para entender responsabilidades.
2. [Operacion](../operations/index.md) para validar infraestructura.
3. `pricing-mlops` para registrar/invocar el endpoint y revisar artefactos.
4. [Contratos de datos](../reference/data-contracts.md) para contenedores esperados.

## Limitacion Del Resultado

La evidencia valida una primera base operativa. No prueba produccion real, entrenamiento formal, promocion de modelos ni rollback productivo.
