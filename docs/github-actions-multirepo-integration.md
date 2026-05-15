# GitHub Actions Multi-Repo Integration

## Proposito

Preparar la integracion entre `pricing-mlops-platform` y `pricing-mlops-eda` usando GitHub Actions, OIDC y variables por environment, sin desplegar produccion ni introducir secretos hardcodeados.

Este documento define el contrato operativo de CI/CD. No ejecuta despliegues nuevos por si mismo.

## Principios

1. `pricing-mlops-platform` despliega y gobierna Azure.
2. `pricing-mlops-eda` valida codigo/model contracts, ejecuta scoring y publica artefactos.
3. Ambos repos usan OIDC; no se guardan client secrets, account keys ni connection strings en Git.
4. El repo modelo no necesita `Owner` ni `Contributor` sobre la subscription.
5. `prod` no existe como GitHub environment operativo en esta fase.

## Workflows esperados por repo

### `pricing-mlops-platform`

| Workflow | Trigger | Azure login | Responsabilidad | Estado |
|---|---|---|---|---|
| `platform-infra.yml` validate | `pull_request` | No | Compilar `infra/foundation/main.bicep`, `infra/workloads/pricing-mlops/main.bicep` y parameter files. | Actual. |
| `platform-infra.yml` what-if | `workflow_dispatch` | Si, OIDC | Ejecutar `scripts/what-if.sh <environment>` con aprobacion manual del usuario. | Actual. |
| `platform-infra.yml` deploy | `workflow_dispatch` | Si, OIDC | Ejecutar deploy manual despues de what-if. No corre automaticamente en PR. | Actual. |
| Publicacion de outputs | Despues de deploy manual | Si, OIDC | Publicar valores no sensibles para el repo modelo: storage, Key Vault URI, containers y `DATA_ROOT`. | Preparar; no requiere secretos. |

Los outputs publicados deben ser no sensibles. El mecanismo puede ser un GitHub Actions artifact `platform-outputs-<environment>.json`, una actualizacion manual de GitHub environment variables o documentacion operativa desde los outputs de IaC. No se deben publicar secrets de Key Vault.

### `pricing-mlops-eda`

| Workflow | Trigger | Azure login | Responsabilidad |
|---|---|---|---|
| `model-ci.yml` | `pull_request` | No | Lint/tests unitarios, validadores locales y contratos con fixtures sinteticos o masked. |
| `data-contract-ci.yml` | `pull_request` | No | Verificar schemas, expectativas de datos y compatibilidad con contratos versionados. |
| `run-sandbox.yml` | `workflow_dispatch` | Si, OIDC | Ejecutar validacion/scoring contra `sandbox-david` con datos masked/curated. |
| `run-staging.yml` | `workflow_dispatch` con aprobacion | Si, OIDC | Ejecutar scoring staging y subir artefactos a Storage. |
| `run-validation.yml` | `workflow_dispatch` con aprobacion | Si, OIDC | Ejecutar corrida controlada y publicar evidencia versionada. |

El repo modelo no despliega Resource Groups, Key Vault, Storage Accounts, redes ni role assignments permanentes.

## GitHub environments

| Environment | Repo platform | Repo model | Uso |
|---|---|---|---|
| `sandbox-david` | What-if/deploy manual de plataforma y outputs no sensibles. | Ejecucion manual de validacion/scoring con datos masked/curated. | PoC de integracion. |
| `data-lab` | Bootstrap/control de Storage seguro, preferentemente local/admin hasta revisar permisos. | No acceso por default a `raw-unmasked`; masking futuro requiere identidad separada. | Zona segura de datos. |
| `staging` | What-if/deploy manual de plataforma. | Corridas manuales staging con aprobacion si aplica. | MVP no productivo. |
| `validation` | What-if/deploy manual de plataforma. | Corridas controladas con evidencia y aprobacion. | Validacion pre-prod conceptual. |

No crear `prod` hasta que exista aprobacion explicita, IaC dedicado y revisiones de seguridad/costo.

## Variables por environment

Estas variables son valores no secretos. Deben vivir como GitHub environment variables, no como repository secrets salvo que GitHub obligue por politica local.

