# Architecture

## Decision principal

Este repo es el monorepo del MVP: infraestructura Azure, contratos MLOps, scripts, workflows y documentacion.

Separar repos en este momento agregaria coordinacion sin mejorar la operacion.

## Subscription

El proyecto usa una sola subscription: `<azure-subscription-name>`.

Esta subscription aprovecha el credito incluido de 200 USD. No se crean subscriptions por ambiente porque eso seria innecesario para el MVP y agregaria gobierno, permisos y costos de operacion que el equipo no necesita todavia.

La separacion minima se hace asi:

| Nivel | Decision MVP |
|---|---|
| Subscription | Una sola: `<azure-subscription-name>` |
| Resource Groups permanentes | Shared y staging |
| Sandbox | Resource Groups temporales |
| Validation | No productivo, controlado y futuro |
| Prod | Conceptual, no desplegado |
| Budget | Alerta a nivel subscription |

## Resource Groups

| Resource Group | Proposito | Lifecycle |
|---|---|---|
| `rg-pricing-mlops-platform-shared` | Key Vault, Log Analytics, identidad OIDC | Permanente |
| `rg-pricing-mlops-staging` | Storage y evidencia de corridas staging | Permanente |
| `rg-pricing-mlops-sbx-david` | Sandbox personal temporal de David | Temporal |
| `rg-pricing-mlops-validation` | Validacion controlada no productiva | Controlado |
| `rg-pricing-mlops-sbx-<owner>-<yyyymmdd>` | Experimentos temporales | Temporal |

No se despliega prod en el MVP. `shared` tampoco es un ambiente operativo de MLOps; es un scope comun para servicios reutilizados por los ambientes permitidos.

## Servicios compartidos

| Servicio | Justificacion |
|---|---|
| Key Vault | Evitar secretos en GitHub o configs |
| Storage Account | Evidencia barata y simple |
| Log Analytics | Observabilidad tecnica minima |
| Budget | Control de gasto de la cuenta Azure |

## RBAC

| Actor | Permisos iniciales |
|---|---|
| Admin cloud | Owner temporal para primer despliegue |
| Equipo tecnico | Contributor en staging, Reader en shared |
| GitHub Actions | Una User Assigned Identity con OIDC |
| Negocio | Sin acceso directo a Azure en MVP |

## Anti-patterns evitados

- Kubernetes.
- Azure ML workspace completo desde el inicio.
- Terraform y Ansible encima de Bicep.
- Repos por componente.
- Ambientes `dev`, `qa`, `uat`, `prod` sin uso real.
- Subscriptions separadas por ambiente.
- Retraining automatico.
- Dashboards avanzados antes de tener logs confiables.
