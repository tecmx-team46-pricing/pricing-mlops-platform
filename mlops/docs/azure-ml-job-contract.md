# Azure ML Pipeline/Job Contract

La ruta AUTH monitoring principal se define en `mlops/azureml/pricing-mlops-pipeline.yml`.

El pipeline activo expone los pasos derivados del notebook de monitoreo:

| Nodo | Entrypoint | Contrato |
|---|---|---|
| `validate_prepare` | `scripts/components/validate_prepare.py` | Lee `raw-masked/<input_blob_path>`, valida y produce `curated_input.csv` + `validation_metadata.json`. |
| `build_monitoring_inputs` | `scripts/components/build_monitoring_inputs.py` | Prepara snapshots normalizados para monitoreo. |
| `calculate_recommendation_validity` | `scripts/components/calculate_recommendation_validity.py` | Calcula validez de recomendacion y summaries. |
| `calculate_auth_history_drift` | `scripts/components/calculate_auth_history_drift.py` | Calcula drift de AUTH history contra baseline. |
| `calculate_operational_decision` | `scripts/components/calculate_operational_decision.py` | Genera semaforo operacional y manifest final. |
| `publish_outputs` | `mlops/components/platform_publish_outputs.py` | Publica los outputs funcionales al Storage MLOps. |

Los componentes usan:

```yaml
code: ../pricing-mlops-source
```

`../pricing-mlops-source` existe dentro del paquete de Azure Functions preparado por `mlops/scripts/publish_orchestrator_function.sh`. Azure ML v2 no trata `code:` como un repo GitHub vivo; `code:` apunta a esa carpeta local y el SDK sube ese snapshot al someter el pipeline/job. Esa carpeta es un snapshot del repo `pricing-mlops`, que mantiene el codigo data science alineado con Cookiecutter Data Science.

La plataforma resuelve el snapshot con `MODEL_REPO_GITHUB` + `MODEL_REPO_REF` durante el empaquetado. Usar commit SHA o tag es la opcion mas reproducible; un branch es valido pero menos estricto porque puede apuntar a otro commit despues. Para desarrollo local se permite `MODEL_REPO_PATH` solo con `ALLOW_LOCAL_MODEL_SOURCE=true`; la Azure Function no clona GitHub por evento.

Inputs inyectados por la Function:

```text
storage_account
environment
run_owner
run_id
input_blob_path
trigger_type
model_repo
model_ref
model_commit_sha
monitoring_config_version
```

`monitoring_config_version` corresponde a `mlops/configs/drift_thresholds.json`.
El step `publish_outputs` guarda esa version y el SHA-256 del archivo en
`model_run_log.json` para reproducibilidad de la configuracion del semaforo.

Outputs funcionales esperados:

```text
<container>/environment=<env>/compute=azure-ml/trigger=<manual|event-grid>/owner=<owner>/run_date=<yyyymmdd>/run_id=<run_id>/<artifact>
```

Azure ML puede generar snapshots, logs, environments y artifacts internos en el storage runtime del workspace. Esos artifacts no son outputs funcionales del modelo.
