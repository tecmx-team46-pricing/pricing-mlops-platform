# Objetivos Y Alcance

El objetivo de esta etapa no es construir una plataforma productiva completa. El objetivo es implementar una base MLOps funcional para Pricing Intelligence, con evidencia para explicar cada corrida y con limites definidos de costo, seguridad y tiempo academico.

## Objetivo General

Disenar e implementar una plataforma MLOps base en Azure que permita ejecutar, registrar y auditar corridas de un flujo de pricing usando datos masked o sinteticos.

## Objetivos Especificos

- Separar infraestructura, orquestacion y codigo funcional/data science.
- Definir infraestructura reproducible con Bicep.
- Orquestar corridas mediante Azure Function.
- Ejecutar el flujo tecnico en Azure ML.
- Publicar evidencia versionada en Storage/ADLS.
- Registrar metadata consultable en Azure SQL audit.
- Evitar datos `raw-unmasked` en ambientes operativos.
- Mantener GitHub Actions como CI/CD, no como compute ML.
- Documentar arquitectura, operacion y evidencia para revision academica.

## Alcance Implementado

| Area | Implementacion actual |
|---|---|
| Infraestructura | Capa foundation y workload con Resource Groups, Storage, Azure ML, Function, SQL audit, identidades y permisos base. |
| Orquestacion | Endpoint `POST /api/model-flow` y trigger Event Grid para `raw-masked/incoming/*.csv`. |
| Ejecucion ML | Pipeline Azure ML con pasos `validate_prepare`, `score_evaluate` y `publish_outputs`. |
| Evidencia | Outputs versionados en `runs`, `snapshots`, `drift-logs`, `reports`, `artifacts` y `curated`. |
| Auditoria | Azure SQL metadata-only para consultar corridas y snapshots sin almacenar datasets completos. |
| Gobierno | Separacion de datos masked/unmasked y rechazo de `raw-unmasked` en ambientes operativos. |

## Fuera De Alcance

Estos puntos quedan fuera por alcance, costo y tiempo del MVP:

- produccion real;
- endpoints online de Azure ML;
- Azure Data Factory como orquestador principal;
- Private Endpoints, Hub-Spoke y hardening de red completo;
- registro formal de modelos productivos;
- ciclo completo de entrenamiento, promocion y rollback;
- datos `raw-unmasked` en `staging`, `validation` o `sandbox-local`.

## Criterio De Exito

El proyecto cumple esta etapa si una corrida se puede iniciar, ejecutar, evidenciar y auditar con separacion entre plataforma y modelo. Esa base permite discutir mejoras futuras a partir de una ejecucion registrada, no solo desde un diagrama.

Siguiente lectura recomendada: [Reporte de avance](reporte-avance-proyecto-integrador.md).
