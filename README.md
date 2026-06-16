# pricing-mlops-platform

Plataforma Azure para operar y auditar el flujo MLOps de Pricing Intelligence. Este repo contiene IaC, Azure Function, template de Azure ML, scripts operativos, contratos y documentacion.

El codigo funcional/data science vive en `pricing-mlops`; este repo orquesta la ejecucion, registra metadata y publica evidencia.

## Flujo Activo

```text
manual / Event Grid
-> Azure Function
-> Azure ML pipeline
-> Storage MLOps
-> Azure SQL audit
```

GitHub Actions valida y despliega infraestructura bajo `workflow_dispatch`; no opera el flujo ML.

## Ambientes

| Scope | Uso |
|---|---|
| `staging` | Ambiente operativo del MVP. |
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

Validar contratos e IaC:

```bash
scripts/validate-mlops-contracts.py
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

Publicar y ejecutar el flujo ML:

```bash
MODEL_REPO_REF=<commit-sha-or-tag> \
mlops/scripts/publish_orchestrator_function.sh staging

mlops/scripts/run_model_flow_function.sh staging team46 samples/sample_pricing_v1.csv
```

`MODEL_REPO_REF` queda registrado en `model_source.json`; la ejecucion funcional usa componentes Azure ML registrados desde `pricing-mlops`.

## Documentacion

```bash
python -m pip install -r requirements-docs.txt
python -m mkdocs serve
```

Lecturas principales:

1. [Inicio](docs/index.md)
2. [Arquitectura](docs/architecture/overview.md)
3. [Operacion](docs/operations/index.md)
4. [Pipeline Azure ML](docs/reference/azure-ml-pipeline.md)
5. [Evidencia](docs/project/evidencia.md)

## Fuera De Alcance

- Produccion real.
- ADF, Private Endpoints, Hub-Spoke y endpoints online de Azure ML.
- Datos `raw-unmasked` en `sandbox-local`, `staging` o `validation`.
- Account keys, connection strings o secretos versionados.
