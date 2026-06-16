# Evidencia Del MVP

La evidencia del MVP responde una pregunta: si el flujo puede ejecutarse en Azure y dejar rastros revisables.

La corrida registrada cubre la cadena principal:

```text
Azure Function
-> Azure ML pipeline
-> Storage MLOps
-> Azure SQL audit
```

## Corrida Validada

| Campo | Valor |
|---|---|
| Azure ML job | `dreamy_vase_3dkv4c7m1f` |
| Run id | `20260518T040339Z-function` |
| Entrada | `raw-masked/samples/sample_pricing_v1.csv` |
| Orquestador | Azure Function |
| Compute ML | Azure ML pipeline |
| Persistencia | Storage MLOps y Azure SQL audit |

Esta corrida valida tres comportamientos:

- la Function puede iniciar el flujo remoto;
- Azure ML puede ejecutar el snapshot funcional;
- la plataforma conserva metadata y artefactos para auditoria posterior.

## Que Artefactos Deben Existir

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

Esa convencion permite comparar corridas sin depender solo del portal de Azure ML.

## Que Se Puede Auditar

La plataforma captura metadata para explicar una corrida:

- ambiente y owner;
- `run_id`;
- input usado;
- trigger manual o Event Grid;
- repo funcional y referencia empaquetada;
- commit real del snapshot funcional;
- ubicacion de outputs;
- status de la corrida.

SQL no guarda datasets completos. Sirve para consultar metadata y ubicar evidencia; los datos y artefactos funcionales siguen en Storage.

## Como Leer La Evidencia

Para revisar el MVP, usa este orden:

1. [Reporte de avance](reporte-avance-proyecto-integrador.md) para la narrativa academica.
2. [Arquitectura](architecture.md) para entender servicios y responsabilidades.
3. [Operacion](operations.md) para comandos, portal y verificacion.
4. [Auditoria SQL](sql-audit-runbook.md) para consultas de metadata.
5. [Contratos de datos](data-contracts.md) para schemas y evidencia minima.

## Limitacion Del Resultado

La evidencia valida el flujo operativo del MVP. No prueba que exista un modelo productivo final ni un ciclo formal de entrenamiento, promocion y rollback. Esa integracion queda para una etapa posterior.

Siguiente lectura recomendada: [Roadmap](roadmap.md).
