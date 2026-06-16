# GitHub Actions

## Regla Principal

GitHub Actions no opera el flujo ML. La ruta operativa manual es Azure Function -> Azure ML -> Storage; la ruta automatica es BlobCreated -> Event Grid -> Azure Function -> Azure ML -> Storage.

GitHub Actions se usa para:

- validar PRs sin Azure login;
- ejecutar `what-if` o deploy manual controlado de infraestructura;
- publicar o probar integraciones cuando se solicite.

## Workflow Activo En Este Repo

`.github/workflows/platform-infra.yml`

| Trigger | Accion | Azure login |
|---|---|---|
| `pull_request` | Compila Bicep, parameter files y tests del runtime MLOps. | No |
| `workflow_dispatch`, `operation=validate` | Valida IaC y runtime MLOps. | No |
| `workflow_dispatch`, `operation=what-if` | Ejecuta `scripts/what-if.sh`. | Si |
| `workflow_dispatch`, `operation=deploy` | Ejecuta what-if y deploy. | Si |

Opciones manuales permitidas:

```text
staging
validation
```

`sandbox-local` y `data-lab` se operan local/admin hasta que el equipo apruebe otra politica.

## Variables Del Environment GitHub

Para plataforma:

```text
AZURE_CLIENT_ID
AZURE_TENANT_ID
AZURE_SUBSCRIPTION_ID
```

Los componentes de Azure ML se registran desde el repo `pricing-mlops`, porque ahi vive el codigo de los entrypoints del modelo. Este repo solo orquesta y referencia esos assets registrados desde `mlops/azureml/pricing-mlops-pipeline.yml`.

## PR Seguro

En pull request:

- no usar `azure/login`;
- no ejecutar `az deployment`;
- no desplegar recursos;
- no correr Azure ML jobs;
- no tocar sandboxes.
