# Data Contracts

Los contratos son la evidencia minima que permite reproducir y auditar una corrida.

## model_run_log

Un registro por corrida. Debe responder que se ejecuto, con que version y donde quedo la evidencia.

Schema: `mlops/schemas/model_run_log.schema.json`

Campos principales:

| Campo | Uso |
|---|---|
| `run_id` | Identificador unico de la corrida |
| `run_timestamp` | Fecha/hora UTC |
| `git_commit_hash` | Version exacta del repo |
| `config_version` | Version de thresholds/reglas |
| `dataset_version` | Snapshot o version de dataset |
| `environment` | `sandbox`, `staging`, `validation` o `prod` futuro |
| `status` | `started`, `succeeded` o `failed` |

## model_output_snapshot

Snapshot de recomendaciones generadas para una corrida.

Schema: `mlops/schemas/model_output_snapshot.schema.json`

La base operativa lo puede guardar como JSONL o Parquet. JSONL es suficiente para evidencia pequena.

## model_drift_log

Metricas de drift por variable evaluada.

Schema: `mlops/schemas/model_drift_log.schema.json`

Debe incluir:

- metrica usada;
- valor calculado;
- umbrales green/yellow/red;
- impacto ponderado por revenue;
- accion recomendada.
