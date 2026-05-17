# Architecture

## Decision principal

Este repo es la plataforma del MVP: infraestructura Azure, contratos MLOps, scripts operativos, workflows de despliegue y documentacion.

La infraestructura se separa en dos capas:

| Capa | Ruta | Responsabilidad |
|---|---|---|
| Foundation | `infra/foundation/` | Base reusable de plataforma: Resource Groups, Key Vault, Log Analytics, identidades OIDC, RBAC base y budget. |
| Workload Pricing MLOps | `infra/workloads/pricing-mlops/` | Recursos especificos del flujo Pricing MLOps: Storage y Azure Function para health/model-flow. |

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
| Function App | Compute minimo del flujo: `/api/health` y `/api/model-flow` para validacion, curated, scoring y drift |

`data-lab` usa solo Storage/ADLS minimo para `raw-unmasked`, `raw-masked`, `curated` y artefactos MLOps. No despliega Function App y mantiene `raw-unmasked` separado de `staging`.

La Function App se crea por IaC en plataforma. El codigo runtime operativo se publica desde el repo `pricing-mlops`; GitHub Actions solo despliega el paquete e invoca `/api/model-flow`. El prototipo usa Azure Functions Consumption `Y1/Dynamic` por default para mantener costo bajo. Si la subscription tiene quota `Dynamic VMs = 0`, se debe solicitar quota o cambiar los parametros `functionPlanSku*` de forma explicita.

## RBAC

| Actor | Permisos iniciales |
|---|---|
| Admin cloud | Owner temporal para bootstrap local |
| Equipo tecnico | Contributor en ambientes de trabajo, Reader en shared |
| GitHub Actions plataforma | User Assigned Identity con OIDC y permisos suficientes para deployments subscription-scope |
| GitHub Actions `pricing-mlops` | User Assigned Identity separada con permiso para publicar Function App e invocar/verificar el flujo |
| Azure Function App | System assigned identity con `Storage Blob Data Contributor` sobre el Storage Account del workload |
| Negocio | Sin acceso directo a Azure en MVP |

El repo modelo no recibe `Owner`, no recibe `Contributor` sobre la subscription y no recibe acceso a `raw-unmasked`.

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
