# pricing-mlops-platform

Plataforma Azure base para Pricing MLOps. Este repo contiene IaC, identidades, RBAC, Storage, Azure ML Workspace y documentacion de plataforma.

El flujo ML operacional vive en `pricing-mlops`: ahi se registran componentes Azure ML, se publica el pipeline component, se despliega el batch pipeline endpoint y se ejecutan smoke tests.

## Flujo De Ownership

```text
pricing-mlops-platform
-> Azure base: Storage, AML workspace, identities, RBAC

pricing-mlops
-> AML components, pipeline component, endpoint/deployment, invoke, artifacts
```

GitHub Actions de platform valida y despliega infraestructura bajo `workflow_dispatch`; no opera el flujo ML.

## Ambientes

| Scope | Uso |
|---|---|
| `staging` | Ambiente operativo compartido. |
| `validation` | No-prod controlado futuro. |
| `data-lab` | Landing restringido para unmasked/masking. |
| `sandbox-local` | Pruebas locales/admin. |
| `shared` | Key Vault, Log Analytics e identidades OIDC. |

`prod` no existe en IaC, parametros ni workflows.

## Comandos Basicos

Validar documentacion:

```bash
python -m mkdocs build --strict
```

Validar IaC:

```bash
az bicep build --file infra/foundation/main.bicep
az bicep build --file infra/workloads/pricing-mlops/main.bicep
az bicep build-params --file infra/parameters/staging.bicepparam
az bicep build-params --file infra/parameters/validation.bicepparam
az bicep build-params --file infra/parameters/data-lab.bicepparam
az bicep build-params --file infra/parameters/sandbox-local.bicepparam
```

Operar infraestructura:

```bash
az login
az account set --subscription "<azure-subscription-name>"
scripts/what-if.sh staging
scripts/deploy.sh staging
```

Operar ML:

```bash
cd ../pricing-mlops
scripts/register_azureml_components.sh
scripts/deploy_auth_monitoring_batch_endpoint.sh
scripts/invoke_auth_monitoring_batch_endpoint.sh
```

## Documentacion

```bash
python -m pip install -r requirements-docs.txt
python -m mkdocs serve
```

Lecturas principales:

1. [Inicio](docs/index.md)
2. [Arquitectura](docs/architecture/overview.md)
3. [Estructura del repo](docs/architecture/repo-structure.md)
4. [Separacion plataforma-modelo](docs/reference/platform-model-contract.md)
5. [Servicios Azure](docs/architecture/azure-services.md)
