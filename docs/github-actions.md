# GitHub Actions

## Regla Principal

GitHub Actions no opera el flujo ML. La ruta operativa manual es Azure Function -> Azure ML -> Storage; la ruta automatica es BlobCreated -> Event Grid -> Azure Function -> Azure ML -> Storage.

GitHub Actions se usa para:

- validar PRs sin Azure login;
- ejecutar `what-if` o deploy manual controlado de infraestructura;
- publicar o probar integraciones cuando se solicite.

## Workflows Activos En Este Repo

`.github/workflows/platform-infra.yml`

| Trigger | Accion | Azure login |
|---|---|---|
| `pull_request` | Compila Bicep, parameter files y tests del runtime MLOps. | No |
| `workflow_dispatch`, `operation=validate` | Valida IaC y runtime MLOps. | No |
| `workflow_dispatch`, `operation=what-if` | Ejecuta `scripts/what-if.sh`. | Si |
| `workflow_dispatch`, `operation=deploy` | Ejecuta what-if y deploy. | Si |

`.github/workflows/azureml-components.yml`

| Trigger | Accion | Azure login |
|---|---|---|
| `push` a `main` con cambios en `mlops/azureml/components/**`, environment, pipeline o scripts de registro | Registra el Azure ML Environment y los componentes versionados que usa el pipeline. | Si |
| `workflow_dispatch` | Re-registra manualmente Environment y componentes. | Si |

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
AZURE_RESOURCE_GROUP
AZURE_ML_WORKSPACE
```

Para registrar componentes, el workflow hace checkout de `tecmx-team46-pricing/pricing-mlops` en `mlops/azureml/pricing-mlops-source`. Si ese repo es privado y el `GITHUB_TOKEN` no tiene acceso, configurar el secret `PRICING_MLOPS_READ_TOKEN` con permisos de lectura. La variable opcional `MODEL_REPO_REF` permite fijar branch, tag o SHA del repo modelo; si no existe, usa `main`.

La identidad federada de GitHub necesita permisos sobre el Resource Group principal para registrar assets de Azure ML. La identidad del repo modelo no debe recibir `Owner` ni `Contributor` de subscription.

## PR Seguro

En pull request:

- no usar `azure/login`;
- no ejecutar `az deployment`;
- no desplegar recursos;
- no correr Azure ML jobs;
- no tocar sandboxes.
