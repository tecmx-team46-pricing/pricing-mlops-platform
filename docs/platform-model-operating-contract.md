# Platform-Model Operating Contract

Contrato entre `pricing-mlops-platform` y `pricing-mlops`.

## Responsabilidades

| Tema | `pricing-mlops-platform` | `pricing-mlops` |
|---|---|---|
| Azure/IaC | Crea Resource Groups, Storage/ADLS, Key Vault, Log Analytics, OIDC y RBAC. | No crea infraestructura. |
| Datos | Publica rutas, containers y permisos. | Lee inputs autorizados y escribe artefactos. |
| Modelo | No contiene scoring productivo. | Implementa validacion, curated, scoring, drift y reportes. |
| Seguridad | Evita secrets en Git, account keys y permisos amplios. | Usa OIDC/RBAC y no accede a `raw-unmasked` por default. |

## Inputs Que Plataforma Publica

Valores no sensibles por ambiente:

| Variable | Uso |
|---|---|
| `MLOPS_ENVIRONMENT` | Ambiente logico compartido: `staging` o `validation` para GitHub Actions. Sandboxes personales son local/admin. |
| `MLOPS_RUN_OWNER` | Owner logico de la corrida, por ejemplo `team46` o usuario. |
| `MLOPS_COMPUTE_TARGET` | Target que ejecuto el flujo: `azure-ml`; `functions` y `container-job` solo para evidencia PoC/legacy. |
| `AZURE_CLIENT_ID` | Client ID OIDC del repo `pricing-mlops`; para GitHub Actions debe venir del ambiente compartido, normalmente `staging`. |
| `AZURE_TENANT_ID` | Tenant Azure. |
| `AZURE_SUBSCRIPTION_ID` | Subscription Azure. |
| `AZURE_STORAGE_ACCOUNT` | Storage Account del workload. |
| `AZURE_STORAGE_DFS_ENDPOINT` | Endpoint ADLS/DFS. |
| `AZURE_KEY_VAULT_URI` | Futuro uso de salts/secrets; el pipeline minimo no lo requiere. |
| `MLOPS_CONTAINER_RAW_MASKED` | Container de input masked, normalmente `raw-masked` o `input`. |
| `MLOPS_CONTAINER_CURATED` | Features limpias. |
| `MLOPS_CONTAINER_BASELINE` | Baselines y thresholds. |
| `MLOPS_CONTAINER_RUNS` | `model_run_log` y summaries. |
| `MLOPS_CONTAINER_SNAPSHOTS` | `model_output_snapshot`. |
| `MLOPS_CONTAINER_DRIFT_LOGS` | `model_drift_log`. |
| `MLOPS_CONTAINER_REPORTS` | Reportes humanos no sensibles. |
| `MLOPS_CONTAINER_ARTIFACTS` | Manifests y evidencia auxiliar. |

`raw-unmasked` no es input normal del repo modelo. Solo existe en `data-lab`/`secure-sandbox` con acceso restringido.

## Outputs Que Modelo Debe Escribir

Cada corrida escribe bajo:

```text
environment=<environment>/owner=<owner>/run_date=<yyyy-mm-dd>/run_id=<run_id>/
```

Para pruebas comparativas de compute, el layout debe incluir el target:

```text
environment=<environment>/compute=<compute-target>/owner=<owner>/run_date=<yyyy-mm-dd>/run_id=<run_id>/
```

| Output | Container | Formato PoC | Obligatorio |
|---|---|---|---|
| `model_run_log` | `runs` | JSON | Si |
| `model_output_snapshot` | `snapshots` | CSV o Parquet | Si cuando hay scoring |
| `model_drift_log` | `drift-logs` | JSON | Si cuando hay drift |
| `report.md` | `reports` | Markdown | Si |
| evidencia auxiliar | `artifacts` | JSON/CSV masked/imagenes | Opcional |

`model_run_log` debe incluir al menos:

- `run_id`
- timestamps
- status
- `git_commit_hash`
- `dataset_version`
- `schema_version`
- `model_version`
- `config_version`
- paths de artefactos

## Estados

| Estado | Significado |
|---|---|
| `succeeded` | Validacion/scoring/drift terminaron y artefactos fueron publicados. |
| `failed` | Error tecnico o quality gate critico. |
| `green` | Sin cambio relevante. |
| `yellow` | Requiere revision. |
| `red` | Bloquear promocion o recalibrar/reentrenar. |

## Pipeline Minimo Azure

Meta operativa actual:

```text
script operativo o prueba controlada
-> llamar Azure Function /api/model-flow
-> Function valida parametros y somete Azure ML command job
-> ejecutar flow ML dentro de Azure ML
-> subir outputs a Storage/ADLS con compute=azure-ml
```

El input compartido minimo es `raw-masked/samples/sample_pricing_v1.csv`. GitHub Actions no debe ser el compute principal ni el orquestador operativo; su rol normal es CI/CD, publicacion y pruebas controladas.

Azure Functions queda como orquestador ligero para iniciar jobs AML. En `staging`, la Function puede desplegarse en una region distinta (`centralus`) para evitar quota 0 de App Service/Functions sin mover Storage ni Azure ML. El endpoint usa Function key como control temporal; la siguiente iteracion debe evaluar Entra ID/Easy Auth o API Management. Si la Function no despliega por quota, GitHub Actions puede someter AML directamente como fallback de emergencia, sin ejecutar el ML en el runner.

## Limites

- El repo modelo no crea Resource Groups, Storage Accounts, Key Vault, redes ni role assignments permanentes.
- El repo plataforma no interpreta la logica interna del modelo.
- No se comparten secrets por Git.
- No se usan account keys ni connection strings.
- `staging`, `validation` y `sandbox-local` no reciben `raw-unmasked`.
- `sandbox-local` no es patron para GitHub Actions del modelo; cualquier identidad OIDC sandbox existente queda legacy/deprecated.
