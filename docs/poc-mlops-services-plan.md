# PoC Pricing MLOps Services Plan

## Objetivo

Definir que servicios Azure se necesitan para un PoC de la plataforma MLOps de Pricing Intelligence, que se desplegaria ahora y en que Resource Groups viviria cada componente.

Este plan toma como referencia el documento externo `Diseno Tecnico: Arquitectura MLOps` del repo `pricing-mlops-eda` y lo aterriza al estado actual de este repo: una sola subscription, separacion `foundation` vs `workloads/pricing-mlops`, `shared` como scope comun, `sandbox-david` como laboratorio principal, `staging` como MVP actual y `validation` como ambiente controlado no productivo.

## Principios de alcance

- No desplegar produccion.
- No guardar CSVs unmasked en Git.
- No mover IaC a `mlops/`.
- Priorizar PoC barato y verificable antes de activar servicios administrados pesados.
- Mantener `shared` como infraestructura comun, no como ambiente operativo.
- Usar `sandbox-david` para validar servicios nuevos antes de tocar `staging`.

## Resource Groups

| Resource Group | Tipo | Region inicial | Rol |
|---|---|---|---|
| `rg-pricing-mlops-platform-shared` | Foundation | `eastus2` | Servicios compartidos: Key Vault, Log Analytics, identidades OIDC, presupuestos y RBAC base. |
| `rg-pricing-mlops-data-lab` | Secure data lab | `eastus2` | Zona controlada para CSVs unmasked/masked, curated inicial y evidencia sin Function/ADF/AML/SQL. |
| `rg-pricing-mlops-sbx-david` | Workload sandbox | `centralus` para nuevos despliegues | Laboratorio personal para validar Function, storage layout, carga de CSVs y flujo hello/drift. |
| `rg-pricing-mlops-staging` | Workload MVP | `eastus2` | Ambiente principal de validacion del MVP cuando el PoC ya este probado. |
| `rg-pricing-mlops-validation` | Workload controlado | `eastus2` | Ambiente no productivo para validar cambios antes de una promocion formal futura. |

Nota: `rg-pricing-mlops-sbx-david` ya tiene recursos existentes en `eastus2`. Para probar `centralus` con los mismos nombres hay que recrear el Resource Group o crear nombres nuevos para un sandbox paralelo.

## Servicios a desplegar en el PoC inmediato

| Servicio | Resource Group | Capa | Se despliega ahora | Proposito |
|---|---|---|---|---|
| Resource Groups | Subscription scope | Foundation | Si | Separar shared, sandbox, staging y validation por tags y ownership. |
| Key Vault | `rg-pricing-mlops-platform-shared` | Foundation | Si | Guardar salts, secretos y configuracion sensible para hashing/enmascaramiento. |
| Log Analytics | `rg-pricing-mlops-platform-shared` | Foundation | Si | Observabilidad minima de despliegues, Function y validaciones. |
| User Assigned Managed Identity | `rg-pricing-mlops-platform-shared` | Foundation | Si | OIDC para GitHub Actions y ejecuciones sin secretos persistentes. |
| Budget | Subscription scope | Foundation | Opcional | Control de gasto contra el credito disponible. |
| Storage Account / ADLS Gen2 data-lab | `rg-pricing-mlops-data-lab` | Data lab | Si | Almacenar `raw-unmasked`, `raw-masked`, `curated` y artefactos controlados sin dar acceso por defecto a GitHub Actions. |
| Storage Account / ADLS Gen2 | `rg-pricing-mlops-sbx-david` | Workload | Si | Almacenar datasets enmascarados, features, baselines, snapshots y evidencia. Los CSVs unmasked pertenecen a `data-lab`/`secure-sandbox`. |
| Azure Function hello/health | `rg-pricing-mlops-sbx-david` | Workload | Si, cuando quota lo permita | Endpoint `/api/health` y base para futuro motor de drift. |
| App Service Plan o Functions Consumption | `rg-pricing-mlops-sbx-david` | Workload | Condicionado a quota | Compute minimo para la Function. Preferido a futuro: Consumption/Flex Consumption. |

## Servicios necesarios pero no desplegados en el PoC inmediato

| Servicio | Resource Group futuro | Fase sugerida | Motivo para esperar |
|---|---|---|---|
| Azure SQL Serverless | `rg-pricing-mlops-staging` o `rg-pricing-mlops-validation` | Auditoria | Primero validar contratos y volumen con archivos; SQL entra cuando `model_run_log`, `model_drift_log` y snapshot metadata requieran consultas historicas. |
| Azure Machine Learning | `rg-pricing-mlops-validation` | Calidad y scoring | Requiere mayor gobierno, costos y setup. Para PoC inicial basta validar schemas y drift con Function/scripts. |
| Azure Data Factory | `rg-pricing-mlops-validation` | Orquestacion | Entra cuando haya fuentes reales y scheduling formal. No es necesario para cargar CSVs manuales del PoC. |
| Azure Container Registry | `rg-pricing-mlops-platform-shared` o workload controlado | Empaquetado ML | Solo necesario si se empaquetan validadores/modelos como contenedores. |
| VNet Hub-Spoke | RG de red futuro | Seguridad enterprise | Fuera del PoC barato; relevante antes de datos productivos o integracion privada. |
| Private Endpoints / Private DNS | Shared + workload | Seguridad enterprise | Requiere red privada formal. No bloquear el PoC con esto. |
| Azure Monitor alerts | `rg-pricing-mlops-platform-shared` | Operacion | Agregar cuando existan metricas reales de drift y fallas recurrentes. |

## Layout de datos para CSVs unmasked

Los CSVs unmasked son datos sensibles. No deben commitearse al repo ni subirse como artefactos de GitHub Actions.

