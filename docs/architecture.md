# Architecture

## Decision Actual

El MVP operativo usa:

```text
Azure Function -> Azure ML command job -> Storage/ADLS
```

Azure Functions orquesta y valida el request. Azure ML ejecuta validacion, curated/features, scoring minimo, drift/semaforo y escritura de outputs. Storage/ADLS conserva inputs masked y evidencia versionada.

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
| `staging` | `rg-pricing-mlops-staging` | MVP operativo compartido. | No |
| `validation` | `rg-pricing-mlops-validation` | No-prod controlado futuro. | No |

No existe `prod` en IaC, parameter files ni workflows.

## Servicios Activos

| Servicio | Resource Group | Estado | Notas |
|---|---|---|---|
| Key Vault | `rg-pricing-mlops-platform-shared` | Activo | Secrets/salts futuros, sin secretos en Git. |
| Log Analytics | `rg-pricing-mlops-platform-shared` | Activo | Observabilidad base. |
| User Assigned Identities | `rg-pricing-mlops-platform-shared` | Activo | OIDC para repos. |
| Storage / ADLS Gen2 | `rg-pricing-mlops-staging` | Activo | `raw-masked`, `curated`, `runs`, `snapshots`, `drift-logs`, `reports`, `artifacts`. |
| Azure ML Workspace | `rg-pricing-mlops-staging` | Activo | Command jobs serverless/administrados, sin GPU ni endpoint online. |
| Azure Function | `rg-pricing-mlops-staging` | Activo | `func-pricing-mlops-staging-<suffix>` en `centralus`, plan Y1/Dynamic. |

Storage y Azure ML de `staging` viven en `eastus2`. La Function vive en `centralus` porque `eastus2` presento quota 0 para App Service/Functions en esta subscription.

## Drift Azure vs Repo

La ruta activa en repo y documentacion es Function + Azure ML. En Azure todavia existen recursos legacy del PoC Container Apps/ACR:

| Recurso Azure | Estado |
|---|---|
| `cae-pricing-mlops-staging` | Legacy PoC, no ruta activa. |
| `job-pricing-mlops-staging` | Legacy PoC, no ruta activa. |
| `acr-pricing-mlops-legacy-<suffix>` | Legacy PoC de Container Apps. |
| `id-pricing-mlops-job-staging-legacy` | Legacy PoC de Container Apps. |
| `` | ACR asociado a Azure ML runtime; sigue siendo necesario para AML. |

No borrar recursos legacy sin confirmacion explicita. La limpieza futura debe ejecutar `what-if`, estimar costo y confirmar que no afecta Azure ML.

## RBAC

| Actor | Permisos |
|---|---|
| GitHub Actions plataforma | OIDC para deployments controlados de infraestructura. |
| GitHub Actions `pricing-mlops` | OIDC para publicar Function o pruebas controladas; no Owner/Contributor de subscription. |
| Azure Function | Managed Identity con permiso para iniciar jobs AML y verificar Storage. |
| Azure ML job | Acceso a Storage por identidad; sin account keys. |

El repo modelo no recibe acceso a `raw-unmasked`.

## Fuera De Alcance Actual

- ADF, Azure SQL, Private Endpoints, Hub-Spoke.
- Endpoints online AML, GPU, clusters persistentes.
- Produccion real.
