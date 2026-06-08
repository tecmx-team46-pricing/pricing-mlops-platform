# Contratos De Datos

Los contratos son la evidencia minima que permite reproducir y auditar una corrida.

## `model_run_log`

Un registro por corrida. Responde que se ejecuto, con que version y donde quedo la evidencia.

Schema:

```text
mlops/schemas/model_run_log.schema.json
```

Campos principales:

| Campo | Uso |
|---|---|
| `run_id` | Identificador unico de la corrida. |
| `run_timestamp` | Fecha/hora UTC. |
| `git_commit_hash` | Version exacta del repo funcional. |
| `config_version` | Version de thresholds o reglas. |
| `dataset_version` | Snapshot o version de dataset. |
| `environment` | Ambiente de ejecucion. |
| `status` | Estado de la corrida. |

## `model_output_snapshot`

Snapshot de recomendaciones generadas para una corrida.

Schema:

```text
mlops/schemas/model_output_snapshot.schema.json
```

Para el MVP, CSV o JSONL es suficiente como evidencia pequena y legible.

## `model_drift_log`

Metricas de drift por variable evaluada.

Schema:

```text
mlops/schemas/model_drift_log.schema.json
```

Debe incluir:

- metrica usada;
- valor calculado;
- umbrales green/yellow/red;
- impacto ponderado por revenue;
- accion recomendada.

## Referencia Operativa

La fuente tecnica viva se mantiene en:

```text
mlops/docs/data-contracts.md
```
