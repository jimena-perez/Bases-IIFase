# Declaración de uso de inteligencia artificial

**IC-4301 Bases de Datos I · Proyecto (2.ª entrega) · Grupo 02 · Taller Ruta 27**
**Integrantes:** Jimena Pérez Alfaro · Rachel Priscilla Ramírez González

Esta declaración sigue la indicación del curso: el uso de IA no sustituye el análisis ni es una justificación técnica, y las integrantes son responsables de verificar, explicar y modificar todo lo entregado.

## 1. Herramientas y propósito

| Entrega | Herramienta | Propósito |
|---|---|---|
| Proyecto 1 | ChatGPT | Apoyo en la redacción y revisión del diseño conceptual y lógico (declarado en esa entrega). |
| Proyecto 2 (esta entrega) | **Claude Code** (agente de código de Anthropic, en una sesión en la nube conectada al repositorio) | Implementación del modelo físico, rutinas, triggers, datos de preparación, pruebas, ejecución real en PostgreSQL 17 y documentación, a partir de un documento de instrucciones preparado por el grupo (`INSTRUCCIONES_PROYECTO2_TallerRuta27.md`). |

## 2. Prompts relevantes

1. Entrega del documento de instrucciones completo con la indicación: *"en este md está todo lo que debes hacer del proyecto"*. El documento incluye el modelo del P1, los defectos D1–D12, el diseño físico recomendado, los procesos P01–P03, las pruebas exigidas, la estructura de la entrega y el flujo de Git.
2. Indicación del repositorio de trabajo (`jimena-perez/Bases-IIFase`).

El agente leyó además, en modo solo lectura, la rama `lab03-grupo02-entrega` del repositorio del curso para reutilizar el Lab03.

## 3. Qué hizo la herramienta y cómo se validó

| Aspecto | Detalle |
|---|---|
| Ejecución real | Se instaló **PostgreSQL 17.10** en el entorno del agente (el repositorio apt oficial estaba bloqueado por la red; se usaron los binarios oficiales de PostgreSQL publicados en npm como `@embedded-postgres/linux-x64`). **Ningún resultado "observado" se escribió a mano:** todos los archivos de `resultados/` son salidas reales de `psql`. |
| Validación automática | 250 comprobaciones registradas en `pruebas.evidencia`: 177 rechazos esperados con SQLSTATE y mensaje reales, y 73 verificaciones de datos. Todas dieron OK desde una base nueva. Además se ejecutaron 7 escenarios de concurrencia con **dos procesos `psql` reales en paralelo**. |
| Revisión contra las instrucciones | Checklist §12 de las instrucciones (ver README §10). |

## 4. Sugerencias aceptadas, corregidas o rechazadas durante el desarrollo

Errores detectados al ejecutar y corregidos por la propia herramienta. Se documentan para que el grupo los pueda explicar.

| # | Situación | Qué se hizo |
|---:|---|---|
| 1 | El trigger de especialidades exigía técnico **activo** y rechazaba la especialidad histórica de una técnica inactiva. | Se corrigió para exigir solo el rol Técnico. |
| 2 | Las rutinas del Lab03 reciben `INTEGER` y la orden se había definido `bigint`: `fn_prioridad_orden(bigint)` no existía. | Se mantuvo `integer` en las relaciones heredadas del Lab03 para reutilizarlas **sin modificar** (C-02). |
| 3 | `CALL` no admite subconsultas como argumento. | Las utilidades de prueba se convirtieron en funciones usadas con `SELECT`. |
| 4 | Los triggers disparan antes que las FK, así que las pruebas no mostraban la FK compuesta. | Se agregaron variantes que desactivan el trigger **solo dentro de la subtransacción de la prueba**, para demostrar que la FK compuesta rechaza por sí sola (defensa en profundidad). |
| 5 | La base se había creado con codificación `SQL_ASCII` (valor por defecto del clúster). | Se recreó con `-E UTF8` y se documentó en el README. |
| 6 | Mensajes poco legibles: valores booleanos `t`/`f` en el vencimiento de la garantía, y "el personal  no existe" cuando faltaba el autor. | Se corrigieron los mensajes y se dejó que la obligatoriedad la imponga `NOT NULL`. |
| 7 | La sugerencia de las instrucciones de usar `GENERATED ALWAYS` impedía reutilizar el alta del Lab03, que recibe `orden_id`. | Se adoptó `BY DEFAULT` y se justificó (C-02). |
| 8 | La validación del curso no admite `.txt`. | Los resultados se guardan en `.md` (C-16). |

**Decisiones de diseño que tomó la herramienta y que el grupo debe revisar y poder defender:** las ambigüedades A-01 … A-16 de [`docs/ambiguedades.md`](docs/ambiguedades.md) y la redacción de los criterios AC (A-15).

## 5. Validación por parte de las integrantes

> **Pendiente de completar por cada integrante.** No se inventa participación humana que no ocurrió: esta sección la llenan Jimena y Rachel.

### Jimena Pérez Alfaro
- [ ] Ejecuté `sql/run_all.sql` y `pruebas/run_pruebas.sql` en mi equipo. Versión de PostgreSQL usada: ________
- [ ] Revisé y puedo explicar: ________________________________________________
- [ ] Cambios o correcciones que hice sobre lo generado: _________________________
- [ ] Discrepancias encontradas con el enunciado o el anexo: _____________________

### Rachel Priscilla Ramírez González
- [ ] Ejecuté `sql/run_all.sql` y `pruebas/run_pruebas.sql` en mi equipo. Versión de PostgreSQL usada: ________
- [ ] Revisé y puedo explicar: ________________________________________________
- [ ] Cambios o correcciones que hice sobre lo generado: _________________________
- [ ] Discrepancias encontradas con el enunciado o el anexo: _____________________
