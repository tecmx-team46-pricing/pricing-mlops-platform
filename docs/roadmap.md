# Roadmap

## Cubierto

- Foundation: Resource Groups, Key Vault, Log Analytics, identidades OIDC y tags.
- Workload `staging`: Storage/ADLS, Azure ML Workspace y Azure Function.
- Flujo E2E: Function -> Azure ML -> Storage con dataset masked compartido.
- Seguridad base: sin account keys para datos MLOps, sin `raw-unmasked` en `staging`, sin prod.
- Cleanup legacy: recursos Container Apps/ACR del PoC anterior eliminados de IaC y Azure `staging`.

## Siguiente Iteracion Recomendada

1. Migrar Function key a Entra ID/Easy Auth o API Management.
2. Agregar reglas reales de calidad inspiradas en el PDF original.
3. Mejorar drift con PSI/KS/Z-test y umbrales aprobados por negocio.
4. Definir si se crea un workspace Azure ML nuevo para separar completamente artifacts runtime del Storage MLOps principal.
5. Agregar lifecycle cleanup para outputs funcionales y artifacts runtime, con aprobacion explicita antes de borrar historicos.
6. Preparar `validation` cuando `staging` sea estable.
7. Reemplazar el baseline controlado por un modelo real o baseline formal aprobado.

## Futuro Conceptual

ADF, Azure SQL, Private Endpoints, Hub-Spoke, registro formal de modelos y prod requieren decision explicita de seguridad/costo. No son parte de la base operativa actual.
