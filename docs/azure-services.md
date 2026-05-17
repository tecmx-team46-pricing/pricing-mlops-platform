# Azure Services

## Servicios actuales del PoC

| Servicio | Resource Group | Para que sirve | Estado |
|---|---|---|---|
| Resource Groups | Subscription scope | Separar `shared`, `data-lab`, `sandbox`, `staging` y `validation`. | Actual |
| Key Vault | `rg-pricing-mlops-platform-shared` | Salts, secretos y configuracion sensible futura. | Actual |
| Log Analytics | `rg-pricing-mlops-platform-shared` | Logs tecnicos y observabilidad base. | Actual |
| User Assigned Managed Identity + OIDC | `rg-pricing-mlops-platform-shared` | Login federado desde GitHub Actions sin client secrets. | Actual |
| Storage / ADLS Gen2 | Workload RG o `data-lab` | Inputs masked, curated, baselines, runs, snapshots, drift logs, reports y artifacts. | Actual |
| Azure Container Registry Basic | Workload RG | Guarda la imagen del flujo `pricing-mlops`. | Actual |
| Azure Container Apps Job | Workload RG | Ejecuta el flujo MLOps minimo dentro de Azure bajo demanda. | Actual |

El job usa capacidad minima (`0.25` CPU, `0.5Gi`) y se ejecuta solo cuando GitHub Actions lo inicia. ACR queda en SKU Basic. Esta ruta evita la cuota App Service/Functions que bloqueo el intento anterior.

## Pipeline minimo en Azure

El primer pipeline real usa:

```text
GitHub Actions + OIDC + ACR + Azure Container Apps Job + Storage/ADLS
```

Flujo:

```text
pricing-mlops workflow_dispatch
-> azure/login con OIDC
-> construir y publicar imagen en ACR
-> iniciar Container Apps Job
-> el job ejecuta flow ML
-> el job sube outputs a Storage containers
-> GitHub Actions verifica outputs
```

GitHub Actions no es el compute ML. Solo publica imagen, inicia el job y verifica. No requiere Azure ML, ADF ni SQL.

## Servicios futuros

| Servicio | Cuando activarlo |
|---|---|
| Azure SQL Serverless | Cuando Storage JSON/Parquet no baste para auditoria historica por `run_id`. |
| Azure Machine Learning | Cuando el scoring requiera jobs administrados, registry o tracking formal de modelos. |
| Azure Data Factory | Cuando existan fuentes formales, calendario, reintentos y dependencias de ingesta. |
| Azure ML | Cuando el scoring requiera jobs administrados, registry o tracking formal de modelos. |
| Private Endpoints / Hub-Spoke | Cuando haya prod o datos productivos con requisito de red privada. |

## Fuera de alcance actual

- Produccion real.
- AML, ADF y SQL.
- Private Endpoints, Private DNS y Hub-Spoke.
- `raw-unmasked` en `sandbox-local`, `staging` o `validation`.
