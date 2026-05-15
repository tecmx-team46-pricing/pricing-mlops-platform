# Azure Phased Deployment Plan

## Proposito

Definir un despliegue incremental y costeable para el proyecto MLOps completo de Pricing Intelligence. El plan cubre los servicios objetivo del PDF de arquitectura, pero los ordena por fases para evitar activar ADF, AML, SQL, ACR, Private Endpoints o Hub-Spoke antes de que exista evidencia tecnica y operativa.

Este documento no modifica IaC. `pricing-mlops-platform` sigue siendo el repo responsable de plataforma, infraestructura y operacion. `pricing-mlops-eda` sigue siendo el repo responsable de modelo, scoring, validaciones y artefactos de ejecucion.

## Resumen ejecutivo

| Clasificacion | Servicios | Decision |
|---|---|---|
| Desplegar ahora | Resource Groups, Key Vault, Log Analytics, User Assigned Managed Identities, OIDC/RBAC, Budget opcional, Storage Account/ADLS layout, Function hello/health si hay cuota | Base barata y verificable para gobierno, storage y operacion inicial. |
| Desplegar despues | Functions Flex para drift/orquestacion liviana, data-lab/secure-sandbox, Azure SQL Serverless, Azure ML, ADF, ACR, Azure Monitor alerts avanzadas | Entran cuando existan datos masked/curated, contratos estables, corridas reproducibles y necesidad real de orquestacion/auditoria. |
| No desplegar por ahora | Hub-Spoke completo, Private Endpoints, Private DNS, self-hosted agents, produccion real | Requieren mayor costo, gobierno de red y operacion. Se reservan para prod conceptual o datos productivos con requisitos enterprise. |

## Fase 0: Foundation

| Campo | Definicion |
|---|---|
| Resource Groups | `rg-pricing-mlops-platform-shared`; RGs de workload declarados por ambiente cuando aplique. |
| Servicios Azure | Resource Groups, tags, Key Vault, Log Analytics, User Assigned Managed Identity, GitHub OIDC federated credentials, RBAC base, Budget opcional. |
| Proposito | Crear la base comun de seguridad, identidad, observabilidad minima y control de costos. |
| Costo/riesgo | Bajo. Key Vault, Log Analytics y UAMI son costeables en PoC; el riesgo principal es asignar permisos demasiado amplios. |
| Dependencias | Subscription activa, permisos de bootstrap, decision de ambientes permitidos y GitHub environments. |
| Criterios para avanzar | Bicep valida, foundation despliega, OIDC funciona sin secrets persistentes, outputs de Key Vault/Log Analytics/UAMI documentados. |

Estado: parcialmente implementado en `infra/foundation/`. Es la unica fase que debe permanecer siempre activa.

## Fase 1: Data Lab

| Campo | Definicion |
|---|---|
| Resource Groups | Futuro `rg-pricing-mlops-data-lab` o `rg-pricing-mlops-secure-sandbox`; `rg-pricing-mlops-platform-shared` para Key Vault e identidades. |
| Servicios Azure | Storage/ADLS con zonas `raw-unmasked`, `raw-masked`, `curated`, lifecycle policies, RBAC dedicado, Key Vault salts/secrets, Log Analytics para auditoria minima. |
| Proposito | Recibir CSVs unmasked de forma controlada, ejecutar masking y producir datasets masked/curated reutilizables por el repo modelo. |
| Costo/riesgo | Bajo a medio. Storage es barato, pero el riesgo de datos es alto porque contiene unmasked. Mitigacion: acceso explicito, retencion corta y sin GitHub Actions por default. |
| Dependencias | Fase 0, data owner definido, reglas de masking, salt en Key Vault, convencion de `dataset_version` y checksums. |
| Criterios para avanzar | `raw-unmasked` aislado, masking reproducible, `raw-masked` publicado, metadata minima registrada, evidencia de que `staging` no recibe unmasked. |

No debe usarse como laboratorio abierto. Si un sandbox personal necesita unmasked, debe cumplir los mismos controles de `secure-sandbox`.

## Fase 2: PoC Sandbox

