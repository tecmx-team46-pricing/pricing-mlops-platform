# Azure Services

## Servicios actuales del PoC

| Servicio | Resource Group | Para que sirve | Estado |
|---|---|---|---|
| Resource Groups | Subscription scope | Separar `shared`, `data-lab`, `sandbox`, `staging` y `validation`. | Actual |
| Key Vault | `rg-pricing-mlops-platform-shared` | Salts, secretos y configuracion sensible futura. | Actual |
| Log Analytics | `rg-pricing-mlops-platform-shared` | Logs tecnicos y observabilidad base. | Actual |
| User Assigned Managed Identity + OIDC | `rg-pricing-mlops-platform-shared` | Login federado desde GitHub Actions sin client secrets. | Actual |
| Storage / ADLS Gen2 | Workload RG o `data-lab` | Inputs masked, curated, baselines, runs, snapshots, drift logs, reports y artifacts. | Actual |
| Azure Machine Learning Workspace | `rg-pricing-mlops-staging` | Ejecuta el flujo MLOps minimo como command job administrado. | Ruta activa |
| Azure Functions | Workload RG | Orquestador ligero para disparar jobs AML y health checks. | Preparado; bloqueado si App Service quota = 0 |
| Azure Container Registry Basic | Workload RG | Guarda la imagen del PoC anterior de Container Apps. | Legacy/PoC |
| Azure Container Apps Job | Workload RG | PoC anterior de compute batch. | Legacy/PoC |

Azure ML debe usarse sin compute persistente al inicio. El primer intento preferido es command job serverless/administrado, sin GPU, sin endpoints online y sin cluster 24/7. Si Azure ML serverless no esta disponible por provider, quota o capacidad, el bloqueo debe quedar documentado con el error exacto.

## Pipeline minimo en Azure

El primer pipeline real usa:

```text
GitHub Actions + OIDC + Azure ML command job + Storage/ADLS
```

Flujo:

```text
pricing-mlops workflow_dispatch
-> azure/login con OIDC
-> someter Azure ML command job
-> Azure ML ejecuta flow ML
-> Azure ML sube outputs a Storage containers
-> GitHub Actions verifica outputs
```

GitHub Actions no es el compute ML. Solo somete el job AML, espera estado y verifica outputs. No requiere ADF ni SQL.

Azure Functions debe convertirse en el trigger/orquestador cuando la quota lo permita: recibe parametros controlados, inicia el job AML y retorna el id de job. No debe ejecutar scoring pesado.

## Servicios futuros

| Servicio | Cuando activarlo |
|---|---|
| Azure SQL Serverless | Cuando Storage JSON/Parquet no baste para auditoria historica por `run_id`. |
| Azure Data Factory | Cuando existan fuentes formales, calendario, reintentos y dependencias de ingesta. |
| Azure ML Registry / tracking formal | Cuando haya modelos versionados y promocion de campeon/retador. |
| Private Endpoints / Hub-Spoke | Cuando haya prod o datos productivos con requisito de red privada. |

## Fuera de alcance actual

- Produccion real.
- ADF y SQL.
- Azure ML online endpoints, GPU y clusters persistentes.
- Private Endpoints, Private DNS y Hub-Spoke.
- `raw-unmasked` en `sandbox-local`, `staging` o `validation`.
