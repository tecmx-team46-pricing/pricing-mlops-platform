# Platform-Model Operating Contract

## Proposito

Definir el contrato operativo entre `pricing-mlops-platform` y `pricing-mlops-eda` para ejecutar validaciones, scoring y generacion de artefactos sin acoplar innecesariamente ambos repositorios.

El contrato se basa en tres reglas:

1. `pricing-mlops-platform` publica infraestructura, identidades, rutas y contratos no sensibles.
2. `pricing-mlops-eda` consume esos inputs por configuracion, ejecuta la logica de modelo y escribe artefactos versionados.
3. Ningun repo debe hardcodear secretos, account keys, rutas locales de datos reales ni supuestos de infraestructura no publicados.

## Responsabilidades

| Responsabilidad | `pricing-mlops-platform` | `pricing-mlops-eda` |
|---|---|---|
| Resource Groups, tags y ambientes | Crea y gobierna. | No crea ni modifica. |
| Storage/ADLS, contenedores y RBAC | Crea y publica nombres/rutas. | Consume y escribe artefactos autorizados. |
| Key Vault, salts/secrets e identidades | Crea y gobierna. | Lee secretos solo por identidad autorizada cuando aplica. |
| IaC y despliegues Azure | Mantiene Bicep, workflows de validate/what-if/deploy. | No contiene IaC de plataforma. |
| Modelo, scoring y validaciones | No contiene notebooks ni model code. | Implementa notebooks, scripts, validadores y scoring. |
| Contratos operativos | Define schemas y convenciones compartidas. | Implementa outputs que cumplen esos contratos. |
| Datos reales | No guarda datos en Git. | No guarda datos en Git; lee Storage/ADLS. |

## Inputs que platform entrega al repo modelo

Platform debe publicar estos valores por ambiente. Los valores no sensibles pueden estar en GitHub environment variables o archivos versionados; los sensibles viven en Key Vault.

| Input | Ejemplo de variable | Fuente recomendada | Uso en `pricing-mlops-eda` |
|---|---|---|---|
| Nombre de ambiente | `MLOPS_ENVIRONMENT=staging` | GitHub environment variable | Seleccionar rutas, permisos y etiquetas de salida. |
| Storage account | `AZURE_STORAGE_ACCOUNT=stpmlops...` | Output de IaC o GitHub environment variable | Construir URIs de lectura/escritura sin hardcodear. |
| Endpoint ADLS/Blob | `AZURE_STORAGE_DFS_ENDPOINT=https://...dfs.core.windows.net` | Derivado del storage account o output de plataforma | Acceso con SDK/CLI usando OIDC/RBAC. |
| Container raw masked/input | `MLOPS_CONTAINER_RAW_MASKED=raw-masked` o `input` | Config no sensible versionada o env var | Leer datasets masked. |
| Container curated | `MLOPS_CONTAINER_CURATED=curated` | Config no sensible | Leer/escribir features limpias. |
| Container baseline | `MLOPS_CONTAINER_BASELINE=baseline` | Config no sensible | Leer baseline y thresholds historicos. |
| Container runs | `MLOPS_CONTAINER_RUNS=runs` | Config no sensible | Escribir `model_run_log` y summaries. |
| Container snapshots | `MLOPS_CONTAINER_SNAPSHOTS=snapshots` | Config no sensible | Escribir `model_output_snapshot`. |
| Container drift logs | `MLOPS_CONTAINER_DRIFT_LOGS=drift-logs` | Config no sensible | Escribir `model_drift_log`. |
| Container reports | `MLOPS_CONTAINER_REPORTS=reports` | Config no sensible | Escribir reportes humanos no sensibles. |
| Container artifacts | `MLOPS_CONTAINER_ARTIFACTS=artifacts` | Config no sensible | Escribir manifests, graficas y evidencia auxiliar. |
| Key Vault URI | `AZURE_KEY_VAULT_URI=https://kv-...vault.azure.net/` | Output de IaC o env var | Resolver salts/secrets por identidad autorizada. |
| Client ID OIDC/Managed Identity | `AZURE_CLIENT_ID=...` | GitHub environment variable | Login federado de GitHub Actions. |
| Tenant ID | `AZURE_TENANT_ID=...` | GitHub environment variable | Login federado. |
| Subscription ID | `AZURE_SUBSCRIPTION_ID=...` | GitHub environment variable | Scope de Azure login. |
| Path pattern | `MLOPS_PATH_PATTERN={container}/environment={environment}/run_date={yyyy-mm-dd}/run_id={run_id}/` | Archivo versionado no sensible | Estandarizar layouts de salida. |
| Dataset version | `MLOPS_DATASET_VERSION=dataset_2026Q2_v1` | Workflow input o manifest en Storage | Registrar reproducibilidad de corrida. |
| Schema version | `MLOPS_SCHEMA_VERSION=pricing_input_schema_v1` | Archivo versionado o manifest | Validar compatibilidad de datos. |