| Variable | Repo platform | Repo model | Descripcion |
|---|---|---|---|
| `AZURE_CLIENT_ID` | Si | Si | Client ID de la identidad federada OIDC del repo/environment. |
| `AZURE_TENANT_ID` | Si | Si | Tenant de Azure. |
| `AZURE_SUBSCRIPTION_ID` | Si | Si | Subscription objetivo. |
| `STORAGE_ACCOUNT` | Publica | Consume | Storage Account del ambiente. Alias recomendado para el repo modelo. |
| `AZURE_STORAGE_ACCOUNT` | Usa actualmente | Opcional | Alias de compatibilidad con workflows existentes del platform repo. |
| `KEY_VAULT_URI` | Publica | Consume si aplica | URI del Key Vault; no contiene secretos por si mismo. |
| `AZURE_KEY_VAULT_URI` | Opcional | Opcional | Alias de compatibilidad para SDK/scripts Azure. |
| `DATA_ROOT` | Publica | Consume | Raiz logica de datos, por ejemplo `https://<storage>.dfs.core.windows.net`. |
| `MLOPS_ENVIRONMENT` | Opcional | Si | `sandbox-david`, `data-lab`, `staging` o `validation`. |
| `MLOPS_CONTAINER_RAW_MASKED` | Publica | Consume | Normalmente `raw-masked` o `input` segun ambiente. |
| `MLOPS_CONTAINER_CURATED` | Publica | Consume | `curated`. |
| `MLOPS_CONTAINER_BASELINE` | Publica | Consume | `baseline`. |
| `MLOPS_CONTAINER_RUNS` | Publica | Consume | `runs`. |
| `MLOPS_CONTAINER_SNAPSHOTS` | Publica | Consume | `snapshots`. |
| `MLOPS_CONTAINER_DRIFT_LOGS` | Publica | Consume | `drift-logs`. |
| `MLOPS_CONTAINER_REPORTS` | Publica | Consume | `reports`. |
| `MLOPS_CONTAINER_ARTIFACTS` | Publica | Consume | `artifacts`. |

`raw-unmasked` no debe exponerse como variable normal para el repo modelo. Si se crea un proceso de masking en `pricing-mlops-eda`, debe usar un environment separado, aprobacion explicita y RBAC restringido a esa identidad.

## Outputs que platform debe publicar

Despues de un deploy manual, platform debe entregar este payload no sensible:

```json
{
  "environment": "staging",
  "storageAccount": "stpmlops...",
  "dataRoot": "https://stpmlops....dfs.core.windows.net",
  "keyVaultUri": "https://kv-pmlops-....vault.azure.net/",
  "containers": {
    "rawMasked": "raw-masked",
    "curated": "curated",
    "baseline": "baseline",
    "runs": "runs",
    "snapshots": "snapshots",
    "driftLogs": "drift-logs",
    "reports": "reports",
    "artifacts": "artifacts"
  }
}
```

Para ambientes existentes que todavia usan `input`, `rawMasked` puede mapear a `input` hasta migrar el layout.

## OIDC y RBAC

### Platform repo

| Scope | Rol recomendado | Motivo |
|---|---|---|
| Subscription o deployment scopes necesarios | `Contributor` durante PoC | Desplegar RGs y recursos a scope subscription. Revisar antes de prod. |
| Key Vault | `Key Vault Secrets User` si necesita leer secretos de despliegue | Evitar secrets en GitHub. |
| Storage workload | `Storage Blob Data Contributor` solo si workflow sube artefactos de plataforma | No requerido para validar Bicep. |

### Model repo

| Scope | Rol recomendado | Motivo |
|---|---|---|
| Contenedores `raw-masked`, `curated`, `baseline` | `Storage Blob Data Reader` o `Storage Blob Data Contributor` si escribe curated | Leer inputs sin acceso a RG. |
| Contenedores `runs`, `snapshots`, `drift-logs`, `reports`, `artifacts` | `Storage Blob Data Contributor` | Publicar outputs MLOps. |
| Key Vault | `Key Vault Secrets User` solo si necesita salts/secrets aprobados | Resolver secretos sin hardcodearlos. |
| Resource Groups/subscription | Ningun `Owner`; evitar `Contributor` | El modelo no despliega infraestructura. |
| `raw-unmasked` | Sin acceso por default | Separar unmasked del scoring normal. |

El repo modelo debe operar con permisos de data plane sobre Storage/Key Vault, no con permisos amplios de management plane.

## Upload de artefactos del repo modelo

Los workflows manuales del repo modelo deben:

1. Autenticarse con `azure/login@v2` usando OIDC.
2. Ejecutar preflight de variables: `STORAGE_ACCOUNT`, `DATA_ROOT`, `MLOPS_ENVIRONMENT` y containers requeridos.
3. Generar `run_id` y registrar `git_commit_hash`, `dataset_version`, `schema_version`, `model_version` y `config_version`.
4. Subir outputs a Storage con `--auth-mode login` o SDK Azure con credenciales federadas.
5. Publicar tambien un GitHub artifact solo con reportes no sensibles.

Ejemplo conceptual:

```bash
az storage blob upload-batch \
  --account-name "${STORAGE_ACCOUNT}" \
  --auth-mode login \
  --destination "${MLOPS_CONTAINER_RUNS}" \
  --destination-path "environment=${MLOPS_ENVIRONMENT}/run_date=${RUN_DATE}/run_id=${RUN_ID}" \
  --source outputs/runs \
  --overwrite true
```

## Reglas de seguridad

- No guardar secrets, salts, account keys, connection strings ni datos en Git.
- No subir CSVs/Parquet reales como GitHub artifacts.
- No dar `Owner` al repo modelo.
- No dar acceso de `raw-unmasked` a workflows de scoring por default.
- No activar despliegues automaticos desde PR.
- No crear production environment en esta fase.
- No usar `pull_request_target` para workflows que tengan OIDC o acceso a Azure.

## Relacion con el contrato operativo

Este documento complementa `docs/platform-model-operating-contract.md`. Ese contrato define la interfaz de datos y artefactos; este documento define como GitHub Actions, environments, variables y RBAC materializan esa interfaz entre repos.
