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

Los scripts locales aceptan:

```text
staging
sandbox-local
validation
data-lab
```

Agregar otro ambiente requiere:

- un caso operativo claro;
- un parameter file en `infra/parameters/`;
- tags de owner, lifecycle y purpose;
- actualizacion de documentacion;
- revision explicita de costo y permisos.

`platform-infra.yml` compila el parameter file de `data-lab` en pull requests, pero no lo expone todavia como opcion de `workflow_dispatch`.

`data-lab` es un ambiente habilitado de forma controlada. Su parameter file debe mantener `environment=data-lab`, `owner=team46`, `lifecycle=controlled` y `purpose=secure-data-lab`; no debe habilitar compute del modelo ni acceso GitHub Actions a `raw-unmasked` por defecto.

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
