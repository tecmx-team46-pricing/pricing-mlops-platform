# Architecture

## Decision Actual

La base operativa actual usa:

```text
Manual: Azure Function HTTP -> Azure ML pipeline job -> Storage/ADLS
Automatico: BlobCreated raw-masked/incoming/*.csv -> Event Grid -> Azure Function -> Azure ML pipeline job -> Storage/ADLS
```

Azure Functions orquesta y valida el request o evento. Azure ML ejecuta validacion, curated/features, scoring minimo, drift/semaforo y escritura de outputs desde el snapshot del repo `pricing-mlops`. Storage/ADLS conserva inputs masked y evidencia versionada. Azure Table `mlopsruns` y Azure SQL audit guardan metadata consultable de corridas.

La arquitectura distingue tres cuentas de Storage:

| Storage | Uso | Contrato |
|---|---|---|
| Storage MLOps principal `<mlops-storage-account>` | Data lake funcional MLOps. | Solo `raw-masked`, `curated`, `baseline`, `runs`, `snapshots`, `drift-logs`, `reports` y `artifacts`. No usa account keys. |
| Storage runtime Azure ML `stamlpmlopsstg<suffix>` | Infraestructura operativa interna de Azure ML. | Snapshots de codigo, logs internos AML, environments y artifacts runtime. Tag `purpose=azure-ml-runtime`. |
| Storage host Function `stfn<generated-suffix>` | Estado runtime de Azure Functions. | `AzureWebJobsStorage`; no es data lake ni artifact store AML. |

Azure SQL audit (`sql-pricing-mlops-staging-<suffix>` / `pricing_mlops_audit`) es metadata-only. No reemplaza Storage Blob ni guarda datasets completos; sirve para consultar `model_run_log`, `model_output_snapshot_metadata` y `data_quality_log`.

El workspace activo de `staging` es `mlw-pricing-mlops-stg-v2-<suffix>` y usa `stamlpmlopsstg<suffix>` como storage asociado. El workspace original `mlw-pricing-mlops-staging-<suffix>` fue creado con `<mlops-storage-account>` como storage asociado y queda como legacy para rollback o auditoria; no se debe recrear ni borrar sin decision explicita.

GitHub Actions queda para CI/CD, validacion y despliegue controlado. No es compute ML ni orquestador operativo.

## Capas

| Capa | Ruta | Responsabilidad |
|---|---|---|
| Foundation | `infra/foundation/` | Resource Groups, Key Vault, Log Analytics, OIDC/RBAC base y budget opcional. |
| Workload | `infra/workloads/pricing-mlops/` | Storage/ADLS, Azure ML Workspace y Azure Function App. |
| Runtime MLOps | `mlops/functions/`, `mlops/azureml/`, `mlops/scripts/` | Codigo de Azure Function, definicion del pipeline/job AML, publicacion y operacion del flujo remoto. |
| Contratos MLOps | `mlops/configs/`, `mlops/schemas/`, `mlops/docs/` | Schemas, thresholds, storage layout y documentacion del flujo. No contiene IaC. |

`pricing-mlops` queda como repo funcional/data science alineado con Cookiecutter Data Science. El script de publicacion de plataforma empaqueta un snapshot de ese repo en `pricing-mlops-source/`; el pipeline `mlops/azureml/pricing-mlops-pipeline.yml` usa `code: ../pricing-mlops-source` y muestra tres nodos: `validate_prepare`, `score_evaluate` y `publish_outputs`. El command job `mlops/azureml/pricing-mlops-job.yml` queda como fallback.

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
| Storage runtime Azure ML | `rg-pricing-mlops-staging` | Activo via IaC | Operacional: snapshots, logs, environments y artifacts internos AML para el workspace v2 activo. |
| Azure ML Workspace v2 | `rg-pricing-mlops-staging` | Activo | `mlw-pricing-mlops-stg-v2-<suffix>`; pipeline/component jobs serverless/administrados, sin GPU ni endpoint online. Usa Storage runtime Azure ML como storage asociado. |
| Azure ML Workspace legacy | `rg-pricing-mlops-staging` | Legacy | `mlw-pricing-mlops-staging-<suffix>`; conserva datastores internos en el Storage MLOps principal. No borrar sin aprobacion. |
| Azure Function | `rg-pricing-mlops-staging` | Activo | `func-pricing-mlops-staging-<suffix>` en `centralus`, plan Y1/Dynamic. |
| Event Grid subscription | `rg-pricing-mlops-staging` | Activo via IaC | Filtra `Microsoft.Storage.BlobCreated` bajo `raw-masked/incoming/*.csv` y dispara la Function. |
| Azure Table `mlopsruns` | `rg-pricing-mlops-staging` | Activo via IaC | Indice consultable de corridas; fallback JSON bajo `runs` si Table no esta disponible. |
| Azure SQL audit | `rg-pricing-mlops-staging` | Activo via IaC + migracion | `sql-pricing-mlops-staging-<suffix>` en `centralus`, DB `pricing_mlops_audit`, metadata-only. |

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
| GitHub Actions plataforma | OIDC para deployments controlados de infraestructura y, si se habilita, runtime MLOps. |
| GitHub Actions `pricing-mlops` | CI del codigo funcional/data science; no Owner/Contributor de subscription. |
| Azure Function | Managed Identity con permiso para iniciar jobs AML, leer/escribir Storage MLOps y escribir Table `mlopsruns`. |
| Azure ML job | Acceso a Storage por identidad; sin account keys. |

El Storage MLOps principal mantiene `allowSharedKeyAccess=false`. El Storage runtime Azure ML prefiere acceso por identidad; si Azure ML requiriera shared keys para un artifact store en una recreacion futura, esa excepcion se limita al Storage runtime y no aplica a datos MLOps.

## Separacion Azure ML Runtime

Microsoft documenta que el storage asociado del workspace se proporciona durante la creacion del workspace. Tambien documenta que ese storage guarda logs de jobs, notebooks, snapshots y otros artifacts internos de Azure ML. Por eso, `staging` usa un workspace v2 asociado al Storage runtime Azure ML:

1. Crear `mlw-pricing-mlops-stg-v2-<suffix>` con `stamlpmlopsstg<suffix>` como `storageAccount`.
2. Mantener `<mlops-storage-account>` como Storage MLOps funcional externo para `raw-masked` y outputs.
3. Cambiar la Function al workspace v2 mediante `AZURE_ML_WORKSPACE`.
4. Ejecutar E2E.
5. Clasificar containers legacy en `<mlops-storage-account>` y borrar solo con aprobacion explicita.

Rollback conservador: volver `AZURE_ML_WORKSPACE` a `mlw-pricing-mlops-staging-<suffix>` y ejecutar E2E antes de cualquier limpieza.

El repo modelo no recibe acceso a `raw-unmasked`.

## Fuera De Alcance Actual

- ADF, Private Endpoints, Hub-Spoke.
- Endpoints online AML, GPU, clusters persistentes.
- Produccion real.
