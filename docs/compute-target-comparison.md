# Compute Target Comparison

## Objetivo

Comparar dos targets de compute para el flujo minimo de Pricing MLOps sin cambiar el contrato funcional:

| Target | Proposito |
|---|---|
| Azure Functions | Probar si el flujo cabe como invocacion serverless HTTP con Managed Identity. |
| Azure Container Apps Job + ACR | Probar si el flujo es mas reproducible como proceso batch empaquetado en contenedor. |

La comparacion usa `staging` como storage compartido estable y separa evidencia por `compute=<target>` en los paths de Storage. No crea ambientes personales ni usa nombres de usuarios.

## Constantes

Ambos targets deben usar:

- Input: `raw-masked/samples/sample_pricing_v1.csv`.
- Storage Account: `<mlops-storage-account>`.
- Ambiente logico: `staging`.
- Owner logico: `team46`.
- Mismo core Python del repo `pricing-mlops`.
- Mismo contrato de outputs: `model_run_log.json`, `curated_pricing.csv`, `model_output_snapshot.csv`, `model_drift_log.json`, `report.md`.
- Managed Identity/OIDC, sin account keys ni connection strings para el flujo de datos.

## Variables comunes

```text
MLOPS_ENVIRONMENT=staging
MLOPS_RUN_OWNER=team46
MLOPS_COMPUTE_TARGET=functions|container-job
AZURE_STORAGE_ACCOUNT=<mlops-storage-account>
MLOPS_CONTAINER_RAW_MASKED=raw-masked
MLOPS_CONTAINER_CURATED=curated
MLOPS_CONTAINER_RUNS=runs
MLOPS_CONTAINER_SNAPSHOTS=snapshots
MLOPS_CONTAINER_DRIFT_LOGS=drift-logs
MLOPS_CONTAINER_REPORTS=reports
MLOPS_CONTAINER_ARTIFACTS=artifacts
MLOPS_INPUT_BLOB_PATH=samples/sample_pricing_v1.csv
```

## Layout de outputs

```text
<container>/environment=staging/compute=<target>/owner=team46/run_date=<yyyymmdd>/run_id=<run_id>/<artifact>
```

Ejemplos:

```text
runs/environment=staging/compute=functions/owner=team46/run_date=20260517/run_id=<run_id>/model_run_log.json
runs/environment=staging/compute=container-job/owner=team46/run_date=20260517/run_id=<run_id>/model_run_log.json
```

## Recursos por target

| Target | Recursos | Permisos minimos |
|---|---|---|
| Functions | Function App Linux, host storage, Managed Identity, app settings del contrato. | Function identity: `Storage Blob Data Contributor` sobre Storage de staging. GitHub model identity: permiso de publicacion/invocacion controlada si se despliega desde Actions. |
| Container Apps Job + ACR | ACR Basic, Container Apps Environment, manual job, Managed Identity. | Job identity: `AcrPull` y `Storage Blob Data Contributor`. GitHub model identity: `AcrPush`, `Container Apps Jobs Operator` y lectura de Storage para verificar outputs. |

## Riesgos

| Target | Riesgo |
|---|---|
| Functions | La subscription actual puede tener cuota App Service/Functions en `0`. Python dependencies pueden complicar cold start y empaquetado. El host de Functions requiere storage runtime; debe evitarse exponer secretos de aplicacion. |
| Container Apps Job + ACR | Requiere Docker/imagen y ACR. La primera ejecucion puede tardar mas por pull de imagen. Hay que configurar explicitamente el `AZURE_CLIENT_ID` de la user-assigned identity dentro del contenedor. |

## Metricas

| Metrica | Como medir |
|---|---|
| Tiempo de deploy | Duracion de `scripts/deploy.sh` o workflow de deploy. |
| Tiempo de ejecucion | Diferencia entre start/finish del job o Function response. |
| Tiempo hasta primer output | Primer blob observado en Storage. |
| Logs/debugging | Facilidad para encontrar logs en Log Analytics o Actions. |
| Empaquetado | Archivos y pasos requeridos para publicar runtime. |
| Dependencias Python | Instalacion y compatibilidad en runtime. |
| Costo esperado | Recursos base siempre activos + costo por ejecucion. |
| Reproducibilidad local | Si puede correr igual como proceso local o contenedor. |
| Disparo desde GitHub Actions | Complejidad de OIDC, permisos y comando. |
| Integracion futura con ADF | Facilidad para disparo externo controlado. |
| Permisos necesarios | Roles Azure requeridos y scope. |
| Blast radius | Recursos afectados si falla el compute. |
| Observabilidad | Logs, estados, run_id y evidencia en Storage. |

## Estado actual

Container Apps Job + ACR ya fue desplegado y validado en `staging` con el flujo end-to-end. Functions queda como PoC comparable, pero no debe desplegarse si `what-if` o deploy confirma cuota App Service/Functions insuficiente.

El intento previo de Functions fallo por `SubscriptionIsOverQuotaForSku` con cuota `Dynamic VMs = 0`. Ese bloqueo cuenta como evidencia operacional a favor de Container Apps Job para esta subscription, salvo que Azure apruebe cuota.

## Resultado PoC actual

| Target | Resultado | Evidencia |
|---|---|---|
| Container Apps Job + ACR | Exitoso | Ejecucion `job-pricing-mlops-staging-5mtlm2a`, `run_id=20260517T021325Z-compute-contract`, outputs completos bajo `compute=container-job`. |
| Azure Functions | Preparado, no desplegado | El wrapper `function_app.py` en `pricing-mlops` usa el mismo core. El `what-if` de Functions no dio un plan confiable por nested deployments short-circuited y el historial de deploy indica bloqueo por cuota App Service/Functions. |

Outputs verificados para Container Apps Job:

```text
runs/environment=staging/compute=container-job/owner=team46/run_date=20260517/run_id=20260517T021325Z-compute-contract/model_run_log.json
snapshots/environment=staging/compute=container-job/owner=team46/run_date=20260517/run_id=20260517T021325Z-compute-contract/model_output_snapshot.csv
drift-logs/environment=staging/compute=container-job/owner=team46/run_date=20260517/run_id=20260517T021325Z-compute-contract/model_drift_log.json
reports/environment=staging/compute=container-job/owner=team46/run_date=20260517/run_id=20260517T021325Z-compute-contract/report.md
artifacts/environment=staging/compute=container-job/owner=team46/run_date=20260517/run_id=20260517T021325Z-compute-contract/curated_pricing.csv
curated/environment=staging/compute=container-job/owner=team46/run_date=20260517/run_id=20260517T021325Z-compute-contract/curated_pricing.csv
```

Duracion observada de la ejecucion del job: termino como `Succeeded` en el tercer intento de polling de 10 segundos, aproximadamente 20-30 segundos desde el start hasta estado final.

## Criterio de decision

Recomendar Functions solo si:

- La cuota App Service/Functions permite deploy.
- El paquete Python despliega sin workarounds.
- El tiempo de ejecucion y logs son suficientes.
- No requiere permisos mas amplios que Container Apps Job.

Recomendar Container Apps Job si:

- Sigue funcionando con ACR Basic y bajo consumo.
- El mismo contenedor puede reproducirse localmente.
- El job produce outputs en el layout `compute=container-job`.
- Functions queda bloqueado por cuota o empaquetado.

## Recomendacion actual

Recomendacion: mantener Container Apps Job + ACR como target activo de `staging` y usar Functions solo como experimento si se libera cuota App Service/Functions. Con la evidencia actual, Container Apps Job gana por viabilidad inmediata, reproducibilidad con Docker, bajo consumo configurado y outputs auditables con `compute=container-job`.
