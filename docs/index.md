# Plataforma MLOps Para Pricing Intelligence

Este repo contiene la base Azure del proyecto Team 46. Su responsabilidad actual es preparar infraestructura, identidades, RBAC, Storage y Azure ML para que el repo `pricing-mlops` opere el flujo AUTH monitoring.

La ruta operativa queda asi:

```text
pricing-mlops-platform
-> provisiona Azure base
-> expone workspace, storage, identidades y permisos

pricing-mlops
-> registra componentes Azure ML
-> publica el pipeline component
-> despliega/invoca el batch pipeline endpoint
-> publica artefactos funcionales en Storage
```

Platform ya no contiene Azure Functions, SQL audit, YAML del pipeline operacional ni componentes Azure ML propios. Esa complejidad se movio al repo funcional para que el equipo que cambia el notebook/componentes tambien cambie y publique el endpoint.

## Que Cubre El Proyecto

- infraestructura Azure reproducible con Bicep;
- separacion clara entre plataforma y codigo data science;
- Storage/ADLS para inputs masked y artefactos versionados;
- Azure ML Workspace y Managed Identity para jobs;
- OIDC/RBAC para GitHub Actions de `pricing-mlops-platform` y `pricing-mlops`;
- documentacion de recursos y limites operativos.

## Repositorios Del Proyecto

| Repo | Rol |
|---|---|
| `pricing-mlops-platform` | IaC/base Azure: resource groups, storage, Azure ML, identidades, RBAC, budget y documentacion de plataforma. |
| `pricing-mlops` | Operacion ML: componentes, pipeline component, batch endpoint/deployment, smoke test y publicacion de artefactos. |
| `pricing-mlops-eda` | Referencia historica y notebooks exploratorios. No es repo operativo. |

## Como Leer La Documentacion

1. [Contexto y problema](project/contexto-problema.md)
2. [Objetivos y alcance](project/objetivos-alcance.md)
3. [Arquitectura](architecture/overview.md)
4. [Estructura del repo](architecture/repo-structure.md)
5. [Separacion plataforma-modelo](reference/platform-model-contract.md)
6. [Flujo end to end](operations/end-to-end-flow.md)
7. [Servicios Azure](architecture/azure-services.md)

## Limites Actuales

No hay ambiente `prod`, Private Endpoints, ADF, Azure Functions operativas, SQL audit ni endpoints online. El endpoint usado por el flujo es un Azure ML batch pipeline endpoint administrado desde `pricing-mlops`.
