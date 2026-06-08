# Plataforma MLOps Para Pricing Intelligence

Documentacion academica del proyecto integrador Team 46.

## Resumen

Este proyecto implementa una base operativa MLOps para un caso de Pricing Intelligence en Azure. La plataforma separa infraestructura, orquestacion, ejecucion del flujo ML, evidencia y gobierno de datos para que las corridas sean trazables, reproducibles y auditables.

El MVP actual valida el approach:

```text
Azure Function -> Azure ML Pipeline -> Storage/ADLS -> Azure SQL audit
```

GitHub Actions queda como mecanismo de validacion y despliegue controlado. No opera el flujo ML ni ejecuta el modelo.

## Que Se Construyo

| Area | Resultado |
|---|---|
| Plataforma Azure | Infraestructura reproducible con Bicep para resource groups, Storage, Azure ML, Azure Function, identidades, SQL audit y observabilidad base. |
| Orquestacion | Azure Function con endpoint HTTP y trigger Event Grid para disparar corridas de Azure ML. |
| Ejecucion ML | Pipeline Azure ML con tres pasos: `validate_prepare`, `score_evaluate` y `publish_outputs`. |
| Evidencia | Outputs versionados en Storage: logs, snapshots, drift logs, reportes, curated data y artefactos. |
| Auditoria | Azure SQL metadata-only para consultar corridas y snapshots sin guardar datasets completos. |
| Gobierno | Separacion entre datos masked y unmasked; `staging` no guarda `raw-unmasked`. |

## Ruta Recomendada De Lectura

1. [Contexto y problema](contexto-problema.md)
2. [Objetivos y alcance](objetivos-alcance.md)
3. [Reporte de avance](reporte-avance-proyecto-integrador.md)
4. [Arquitectura](architecture.md)
5. [Estructura del repo](project-structure.md)
6. [Operacion](operations.md)
7. [Evidencia del MVP](evidencia.md)
8. [Gobierno de datos](data-governance-plan.md)
9. [Roadmap](roadmap.md)

## Repositorios Del Proyecto

| Repo | Rol |
|---|---|
| `pricing-mlops-platform` | Plataforma Azure, IaC, RBAC/OIDC, Storage, Azure ML, Function, runtime MLOps y documentacion operativa. |
| `pricing-mlops` | Codigo funcional/data science: validacion, curated, scoring, drift y reportes. |
| `pricing-mlops-eda` | Referencia historica y analisis exploratorio. No es repo operativo. |

## Estado Del MVP

El MVP no pretende representar produccion real. Su objetivo es demostrar una base MLOps defendible para una entrega de maestria:

- hay infraestructura reproducible;
- hay un flujo end-to-end ejecutable en Azure;
- hay separacion clara entre plataforma y codigo funcional;
- hay evidencia versionada de corridas;
- hay controles para no operar con datos unmasked en `staging`;
- hay un roadmap claro para evolucionar hacia una arquitectura mas completa.

## Fuera De Alcance Actual

- Produccion real.
- Endpoints online de Azure ML.
- ADF como orquestador principal.
- Private Endpoints y Hub-Spoke.
- Modelo productivo definitivo.
- Datos `raw-unmasked` en `staging`.
