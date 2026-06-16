# Roadmap

El MVP deja una base inicial: infraestructura reproducible, una Function que orquesta, un pipeline Azure ML que ejecuta el flujo y evidencia publicada en Storage/SQL. El roadmap parte de esa implementacion, no de un diseno aislado.

## Ya Cubierto

| Area | Avance |
|---|---|
| Foundation | Resource Groups, Key Vault, Log Analytics, identidades OIDC y tags. |
| Workload `staging` | Storage/ADLS, Azure ML Workspace, Function y SQL audit. |
| Flujo E2E | Function -> Azure ML -> Storage con dataset masked compartido. |
| Avance 4 AUTH monitoring | Template multi-step con logica del notebook abstraida en componentes visibles. |
| Seguridad base | Sin account keys para datos MLOps, sin `raw-unmasked` en `staging`, sin prod. |
| Limpieza legacy | Retiro de recursos Container Apps/ACR del PoC anterior en IaC y Azure `staging`. |

## Siguiente Iteracion Recomendada

La siguiente etapa propuesta es reducir las brechas principales del MVP:

1. Evolucionar el pipeline Azure ML a DAG de datos real con SDK v2 DSL, componentes registrados, inputs/outputs `uri_folder` y datastore explicito.
2. Migrar Function key a Entra ID/Easy Auth o API Management.
3. Agregar reglas reales de calidad inspiradas en el diseno original.
4. Mejorar drift con PSI/KS/Z-test y umbrales aprobados por negocio.
5. Definir lifecycle cleanup para outputs funcionales y artifacts runtime, con aprobacion explicita antes de borrar historicos.
6. Preparar `validation` cuando `staging` sea estable.
7. Reemplazar el baseline controlado por un modelo real o baseline formal aprobado.
8. Validar AUTH monitoring end-to-end con blobs reales de baseline/current history y comparar contra la copia transicional del notebook.

## Pipeline Azure ML Como DAG Real

El pipeline actual funciona con tres command components:

```text
validate_prepare -> build_monitoring_inputs -> calculate_recommendation_validity -> calculate_auth_history_drift -> calculate_operational_decision -> publish_outputs
```

Hoy la coordinacion usa estado intermedio en Blob bajo `artifacts/component-state/<run_id>/`. Funciona para el MVP, pero Azure ML no entiende esos blobs como dependencias de datos nativas.

La evolucion recomendada es declarar dependencias de datos nativas:

```text
validate_prepare.outputs.prepared_data
  -> build_monitoring_inputs

calculate_operational_decision.outputs.run_artifacts
  -> publish_outputs.inputs.run_artifacts
```

Decision propuesta:

- Implementar una version SDK v2 DSL en `mlops/azureml/`, manteniendo el YAML actual como fallback hasta validar estabilidad.
- Usar componentes con interfaces explicitas `uri_folder`.
- Crear un datastore Azure ML explicito apuntando al Storage funcional MLOps.
- Ejecutar jobs con `managed_identity` y RBAC minimo confirmado.
- Mantener el command job unico como fallback operativo para incidentes.

## Riesgos A Vigilar

- El datastore explicito no debe introducir account keys ni connection strings.
- Los permisos de la identidad AML deben probarse antes de mover el pipeline principal.
- Azure ML Studio debe mostrar dependencias de datos nativas, no solo nodos coordinados por Blob.
- Los outputs finales deben conservar el layout funcional:

```text
environment=<env>/compute=azure-ml/trigger=<trigger>/owner=<owner>/run_date=<yyyymmdd>/run_id=<run_id>/
```

## Futuro Conceptual

ADF, Private Endpoints, Hub-Spoke, registro formal de modelos y prod requieren decision explicita de seguridad, costo y alcance. Azure SQL audit ya existe como capa metadata-only en `staging`; sus siguientes mejoras son endurecer red/acceso y automatizar migraciones.

Lectura relacionada: [Evidencia del MVP](evidencia.md) para ver que se valido en la implementacion actual.