| Campo | Definicion |
|---|---|
| Resource Groups | `rg-pricing-mlops-sbx-david` o `rg-pricing-mlops-sbx-<owner>-<yyyymmdd>`. |
| Servicios Azure | Storage/ADLS para `raw-masked`, `curated`, `baseline`, `runs`, `snapshots`, `drift-logs`, `reports`, `artifacts`; Azure Function hello/health; App Service Plan B1 o Functions Consumption/Flex si hay cuota. |
| Proposito | Validar el flujo completo con datos masked/curated sin desplegar servicios pesados: contratos, health endpoint, drift PoC, snapshots y reportes. |
| Costo/riesgo | Bajo. Riesgo principal: cuota de App Service/Functions y proliferacion de sandboxes. Mitigacion: lifecycle tags, destruccion de sandboxes y `ENABLE_HELLO_FUNCTION=false` si compute falla. |
| Dependencias | Fases 0 y 1, dataset masked disponible, contenedores definidos, scripts del repo modelo capaces de leer Storage/ADLS. |
| Criterios para avanzar | Corrida end-to-end en sandbox con `run_id`, `model_run_log`, snapshot, drift log, reporte humano y costos revisados. |

Esta fase cubre mas que hello world: el hello endpoint solo prueba compute. El objetivo real es probar evidencia MLOps barata antes de promover a `staging`.

## Fase 3: Staging MVP

| Campo | Definicion |
|---|---|
| Resource Groups | `rg-pricing-mlops-staging`; `rg-pricing-mlops-platform-shared` para servicios comunes. |
| Servicios Azure | Storage/ADLS con datos masked/curated, baseline aprobado, runs, snapshots, drift logs, reports; Function health/drift si el PoC lo justifico; GitHub OIDC para plataforma y modelo. |
| Proposito | Integrar plataforma y repo modelo con datos masked/curated, validaciones automatizadas y corridas manuales reproducibles. |
| Costo/riesgo | Bajo a medio. Se evita unmasked, AML, SQL y ADF. Riesgo principal: tratar staging como prod o promover baselines sin revision. |
| Dependencias | Fase 2 con corrida exitosa, reglas de data governance, workflows del repo modelo, permisos por ambiente. |
| Criterios para avanzar | `pricing-mlops-eda` consume Storage/ADLS, no Git; quality gates pasan; drift produce semaforo; baseline versionado; reportes aprobados por equipo tecnico. |

`staging` no recibe `raw-unmasked`. Es el ambiente para demostrar integracion MVP, no para operar datos productivos.

## Fase 4: Validation Controlada

| Campo | Definicion |
|---|---|
| Resource Groups | `rg-pricing-mlops-validation`; `rg-pricing-mlops-platform-shared`; opcional RG futuro para servicios compartidos de ejecucion si se justifica. |
| Servicios Azure | Storage/ADLS controlado, Function drift/orquestacion liviana, Azure SQL Serverless si Storage ya no basta para auditoria, AML si scripts locales/Functions ya no bastan para scoring/validacion, Azure Monitor alerts iniciales. |
| Proposito | Probar cambios candidatos de plataforma y modelo con aprobacion, evidencia historica y controles mas cercanos a produccion. |
| Costo/riesgo | Medio. SQL/AML agregan costo y complejidad operativa. Se activan solo cuando hay necesidad de consultas historicas, registro de modelos o ejecuciones reproducibles fuera de scripts. |
| Dependencias | Fase 3 estable, criterios de promocion, dataset y baseline aprobados, owners de aprobacion, presupuesto revisado. |
| Criterios para avanzar | Auditoria reproducible por `run_id`, rollback conceptual probado, thresholds revisados, alertas utiles, costo mensual aceptado, decision explicita de entrar a diseno prod. |

Esta fase es el primer punto donde SQL Serverless o AML pueden ser razonables. ADF y ACR siguen opcionales: se justifican por fuentes reales, scheduling formal o necesidad de empaquetar contenedores.

## Fase 5: Prod Conceptual

