# Documentation Index

Ruta corta para entender el repo sin leer planes historicos.

| Documento | Uso |
|---|---|
| [`../README.md`](../README.md) | Resumen, comandos principales y alcance. |
| [`architecture.md`](architecture.md) | Arquitectura actual, ambientes, servicios Azure y drift contra lo desplegado. |
| [`operations.md`](operations.md) | Runbook de validacion, deploy, portal, costos y operacion diaria. |
| [`github-actions.md`](github-actions.md) | Workflows vigentes, OIDC y reglas de PR/deploy. |
| [`platform-model-operating-contract.md`](platform-model-operating-contract.md) | Contrato entre plataforma y repo funcional. |
| [`data-governance-plan.md`](data-governance-plan.md) | Zonas de datos, acceso y retencion. |
| [`roadmap.md`](roadmap.md) | Siguientes pasos y fases. |
| [`reporte-avance-proyecto-integrador.md`](reporte-avance-proyecto-integrador.md) | Reporte academico de avance; conserva el contexto historico de MVP. |
| [`original/technical-design-original.md`](original/technical-design-original.md) | Diseno tecnico original del PDF, preservado como referencia historica. |

## Repos

| Repo | Rol |
|---|---|
| `pricing-mlops-platform` | Azure, IaC, RBAC/OIDC, Storage, Azure ML, Function y runbooks. |
| `pricing-mlops` | Validacion, curated, scoring, drift, reportes y script operativo. |
| `pricing-mlops-eda` | Referencia historica/EDA. No es repo operativo. |

## Archivo

Los documentos redundantes y planes largos se retiraron de la ruta activa. Si hace falta consultar un estado anterior, usar el historial de Git. [`archive/README.md`](archive/README.md) conserva esta regla.
