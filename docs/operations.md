# Operations

## Preflight

```bash
az login
az account set --subscription "<azure-subscription-name>"
az account show --query "{name:name,id:id}" -o table
```

## Validacion Local

```bash
scripts/validate-mlops-contracts.py
az bicep build --file infra/foundation/main.bicep
az bicep build --file infra/workloads/pricing-mlops/main.bicep
az bicep build-params --file infra/parameters/staging.bicepparam
az bicep build-params --file infra/parameters/validation.bicepparam
az bicep build-params --file infra/parameters/data-lab.bicepparam
az bicep build-params --file infra/parameters/sandbox-local.bicepparam
```

## What-if y Deploy

```bash
scripts/what-if.sh staging
scripts/deploy.sh staging
```

Ambientes aceptados por scripts:

```text
staging
validation
data-lab
sandbox-local
```

`sandbox-local` es local/admin only. GitHub Actions solo expone `staging` y `validation` para operacion manual.

## Operacion Del Flujo ML

La operacion diaria del flujo vive en el repo `pricing-mlops`:

```bash
AZURE_FUNCTION_APP=func-pricing-mlops-staging-<suffix> \
AZURE_RESOURCE_GROUP=rg-pricing-mlops-staging \
AZURE_ML_WORKSPACE=mlw-pricing-mlops-staging-<suffix> \
scripts/run_model_flow_function.sh staging team46 samples/sample_pricing_v1.csv
```

Ese script llama la Function, espera el job AML por ARM/REST y verifica metadata de los seis outputs. No usa GitHub Actions ni `az ml`.

## Portal

| Necesidad | Ruta |
|---|---|
| Function | Function App `func-pricing-mlops-staging-<suffix>` > Functions / Log stream |
| Azure ML jobs | Machine Learning workspace `mlw-pricing-mlops-staging-<suffix>` > Jobs |
| Outputs | Storage `<mlops-storage-account>` > Containers |
| Costos | Cost Management > Cost analysis > filtrar `rg-pricing-mlops-staging` |
| RBAC | Resource > Access control (IAM) |

## Seguridad Actual

- Storage MLOps principal tiene account keys deshabilitadas.
- Function usa Function key como control temporal.
- Function App usa HTTPS-only, TLS minimo 1.2, FTPS disabled, remote debugging off y detailed errors off.
- No se versionan secrets, account keys ni connection strings.
- `raw-unmasked` no existe en `staging`.

Pendiente: migrar el endpoint a Entra ID/Easy Auth o API Management si el equipo aprueba ese modelo.

## Limpieza De Recursos Legacy

Existen recursos de un PoC anterior de Container Apps/ACR en `rg-pricing-mlops-staging`. No son ruta activa. No borrarlos sin una tarea explicita de cleanup con:

1. Inventario de recursos.
2. Estimacion de costo.
3. Confirmacion de que Azure ML no depende del ACR legacy.
4. Aprobacion explicita antes de delete.
