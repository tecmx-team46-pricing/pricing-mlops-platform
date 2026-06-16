# Contrato Platform-Model

## Responsabilidades

| Repo | Responsabilidad |
|---|---|
| `pricing-mlops-platform` | Infraestructura base: resource groups, Storage, Azure ML Workspace, Managed Identities, OIDC/RBAC y documentacion de plataforma. |
| `pricing-mlops` | Operacion ML: componentes Azure ML, pipeline component, batch endpoint/deployment, smoke test y publicacion de artefactos. |

La regla practica es simple: si cambia la logica del notebook o del pipeline, se cambia en `pricing-mlops`; si cambia un recurso Azure base o permisos, se cambia en platform.

## Outputs De Platform Que Usa El Modelo

```text
AZURE_SUBSCRIPTION_ID
AZURE_TENANT_ID
AZURE_RESOURCE_GROUP
AZURE_STORAGE_ACCOUNT
AZURE_ML_WORKSPACE
AZURE_ML_JOB_IDENTITY_CLIENT_ID
MLOPS_ENVIRONMENT
MLOPS_RUN_OWNER
```

No se publican account keys, connection strings ni secretos.

## Contrato De Storage

`pricing-mlops` publica artefactos bajo el Storage MLOps principal usando la identidad del job:

```text
<container>/environment=<env>/compute=azure-ml/trigger=<trigger>/owner=<owner>/run_date=<yyyymmdd>/run_id=<run_id>/<artifact>
```

Contenedores esperados:

| Container | Uso |
|---|---|
| `raw-masked` | Inputs masked. |
| `curated` | Intermedios curados. |
| `baseline` | Baselines controlados. |
| `runs` | Logs de corrida y summaries. |
| `snapshots` | Snapshots funcionales. |
| `drift-logs` | Logs de drift/validity. |
| `reports` | Reportes markdown. |
| `artifacts` | Manifests y estado de componentes. |

## Contrato De Azure ML

`pricing-mlops` debe registrar el pipeline component antes de actualizar el endpoint:

```text
azureml:pricing_mlops_auth_monitoring_pipeline:<version>
```

Platform no referencia versiones concretas de componentes operativos. Esa version vive en el manifest de `pricing-mlops`.
