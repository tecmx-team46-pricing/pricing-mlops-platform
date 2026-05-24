# Azure ML Pipeline/Job Contract

La ruta preferida se define en `mlops/azureml/pricing-mlops-pipeline.yml`. El fallback command job se conserva en `mlops/azureml/pricing-mlops-job.yml`.

El pipeline activo tiene tres nodos visibles:

| Nodo | Entrypoint | Contrato |
|---|---|---|
| `validate_prepare` | `scripts/components/validate_prepare.py` | Lee `raw-masked/<input_blob_path>`, valida y produce `curated_input.csv` + `validation_metadata.json`. |
| `score_evaluate` | `scripts/components/score_evaluate.py` | Lee el intermedio, scorea, calcula drift y escribe los cinco artefactos funcionales locales. |
| `publish_outputs` | `scripts/components/publish_outputs.py` | Publica los seis outputs funcionales al Storage MLOps. |

Los componentes usan:

```yaml
code: ../pricing-mlops-source
```

El fallback command job usa:

```yaml
code: ../pricing-mlops-source
command: >-
  python -m pip install -e . &&
  python scripts/run_azure_ml_flow.py
```

`../pricing-mlops-source` existe dentro del paquete de Azure Functions preparado por `mlops/scripts/publish_orchestrator_function.sh`. Esa carpeta es un snapshot del repo `pricing-mlops`, que mantiene el codigo data science alineado con Cookiecutter Data Science.

La plataforma resuelve el snapshot con `MODEL_REPO_GITHUB` + `MODEL_REPO_REF` durante el empaquetado. Para desarrollo local se permite `MODEL_REPO_PATH`; la Azure Function no clona GitHub por evento.

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
```

Outputs funcionales esperados:

```text
<container>/environment=<env>/compute=azure-ml/trigger=<manual|event-grid>/owner=<owner>/run_date=<yyyymmdd>/run_id=<run_id>/<artifact>
```

Azure ML puede generar snapshots, logs, environments y artifacts internos en el storage runtime del workspace. Esos artifacts no son outputs funcionales del modelo.