| Campo | Definicion |
|---|---|
| Resource Groups | Futuros `rg-pricing-mlops-prod`, `rg-pricing-mlops-network-prod` o equivalentes; `shared` reforzado; RGs separados para datos, ejecucion y red si el gobierno lo exige. |
| Servicios Azure | ADLS Gen2, Azure Functions Flex, Azure SQL Serverless o base de auditoria formal, Azure ML, ADF, ACR, Azure Monitor alerts, Hub-Spoke, Private Endpoints, Private DNS, self-hosted runners/agents si se requiere red privada. |
| Proposito | Ejecutar scoring con impacto operativo o de negocio, aislamiento de red, auditoria fuerte, rollback y aprobaciones formales. |
| Costo/riesgo | Alto. Red privada, AML, ADF, SQL y agentes privados elevan costo y carga operativa. Riesgo alto si se activa sin runbooks, monitoreo y ownership claros. |
| Dependencias | Fase 4 aprobada, costo autorizado, data classification formal, runbooks, soporte operativo, SLOs, proceso de rollback y aprobacion de negocio. |
| Criterios para avanzar | No hay fase siguiente. Prod se crea solo con decision explicita, IaC dedicado, revisiones de seguridad/costo y aceptacion de negocio. |

En el estado actual, `prod` no tiene parameter file, workflow ni IaC. Debe seguir conceptual hasta que exista necesidad real.

## Mapeo de servicios del PDF a fases

| Servicio del PDF | Fase realista | Clasificacion | Razon |
|---|---|---|---|
| Azure Data Lake Storage Gen2 / Storage | Fase 1 y Fase 2 | Desplegar ahora/incremental | Es la base barata para datasets masked, curated y evidencia. |
| Azure Key Vault | Fase 0 | Desplegar ahora | Necesario para salts, secretos y referencias sensibles desde el inicio. |
| User Assigned Managed Identity + OIDC | Fase 0 | Desplegar ahora | Evita secrets persistentes en GitHub Actions. |
| Log Analytics | Fase 0 | Desplegar ahora | Observabilidad minima de despliegues y Functions. |
| Azure Functions Flex | Fase 2 o Fase 4 | Desplegar despues si quota/uso lo justifican | Primero health/drift simple; Flex real entra cuando haya ejecucion recurrente o serverless estable. |
| Azure SQL Serverless | Fase 4 | Desplegar despues | Storage JSON/Parquet basta para PoC; SQL entra cuando auditoria requiera consultas historicas. |
| Azure Machine Learning | Fase 4 | Desplegar despues | Requiere gobierno, costos y empaquetado; primero validar scoring en `pricing-mlops-eda`. |
| Azure Data Factory | Fase 4 o Fase 5 | Desplegar despues | Solo se justifica con fuentes reales, scheduling formal y dependencias upstream. |
| Azure Container Registry | Fase 4 o Fase 5 | Desplegar despues | Necesario si validadores/modelos se empaquetan como contenedores. No antes. |
| Azure Monitor alerts | Fase 4 | Desplegar despues | Las alertas son utiles cuando hay metricas reales y runbooks. |
| Hub-Spoke VNet | Fase 5 | No desplegar por ahora | Alto costo/complejidad; se reserva para prod o datos productivos con red privada. |
| Private Endpoints / Private DNS | Fase 5 | No desplegar por ahora | Requieren gobierno de red y operacion privada; bloquean el PoC si se adelantan. |
| Self-hosted DevOps/GitHub agents | Fase 5 | No desplegar por ahora | Solo necesarios si los servicios quedan sin acceso publico y requieren runners dentro de VNet. |

## Por que postergar servicios pesados

| Servicio | Motivo para no usarlo todavia | Senal para activarlo |
|---|---|---|
| ADF | No hay todavia fuentes formales ni scheduling operacional; scripts/manual upload cubren PoC. | Fuentes upstream reales, frecuencia definida, reintentos y dependencias de ingesta. |
| AML | El repo modelo aun debe convertir EDA en scripts reproducibles; AML agregaria registro, compute y permisos antes de validar necesidad. | Modelo empaquetado, tests, necesidad de registry, jobs reproducibles y aprobacion de costo. |
| SQL Serverless | Los logs iniciales caben en Storage y no requieren consultas historicas complejas. | Auditoria por `run_id`, joins frecuentes, reportes historicos y necesidad de SQL para compliance. |
| ACR | No hay imagenes de modelo/validadores listas para publicar. | Scoring/validacion se empaqueta en contenedores para AML, Functions custom container o runners privados. |
| Private Endpoints | Incrementan complejidad de DNS, red y runners. | Datos productivos, requisito de red privada o prohibicion de endpoints publicos. |
| Hub-Spoke | Requiere diseno enterprise, costos y ownership de red. | Prod aprobado, multiples spokes, controles privados y soporte operativo. |

## Tabla servicio -> Resource Group -> ambiente -> repo responsable