`raw-unmasked` no es input normal del repo modelo. Solo un proceso de masking autorizado puede leerlo, y solo en `data-lab`/`secure-sandbox`.

## Outputs obligatorios del repo modelo

Cada corrida del repo modelo debe escribir un conjunto minimo de artefactos bajo un `run_id` unico. Los paths siguen el patron:

```text
{container}/environment={environment}/run_date={yyyy-mm-dd}/run_id={run_id}/
```

| Output | Container | Formato recomendado | Obligatorio | Contenido minimo |
|---|---|---|---|---|
| `model_run_log` | `runs` | JSON | Si | `run_id`, timestamps, commit hash, dataset/config/schema/model versions, status, actor, URIs de artefactos. |
| `model_output_snapshot` | `snapshots` | Parquet para volumen; JSONL aceptable en PoC | Si si hubo scoring | Recomendaciones por registro y columnas requeridas por `mlops/schemas/model_output_snapshot.schema.json`. |
| `model_drift_log` | `drift-logs` | JSONL o Parquet | Si si hubo drift | Variable, metrica, valor, thresholds, status y accion recomendada segun schema. |
| `reports` | `reports` | Markdown, HTML o PDF sin datos sensibles | Si | Resumen humano de validacion, scoring, drift, semaforo y decision. |
| `artifacts` | `artifacts` | JSON, CSV masked, imagenes, manifests | Opcional pero recomendado | Evidencia auxiliar, graficas, validation results y manifests. Nunca unmasked. |
| Exit status | GitHub Actions status + `model_run_log.status` | Exit code | Si | `0` para exito; no cero para falla tecnica o quality gate rojo que debe bloquear. |

### Estados y exit codes

| Situacion | Exit code | `model_run_log.status` | Resultado operativo |
|---|---:|---|---|
| Validacion/scoring completo | `0` | `succeeded` | Artefactos completos publicados. |
| Drift `green` o `yellow` sin bloqueo | `0` | `succeeded` | Reporte marca decision; negocio revisa si aplica. |
| Quality gate critico falla | `2` | `failed` | No publicar snapshot como aprobado; escribir reporte de falla. |
| Drift `red` configurado como bloqueo | `3` | `failed` o `succeeded` con accion `recalibrate_or_retrain` segun politica | No promover outputs sin revision. |
| Error tecnico | `1` | `failed` | Corrida fallida; logs y artefactos parciales si existen. |
| Configuracion faltante | `4` | `failed` | Fallo temprano; no inferir defaults peligrosos. |

El repo modelo debe preferir fallar temprano cuando falten inputs de plataforma. No debe inventar nombres de storage, contenedores o Key Vault.

## Configuracion

### GitHub environment variables

Usar para valores no secretos y distintos por ambiente:

```text
MLOPS_ENVIRONMENT
AZURE_CLIENT_ID
AZURE_TENANT_ID
AZURE_SUBSCRIPTION_ID
AZURE_STORAGE_ACCOUNT
AZURE_STORAGE_DFS_ENDPOINT
AZURE_KEY_VAULT_URI
MLOPS_CONTAINER_RAW_MASKED
MLOPS_CONTAINER_CURATED
MLOPS_CONTAINER_BASELINE
MLOPS_CONTAINER_RUNS
MLOPS_CONTAINER_SNAPSHOTS
MLOPS_CONTAINER_DRIFT_LOGS
MLOPS_CONTAINER_REPORTS
MLOPS_CONTAINER_ARTIFACTS
```

### Azure Key Vault

Usar para secretos o material sensible:

- salts de hashing/tokenizacion;
- credenciales de fuentes upstream;
- secretos temporales de integracion;
- referencias sensibles que no deben quedar en logs.

GitHub Actions debe acceder por OIDC/RBAC. No se deben pasar secrets de Key Vault como literales versionados.

### Archivos versionados no sensibles

Usar para contratos y defaults seguros:

- schemas JSON;
- thresholds aprobados;
- nombres logicos de containers;
- path patterns;
- reglas de validacion;
- documentacion de columnas.

Estos archivos no deben contener account keys, connection strings, CSVs reales, Parquet reales ni samples unmasked.

### Storage paths

Usar Storage/ADLS como interfaz de datos entre repos:

