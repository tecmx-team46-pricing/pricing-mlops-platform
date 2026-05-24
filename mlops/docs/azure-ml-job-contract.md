# Azure ML Job Contract

El job remoto se define en `mlops/azureml/pricing-mlops-job.yml`.

El YAML usa:

```yaml
code: ../pricing-mlops-source
command: >-
  python -m pip install -e . &&
  python scripts/run_azure_ml_flow.py
```

`../pricing-mlops-source` existe dentro del paquete de Azure Functions preparado por `mlops/scripts/publish_orchestrator_function.sh`. Esa carpeta es un snapshot del repo `pricing-mlops`, que mantiene el codigo data science alineado con Cookiecutter Data Science.

Inputs inyectados por la Function:

```text
storage_account
environment
run_owner
run_id
input_blob_path
```

Outputs funcionales esperados:

```text
<container>/environment=<env>/compute=azure-ml/owner=<owner>/run_date=<yyyymmdd>/run_id=<run_id>/<artifact>
```

Azure ML puede generar snapshots, logs, environments y artifacts internos en el storage runtime del workspace. Esos artifacts no son outputs funcionales del modelo.
