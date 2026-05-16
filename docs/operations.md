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
sandbox-david
validation
data-lab
```

`shared` se despliega desde foundation, pero no se opera como ambiente MLOps. `prod` no existe.

## Validar Localmente

```bash
scripts/validate-mlops-contracts.py
az bicep build --file infra/foundation/main.bicep
az bicep build --file infra/workloads/pricing-mlops/main.bicep
az bicep build-params --file infra/parameters/sandbox-david.bicepparam
```

## What-If

```bash
scripts/what-if.sh sandbox-david
```

Los sandboxes personales se operan solo desde local/admin. Los scripts bloquean `sandbox-*` cuando `GITHUB_ACTIONS=true`.

Mientras la cuota de App Service/Functions siga bloqueada, validar solo foundation y Storage:

```bash
ENABLE_HELLO_FUNCTION=false scripts/what-if.sh sandbox-david
```

## Deploy Minimo

```bash
ENABLE_HELLO_FUNCTION=false scripts/deploy.sh sandbox-david
```

Ese despliegue prepara el pipeline Azure minimo:

- Resource Groups.
- Key Vault y Log Analytics en `shared`.
- Storage/ADLS y containers del workload.
- Sin identidades OIDC por default para sandboxes personales.

No crea AML, ADF, SQL, ACR ni prod.

## Function Hello World

La Function App es opcional. Solo intentar si hay cuota App Service disponible:

```bash
scripts/deploy.sh sandbox-david
npm test --prefix src/functions/pricing-mlops-hello
scripts/publish-hello-function.sh sandbox-david
```

Endpoint esperado:

```text
https://<function-app-name>.azurewebsites.net/api/health
```

Si Azure devuelve `SubscriptionIsOverQuotaForSku`, volver a `ENABLE_HELLO_FUNCTION=false`.

## Data-Lab

```bash
scripts/what-if.sh data-lab
scripts/deploy.sh data-lab
```

`data-lab` crea Storage/ADLS para zonas sensibles, incluyendo `raw-unmasked`. No despliega Function App y no debe entregar acceso automatico a GitHub Actions.

## GitHub Actions

`.github/workflows/platform-infra.yml`:

| Trigger | Comportamiento |
|---|---|
| `pull_request` | Compila Bicep y parameter files. No hace Azure login ni deploy. |
| `workflow_dispatch`, `validate` | Valida sin deploy. |
| `workflow_dispatch`, `what-if` | Login OIDC y `scripts/what-if.sh`. |
| `workflow_dispatch`, `deploy` | What-if y luego `scripts/deploy.sh`. |

Configurar environments y variables en [`github-actions.md`](github-actions.md).

GitHub Actions solo opera ambientes compartidos/controlados (`staging`, `validation`). `sandbox-david` y futuros `sandbox-*` son local/admin only.

## Revision Semanal

- Revisar costos del credito Azure.
- Confirmar sandboxes activos.
- Revisar corridas `yellow/red`.
- Borrar recursos temporales aprobados para limpieza.
- Promover a IaC solo recursos que se repiten o que otros consumen.
