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

## Migracion A Validation

Para levantar la cuenta `pricing46mlops@outlook.com`, crear o confirmar el environment
`validation` en ambos repos:

```text
tecmx-team46-pricing/pricing-mlops-platform
tecmx-team46-pricing/pricing-mlops
```

`pricing-mlops-platform` usa la identidad OIDC de plataforma para `what-if` y `deploy`.
`pricing-mlops` usa una identidad OIDC separada del repo modelo para registrar componentes,
desplegar el endpoint AUTH monitoring e invocar jobs con la managed identity de Azure ML.
En `pricing46mlops@outlook.com`, el environment `validation` debe incluir
`AZURE_ML_BATCH_ENDPOINT=pricing-auth-monitoring-v46`.

La lista exacta de variables y comandos vive en
`docs/goals/lift-validation-to-pricing46-account.md`.
