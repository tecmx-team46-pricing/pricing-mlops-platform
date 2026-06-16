# Arquitectura

La arquitectura se simplifico para evitar doble ownership entre repos. `pricing-mlops-platform` prepara Azure; `pricing-mlops` opera el flujo ML.

## Decision Actual

```text
Platform repo
-> foundation: shared RG, Key Vault, Log Analytics, OIDC, budget
-> workload: Storage/ADLS, Azure ML Workspace, AML job identity, RBAC

Model repo
-> Azure ML command components
-> AUTH monitoring pipeline component
-> batch pipeline endpoint/deployment
-> smoke test y publicacion de artefactos
```

Esta division evita que platform tenga que volver a publicar componentes cada vez que cambia la logica del notebook. El equipo del repo `pricing-mlops` registra el componente completo y actualiza el endpoint con su propia version.

## Capas De Platform

| Capa | Ruta | Responsabilidad |
|---|---|---|
| Foundation | `infra/foundation/` | Resource groups compartidos, Key Vault, Log Analytics, OIDC/RBAC base y budget opcional. |
| Workload | `infra/workloads/pricing-mlops/` | Storage MLOps, Azure ML Workspace, storage runtime AML, Managed Identity del job y permisos del repo modelo. |
| Parametros | `infra/parameters/` | Ambientes `staging`, `validation`, `sandbox-local` y `data-lab`. |
| Automatizacion | `.github/workflows/`, `scripts/` | Build de Bicep, what-if y deploy manual controlado. |

## Servicios Activos

| Servicio | Rol |
|---|---|
| Storage MLOps principal | Data lake funcional para `raw-masked`, `curated`, `baseline`, `runs`, `snapshots`, `drift-logs`, `reports` y `artifacts`. |
| Storage runtime Azure ML | Storage asociado al workspace para logs, snapshots y artefactos internos de Azure ML. |
| Azure ML Workspace | Control plane donde `pricing-mlops` registra componentes y ejecuta pipeline jobs. |
| User Assigned Identity AML | Identidad usada por jobs para acceder a Storage sin account keys. |
| GitHub OIDC identities | Identidades separadas para platform y modelo. |

## Fuera De Platform

Estos elementos ahora viven en `pricing-mlops`:

- `pricing_mlops_publish_outputs`;
- `pricing_mlops_auth_monitoring_pipeline`;
- YAML de batch endpoint/deployment;
- scripts de registro, deploy e invoke del endpoint;
- tests de contrato del pipeline operacional.

## Ambientes

| Scope | Resource Group | Proposito |
|---|---|---|
| `shared` | `rg-pricing-mlops-platform-shared` | Servicios comunes; no es ambiente MLOps. |
| `staging` | `rg-pricing-mlops-staging` | Ambiente operativo compartido. |
| `validation` | `rg-pricing-mlops-validation` | No-prod controlado futuro. |
| `sandbox-local` | `rg-pricing-mlops-sbx-local` | Pruebas local/admin temporales. |
| `data-lab` | `rg-pricing-mlops-data-lab` | Landing restringido para datos unmasked/masking. |

No existe `prod` en IaC, parametros ni workflows.
