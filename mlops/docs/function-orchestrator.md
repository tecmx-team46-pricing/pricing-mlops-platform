# Function Orchestrator

La Azure Function operativa vive en `mlops/functions/function_app.py`.

Endpoints:

| Endpoint | Metodo | Uso |
|---|---|---|
| `/api/model-flow` | `POST` | Valida payload manual, arma `run_id`, carga el pipeline/job AML y lo somete. |
| `/api/health` | `GET` | Healthcheck minimo del orquestador. |
| `model-flow-blob-created` | Event Grid | Valida `BlobCreated` bajo `raw-masked/incoming/*.csv` y somete el mismo flujo. |

El paquete de despliegue se arma con:

```bash
MODEL_REPO_PATH=../pricing-mlops \
mlops/scripts/publish_orchestrator_function.sh staging
```

El script copia `function_app.py`, `host.json`, `requirements.txt`, `mlops/azureml/` y un snapshot del repo `pricing-mlops` bajo `pricing-mlops-source/`. Por defecto resuelve `MODEL_REPO_GITHUB` + `MODEL_REPO_REF`; `MODEL_REPO_PATH` solo se usa como fallback local. No hace deploy real si se ejecuta con `DRY_RUN=true`.

La Function no ejecuta scoring, drift ni procesamiento pesado. Solo valida, registra metadata inicial en `mlopsruns` o en JSON fallback bajo `runs`, y somete Azure ML con managed identity.

Reglas del trigger automatico:

- container permitido: `raw-masked`
- prefix permitido: `incoming/`
- extension permitida: `.csv`
- ambiente automatico: `staging`
- owner default: `team46`
- `samples/`, paths absolutos, `..` y `raw-unmasked` se rechazan
