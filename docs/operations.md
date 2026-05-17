# Operations

Runbook operativo para el repo plataforma. Para variables de GitHub/OIDC, usar [`github-actions.md`](github-actions.md).

## Preflight

```bash
az login
az account set --subscription "<azure-subscription-name>"
az account show --query "{name:name, id:id}" --output table
```

Los scripts aceptan:

```text
staging
sandbox-local
validation
data-lab
```

`shared` se despliega desde foundation, pero no se opera como ambiente MLOps. `prod` no existe.

## Validar Localmente

```bash
scripts/validate-mlops-contracts.py
az bicep build --file infra/foundation/main.bicep
az bicep build --file infra/workloads/pricing-mlops/main.bicep
az bicep build-params --file infra/parameters/sandbox-local.bicepparam
```

## What-If

```bash
scripts/what-if.sh sandbox-local
```

Los sandboxes personales se operan solo desde local/admin. Los scripts bloquean `sandbox-*` cuando `GITHUB_ACTIONS=true`.

`staging` habilita el Container Apps Job del modelo. `sandbox-local` queda para pruebas local/admin y no se opera desde GitHub Actions.

## Deploy Minimo

```bash
scripts/deploy.sh sandbox-local
```

Ese despliegue prepara el pipeline Azure minimo:

- Resource Groups.
- Key Vault y Log Analytics en `shared`.
- Storage/ADLS y containers del workload.
- Sin identidades OIDC por default para sandboxes personales.

No crea AML, ADF, SQL ni prod.

## Container Apps Model Flow

El Container Apps Job es el compute minimo del flujo MLOps. La infraestructura se crea desde este repo; el codigo runtime se empaqueta como imagen desde `pricing-mlops` y GitHub Actions la publica en ACR antes de iniciar el job:

```bash
scripts/deploy.sh staging
```

Recursos esperados en `staging`:

```text
acrpmlops...
cae-pricing-mlops-staging
job-pricing-mlops-staging
id-pricing-mlops-job-staging-legacy
```

La identidad de GitHub del repo modelo publica la imagen y arranca el job. La identidad del job lee `raw-masked` y escribe outputs en Storage. No se usan account keys ni connection strings.

## Data-Lab

```bash
scripts/what-if.sh data-lab
scripts/deploy.sh data-lab
```

`data-lab` crea Storage/ADLS para zonas sensibles, incluyendo `raw-unmasked`. No despliega compute del modelo y no debe entregar acceso automatico a GitHub Actions.

## GitHub Actions

`.github/workflows/platform-infra.yml`:

| Trigger | Comportamiento |
|---|---|
| `pull_request` | Compila Bicep y parameter files. No hace Azure login ni deploy. |
| `workflow_dispatch`, `validate` | Valida sin deploy. |
| `workflow_dispatch`, `what-if` | Login OIDC y `scripts/what-if.sh`. |
| `workflow_dispatch`, `deploy` | What-if y luego `scripts/deploy.sh`. |

Configurar environments y variables en [`github-actions.md`](github-actions.md).

GitHub Actions solo opera ambientes compartidos/controlados (`staging`, `validation`). `sandbox-local` y futuros `sandbox-*` son local/admin only.

## Revision Semanal

- Revisar costos del credito Azure.
- Confirmar sandboxes activos.
- Revisar corridas `yellow/red`.
- Borrar recursos temporales aprobados para limpieza.
- Promover a IaC solo recursos que se repiten o que otros consumen.
