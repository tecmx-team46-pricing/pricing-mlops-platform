# Retraining Decision

La base operativa no reentrena automaticamente. Solo clasifica el estado y recomienda una accion.

## Semaforo

| Estado | Interpretacion | Accion |
|---|---|---|
| green | Cambios esperados o bajos | `no_action` |
| yellow | Cambio moderado o posible impacto | `business_review` |
| red | Cambio alto o impacto comercial relevante | `recalibrate_or_retrain` |

## Umbrales iniciales

Los umbrales viven en `mlops/configs/drift_thresholds.json`.

| Metrica | Green | Yellow | Red |
|---|---:|---:|---:|
| Cambio relativo de precio | <= 5% | <= 15% | > 15% |
| Cambio relativo de cantidad | <= 10% | <= 25% | > 25% |
| Cambio relativo de precio recomendado | <= 5% | <= 12% | > 12% |
| Impacto ponderado por revenue | <= 3% | <= 10% | > 10% |

## Criterio operativo

El estado final de la corrida es el peor estado observado:

- si todas las metricas son green, la corrida es green;
- si existe al menos una metrica yellow y ninguna red, la corrida es yellow;
- si existe una metrica red, la corrida es red.

## Decision de negocio

`red` no significa reentrenar sin revisar. En pricing B2B, un cambio fuerte puede venir de datos, mix comercial, costos o reglas de negocio. La accion correcta es revisar con Pricing BI/Product antes de recalibrar o reentrenar.
