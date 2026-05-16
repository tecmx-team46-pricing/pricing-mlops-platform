# Operations

## Despliegue de infraestructura

```bash
az login
az account set --subscription "<azure-subscription-name>"
scripts/what-if.sh sandbox-david
scripts/deploy.sh sandbox-david
scripts/what-if.sh data-lab
scripts/deploy.sh data-lab
```

Los scripts aceptan solo:

```text
staging
sandbox-david
validation
data-lab
```

Cada ejecucion despliega en orden:

1. Foundation: `infra/foundation/main.bicep`
2. Workload Pricing MLOps: `infra/workloads/pricing-mlops/main.bicep`

`shared` se despliega como scope compartido desde foundation, pero no se opera como ambiente MLOps. `prod` sigue fuera de alcance y no tiene parameter file.

`data-lab` crea `rg-pricing-mlops-data-lab` y un Storage Account con contenedores `raw-unmasked`, `raw-masked`, `curated`, `baseline`, `runs`, `snapshots`, `drift-logs`, `reports` y `artifacts`. No despliega Function App y no crea identidad GitHub Actions por defecto para evitar acceso automatico a `raw-unmasked`.

La Function App del workload usa App Service Plan `B1` por defecto. Si Azure devuelve `SubscriptionIsOverQuotaForSku` para `Basic VMs`, la infraestructura base queda preparada pero la Function App no puede crearse hasta pedir cuota `Basic VMs >= 1` o ajustar los parametros `functionPlanSkuName`, `functionPlanSkuTier` y `functionPlanSkuSize` en el despliegue.

`sandbox-david` usa `eastus2` porque los recursos existentes de `rg-pricing-mlops-sbx-david` ya viven ahi. Azure no mueve Storage Accounts ni Function Apps en sitio. Un cambio de region requiere borrar y recrear `rg-pricing-mlops-sbx-david` o usar nombres nuevos, siempre con confirmacion explicita.

Mientras se resuelve la cuota de compute, se puede validar foundation y storage sin crear Function App:

```bash
ENABLE_HELLO_FUNCTION=false scripts/what-if.sh sandbox-david
ENABLE_HELLO_FUNCTION=false scripts/deploy.sh sandbox-david
```

Antes de desplegar, confirmar el contexto activo:

```bash
az account show --query "{name:name, id:id}" --output table
```

## Publicar Function hello world

El despliegue de infraestructura crea la Function App. El codigo runtime vive fuera de `infra/`:

```text
src/functions/pricing-mlops-hello/
```

Validar localmente:

```bash
npm test --prefix src/functions/pricing-mlops-hello
```

Publicar a sandbox:

```bash
scripts/publish-hello-function.sh sandbox-david
```

Endpoint esperado despues de publicar:

```text
https://<function-app-name>.azurewebsites.net/api/health
```

Debe responder JSON con `status=ok`, `message=hello world`, `workload=pricing-mlops` y el ambiente.

## Configurar GitHub Actions

La referencia compacta de workflows, variables y OIDC esta en [`github-actions.md`](github-actions.md).

Crear GitHub environments para los ambientes que se quieran operar desde Actions:

```text
staging
sandbox-david
validation
```

`data-lab` se compila en CI, pero el bootstrap inicial se recomienda local/admin hasta que exista una identidad GitHub especifica con permisos revisados.

Variables por environment:

```text
AZURE_CLIENT_ID=<output githubActionsClientId>
AZURE_TENANT_ID=<tenant id>
AZURE_SUBSCRIPTION_ID=<subscription id>
AZURE_STORAGE_ACCOUNT=<output storageAccountName>
```

Para el repo funcional `tecmx-team46-pricing/pricing-mlops`, crear tambien el environment `sandbox-david` con:

```text
AZURE_CLIENT_ID=<output modelGithubActionsClientId>
AZURE_TENANT_ID=<tenant id>
AZURE_SUBSCRIPTION_ID=<subscription id>
AZURE_STORAGE_ACCOUNT=<output storageAccountName>
AZURE_STORAGE_DFS_ENDPOINT=<output storageDfsEndpoint>
MLOPS_ENVIRONMENT=sandbox-david
MLOPS_CONTAINER_RAW_MASKED=raw-masked
MLOPS_CONTAINER_CURATED=curated
MLOPS_CONTAINER_BASELINE=baseline
MLOPS_CONTAINER_RUNS=runs
MLOPS_CONTAINER_SNAPSHOTS=snapshots
MLOPS_CONTAINER_DRIFT_LOGS=drift-logs
MLOPS_CONTAINER_REPORTS=reports
MLOPS_CONTAINER_ARTIFACTS=artifacts
FUNCTION_HEALTH_ENDPOINT=<output functionHealthEndpoint, si existe>
```

La identidad del repo funcional es `id-gha-pricing-mlops-model-sandbox-david`. Solo recibe `Storage Blob Data Contributor` sobre el Storage Account del workload. No recibe `Owner`, no recibe `Contributor` de subscription y no recibe acceso a `raw-unmasked`.

`platform-infra.yml` se comporta asi:

- En `pull_request` solo compila Bicep y parameter files.
- En `pull_request` no hace `azure/login`.
- En `pull_request` no ejecuta `az deployment`.
- En `workflow_dispatch`, `operation=validate` solo valida.
- En `workflow_dispatch`, `operation=what-if` inicia sesion con OIDC y ejecuta `scripts/what-if.sh <environment>`.
- En `workflow_dispatch`, `operation=deploy` ejecuta primero what-if y luego `scripts/deploy.sh <environment>`.

Para ejecutar `what-if` y `deploy` desde GitHub Actions con templates a scope subscription, la identidad OIDC de cada GitHub environment necesita `Contributor` sobre la subscription.

## Corrida MLOps staging

Local:

```bash
scripts/run-mlops-staging.py --environment staging
```

GitHub:

- Abrir Actions.
- Ejecutar `mlops`.
- Usar `upload_to_azure=true` solo cuando el Storage ya exista y OIDC este configurado.

## Revision operativa

Cada semana:

- revisar costos;
- confirmar consumo contra el credito de 200 USD;
- borrar sandboxes;
- revisar ultimas corridas yellow/red;
- revisar si algun experimento debe pasar a IaC.

## Cuando crear prod

Crear prod solo cuando exista ejecucion real con impacto operativo o de negocio. Antes de eso, `prod` debe ser documentacion conceptual.