- platform crea contenedores y permisos;
- modelo lee `raw-masked`, `curated` y `baseline`;
- modelo escribe `runs`, `snapshots`, `drift-logs`, `reports` y `artifacts`;
- `raw-unmasked` queda fuera del flujo normal de scoring.

## GitHub Actions esperadas

### `pricing-mlops-platform`

| Workflow | Trigger | Contrato |
|---|---|---|
| `platform-infra.yml` | PR, `workflow_dispatch` | Valida Bicep, ejecuta what-if/deploy manual y publica outputs de ambiente. |
| `platform-contracts.yml` futuro | PR | Valida schemas y archivos de contrato sin ejecutar modelo. |
| `platform-observability.yml` futuro | Manual | Valida queries/alertas cuando existan. |

Platform no ejecuta scoring productivo ni notebooks. El workflow actual `.github/workflows/mlops.yml` debe mantenerse limitado a contratos/PoC hasta que el repo modelo asuma sus pipelines.

### `pricing-mlops-eda`

| Workflow | Trigger | Contrato |
|---|---|---|
| `model-ci.yml` | PR | Lint, tests unitarios, validaciones con fixtures sinteticos o masked. |
| `data-contract-ci.yml` | PR | Verifica compatibilidad con schemas y reglas de calidad. |
| `run-sandbox.yml` | Manual | Ejecuta validacion/scoring en sandbox con Storage/ADLS y OIDC. |
| `run-staging.yml` | Manual con aprobacion si aplica | Ejecuta corrida staging con masked/curated, publica outputs obligatorios. |
| `run-validation.yml` | Manual con aprobacion | Ejecuta corrida controlada, conserva evidencia y reportes. |
| `model-package.yml` futuro | Tag o manual | Empaqueta version de modelo/scoring sin datos sensibles. |

Los workflows del repo modelo deben aceptar inputs como `dataset_version`, `baseline_version`, `schema_version`, `model_version` y `environment`.

## Versionado y reproducibilidad

Cada corrida debe registrar:

| Campo | Fuente | Regla |
|---|---|---|
| `git_commit_hash` | `pricing-mlops-eda` | SHA exacto que ejecuto scoring/validaciones. |
| `platform_commit_hash` | `pricing-mlops-platform` cuando sea conocido | SHA de IaC/contratos usados para el ambiente. |
| `dataset_version` | Manifest de Storage o workflow input | Version del dataset masked/curated. |
| `schema_version` | Archivo versionado o manifest | Version de contrato de datos validada. |
| `model_version` | Tag, package version o commit | Version logica del modelo/scoring. |
| `config_version` | Thresholds/reglas versionadas | Version de reglas de drift/calidad/pricing. |
| `baseline_version` | Storage `baseline` | Baseline usado para comparar drift. |
| `run_id` | Generado por workflow/model repo | Unico por corrida; usado como particion de outputs. |

Sin estos campos, la corrida no es reproducible y no debe promoverse.

## Limites de acoplamiento

- El repo modelo no crea Resource Groups, Key Vault, Storage Accounts, role assignments permanentes ni redes.
- Platform no contiene notebooks productivos, model code, feature engineering ni scoring.
- Los datos no viven en Git: ni unmasked, ni masked reales, ni Parquet/CSV de corridas.
- El repo modelo no hardcodea nombres fisicos de recursos; usa variables/outputs publicados por plataforma.
- Platform no interpreta internamente la logica del modelo; valida existencia, formato y trazabilidad de outputs.
- Los secretos no se pasan por archivos versionados ni GitHub artifacts.
- `staging` y `validation` no reciben `raw-unmasked` por default.

## Handshake operativo

1. Platform despliega o valida el ambiente.
2. Platform publica variables no sensibles y permisos OIDC del ambiente.
3. Repo modelo ejecuta preflight: verifica login Azure, storage account, containers, Key Vault URI y permisos.
4. Repo modelo lee dataset/versiones desde Storage/ADLS.
5. Repo modelo ejecuta validacion, scoring y drift.
6. Repo modelo escribe outputs obligatorios bajo `run_id`.
7. Platform y reviewers validan que existan `model_run_log`, snapshots, drift logs, reports y artifacts esperados.
8. Si la corrida cumple criterios, se conserva evidencia o se promueve a la siguiente fase.

## Relacion con docs actuales

Este contrato concreta la interfaz descrita en:

- `docs/multi-repo-mlops-deployment-plan.md`;
- `docs/data-governance-plan.md`;
- `docs/azure-phased-deployment-plan.md`;
- `mlops/docs/data-contracts.md`.

No cambia IaC ni mueve responsabilidades. Define como operar el modelo sin hardcodear infraestructura y sin convertir `pricing-mlops-platform` en repo de modelo.
