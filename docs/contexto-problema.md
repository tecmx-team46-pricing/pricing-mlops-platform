# Contexto Y Problema

## Contexto

Pricing Intelligence requiere operar datos, reglas, modelos, resultados y evidencia de forma controlada. En un entorno real, una recomendacion de precio no solo debe generarse: tambien debe poder explicarse, repetirse, auditarse y monitorearse.

El proyecto parte de una necesidad academica y tecnica: pasar de un diseno conceptual a una base operativa que permita ejecutar un flujo MLOps minimo en la nube, con costos controlados y sin exponer datos sensibles.

## Problema

Sin una plataforma MLOps, el flujo de pricing tiende a quedar repartido entre notebooks, scripts locales, archivos manuales y ejecuciones dificiles de auditar. Eso genera riesgos:

- baja trazabilidad de que version de codigo, datos y configuracion produjo una recomendacion;
- poca separacion entre infraestructura y logica funcional del modelo;
- dificultad para repetir corridas y comparar resultados;
- falta de evidencia versionada para revision academica o tecnica;
- riesgo de mezclar datos sensibles con ambientes operativos no aprobados.

## Propuesta Del MVP

El MVP resuelve el problema con una arquitectura acotada:

```text
Evento o solicitud manual
-> Azure Function
-> Azure ML Pipeline
-> Storage/ADLS
-> Azure SQL audit
```

La Function orquesta. Azure ML ejecuta el flujo tecnico. Storage conserva los artefactos funcionales. SQL guarda metadata consultable. GitHub Actions valida y despliega infraestructura, pero no ejecuta el flujo ML.

## Criterio Academico

Para la entrega de maestria, el valor principal no es afirmar que existe una plataforma productiva completa. El valor es demostrar que el equipo construyo una base operativa con decisiones claras de arquitectura, seguridad, gobierno de datos, evidencia y evolucion futura.
