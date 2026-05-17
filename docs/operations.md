# Operations

Runbook operativo para el repo plataforma. Para variables de GitHub/OIDC, usar [`github-actions.md`](github-actions.md).

## Preflight

```bash
az login
az account set --subscription "<azure-subscription-name>"
az account show --query "{name:name, id:id}" --output table
```

Los scripts aceptan:

```text
staging
sandbox-local
validation
data-lab
```

`shared` se despliega desde foundation, pero no se opera como ambiente MLOps. `prod` no existe.

## Validar Localmente

```bash
scripts/validate-mlops-contracts.py
az bicep build --file infra/foundation/main.bicep
az bicep build --file infra/workloads/pricing-mlops/main.bicep
az bicep build-params --file infra/parameters/sandbox-local.bicepparam
```

## What-If

```bash
scripts/what-if.sh sandbox-local
```

Los sandboxes personales se operan solo desde local/admin. Los scripts bloquean `sandbox-*` cuando `GITHUB_ACTIONS=true`.

`staging` habilita Azure ML como compute del modelo. `sandbox-local` queda para pruebas local/admin y no se opera desde GitHub Actions.

## Deploy Minimo

```bash
scripts/deploy.sh sandbox-local
```

Ese despliegue prepara el pipeline Azure minimo:

- Resource Groups.
- Key Vault y Log Analytics en `shared`.
- Storage/ADLS y containers del workload.
- Sin identidades OIDC por default para sandboxes personales.

No crea ADF, SQL ni prod.

## Azure ML Model Flow

Azure ML es el compute principal del flujo MLOps. La infraestructura se crea desde este repo; el codigo runtime vive en `pricing-mlops` y se ejecuta como command job:

```bash
scripts/deploy.sh staging
```

Recursos esperados en `staging`:

```text
mlw-pricing-mlops-staging-...
appi-pricing-mlops-staging-...
stpmlops...
```

La identidad de GitHub del repo modelo somete el job AML. La identidad administrada del workspace/job lee `raw-masked` y escribe outputs en Storage. No se usan account keys ni connection strings.

## Azure Functions Orchestrator

Azure Functions queda como orquestador ligero: health check, validacion de parametros e inicio del job AML. La Function no entrena, no hace scoring pesado y no reemplaza Azure ML.

La Function esperada expone:

```text
GET /api/health
POST /api/model-flow
```

`POST /api/model-flow` recibe `environment`, `run_owner` e `input_blob_path`, genera o acepta un `run_id`, somete el Azure ML command job y devuelve el `azure_ml_job_name` junto con el prefijo esperado de outputs. Si App Service/Functions sigue bloqueado por quota, GitHub Actions puede someter AML directamente como alternativa temporal de orquestacion. Ese caso debe documentarse con el error exacto.

Estado observado en `staging`: el deploy de la Function Consumption fallo en `eastus2` con `SubscriptionIsOverQuotaForSku`. La subscription tenia `Current Limit (Total VMs): 0`, `Current Usage: 0` y requeria `Amount required: 1`. Para mantener bajo costo sin mover Storage ni Azure ML, `staging` habilita la Function en `centralus` mediante `functionLocation=centralus`.

Estado actual:

```text
Function App: func-pricing-mlops-staging-<suffix>
Region: centralus
Plan: Y1 / Dynamic Consumption
Health: https://func-pricing-mlops-staging-<suffix>.azurewebsites.net/api/health
Trigger: https://func-pricing-mlops-staging-<suffix>.azurewebsites.net/api/model-flow
```

Se puede revisar el plan con:

```bash
scripts/what-if.sh staging
scripts/deploy.sh staging
```

Si `centralus` tambien falla por quota, no probar regiones al azar. Capturar el error exacto y pedir quota App Service/Functions minima (`Total VMs >= 1`) para la region/SKU elegida.

Publicar codigo de Function desde el repo `pricing-mlops`:

```bash
AZURE_FUNCTION_APP=func-pricing-mlops-staging-<suffix> scripts/publish_orchestrator_function.sh staging
```

La Function usa una key de Function para el prototipo. El siguiente hardening debe reemplazar o complementar esto con autenticacion gestionada aprobada por el equipo.

## Compute Legacy

Container Apps Job + ACR fue un PoC anterior. Si se consulta evidencia historica, separar outputs con `MLOPS_COMPUTE_TARGET`:

```text
raw-masked/samples/sample_pricing_v1.csv
environment=staging/compute=<azure-ml|functions|container-job>/owner=team46/run_date=<yyyymmdd>/run_id=<run_id>/
```

No borrar ACR/Container Apps sin confirmacion explicita. La ruta recomendada nueva queda documentada en [`compute-target-comparison.md`](compute-target-comparison.md).

## Data-Lab

```bash
scripts/what-if.sh data-lab
scripts/deploy.sh data-lab
```

`data-lab` crea Storage/ADLS para zonas sensibles, incluyendo `raw-unmasked`. No despliega compute del modelo y no debe entregar acceso automatico a GitHub Actions.

## GitHub Actions

`.github/workflows/platform-infra.yml`:

| Trigger | Comportamiento |
|---|---|
| `pull_request` | Compila Bicep y parameter files. No hace Azure login ni deploy. |
| `workflow_dispatch`, `validate` | Valida sin deploy. |
| `workflow_dispatch`, `what-if` | Login OIDC y `scripts/what-if.sh`. |
| `workflow_dispatch`, `deploy` | What-if y luego `scripts/deploy.sh`. |

Configurar environments y variables en [`github-actions.md`](github-actions.md).

GitHub Actions solo opera ambientes compartidos/controlados (`staging`, `validation`). `sandbox-local` y futuros `sandbox-*` son local/admin only.

## Revision Semanal

- Revisar costos del credito Azure.
- Confirmar sandboxes activos.
- Revisar corridas `yellow/red`.
- Borrar recursos temporales aprobados para limpieza.
- Promover a IaC solo recursos que se repiten o que otros consumen.
