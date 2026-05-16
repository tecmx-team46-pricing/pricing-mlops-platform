# Roadmap

## Fase 0: Foundation

Estado: implementado parcialmente.

- Resource Groups.
- Key Vault.
- Log Analytics.
- Managed identities/OIDC.
- Tags y budget opcional.

## Fase 1: Storage y data-lab

Estado: preparado para PoC.

- Storage/ADLS con zonas `raw-unmasked`, `raw-masked`, `curated`, `baseline`, `runs`, `snapshots`, `drift-logs`, `reports`, `artifacts`.
- `raw-unmasked` solo en `data-lab`/`secure-sandbox`.
- No GitHub Actions con acceso automatico a unmasked.

## Fase 2: Pipeline minimo Azure

Siguiente paso recomendado.

- Desplegar `sandbox-david` con `ENABLE_HELLO_FUNCTION=false` si la quota de Function/App Service bloquea.
- Crear identidad OIDC para `pricing-mlops`.
- Dar `Storage Blob Data Contributor` solo al Storage Account del workload.
- Ejecutar workflow manual en `pricing-mlops`.
- Subir `model_run_log`, snapshots, drift logs, reports y artifacts a Storage.

## Fase 3: Staging MVP

Cuando sandbox funcione:

- Promover el flujo a `staging`.
- Usar datos masked/curated aprobados.
- Mantener evidence por `run_id`.
- Revisar semaforo `green/yellow/red`.

## Fase 4: Validation controlada

Cuando staging sea estable:

- Ejecutar validaciones controladas antes de promocion formal.
- Considerar SQL Serverless si Storage ya no basta para auditoria.
- Considerar Azure ML si el scoring necesita jobs administrados.

## Fase 5: Prod conceptual

No se implementa ahora.

Prod requiere decision explicita, IaC dedicado, revision de seguridad/costos, runbooks, owner operativo y controles de red si aplica.
