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
4. Normalizar Storage y limpiar particiones legacy de outputs, especialmente `compute=container-job` y layouts antiguos sin `compute=azure-ml`.
5. Preparar `validation` cuando `staging` sea estable.

## Futuro Conceptual

ADF, Azure SQL, Private Endpoints, Hub-Spoke, registro formal de modelos y prod requieren decision explicita de seguridad/costo. No son parte del MVP actual.