Propuesta de almacenamiento para PoC:

| Contenedor | Datos | Acceso |
|---|---|---|
| `raw-unmasked` | CSVs originales no enmascarados | Solo `data-lab`/`secure-sandbox` con RBAC explicito. No acceso desde GitHub por defecto. No usar en `staging`. |
| `raw-masked` | CSVs con IDs hasheados/tokenizados | Equipo tecnico del proyecto. |
| `curated` | Features limpias para validacion y scoring | Workload MLOps. |
| `baseline` | Distribuciones historicas y thresholds | Function/drift engine. |
| `runs` | Artefactos por corrida | Workload MLOps. |
| `snapshots` | Recomendaciones de precios por `run_id` | Workload MLOps y analisis. |
| `drift-logs` | Resultados PSI, KS, semaforo y decision | Workload MLOps. |
| `reports` | Resumenes para revision humana | Equipo tecnico/negocio. |
| `artifacts` | Paquetes, outputs auxiliares y evidencia | Equipo tecnico. |

Reglas minimas:

- Cargar unmasked solo por `az storage blob upload` local o proceso controlado, nunca por Git.
- Enmascarar antes de usar datos en `staging`.
- Guardar salt/secret de hashing en Key Vault.
- Registrar `dataset_version`, `schema_version`, `run_id` y `git_commit_hash` en cada corrida.

## Flujo PoC propuesto

1. Cargar CSVs unmasked a `raw-unmasked` en `data-lab`/`secure-sandbox`, no en `staging`.
2. Ejecutar enmascaramiento con salt/secret desde Key Vault.
3. Escribir salida a `raw-masked` para uso en sandbox, `staging` y `validation`.
4. Validar contratos iniciales:
   - nulos criticos;
   - unicidad de `[kpn, vpareadescription, distysegment]`;
   - monotonicidad de percentiles;
   - regla de piso de margen si `P20_Was_Adjusted=true`.
5. Generar `run_id` y escribir evidencia en `runs`.
6. Calcular baseline inicial y guardar en `baseline`.
7. Calcular drift con PSI/KS y guardar en `drift-logs`.
8. Guardar recomendaciones en `snapshots`.
9. Publicar reporte humano en `reports`.

## Mapeo al documento tecnico objetivo

| Documento tecnico | PoC en este repo | Decision |
|---|---|---|
| ADF orquesta ingesta | Scripts/manual upload + Function | Posponer ADF hasta fuentes reales. |
| ADLS Gen2 guarda raw/curated/snapshots | Storage Account con containers | Implementar ya en sandbox. |
| Functions Flex calcula drift/semaforo | Function hello/health, luego drift endpoint | Implementar incrementalmente. |
| AML ejecuta validacion y scoring | Scripts y contratos locales primero | Posponer AML hasta validar necesidad. |
| SQL Serverless audita run logs | JSON/Parquet en Storage primero | Posponer SQL hasta requerir consultas historicas. |
| Key Vault guarda llaves | Key Vault shared | Mantener en foundation. |
| Hub-Spoke y Private Endpoints | No en PoC inmediato | Posponer por costo y complejidad. |
| ACR para contenedores | No en PoC inmediato | Posponer hasta necesitar imagenes. |

## Orden recomendado de implementacion

### Paso 1: Resolver compute minimo en sandbox

- Confirmar si `centralus` permite Function App o Consumption/Flex.
- Si hay conflicto por recursos existentes en `eastus2`, crear sandbox paralelo o recrear `rg-pricing-mlops-sbx-david` con confirmacion explicita.
- Publicar `/api/health`.

### Paso 2: Endurecer storage para datos sensibles

- Confirmar containers esperados.
- Crear `raw-unmasked` solo en `data-lab`/`secure-sandbox`; los sandboxes personales consumen masked/curated por default.
- Asegurar RBAC minimo: sin acceso publico, sin secrets en GitHub, uso de identidad administrada.

### Paso 3: Registrar contratos de datos reales

- Documentar columnas de los CSVs unmasked sin guardar datos.
- Versionar schema en `mlops/schemas/`.
- Crear reglas de validacion iniciales basadas en el PDF.

### Paso 4: Drift PoC

- Leer datos masked/curated.
- Calcular PSI/KS para variables criticas.
- Escribir `model_drift_log`.
- Emitir semaforo green/yellow/red.

### Paso 5: Promocion a staging

- Repetir con datos masked o sinteticos.
- No mover unmasked fuera del sandbox sin aprobacion.
- Usar GitHub Actions solo para validar IaC y deployments controlados.

## No alcance de este PoC

- Produccion real.
- Datos productivos expuestos publicamente.
- Hub-and-Spoke completo.
- Private Endpoints.
- Azure Data Factory.
- Azure Machine Learning.
- Azure SQL Serverless.
- ACR.
- Retraining automatico.
- Promocion automatica de modelos.

## Decisiones pendientes

| Decision | Opciones | Recomendacion inicial |
|---|---|---|
| Region de sandbox | `centralus`, otra region, o mantener `eastus2` | Probar `centralus` con RG temporal antes de borrar sandbox actual. |
| Compute de Function | Consumption/Flex, B1 App Service Plan | Preferir Consumption/Flex si la cuenta lo permite. |
| Manejo de unmasked | Local-only, `raw-unmasked` en `data-lab`/`secure-sandbox`, Key Vault hashing | Usar `raw-unmasked` solo en zona segura con RBAC estricto; `staging` consume solo masked/curated. |
| SQL audit store | Storage JSON/Parquet, Azure SQL Serverless | Empezar con Storage; pasar a SQL cuando haya consultas reales. |
| Orquestacion | Manual/scripts, Function timer, ADF | Empezar manual/scripts; ADF cuando haya fuente formal. |
