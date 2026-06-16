# Legacy Resource Inventory

Fecha de inventario: 2026-05-24.

Este documento separa recursos activos, legacy conservados y recursos legacy eliminados. No autoriza borrados por si mismo.

## Ruta Activa

| Recurso | Tipo | Estado | Uso |
|---|---|---|---|
| `mlw-pricing-mlops-stg-v2-<suffix>` | Azure ML Workspace | Existe | Workspace activo para command jobs. |
| `<mlops-storage-account>` | Storage Account | Existe | Storage MLOps funcional: inputs masked y outputs versionados. |
| `stamlpmlopsstg<suffix>` | Storage Account | Existe | Storage runtime del workspace Azure ML activo. |
| `` | Azure Container Registry | Existe | ACR asociado al runtime interno de Azure ML; no es ACR legacy de Container Apps. |

## Legacy Conservado

| Recurso | Tipo | Estado | Referencia | Borrado |
|---|---|---|---|---|
| `mlw-pricing-mlops-staging-<suffix>` | Azure ML Workspace | Existe | Workspace anterior. Conserva datastores/artifacts internos en `<mlops-storage-account>`. | Requiere aprobacion explicita despues de confirmar que no se necesita rollback. |
| `func-pricing-mlops-staging-<suffix>` | Function App | Puede existir | Orquestador anterior. Ya no se despliega desde IaC activo. | Requiere aprobacion explicita despues de confirmar que el batch pipeline endpoint cubre la operacion. |
| `stfn<generated-suffix>` | Storage Account | Puede existir | Host state de la Function anterior. Ya no se despliega desde IaC activo. | Requiere aprobacion explicita junto con la Function. |

## Legacy Eliminado

| Recurso | Tipo | Estado | Comando si reaparece |
|---|---|---|---|
| `cae-pricing-mlops-staging` | Container Apps Environment | No existe | `az containerapp env delete --resource-group rg-pricing-mlops-staging --name cae-pricing-mlops-staging --yes` |
| `job-pricing-mlops-staging` | Container Apps Job | No existe | `az containerapp job delete --resource-group rg-pricing-mlops-staging --name job-pricing-mlops-staging --yes` |
| `id-pricing-mlops-job-staging-legacy-legacy` | Managed Identity | No existe | `az identity delete --resource-group rg-pricing-mlops-staging --name id-pricing-mlops-job-staging-legacy-legacy` |
| `acr-pricing-mlops-legacy-<suffix>` | Azure Container Registry | No existe | `az acr delete --resource-group rg-pricing-mlops-staging --name acr-pricing-mlops-legacy-<suffix> --yes` |

## Containers Observados

`<mlops-storage-account>`:

```text
artifacts
azureml
baseline
curated
drift-logs
input
insights-logs-auditevent
insights-metrics-pt1m
raw-masked
reports
runs
snapshots
```

`azureml`, `insights-*` y containers internos similares son runtime/diagnostico; no son outputs funcionales del modelo. No borrarlos sin una decision explicita de retencion.

`stamlpmlopsstg<suffix>`:

```text
azureml
azureml-blobstore-<active-workspace-guid>
<active-workspace-guid>-phptftdcismzwd139t8ca06c92
<active-workspace-guid>-r1d9rqkgn4h2hc7mox2levs7sp
revisions
snapshots
snapshotzips
```

Estos containers pertenecen al runtime del workspace Azure ML activo.
