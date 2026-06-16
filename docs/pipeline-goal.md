# Goal Pipeline AUTH Monitoring En Azure ML

Este goal convierte el notebook de monitoreo AUTH de Avance 4 en una primera infraestructura operable de Azure ML pipeline, sin ejecutar el notebook completo como una caja negra. El notebook queda como referencia del analista, control exploratorio y evidencia metodologica; Azure ML ejecuta componentes Python versionados que importan `pricing_mlops`.

## Contexto Actualizado Del Repo De Logica

Repo de logica:
`/Users/me/Developer/tecmx-team46-pricing/pricing-mlops`

Branch de trabajo:
`feature/avance4-pipeline-abstraction`

Commits base del trabajo de abstraccion:

| Commit | Proposito |
|---|---|
| `e260fb2` | Agrega overrides seguros para notebook/control manual. |
| `f694f2a` | Agrega helper de materializacion de outputs de monitoreo. |
| `339fd61` | Usa el helper de outputs en la copia transicional del notebook. |

Notebook transicional:
`notebooks/eda/auth_recommendation_monitoring_pipeline_abstraction.ipynb`

Notebook original de referencia:
`notebooks/eda/Avance4_Equipo46_AUTH_Recommendation_Validity_Current_History_REAL_v4_operational_decision.ipynb`

Decision tecnica:

- El notebook ya no es el motor productivo del pipeline.
- La logica productiva vive en `src/pricing_mlops`.
- La configuracion oficial vive en `src/pricing_mlops/monitoring/auth_monitoring_config.json`.
- Los overrides del notebook son solo para experimentos o revision manual.
- La publicacion a Azure Storage, Azure ML metadata y SQL vive en este repo de plataforma.

Package relevante en `pricing-mlops`:

| Modulo | Uso |
|---|---|
| `pricing_mlops.monitoring.config` | Carga config oficial y permite overrides controlados. |
| `pricing_mlops.monitoring.artifact_contract` | Declara y valida artefactos esperados. |
| `pricing_mlops.monitoring.domain.notebook_logic` | Contiene calculos abstraidos desde el notebook. |
| `pricing_mlops.monitoring.steps` | Expone funciones de step para Azure ML. |
| `pricing_mlops.io` | Materializa outputs locales y manifiesto. |

Contrato de artefactos requerido por el pipeline:

```text
snapshots/baseline_recommendation_snapshot.csv
snapshots/baseline_auth_history_profile.csv
snapshots/current_auth_history_snapshot_real.csv
logs/auth_recommendation_validity_log.csv
logs/auth_history_drift_log.csv
summaries/operational_decision_summary.csv
summaries/run_readiness_summary.csv
reports/auth_recommendation_validity_report.md
manifest/artifact_manifest.json
```

## Estado Actual

Hay una ruta operacional de Azure ML:

| Ruta | Template | Uso |
|---|---|---|
| AUTH monitoring | `mlops/azureml/pricing-mlops-pipeline.yml` | Pipeline principal multi-step para validar vigencia de recomendaciones AUTH. |

## Steps Azure ML Objetivo

El pipeline AUTH monitoring debe verse en Azure ML Studio con estos nodos:

```text
validate_prepare
-> build_monitoring_inputs
-> calculate_recommendation_validity
-> calculate_auth_history_drift
-> calculate_operational_decision
-> publish_outputs
```

Responsabilidades:

| Step | Repo | Responsabilidad |
|---|---|---|
| `validate_prepare` | `pricing-mlops` | Valida el CSV masked de entrada y produce estado preparado. |
| `build_monitoring_inputs` | `pricing-mlops` | Construye snapshots de entrada para monitoreo AUTH desde baseline y current history. |
| `calculate_recommendation_validity` | `pricing-mlops` | Evalua si las recomendaciones siguen dentro de bandas AUTH actuales. |
| `calculate_auth_history_drift` | `pricing-mlops` | Calcula drift estadistico sobre historia AUTH. |
| `calculate_operational_decision` | `pricing-mlops` | Abstrae el semaforo y la accion operacional. |
| `publish_outputs` | `pricing-mlops-platform` | Publica el arbol final a Storage MLOps. |

La dependencia entre steps debe estar expresada con outputs/inputs de Azure ML, por ejemplo `flow_token`, para que Azure ML Studio muestre el grafo como steps conectados. El uso de `depends_on` solo es aceptable como fallback si el schema del tenant no permite tokens, pero el objetivo de visualizacion es ver nodos conectados por entradas/salidas.

