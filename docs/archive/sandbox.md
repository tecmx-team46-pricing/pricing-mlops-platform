# Sandbox

Sandbox es para experimentar rapido y destruir rapido.

El prototipo incluye un sandbox personal habilitado por IaC:

```text
rg-pricing-mlops-sbx-david
```

Sus tags obligatorios son:

```text
environment=sandbox
owner=david
purpose=personal-sandbox
lifecycle=temporary
```

El tag real `environment` es `sandbox`. El nombre `sandbox-david` se usa como parameter file y GitHub environment para evitar confundirlo con otros sandboxes.

`sandbox-david` usa `centralus` para probar compute fuera de `eastus2`, donde Azure reporto quota 0 para App Service/Functions. Si `centralus` tambien falla por quota, el siguiente paso es pedir `Dynamic VMs >= 1` o probar otra region de forma explicita.

Los recursos Azure no se mueven de region en sitio. Si el Resource Group del sandbox ya contiene Storage Accounts en `eastus2`, hay que borrar y recrear `rg-pricing-mlops-sbx-david` o cambiar nombres antes de desplegar en `centralus`.

En este refactor, `sandbox-david` es el ambiente principal para probar el workload hello world:

```bash
scripts/what-if.sh sandbox-david
scripts/deploy.sh sandbox-david
scripts/publish-hello-function.sh sandbox-david
```

Si Azure bloquea la Function App por cuota de App Service Plan, probar la base del sandbox con:

```bash
ENABLE_HELLO_FUNCTION=false scripts/deploy.sh sandbox-david
```

## Nombre

```text
rg-pricing-mlops-sbx-<owner>-<yyyymmdd>
```

Ejemplo:

```text
rg-pricing-mlops-sbx-msoriano-20260507
```

## Tags

```text
project=pricing-mlops
environment=sandbox
owner=<email-or-alias>
purpose=experiment
lifecycle=temporary
expires_on=<yyyy-mm-dd>
```

## Regla de promocion

Un recurso pasa a IaC formal si:

- se usa mas de una vez;
- es necesario para staging;
- alguien mas depende de el;
- no se puede reconstruir facilmente a mano.

Si no cumple eso, se elimina.

## Destruir

```bash
scripts/destroy-sandbox.sh rg-pricing-mlops-sbx-<owner>-<yyyymmdd>
```
