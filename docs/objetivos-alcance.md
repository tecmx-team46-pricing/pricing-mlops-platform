# Objetivos Y Alcance

## Objetivo General

Disenar e implementar una plataforma MLOps base para Pricing Intelligence que permita ejecutar, registrar y auditar corridas de un flujo ML en Azure con datos masked o sinteticos.

## Objetivos Especificos

- Separar infraestructura, runtime MLOps y codigo funcional/data science.
- Definir infraestructura reproducible con Bicep.
- Orquestar corridas mediante Azure Function.
- Ejecutar el flujo tecnico en Azure ML.
- Publicar evidencia versionada en Storage/ADLS.
- Registrar metadata consultable en Azure SQL audit.
- Evitar datos `raw-unmasked` en ambientes operativos.
- Mantener GitHub Actions como CI/CD y no como compute ML.
- Documentar la arquitectura para revision academica y tecnica.

## Alcance Implementado

| Componente | Estado |
|---|---|
| Foundation Azure | Implementado para resource groups, identidades, Key Vault y Log Analytics. |
| Workload `staging` | Implementado con Storage, Azure ML, Function, SQL audit y permisos base. |
| Orquestacion manual | Implementada con `POST /api/model-flow`. |
| Orquestacion automatica | Implementada con Event Grid sobre `raw-masked/incoming/*.csv`. |
| Pipeline Azure ML | Implementado como flujo lineal de tres nodos. |
| Evidencia | Implementada en Storage con layout versionado. |
| Auditoria | Implementada como metadata-only en Azure SQL. |
| Gobierno de datos | Implementado por convencion, documentacion y validaciones de rutas. |

## Fuera De Alcance

- Produccion real.
- Endpoints online de Azure ML.
- ADF como orquestador principal.
- Private Endpoints, Hub-Spoke y hardening de red completo.
- Registro formal de modelos productivos.
- Ciclo completo de entrenamiento, promocion y rollback.
- Datos `raw-unmasked` en `staging`, `validation` o `sandbox-local`.

## Criterio De Exito

El proyecto se considera exitoso para esta etapa si puede demostrar:

- infraestructura reproducible;
- una corrida end-to-end en Azure;
- outputs y metadata auditables;
- separacion clara de responsabilidades;
- controles basicos de seguridad y gobierno;
- roadmap defendible para evolucion posterior.
