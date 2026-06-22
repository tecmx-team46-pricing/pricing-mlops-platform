# Operacion

Esta pagina cubre solo la operacion de infraestructura de platform. La operacion del flujo ML vive en `pricing-mlops`.

## Preflight

```bash
az login
az account set --subscription "<azure-subscription-name>"
az account show --query "{name:name,id:id}" -o table
```

## Validacion Local

```bash
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
scripts/what-if.sh validation
scripts/deploy.sh validation
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

Usar el repo `pricing-mlops`:

```bash
cd ../pricing-mlops

AZURE_SUBSCRIPTION_ID=<subscription-id> \
AZURE_RESOURCE_GROUP=<resource-group> \
AZURE_ML_WORKSPACE=<workspace> \
scripts/register_azureml_components.sh

scripts/deploy_auth_monitoring_batch_endpoint.sh
scripts/invoke_auth_monitoring_batch_endpoint.sh
```

Platform no contiene scripts de endpoint ni componentes Azure ML operativos.

Para levantar `validation` en la cuenta `pricing46mlops@outlook.com`, seguir
`docs/goals/lift-validation-to-pricing46-account.md`.

Para entender el flujo completo entre ambos repos, ver [Flujo end to end](end-to-end-flow.md).

## Portal

| Necesidad | Ruta |
|---|---|
| Azure ML jobs/endpoints | Machine Learning workspace > Jobs / Endpoints |
| Outputs funcionales | Storage MLOps > Containers |
| Artifacts runtime AML | Storage runtime Azure ML asociado al workspace activo |
| Costos | Cost Management > Cost analysis > filtrar Resource Group |
| RBAC | Resource > Access control (IAM) |

## Limpieza

No borrar recursos Azure legacy sin aprobacion explicita. Especialmente:

- workspace Azure ML legacy;
- containers internos de Azure ML;
- outputs funcionales historicos en Storage.
