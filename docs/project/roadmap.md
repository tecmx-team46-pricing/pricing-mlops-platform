# Roadmap

## Ya Cubierto

| Area | Avance |
|---|---|
| Foundation | Resource Groups, Key Vault, Log Analytics, identidades OIDC y tags. |
| Workload base | Storage/ADLS, Azure ML Workspace, storage runtime AML, identidad de job y RBAC. |
| Separacion de repos | Platform deja IaC/base Azure; `pricing-mlops` opera componentes y endpoint. |
| Seguridad base | Sin account keys para datos MLOps, sin `raw-unmasked` en `staging`, sin prod. |

## Siguiente Iteracion Recomendada

1. Mantener el pipeline endpoint en `pricing-mlops` como unica ruta operacional.
2. Convertir dependencias entre steps a `uri_folder` nativos cuando el equipo quiera mejorar observabilidad del DAG.
3. Agregar lifecycle cleanup para outputs funcionales y artefactos runtime con aprobacion explicita.
4. Preparar `validation` cuando `staging` sea estable.
5. Definir un modelo real o baseline formal aprobado.
6. Evaluar SQL audit, ADF, Private Endpoints o APIM solo si aparecen requisitos reales de auditoria/seguridad.

## Riesgos A Vigilar

- Doble ownership de componentes entre repos.
- Permisos demasiado amplios para GitHub Actions.
- Borrado accidental de outputs historicos o artefactos runtime AML.
- Reintroducir Azure Functions sin una necesidad clara.
