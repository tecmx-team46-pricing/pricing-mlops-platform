# Estructura Del Proyecto

Este repo es la capa de plataforma del proyecto. No guarda el modelo de pricing como pieza principal; guarda la infraestructura, la orquestacion y la evidencia que permiten ejecutar el flujo MLOps en Azure de forma repetible.

La idea corta es:

```text
pricing-mlops-platform
-> prepara Azure
-> recibe eventos o solicitudes
-> dispara Azure ML
-> guarda outputs y metadata
-> documenta como operar y auditar el flujo
```

El codigo funcional/data science vive en el repo `pricing-mlops`. Este repo lo empaqueta como snapshot cuando publica la Azure Function, para que Azure ML ejecute una version concreta del flujo.

## Mapa Mental

Piensa el repo como cuatro capas:

| Capa | Donde vive | Para que sirve |
|---|---|---|
| Narrativa y evidencia | `docs/` | Explica el proyecto, decisiones, arquitectura, operacion, gobierno y avance academico. |
| Infraestructura | `infra/` | Define recursos Azure con Bicep: Storage, Azure ML, Function, SQL audit, identidades y RBAC. |
| Runtime MLOps | `mlops/` | Contiene la Function, pipeline Azure ML, configs, schemas, SQL y scripts operativos. |
| Automatizacion | `.github/workflows/`, `scripts/`, `tests/` | Valida contratos, corre pruebas, construye docs y despliega bajo operacion controlada. |

## Flujo Del Sistema

Hay dos formas de iniciar una corrida.

La ruta automatica empieza cuando llega un CSV masked:

```text
raw-masked/incoming/*.csv
-> Event Grid
-> Azure Function
-> Azure ML pipeline
-> Storage MLOps + Azure SQL audit
```

La ruta manual sirve para pruebas controladas:

```text
operador/script
-> /api/model-flow
-> Azure Function
-> Azure ML pipeline
-> evidencia versionada
```

Referencias utiles:

| Referencia | Que muestra |
|---|---|
| `README.md:7-25` | Resumen del flujo manual y automatico. |
| `mlops/functions/function_app.py:48-115` | Entrypoints HTTP, Event Grid y healthcheck. |
| `mlops/functions/function_app.py:178-222` | Validaciones y convencion de outputs por corrida. |
| `mlops/azureml/pricing-mlops-pipeline.yml` | Pipeline principal AUTH monitoring de seis pasos derivado del notebook. |
| `mlops/azureml/pricing-mlops-notebook-pipeline.yml` | Alias temporal para `MLOPS_JOB_TEMPLATE=notebook`. |

## Donde Mirar Primero

| Si quieres entender... | Empieza aqui |
|---|---|
| La historia del proyecto | `docs/index.md`, `docs/contexto-problema.md`, `docs/reporte-avance-proyecto-integrador.md` |
| La arquitectura | `README.md:27-48`, `docs/architecture.md`, `docs/azure-services.md` |
| La infraestructura Azure | `infra/workloads/pricing-mlops/main.bicep:49-103`, `infra/parameters/staging.bicepparam` |
| La Function orquestadora | `mlops/functions/function_app.py:48-115` |
| El pipeline Azure ML AUTH monitoring | `mlops/azureml/pricing-mlops-pipeline.yml`, `docs/pipeline-goal.md` |
| El alias notebook | `mlops/azureml/pricing-mlops-notebook-pipeline.yml` |
| Los contratos de evidencia | `mlops/schemas/`, `docs/data-contracts.md` |
| La operacion diaria | `docs/operations.md`, `mlops/scripts/` |
| La publicacion del sitio | `mkdocs.yml:54-79`, `.github/workflows/docs.yml:33-64` |

## Directorios Principales

