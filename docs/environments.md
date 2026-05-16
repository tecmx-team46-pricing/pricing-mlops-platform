# Environments

El MVP usa una sola subscription y separa responsabilidades con Resource Groups, tags y GitHub environments.

## Ambientes

| Nombre | Tipo | Resource Group | Uso | Datos unmasked |
|---|---|---|---|---|
| `shared` | Scope foundation | `rg-pricing-mlops-platform-shared` | Key Vault, Log Analytics, identidades OIDC y budgets. No es ambiente MLOps. | No |
| `data-lab` | Secure data lab | `rg-pricing-mlops-data-lab` | Landing controlado para unmasked, masking y datasets masked iniciales. | Si, restringido |
| `sandbox-local` | Sandbox personal | `rg-pricing-mlops-sbx-local` | Pruebas locales/admin temporales. No se opera desde GitHub Actions. | No |
| `staging` | MVP compartido | `rg-pricing-mlops-staging` | Validacion integrada del MVP con datos masked/curated y GitHub Actions del modelo. | No |
| `validation` | No-prod controlado | `rg-pricing-mlops-validation` | Validacion futura antes de promocion formal. | No por default |

`prod` sigue conceptual. No hay IaC, parameter file ni workflow de produccion.

## Tags requeridos

| Ambiente | Tags clave |
|---|---|
| `sandbox-local` | `environment=sandbox`, `owner=<owner>`, `lifecycle=temporary`, `purpose=personal-sandbox` |
| `data-lab` | `environment=data-lab`, `owner=team46`, `lifecycle=controlled`, `purpose=secure-data-lab` |
| `validation` | `environment=validation`, `owner=team46`, `lifecycle=controlled`, `purpose=controlled-validation` |

## Regla de sandbox

Los sandboxes son temporales y se despliegan desde local/admin. GitHub Actions no debe crear, actualizar ni destruir sandboxes personales. Un recurso pasa a IaC formal solo si se usa mas de una vez, otra persona depende de el, es necesario para staging o no se puede reconstruir facilmente.

Para destruir un sandbox temporal:

```bash
scripts/destroy-sandbox.sh rg-pricing-mlops-sbx-<owner>-<yyyymmdd>
```

No borrar `rg-pricing-mlops-sbx-local` sin confirmacion explicita si contiene recursos existentes.
