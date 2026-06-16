# GitHub Actions

## Regla Principal

GitHub Actions de este repo solo valida y despliega infraestructura de plataforma. No registra componentes Azure ML, no despliega endpoints y no invoca jobs del modelo.

## Workflow Activo

`.github/workflows/platform-infra.yml`

| Trigger | Accion | Azure login |
|---|---|---|
| `pull_request` | Compila Bicep y parameter files. | No |
| `workflow_dispatch`, `operation=validate` | Valida IaC. | No |
| `workflow_dispatch`, `operation=what-if` | Ejecuta `scripts/what-if.sh`. | Si |
| `workflow_dispatch`, `operation=deploy` | Ejecuta what-if y deploy. | Si |

## Variables Del Environment GitHub

```text
AZURE_CLIENT_ID
AZURE_TENANT_ID
AZURE_SUBSCRIPTION_ID
```

El repo `pricing-mlops` tiene su propio workflow para registrar componentes y actualizar el endpoint usando la identidad OIDC del repo modelo.
