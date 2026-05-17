# Azure Services

## Servicios actuales del PoC

| Servicio | Resource Group | Para que sirve | Estado |
|---|---|---|---|
| Resource Groups | Subscription scope | Separar `shared`, `data-lab`, `sandbox`, `staging` y `validation`. | Actual |
| Key Vault | `rg-pricing-mlops-platform-shared` | Salts, secretos y configuracion sensible futura. | Actual |
| Log Analytics | `rg-pricing-mlops-platform-shared` | Logs tecnicos y observabilidad base. | Actual |
| User Assigned Managed Identity + OIDC | `rg-pricing-mlops-platform-shared` | Login federado desde GitHub Actions sin client secrets. | Actual |
| Storage / ADLS Gen2 | Workload RG o `data-lab` | Inputs masked, curated, baselines, runs, snapshots, drift logs, reports y artifacts. | Actual |
| Azure Function App | Workload RG | `/api/health` y `/api/model-flow`; ejecuta el flujo MLOps minimo dentro de Azure. | Condicionado a quota |

La Function App usa Azure Functions Consumption `Y1/Dynamic` como opcion de bajo costo. En esta subscription el despliegue queda bloqueado si `Dynamic VMs` o la quota equivalente de App Service/Functions esta en `0`; pedir limite minimo `1` para `eastus2`.

## Pipeline minimo en Azure

El primer pipeline real usa:

```text
GitHub Actions + OIDC + Azure Function App + Storage/ADLS
```

Flujo:

```text
pricing-mlops workflow_dispatch
-> azure/login con OIDC
-> publicar paquete de Azure Function
-> invocar /api/model-flow
-> Azure Function ejecuta flow ML
-> Azure Function sube outputs a Storage containers
-> GitHub Actions verifica outputs
```

GitHub Actions no es el compute ML. Solo publica, invoca y verifica. No requiere Azure ML, ADF, SQL ni ACR.

## Servicios futuros

| Servicio | Cuando activarlo |
|---|---|
| Azure SQL Serverless | Cuando Storage JSON/Parquet no baste para auditoria historica por `run_id`. |
| Azure Machine Learning | Cuando el scoring requiera jobs administrados, registry o tracking formal de modelos. |
| Azure Data Factory | Cuando existan fuentes formales, calendario, reintentos y dependencias de ingesta. |
| Azure Container Registry | Cuando validadores/modelos se empaqueten como contenedores. |
| Private Endpoints / Hub-Spoke | Cuando haya prod o datos productivos con requisito de red privada. |

## Fuera de alcance actual

- Produccion real.
- AML, ADF, SQL y ACR.
- Private Endpoints, Private DNS y Hub-Spoke.
- `raw-unmasked` en `sandbox-local`, `staging` o `validation`.
