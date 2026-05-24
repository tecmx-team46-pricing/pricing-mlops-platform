# Azure Services

## Staging

| Servicio | Recurso | Rol |
|---|---|---|
| Azure ML Workspace | `mlw-pricing-mlops-staging-<suffix>` | Ejecuta command jobs serverless/administrados. |
| Storage MLOps | `<mlops-storage-account>` | Data lake funcional: inputs masked y outputs MLOps. |
| Storage runtime Azure ML | `stamlpmlopsstg<suffix>` | Infraestructura operativa interna AML para workspaces nuevos. |
| Storage host Function | `stfn<generated-suffix>` | Estado runtime de Azure Functions. |
| Function App | `func-pricing-mlops-staging-<suffix>` | Orquesta requests hacia Azure ML. |
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
- blobstore/default datastore de Azure ML en un workspace nuevo

El workspace actual fue creado con `<mlops-storage-account>` como storage asociado. No cambiar ni recrear ese workspace sin decision explicita; la separacion completa requiere crear un workspace nuevo con el Storage runtime como `storageAccount`.

## Function Host Storage

`stfn<generated-suffix>` es solo host state de Azure Functions (`AzureWebJobsStorage`). Puede tener configuracion distinta porque Functions Consumption necesita connection string de host. No se usa para datos MLOps ni outputs funcionales.

## RBAC

| Principal | Permiso |
|---|---|
| Azure ML workspace managed identity | Blob/File contributor en Storage runtime AML; permisos legacy en storage asociado actual mientras exista. |
| Azure ML job identity | Blob contributor en Storage MLOps para leer `raw-masked` y escribir outputs funcionales; Blob contributor en Storage runtime AML para operacion futura. |
| Function managed identity | AzureML Data Scientist en workspace y Blob contributor en Storage MLOps. |

No dar Owner ni Contributor de subscription para operar el flujo.
