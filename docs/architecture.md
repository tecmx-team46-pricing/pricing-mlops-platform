# Architecture

## Decision Actual

La base operativa actual usa:

```text
Azure Function -> Azure ML command job -> Storage/ADLS
```

Azure Functions orquesta y valida el request. Azure ML ejecuta validacion, curated/features, scoring minimo, drift/semaforo y escritura de outputs. Storage/ADLS conserva inputs masked y evidencia versionada.

La arquitectura distingue tres cuentas de Storage:

| Storage | Uso | Contrato |
|---|---|---|
| Storage MLOps principal `<mlops-storage-account>` | Data lake funcional MLOps. | Solo `raw-masked`, `curated`, `baseline`, `runs`, `snapshots`, `drift-logs`, `reports` y `artifacts`. No usa account keys. |
| Storage runtime Azure ML `stamlpmlopsstg<suffix>` | Infraestructura operativa interna de Azure ML. | Snapshots de codigo, logs internos AML, environments y artifacts runtime. Tag `purpose=azure-ml-runtime`. |
| Storage host Function `stfn<generated-suffix>` | Estado runtime de Azure Functions. | `AzureWebJobsStorage`; no es data lake ni artifact store AML. |

El workspace actual de `staging` fue creado con `<mlops-storage-account>` como storage asociado. La separacion completa de `workspaceblobstore`, `workspaceartifactstore`, `workspacefilestore` y `workspaceworkingdirectory` requiere crear un workspace nuevo apuntando al Storage runtime Azure ML. No se debe recrear ni borrar el workspace actual sin decision explicita.

GitHub Actions queda para CI/CD, validacion y despliegue controlado. No es compute ML ni orquestador operativo.

## Capas

| Capa | Ruta | Responsabilidad |
|---|---|---|
| Foundation | `infra/foundation/` | Resource Groups, Key Vault, Log Analytics, OIDC/RBAC base y budget opcional. |
| Workload | `infra/workloads/pricing-mlops/` | Storage/ADLS, Azure ML Workspace y Azure Function orquestadora. |
| Contratos MLOps | `mlops/` | Schemas, thresholds, storage layout y documentacion del flujo. No contiene IaC. |

## Ambientes

| Scope | Resource Group | Proposito | Datos unmasked |
|---|---|---|---|
| `shared` | `rg-pricing-mlops-platform-shared` | Servicios comunes; no es ambiente MLOps. | No |
| `data-lab` | `rg-pricing-mlops-data-lab` | Landing restringido para unmasked/masking. | Si, restringido |
| `sandbox-local` | `rg-pricing-mlops-sbx-local` | Pruebas local/admin temporales. | No |
| `staging` | `rg-pricing-mlops-staging` | Staging operativo compartido. | No |
| `validation` | `rg-pricing-mlops-validation` | No-prod controlado futuro. | No |

No existe `prod` en IaC, parameter files ni workflows.

## Servicios Activos

| Servicio | Resource Group | Estado | Notas |
|---|---|---|---|
| Key Vault | `rg-pricing-mlops-platform-shared` | Activo | Secrets/salts futuros, sin secretos en Git. |
| Log Analytics | `rg-pricing-mlops-platform-shared` | Activo | Observabilidad base. |
| User Assigned Identities | `rg-pricing-mlops-platform-shared` | Activo | OIDC para repos. |
| Storage / ADLS Gen2 | `rg-pricing-mlops-staging` | Activo | Data lake MLOps: `raw-masked`, `curated`, `runs`, `snapshots`, `drift-logs`, `reports`, `artifacts`. |
| Storage runtime Azure ML | `rg-pricing-mlops-staging` | Activo via IaC | Operacional: snapshots, logs, environments y artifacts internos AML. El workspace actual solo lo puede usar como default al crear un workspace nuevo. |
| Azure ML Workspace | `rg-pricing-mlops-staging` | Activo | Command jobs serverless/administrados, sin GPU ni endpoint online. El workspace actual conserva su storage asociado legacy. |
| Azure Function | `rg-pricing-mlops-staging` | Activo | `func-pricing-mlops-staging-<suffix>` en `centralus`, plan Y1/Dynamic. |

Storage y Azure ML de `staging` viven en `eastus2`. La Function vive en `centralus` porque `eastus2` presento quota 0 para App Service/Functions en esta subscription.

## Cleanup Legacy

La ruta activa en repo y documentacion es Function + Azure ML. La infraestructura de Container Apps del PoC anterior fue retirada del IaC activo y los recursos legacy de `staging` fueron eliminados:

| Recurso Azure | Estado |
|---|---|
| `cae-pricing-mlops-staging` | Eliminado. |
| `job-pricing-mlops-staging` | Eliminado. |
| `acr-pricing-mlops-legacy-<suffix>` | Eliminado. |
| `id-pricing-mlops-job-staging-legacy` | Eliminado. |
| `` | ACR asociado a Azure ML runtime; sigue siendo necesario para AML. |

No borrar ``: Azure ML lo usa como runtime interno.

## RBAC

| Actor | Permisos |
|---|---|
| GitHub Actions plataforma | OIDC para deployments controlados de infraestructura. |
| GitHub Actions `pricing-mlops` | OIDC para publicar Function o pruebas controladas; no Owner/Contributor de subscription. |
| Azure Function | Managed Identity con permiso para iniciar jobs AML y verificar Storage. |
| Azure ML job | Acceso a Storage por identidad; sin account keys. |

El Storage MLOps principal mantiene `allowSharedKeyAccess=false`. El Storage runtime Azure ML prefiere acceso por identidad; si Azure ML requiriera shared keys para un artifact store en una recreacion futura, esa excepcion se limita al Storage runtime y no aplica a datos MLOps.

## Separacion Azure ML Runtime

Microsoft documenta que el storage asociado del workspace se proporciona durante la creacion del workspace. Tambien documenta que ese storage guarda logs de jobs, notebooks, snapshots y otros artifacts internos de Azure ML. Por eso, para limpiar completamente `<mlops-storage-account>`, la opcion recomendada es:

1. Crear un workspace nuevo de staging, por ejemplo `mlw-pricing-mlops-staging-v2-<suffix>`, con `stamlpmlopsstg<suffix>` como `storageAccount`.
2. Registrar el Storage MLOps principal como datastore funcional externo para `raw-masked` y outputs.
3. Cambiar la Function al nuevo workspace.
4. Ejecutar E2E.
5. Clasificar containers legacy en `<mlops-storage-account>` y borrar solo con aprobacion explicita.

La opcion conservadora es mantener el workspace actual y usar lifecycle policy para artifacts internos legacy, sabiendo que AML seguira escribiendo runtime artifacts en el storage asociado actual.

El repo modelo no recibe acceso a `raw-unmasked`.

## Fuera De Alcance Actual

- ADF, Azure SQL, Private Endpoints, Hub-Spoke.
- Endpoints online AML, GPU, clusters persistentes.
- Produccion real.
