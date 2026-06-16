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
AZURE_SUBSCRIPTION_ID=<subscription-id> \
AZURE_RESOURCE_GROUP=<resource-group> \
AZURE_ML_WORKSPACE=<workspace-name> \
mlops/scripts/register_azureml_environment.sh

MODEL_REPO_REF=<commit-sha-or-tag> \
mlops/scripts/publish_orchestrator_function.sh staging
```

El registro del Azure ML Environment crea/actualiza `pricing-auth-monitoring-env:1`. Ese environment no mantiene compute prendido; solo guarda la definicion de runtime e imagen para que los jobs serverless no instalen dependencias en cada step.

Por default el script usa `FUNCTION_PACKAGE_MODE=remote-build`, que delega la instalacion de dependencias a Kudu/Oryx. Para despliegues reproducibles o cuando remote build no instala `azure-ai-ml`, se puede generar un paquete vendorizado para Linux Python 3.11:

```bash
FUNCTION_PACKAGE_MODE=vendored \
MODEL_REPO_REF=<commit-sha-or-tag> \
mlops/scripts/publish_orchestrator_function.sh staging
```

El modo `vendored` instala las dependencias en `.python_packages/lib/site-packages` antes de crear el ZIP y publica con `SCM_DO_BUILD_DURING_DEPLOYMENT=false`.

El script copia `function_app.py`, `host.json`, `requirements.txt`, `mlops/azureml/`, `mlops/configs/` y `mlops/components/platform_publish_outputs.py`. Para operacion de `staging` y `validation`, resuelve `MODEL_REPO_GITHUB` + `MODEL_REPO_REF` antes de empaquetar y escribe el commit real en `model_source.json`. `MODEL_REPO_PATH` solo se usa como fallback local con `ALLOW_LOCAL_MODEL_SOURCE=true`. No hace deploy real si se ejecuta con `DRY_RUN=true`.

La Function no ejecuta scoring, drift ni procesamiento pesado. Solo valida, registra metadata inicial en `mlopsruns` o en JSON fallback bajo `runs`, y somete Azure ML con managed identity.

Reglas del trigger automatico:

- container permitido: `raw-masked`
- prefix permitido: `incoming/`
- extension permitida: `.csv`
- ambiente automatico: `staging`
- owner default: `team46`
- `samples/`, paths absolutos, `..` y `raw-unmasked` se rechazan
