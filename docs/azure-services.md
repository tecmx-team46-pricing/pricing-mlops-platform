# Azure Services

## Staging

| Servicio | Recurso | Rol |
|---|---|---|
| Azure ML Workspace activo | `mlw-pricing-mlops-stg-v2-<suffix>` | Ejecuta pipeline/job serverless/administrado. Usa `stamlpmlopsstg<suffix>` como storage asociado. |
| Azure ML Workspace legacy | `mlw-pricing-mlops-staging-<suffix>` | Workspace anterior. Conserva datastores internos en `<mlops-storage-account>`; no borrar sin aprobacion. |
| Storage MLOps | `<mlops-storage-account>` | Data lake funcional: inputs masked y outputs MLOps. |
| Storage runtime Azure ML | `stamlpmlopsstg<suffix>` | Infraestructura operativa interna AML para el workspace v2 activo. |
| Storage host Function | `stfn<generated-suffix>` | Estado runtime de Azure Functions. |
| Function App | `func-pricing-mlops-staging-<suffix>` | Orquesta requests hacia Azure ML. |
| Event Grid subscription | `evg-func-pricing-mlops-staging-<suffix>-blob-created` | Dispara la Function para BlobCreated bajo `raw-masked/incoming/*.csv`. |
| Table run index | `mlopsruns` | Metadata consultable de corridas, sin account keys. |
| Azure SQL audit | `sql-pricing-mlops-staging-<suffix>` / `pricing_mlops_audit` | Espina dorsal de auditoria con metadata de corrida y snapshots. No almacena CSVs ni artifacts grandes. |
| ACR AML | `` | Registry asociado a Azure ML runtime. |

## Storage MLOps

`<mlops-storage-account>` debe ser facil de leer como data lake MLOps. Containers esperados:

```text
raw-masked
curated
baseline
runs
snapshots
drift-logs
reports
artifacts
```

Seguridad:

- `allowBlobPublicAccess=false`
- `allowSharedKeyAccess=false`
- acceso por identidad administrada/RBAC
- no `raw-unmasked` en `staging`

## Storage Runtime Azure ML

El Storage runtime Azure ML usa `Standard_LRS`, acceso publico deshabilitado y tags:

```text
environment=staging
owner=team46
purpose=azure-ml-runtime
lifecycle=permanent
workload=pricing-mlops
data_classification=operational-metadata
```

Uso previsto:

- snapshots de codigo
- logs internos de Azure ML
- environments
- job artifacts internos
- blobstore/default datastore de Azure ML en el workspace v2 activo

El workspace v2 activo usa este Storage runtime como `storageAccount`. El workspace legacy fue creado con `<mlops-storage-account>` como storage asociado; no cambiar, recrear ni borrar ese workspace sin decision explicita.

## Function Host Storage

`stfn<generated-suffix>` es solo host state de Azure Functions (`AzureWebJobsStorage`). Puede tener configuracion distinta porque Functions Consumption necesita connection string de host. No se usa para datos MLOps ni outputs funcionales.

## Azure SQL Audit

`pricing_mlops_audit` complementa Storage Blob y Table `mlopsruns`. Su alcance es metadata consultable:

- `dbo.model_run_log`
- `dbo.model_output_snapshot_metadata`
- `dbo.data_quality_log`

Los outputs funcionales siguen en Storage MLOps (`runs`, `snapshots`, `drift-logs`, `reports`, `artifacts`, `curated`). SQL usa Microsoft Entra auth; no se usan account keys ni connection strings para datos MLOps.

SQL está en `centralus` porque `eastus2` rechazo nuevas altas de SQL Server para esta suscripcion. Existe una regla `AllowAllWindowsAzureIps` para permitir acceso desde Azure ML/Functions en el MVP sin private endpoints. La regla `AllowLocalMigrationClient` se uso para migracion local y debe eliminarse cuando ya no haga falta diagnostico local.

## RBAC

| Principal | Permiso |
|---|---|
| Azure ML workspace v2 managed identity | Blob/File contributor en Storage runtime AML. |
| Azure ML workspace legacy managed identity | Permisos legacy en el storage asociado anterior mientras exista. |
| Azure ML job identity | Blob contributor en Storage MLOps para leer `raw-masked` y escribir outputs funcionales; Blob contributor en Storage runtime AML para operacion futura. |
| Azure ML job identity | Usuario Entra en Azure SQL audit con `db_datareader` y `db_datawriter`. |
| Function managed identity | AzureML Data Scientist en workspace y Blob contributor en Storage MLOps. |
| Function managed identity | Table Data Contributor en Storage MLOps para `mlopsruns`. |

No dar Owner ni Contributor de subscription para operar el flujo.
