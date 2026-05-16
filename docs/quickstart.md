# Quickstart

## Validar localmente

```bash
scripts/validate-mlops-contracts.py
az bicep build --file infra/foundation/main.bicep
az bicep build --file infra/workloads/pricing-mlops/main.bicep
az bicep build-params --file infra/parameters/sandbox-david.bicepparam
```

## Revisar Azure antes de desplegar

```bash
az login
az account set --subscription "<azure-subscription-name>"
az account show --query "{name:name, id:id}" --output table
```

## Ejecutar what-if de sandbox

Para validar Storage, OIDC y RBAC sin crear Function App:

```bash
ENABLE_HELLO_FUNCTION=false scripts/what-if.sh sandbox-david
```

## Desplegar minimo sandbox

```bash
ENABLE_HELLO_FUNCTION=false scripts/deploy.sh sandbox-david
```

Este despliegue apunta al pipeline Azure minimo: Storage/ADLS, contenedores e identidad OIDC/RBAC para que `pricing-mlops` suba artefactos. No crea AML, ADF, SQL, ACR ni prod.

## Publicar Function hello world

Solo si la subscription tiene cuota App Service:

```bash
scripts/deploy.sh sandbox-david
scripts/publish-hello-function.sh sandbox-david
```

Si Azure devuelve quota 0 para App Service/Functions, mantener `ENABLE_HELLO_FUNCTION=false`.

## Siguiente repo

El flujo ML vive en `pricing-mlops`. Ese repo debe usar los outputs de plataforma:

```text
AZURE_CLIENT_ID=<modelGithubActionsClientId>
AZURE_TENANT_ID=<tenant id>
AZURE_SUBSCRIPTION_ID=<subscription id>
AZURE_STORAGE_ACCOUNT=<storageAccountName>
MLOPS_ENVIRONMENT=sandbox-david
```
