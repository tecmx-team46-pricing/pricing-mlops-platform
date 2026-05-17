# Architecture

## Decision principal

Este repo es la plataforma del MVP: infraestructura Azure, contratos MLOps, scripts operativos, workflows de despliegue y documentacion.

La infraestructura se separa en dos capas:

| Capa | Ruta | Responsabilidad |
|---|---|---|
| Foundation | `infra/foundation/` | Base reusable de plataforma: Resource Groups, Key Vault, Log Analytics, identidades OIDC, RBAC base y budget. |
| Workload Pricing MLOps | `infra/workloads/pricing-mlops/` | Recursos especificos del flujo Pricing MLOps: Storage, Azure Container Registry y Container Apps Job para ejecutar el flujo minimo. |

`mlops/` no contiene IaC. Contiene contratos, schemas, thresholds, reglas y documentacion del flujo del modelo.

## Subscription

El proyecto usa una sola subscription: `<azure-subscription-name>`.

Esta subscription aprovecha el credito incluido de 200 USD. No se crean subscriptions por ambiente porque eso agregaria gobierno, permisos y costos de operacion que el equipo no necesita todavia.

## Resource Groups

| Resource Group | Capa | Proposito | Lifecycle |
|---|---|---|---|
| `rg-pricing-mlops-platform-shared` | Foundation | Key Vault, Log Analytics, identidades OIDC | Permanente |
| `rg-pricing-mlops-data-lab` | Data lab | CSVs unmasked/masked, curated inicial y artefactos controlados sin compute MLOps/ADF/AML/SQL | Controlado |
| `rg-pricing-mlops-staging` | Workload | Storage, ACR y Container Apps Job del MVP | Permanente |
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
| Azure Container Registry Basic | Registro barato para la imagen del repo `pricing-mlops` |
| Azure Container Apps Job | Compute minimo del flujo: validacion, curated, scoring, drift y escritura de artefactos |

`data-lab` usa solo Storage/ADLS minimo para `raw-unmasked`, `raw-masked`, `curated` y artefactos MLOps. No despliega compute del modelo y mantiene `raw-unmasked` separado de `staging`.

El Container Apps Job se crea por IaC en plataforma. El codigo runtime operativo se empaqueta como imagen desde el repo `pricing-mlops`; GitHub Actions solo publica la imagen en ACR, inicia el job y verifica outputs. El prototipo usa ACR Basic y un job manual de baja capacidad (`0.25` CPU, `0.5Gi`) para mantener costo bajo.

La comparacion Functions vs Container Apps Job se documenta en [`compute-target-comparison.md`](compute-target-comparison.md). Mientras `staging` sea el ambiente estable, los experimentos deben separar evidencia con `compute=functions` o `compute=container-job` en Storage y no crear sandboxes personales.

## RBAC

| Actor | Permisos iniciales |
|---|---|
| Admin cloud | Owner temporal para bootstrap local |
| Equipo tecnico | Contributor en ambientes de trabajo, Reader en shared |
| GitHub Actions plataforma | User Assigned Identity con OIDC y permisos suficientes para deployments subscription-scope |
| GitHub Actions `pricing-mlops` | User Assigned Identity separada con `AcrPush` sobre ACR, `Container Apps Jobs Operator` sobre el job y permiso de verificacion sobre Storage |
| Container Apps Job | User Assigned Identity con `AcrPull` sobre ACR y `Storage Blob Data Contributor` sobre el Storage Account del workload |
| Negocio | Sin acceso directo a Azure en MVP |

El repo modelo no recibe `Owner`, no recibe `Contributor` sobre la subscription y no recibe acceso a `raw-unmasked`.

## Anti-patterns evitados

- Kubernetes.
- Azure ML workspace completo desde el inicio.
- Azure Data Factory.
- Azure SQL.
- Hub-and-Spoke.
- Private Endpoints.
- Terraform y Ansible encima de Bicep.
- Repos por componente.
- Ambientes `dev`, `qa`, `uat`, `prod` sin uso real.
- Subscriptions separadas por ambiente.
- Retraining automatico.
- Dashboards avanzados antes de tener logs confiables.
