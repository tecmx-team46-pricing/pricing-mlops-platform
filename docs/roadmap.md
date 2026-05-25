# Roadmap

## Cubierto

- Foundation: Resource Groups, Key Vault, Log Analytics, identidades OIDC y tags.
- Workload `staging`: Storage/ADLS, Azure ML Workspace y Azure Function.
- Flujo E2E: Function -> Azure ML -> Storage con dataset masked compartido.
- Seguridad base: sin account keys para datos MLOps, sin `raw-unmasked` en `staging`, sin prod.
- Cleanup legacy: recursos Container Apps/ACR del PoC anterior eliminados de IaC y Azure `staging`.

## Siguiente Iteracion Recomendada

1. Evolucionar el pipeline Azure ML a DAG de datos real con SDK v2 DSL, componentes registrados, inputs/outputs `uri_folder` y datastore explicito.
2. Migrar Function key a Entra ID/Easy Auth o API Management.
3. Agregar reglas reales de calidad inspiradas en el PDF original.
4. Mejorar drift con PSI/KS/Z-test y umbrales aprobados por negocio.
5. Definir si se crea un workspace Azure ML nuevo para separar completamente artifacts runtime del Storage MLOps principal.
6. Agregar lifecycle cleanup para outputs funcionales y artifacts runtime, con aprobacion explicita antes de borrar historicos.
7. Preparar `validation` cuando `staging` sea estable.
8. Reemplazar el baseline controlado por un modelo real o baseline formal aprobado.

## Investigacion: Pipeline Azure ML Como DAG Real

Estado actual: el pipeline operativo funciona con tres command components (`validate_prepare`, `score_evaluate`, `publish_outputs`) y estado intermedio en Blob bajo `artifacts/component-state/<run_id>/`. Es robusto e idempotente, pero Azure ML no entiende esos blobs como dependencias de datos nativas; por eso puede preparar o agendar nodos antes de que el flujo parezca estrictamente secuencial en Studio.

La forma recomendada para la siguiente iteracion es declarar dependencias de datos reales:

```text
validate_prepare.outputs.prepared_data
  -> score_evaluate.inputs.prepared_data

score_evaluate.outputs.run_artifacts
  -> publish_outputs.inputs.run_artifacts
```

Decision propuesta:

- Implementar una version SDK v2 DSL en `mlops/azureml/`, por ejemplo `pricing_mlops_pipeline.py`, manteniendo el YAML actual como fallback hasta validar estabilidad.
- Registrar o cargar componentes con interfaces explicitas:
  - `validate_prepare`: output `prepared_data` tipo `uri_folder`.
  - `score_evaluate`: input `prepared_data` tipo `uri_folder`, output `run_artifacts` tipo `uri_folder`.
  - `publish_outputs`: input `run_artifacts` tipo `uri_folder`.
- Crear un datastore Azure ML explicito apuntando al storage funcional MLOps, no depender del `workspaceartifactstore` implicito.
- Configurar outputs intermedios con rutas `azureml://datastores/<datastore>/paths/component-state/${run_id}/...` o una convencion equivalente validada.
- Ejecutar jobs con `managed_identity` y RBAC minimo confirmado sobre el datastore funcional.
- Mantener el command job unico como fallback operativo para incidentes.

Riesgos y validaciones:

- Validar que el datastore explicito no use account keys ni connection strings.
- Validar permisos de escritura/lectura para la identidad AML dedicada antes de mover el pipeline productivo.
- Confirmar que Azure ML Studio muestre un DAG con dependencias de datos, no solo nodos coordinados por Blob.
- Confirmar que los outputs finales siguen en el layout funcional existente:

```text
environment=<env>/compute=azure-ml/trigger=<trigger>/owner=<owner>/run_date=<yyyymmdd>/run_id=<run_id>/
```

Referencias oficiales revisadas:

- Azure ML SDK v2 permite componer pipelines con `@pipeline` y conectar outputs de un componente como inputs del siguiente.
- Los componentes/pipelines soportan inputs y outputs `uri_folder`; si no se configura salida, Azure ML genera una ubicacion bajo el datastore configurado.
- Azure ML datastores conectan storage existente al workspace; no crean la cuenta de storage.
- Jobs pueden usar identidad `managed_identity` para acceder a datos y escribir outputs.

## Futuro Conceptual

ADF, Azure SQL, Private Endpoints, Hub-Spoke, registro formal de modelos y prod requieren decision explicita de seguridad/costo. No son parte de la base operativa actual.