| Servicio | Resource Group | Ambiente/fase | Repo responsable |
|---|---|---|---|
| Resource Groups y tags | Subscription scope | Fase 0, todos | `pricing-mlops-platform` |
| Key Vault | `rg-pricing-mlops-platform-shared` | Fase 0 shared | `pricing-mlops-platform` |
| Log Analytics | `rg-pricing-mlops-platform-shared` | Fase 0 shared | `pricing-mlops-platform` |
| User Assigned Managed Identity/OIDC | `rg-pricing-mlops-platform-shared` | Fase 0 shared | `pricing-mlops-platform` |
| Budget | Subscription scope | Fase 0 shared | `pricing-mlops-platform` |
| Storage/ADLS data-lab | `rg-pricing-mlops-data-lab` o `rg-pricing-mlops-secure-sandbox` | Fase 1 data lab | `pricing-mlops-platform` provisiona; `pricing-mlops-eda` consume/genera masked |
| Storage sandbox | `rg-pricing-mlops-sbx-david` o sandbox temporal | Fase 2 PoC sandbox | `pricing-mlops-platform` provisiona; `pricing-mlops-eda` ejecuta validacion/scoring |
| Function hello/health | `rg-pricing-mlops-sbx-david` | Fase 2 PoC sandbox | `pricing-mlops-platform` provisiona; codigo actual en plataforma hasta reemplazo |
| Function drift/orquestacion | `rg-pricing-mlops-staging` o `rg-pricing-mlops-validation` | Fase 3/4 | `pricing-mlops-platform` provisiona; `pricing-mlops-eda` aporta logica si aplica |
| Storage staging | `rg-pricing-mlops-staging` | Fase 3 staging MVP | `pricing-mlops-platform` provisiona; `pricing-mlops-eda` consume/genera artefactos |
| Storage validation | `rg-pricing-mlops-validation` | Fase 4 validation | `pricing-mlops-platform` provisiona; `pricing-mlops-eda` consume/genera artefactos |
| Azure SQL Serverless | `rg-pricing-mlops-validation` o futuro RG audit | Fase 4 validation | `pricing-mlops-platform` provisiona; ambos repos consumen metadata |
| Azure ML | `rg-pricing-mlops-validation` o futuro RG ml | Fase 4 validation | `pricing-mlops-platform` provisiona; `pricing-mlops-eda` opera jobs/modelos |
| Azure Data Factory | `rg-pricing-mlops-validation` o futuro prod RG | Fase 4/5 | `pricing-mlops-platform` provisiona; ambos repos definen contratos de integracion |
| ACR | `rg-pricing-mlops-platform-shared` o RG controlado | Fase 4/5 | `pricing-mlops-platform` provisiona; `pricing-mlops-eda` publica imagenes aprobadas |
| Hub-Spoke, Private Endpoints, Private DNS | Futuros RG de red/prod | Fase 5 prod conceptual | `pricing-mlops-platform` |
| Prod Storage/ADLS, AML, SQL, ADF | Futuros RG prod | Fase 5 prod conceptual | `pricing-mlops-platform` provisiona; `pricing-mlops-eda` opera modelo |

## Reglas de avance entre fases

1. No avanzar si la fase anterior no tiene evidencia escrita de despliegue, costo y owner.
2. No activar servicios pagos persistentes sin revisar presupuesto y tags.
3. No promover datasets si contienen unmasked fuera de `data-lab`/`secure-sandbox`.
4. No mover scoring a AML hasta que el repo modelo tenga scripts reproducibles, tests y versionado de artefactos.
5. No introducir SQL hasta que Storage deje de ser suficiente para auditoria.
6. No introducir ADF hasta que existan fuentes, calendario y SLA de ingesta.
7. No introducir red privada hasta que prod o datos productivos lo exijan.

## Relacion con docs actuales

Este plan extiende `docs/poc-mlops-services-plan.md`, `docs/data-governance-plan.md` y `docs/multi-repo-mlops-deployment-plan.md`.

No contradice el alcance actual porque:

- no toca IaC;
- mantiene `prod` como conceptual;
- mantiene `staging` sin unmasked;
- preserva `shared` como scope comun;
- trata ADF, AML, SQL, ACR, Hub-Spoke y Private Endpoints como fases posteriores;
- cubre el proyecto MLOps completo sin asumir que el repo plataforma contiene el modelo.
