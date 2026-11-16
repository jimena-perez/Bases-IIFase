# Defensa — Proyecto 2 (Grupo 02, Taller Ruta 27)

**IC-4301 Bases de Datos I · Tecnológico de Costa Rica**

## Enlaces a los videos

| Integrante | Enlace |
|---|---|
| Jimena Pérez Alfaro | `<PENDIENTE — lo agrega la integrante>` |
| Rachel Priscilla Ramírez González | `<PENDIENTE — lo agrega la integrante>` |

Condiciones del curso, iguales a las del Lab03 salvo que el profesor indique otras: toma continua sin cortes, cámara encendida y pantalla compartida. Cada integrante se identifica, explica decisiones y efectos en los datos con sus propias palabras y ejecuta **al menos una prueba o un rechazo** de su parte.

## Reparto sugerido (las integrantes lo ajustan)

| Integrante | Parte |
|---|---|
| **Jimena** | G02-P01 (versiones y decisiones) + integridad de facultades y garantía |
| **Rachel** | G02-P02 (ejecución) + G02-P03 (estados y fecha prometida) |

## Preparación antes de grabar (2 minutos)

```bash
dropdb --if-exists -U postgres taller_ruta27
```

```bash
createdb -U postgres -E UTF8 -T template0 taller_ruta27
```

```bash
psql -U postgres -d taller_ruta27 -v ON_ERROR_STOP=1 -f sql/run_all.sql
```

```bash
psql -U postgres -d taller_ruta27 -v ON_ERROR_STOP=1 -f pruebas/run_pruebas.sql > resultados_locales.txt 2>&1
```

Para la parte de concurrencia: `psql -U postgres -d taller_ruta27 -f pruebas/concurrencia/00_preparacion_concurrencia.sql`.

---

## Guion — Jimena (P01 + facultades y garantía)

1. **Identificación y tema** (15 s).
2. **Decisión técnica: labor ≠ línea de versión** (D6). Mostrar en `docs/modelo_relacional.md` `labor`, `linea_propuesta` y `autorizacion_labor` y explicar por qué la decisión es por versión.
3. **Regla de decisión aplicable** (README §6.1). Consultar:
   ```sql
   SET search_path = taller, public;
   SELECT labor_id, descripcion, version_vigente, precio_vigente, situacion, decidido_por, autorizacion_id
   FROM v_situacion_labor WHERE orden_id = 9001 ORDER BY labor_id;
   SELECT labor, version, precio_estimado, decision_en_esta_version, es_version_vigente
   FROM v_comparacion_versiones WHERE orden_id = 9001 ORDER BY labor_id, version;
   ```
   Señalar que la v1 sigue intacta y que la alineación (C) está Pendiente en v1 y Aceptada en v3, sin arrastre.
4. **Rechazo en vivo (facultad de otro contexto):** Ana está facultada en la orden 9002, no en la 9001.
   ```sql
   SELECT fn_registrar_decision(pruebas.propuesta_id(9001, 2), pruebas.labor_id(9001, 'Purga y cambio'),
                                104, 'Rechazada', 'Teléfono', 201, now());
   ```
   Error esperado: `G02-P01: el cliente 104 no tiene facultad vigente para aprobar en la orden 9001`. Después mostrar que no hay fila nueva (`SELECT count(*) FROM autorizacion_labor WHERE orden_id = 9001;`).
5. **Concurrencia** (opcional, si alcanza el tiempo): `pruebas/concurrencia/P01_instrucciones.md`, escenario C1, con dos terminales.
6. **Garantía "vence lo primero":** mostrar la consulta final de G02-INT-18 en `pruebas/90_integridad_modelo.sql`, con un reclamo rechazado por km y uno aceptado dentro de ambos límites, y explicar por qué la garantía existe sin reclamo (D3).

## Guion — Rachel (P02 + P03)

1. **Identificación y tema** (15 s).
2. **Decisión técnica: valor actual + historial** (D4). Explicar por qué el UPDATE directo del Lab03 ahora falla y quién actualiza el valor actual: el trigger AFTER INSERT del historial, en la misma transacción.
   ```sql
   SET search_path = taller, public;
   UPDATE orden_trabajo SET fecha_prometida_actual = now() + interval '9 days' WHERE orden_id = 9013;
   ```
   Error esperado: `G02-P03: … solo cambian mediante su historial`. Luego hacer el cambio por la vía correcta:
   ```sql
   SELECT fn_cambiar_fecha_prometida(9013, now() + interval '9 days', now(), 'Teléfono', 'Demostración en la defensa', 201);
   SELECT * FROM v_cronologia_promesas WHERE orden_id = 9013 ORDER BY secuencia;
   ```
3. **Historia de una reparación con retrabajo** (P02-V):
   ```sql
   SELECT * FROM v_historia_labor WHERE orden_id = 9003 ORDER BY labor_id, secuencia;
   SELECT * FROM v_retrabajos WHERE orden_id = 9003;
   SELECT * FROM v_propuesto_vs_ejecutado WHERE orden_id = 9003;
   ```
   Explicar que el retrabajo **no** queda cubierto por la autorización original (ambigüedad A-01).
4. **Rechazo en vivo (labor rechazada):**
   ```sql
   SELECT fn_iniciar_labor(pruebas.labor_id(9003, 'Limpieza de inyectores'), 202, now());
   ```
   Error esperado: `… no tiene autorización aplicable Aceptada … (situación: Rechazada)`.
5. **Concurrencia:** `pruebas/concurrencia/P02_instrucciones.md`, escenario C2 (dos consumos de la última unidad, stock final 0), o `P03_instrucciones.md`, escenario C1.
