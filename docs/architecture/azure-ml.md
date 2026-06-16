# Azure ML En Platform

Platform solo provisiona los recursos base que Azure ML necesita. La definicion operacional del pipeline vive en `pricing-mlops`.

## Responsabilidad De Platform

- crear o mantener el Azure ML Workspace;
- crear el storage runtime asociado al workspace;
- crear la Managed Identity usada por jobs;
- dar permisos de Storage/AML al repo `pricing-mlops`;
- exponer nombres/outputs para CI/CD.

## Responsabilidad De `pricing-mlops`

- registrar `pricing_mlops_*` command components;
- registrar `pricing_mlops_publish_outputs`;
- registrar `pricing_mlops_auth_monitoring_pipeline`;
- crear/actualizar el batch pipeline endpoint `pricing-auth-monitoring`;
- invocar smoke tests y validar artefactos.

## Decision De Tooling

| Herramienta | Decision | Razon |
|---|---|---|
| Azure ML pipeline component | Adoptado | Permite publicar un componente versionado e invocable por endpoint. |
| Azure ML batch pipeline endpoint | Adoptado | Da un REST endpoint administrado para invocar el pipeline sin Function intermedia. |
| Azure ML online endpoint | No | No hay serving online. |
| Azure Functions | No en platform actual | Se reemplaza por batch pipeline endpoint para simplificar ownership. |
| Azure SQL audit | No en platform actual | Los artefactos funcionales quedan en Storage; metadata avanzada puede agregarse despues desde el repo operativo. |
