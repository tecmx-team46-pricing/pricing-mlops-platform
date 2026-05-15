# Platform Environments

Este repo mantiene una sola subscription Azure y separa el MVP con Resource Groups, tags y GitHub environments.

## Ambientes habilitados

| Nombre | Tipo | Resource Group | Uso |
|---|---|---|---|
| `shared` | Scope foundation | `rg-pricing-mlops-platform-shared` | Key Vault, Log Analytics e identidades OIDC. No es ambiente MLOps. |
| `data-lab` | Secure data lab | `rg-pricing-mlops-data-lab` | Zona controlada para CSVs unmasked/masked, masking y datasets curated iniciales. |
| `staging` | MVP actual | `rg-pricing-mlops-staging` | Validacion y despliegue inicial de la plataforma. |
| `sandbox-david` | Sandbox personal | `rg-pricing-mlops-sbx-david` | Ambiente principal para probar el hello world del refactor. |
| `validation` | No-prod controlado | `rg-pricing-mlops-validation` | Validar cambios antes de una promocion formal futura. |

`prod` sigue siendo conceptual. No hay infraestructura, parameter file ni workflow de produccion.

`data-lab` no es staging ni sandbox personal. Es un ambiente controlado para datos sensibles; por defecto no despliega Function App y no crea identidad GitHub Actions con acceso de datos a `raw-unmasked`.

`sandbox-david` puede usar una region distinta a `staging` para pruebas temporales de capacidad. Actualmente usa `centralus` porque `eastus2` reporto quota 0 para App Service/Functions en la cuenta con credito gratis.

Cambiar la region de un sandbox existente no mueve recursos Azure ya creados; requiere recrear el Resource Group del sandbox o usar nombres nuevos.

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

`data-lab`:

```text
environment=data-lab
owner=team46
lifecycle=controlled
purpose=secure-data-lab
```

## Operacion local

Los scripts locales aceptan:

```text
staging
sandbox-david
validation
data-lab
```

Ejemplos:

```bash
scripts/what-if.sh sandbox-david
scripts/deploy.sh sandbox-david
scripts/publish-hello-function.sh sandbox-david
scripts/what-if.sh data-lab
scripts/deploy.sh data-lab
```

La publicacion de la Function requiere que el despliegue haya creado la Function App. Si la subscription no tiene cuota de compute para App Service Plan, usar `ENABLE_HELLO_FUNCTION=false` para validar foundation y storage mientras se solicita cuota.

## GitHub Actions

`platform-infra.yml` valida en pull requests sin credenciales Azure. Para operaciones manuales, ejecutar `workflow_dispatch` y seleccionar:

- `environment`: `staging`, `sandbox-david` o `validation`.
- `operation`: `validate`, `what-if` o `deploy`.

`data-lab` se valida en pull requests con `build-params`. Su operacion por `workflow_dispatch` queda pendiente hasta configurar explicitamente un GitHub environment sin acceso amplio a `raw-unmasked`.

Cada GitHub environment usado para what-if o deploy necesita:

```text
AZURE_CLIENT_ID
AZURE_TENANT_ID
AZURE_SUBSCRIPTION_ID
```

El valor de `AZURE_CLIENT_ID` sale del output `githubActionsClientId` del despliegue foundation del ambiente.
