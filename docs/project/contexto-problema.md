# Contexto Y Problema

Pricing Intelligence no termina cuando se calcula una recomendacion de precio. En un entorno operativo, tambien importa saber con que datos se corrio, que version de codigo participo, donde quedo la evidencia, quien puede revisar los resultados y como repetir la ejecucion.

Ese es el problema que atiende este proyecto: convertir un flujo tecnico de pricing en una base MLOps que pueda ser operada, auditada y explicada.

## El Riesgo De Un Flujo Aislado

Sin plataforma, el trabajo de pricing puede quedar repartido entre notebooks, scripts locales, archivos manuales y ejecuciones dificiles de reconstruir. Eso complica tres cosas:

- **Trazabilidad:** no siempre queda claro que version de datos, codigo y configuracion produjo un resultado.
- **Repetibilidad:** repetir una corrida depende de conocimiento manual o contexto local.
- **Gobierno:** es facil mezclar datos sensibles, outputs temporales y evidencias sin una frontera clara.

Para este proyecto, esos riesgos afectan la revision del trabajo. No basta con mostrar una ejecucion; tambien hay que explicar como se ejecuto, donde quedo la evidencia y que decisiones limitan el alcance.

## La Decision Del MVP

El equipo eligio una arquitectura acotada y de bajo costo para validar la base operativa:

```text
Platform
-> Azure base
-> Storage/ADLS y Azure ML

pricing-mlops
-> Azure ML pipeline endpoint
-> artefactos versionados en Storage
```

Azure ML ejecuta el flujo funcional. Storage conserva inputs masked y artefactos versionados. GitHub Actions valida y despliega infraestructura, pero no ejecuta el modelo desde platform.

## Que Permite Esta Base

El MVP permite validar capacidades basicas antes de invertir en piezas mas costosas o complejas:

- separar plataforma de codigo data science;
- operar con datos masked en `staging`;
- publicar outputs con una convencion de rutas;
- conservar evidencia de corridas;
- conservar metadata y artefactos sin guardar datasets completos en servicios externos innecesarios;
- preparar la integracion posterior de un modelo real.

## Lectura Siguiente

Para ver que se comprometio formalmente en esta etapa, continua con [Objetivos y alcance](objetivos-alcance.md).
