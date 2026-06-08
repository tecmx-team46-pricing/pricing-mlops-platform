# Plataforma MLOps Para Pricing Intelligence

Esta documentacion explica como se construyo una base MLOps en Azure para operar y auditar un flujo de Pricing Intelligence con datos masked.

La respuesta del MVP fue construir una base MLOps en Azure:

```text
Evento o solicitud manual
-> Azure Function
-> Azure ML Pipeline
-> Storage/ADLS
-> Azure SQL audit
```

La Function no calcula precios. Orquesta. Azure ML ejecuta el flujo funcional. Storage conserva los artefactos. SQL guarda metadata consultable. GitHub Actions valida y despliega de forma controlada, pero no opera el modelo.

## Que Cubre El Proyecto

Este avance no presenta una plataforma productiva. Presenta un MVP que cubre:

- infraestructura Azure reproducible con Bicep;
- separacion entre plataforma y codigo data science;
- corrida end-to-end con datos masked;
- outputs versionados en Storage;
- metadata auditable en Azure SQL;
- controles para no operar `raw-unmasked` en `staging`;
- un roadmap para integrar controles y componentes adicionales.

## Como Leer La Documentacion

Para entender el proyecto en orden:

1. [Contexto y problema](contexto-problema.md)
2. [Objetivos y alcance](objetivos-alcance.md)
3. [Reporte de avance](reporte-avance-proyecto-integrador.md)
4. [Arquitectura](architecture.md)
5. [Estructura del repo](project-structure.md)
6. [Evidencia del MVP](evidencia.md)
7. [Gobierno de datos](data-governance-plan.md)
8. [Roadmap](roadmap.md)

Si necesitas operar o revisar detalles tecnicos, salta a:

| Necesidad | Documento |
|---|---|
| Entender servicios Azure | [Servicios Azure](azure-services.md) |
| Ejecutar o diagnosticar el flujo | [Operacion](operations.md) |
| Revisar contrato plataforma-modelo | [Contrato plataforma-modelo](platform-model-operating-contract.md) |
| Revisar Function y pipeline | [Function orchestrator](function-orchestrator.md), [Pipeline Azure ML](azure-ml-job-contract.md) |
| Consultar auditoria | [Auditoria SQL](sql-audit-runbook.md) |

## Repositorios Del Proyecto

| Repo | Rol |
|---|---|
| `pricing-mlops-platform` | Plataforma Azure, IaC, RBAC/OIDC, Storage, Azure ML, Function, runtime MLOps y documentacion operativa. |
| `pricing-mlops` | Codigo funcional/data science: validacion, curated, scoring, drift y reportes. |
| `pricing-mlops-eda` | Referencia historica y analisis exploratorio. No es repo operativo. |

## Limites Del MVP

El MVP no contiene produccion real ni un modelo productivo definitivo. Tampoco incluye ADF, endpoints online de Azure ML, Private Endpoints o Hub-Spoke. La etapa actual se limita a operar el flujo, guardar evidencia y dejar preparada la integracion posterior de un modelo formal.

Siguiente lectura recomendada: [Contexto y problema](contexto-problema.md).
