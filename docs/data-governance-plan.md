# Data Governance

## Reglas

1. No commitear datos reales ni `raw-unmasked`.
2. `raw-unmasked` solo puede vivir en `data-lab` o un secure sandbox aprobado.
3. `staging`, `validation` y `sandbox-local` usan datos masked, curated o sinteticos.
4. El repo modelo consume Storage con Entra ID/RBAC, no account keys.
5. El equipo de negocio consume reportes o snapshots aprobados, no datasets raw.

## Zonas

| Zona | Uso | Donde |
|---|---|---|
| `raw-unmasked` | Datos sensibles originales. | Solo `data-lab`. |
| `raw-masked` | Inputs masked/sinteticos. | `staging`, `validation`, sandboxes. |
| `curated` | Features limpias. | Ambientes MLOps. |
| `baseline` | Distribuciones y thresholds aprobados. | Ambientes MLOps. |
| `runs` | Run logs. | Ambientes MLOps. |
| `snapshots` | Outputs de scoring. | Ambientes MLOps. |
| `drift-logs` | Semaforo y metricas. | Ambientes MLOps. |
| `reports` | Resumen humano. | Ambientes MLOps. |
| `artifacts` | Evidencia auxiliar. | Ambientes MLOps. |

## Retencion PoC

| Zona | Retencion sugerida |
|---|---:|
| `raw-unmasked` | 7-30 dias |
| `raw-masked`, `curated` | 90-180 dias |
| `baseline`, `runs`, `snapshots`, `drift-logs` | 180-365 dias |
| `reports`, `artifacts` | 30-180 dias |

## Prohibiciones

- No subir CSVs/Parquet reales a GitHub.
- No subir `raw-unmasked` como artifact.
- No usar account keys o connection strings.
- No dar `Owner` o `Contributor` de subscription al repo modelo.
