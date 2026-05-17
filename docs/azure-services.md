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
| Azure Functions | Workload RG | Orquestador ligero para disparar jobs AML y health checks. | Desplegado en `centralus` |
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
pricing-mlops workflow_dispatch o trigger controlado
-> Azure Function /api/model-flow
-> validar parametros y someter Azure ML command job
-> Azure ML ejecuta flow ML
-> Azure ML sube outputs a Storage containers
-> caller verifica outputs por run_id
```

GitHub Actions no es el compute ML. Cuando la Function esta disponible, GitHub la llama como orquestador. Si la quota de App Service/Functions bloquea el deploy, GitHub Actions puede someter el job AML directamente como fallback temporal; en ambos casos el ML corre en Azure ML. No requiere ADF ni SQL.

El intento de habilitar la Function en `staging` con Linux Consumption en `eastus2` fallo por quota `SubscriptionIsOverQuotaForSku`: limite actual `Total VMs=0`, requerido `1`. Para no mover el ambiente completo, solo la Function se despliega en `centralus`; Storage, Azure ML y datos de `staging` permanecen en `eastus2`. El Storage interno de host de Azure Functions puede usar una connection string/runtime key administrada por Azure Functions; eso no es el Storage MLOps ni se usa para datasets u outputs.

Function activa:

```text
func-pricing-mlops-staging-<suffix>
Plan Y1 / Dynamic Consumption
Region Central US
```

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