Los steps funcionales escriben estado intermedio bajo:

```text
artifacts/component-state/<run_id>/<step>/
```

El step de plataforma publica la evidencia funcional final en:

```text
<container>/environment=<env>/compute=azure-ml/trigger=<trigger>/owner=<owner>/run_date=<yyyymmdd>/run_id=<run_id>/
```

## Responsabilidad De Publicacion

La publicacion es un step independiente y pertenece a plataforma:

```text
pricing-mlops-platform/mlops/components/platform_publish_outputs.py
```

Este step recibe el `output_root` o el prefijo de artifacts generado por `calculate_operational_decision`. No recalcula metricas, no reinterpreta semaforos y no importa notebooks. Sus responsabilidades son:

- Descargar o recibir el arbol final de artefactos.
- Validar que existen los archivos esperados antes de publicar.
- Publicar particionado por ambiente, compute, trigger, owner, fecha y run id.
- Distribuir archivos a containers `runs`, `snapshots`, `drift-logs`, `reports`, `artifacts` y `curated` segun tipo.
- Preparar la ruta para futuras integraciones con Azure ML tags y SQL metadata.

## Entradas Requeridas

Para AUTH monitoring se requieren dos blobs:

| Input | Variable | Default |
|---|---|---|
| Baseline recommendation snapshot | `MLOPS_BASELINE_SNAPSHOT_BLOB_PATH` | Requerido, sin default seguro. |
| Current AUTH history snapshot | `MLOPS_CURRENT_AUTH_HISTORY_BLOB_PATH` | Puede usar el input del request para pruebas, pero debe apuntar al snapshot real en operacion. |

El preflight minimo es:

```bash
MLOPS_BASELINE_SNAPSHOT_BLOB_PATH=<path-en-artifacts-o-snapshots> \
MLOPS_CURRENT_AUTH_HISTORY_BLOB_PATH=<path-en-raw-masked> \
mlops/scripts/preflight_pipeline_e2e.sh staging
```

## Configuracion Y Constantes

Las constantes del notebook deben administrarse asi:

| Tipo | Ubicacion productiva |
|---|---|
| Thresholds de drift/semaforo | `pricing-mlops/src/pricing_mlops/monitoring/auth_monitoring_config.json` |
| Layout de storage | `pricing-mlops-platform/mlops/configs/storage_layout.json` |
| Reglas de precios o defaults de negocio | `pricing-mlops-platform/mlops/configs/pricing_rules.example.json` mientras se formaliza contrato |
| Parametros de ambiente Azure | `.env`, Key Vault o inputs del pipeline, no hardcode en notebook |
| Overrides experimentales | Solo en notebook transicional, usando `AuthMonitoringConfig.with_overrides(...)` |

## Frontera Entre Repos

`pricing-mlops` conserva el codigo data science, componentes y notebooks controlados. No publica directo a Azure Blob, Azure ML tags ni SQL.

`pricing-mlops-platform` conserva IaC, Function, templates Azure ML, scripts operativos y `mlops/components/platform_publish_outputs.py`.

## Goal End To End Para Crear El Pipeline En Azure

Objetivo:
tener un Azure ML pipeline ejecutable desde Function/orquestador, visible en Azure ML Studio como steps separados, que use los componentes abstraidos de Avance 4 y publique artefactos en Storage sin correr notebooks productivamente.

### Fase 1: Congelar Contrato Entre Repos

1. En `pricing-mlops`, fijar el commit exacto que contiene `feature/avance4-pipeline-abstraction`.
2. En `pricing-mlops-platform`, actualizar `MODEL_REPO_REF` y `model_commit_sha` al branch/commit correcto.
3. Confirmar que el pipeline usa el repo fuente `tecmx-team46-pricing/pricing-mlops`.
4. Confirmar que `publish_outputs` usa solo outputs ya calculados.

Criterio de cierre:
el template apunta a una version concreta del repo de logica y no a un placeholder como `PoC/model-flow-template`.

### Fase 2: Validar El Template Azure ML

1. Revisar `mlops/azureml/pricing-mlops-pipeline.yml`.
2. Mantener los seis steps visibles:
   `validate_prepare`, `build_monitoring_inputs`, `calculate_recommendation_validity`, `calculate_auth_history_drift`, `calculate_operational_decision`, `publish_outputs`.
