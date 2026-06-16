# Servicios Azure

Esta pagina traduce la arquitectura a recursos concretos de Azure.

## Staging

| Servicio | Recurso | Rol |
|---|---|---|
| Azure ML Workspace activo | `mlw-...` | Control plane donde `pricing-mlops` registra componentes y ejecuta jobs. |
| Azure ML Workspace legacy | `mlw-...` | Workspace anterior. No borrar sin aprobacion. |
| Storage MLOps | `st...` | Data lake funcional: inputs masked y outputs MLOps. |
| Storage runtime Azure ML | `staml...` | Infraestructura interna AML: logs, snapshots, environments y job artifacts. |
| Managed Identity AML job | `id-pricing-mlops-aml-...` | Identidad usada por jobs para leer/escribir Storage. |
| GitHub OIDC identities | `id-gha-...` | Deploy de platform y registro/deploy operativo desde `pricing-mlops`. |

## Storage MLOps

Containers esperados:

```text
input
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

- `allowBlobPublicAccess=false`;
- `allowSharedKeyAccess=false`;
- acceso por identidad administrada/RBAC;
- no `raw-unmasked` en `staging`.

## Storage Runtime Azure ML

Se usa para separar artefactos internos de Azure ML de los outputs funcionales del proyecto:

- snapshots de codigo;
- logs internos de Azure ML;
- environments;
- job artifacts internos;
- blobstore/default datastore del workspace.

## RBAC

| Principal | Permiso |
|---|---|
| GitHub Actions platform | Permisos para deployments de infraestructura. |
| GitHub Actions `pricing-mlops` | Permisos para registrar componentes, crear endpoint/deployment e invocar jobs. |
| Azure ML job identity | Blob contributor en Storage MLOps y acceso requerido al workspace. |
| Azure ML workspace identity | Permisos sobre storage runtime AML. |

No dar Owner ni Contributor de subscription para operar el flujo ML.
