# Repository Governance

## Principios

- Mantener una sola entrada de infraestructura: `infra/main.bicep`.
- Crear parameter files solo para ambientes realmente habilitados.
- No crear `prod` hasta que exista una necesidad operativa real.
- Usar `shared` para servicios comunes, no como ambiente MLOps.
- Mantener cambios de plataforma pequenos, revisables y reversibles.

## Ambientes permitidos en automatizacion

Los scripts locales aceptan:

```text
staging
sandbox-david
validation
```

El workflow `platform-infra.yml` expone solo:

```text
staging
validation
```

Los sandboxes personales no se operan desde GitHub Actions.

Agregar otro ambiente requiere:

- un caso operativo claro;
- un parameter file en `infra/parameters/`;
- tags de owner, lifecycle y purpose;
- actualizacion de documentacion;
- revision explicita de costo y permisos.

## Pull requests

En pull requests, la validacion debe ser segura:

- compilar Bicep;
- compilar parameter files;
- no hacer login a Azure;
- no ejecutar `az deployment`;
- no modificar recursos remotos.

## Operacion manual

`workflow_dispatch` es el punto de operacion desde GitHub Actions. `what-if` y `deploy` usan el GitHub environment seleccionado para aplicar aprobaciones, variables y protecciones propias de cada ambiente.
