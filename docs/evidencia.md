# Evidencia Del MVP

## Corrida Validada

El avance documenta una ejecucion end-to-end en Azure:

| Campo | Valor |
|---|---|
| Azure ML job | `dreamy_vase_3dkv4c7m1f` |
| Run id | `20260518T040339Z-function` |
| Entrada | `raw-masked/samples/sample_pricing_v1.csv` |
| Orquestador | Azure Function |
| Compute ML | Azure ML pipeline |
| Persistencia | Storage MLOps y Azure SQL audit |

## Outputs Esperados

Una corrida valida publica evidencia en rutas versionadas:

```text
runs/.../model_run_log.json
snapshots/.../model_output_snapshot.csv
drift-logs/.../model_drift_log.json
reports/.../report.md
artifacts/.../curated_pricing.csv
curated/.../curated_pricing.csv
```

La convencion funcional de ruta es:

```text
environment=<env>/compute=azure-ml/trigger=<trigger>/owner=<owner>/run_date=<yyyymmdd>/run_id=<run_id>/
```

## Trazabilidad

La plataforma captura metadata suficiente para explicar una corrida:

- ambiente;
- owner;
- `run_id`;
- input usado;
- trigger manual o Event Grid;
- referencia del repo funcional;
- commit real del snapshot funcional cuando se publica la Function;
- ubicacion de outputs funcionales;
- status de la corrida.

## Lectura De Evidencia

Para una revision academica, la evidencia se revisa en este orden:

1. [Reporte de avance](reporte-avance-proyecto-integrador.md) para el contexto narrativo.
2. [Arquitectura](architecture.md) para entender servicios y responsabilidades.
3. [Operacion](operations.md) para comandos, portal y verificacion.
4. [Auditoria SQL](sql-audit-runbook.md) para consultas de metadata.
5. [Contratos de datos](data-contracts.md) para schemas y evidencia minima.

## Limitaciones

La evidencia actual demuestra la plataforma y el flujo operativo, no un modelo productivo final. El scoring y drift son una base controlada para validar la arquitectura y permitir integracion posterior de un modelo real.
