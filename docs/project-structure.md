# Project Structure

Este documento explica como leer el repo `pricing-mlops-platform` sin entrar primero al detalle de Azure o de cada runbook.

## Idea Principal

Este repo no contiene principalmente el modelo de pricing. Este repo contiene la plataforma que permite operar el flujo MLOps en Azure:

```text
pricing-mlops-platform
-> infraestructura Azure
-> permisos e identidades
-> Azure Function orquestadora
-> definicion del pipeline/job de Azure ML
-> scripts de deploy/operacion
-> contratos, schemas y documentacion
```

El codigo funcional/data science vive en el repo `pricing-mlops`. Durante la publicacion, la plataforma puede empaquetar un snapshot de ese repo para que Azure ML lo ejecute.

## Flujo Operativo

```text
Archivo CSV masked en Storage
-> Event Grid detecta BlobCreated
-> Azure Function recibe el evento
-> Azure Function dispara Azure ML pipeline
-> Azure ML ejecuta el codigo del modelo
-> Outputs quedan en Storage MLOps
-> Metadata queda en Table/JSON y Azure SQL audit
```

Tambien existe una ruta manual/controlada:

```text
Operador o script
-> Azure Function /api/model-flow
-> Azure ML pipeline
-> Storage + metadata
```

## Carpetas Principales

| Ruta | Rol |
|---|---|
| `infra/` | Infraestructura como codigo en Bicep. Define resource groups, storage, Azure ML, Function, SQL audit, RBAC/OIDC y budgets. |
| `infra/foundation/` | Capa compartida: resource groups base, Key Vault, Log Analytics e identidades GitHub Actions/OIDC. |
| `infra/workloads/pricing-mlops/` | Capa del workload MLOps: Storage funcional, Azure ML workspace, Function App, SQL audit y permisos. |
| `infra/parameters/` | Parametros por ambiente: `staging`, `validation`, `data-lab` y `sandbox-local`. |
| `mlops/` | Runtime MLOps que se publica y opera: Function, pipeline Azure ML, configs, schemas, SQL y scripts. |
| `mlops/functions/` | Codigo de Azure Function. Orquesta requests/eventos y dispara Azure ML. |
| `mlops/azureml/` | Definicion del pipeline/job Azure ML y ambiente de ejecucion. |
| `mlops/configs/` | Configuracion funcional del flujo: layout de storage, thresholds y reglas ejemplo. |
| `mlops/schemas/` | Schemas JSON de logs, snapshots y drift. |
| `mlops/sql/` | Migraciones SQL para tablas de auditoria. |
| `mlops/scripts/` | Scripts para publicar Function, correr el flujo y aplicar schema SQL. |
| `scripts/` | Scripts generales de plataforma: deploy, what-if, destroy sandbox y validacion de contratos. |
| `.github/workflows/` | Workflows de GitHub Actions para validar/desplegar infraestructura. |
| `tests/` | Pruebas automatizadas de Function, pipeline/job y empaquetado. |
| `docs/` | Documentacion activa, runbooks, decisiones y reportes. |
| `src/` | Codigo legacy/minimo de ejemplo. No es la ruta operativa principal del flujo MLOps. |

## Archivos Clave

| Archivo | Para que sirve |
|---|---|
| `README.md` | Resumen principal del repo, arquitectura, comandos y ruta de lectura. |
| `docs/index.md` | Indice de documentacion activa. |
| `docs/architecture.md` | Arquitectura actual, servicios activos, ambientes y decisiones vigentes. |
| `docs/azure-services.md` | Inventario y rol de servicios Azure en staging. |
| `docs/platform-model-operating-contract.md` | Contrato entre esta plataforma y el repo funcional del modelo. |
| `mlops/docs/function-orchestrator.md` | Como funciona la Azure Function y el empaquetado. |
| `mlops/docs/azure-ml-job-contract.md` | Contrato del pipeline/job de Azure ML. |
| `infra/workloads/pricing-mlops/main.bicep` | Entry point Bicep del workload MLOps. |
| `infra/foundation/main.bicep` | Entry point Bicep de foundation/shared. |
| `infra/parameters/staging.bicepparam` | Parametros del ambiente operativo `staging`. |
| `mlops/functions/function_app.py` | Funcion que valida requests/eventos y envia jobs a Azure ML. |
| `mlops/azureml/pricing-mlops-pipeline.yml` | Pipeline lineal activo de Azure ML. |
| `mlops/azureml/pricing-mlops-job.yml` | Fallback de un solo command job. |
| `mlops/scripts/publish_orchestrator_function.sh` | Empaqueta y publica la Function con el runtime y snapshot del repo modelo. |

## Ambientes

| Ambiente | Proposito | Estado esperado |
|---|---|---|
| `staging` | Ambiente operativo compartido para el MVP. | Activo. |
| `validation` | No-prod controlado futuro. | Preparado, no necesariamente activo. |
| `data-lab` | Landing restringido para datos unmasked/masking. | Preparado. |
| `sandbox-local` | Pruebas local/admin temporales. | Preparado. |

No existe `prod` en IaC, parametros ni workflows. Cuando se hable de "produccion" en conversaciones del proyecto, conviene aclarar si se refieren a produccion real o al MVP/staging operativo.

## Relacion Con El Repo Del Modelo

La separacion conceptual es:

```text
pricing-mlops-platform
-> despliega y opera la plataforma
-> decide donde corre el flujo
-> orquesta Azure ML
-> guarda evidencia, outputs y metadata

pricing-mlops
-> contiene la logica funcional/data science
-> valida/prepara datos
-> ejecuta scoring
-> genera reportes, drift y outputs
```

En la ruta actual, la plataforma resuelve el repo del modelo mediante `MODEL_REPO_GITHUB` y `MODEL_REPO_REF`, empaqueta un snapshot y lo entrega al pipeline/job de Azure ML. La Function no clona GitHub cada vez que llega un evento.

## Pipeline Azure ML

La forma activa es lineal:

```text
validate_prepare -> score_evaluate -> publish_outputs
```

| Paso | Responsabilidad |
|---|---|
| `validate_prepare` | Validar input y preparar datos/features. |
| `score_evaluate` | Ejecutar scoring/evaluacion con el modelo. |
| `publish_outputs` | Publicar outputs, metadata, logs y evidencia. |

El archivo `pricing-mlops-job.yml` se conserva como fallback operativo si el pipeline multi-componente falla.

## Regiones Azure

La region base es `eastus2`. En `staging`, Azure ML y Storage viven ahi. La Function y SQL audit quedaron en `centralus` por restricciones de quota/capacidad en la suscripcion.

## Como Leer El Repo

Para una lectura rapida:

1. Leer `README.md`.
2. Leer este documento.
3. Leer `docs/architecture.md`.
4. Leer `docs/platform-model-operating-contract.md`.
5. Leer `mlops/docs/azure-ml-job-contract.md`.
6. Leer `docs/operations.md` cuando se necesite operar o desplegar.

Para entender codigo primero:

1. `mlops/functions/function_app.py`
2. `mlops/azureml/pricing-mlops-pipeline.yml`
3. `mlops/scripts/publish_orchestrator_function.sh`
4. `infra/workloads/pricing-mlops/main.bicep`
5. `infra/parameters/staging.bicepparam`

## Que No Es Este Repo

- No es el repo principal del modelo/data science.
- No contiene produccion real.
- No usa GitHub Actions como orquestador operativo del modelo.
- No usa endpoints online de Azure ML.
- No guarda `raw-unmasked` en `staging`.
- No deberia mezclar outputs funcionales con storage interno/runtime de Azure ML.
