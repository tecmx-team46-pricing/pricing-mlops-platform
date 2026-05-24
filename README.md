# pricing-mlops-platform

Plataforma Azure para la base operativa de Pricing MLOps. Este repo gobierna infraestructura, ambientes, RBAC/OIDC, Storage/ADLS, Azure ML, Azure Functions, runtime MLOps y runbooks de operacion.

El codigo funcional/data science del flujo vive en `pricing-mlops` siguiendo Cookiecutter Data Science. La orquestacion MLOps vive aqui en `mlops/`. La referencia historica/EDA vive en `pricing-mlops-eda`.

## Estado Actual

```text
Operador o prueba controlada
-> Azure Function /api/model-flow
-> Azure ML pipeline job
-> Storage/ADLS outputs versionados

BlobCreated raw-masked/incoming/*.csv
-> Event Grid
-> Azure Function EventGrid trigger
-> Azure ML pipeline job
-> Storage/ADLS outputs versionados
-> Table/JSON run metadata
```

GitHub Actions no es el orquestador operativo del flujo ML. En este repo solo valida o despliega infraestructura por `workflow_dispatch`.

## Arquitectura

```mermaid
flowchart TD
  Platform["pricing-mlops-platform<br/>Bicep / RBAC / Runbooks"] --> ARM["Azure Resource Manager"]
  ARM --> Shared["rg-pricing-mlops-platform-shared<br/>Key Vault / Log Analytics / OIDC"]
  ARM --> Staging["rg-pricing-mlops-staging<br/>Storage / Azure ML v2 / Function"]
  ARM --> DataLab["rg-pricing-mlops-data-lab<br/>raw-unmasked restringido"]

  Operator["Script operativo local"] --> Function["Azure Function<br/>orquestador"]
  Incoming["BlobCreated<br/>raw-masked/incoming/*.csv"] --> EventGrid["Event Grid"]
  EventGrid --> Function
  Function --> AML["Azure ML v2 Pipeline<br/>compute ML"]
  AML --> Storage["Storage MLOps<br/>raw-masked / curated / runs / snapshots / drift-logs / reports / artifacts"]
  AML -. runtime interno .-> AMLRuntime["Storage runtime Azure ML<br/>snapshots / logs / environments"]
  Function -. host state .-> FunctionStorage["Storage host Function"]
  Platform --> Runtime["mlops/<br/>Function code / AML job YAML"]
  Runtime --> Function
  Runtime --> AML
  ModelRepo["pricing-mlops<br/>codigo funcional CCDS"] --> AML
```

## Ambientes

| Scope | Resource Group | Uso | Estado |
|---|---|---|---|
| `shared` | `rg-pricing-mlops-platform-shared` | Key Vault, Log Analytics, identidades OIDC. No es ambiente MLOps. | Activo |
| `data-lab` | `rg-pricing-mlops-data-lab` | Landing restringido para unmasked y masking. | Preparado |
| `sandbox-local` | `rg-pricing-mlops-sbx-local` | Sandbox local/admin, no GitHub Actions. | Preparado |
| `staging` | `rg-pricing-mlops-staging` | Staging operativo con Storage, Azure ML y Function. | Activo |
| `validation` | `rg-pricing-mlops-validation` | No-prod controlado futuro. | Preparado |

`prod` no existe en IaC, parameters ni workflows.

## Comandos

Validar:

```bash
scripts/validate-mlops-contracts.py
az bicep build --file infra/foundation/main.bicep
az bicep build --file infra/workloads/pricing-mlops/main.bicep
az bicep build-params --file infra/parameters/staging.bicepparam
az bicep build-params --file infra/parameters/validation.bicepparam
az bicep build-params --file infra/parameters/data-lab.bicepparam
az bicep build-params --file infra/parameters/sandbox-local.bicepparam
```

What-if/deploy:

```bash
az login
az account set --subscription "<azure-subscription-name>"
scripts/what-if.sh staging
scripts/deploy.sh staging
```

Publicar la Function y operar el endpoint se hace desde plataforma:

```bash
MODEL_REPO_PATH=../pricing-mlops \
mlops/scripts/publish_orchestrator_function.sh staging

mlops/scripts/run_model_flow_function.sh staging team46 samples/sample_pricing_v1.csv
```

El publish prepara un paquete temporal con el entrypoint de Azure Functions, `mlops/azureml/pricing-mlops-pipeline.yml`, fallback `mlops/azureml/pricing-mlops-job.yml` y un snapshot del repo `pricing-mlops` bajo `pricing-mlops-source/`. Por defecto obtiene el modelo desde `MODEL_REPO_GITHUB` + `MODEL_REPO_REF`; `MODEL_REPO_PATH` es fallback local de desarrollo. La Function no clona GitHub por evento.

## Storage

`<mlops-storage-account>` es el data lake MLOps de `staging`. Su contrato funcional se limita a datos masked y outputs en `raw-masked`, `curated`, `baseline`, `runs`, `snapshots`, `drift-logs`, `reports` y `artifacts`; mantiene `allowSharedKeyAccess=false`.

Azure ML usa un workspace v2 activo (`mlw-pricing-mlops-stg-v2-<suffix>`) asociado al Storage runtime `stamlpmlopsstg<suffix>` para snapshots de codigo, logs, environments y artifacts internos de AML. El workspace original `mlw-pricing-mlops-staging-<suffix>` queda como legacy sin borrar; sus containers internos en `<mlops-storage-account>` no se deben eliminar sin aprobacion explicita.

La Function App usa otro Storage (`stfn<generated-suffix>`) para `AzureWebJobsStorage`. Ese storage puede usar connection string de host runtime, pero no es data lake MLOps.

## Documentacion

Leer en este orden:

1. [`docs/index.md`](docs/index.md)
2. [`docs/architecture.md`](docs/architecture.md)
3. [`docs/operations.md`](docs/operations.md)
4. [`docs/azure-services.md`](docs/azure-services.md)
5. [`docs/github-actions.md`](docs/github-actions.md)
6. [`docs/platform-model-operating-contract.md`](docs/platform-model-operating-contract.md)
7. [`docs/data-governance-plan.md`](docs/data-governance-plan.md)
8. [`docs/roadmap.md`](docs/roadmap.md)
9. [`docs/azure-ml-tooling-decision.md`](docs/azure-ml-tooling-decision.md)
10. [`docs/original/technical-design-original.md`](docs/original/technical-design-original.md)

## Fuera De Alcance

- Produccion real.
- ADF, SQL, Private Endpoints, Hub-Spoke y endpoints online de Azure ML.
- Datos `raw-unmasked` en `sandbox-local`, `staging` o `validation`.
- Account keys, connection strings o secretos versionados.
