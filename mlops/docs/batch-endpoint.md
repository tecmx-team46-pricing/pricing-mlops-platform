# Azure ML Batch Endpoint

El flujo AUTH monitoring se expone sin Azure Function mediante un Azure ML Batch Endpoint.

## Ownership

`pricing-mlops` es dueno del pipeline funcional completo:

- componentes internos derivados del notebook;
- pipeline component `pricing_mlops_auth_monitoring_pipeline`;
- versionado y registro de ese pipeline component en Azure ML.

`pricing-mlops-platform` es dueno de la publicacion operativa:

- Azure ML Batch Endpoint;
- Batch Deployment;
- identidad, Storage, RBAC e invocacion;
- smoke test del endpoint publicado.

Platform no debe listar ni versionar los steps internos del pipeline. Solo promueve un pipeline component ya registrado por `pricing-mlops`.

## Contrato De Promocion

El pipeline component externo se declara en:

```text
mlops/manifests/auth-monitoring-pipeline-component.json
```

Formato:

```json
{
  "release": "auth-monitoring-0.1.1",
  "owner_repo": "tecmx-team46-pricing/pricing-mlops",
  "pipeline_component": "azureml:pricing_mlops_auth_monitoring_pipeline:0.1.1"
}
```

Tambien puede sobreescribirse por ambiente:

```bash
AZURE_ML_PIPELINE_COMPONENT=azureml:pricing_mlops_auth_monitoring_pipeline:0.1.2 \
mlops/scripts/deploy_auth_monitoring_batch_endpoint.sh
```

Prerequisito: `pricing-mlops` debe registrar esa version de
`pricing_mlops_auth_monitoring_pipeline` antes de que platform la promueva. Este repo valida que el
component exista, pero no lo crea.

## Deploy

```bash
AZURE_SUBSCRIPTION_NAME=Tecmx \
AZURE_RESOURCE_GROUP=rg-pricing-mlops-main \
AZURE_ML_WORKSPACE=mlw-pmlops-06152240 \
mlops/scripts/deploy_auth_monitoring_batch_endpoint.sh
```

El script valida que el pipeline component exista en Azure ML antes de crear o actualizar el endpoint/deployment.

## Invoke

```bash
AZURE_RESOURCE_GROUP=rg-pricing-mlops-main \
AZURE_ML_WORKSPACE=mlw-pmlops-06152240 \
AZURE_STORAGE_ACCOUNT=stpmlops06152240 \
AZURE_ML_JOB_IDENTITY_CLIENT_ID=<client-id> \
MLOPS_INPUT_BLOB_PATH=samples/auth_monitoring_sample.csv \
MLOPS_BASELINE_SNAPSHOT_BLOB_PATH=baseline/auth_monitoring_sample_baseline.csv \
MLOPS_CURRENT_AUTH_HISTORY_BLOB_PATH=samples/auth_monitoring_sample.csv \
mlops/scripts/invoke_auth_monitoring_batch_endpoint.sh
```

Las invocaciones del script usan el experimento `pricing-mlops-batch-endpoint` para agrupar los runs operativos.

## Flujo

```text
pricing-mlops CI/CD
  -> registra azureml:pricing_mlops_auth_monitoring_pipeline:<version>
  -> publica manifest o version

pricing-mlops-platform
  -> valida que el pipeline component exista
  -> actualiza Batch Endpoint deployment
  -> invoca smoke test
  -> verifica artefactos en Storage
```
