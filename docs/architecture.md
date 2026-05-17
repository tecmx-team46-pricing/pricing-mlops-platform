# Architecture

## Decision principal

Este repo es la plataforma del MVP: infraestructura Azure, contratos MLOps, scripts operativos, workflows de despliegue y documentacion.

La infraestructura se separa en dos capas:

| Capa | Ruta | Responsabilidad |
|---|---|---|
| Foundation | `infra/foundation/` | Base reusable de plataforma: Resource Groups, Key Vault, Log Analytics, identidades OIDC, RBAC base y budget. |
| Workload Pricing MLOps | `infra/workloads/pricing-mlops/` | Recursos especificos del flujo Pricing MLOps: Storage/ADLS, Azure ML Workspace y Azure Functions como orquestador ligero. |

`mlops/` no contiene IaC. Contiene contratos, schemas, thresholds, reglas y documentacion del flujo del modelo.

## Subscription

El proyecto usa una sola subscription: `<azure-subscription-name>`.

Esta subscription aprovecha el credito incluido de 200 USD. No se crean subscriptions por ambiente porque eso agregaria gobierno, permisos y costos de operacion que el equipo no necesita todavia.

## Resource Groups

| Resource Group | Capa | Proposito | Lifecycle |
|---|---|---|---|
| `rg-pricing-mlops-platform-shared` | Foundation | Key Vault, Log Analytics, identidades OIDC | Permanente |
| `rg-pricing-mlops-data-lab` | Data lab | CSVs unmasked/masked, curated inicial y artefactos controlados sin compute MLOps/ADF/AML/SQL | Controlado |
| `rg-pricing-mlops-staging` | Workload | Storage, Azure ML Workspace y Function orquestadora del MVP | Permanente |
| `rg-pricing-mlops-sbx-local` | Workload | Sandbox personal temporal de un owner local | Temporal |
| `rg-pricing-mlops-validation` | Workload | Validacion controlada no productiva | Controlado |

No se despliega prod en el MVP. `shared` no es ambiente operativo de MLOps; es un scope comun para servicios reutilizables.

## Servicios compartidos

| Servicio | Capa | Justificacion |
|---|---|---|
| Key Vault | Foundation | Evitar secretos en GitHub o configs |
| Log Analytics | Foundation | Observabilidad tecnica minima |
| User Assigned Identities | Foundation | OIDC para GitHub Actions de plataforma y repo modelo |
| Budget | Foundation | Control de gasto de la subscription |

## Workload Pricing MLOps

| Servicio | Justificacion |
|---|---|
| Storage Account | Evidencia barata y simple para inputs, baselines, runs, snapshots, drift logs, reportes y artefactos |
| Azure Machine Learning Workspace | Compute ML principal para command jobs de validacion, curated/features, scoring minimo, drift/semaforo y escritura de artefactos |
| Azure Functions | Orquestador ligero para disparar jobs AML y exponer health/trigger controlado; no ejecuta scoring pesado |

`data-lab` usa solo Storage/ADLS minimo para `raw-unmasked`, `raw-masked`, `curated` y artefactos MLOps. No despliega compute del modelo y mantiene `raw-unmasked` separado de `staging`.

Azure ML se crea por IaC en plataforma. El codigo runtime operativo vive en el repo `pricing-mlops` y se ejecuta como command job. GitHub Actions solo somete el job y espera el estado; no ejecuta el ML en el runner. La Function queda preparada como trigger/orquestador, pero si la subscription sigue con quota App Service/Functions en `0`, GitHub Actions puede someter el job AML temporalmente.

Container Apps Job + ACR queda documentado como PoC anterior en [`compute-target-comparison.md`](compute-target-comparison.md). No se borra automaticamente; cualquier limpieza de ACR/Container Apps requiere confirmacion explicita.

## RBAC

| Actor | Permisos iniciales |
|---|---|
| Admin cloud | Owner temporal para bootstrap local |
| Equipo tecnico | Contributor en ambientes de trabajo, Reader en shared |
| GitHub Actions plataforma | User Assigned Identity con OIDC y permisos suficientes para deployments subscription-scope |
| GitHub Actions `pricing-mlops` | User Assigned Identity separada con permiso `AzureML Data Scientist` sobre el workspace y permiso de verificacion sobre Storage |
| Azure ML Workspace/Job | Managed Identity con `Storage Blob Data Contributor` sobre el Storage Account del workload |
| Azure Function | Managed Identity con permiso minimo para iniciar jobs AML y consultar Storage cuando la quota permita desplegarla |
| Negocio | Sin acceso directo a Azure en MVP |

El repo modelo no recibe `Owner`, no recibe `Contributor` sobre la subscription y no recibe acceso a `raw-unmasked`.

## Anti-patterns evitados

- Kubernetes.
- Azure Data Factory.
- Azure SQL.
- Hub-and-Spoke.
- Private Endpoints.
- Terraform y Ansible encima de Bicep.
- Repos por componente.
- Ambientes `dev`, `qa`, `uat`, `prod` sin uso real.
- Subscriptions separadas por ambiente.
- Retraining automatico.
- Endpoints online de Azure ML.
- Dashboards avanzados antes de tener logs confiables.
