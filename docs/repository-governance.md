# Repository Governance

## Principios

- Mantener foundation y workloads separados bajo `infra/`.
- Crear parameter files solo para ambientes realmente habilitados.
- No crear `prod` hasta que exista una necesidad operativa real.
- Usar `shared` para servicios comunes, no como ambiente MLOps.
- Mantener `mlops/` libre de IaC.
- Mantener cambios de plataforma pequenos, revisables y reversibles.

## Layout de infraestructura

```text
infra/
  foundation/
  workloads/pricing-mlops/
  parameters/
```

`infra/foundation/` contiene recursos reutilizables de plataforma.

`infra/workloads/pricing-mlops/` contiene recursos especificos del workload Pricing MLOps.

## Ambientes permitidos

Los scripts y el workflow `platform-infra.yml` aceptan:

```text
staging
sandbox-david
validation
```

Agregar otro ambiente requiere:

- un caso operativo claro;
- un parameter file en `infra/parameters/`;
- tags de owner, lifecycle y purpose;
- actualizacion de documentacion;
- revision explicita de costo y permisos.

## Pull requests

En pull requests, la validacion debe ser segura:

- compilar foundation;
- compilar workload Pricing MLOps;
- compilar parameter files;
- no hacer login a Azure;
- no ejecutar `az deployment`;
- no modificar recursos remotos.

## Operacion manual

`workflow_dispatch` es el punto de operacion desde GitHub Actions. `what-if` y `deploy` usan el GitHub environment seleccionado para aplicar variables, permisos y protecciones propias de cada ambiente.
