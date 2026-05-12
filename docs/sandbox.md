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

El tag real `environment` es `sandbox`. El nombre `sandbox-david` se usa como parameter file local para evitar confundirlo con otros sandboxes. No se expone como GitHub environment de despliegue.

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
