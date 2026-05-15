# Architecture

## Decision principal

Este repo es el monorepo del MVP: infraestructura Azure, contratos MLOps, scripts, workflows y documentacion.

La infraestructura se separa en dos capas:

| Capa | Ruta | Responsabilidad |
|---|---|---|
| Foundation | `infra/foundation/` | Base reusable de plataforma: Resource Groups, Key Vault, Log Analytics, identidades OIDC, RBAC base y budget. |
| Workload Pricing MLOps | `infra/workloads/pricing-mlops/` | Recursos especificos del flujo Pricing MLOps: Storage y Function App hello world. |

`mlops/` no contiene IaC. Contiene contratos, schemas, thresholds, reglas y documentacion del flujo del modelo.

## Subscription

El proyecto usa una sola subscription: `<azure-subscription-name>`.

Esta subscription aprovecha el credito incluido de 200 USD. No se crean subscriptions por ambiente porque eso agregaria gobierno, permisos y costos de operacion que el equipo no necesita todavia.

## Resource Groups

| Resource Group | Capa | Proposito | Lifecycle |
|---|---|---|---|
| `rg-pricing-mlops-platform-shared` | Foundation | Key Vault, Log Analytics, identidades OIDC | Permanente |
| `rg-pricing-mlops-data-lab` | Data lab | CSVs unmasked/masked, curated inicial y artefactos controlados sin Function/ADF/AML/SQL | Controlado |
| `rg-pricing-mlops-staging` | Workload | Storage y Function App del MVP | Permanente |
| `rg-pricing-mlops-sbx-david` | Workload | Sandbox personal temporal de David | Temporal |
| `rg-pricing-mlops-validation` | Workload | Validacion controlada no productiva | Controlado |

No se despliega prod en el MVP. `shared` no es ambiente operativo de MLOps; es un scope comun para servicios reutilizables.

## Servicios compartidos

| Servicio | Capa | Justificacion |
|---|---|---|
| Key Vault | Foundation | Evitar secretos en GitHub o configs |
| Log Analytics | Foundation | Observabilidad tecnica minima |
| User Assigned Identity | Foundation | OIDC para GitHub Actions |
| Budget | Foundation | Control de gasto de la subscription |

## Workload Pricing MLOps

| Servicio | Justificacion |
|---|---|
| Storage Account | Evidencia barata y simple para inputs, baselines, runs, snapshots, drift logs, reportes y artefactos |
| Function App | Prototipo hello world y punto futuro para health/drift endpoints |

`data-lab` usa solo Storage/ADLS minimo para `raw-unmasked`, `raw-masked`, `curated` y artefactos MLOps. No despliega Function App y mantiene `raw-unmasked` separado de `staging`.

La Function App se crea por IaC, pero el codigo runtime se publica desde `src/functions/pricing-mlops-hello/` con `scripts/publish-hello-function.sh`. El prototipo usa App Service Plan `B1` por defecto porque algunas subscriptions academicas bloquean Consumption y Free; si la subscription no tiene cuota `Basic VMs >= 1`, primero se debe solicitar cuota o cambiar los parametros `functionPlanSku*`.

## RBAC

| Actor | Permisos iniciales |
|---|---|
| Admin cloud | Owner temporal para bootstrap local |
| Equipo tecnico | Contributor en ambientes de trabajo, Reader en shared |
| GitHub Actions | User Assigned Identity con OIDC y Contributor a nivel subscription para deployments subscription-scope |
| Negocio | Sin acceso directo a Azure en MVP |

## Anti-patterns evitados

- Kubernetes.
- Azure ML workspace completo desde el inicio.
- Azure Data Factory.
- Azure SQL.
- Hub-and-Spoke.
- Private Endpoints.
- ACR.
- Terraform y Ansible encima de Bicep.
- Repos por componente.
- Ambientes `dev`, `qa`, `uat`, `prod` sin uso real.
- Subscriptions separadas por ambiente.
- Retraining automatico.
- Dashboards avanzados antes de tener logs confiables.
