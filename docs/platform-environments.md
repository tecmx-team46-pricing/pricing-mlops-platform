# Platform Environments

Este repo mantiene una sola subscription Azure y separa el MVP con Resource Groups, tags y GitHub environments.

## Ambientes habilitados

| Nombre | Tipo | Resource Group | Uso |
|---|---|---|---|
| `shared` | Scope compartido | `rg-pricing-mlops-platform-shared` | Key Vault, Log Analytics e identidades OIDC. No es ambiente MLOps. |
| `staging` | MVP actual | `rg-pricing-mlops-staging` | Validacion y despliegue inicial de la plataforma. |
| `sandbox-david` | Sandbox personal | `rg-pricing-mlops-sbx-david` | Pruebas temporales de David con lifecycle temporal. |
| `validation` | No-prod controlado | `rg-pricing-mlops-validation` | Validar cambios antes de una promocion formal futura. |

`prod` sigue siendo conceptual. No hay infraestructura, parameter file ni workflow de produccion.

## Tags obligatorios

`sandbox-david`:

```text
environment=sandbox
owner=david
lifecycle=temporary
purpose=personal-sandbox
```

`validation`:

```text
environment=validation
owner=team46
lifecycle=controlled
purpose=controlled-validation
```

## Operacion

Los scripts locales aceptan solo:

```text
staging
sandbox-david
validation
```

Ejemplos:

```bash
scripts/what-if.sh sandbox-david
scripts/deploy.sh validation
```

Antes de ejecutar what-if o deploy local, confirmar la subscription:

```bash
az account show --query "{name:name, id:id}" --output table
```

## GitHub Actions

`platform-infra.yml` valida en pull requests sin credenciales Azure. Para operaciones manuales, ejecutar `workflow_dispatch` y seleccionar:

- `environment`: `staging` o `validation`.
- `operation`: `validate`, `what-if` o `deploy`.

Los sandboxes personales no se exponen como GitHub environments de despliegue. `sandbox-david` se mantiene como ejemplo local reproducible para que cada companero pueda tener un parameter file temporal equivalente.

Cada GitHub environment usado para what-if o deploy necesita:

```text
AZURE_CLIENT_ID
AZURE_TENANT_ID
AZURE_SUBSCRIPTION_ID
```

El valor de `AZURE_CLIENT_ID` sale del output `githubActionsClientId` del despliegue del ambiente.
Si ese despliegue todavia no existe, el bootstrap inicial debe hacerse localmente con una cuenta autorizada.