```text
.
├── docs/                   # Sitio academico, runbooks y decisiones
├── infra/                  # Infraestructura Azure en Bicep
│   ├── foundation/         # Servicios compartidos
│   ├── parameters/         # Parametros por ambiente
│   └── workloads/          # Workload Pricing MLOps
├── mlops/                  # Runtime que se publica y opera
│   ├── functions/          # Azure Function
│   ├── azureml/            # Pipeline/job Azure ML
│   ├── configs/            # Layout y thresholds
│   ├── schemas/            # Schemas JSON de evidencia
│   ├── scripts/            # Publicacion y ejecucion
│   └── sql/                # Auditoria metadata-only
├── scripts/                # Validacion, what-if y deploy
├── tests/                  # Pruebas del runtime
└── .github/workflows/      # CI/CD y GitHub Pages
```

## Archivos Que Anclan El Proyecto

| Archivo | Rol |
|---|---|
| `README.md` | Resumen principal, arquitectura compacta, comandos y ruta de lectura. |
| `mkdocs.yml` | Configura el sitio de documentacion y su navegacion. |
| `.github/workflows/docs.yml` | Construye y publica GitHub Pages. |
| `.github/workflows/platform-infra.yml` | Valida IaC/runtime y ejecuta `what-if` o deploy manual. |
| `infra/workloads/pricing-mlops/main.bicep` | Entry point del workload MLOps en Azure. |
| `mlops/functions/function_app.py` | Orquestador HTTP/Event Grid que somete jobs a Azure ML. |
| `mlops/azureml/pricing-mlops-pipeline.yml` | Pipeline activo de Azure ML. |
| `mlops/scripts/publish_orchestrator_function.sh` | Empaqueta Function + runtime + snapshot del repo modelo. |
| `scripts/validate-mlops-contracts.py` | Valida schemas, thresholds, layout y contratos IaC/docs. |

## Relacion Con El Repo Del Modelo

La frontera entre repos es deliberada:

```text
pricing-mlops-platform
-> plataforma, nube, orquestacion, evidencia, operacion

pricing-mlops
-> validacion de datos, curated, scoring, drift, reportes
```

La plataforma no clona el repo funcional en cada evento. Durante la publicacion, resuelve `MODEL_REPO_GITHUB` + `MODEL_REPO_REF`, empaqueta un snapshot bajo `pricing-mlops-source/` y Azure ML ejecuta ese snapshot.

Referencias:

| Referencia | Que revisar |
|---|---|
| `README.md:85-100` | Como se publica la Function y se registra el snapshot. |
| `docs/platform-model-operating-contract.md` | Contrato entre plataforma y modelo. |
| `mlops/docs/azure-ml-job-contract.md` | Contrato tecnico del pipeline/job. |

## Ambientes

| Ambiente | Proposito |
|---|---|
| `staging` | Ambiente operativo del MVP. |
| `validation` | No-prod controlado futuro. |
| `data-lab` | Landing restringido para datos unmasked/masking. |
| `sandbox-local` | Pruebas locales/admin temporales. |

No existe `prod` en IaC, parametros ni workflows.

## Lecturas Recomendadas

Para una revision academica:

1. `docs/index.md`
2. `docs/contexto-problema.md`
3. `docs/objetivos-alcance.md`
4. `docs/reporte-avance-proyecto-integrador.md`
5. `docs/evidencia.md`

Para entender como corre el sistema:

1. `README.md:7-25`
2. `mlops/functions/function_app.py:48-115`
3. `mlops/azureml/pricing-mlops-pipeline.yml`
4. `mlops/azureml/pricing-mlops-notebook-pipeline.yml`
4. `docs/operations.md`

Para entender que se despliega:

1. `infra/workloads/pricing-mlops/main.bicep`
2. `infra/parameters/staging.bicepparam`
3. `docs/azure-services.md`

Siguiente lectura recomendada: [Operacion](operations.md), si quieres pasar del mapa del repo a los comandos concretos.

## Que No Es Este Repo

- No es el repo principal del modelo/data science.
- No contiene produccion real.
- No usa GitHub Actions como orquestador operativo del modelo.
- No usa endpoints online de Azure ML.
- No guarda `raw-unmasked` en `staging`.
