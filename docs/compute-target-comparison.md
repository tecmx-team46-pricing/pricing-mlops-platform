# Compute Target Comparison

## Objetivo

Comparar y cerrar la decision de compute para el flujo minimo de Pricing MLOps sin cambiar el contrato funcional:

| Target | Proposito |
|---|---|
| Azure Machine Learning | Ruta activa alineada al diseno tecnico: command jobs administrados para validacion, scoring, drift y evidencia. |
| Azure Functions | Orquestador ligero para iniciar jobs AML; no ejecuta scoring pesado. |
| Azure Container Apps Job + ACR | PoC anterior de batch empaquetado en contenedor; queda como referencia/fallback, no como recomendacion activa. |

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
MLOPS_COMPUTE_TARGET=azure-ml
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
runs/environment=staging/compute=azure-ml/owner=team46/run_date=20260517/run_id=<run_id>/model_run_log.json
runs/environment=staging/compute=container-job/owner=team46/run_date=20260517/run_id=<run_id>/model_run_log.json
```

## Recursos por target

| Target | Recursos | Permisos minimos |
|---|---|---|
| Azure ML | AML Workspace, Application Insights, Storage asociado, Key Vault compartido. Sin cluster persistente al inicio. | GitHub model identity: `AzureML Data Scientist` sobre workspace y lectura de Storage para verificar. AML identity: `Storage Blob Data Contributor` sobre Storage de staging. |
| Functions | Function App Linux, host storage, Managed Identity, app settings del contrato. | Function identity: permiso minimo para iniciar AML jobs y consultar Storage. |
| Container Apps Job + ACR | ACR Basic, Container Apps Environment, manual job, Managed Identity. | Legacy: Job identity con `AcrPull` y `Storage Blob Data Contributor`; GitHub model identity con `AcrPush` y `Container Apps Jobs Operator`. |

## Riesgos

| Target | Riesgo |
|---|---|
| Azure ML | Requiere registrar `Microsoft.MachineLearningServices` y puede tener quota/capacidad serverless limitada en la subscription. El primer job puede tardar por creacion de environment. |
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

Container Apps Job + ACR ya fue desplegado y validado en `staging` con el flujo end-to-end. Esa evidencia se conserva como PoC anterior. La direccion activa cambia a Azure ML como compute principal y Azure Functions como orquestador ligero, porque el PDF tecnico ubica AML como motor de entrenamiento, validacion y scoring, y Functions como coordinacion/reglas.

El intento previo de Functions fallo por `SubscriptionIsOverQuotaForSku` con cuota `Dynamic VMs = 0`. Ese bloqueo no cambia la decision de compute ML: si Functions sigue bloqueado, GitHub Actions somete el job AML temporalmente; el ML no corre en GitHub.

## Resultado PoC actual

| Target | Resultado | Evidencia |
|---|---|---|
| Azure ML | Infra desplegada; job bloqueado por Storage key policy | Workspace `mlw-pricing-mlops-staging-<suffix>`, identity `id-pricing-mlops-aml-staging` y job YAML preparados. La primera corrida `upbeat_rice_wnyswb7t1v` fallo inmediatamente; al descargar logs, AML SDK intento usar key auth contra Storage y Azure respondio `KeyBasedAuthenticationNotPermitted`. |
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

## Decision activa

Recomendacion: usar Azure ML como compute principal del MVP y Azure Functions como orquestador ligero. Container Apps Job + ACR deja de ser la ruta recomendada activa y se conserva solo como PoC/fallback hasta que el equipo confirme cleanup.

Condiciones para sostener Azure ML:

- El workspace despliega sin crear GPU, endpoints online ni clusters persistentes.
- El job AML produce los mismos seis outputs bajo `compute=azure-ml`.
- GitHub Actions solo orquesta: login OIDC, submit, wait y verificacion.
- La identidad AML usa RBAC sobre Storage; no account keys ni connection strings.

Condiciones para habilitar Functions:

- La quota App Service/Functions permite deploy.
- La Function solo valida parametros e inicia jobs AML.
- No duplica logica de pricing ni scoring.

Si Azure ML falla por provider/quota/capacidad, documentar el error exacto antes de volver a invertir en Container Apps.

Bloqueo actual de AML: el Storage de `staging` tiene shared key access deshabilitado. Esto es correcto para el flujo de datos del MVP, pero Azure ML todavia intento usar key-based auth para artifacts/log download del workspace asociado. No habilitar account keys sin una decision explicita de seguridad. El siguiente paso tecnico es configurar AML con acceso identity-based para artifacts/datastores, o separar un storage interno de AML con riesgo documentado.
