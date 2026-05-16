# GitHub Actions

## Reglas

- Pull requests validan sin Azure login.
- Deploys solo ocurren por `workflow_dispatch`.
- El repo plataforma despliega infraestructura.
- El repo `pricing-mlops` ejecuta el flujo ML y sube artefactos.
- No usar account keys ni connection strings.
- No dar `Owner` ni `Contributor` de subscription al repo modelo.

## Repo plataforma

Workflow actual: `.github/workflows/platform-infra.yml`.

| Trigger | Que hace | Azure login |
|---|---|---|
| `pull_request` | Compila Bicep y parameter files. | No |
| `workflow_dispatch`, `operation=validate` | Ejecuta validacion. | No |
| `workflow_dispatch`, `operation=what-if` | Ejecuta `scripts/what-if.sh`. | Si |
| `workflow_dispatch`, `operation=deploy` | Ejecuta what-if y luego `scripts/deploy.sh`. | Si |

GitHub environments soportados para operacion:

```text
staging
validation
```

`sandbox-*` es local/admin only. GitHub Actions no despliega ni ejecuta what-if de sandboxes personales. `data-lab` se valida en CI, pero su bootstrap se recomienda local/admin hasta revisar permisos sobre datos sensibles.

## Repo modelo

Repo objetivo: `tecmx-team46-pricing/pricing-mlops`.

El environment recomendado para GitHub Actions del modelo es `staging`. Debe usar:

```text
AZURE_CLIENT_ID=<modelGithubActionsClientId>
AZURE_TENANT_ID=<tenant id>
AZURE_SUBSCRIPTION_ID=<subscription id>
AZURE_STORAGE_ACCOUNT=<storageAccountName>
AZURE_STORAGE_DFS_ENDPOINT=<storageDfsEndpoint>
MLOPS_ENVIRONMENT=staging
MLOPS_RUN_OWNER=team46
MLOPS_CONTAINER_RAW_MASKED=raw-masked
MLOPS_CONTAINER_CURATED=curated
MLOPS_CONTAINER_BASELINE=baseline
MLOPS_CONTAINER_RUNS=runs
MLOPS_CONTAINER_SNAPSHOTS=snapshots
MLOPS_CONTAINER_DRIFT_LOGS=drift-logs
MLOPS_CONTAINER_REPORTS=reports
MLOPS_CONTAINER_ARTIFACTS=artifacts
```

La identidad modelo solo debe tener `Storage Blob Data Contributor` sobre el Storage Account del workload compartido. No debe recibir acceso a `raw-unmasked`, `Owner` ni `Contributor` de subscription.

`sandbox-david` puede tener identidades OIDC heredadas de pruebas previas. Quedan consideradas legacy/deprecated para GitHub Actions y no deben usarse como patron de equipo.

## Outputs de plataforma

Despues del deploy, la plataforma debe publicar valores no sensibles:

```json
{
  "environment": "staging",
  "storageAccount": "stpmlops...",
  "storageDfsEndpoint": "https://stpmlops....dfs.core.windows.net",
  "modelGithubActionsClientId": "<client-id>",
  "containers": {
    "input": "input",
    "rawMasked": "raw-masked",
    "curated": "curated",
    "baseline": "baseline",
    "runs": "runs",
    "snapshots": "snapshots",
    "driftLogs": "drift-logs",
    "reports": "reports",
    "artifacts": "artifacts"
  }
}
```
