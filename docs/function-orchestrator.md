# Function Orchestrator

## Rol

La Azure Function es el orquestador ligero del flujo MLOps. No ejecuta scoring, drift ni procesamiento pesado. Su responsabilidad es validar solicitudes o eventos, construir metadata de corrida y someter Azure ML.

Archivo operativo de referencia:

```text
mlops/functions/function_app.py
```

## Entradas

| Endpoint | Metodo | Uso |
|---|---|---|
| `/api/model-flow` | `POST` | Valida payload manual, arma `run_id` y somete el pipeline/job AML. |
| `/api/health` | `GET` | Healthcheck minimo del orquestador. |
| `model-flow-blob-created` | Event Grid | Valida `BlobCreated` bajo `raw-masked/incoming/*.csv` y somete el mismo flujo. |

## Empaquetado

El despliegue de la Function se prepara con:

```bash
MODEL_REPO_REF=<commit-sha-or-tag> \
mlops/scripts/publish_orchestrator_function.sh staging
```

El paquete incluye:

- codigo de Azure Functions;
- configuracion `host.json`;
- dependencias runtime;
- definiciones Azure ML;
- snapshot del repo funcional `pricing-mlops` bajo `pricing-mlops-source/`.

## Reglas Del Trigger Automatico

- container permitido: `raw-masked`;
- prefix permitido: `incoming/`;
- extension permitida: `.csv`;
- ambiente automatico: `staging`;
- owner default: `team46`;
- se rechazan paths absolutos, `..`, `samples/` y referencias a `raw-unmasked`.

## Referencia Operativa

La fuente tecnica viva se mantiene en:

```text
mlops/docs/function-orchestrator.md
```