3. Conectar steps mediante outputs/inputs `flow_token`.
4. Verificar que cada step usa `identity: user_identity`.
5. Verificar que todos los comandos instalan/importan `pricing_mlops` desde el source descargado.

Criterio de cierre:
`python -m pytest tests/test_function_orchestrator.py tests/test_pipeline_e2e_scripts.py -q` pasa localmente.

### Fase 3: Preparar Infra Y Cuenta Nueva

1. Usar un solo resource group principal para esta etapa.
2. Validar `AZURE_SUBSCRIPTION_ID`, `AZURE_RESOURCE_GROUP`, `AZURE_ML_WORKSPACE`, `AZURE_FUNCTION_APP` y `AZURE_STORAGE_ACCOUNT`.
3. Confirmar que la cuenta anterior `team46pricing@outlook.com` ya no aparece en scripts, docs ni parametros activos.
4. Confirmar permisos de managed identity sobre Storage y Azure ML Workspace.
5. Ejecutar `what-if` de IaC si hay cambios pendientes de Bicep.

Criterio de cierre:
preflight de recursos encuentra workspace, function app, storage account y blobs requeridos.

### Fase 4: Sembrar Inputs Reales

1. Publicar baseline Avance 3 en el container esperado.
2. Publicar current AUTH history real/masked en el container esperado.
3. Definir:

```bash
MLOPS_BASELINE_SNAPSHOT_BLOB_PATH=<baseline-avance3>
MLOPS_CURRENT_AUTH_HISTORY_BLOB_PATH=<current-auth-history>
```

4. Ejecutar:

```bash
mlops/scripts/preflight_pipeline_e2e.sh staging
```

Criterio de cierre:
los blobs existen y el preflight no usa datos unmasked en `staging`.

### Fase 5: Publicar Function Y Ejecutar Pipeline

1. Publicar la Function con el template activo.
2. Ejecutar `mlops/scripts/run_model_flow_function.sh`.
3. Confirmar que la Function somete un Azure ML pipeline job, no un notebook job.
4. Revisar en Azure ML Studio que aparecen los seis nodos.
5. Revisar logs de cada step.

Criterio de cierre:
el run termina en `Completed` o falla en un step especifico con error accionable de datos/configuracion, no por placeholder o falta de wiring.

### Fase 6: Validar Artefactos Y Visualizacion

1. Verificar que existen los artefactos del contrato:
   snapshots, logs, summaries, reports y manifest.
2. Verificar publicacion particionada:

```text
environment=<env>/compute=azure-ml/trigger=<trigger>/owner=<owner>/run_date=<yyyymmdd>/run_id=<run_id>/
```

3. Comparar los outputs clave contra el notebook transicional.
4. Confirmar que Azure ML Studio muestra los artifacts del job y los logs por step.
5. Documentar la ruta final de Storage como fuente para dashboard.

Criterio de cierre:
los mismos tipos de artefactos que el notebook exportaba quedan generados por pipeline y publicados por plataforma.

### Fase 7: Cierre Tecnico

1. Actualizar evidencia en `docs/evidencia.md`.
2. Actualizar contrato operativo en `docs/azure-ml-job-contract.md`.
3. Commit atomico en `pricing-mlops-platform`.
4. Commit atomico en `pricing-mlops` si faltan ajustes de componentes.
5. No hacer push hasta que el run end to end haya sido revisado.

## Plan Para Cerrar La Etapa Actual

1. Mantener el branch `feature/avance4-pipeline-abstraction` en ambos repos hasta completar la validacion.
2. Confirmar que `MODEL_REPO_REF` apunta a un commit del repo `pricing-mlops` que contiene los componentes AUTH monitoring.
3. Publicar Function usando el template activo `mlops/azureml/pricing-mlops-pipeline.yml`.
4. Ejecutar preflight con blobs reales de baseline y current history.
5. Someter el job por Function con `mlops/scripts/run_model_flow_function.sh`.
6. Verificar en Azure ML Studio que aparecen los seis nodos.
7. Verificar Storage MLOps: `runs`, `snapshots`, `drift-logs`, `reports` y `artifacts`.
8. Comparar artefactos clave contra la copia transicional del notebook.

## No Objetivos De Esta Etapa

- No ejecutar notebooks completos dentro del pipeline como fuente operacional principal.
- No mover datos unmasked a `staging`.
- No crear grupos complejos ni ambientes nuevos.
- No convertir GitHub Actions en orquestador ML.
- No hacer retraining automatico; el semaforo decide accion operacional y revision.
