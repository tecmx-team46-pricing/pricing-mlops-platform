# Quickstart

## Validar localmente

```bash
scripts/validate-mlops-contracts.py
az bicep build --file infra/foundation/main.bicep
az bicep build --file infra/workloads/pricing-mlops/main.bicep
az bicep build-params --file infra/parameters/sandbox-local.bicepparam
```

## Revisar Azure antes de desplegar

```bash
az login
az account set --subscription "<azure-subscription-name>"
az account show --query "{name:name, id:id}" --output table
```

## Ejecutar what-if de sandbox local/admin

```bash
scripts/what-if.sh sandbox-local
```

## Desplegar minimo sandbox

```bash
scripts/deploy.sh sandbox-local
```

Este despliegue apunta a pruebas personales local/admin: Storage/ADLS y contenedores. No crea OIDC/RBAC para GitHub Actions por default y no crea Azure ML, ADF, SQL ni prod.

## Ejecutar flujo Azure del modelo

Para `staging`, la plataforma crea Storage/ADLS y Azure ML Workspace:

```bash
scripts/deploy.sh staging
```

El codigo runtime vive en el repo `pricing-mlops`. GitHub Actions somete un Azure ML command job, espera el resultado y verifica outputs en Storage. GitHub no ejecuta el ML.

## Siguiente repo

El flujo ML vive en `pricing-mlops`. Para GitHub Actions debe usar un ambiente compartido como `staging`, no un sandbox personal:

```text
AZURE_CLIENT_ID=<modelGithubActionsClientId>
AZURE_TENANT_ID=<tenant id>
AZURE_SUBSCRIPTION_ID=<subscription id>
AZURE_STORAGE_ACCOUNT=<storageAccountName>
AZURE_RESOURCE_GROUP=rg-pricing-mlops-staging
AZURE_ML_WORKSPACE=<azureMlWorkspaceName>
MLOPS_ENVIRONMENT=staging
MLOPS_RUN_OWNER=team46
```
