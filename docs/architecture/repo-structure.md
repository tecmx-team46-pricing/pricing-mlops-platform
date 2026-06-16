# Estructura Del Proyecto

Este repo es solamente la capa de plataforma. No contiene runtime MLOps, Azure Functions, componentes Azure ML ni scripts de endpoint.

## Directorios Principales

```text
.
├── docs/                   # Sitio academico y documentacion de plataforma
├── infra/                  # Infraestructura Azure en Bicep
│   ├── foundation/         # Servicios compartidos
│   ├── parameters/         # Parametros por ambiente
│   └── workloads/          # Workload Pricing MLOps base
├── scripts/                # What-if y deploy de infraestructura
└── .github/workflows/      # Validacion de IaC y GitHub Pages
```

## Archivos Que Anclan El Proyecto

| Archivo | Rol |
|---|---|
| `README.md` | Resumen principal y comandos de plataforma. |
| `mkdocs.yml` | Configura el sitio de documentacion. |
| `.github/workflows/platform-infra.yml` | Compila Bicep y ejecuta what-if/deploy manual. |
| `.github/workflows/docs.yml` | Publica GitHub Pages. |
| `infra/foundation/main.bicep` | Recursos compartidos y OIDC base. |
| `infra/workloads/pricing-mlops/main.bicep` | Storage, Azure ML, identidad de job y RBAC del workload. |
| `infra/parameters/staging.bicepparam` | Parametros del ambiente operativo compartido. |

## Relacion Con El Repo Modelo

```text
pricing-mlops-platform
-> crea workspace/storage/identity/RBAC

pricing-mlops
-> registra componentes
-> registra pipeline component
-> despliega endpoint
-> invoca smoke test
```

La frontera deliberada es que platform no publica componentes Azure ML. Si cambia la logica del notebook o el pipeline, el cambio se hace y se registra desde `pricing-mlops`.

## Que No Es Este Repo

- No es el repo principal del modelo/data science.
- No contiene `mlops/` runtime.
- No despliega Azure Functions ni SQL audit.
- No opera el endpoint del pipeline.
- No usa GitHub Actions como compute ML.
