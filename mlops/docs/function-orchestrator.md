# Function Orchestrator

La Azure Function operativa vive en `mlops/functions/function_app.py`.

Endpoints:

| Endpoint | Metodo | Uso |
|---|---|---|
| `/api/model-flow` | `POST` | Valida payload, arma `run_id`, carga el job AML y lo somete. |
| `/api/health` | `GET` | Healthcheck minimo del orquestador. |

El paquete de despliegue se arma con:

```bash
PRICING_MLOPS_REPO=../pricing-mlops \
mlops/scripts/publish_orchestrator_function.sh staging
```

El script copia `function_app.py`, `host.json`, `requirements.txt`, `mlops/azureml/` y un snapshot del repo `pricing-mlops` bajo `pricing-mlops-source/`. No hace deploy real si se ejecuta con `DRY_RUN=true`.

La Function no ejecuta scoring, drift ni procesamiento pesado. Solo somete el command job a Azure ML con managed identity.
