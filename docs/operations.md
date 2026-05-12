# Operations

## Despliegue de infraestructura

```bash
az login
az account set --subscription "<azure-subscription-name>"
scripts/what-if.sh staging
scripts/deploy.sh staging
```

El prototipo de plataforma permite solo estos ambientes operativos:

```text
staging
sandbox-david
validation
```

`shared` se despliega como scope compartido desde el mismo template, pero no se opera como ambiente MLOps. `prod` sigue fuera de alcance y no tiene parameter file.

Todo se despliega en esa unica subscription. Antes de desplegar, confirmar el contexto activo:

```bash
az account show --query "{name:name, id:id}" --output table
```

El repo no incluye scripts para crear el repositorio remoto ni para otorgar `Owner`. Esas acciones son bootstrap administrativo de una sola vez y deben hacerse conscientemente desde Azure Portal, Azure CLI o GitHub, segun aplique.

## Configurar GitHub Actions

Despues del primer deploy, crear el GitHub environment correspondiente (`staging` o `validation`) y agregar estas variables:

```text
AZURE_CLIENT_ID=<output githubActionsClientId>
AZURE_TENANT_ID=<tenant id>
AZURE_SUBSCRIPTION_ID=<subscription id>
AZURE_STORAGE_ACCOUNT=<output storageAccountName>
```

El workflow `platform-infra.yml` se comporta asi:

- En `pull_request` solo compila Bicep y parameter files. No hace `azure/login`, no ejecuta `az deployment` y no modifica Azure.
- En `workflow_dispatch`, `operation=validate` solo valida.
- En `workflow_dispatch`, `operation=what-if` inicia sesion con OIDC y ejecuta `scripts/what-if.sh <environment>` para `staging` o `validation`.
- En `workflow_dispatch`, `operation=deploy` ejecuta primero what-if y luego `scripts/deploy.sh <environment>` para `staging` o `validation`.

Los sandboxes personales, por ejemplo `sandbox-david`, no se despliegan desde GitHub Actions. Cada companero los opera localmente con su propio parameter file y contexto Azure.

El login OIDC requiere estas variables por GitHub environment:

```text
AZURE_CLIENT_ID
AZURE_TENANT_ID
AZURE_SUBSCRIPTION_ID
```

Para un ambiente nuevo, GitHub Actions no puede hacer su propio primer bootstrap si todavia no existe la identidad OIDC y su federated credential. En ese caso, hacer el primer despliegue local con una cuenta autorizada y luego copiar los outputs al GitHub environment.

Despues del bootstrap local, los scripts detectan `GITHUB_ACTIONS=true` y no intentan recrear identidades OIDC ni role assignments. Esos permisos se administran desde el despliegue local inicial.

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
