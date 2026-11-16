# Salida de las pruebas · P02

> Generado ejecutando de verdad, el 2026-11-16 04:07 UTC, en una base nueva (`taller_ruta27`).
>
> Comando: `psql -X -a -d taller_ruta27 -v ON_ERROR_STOP=1 -f pruebas/20_p02_validas.sql -f pruebas/21_p02_invalidas.sql -f pruebas/22_p02_limite.sql -f pruebas/23_p02_atomicidad.sql`

```text
-- =====================================================================
-- G02-P02 · Ejecutar reparaciones y pruebas · VÁLIDAS
-- Orden: 9003 (Carlos Méndez, VW Jetta DEF456). Reserva previa de 1 juego
-- de pastillas FR-001. Hallazgos: 4104 frenos, 4105 sensor de oxígeno.
-- Las autorizaciones se obtienen con el proceso P01 real (no precargadas).
-- =====================================================================
SET search_path = taller, public;
SET
SET TIME ZONE 'America/Costa_Rica';
SET
-- ---------------------------------------------------------------------
-- Preparación vía P01 y P03: v1 con 6 labores; Carlos acepta 5 y rechaza 1.
--   P  pastillas (requiere repuesto FR-001)      Q  purga (requiere P)
--   S  sensor de oxígeno                          U  borrado de códigos (requiere S)
--   K  limpieza de inyectores (será RECHAZADA)    W  freno de mano (sin repuestos)
-- ---------------------------------------------------------------------
SELECT fn_cambiar_estado_orden(9003, 'En diagnóstico', 202, NULL, '2026-11-04 08:30');
 fn_cambiar_estado_orden 
-------------------------
                      23
(1 row)

SELECT fn_publicar_propuesta(9003, NULL,
  '[{"clave":"P","descripcion":"Cambio de pastillas y revisión de discos","hallazgo_id":4104,"precio_estimado":40000,
     "repuestos":[{"repuesto_id":"FR-001","cantidad":1,"precio_unitario":25000}]},
    {"clave":"S","descripcion":"Sustitución del sensor de oxígeno","hallazgo_id":4105,"precio_estimado":20000,
     "repuestos":[{"repuesto_id":"EL-001","cantidad":1,"precio_unitario":41000}]},
    {"descripcion":"Purga del sistema de frenos","hallazgo_id":4104,"precio_estimado":12000,
     "repuestos":[{"repuesto_id":"FR-002","cantidad":1,"precio_unitario":6500}],"requiere":["P"]},
    {"descripcion":"Borrado de códigos y prueba de emisiones","hallazgo_id":4105,"precio_estimado":8000,"requiere":["S"]},
    {"descripcion":"Limpieza de inyectores","precio_estimado":25000},
    {"descripcion":"Ajuste de freno de mano","hallazgo_id":4104,"precio_estimado":6000}]'::jsonb,
  205, 'Presupuesto de frenos y motor', '2026-11-04 10:00');
 fn_publicar_propuesta 
-----------------------
                   318
(1 row)

SELECT fn_cambiar_estado_orden(9003, 'Pendiente autorización', 206, NULL, '2026-11-04 10:05');
 fn_cambiar_estado_orden 
-------------------------
                      24
(1 row)

SELECT fn_registrar_decision(pruebas.propuesta_id(9003, 1), l.labor_id, 102,
                             CASE WHEN l.descripcion LIKE 'Limpieza%' THEN 'Rechazada' ELSE 'Aceptada' END,
                             'Correo', 206, '2026-11-04 10:30')
FROM labor l WHERE l.orden_id = 9003 ORDER BY l.labor_id;
 fn_registrar_decision 
-----------------------
                   622
                   623
                   624
                   625
                   626
                   627
(6 rows)

SELECT fn_cambiar_estado_orden(9003, 'Autorizada', 206, NULL, '2026-11-04 10:40');
 fn_cambiar_estado_orden 
-------------------------
                      25
(1 row)

SELECT fn_cambiar_estado_orden(9003, 'En reparación', 202, NULL, '2026-11-04 13:00');
 fn_cambiar_estado_orden 
-------------------------
                      26
(1 row)

SELECT labor_id, descripcion, situacion, autorizacion_id FROM v_situacion_labor WHERE orden_id = 9003 ORDER BY labor_id;
 labor_id |               descripcion                | situacion | autorizacion_id 
----------+------------------------------------------+-----------+-----------------
      515 | Cambio de pastillas y revisión de discos | Aceptada  |             622
      516 | Sustitución del sensor de oxígeno        | Aceptada  |             623
      517 | Purga del sistema de frenos              | Aceptada  |             624
      518 | Borrado de códigos y prueba de emisiones | Aceptada  |             625
      519 | Limpieza de inyectores                   | Rechazada |             626
      520 | Ajuste de freno de mano                  | Aceptada  |             627
(6 rows)

-- ===========================================================
-- ID: G02-P02-V-01     Criterio: AC-G02-P02-01, AC-G02-P02-02, AC-G02-P02-03, AC-G02-P02-04
-- Preparación: P aceptada en v1 (vía P01).
-- Acción (una transacción confirmada con COMMIT):
--   iniciar P -> 2 participaciones de técnicos distintos (Diego 90 min de
--   intervalo con 85 efectivos; Andrés 45/45) -> consumo de FR-001 (usa la
--   reserva) -> prueba Desfavorable con medición -> retrabajo ligado ->
--   versión 2 con la línea del retrabajo a precio 0 y aceptación ->
--   iniciar retrabajo -> participación -> prueba Favorable -> completar
--   retrabajo -> completar P.
-- Esperado: historia completa de P y del retrabajo, cada inicio con su
--   autorizacion_id; consumo con su movimiento y liberación de reserva;
--   retrabajo ligado a P y a la prueba; P y retrabajo Completados.
-- ===========================================================
BEGIN;
BEGIN
SELECT fn_iniciar_labor(pruebas.labor_id(9003, 'Cambio de pastillas'), 202, '2026-11-04 13:00');
 fn_iniciar_labor 
------------------
               22
(1 row)

SELECT fn_registrar_participacion(pruebas.labor_id(9003, 'Cambio de pastillas'), 202,
       '2026-11-04 13:00', '2026-11-04 14:30', 85, 'Desmontaje y cambio de pastillas', 1);
 fn_registrar_participacion 
----------------------------
                          1
(1 row)

SELECT fn_registrar_participacion(pruebas.labor_id(9003, 'Cambio de pastillas'), 204,
       '2026-11-04 14:30', '2026-11-04 15:15', 45, 'Medición de discos y montaje de ruedas', 4);
 fn_registrar_participacion 
----------------------------
                          2
(1 row)

SELECT fn_registrar_consumo(9003, pruebas.labor_id(9003, 'Cambio de pastillas'), 'FR-001', 1, 25000, 202, '2026-11-04 14:00');
 fn_registrar_consumo 
----------------------
                    1
(1 row)

SELECT fn_registrar_prueba(pruebas.labor_id(9003, 'Cambio de pastillas'), 202, '2026-11-04 15:30',
       'Prueba de frenado en pista', 'Desfavorable',
       'Distancia de frenado a 80 km/h superior a lo esperado (< 42 m); vibración en el pedal', 48.5, 'm');
 fn_registrar_prueba 
---------------------
                   1
(1 row)

SELECT fn_registrar_retrabajo(pruebas.labor_id(9003, 'Cambio de pastillas'),
       (SELECT prueba_id FROM prueba WHERE labor_id = pruebas.labor_id(9003, 'Cambio de pastillas') AND resultado = 'Desfavorable'),
       'Rectificado de discos delanteros (retrabajo)', 205, '2026-11-04 15:45');
 fn_registrar_retrabajo 
------------------------
                    521
(1 row)

-- El retrabajo NO queda cubierto por la autorización original: línea propia (precio 0) y decisión.
SELECT fn_publicar_propuesta(9003, pruebas.propuesta_id(9003, 1),
       ('[{"labor_id":' || pruebas.labor_id(9003, 'Rectificado') || ',"precio_estimado":0,
           "alcance":"Retrabajo sin costo para el cliente"}]')::jsonb,
       205, 'Retrabajo por prueba desfavorable', '2026-11-04 16:00');
 fn_publicar_propuesta 
-----------------------
                   319
(1 row)

SELECT fn_registrar_decision(pruebas.propuesta_id(9003, 2), pruebas.labor_id(9003, 'Rectificado'),
       102, 'Aceptada', 'Teléfono', 206, '2026-11-04 16:15', 'Acepta el retrabajo sin costo');
 fn_registrar_decision 
-----------------------
                   628
(1 row)

SELECT fn_iniciar_labor(pruebas.labor_id(9003, 'Rectificado'), 202, '2026-11-05 08:00');
 fn_iniciar_labor 
------------------
               24
(1 row)

SELECT fn_registrar_participacion(pruebas.labor_id(9003, 'Rectificado'), 202,
       '2026-11-05 08:00', '2026-11-05 09:00', 55, 'Rectificado en torno y montaje', 1);
 fn_registrar_participacion 
----------------------------
                          3
(1 row)

SELECT fn_registrar_prueba(pruebas.labor_id(9003, 'Rectificado'), 202, '2026-11-05 09:10',
       'Prueba de frenado en pista', 'Favorable', 'Distancia de frenado dentro de lo esperado; sin vibración', 38.2, 'm');
 fn_registrar_prueba 
---------------------
                   2
(1 row)

SELECT fn_completar_labor(pruebas.labor_id(9003, 'Rectificado'), 202, '2026-11-05 09:20');
 fn_completar_labor 
--------------------
                 25
(1 row)

SELECT fn_completar_labor(pruebas.labor_id(9003, 'Cambio de pastillas'), 202, '2026-11-05 09:30');
 fn_completar_labor 
--------------------
                 26
(1 row)

COMMIT;
COMMIT
-- Lectura posterior (nueva transacción).
SELECT * FROM v_historia_labor WHERE orden_id = 9003 AND (labor LIKE 'Cambio de pastillas%' OR labor LIKE 'Rectificado%') ORDER BY labor_id, secuencia;
 orden_id | labor_id |                    labor                     | secuencia | estado_anterior | estado_nuevo |       fecha_hora       | registrado_por | autorizacion_id | emergencia_id |        motivo        
----------+----------+----------------------------------------------+-----------+-----------------+--------------+------------------------+----------------+-----------------+---------------+----------------------
     9003 |      515 | Cambio de pastillas y revisión de discos     |         1 |                 | Pendiente    | 2026-11-04 10:00:00-06 | Marta León     |                 |               | Registro de la labor
     9003 |      515 | Cambio de pastillas y revisión de discos     |         2 | Pendiente       | En proceso   | 2026-11-04 13:00:00-06 | Diego Mora     |             622 |               | 
     9003 |      515 | Cambio de pastillas y revisión de discos     |         3 | En proceso      | Completada   | 2026-11-05 09:30:00-06 | Diego Mora     |                 |               | 
     9003 |      521 | Rectificado de discos delanteros (retrabajo) |         1 |                 | Pendiente    | 2026-11-04 15:45:00-06 | Marta León     |                 |               | Registro de la labor
     9003 |      521 | Rectificado de discos delanteros (retrabajo) |         2 | Pendiente       | En proceso   | 2026-11-05 08:00:00-06 | Diego Mora     |             628 |               | 
     9003 |      521 | Rectificado de discos delanteros (retrabajo) |         3 | En proceso      | Completada   | 2026-11-05 09:20:00-06 | Diego Mora     |                 |               | 
(6 rows)

SELECT * FROM v_participaciones WHERE orden_id = 9003 ORDER BY participacion_id;
 orden_id | labor_id | participacion_id |    tecnico    |   especialidad   |         inicio         |          fin           | minutos_intervalo | minutos_efectivos |       descripcion_participacion        
----------+----------+------------------+---------------+------------------+------------------------+------------------------+-------------------+-------------------+----------------------------------------
     9003 |      515 |                1 | Diego Mora    | Frenos           | 2026-11-04 13:00:00-06 | 2026-11-04 14:30:00-06 |                90 |                85 | Desmontaje y cambio de pastillas
     9003 |      515 |                2 | Andrés Castro | Mecánica general | 2026-11-04 14:30:00-06 | 2026-11-04 15:15:00-06 |                45 |                45 | Medición de discos y montaje de ruedas
     9003 |      521 |                3 | Diego Mora    | Frenos           | 2026-11-05 08:00:00-06 | 2026-11-05 09:00:00-06 |                60 |                55 | Rectificado en torno y montaje
(3 rows)

SELECT * FROM v_pruebas WHERE orden_id = 9003 ORDER BY prueba_id;
 orden_id | labor_id | prueba_id |       fecha_hora       | realizada_por |        tipo_prueba         |  resultado   | medicion_valor | unidad |                                 descripcion_resultado                                 
----------+----------+-----------+------------------------+---------------+----------------------------+--------------+----------------+--------+---------------------------------------------------------------------------------------
     9003 |      515 |         1 | 2026-11-04 15:30:00-06 | Diego Mora    | Prueba de frenado en pista | Desfavorable |         48.500 | m      | Distancia de frenado a 80 km/h superior a lo esperado (< 42 m); vibración en el pedal
     9003 |      521 |         2 | 2026-11-05 09:10:00-06 | Diego Mora    | Prueba de frenado en pista | Favorable    |         38.200 | m      | Distancia de frenado dentro de lo esperado; sin vibración
(2 rows)

SELECT * FROM v_retrabajos WHERE orden_id = 9003;
 orden_id | retrabajo_id |                  retrabajo                   | estado_retrabajo | labor_revisada_id |              labor_revisada              | estado_labor_revisada | prueba_origen_id | resultado_prueba_origen |                                hallazgo_prueba_origen                                 
----------+--------------+----------------------------------------------+------------------+-------------------+------------------------------------------+-----------------------+------------------+-------------------------+---------------------------------------------------------------------------------------
     9003 |          521 | Rectificado de discos delanteros (retrabajo) | Completada       |               515 | Cambio de pastillas y revisión de discos | Completada            |                1 | Desfavorable            | Distancia de frenado a 80 km/h superior a lo esperado (< 42 m); vibración en el pedal
(1 row)

SELECT pruebas.verificar('G02-P02-V-01', 'AC-G02-P02-01', 'P inició con SU autorización aplicable Aceptada',
     (SELECT h.autorizacion_id = s.autorizacion_id FROM historial_labor h JOIN v_situacion_labor s USING (labor_id)
      WHERE h.labor_id = pruebas.labor_id(9003, 'Cambio de pastillas') AND h.estado_nuevo = 'En proceso'),
     'autorizacion_id del inicio = decisión aplicable',
     (SELECT 'inicio con autorizacion_id ' || autorizacion_id FROM historial_labor
      WHERE labor_id = pruebas.labor_id(9003, 'Cambio de pastillas') AND estado_nuevo = 'En proceso'));
psql:pruebas/20_p02_validas.sql:91: NOTICE:  OK    [G02-P02-V-01] autorizacion_id del inicio = decisión aplicable -> inicio con autorizacion_id 622
                    verificar                    
-------------------------------------------------
 OK G02-P02-V-01: inicio con autorizacion_id 622
(1 row)

SELECT pruebas.verificar('G02-P02-V-01', 'AC-G02-P02-02', '2 técnicos; efectivo (85) menor que el intervalo (90)',
     (SELECT count(DISTINCT tecnico) = 2 AND bool_or(minutos_efectivos < minutos_intervalo)
      FROM v_participaciones WHERE labor_id = pruebas.labor_id(9003, 'Cambio de pastillas')),
     '2 técnicos, uno con 85 de 90 minutos',
     (SELECT string_agg(tecnico || ' ' || minutos_efectivos || '/' || minutos_intervalo, '; ' ORDER BY participacion_id)
      FROM v_participaciones WHERE labor_id = pruebas.labor_id(9003, 'Cambio de pastillas')));
psql:pruebas/20_p02_validas.sql:97: NOTICE:  OK    [G02-P02-V-01] 2 técnicos, uno con 85 de 90 minutos -> Diego Mora 85/90; Andrés Castro 45/45
                       verificar                        
--------------------------------------------------------
 OK G02-P02-V-01: Diego Mora 85/90; Andrés Castro 45/45
(1 row)

SELECT pruebas.verificar('G02-P02-V-01', 'AC-G02-P02-03', 'retrabajo ligado a P y a la prueba Desfavorable; ambos Completados',
     (SELECT estado_retrabajo = 'Completada' AND estado_labor_revisada = 'Completada' AND resultado_prueba_origen = 'Desfavorable'
      FROM v_retrabajos WHERE labor_revisada_id = pruebas.labor_id(9003, 'Cambio de pastillas')),
     'retrabajo Completada, P Completada, origen Desfavorable',
     (SELECT 'retrabajo ' || estado_retrabajo || ', P ' || estado_labor_revisada || ', origen ' || resultado_prueba_origen
      FROM v_retrabajos WHERE labor_revisada_id = pruebas.labor_id(9003, 'Cambio de pastillas')));
psql:pruebas/20_p02_validas.sql:103: NOTICE:  OK    [G02-P02-V-01] retrabajo Completada, P Completada, origen Desfavorable -> retrabajo Completada, P Completada, origen Desfavorable
                                verificar                                 
--------------------------------------------------------------------------
 OK G02-P02-V-01: retrabajo Completada, P Completada, origen Desfavorable
(1 row)

SELECT pruebas.verificar('G02-P02-V-01', 'AC-G02-P02-03', 'la intervención original y su prueba Desfavorable se conservan',
     (SELECT count(*) = 2 FROM prueba WHERE labor_id = pruebas.labor_id(9003, 'Cambio de pastillas') OR labor_id = pruebas.labor_id(9003, 'Rectificado'))
     AND (SELECT count(*) = 2 FROM participacion_tecnica WHERE labor_id = pruebas.labor_id(9003, 'Cambio de pastillas')),
     '2 pruebas (Desfavorable + Favorable) y 2 participaciones de P intactas',
     (SELECT string_agg(resultado, ' + ' ORDER BY prueba_id) FROM prueba WHERE orden_id = 9003));
psql:pruebas/20_p02_validas.sql:108: NOTICE:  OK    [G02-P02-V-01] 2 pruebas (Desfavorable + Favorable) y 2 participaciones de P intactas -> Desfavorable + Favorable
                 verificar                 
-------------------------------------------
 OK G02-P02-V-01: Desfavorable + Favorable
(1 row)

SELECT pruebas.verificar('G02-P02-V-01', 'AC-G02-P02-04', 'consumo con movimiento y liberación de la reserva',
     (SELECT count(*) = 1 FROM movimiento_inventario m JOIN consumo_repuesto c USING (consumo_id)
      WHERE c.labor_id = pruebas.labor_id(9003, 'Cambio de pastillas') AND m.tipo_movimiento = 'Consumo')
     AND (SELECT fisico = 9 AND reservado = 0 AND disponible = 9 FROM v_existencias WHERE repuesto_id = 'FR-001'),
     'FR-001: físico 9, reservado 0, disponible 9',
     (SELECT 'FR-001: físico ' || fisico || ', reservado ' || reservado || ', disponible ' || disponible FROM v_existencias WHERE repuesto_id = 'FR-001'));
psql:pruebas/20_p02_validas.sql:114: NOTICE:  OK    [G02-P02-V-01] FR-001: físico 9, reservado 0, disponible 9 -> FR-001: físico 9.00, reservado 0.00, disponible 9.00
                               verificar                               
-----------------------------------------------------------------------
 OK G02-P02-V-01: FR-001: físico 9.00, reservado 0.00, disponible 9.00
(1 row)

-- ===========================================================
-- ID: G02-P02-V-02     Criterio: AC-G02-P02-01, AC-G02-P02-04
-- Preparación: Q depende de P (ya Completada).
-- Acción: iniciar Q, participación, consumo de líquido de frenos, prueba
--   con medición y completar.
-- Esperado: Q Completada; la dependencia se respetó; propuesto vs ejecutado.
-- ===========================================================
SELECT fn_iniciar_labor(pruebas.labor_id(9003, 'Purga'), 204, '2026-11-05 09:40');
 fn_iniciar_labor 
------------------
               27
(1 row)

SELECT fn_registrar_participacion(pruebas.labor_id(9003, 'Purga'), 204, '2026-11-05 09:40', '2026-11-05 10:20', 40,
       'Purga por las cuatro ruedas', 4);
 fn_registrar_participacion 
----------------------------
                          4
(1 row)

SELECT fn_registrar_consumo(9003, pruebas.labor_id(9003, 'Purga'), 'FR-002', 1, 6500, 204, '2026-11-05 09:50');
 fn_registrar_consumo 
----------------------
                    2
(1 row)

SELECT fn_registrar_prueba(pruebas.labor_id(9003, 'Purga'), 204, '2026-11-05 10:25', 'Prueba de recorrido del pedal',
       'Favorable', 'Pedal firme, sin aire en el circuito', 35, 'mm');
 fn_registrar_prueba 
---------------------
                   3
(1 row)

SELECT fn_completar_labor(pruebas.labor_id(9003, 'Purga'), 204, '2026-11-05 10:30');
 fn_completar_labor 
--------------------
                 28
(1 row)

SELECT * FROM v_propuesto_vs_ejecutado WHERE orden_id = 9003 ORDER BY labor_id;
 orden_id | labor_id |                 descripcion                  | estado_labor | version_vigente | mano_obra_estimada | repuestos_estimados | repuestos_consumidos | minutos_efectivos | tecnicos 
----------+----------+----------------------------------------------+--------------+-----------------+--------------------+---------------------+----------------------+-------------------+----------
     9003 |      515 | Cambio de pastillas y revisión de discos     | Completada   |               1 |           40000.00 |          25000.0000 |           25000.0000 |               130 |        2
     9003 |      516 | Sustitución del sensor de oxígeno            | Pendiente    |               1 |           20000.00 |          41000.0000 |                    0 |                 0 |        0
     9003 |      517 | Purga del sistema de frenos                  | Completada   |               1 |           12000.00 |           6500.0000 |            6500.0000 |                40 |        1
     9003 |      518 | Borrado de códigos y prueba de emisiones     | Pendiente    |               1 |            8000.00 |                   0 |                    0 |                 0 |        0
     9003 |      519 | Limpieza de inyectores                       | Pendiente    |               1 |           25000.00 |                   0 |                    0 |                 0 |        0
     9003 |      520 | Ajuste de freno de mano                      | Pendiente    |               1 |            6000.00 |                   0 |                    0 |                 0 |        0
     9003 |      521 | Rectificado de discos delanteros (retrabajo) | Completada   |               2 |               0.00 |                   0 |                    0 |                55 |        1
(7 rows)

SELECT * FROM v_insumos_orden WHERE orden_id = 9003 ORDER BY concepto, referencia;
 orden_id |       concepto        | labor_id | referencia | cantidad | precio_unitario 
----------+-----------------------+----------+------------+----------+-----------------
     9003 | Consumo               |      515 | FR-001     |     1.00 |        25000.00
     9003 | Consumo               |      517 | FR-002     |     1.00 |         6500.00
     9003 | Liberación de reserva |          | FR-001     |     1.00 |                
     9003 | Presupuesto (v1)      |      516 | EL-001     |     1.00 |        41000.00
     9003 | Presupuesto (v1)      |      515 | FR-001     |     1.00 |        25000.00
     9003 | Presupuesto (v1)      |      517 | FR-002     |     1.00 |         6500.00
     9003 | Reserva               |          | FR-001     |     1.00 |                
(7 rows)

SELECT pruebas.verificar('G02-P02-V-02', 'AC-G02-P02-04', 'propuesto vs ejecutado de P y Q',
     (SELECT string_agg(repuestos_estimados || '/' || repuestos_consumidos || '/' || minutos_efectivos, ',' ORDER BY labor_id)
      FROM v_propuesto_vs_ejecutado WHERE labor_id IN (pruebas.labor_id(9003, 'Cambio de pastillas'), pruebas.labor_id(9003, 'Purga')))
     = '25000.0000/25000.0000/130,6500.0000/6500.0000/40',
     'P 25000/25000/130 min; Q 6500/6500/40 min',
     (SELECT string_agg(repuestos_estimados || '/' || repuestos_consumidos || '/' || minutos_efectivos, ',' ORDER BY labor_id)
      FROM v_propuesto_vs_ejecutado WHERE labor_id IN (pruebas.labor_id(9003, 'Cambio de pastillas'), pruebas.labor_id(9003, 'Purga'))));
psql:pruebas/20_p02_validas.sql:139: NOTICE:  OK    [G02-P02-V-02] P 25000/25000/130 min; Q 6500/6500/40 min -> 25000.0000/25000.0000/130,6500.0000/6500.0000/40
                             verificar                             
-------------------------------------------------------------------
 OK G02-P02-V-02: 25000.0000/25000.0000/130,6500.0000/6500.0000/40
(1 row)

-- =====================================================================
-- G02-P02 · Ejecutar reparaciones y pruebas · INVÁLIDAS
-- Orden 9003: K Rechazada, U depende de S, S se inicia aquí (válido) para
-- servir de labor En proceso; la orden 9001 es el "contexto ajeno".
-- Tras cada intento se comprueba que el estado no avanzó ni quedaron filas.
-- =====================================================================
SET search_path = taller, public;
SET
SET TIME ZONE 'America/Costa_Rica';
SET
-- ===========================================================
-- ID: G02-P02-I-01     Criterio: AC-G02-P02-01
-- Preparación: K fue RECHAZADA por Carlos en v1; P ya está Completada.
-- Acción: iniciar K (por la rutina y por INSERT directo citando la
--   autorización Rechazada) e iniciar de nuevo P.
-- Esperado: rechazos; K sigue Pendiente con 1 fila de historial.
-- ===========================================================
SELECT pruebas.esperar_rechazo('G02-P02-I-01', 'AC-G02-P02-01', 'iniciar labor rechazada',
     $q$ SELECT fn_iniciar_labor(pruebas.labor_id(9003, 'Limpieza de inyectores'), 202, '2026-11-05 11:00') $q$,
     'situación: Rechazada');
psql:pruebas/21_p02_invalidas.sql:19: NOTICE:  OK    [G02-P02-I-01] rechazo esperado -> P0001: G02-P02: la labor 519 no tiene autorización aplicable Aceptada ni excepción de emergencia (situación: Rechazada)
                                                             esperar_rechazo                                                              
------------------------------------------------------------------------------------------------------------------------------------------
 OK G02-P02-I-01: P0001: G02-P02: la labor 519 no tiene autorización aplicable Aceptada ni excepción de emergencia (situación: Rechazada)
(1 row)

SELECT pruebas.esperar_rechazo('G02-P02-I-01', 'AC-G02-P02-01', 'INSERT directo citando la autorización Rechazada',
     $q$ INSERT INTO historial_labor (labor_id, estado_nuevo, fecha_hora, personal_id, autorizacion_id)
         SELECT labor_id, 'En proceso', '2026-11-05 11:00', 202, autorizacion_id
         FROM v_situacion_labor WHERE labor_id = pruebas.labor_id(9003, 'Limpieza de inyectores') $q$,
     'no es la decisión aplicable Aceptada');
psql:pruebas/21_p02_invalidas.sql:24: NOTICE:  OK    [G02-P02-I-01] rechazo esperado -> P0001: G02-P02: la autorización 626 no es la decisión aplicable Aceptada de la labor 519 (situación: Rechazada)
                                                         esperar_rechazo                                                          
----------------------------------------------------------------------------------------------------------------------------------
 OK G02-P02-I-01: P0001: G02-P02: la autorización 626 no es la decisión aplicable Aceptada de la labor 519 (situación: Rechazada)
(1 row)

SELECT pruebas.esperar_rechazo('G02-P02-I-01', 'AC-G02-P02-01', 'INSERT directo citando la autorización de OTRA labor',
     $q$ INSERT INTO historial_labor (labor_id, estado_nuevo, fecha_hora, personal_id, autorizacion_id)
         SELECT pruebas.labor_id(9003, 'Limpieza de inyectores'), 'En proceso', '2026-11-05 11:00', 202, autorizacion_id
         FROM v_situacion_labor WHERE labor_id = pruebas.labor_id(9003, 'Sustitución del sensor') $q$,
     'no es la decisión aplicable Aceptada');
psql:pruebas/21_p02_invalidas.sql:29: NOTICE:  OK    [G02-P02-I-01] rechazo esperado -> P0001: G02-P02: la autorización 623 no es la decisión aplicable Aceptada de la labor 519 (situación: Rechazada)
                                                         esperar_rechazo                                                          
----------------------------------------------------------------------------------------------------------------------------------
 OK G02-P02-I-01: P0001: G02-P02: la autorización 623 no es la decisión aplicable Aceptada de la labor 519 (situación: Rechazada)
(1 row)

-- Defensa en profundidad: con el trigger desactivado (solo dentro de la
-- subtransacción de la prueba), la FK compuesta (autorizacion_id, labor_id)
-- impide citar la autorización de otra labor.
SELECT pruebas.esperar_rechazo('G02-P02-I-01', 'AC-G02-P02-01', 'misma inserción solo contra la FK compuesta',
     $q$ DO $b$ BEGIN
            ALTER TABLE historial_labor DISABLE TRIGGER trg_historial_labor_antes;
            INSERT INTO historial_labor (labor_id, secuencia, estado_anterior, estado_nuevo, fecha_hora, personal_id, autorizacion_id)
            SELECT pruebas.labor_id(9003, 'Limpieza de inyectores'), 2, 'Pendiente', 'En proceso', '2026-11-05 11:00', 202, autorizacion_id
            FROM v_situacion_labor WHERE labor_id = pruebas.labor_id(9003, 'Sustitución del sensor');
         END $b$ $q$,
     'fk_historial_labor_autorizacion');
psql:pruebas/21_p02_invalidas.sql:40: NOTICE:  OK    [G02-P02-I-01] rechazo esperado -> 23503: insert or update on table "historial_labor" violates foreign key constraint "fk_historial_labor_autorizacion"
                                                            esperar_rechazo                                                            
---------------------------------------------------------------------------------------------------------------------------------------
 OK G02-P02-I-01: 23503: insert or update on table "historial_labor" violates foreign key constraint "fk_historial_labor_autorizacion"
(1 row)

SELECT pruebas.esperar_rechazo('G02-P02-I-01', 'AC-G02-P02-01', 'reiniciar una labor Completada',
     $q$ SELECT fn_iniciar_labor(pruebas.labor_id(9003, 'Cambio de pastillas'), 202, '2026-11-05 11:00') $q$,
     'está Completada y no puede iniciarse');
psql:pruebas/21_p02_invalidas.sql:43: NOTICE:  OK    [G02-P02-I-01] rechazo esperado -> P0001: G02-P02: la labor 515 está Completada y no puede iniciarse
                                  esperar_rechazo                                   
------------------------------------------------------------------------------------
 OK G02-P02-I-01: P0001: G02-P02: la labor 515 está Completada y no puede iniciarse
(1 row)

SELECT pruebas.verificar('G02-P02-I-01', 'AC-G02-P02-01', 'K no avanzó',
     (SELECT estado_labor = 'Pendiente' FROM labor WHERE labor_id = pruebas.labor_id(9003, 'Limpieza de inyectores'))
     AND (SELECT count(*) = 1 FROM historial_labor WHERE labor_id = pruebas.labor_id(9003, 'Limpieza de inyectores')),
     'K Pendiente con 1 fila de historial',
     (SELECT estado_labor FROM labor WHERE labor_id = pruebas.labor_id(9003, 'Limpieza de inyectores')) || ' con '
     || (SELECT count(*) FROM historial_labor WHERE labor_id = pruebas.labor_id(9003, 'Limpieza de inyectores')) || ' fila(s)');
psql:pruebas/21_p02_invalidas.sql:49: NOTICE:  OK    [G02-P02-I-01] K Pendiente con 1 fila de historial -> Pendiente con 1 fila(s)
                verificar                 
------------------------------------------
 OK G02-P02-I-01: Pendiente con 1 fila(s)
(1 row)

-- ===========================================================
-- ID: G02-P02-I-02     Criterio: AC-G02-P02-01
-- Preparación: U (aceptada) depende de S, que no está Completada.
-- Acción: iniciar U.
-- Esperado: rechazo "depende de la labor ..., que no está Completada".
-- ===========================================================
SELECT pruebas.esperar_rechazo('G02-P02-I-02', 'AC-G02-P02-01', 'iniciar labor con dependencia sin completar',
     $q$ SELECT fn_iniciar_labor(pruebas.labor_id(9003, 'Borrado de códigos'), 203, '2026-11-05 11:00') $q$,
     'que no está Completada');
psql:pruebas/21_p02_invalidas.sql:59: NOTICE:  OK    [G02-P02-I-02] rechazo esperado -> P0001: G02-P02: la labor 518 depende de la labor 516, que no está Completada
                                        esperar_rechazo                                        
-----------------------------------------------------------------------------------------------
 OK G02-P02-I-02: P0001: G02-P02: la labor 518 depende de la labor 516, que no está Completada
(1 row)

SELECT pruebas.verificar('G02-P02-I-02', 'AC-G02-P02-01', 'U sigue Pendiente',
     (SELECT estado_labor = 'Pendiente' FROM labor WHERE labor_id = pruebas.labor_id(9003, 'Borrado de códigos')),
     'Pendiente', (SELECT estado_labor FROM labor WHERE labor_id = pruebas.labor_id(9003, 'Borrado de códigos')));
psql:pruebas/21_p02_invalidas.sql:62: NOTICE:  OK    [G02-P02-I-02] Pendiente -> Pendiente
         verificar          
----------------------------
 OK G02-P02-I-02: Pendiente
(1 row)

-- Preparación válida para el resto: S pasa a En proceso.
SELECT fn_iniciar_labor(pruebas.labor_id(9003, 'Sustitución del sensor'), 203, '2026-11-05 11:00');
 fn_iniciar_labor 
------------------
               33
(1 row)

-- ===========================================================
-- ID: G02-P02-I-03     Criterio: AC-G02-P02-02
-- Acción: participación en S con un técnico INEXISTENTE (999).
-- Esperado: rechazo "el personal 999 no existe"; 0 participaciones en S.
-- ===========================================================
SELECT pruebas.esperar_rechazo('G02-P02-I-03', 'AC-G02-P02-02', 'participación con técnico inexistente',
     $q$ SELECT fn_registrar_participacion(pruebas.labor_id(9003, 'Sustitución del sensor'), 999,
                '2026-11-05 11:00', '2026-11-05 11:30', 30, 'Intento con técnico inexistente') $q$,
     'el personal 999 no existe');
psql:pruebas/21_p02_invalidas.sql:75: NOTICE:  OK    [G02-P02-I-03] rechazo esperado -> P0001: G02-P02: participación: el personal 999 no existe
                              esperar_rechazo                              
---------------------------------------------------------------------------
 OK G02-P02-I-03: P0001: G02-P02: participación: el personal 999 no existe
(1 row)

-- ===========================================================
-- ID: G02-P02-I-04     Criterio: AC-G02-P02-02
-- Preparación: 201 existe pero es de Recepción; 207 es técnica INACTIVA;
--   la especialidad 3 es de Sofía (203), no de Diego (202); la 5 (Frenos de
--   Andrés) venció el 2025-12-31.
-- Acción: participaciones con cada uno de esos contextos válidos distintos.
-- Esperado: rechazo por rol, por inactividad, por especialidad de otro
--   técnico y por especialidad vencida.
-- ===========================================================
SELECT pruebas.esperar_rechazo('G02-P02-I-04', 'AC-G02-P02-02', 'participación de personal que no es técnico',
     $q$ SELECT fn_registrar_participacion(pruebas.labor_id(9003, 'Sustitución del sensor'), 201,
                '2026-11-05 11:00', '2026-11-05 11:30', 30, 'Recepcionista intentando participar') $q$,
     'tiene rol Recepción y se requiere Técnico');
psql:pruebas/21_p02_invalidas.sql:89: NOTICE:  OK    [G02-P02-I-04] rechazo esperado -> P0001: G02-P02: participación: el personal 201 tiene rol Recepción y se requiere Técnico
                                              esperar_rechazo                                              
-----------------------------------------------------------------------------------------------------------
 OK G02-P02-I-04: P0001: G02-P02: participación: el personal 201 tiene rol Recepción y se requiere Técnico
(1 row)

SELECT pruebas.esperar_rechazo('G02-P02-I-04', 'AC-G02-P02-02', 'participación de técnica inactiva',
     $q$ SELECT fn_registrar_participacion(pruebas.labor_id(9003, 'Sustitución del sensor'), 207,
                '2026-11-05 11:00', '2026-11-05 11:30', 30, 'Técnica inactiva') $q$,
     'no está activo');
psql:pruebas/21_p02_invalidas.sql:93: NOTICE:  OK    [G02-P02-I-04] rechazo esperado -> P0001: G02-P02: participación: el personal 207 no está activo
                                esperar_rechazo                                 
--------------------------------------------------------------------------------
 OK G02-P02-I-04: P0001: G02-P02: participación: el personal 207 no está activo
(1 row)

SELECT pruebas.esperar_rechazo('G02-P02-I-04', 'AC-G02-P02-02', 'especialidad de otro técnico',
     $q$ SELECT fn_registrar_participacion(pruebas.labor_id(9003, 'Sustitución del sensor'), 202,
                '2026-11-05 11:00', '2026-11-05 11:30', 30, 'Diego con la especialidad de Sofía', 3) $q$,
     'la especialidad 3 no está vigente para el técnico 202');
psql:pruebas/21_p02_invalidas.sql:97: NOTICE:  OK    [G02-P02-I-04] rechazo esperado -> P0001: G02-P02: la especialidad 3 no está vigente para el técnico 202 en 2026-11-05
                                           esperar_rechazo                                            
------------------------------------------------------------------------------------------------------
 OK G02-P02-I-04: P0001: G02-P02: la especialidad 3 no está vigente para el técnico 202 en 2026-11-05
(1 row)

SELECT pruebas.esperar_rechazo('G02-P02-I-04', 'AC-G02-P02-02', 'especialidad vencida',
     $q$ SELECT fn_registrar_participacion(pruebas.labor_id(9003, 'Sustitución del sensor'), 204,
                '2026-11-05 11:00', '2026-11-05 11:30', 30, 'Andrés con Frenos vencida', 5) $q$,
     'la especialidad 5 no está vigente');
psql:pruebas/21_p02_invalidas.sql:101: NOTICE:  OK    [G02-P02-I-04] rechazo esperado -> P0001: G02-P02: la especialidad 5 no está vigente para el técnico 204 en 2026-11-05
                                           esperar_rechazo                                            
------------------------------------------------------------------------------------------------------
 OK G02-P02-I-04: P0001: G02-P02: la especialidad 5 no está vigente para el técnico 204 en 2026-11-05
(1 row)

SELECT pruebas.esperar_rechazo('G02-P02-I-04', 'AC-G02-P02-02', 'participación antes de iniciar la labor',
     $q$ SELECT fn_registrar_participacion(pruebas.labor_id(9003, 'Sustitución del sensor'), 203,
                '2026-11-05 10:00', '2026-11-05 10:30', 30, 'Antes del inicio') $q$,
     'no puede iniciar antes de que la labor');
psql:pruebas/21_p02_invalidas.sql:105: NOTICE:  OK    [G02-P02-I-04] rechazo esperado -> P0001: G02-P02: la participación (2026-11-05 10:00:00-06) no puede iniciar antes de que la labor 516 pasara a En proceso (2026-11-05 11:00:00-06)
                                                                          esperar_rechazo                                                                           
--------------------------------------------------------------------------------------------------------------------------------------------------------------------
 OK G02-P02-I-04: P0001: G02-P02: la participación (2026-11-05 10:00:00-06) no puede iniciar antes de que la labor 516 pasara a En proceso (2026-11-05 11:00:00-06)
(1 row)

SELECT pruebas.verificar('G02-P02-I-04', 'AC-G02-P02-02', 'S sin participaciones',
     (SELECT count(*) = 0 FROM participacion_tecnica WHERE labor_id = pruebas.labor_id(9003, 'Sustitución del sensor')),
     '0 participaciones', (SELECT count(*) || ' participaciones' FROM participacion_tecnica WHERE labor_id = pruebas.labor_id(9003, 'Sustitución del sensor')));
psql:pruebas/21_p02_invalidas.sql:108: NOTICE:  OK    [G02-P02-I-04] 0 participaciones -> 0 participaciones
             verificar              
------------------------------------
 OK G02-P02-I-04: 0 participaciones
(1 row)

-- ===========================================================
-- ID: G02-P02-I-05     Criterio: AC-G02-P02-04
-- Acción: cargar a la orden 9001 un consumo de la labor S (que es de 9003),
--   por la rutina y por INSERT directo.
-- Esperado: la rutina responde "no pertenece a la orden 9001"; el INSERT
--   falla por la FK compuesta fk_consumo_labor. 0 consumos/movimientos.
-- ===========================================================
SELECT pruebas.esperar_rechazo('G02-P02-I-05', 'AC-G02-P02-04', 'consumo sobre labor de otra orden (rutina)',
     $q$ SELECT fn_registrar_consumo(9001, pruebas.labor_id(9003, 'Sustitución del sensor'), 'EL-001', 1, 41000, 203, '2026-11-05 11:10') $q$,
     'no pertenece a la orden 9001');
psql:pruebas/21_p02_invalidas.sql:119: NOTICE:  OK    [G02-P02-I-05] rechazo esperado -> P0001: G02-P02: la labor 516 no pertenece a la orden 9001 (es de la orden 9003)
                                         esperar_rechazo                                          
--------------------------------------------------------------------------------------------------
 OK G02-P02-I-05: P0001: G02-P02: la labor 516 no pertenece a la orden 9001 (es de la orden 9003)
(1 row)

SELECT pruebas.esperar_rechazo('G02-P02-I-05', 'AC-G02-P02-04', 'consumo sobre labor de otra orden (INSERT directo)',
     $q$ INSERT INTO consumo_repuesto (labor_id, orden_id, repuesto_id, cantidad_utilizada, precio_unitario_cargado, registrado_por_id)
         VALUES (pruebas.labor_id(9003, 'Sustitución del sensor'), 9001, 'EL-001', 1, 41000, 203) $q$,
     'fk_consumo_labor');
psql:pruebas/21_p02_invalidas.sql:123: NOTICE:  OK    [G02-P02-I-05] rechazo esperado -> 23503: insert or update on table "consumo_repuesto" violates foreign key constraint "fk_consumo_labor"
                                                     esperar_rechazo                                                     
-------------------------------------------------------------------------------------------------------------------------
 OK G02-P02-I-05: 23503: insert or update on table "consumo_repuesto" violates foreign key constraint "fk_consumo_labor"
(1 row)

-- ===========================================================
-- ID: G02-P02-I-06     Criterio: AC-G02-P02-04
-- Preparación: EL-002 (batería) no tiene existencias.
-- Acción: consumir 1 unidad en S.
-- Esperado: rechazo "existencias insuficientes"; no queda consumo ni
--   movimiento (ni consumo sin movimiento, ni movimiento sin origen).
-- ===========================================================
SELECT pruebas.esperar_rechazo('G02-P02-I-06', 'AC-G02-P02-04', 'consumo sin existencias',
     $q$ SELECT fn_registrar_consumo(9003, pruebas.labor_id(9003, 'Sustitución del sensor'), 'EL-002', 1, 52000, 203, '2026-11-05 11:10') $q$,
     'existencias insuficientes de EL-002');
psql:pruebas/21_p02_invalidas.sql:134: NOTICE:  OK    [G02-P02-I-06] rechazo esperado -> P0001: G02-INT: existencias insuficientes de EL-002: el movimiento dejaría -1.00 físicas
                                              esperar_rechazo                                              
-----------------------------------------------------------------------------------------------------------
 OK G02-P02-I-06: P0001: G02-INT: existencias insuficientes de EL-002: el movimiento dejaría -1.00 físicas
(1 row)

SELECT pruebas.verificar('G02-P02-I-06', 'AC-G02-P02-04', 'sin consumo ni movimiento de EL-002',
     (SELECT count(*) = 0 FROM consumo_repuesto WHERE labor_id = pruebas.labor_id(9003, 'Sustitución del sensor'))
     AND (SELECT count(*) = 0 FROM movimiento_inventario WHERE repuesto_id = 'EL-002'),
     '0 consumos en S, 0 movimientos de EL-002',
     (SELECT count(*) FROM consumo_repuesto WHERE labor_id = pruebas.labor_id(9003, 'Sustitución del sensor')) || ' consumos, '
     || (SELECT count(*) FROM movimiento_inventario WHERE repuesto_id = 'EL-002') || ' movimientos');
psql:pruebas/21_p02_invalidas.sql:140: NOTICE:  OK    [G02-P02-I-06] 0 consumos en S, 0 movimientos de EL-002 -> 0 consumos, 0 movimientos
                 verificar                  
--------------------------------------------
 OK G02-P02-I-06: 0 consumos, 0 movimientos
(1 row)

-- ===========================================================
-- ID: G02-P02-I-07     Criterio: AC-G02-P02-03
-- Acción: completar S, que no tiene ninguna participación.
-- Esperado: rechazo "sin participación técnica cerrada"; S sigue En proceso.
-- ===========================================================
SELECT pruebas.esperar_rechazo('G02-P02-I-07', 'AC-G02-P02-03', 'completar sin participación',
     $q$ SELECT fn_completar_labor(pruebas.labor_id(9003, 'Sustitución del sensor'), 203, '2026-11-05 11:20') $q$,
     'sin participación técnica cerrada');
psql:pruebas/21_p02_invalidas.sql:149: NOTICE:  OK    [G02-P02-I-07] rechazo esperado -> P0001: G02-P02: no se puede completar la labor 516 sin participación técnica cerrada
                                            esperar_rechazo                                            
-------------------------------------------------------------------------------------------------------
 OK G02-P02-I-07: P0001: G02-P02: no se puede completar la labor 516 sin participación técnica cerrada
(1 row)

SELECT pruebas.verificar('G02-P02-I-07', 'AC-G02-P02-03', 'S sigue En proceso',
     (SELECT estado_labor = 'En proceso' FROM labor WHERE labor_id = pruebas.labor_id(9003, 'Sustitución del sensor')),
     'En proceso', (SELECT estado_labor FROM labor WHERE labor_id = pruebas.labor_id(9003, 'Sustitución del sensor')));
psql:pruebas/21_p02_invalidas.sql:152: NOTICE:  OK    [G02-P02-I-07] En proceso -> En proceso
          verificar          
-----------------------------
 OK G02-P02-I-07: En proceso
(1 row)

-- ===========================================================
-- ID: G02-P02-I-08     Criterio: AC-G02-P02-01
-- Acción: participación, prueba y consumo sobre K (no está En proceso).
-- Esperado: rechazo "no está En proceso".
-- ===========================================================
SELECT pruebas.esperar_rechazo('G02-P02-I-08', 'AC-G02-P02-01', 'participación en labor no iniciada',
     $q$ SELECT fn_registrar_participacion(pruebas.labor_id(9003, 'Limpieza de inyectores'), 202,
                '2026-11-05 11:00', '2026-11-05 11:30', 30, 'Sin autorización') $q$,
     'no está En proceso');
psql:pruebas/21_p02_invalidas.sql:162: NOTICE:  OK    [G02-P02-I-08] rechazo esperado -> P0001: G02-P02: la labor 519 no está En proceso (estado: Pendiente)
                                   esperar_rechazo                                    
--------------------------------------------------------------------------------------
 OK G02-P02-I-08: P0001: G02-P02: la labor 519 no está En proceso (estado: Pendiente)
(1 row)

SELECT pruebas.esperar_rechazo('G02-P02-I-08', 'AC-G02-P02-01', 'prueba en labor no iniciada',
     $q$ SELECT fn_registrar_prueba(pruebas.labor_id(9003, 'Limpieza de inyectores'), 202, '2026-11-05 11:00',
                'Prueba', 'Favorable', 'Sin autorización') $q$,
     'no está En proceso');
psql:pruebas/21_p02_invalidas.sql:166: NOTICE:  OK    [G02-P02-I-08] rechazo esperado -> P0001: G02-P02: la labor 519 no está En proceso (estado: Pendiente)
                                   esperar_rechazo                                    
--------------------------------------------------------------------------------------
 OK G02-P02-I-08: P0001: G02-P02: la labor 519 no está En proceso (estado: Pendiente)
(1 row)

SELECT pruebas.esperar_rechazo('G02-P02-I-08', 'AC-G02-P02-01', 'consumo en labor no iniciada',
     $q$ SELECT fn_registrar_consumo(9003, pruebas.labor_id(9003, 'Limpieza de inyectores'), 'MG-002', 1, 7200, 202, '2026-11-05 11:00') $q$,
     'no está En proceso');
psql:pruebas/21_p02_invalidas.sql:169: NOTICE:  OK    [G02-P02-I-08] rechazo esperado -> P0001: G02-P02: la labor 519 no está En proceso (estado: Pendiente)
                                   esperar_rechazo                                    
--------------------------------------------------------------------------------------
 OK G02-P02-I-08: P0001: G02-P02: la labor 519 no está En proceso (estado: Pendiente)
(1 row)

-- ===========================================================
-- ID: G02-P02-I-09     Criterio: AC-G02-P02-02
-- Acción: minutos efectivos mayores que el intervalo (61 en 60 min) y un
--   técnico en dos intervenciones superpuestas.
-- Esperado: rechazo por ck_participacion_minutos y por
--   ex_participacion_tecnico.
-- ===========================================================
SELECT pruebas.esperar_rechazo('G02-P02-I-09', 'AC-G02-P02-02', 'efectivos > intervalo',
     $q$ SELECT fn_registrar_participacion(pruebas.labor_id(9003, 'Sustitución del sensor'), 203,
                '2026-11-05 11:00', '2026-11-05 12:00', 61, 'Minutos inflados', 3) $q$,
     'ck_participacion_minutos');
psql:pruebas/21_p02_invalidas.sql:181: NOTICE:  OK    [G02-P02-I-09] rechazo esperado -> 23514: new row for relation "participacion_tecnica" violates check constraint "ck_participacion_minutos"
                                                      esperar_rechazo                                                      
---------------------------------------------------------------------------------------------------------------------------
 OK G02-P02-I-09: 23514: new row for relation "participacion_tecnica" violates check constraint "ck_participacion_minutos"
(1 row)

SELECT pruebas.esperar_rechazo('G02-P02-I-09', 'AC-G02-P02-02', 'técnico en dos intervenciones a la vez',
     $q$ DO $b$ BEGIN
            PERFORM fn_registrar_participacion(pruebas.labor_id(9003, 'Sustitución del sensor'), 203,
                    '2026-11-05 11:00', '2026-11-05 12:00', 50, 'Cambio del sensor', 3);
            PERFORM fn_registrar_participacion(pruebas.labor_id(9003, 'Sustitución del sensor'), 203,
                    '2026-11-05 11:30', '2026-11-05 11:45', 15, 'Superpuesta', 3);
         END $b$ $q$,
     'ex_participacion_tecnico');
psql:pruebas/21_p02_invalidas.sql:189: NOTICE:  OK    [G02-P02-I-09] rechazo esperado -> 23P01: conflicting key value violates exclusion constraint "ex_participacion_tecnico"
                                            esperar_rechazo                                             
--------------------------------------------------------------------------------------------------------
 OK G02-P02-I-09: 23P01: conflicting key value violates exclusion constraint "ex_participacion_tecnico"
(1 row)

-- ===========================================================
-- ID: G02-P02-I-10     Criterio: AC-G02-P02-03
-- Acción: reescribir la historia: UPDATE del estado o la descripción de una
--   labor, DELETE de una labor, UPDATE de una prueba, DELETE de un consumo,
--   UPDATE de una participación cerrada.
-- Esperado: todos rechazados (RN-15: revisar sin borrar).
-- ===========================================================
SELECT pruebas.esperar_rechazo('G02-P02-I-10', 'AC-G02-P02-03', 'UPDATE directo del estado de una labor',
     $q$ UPDATE labor SET estado_labor = 'Completada' WHERE labor_id = pruebas.labor_id(9003, 'Sustitución del sensor') $q$,
     'solo cambia mediante historial_labor');
psql:pruebas/21_p02_invalidas.sql:200: NOTICE:  OK    [G02-P02-I-10] rechazo esperado -> P0001: G02-P02: el estado de la labor 516 solo cambia mediante historial_labor
                                         esperar_rechazo                                         
-------------------------------------------------------------------------------------------------
 OK G02-P02-I-10: P0001: G02-P02: el estado de la labor 516 solo cambia mediante historial_labor
(1 row)

SELECT pruebas.esperar_rechazo('G02-P02-I-10', 'AC-G02-P02-03', 'UPDATE de la descripción de una labor',
     $q$ UPDATE labor SET descripcion = 'Otra cosa' WHERE labor_id = pruebas.labor_id(9003, 'Cambio de pastillas') $q$,
     'no se reescribe');
psql:pruebas/21_p02_invalidas.sql:203: NOTICE:  OK    [G02-P02-I-10] rechazo esperado -> P0001: G02-INM: la labor 515 no se reescribe; registre un retrabajo o una labor nueva (RN-15)
                                                esperar_rechazo                                                 
----------------------------------------------------------------------------------------------------------------
 OK G02-P02-I-10: P0001: G02-INM: la labor 515 no se reescribe; registre un retrabajo o una labor nueva (RN-15)
(1 row)

SELECT pruebas.esperar_rechazo('G02-P02-I-10', 'AC-G02-P02-03', 'DELETE de una labor',
     $q$ DELETE FROM labor WHERE labor_id = pruebas.labor_id(9003, 'Limpieza de inyectores') $q$,
     'no se elimina');
psql:pruebas/21_p02_invalidas.sql:206: NOTICE:  OK    [G02-P02-I-10] rechazo esperado -> P0001: G02-INM: la labor 519 no se elimina; anúlela con motivo
                                 esperar_rechazo                                 
---------------------------------------------------------------------------------
 OK G02-P02-I-10: P0001: G02-INM: la labor 519 no se elimina; anúlela con motivo
(1 row)

SELECT pruebas.esperar_rechazo('G02-P02-I-10', 'AC-G02-P02-03', 'UPDATE del resultado de una prueba',
     $q$ UPDATE prueba SET resultado = 'Favorable' WHERE resultado = 'Desfavorable' AND orden_id = 9003 $q$,
     'solo inserción');
psql:pruebas/21_p02_invalidas.sql:209: NOTICE:  OK    [G02-P02-I-10] rechazo esperado -> P0001: G02-INM: prueba es de solo inserción; no se permite UPDATE (registre una fila nueva)
                                               esperar_rechazo                                                
--------------------------------------------------------------------------------------------------------------
 OK G02-P02-I-10: P0001: G02-INM: prueba es de solo inserción; no se permite UPDATE (registre una fila nueva)
(1 row)

SELECT pruebas.esperar_rechazo('G02-P02-I-10', 'AC-G02-P02-04', 'DELETE de un consumo',
     $q$ DELETE FROM consumo_repuesto WHERE orden_id = 9003 $q$,
     'solo inserción');
psql:pruebas/21_p02_invalidas.sql:212: NOTICE:  OK    [G02-P02-I-10] rechazo esperado -> P0001: G02-INM: consumo_repuesto es de solo inserción; no se permite DELETE (registre una fila nueva)
                                                    esperar_rechazo                                                     
------------------------------------------------------------------------------------------------------------------------
 OK G02-P02-I-10: P0001: G02-INM: consumo_repuesto es de solo inserción; no se permite DELETE (registre una fila nueva)
(1 row)

SELECT pruebas.esperar_rechazo('G02-P02-I-10', 'AC-G02-P02-02', 'UPDATE de una participación cerrada',
     $q$ UPDATE participacion_tecnica SET minutos_efectivos = 10 WHERE labor_id = pruebas.labor_id(9003, 'Cambio de pastillas') $q$,
     'solo admite su cierre');
psql:pruebas/21_p02_invalidas.sql:215: NOTICE:  OK    [G02-P02-I-10] rechazo esperado -> P0001: G02-INM: la participación 1 solo admite su cierre (fin y minutos), una vez
                                          esperar_rechazo                                           
----------------------------------------------------------------------------------------------------
 OK G02-P02-I-10: P0001: G02-INM: la participación 1 solo admite su cierre (fin y minutos), una vez
(1 row)

-- ===========================================================
-- ID: G02-P02-I-11     Criterio: AC-G02-P02-03
-- Acción: retrabajo originado en una prueba Favorable; retrabajo citando
--   una prueba de OTRA labor; prueba con valor sin unidad; resultado fuera
--   de dominio.
-- Esperado: rechazos con causa visible.
-- ===========================================================
SELECT pruebas.esperar_rechazo('G02-P02-I-11', 'AC-G02-P02-03', 'retrabajo desde prueba Favorable',
     $q$ SELECT fn_registrar_retrabajo(pruebas.labor_id(9003, 'Rectificado'),
            (SELECT prueba_id FROM prueba WHERE labor_id = pruebas.labor_id(9003, 'Rectificado')),
            'Retrabajo injustificado', 205, '2026-11-05 11:30') $q$,
     'solo se origina en una prueba Desfavorable');
psql:pruebas/21_p02_invalidas.sql:228: NOTICE:  OK    [G02-P02-I-11] rechazo esperado -> P0001: G02-P02: un retrabajo solo se origina en una prueba Desfavorable (la prueba 2 es Favorable)
                                                   esperar_rechazo                                                   
---------------------------------------------------------------------------------------------------------------------
 OK G02-P02-I-11: P0001: G02-P02: un retrabajo solo se origina en una prueba Desfavorable (la prueba 2 es Favorable)
(1 row)

SELECT pruebas.esperar_rechazo('G02-P02-I-11', 'AC-G02-P02-03', 'retrabajo con prueba de otra labor',
     $q$ SELECT fn_registrar_retrabajo(pruebas.labor_id(9003, 'Purga'),
            (SELECT prueba_id FROM prueba WHERE labor_id = pruebas.labor_id(9003, 'Cambio de pastillas')),
            'Retrabajo cruzado', 205, '2026-11-05 11:30') $q$,
     'no es de la labor');
psql:pruebas/21_p02_invalidas.sql:233: NOTICE:  OK    [G02-P02-I-11] rechazo esperado -> P0001: G02-P02: la prueba 1 no es de la labor 517
                          esperar_rechazo                           
--------------------------------------------------------------------
 OK G02-P02-I-11: P0001: G02-P02: la prueba 1 no es de la labor 517
(1 row)

SELECT pruebas.esperar_rechazo('G02-P02-I-11', 'AC-G02-P02-03', 'medición sin unidad',
     $q$ SELECT fn_registrar_prueba(pruebas.labor_id(9003, 'Sustitución del sensor'), 203, '2026-11-05 11:40',
                'Lectura del sensor', 'Favorable', 'Lectura estable', 0.45, NULL) $q$,
     'ck_prueba_medicion');
psql:pruebas/21_p02_invalidas.sql:237: NOTICE:  OK    [G02-P02-I-11] rechazo esperado -> 23514: new row for relation "prueba" violates check constraint "ck_prueba_medicion"
                                           esperar_rechazo                                            
------------------------------------------------------------------------------------------------------
 OK G02-P02-I-11: 23514: new row for relation "prueba" violates check constraint "ck_prueba_medicion"
(1 row)

SELECT pruebas.esperar_rechazo('G02-P02-I-11', 'AC-G02-P02-03', 'resultado fuera de dominio',
     $q$ SELECT fn_registrar_prueba(pruebas.labor_id(9003, 'Sustitución del sensor'), 203, '2026-11-05 11:40',
                'Lectura del sensor', 'Excelente', 'Lectura estable') $q$,
     'ck_prueba_resultado');
psql:pruebas/21_p02_invalidas.sql:241: NOTICE:  OK    [G02-P02-I-11] rechazo esperado -> 23514: new row for relation "prueba" violates check constraint "ck_prueba_resultado"
                                            esperar_rechazo                                            
-------------------------------------------------------------------------------------------------------
 OK G02-P02-I-11: 23514: new row for relation "prueba" violates check constraint "ck_prueba_resultado"
(1 row)

SELECT pruebas.verificar('G02-P02-I-11', 'AC-G02-P02-03', 'S sigue En proceso sin pruebas ni participaciones',
     (SELECT estado_labor = 'En proceso' FROM labor WHERE labor_id = pruebas.labor_id(9003, 'Sustitución del sensor'))
     AND (SELECT count(*) = 0 FROM prueba WHERE labor_id = pruebas.labor_id(9003, 'Sustitución del sensor'))
     AND (SELECT count(*) = 0 FROM participacion_tecnica WHERE labor_id = pruebas.labor_id(9003, 'Sustitución del sensor')),
     'En proceso, 0 pruebas, 0 participaciones',
     (SELECT estado_labor FROM labor WHERE labor_id = pruebas.labor_id(9003, 'Sustitución del sensor')) || ', '
     || (SELECT count(*) FROM prueba WHERE labor_id = pruebas.labor_id(9003, 'Sustitución del sensor')) || ' pruebas, '
     || (SELECT count(*) FROM participacion_tecnica WHERE labor_id = pruebas.labor_id(9003, 'Sustitución del sensor')) || ' participaciones');
psql:pruebas/21_p02_invalidas.sql:249: NOTICE:  OK    [G02-P02-I-11] En proceso, 0 pruebas, 0 participaciones -> En proceso, 0 pruebas, 0 participaciones
                         verificar                         
-----------------------------------------------------------
 OK G02-P02-I-11: En proceso, 0 pruebas, 0 participaciones
(1 row)

-- =====================================================================
-- G02-P02 · Ejecutar reparaciones y pruebas · LÍMITE
-- =====================================================================
SET search_path = taller, public;
SET
SET TIME ZONE 'America/Costa_Rica';
SET
-- ===========================================================
-- ID: G02-P02-L-01     Criterio: AC-G02-P02-03, AC-G02-P02-04
-- Preparación: W (freno de mano) de 9003, aceptada y sin repuestos.
-- Acción: ejecutarla sin consumir repuestos y con una prueba SOLO
--   descriptiva (sin valor ni unidad); completarla.
-- Esperado: válido: W Completada, 0 consumos, prueba sin medición.
-- ===========================================================
SELECT fn_iniciar_labor(pruebas.labor_id(9003, 'Ajuste de freno de mano'), 204, '2026-11-05 12:30');
 fn_iniciar_labor 
------------------
               35
(1 row)

SELECT fn_registrar_participacion(pruebas.labor_id(9003, 'Ajuste de freno de mano'), 204,
       '2026-11-05 12:30', '2026-11-05 13:00', 25, 'Ajuste de cable y palanca', 4);
 fn_registrar_participacion 
----------------------------
                         15
(1 row)

SELECT fn_registrar_prueba(pruebas.labor_id(9003, 'Ajuste de freno de mano'), 204, '2026-11-05 13:05',
       'Prueba en pendiente', 'Favorable', 'El vehículo se sostiene en la rampa con 4 clics de palanca');
 fn_registrar_prueba 
---------------------
                   7
(1 row)

SELECT fn_completar_labor(pruebas.labor_id(9003, 'Ajuste de freno de mano'), 204, '2026-11-05 13:10');
 fn_completar_labor 
--------------------
                 36
(1 row)

SELECT pruebas.verificar('G02-P02-L-01', 'AC-G02-P02-03', 'labor sin repuestos y prueba descriptiva',
     (SELECT estado_labor = 'Completada' FROM labor WHERE labor_id = pruebas.labor_id(9003, 'Ajuste de freno de mano'))
     AND (SELECT count(*) = 0 FROM consumo_repuesto WHERE labor_id = pruebas.labor_id(9003, 'Ajuste de freno de mano'))
     AND (SELECT medicion_valor IS NULL AND unidad IS NULL FROM prueba WHERE labor_id = pruebas.labor_id(9003, 'Ajuste de freno de mano')),
     'Completada, 0 consumos, prueba sin medición',
     (SELECT estado_labor FROM labor WHERE labor_id = pruebas.labor_id(9003, 'Ajuste de freno de mano')) || ', '
     || (SELECT count(*) FROM consumo_repuesto WHERE labor_id = pruebas.labor_id(9003, 'Ajuste de freno de mano')) || ' consumos, medición '
     || coalesce((SELECT medicion_valor::text FROM prueba WHERE labor_id = pruebas.labor_id(9003, 'Ajuste de freno de mano')), 'NULL'));
psql:pruebas/22_p02_limite.sql:27: NOTICE:  OK    [G02-P02-L-01] Completada, 0 consumos, prueba sin medición -> Completada, 0 consumos, medición NULL
                       verificar                        
--------------------------------------------------------
 OK G02-P02-L-01: Completada, 0 consumos, medición NULL
(1 row)

-- ===========================================================
-- ID: G02-P02-L-02     Criterio: AC-G02-P02-01
-- Preparación: orden 9004 (Mensajería): hallazgo CRÍTICO 4108 (fuga de
--   frenos) y una v1 con "Cambio de bujes" SIN decisión del cliente.
-- Acción: registrar una emergencia justificada que crea la labor MÍNIMA y
--   su excepción; ejecutarla de punta a punta. Luego intentar iniciar la
--   labor pendiente de la misma propuesta.
-- Esperado: la emergencia habilita SOLO su labor (se inicia citando su
--   emergencia_id); los bujes se rechazan (situación Sin decidir); la
--   propuesta no cambia (1 línea).
-- ===========================================================
SELECT fn_cambiar_estado_orden(9004, 'En diagnóstico', 202, NULL, '2026-11-05 07:45');
 fn_cambiar_estado_orden 
-------------------------
                      27
(1 row)

SELECT fn_publicar_propuesta(9004, NULL,
  '[{"descripcion":"Cambio de bujes de suspensión","hallazgo_id":4109,"precio_estimado":35000}]'::jsonb,
  205, 'Pendiente de respuesta del cliente', '2026-11-05 08:45');
 fn_publicar_propuesta 
-----------------------
                   320
(1 row)

SELECT fn_registrar_emergencia(9004, 4108,
       'Reparación mínima de la fuga en el cilindro de rueda trasero izquierdo',
       'Vehículo sin capacidad de frenado; riesgo de accidente al moverlo',
       'El cliente no responde y el vehículo debe salir del área de recepción; solo se detiene la fuga',
       'Sustituir el cilindro de rueda y purgar ese circuito; nada más', 205, '2026-11-05 09:00');
 fn_registrar_emergencia 
-------------------------
                     524
(1 row)

SELECT fn_iniciar_labor(pruebas.labor_id(9004, 'Reparación mínima'), 202, '2026-11-05 09:05');
 fn_iniciar_labor 
------------------
               39
(1 row)

SELECT fn_registrar_participacion(pruebas.labor_id(9004, 'Reparación mínima'), 202,
       '2026-11-05 09:05', '2026-11-05 10:05', 50, 'Cambio de cilindro y purga', 1);
 fn_registrar_participacion 
----------------------------
                         16
(1 row)

SELECT fn_registrar_consumo(9004, pruebas.labor_id(9004, 'Reparación mínima'), 'FR-002', 1, 6500, 202, '2026-11-05 09:30');
 fn_registrar_consumo 
----------------------
                    6
(1 row)

SELECT fn_registrar_prueba(pruebas.labor_id(9004, 'Reparación mínima'), 202, '2026-11-05 10:10',
       'Prueba de pedal', 'Favorable', 'Pedal firme, sin fuga visible');
 fn_registrar_prueba 
---------------------
                   8
(1 row)

SELECT fn_completar_labor(pruebas.labor_id(9004, 'Reparación mínima'), 202, '2026-11-05 10:20');
 fn_completar_labor 
--------------------
                 40
(1 row)

SELECT * FROM v_historia_labor WHERE orden_id = 9004 ORDER BY labor_id, secuencia;
 orden_id | labor_id |                                 labor                                  | secuencia | estado_anterior | estado_nuevo |       fecha_hora       | registrado_por | autorizacion_id | emergencia_id |        motivo        
----------+----------+------------------------------------------------------------------------+-----------+-----------------+--------------+------------------------+----------------+-----------------+---------------+----------------------
     9004 |      523 | Cambio de bujes de suspensión                                          |         1 |                 | Pendiente    | 2026-11-05 08:45:00-06 | Marta León     |                 |               | Registro de la labor
     9004 |      524 | Reparación mínima de la fuga en el cilindro de rueda trasero izquierdo |         1 |                 | Pendiente    | 2026-11-05 09:00:00-06 | Marta León     |                 |               | Registro de la labor
     9004 |      524 | Reparación mínima de la fuga en el cilindro de rueda trasero izquierdo |         2 | Pendiente       | En proceso   | 2026-11-05 09:05:00-06 | Diego Mora     |                 |             1 | 
     9004 |      524 | Reparación mínima de la fuga en el cilindro de rueda trasero izquierdo |         3 | En proceso      | Completada   | 2026-11-05 10:20:00-06 | Diego Mora     |                 |               | 
(4 rows)

SELECT pruebas.verificar('G02-P02-L-02', 'AC-G02-P02-01', 'la emergencia habilitó su labor citando la excepción',
     (SELECT h.emergencia_id IS NOT NULL AND h.autorizacion_id IS NULL FROM historial_labor h
      WHERE h.labor_id = pruebas.labor_id(9004, 'Reparación mínima') AND h.estado_nuevo = 'En proceso')
     AND (SELECT estado_labor = 'Completada' FROM labor WHERE labor_id = pruebas.labor_id(9004, 'Reparación mínima')),
     'inicio con emergencia_id, labor Completada',
     (SELECT 'emergencia_id ' || h.emergencia_id || ', ' || l.estado_labor FROM historial_labor h JOIN labor l USING (labor_id)
      WHERE h.labor_id = pruebas.labor_id(9004, 'Reparación mínima') AND h.estado_nuevo = 'En proceso'));
psql:pruebas/22_p02_limite.sql:64: NOTICE:  OK    [G02-P02-L-02] inicio con emergencia_id, labor Completada -> emergencia_id 1, Completada
                  verificar                   
----------------------------------------------
 OK G02-P02-L-02: emergencia_id 1, Completada
(1 row)

SELECT pruebas.esperar_rechazo('G02-P02-L-02', 'AC-G02-P02-01', 'la emergencia NO habilita otra labor de la propuesta',
     $q$ SELECT fn_iniciar_labor(pruebas.labor_id(9004, 'Cambio de bujes'), 204, '2026-11-05 10:30') $q$,
     'situación: Sin decidir');
psql:pruebas/22_p02_limite.sql:67: NOTICE:  OK    [G02-P02-L-02] rechazo esperado -> P0001: G02-P02: la labor 523 no tiene autorización aplicable Aceptada ni excepción de emergencia (situación: Sin decidir)
                                                              esperar_rechazo                                                               
--------------------------------------------------------------------------------------------------------------------------------------------
 OK G02-P02-L-02: P0001: G02-P02: la labor 523 no tiene autorización aplicable Aceptada ni excepción de emergencia (situación: Sin decidir)
(1 row)

SELECT pruebas.esperar_rechazo('G02-P02-L-02', 'AC-G02-P02-01', 'INSERT directo citando la emergencia en otra labor',
     $q$ INSERT INTO historial_labor (labor_id, estado_nuevo, fecha_hora, personal_id, emergencia_id)
         SELECT pruebas.labor_id(9004, 'Cambio de bujes'), 'En proceso', '2026-11-05 10:30', 204, emergencia_id
         FROM excepcion_emergencia WHERE orden_id = 9004 $q$,
     'no es de emergencia');
psql:pruebas/22_p02_limite.sql:72: NOTICE:  OK    [G02-P02-L-02] rechazo esperado -> P0001: G02-P02: la labor 523 no es de emergencia
                          esperar_rechazo                          
-------------------------------------------------------------------
 OK G02-P02-L-02: P0001: G02-P02: la labor 523 no es de emergencia
(1 row)

-- Defensa en profundidad: sin el trigger, la FK compuesta
-- (emergencia_id, labor_id) impide usar la excepción en otra labor.
SELECT pruebas.esperar_rechazo('G02-P02-L-02', 'AC-G02-P02-01', 'misma inserción solo contra la FK compuesta',
     $q$ DO $b$ BEGIN
            ALTER TABLE historial_labor DISABLE TRIGGER trg_historial_labor_antes;
            INSERT INTO historial_labor (labor_id, secuencia, estado_anterior, estado_nuevo, fecha_hora, personal_id, emergencia_id)
            SELECT pruebas.labor_id(9004, 'Cambio de bujes'), 2, 'Pendiente', 'En proceso', '2026-11-05 10:30', 204, emergencia_id
            FROM excepcion_emergencia WHERE orden_id = 9004;
         END $b$ $q$,
     'fk_historial_labor_emergencia');
psql:pruebas/22_p02_limite.sql:82: NOTICE:  OK    [G02-P02-L-02] rechazo esperado -> 23503: insert or update on table "historial_labor" violates foreign key constraint "fk_historial_labor_emergencia"
                                                           esperar_rechazo                                                           
-------------------------------------------------------------------------------------------------------------------------------------
 OK G02-P02-L-02: 23503: insert or update on table "historial_labor" violates foreign key constraint "fk_historial_labor_emergencia"
(1 row)

SELECT pruebas.esperar_rechazo('G02-P02-L-02', 'AC-G02-P02-01', 'excepción de emergencia sobre una labor no marcada como emergencia',
     $q$ INSERT INTO excepcion_emergencia (labor_id, orden_id, riesgo, justificacion, alcance_minimo, autorizada_por_id, fecha_hora)
         VALUES (pruebas.labor_id(9004, 'Cambio de bujes'), 9004, 'Ruido', 'Justificación suficientemente larga', 'Bujes', 205, '2026-11-05 10:30') $q$,
     'no está marcada como emergencia');
psql:pruebas/22_p02_limite.sql:86: NOTICE:  OK    [G02-P02-L-02] rechazo esperado -> P0001: G02-P02: la labor 523 no está marcada como emergencia; no admite excepción
                                          esperar_rechazo                                           
----------------------------------------------------------------------------------------------------
 OK G02-P02-L-02: P0001: G02-P02: la labor 523 no está marcada como emergencia; no admite excepción
(1 row)

SELECT pruebas.esperar_rechazo('G02-P02-L-02', 'AC-G02-P02-01', 'emergencia con justificación insuficiente',
     $q$ SELECT fn_registrar_emergencia(9004, 4109, 'Bujes urgentes', 'Ruido', 'Porque sí', 'Cambiar bujes', 205, '2026-11-05 10:30') $q$,
     'ck_emergencia_justificacion');
psql:pruebas/22_p02_limite.sql:89: NOTICE:  OK    [G02-P02-L-02] rechazo esperado -> 23514: new row for relation "excepcion_emergencia" violates check constraint "ck_emergencia_justificacion"
                                                       esperar_rechazo                                                       
-----------------------------------------------------------------------------------------------------------------------------
 OK G02-P02-L-02: 23514: new row for relation "excepcion_emergencia" violates check constraint "ck_emergencia_justificacion"
(1 row)

SELECT pruebas.verificar('G02-P02-L-02', 'AC-G02-P02-01', 'la propuesta y las demás labores no cambiaron',
     (SELECT count(*) = 1 FROM linea_propuesta WHERE orden_id = 9004)
     AND (SELECT count(*) = 2 FROM labor WHERE orden_id = 9004)
     AND (SELECT estado_labor = 'Pendiente' FROM labor WHERE labor_id = pruebas.labor_id(9004, 'Cambio de bujes')),
     '1 línea, 2 labores, bujes Pendiente',
     (SELECT count(*) FROM linea_propuesta WHERE orden_id = 9004) || ' línea, '
     || (SELECT count(*) FROM labor WHERE orden_id = 9004) || ' labores, bujes '
     || (SELECT estado_labor FROM labor WHERE labor_id = pruebas.labor_id(9004, 'Cambio de bujes')));
psql:pruebas/22_p02_limite.sql:97: NOTICE:  OK    [G02-P02-L-02] 1 línea, 2 labores, bujes Pendiente -> 1 línea, 2 labores, bujes Pendiente
                      verificar                       
------------------------------------------------------
 OK G02-P02-L-02: 1 línea, 2 labores, bujes Pendiente
(1 row)

-- ===========================================================
-- ID: G02-P02-L-03     Criterio: AC-G02-P02-02
-- Preparación: S (sensor) de 9003 En proceso.
-- Acción: participación de Sofía con intervalo de 120 min y 75 efectivos;
--   otra con intervalo de 120 y exactamente 120 efectivos (borde).
-- Esperado: ambas válidas.
-- ===========================================================
SELECT fn_registrar_participacion(pruebas.labor_id(9003, 'Sustitución del sensor'), 203,
       '2026-11-05 13:00', '2026-11-05 15:00', 75, 'Diagnóstico eléctrico con pausas por espera de repuesto', 3);
 fn_registrar_participacion 
----------------------------
                         17
(1 row)

SELECT fn_registrar_participacion(pruebas.labor_id(9003, 'Sustitución del sensor'), 203,
       '2026-11-05 15:00', '2026-11-05 17:00', 120, 'Montaje y calibración sin pausas', 3);
 fn_registrar_participacion 
----------------------------
                         18
(1 row)

SELECT pruebas.verificar('G02-P02-L-03', 'AC-G02-P02-02', 'intervalo 120 / efectivos 75 y 120 / 120',
     (SELECT string_agg(minutos_efectivos || '/' || minutos_intervalo, ',' ORDER BY participacion_id) = '75/120,120/120'
      FROM v_participaciones WHERE labor_id = pruebas.labor_id(9003, 'Sustitución del sensor')),
     '75/120,120/120',
     (SELECT string_agg(minutos_efectivos || '/' || minutos_intervalo, ',' ORDER BY participacion_id)
      FROM v_participaciones WHERE labor_id = pruebas.labor_id(9003, 'Sustitución del sensor')));
psql:pruebas/22_p02_limite.sql:115: NOTICE:  OK    [G02-P02-L-03] 75/120,120/120 -> 75/120,120/120
            verificar            
---------------------------------
 OK G02-P02-L-03: 75/120,120/120
(1 row)

-- ===========================================================
-- ID: G02-P02-L-04     Criterio: AC-G02-P02-02, AC-G02-P02-03
-- Acción: participación ABIERTA de Andrés en S; intentar completar S;
--   cerrarla; consumir el sensor; registrar la prueba; completar S. Luego
--   U (que dependía de S) ya puede iniciarse.
-- Esperado: completar con participación abierta se rechaza; tras cerrarla
--   se completa; U inicia porque su dependencia ya está Completada.
-- ===========================================================
SELECT fn_registrar_participacion(pruebas.labor_id(9003, 'Sustitución del sensor'), 204,
       '2026-11-05 17:00', NULL, NULL, 'Revisión de cableado (en curso)', 4);
 fn_registrar_participacion 
----------------------------
                         19
(1 row)

SELECT pruebas.esperar_rechazo('G02-P02-L-04', 'AC-G02-P02-03', 'completar con una participación abierta',
     $q$ SELECT fn_completar_labor(pruebas.labor_id(9003, 'Sustitución del sensor'), 203, '2026-11-05 17:10') $q$,
     'tiene participaciones abiertas');
psql:pruebas/22_p02_limite.sql:129: NOTICE:  OK    [G02-P02-L-04] rechazo esperado -> P0001: G02-P02: la labor 516 tiene participaciones abiertas
                               esperar_rechazo                                
------------------------------------------------------------------------------
 OK G02-P02-L-04: P0001: G02-P02: la labor 516 tiene participaciones abiertas
(1 row)

SELECT fn_cerrar_participacion((SELECT participacion_id FROM participacion_tecnica
                                WHERE labor_id = pruebas.labor_id(9003, 'Sustitución del sensor') AND fin IS NULL),
                               '2026-11-05 17:30', 25);
 fn_cerrar_participacion 
-------------------------
 
(1 row)

SELECT fn_registrar_consumo(9003, pruebas.labor_id(9003, 'Sustitución del sensor'), 'EL-001', 1, 41000, 203, '2026-11-05 15:30');
 fn_registrar_consumo 
----------------------
                    7
(1 row)

SELECT fn_registrar_prueba(pruebas.labor_id(9003, 'Sustitución del sensor'), 203, '2026-11-05 17:35',
       'Lectura del sensor con escáner', 'Favorable', 'Señal oscilando entre 0,1 y 0,9 V', 0.45, 'V');
 fn_registrar_prueba 
---------------------
                   9
(1 row)

SELECT fn_completar_labor(pruebas.labor_id(9003, 'Sustitución del sensor'), 203, '2026-11-05 17:40');
 fn_completar_labor 
--------------------
                 45
(1 row)

SELECT fn_iniciar_labor(pruebas.labor_id(9003, 'Borrado de códigos'), 203, '2026-11-05 17:45');
 fn_iniciar_labor 
------------------
               46
(1 row)

SELECT pruebas.verificar('G02-P02-L-04', 'AC-G02-P02-01', 'S Completada y U iniciada tras cumplir su dependencia',
     (SELECT estado_labor = 'Completada' FROM labor WHERE labor_id = pruebas.labor_id(9003, 'Sustitución del sensor'))
     AND (SELECT estado_labor = 'En proceso' FROM labor WHERE labor_id = pruebas.labor_id(9003, 'Borrado de códigos')),
     'S Completada; U En proceso',
     'S ' || (SELECT estado_labor FROM labor WHERE labor_id = pruebas.labor_id(9003, 'Sustitución del sensor'))
     || '; U ' || (SELECT estado_labor FROM labor WHERE labor_id = pruebas.labor_id(9003, 'Borrado de códigos')));
psql:pruebas/22_p02_limite.sql:143: NOTICE:  OK    [G02-P02-L-04] S Completada; U En proceso -> S Completada; U En proceso
                  verificar                  
---------------------------------------------
 OK G02-P02-L-04: S Completada; U En proceso
(1 row)

-- ===========================================================
-- ID: G02-P02-L-05     Criterio: AC-G02-P02-01
-- Acción: suspender U sin motivo (rechazo), suspenderla con motivo y
--   reanudarla.
-- Esperado: al reanudar se vuelve a exigir y registrar el habilitante (la
--   misma autorización aplicable); la historia conserva la suspensión.
-- ===========================================================
SELECT pruebas.esperar_rechazo('G02-P02-L-05', 'AC-G02-P02-01', 'suspender sin motivo',
     $q$ SELECT fn_suspender_labor(pruebas.labor_id(9003, 'Borrado de códigos'), 203, NULL, '2026-11-05 17:50') $q$,
     'requiere motivo');
psql:pruebas/22_p02_limite.sql:154: NOTICE:  OK    [G02-P02-L-05] rechazo esperado -> P0001: G02-P02: pasar la labor 518 a Suspendida requiere motivo
                                 esperar_rechazo                                  
----------------------------------------------------------------------------------
 OK G02-P02-L-05: P0001: G02-P02: pasar la labor 518 a Suspendida requiere motivo
(1 row)

SELECT fn_suspender_labor(pruebas.labor_id(9003, 'Borrado de códigos'), 203, 'Falta el equipo analizador de gases', '2026-11-05 17:50');
 fn_suspender_labor 
--------------------
                 48
(1 row)

SELECT fn_iniciar_labor(pruebas.labor_id(9003, 'Borrado de códigos'), 203, '2026-11-06 08:00');
 fn_iniciar_labor 
------------------
               49
(1 row)

SELECT * FROM v_historia_labor WHERE labor_id = pruebas.labor_id(9003, 'Borrado de códigos') ORDER BY secuencia;
 orden_id | labor_id |                  labor                   | secuencia | estado_anterior | estado_nuevo |       fecha_hora       | registrado_por | autorizacion_id | emergencia_id |               motivo                
----------+----------+------------------------------------------+-----------+-----------------+--------------+------------------------+----------------+-----------------+---------------+-------------------------------------
     9003 |      518 | Borrado de códigos y prueba de emisiones |         1 |                 | Pendiente    | 2026-11-04 10:00:00-06 | Marta León     |                 |               | Registro de la labor
     9003 |      518 | Borrado de códigos y prueba de emisiones |         2 | Pendiente       | En proceso   | 2026-11-05 17:45:00-06 | Sofía Arias    |             625 |               | 
     9003 |      518 | Borrado de códigos y prueba de emisiones |         3 | En proceso      | Suspendida   | 2026-11-05 17:50:00-06 | Sofía Arias    |                 |               | Falta el equipo analizador de gases
     9003 |      518 | Borrado de códigos y prueba de emisiones |         4 | Suspendida      | En proceso   | 2026-11-06 08:00:00-06 | Sofía Arias    |             625 |               | 
(4 rows)

SELECT pruebas.verificar('G02-P02-L-05', 'AC-G02-P02-01', 'suspensión y reanudación con habilitante',
     (SELECT string_agg(estado_nuevo, ' -> ' ORDER BY secuencia) = 'Pendiente -> En proceso -> Suspendida -> En proceso'
      FROM historial_labor WHERE labor_id = pruebas.labor_id(9003, 'Borrado de códigos'))
     AND (SELECT count(*) = 2 FROM historial_labor WHERE labor_id = pruebas.labor_id(9003, 'Borrado de códigos') AND autorizacion_id IS NOT NULL),
     'Pendiente -> En proceso -> Suspendida -> En proceso (2 inicios con autorización)',
     (SELECT string_agg(estado_nuevo, ' -> ' ORDER BY secuencia) FROM historial_labor WHERE labor_id = pruebas.labor_id(9003, 'Borrado de códigos')));
psql:pruebas/22_p02_limite.sql:163: NOTICE:  OK    [G02-P02-L-05] Pendiente -> En proceso -> Suspendida -> En proceso (2 inicios con autorización) -> Pendiente -> En proceso -> Suspendida -> En proceso
                              verificar                               
----------------------------------------------------------------------
 OK G02-P02-L-05: Pendiente -> En proceso -> Suspendida -> En proceso
(1 row)

-- =====================================================================
-- G02-P02 · ATOMICIDAD
-- Preparación: U (borrado de códigos, 9003) En proceso.
-- =====================================================================
SET search_path = taller, public;
SET
SET TIME ZONE 'America/Costa_Rica';
SET
SELECT repuesto_id, fisico, reservado, disponible FROM v_existencias WHERE repuesto_id IN ('MG-002', 'EL-002') ORDER BY 1;
 repuesto_id | fisico | reservado | disponible 
-------------+--------+-----------+------------
 EL-002      |      0 |         0 |          0
 MG-002      |  20.00 |         0 |      20.00
(2 rows)

-- ===========================================================
-- ID: G02-P02-A-01     Criterio: AC-G02-P02-04
-- Acción: en UN bloque: participación válida, consumo válido de 2 L de
--   aceite, consumo de una batería SIN existencias y completar la labor.
-- Esperado: rechazo por existencias y NADA queda: ni participación, ni
--   consumo de aceite, ni movimientos, ni labor completada.
-- ===========================================================
SELECT pruebas.esperar_rechazo('G02-P02-A-01', 'AC-G02-P02-04', 'bloque con consumo sin existencias a mitad',
     $q$ DO $b$ BEGIN
            PERFORM fn_registrar_participacion(pruebas.labor_id(9003, 'Borrado de códigos'), 203,
                    '2026-11-06 08:00', '2026-11-06 08:30', 30, 'Borrado de códigos', 3);
            PERFORM fn_registrar_consumo(9003, pruebas.labor_id(9003, 'Borrado de códigos'), 'MG-002', 2, 7200, 203, '2026-11-06 08:10');
            PERFORM fn_registrar_consumo(9003, pruebas.labor_id(9003, 'Borrado de códigos'), 'EL-002', 1, 52000, 203, '2026-11-06 08:20');
            PERFORM fn_completar_labor(pruebas.labor_id(9003, 'Borrado de códigos'), 203, '2026-11-06 08:40');
         END $b$ $q$,
     'existencias insuficientes de EL-002');
psql:pruebas/23_p02_atomicidad.sql:25: NOTICE:  OK    [G02-P02-A-01] rechazo esperado -> P0001: G02-INT: existencias insuficientes de EL-002: el movimiento dejaría -1.00 físicas
                                              esperar_rechazo                                              
-----------------------------------------------------------------------------------------------------------
 OK G02-P02-A-01: P0001: G02-INT: existencias insuficientes de EL-002: el movimiento dejaría -1.00 físicas
(1 row)

SELECT pruebas.verificar('G02-P02-A-01', 'AC-G02-P02-04', 'ni labor completada ni consumo huérfano',
     (SELECT estado_labor = 'En proceso' FROM labor WHERE labor_id = pruebas.labor_id(9003, 'Borrado de códigos'))
     AND (SELECT count(*) = 0 FROM consumo_repuesto WHERE labor_id = pruebas.labor_id(9003, 'Borrado de códigos'))
     AND (SELECT count(*) = 0 FROM participacion_tecnica WHERE labor_id = pruebas.labor_id(9003, 'Borrado de códigos'))
     AND (SELECT fisico = 20 FROM v_existencias WHERE repuesto_id = 'MG-002'),
     'U En proceso, 0 consumos, 0 participaciones, MG-002 físico 20',
     (SELECT estado_labor FROM labor WHERE labor_id = pruebas.labor_id(9003, 'Borrado de códigos')) || ', '
     || (SELECT count(*) FROM consumo_repuesto WHERE labor_id = pruebas.labor_id(9003, 'Borrado de códigos')) || ' consumos, '
     || (SELECT count(*) FROM participacion_tecnica WHERE labor_id = pruebas.labor_id(9003, 'Borrado de códigos')) || ' participaciones, MG-002 '
     || (SELECT fisico FROM v_existencias WHERE repuesto_id = 'MG-002'));
psql:pruebas/23_p02_atomicidad.sql:35: NOTICE:  OK    [G02-P02-A-01] U En proceso, 0 consumos, 0 participaciones, MG-002 físico 20 -> En proceso, 0 consumos, 0 participaciones, MG-002 20.00
                                verificar                                 
--------------------------------------------------------------------------
 OK G02-P02-A-01: En proceso, 0 consumos, 0 participaciones, MG-002 20.00
(1 row)

-- ===========================================================
-- ID: G02-P02-A-02     Criterio: AC-G02-P02-03
-- Acción: en UN bloque: participación cerrada, prueba Desfavorable y
--   completar (no hay retrabajo).
-- Esperado: rechazo "es Desfavorable y no tiene retrabajo completado"; la
--   participación y la prueba del bloque tampoco quedan.
-- ===========================================================
SELECT pruebas.esperar_rechazo('G02-P02-A-02', 'AC-G02-P02-03', 'completar con última prueba Desfavorable',
     $q$ DO $b$ BEGIN
            PERFORM fn_registrar_participacion(pruebas.labor_id(9003, 'Borrado de códigos'), 203,
                    '2026-11-06 08:00', '2026-11-06 08:30', 30, 'Borrado de códigos', 3);
            PERFORM fn_registrar_prueba(pruebas.labor_id(9003, 'Borrado de códigos'), 203, '2026-11-06 08:35',
                    'Prueba de emisiones', 'Desfavorable', 'CO por encima del límite', 1.8, '%');
            PERFORM fn_completar_labor(pruebas.labor_id(9003, 'Borrado de códigos'), 203, '2026-11-06 08:40');
         END $b$ $q$,
     'es Desfavorable y no tiene retrabajo completado');
psql:pruebas/23_p02_atomicidad.sql:52: NOTICE:  OK    [G02-P02-A-02] rechazo esperado -> P0001: G02-P02: la última prueba (10) de la labor 518 es Desfavorable y no tiene retrabajo completado
                                                    esperar_rechazo                                                     
------------------------------------------------------------------------------------------------------------------------
 OK G02-P02-A-02: P0001: G02-P02: la última prueba (10) de la labor 518 es Desfavorable y no tiene retrabajo completado
(1 row)

SELECT pruebas.verificar('G02-P02-A-02', 'AC-G02-P02-03', 'nada quedó del bloque',
     (SELECT count(*) = 0 FROM prueba WHERE labor_id = pruebas.labor_id(9003, 'Borrado de códigos'))
     AND (SELECT count(*) = 0 FROM participacion_tecnica WHERE labor_id = pruebas.labor_id(9003, 'Borrado de códigos')),
     '0 pruebas, 0 participaciones en U',
     (SELECT count(*) FROM prueba WHERE labor_id = pruebas.labor_id(9003, 'Borrado de códigos')) || ' pruebas, '
     || (SELECT count(*) FROM participacion_tecnica WHERE labor_id = pruebas.labor_id(9003, 'Borrado de códigos')) || ' participaciones');
psql:pruebas/23_p02_atomicidad.sql:58: NOTICE:  OK    [G02-P02-A-02] 0 pruebas, 0 participaciones en U -> 0 pruebas, 0 participaciones
                   verificar                   
-----------------------------------------------
 OK G02-P02-A-02: 0 pruebas, 0 participaciones
(1 row)

-- ===========================================================
-- ID: G02-P02-A-03     Criterio: AC-G02-P02-04
-- Acción: saltarse la rutina: (a) INSERT de un consumo sin su movimiento
--   (se fuerzan las restricciones diferidas como al COMMIT); (b) movimiento
--   'Consumo' sin consumo de origen; (c) movimiento de Consumo por una
--   cantidad distinta a la del consumo.
-- Esperado: (a) "no tiene su movimiento de inventario"; (b) "requiere el
--   consumo de origen" (trigger) y, sin el trigger, el CHECK
--   ck_movimiento_consumo_origen; (c) "no coincide con la cantidad".
-- ===========================================================
SELECT pruebas.esperar_rechazo('G02-P02-A-03', 'AC-G02-P02-04', 'consumo sin movimiento (al COMMIT)',
     $q$ DO $b$ BEGIN
            INSERT INTO consumo_repuesto (labor_id, orden_id, repuesto_id, cantidad_utilizada, precio_unitario_cargado, fecha_hora, registrado_por_id)
            VALUES (pruebas.labor_id(9003, 'Borrado de códigos'), 9003, 'MG-002', 1, 7200, '2026-11-06 08:10', 203);
            SET CONSTRAINTS ALL IMMEDIATE;
         END $b$ $q$,
     'no tiene su movimiento de inventario');
psql:pruebas/23_p02_atomicidad.sql:76: NOTICE:  OK    [G02-P02-A-03] rechazo esperado -> P0001: G02-P02: el consumo 10 no tiene su movimiento de inventario de Consumo
                                        esperar_rechazo                                         
------------------------------------------------------------------------------------------------
 OK G02-P02-A-03: P0001: G02-P02: el consumo 10 no tiene su movimiento de inventario de Consumo
(1 row)

SELECT pruebas.esperar_rechazo('G02-P02-A-03', 'AC-G02-P02-04', 'movimiento Consumo sin origen',
     $q$ INSERT INTO movimiento_inventario (repuesto_id, orden_id, tipo_movimiento, cantidad, registrado_por_id)
         VALUES ('MG-002', 9003, 'Consumo', 1, 203) $q$,
     'requiere el consumo de origen');
psql:pruebas/23_p02_atomicidad.sql:80: NOTICE:  OK    [G02-P02-A-03] rechazo esperado -> P0001: G02-INT: un movimiento de Consumo requiere el consumo de origen (consumo_id), D11
                                              esperar_rechazo                                              
-----------------------------------------------------------------------------------------------------------
 OK G02-P02-A-03: P0001: G02-INT: un movimiento de Consumo requiere el consumo de origen (consumo_id), D11
(1 row)

SELECT pruebas.esperar_rechazo('G02-P02-A-03', 'AC-G02-P02-04', 'movimiento Consumo sin origen (solo contra el CHECK)',
     $q$ DO $b$ BEGIN
            ALTER TABLE movimiento_inventario DISABLE TRIGGER trg_movimiento_validar;
            INSERT INTO movimiento_inventario (repuesto_id, orden_id, tipo_movimiento, cantidad, registrado_por_id)
            VALUES ('MG-002', 9003, 'Consumo', 1, 203);
         END $b$ $q$,
     'ck_movimiento_consumo_origen');
psql:pruebas/23_p02_atomicidad.sql:87: NOTICE:  OK    [G02-P02-A-03] rechazo esperado -> 23514: new row for relation "movimiento_inventario" violates check constraint "ck_movimiento_consumo_origen"
                                                        esperar_rechazo                                                        
-------------------------------------------------------------------------------------------------------------------------------
 OK G02-P02-A-03: 23514: new row for relation "movimiento_inventario" violates check constraint "ck_movimiento_consumo_origen"
(1 row)

SELECT pruebas.esperar_rechazo('G02-P02-A-03', 'AC-G02-P02-04', 'movimiento con cantidad distinta a la del consumo',
     $q$ DO $b$ DECLARE v bigint; BEGIN
            INSERT INTO consumo_repuesto (labor_id, orden_id, repuesto_id, cantidad_utilizada, precio_unitario_cargado, fecha_hora, registrado_por_id)
            VALUES (pruebas.labor_id(9003, 'Borrado de códigos'), 9003, 'MG-002', 1, 7200, '2026-11-06 08:10', 203)
            RETURNING consumo_id INTO v;
            INSERT INTO movimiento_inventario (repuesto_id, orden_id, tipo_movimiento, cantidad, consumo_id, registrado_por_id)
            VALUES ('MG-002', 9003, 'Consumo', 3, v, 203);
         END $b$ $q$,
     'no coincide con la cantidad');
psql:pruebas/23_p02_atomicidad.sql:96: NOTICE:  OK    [G02-P02-A-03] rechazo esperado -> P0001: G02-INT: el movimiento de Consumo (3.00) no coincide con la cantidad del consumo 11 (1.00)
                                                  esperar_rechazo                                                   
--------------------------------------------------------------------------------------------------------------------
 OK G02-P02-A-03: P0001: G02-INT: el movimiento de Consumo (3.00) no coincide con la cantidad del consumo 11 (1.00)
(1 row)

SELECT pruebas.verificar('G02-P02-A-03', 'AC-G02-P02-04', 'todo consumo tiene exactamente su movimiento',
     NOT EXISTS (SELECT 1 FROM consumo_repuesto c
                 WHERE NOT EXISTS (SELECT 1 FROM movimiento_inventario m WHERE m.consumo_id = c.consumo_id))
     AND NOT EXISTS (SELECT 1 FROM movimiento_inventario WHERE tipo_movimiento = 'Consumo' AND consumo_id IS NULL),
     '0 consumos sin movimiento y 0 movimientos de consumo sin origen',
     (SELECT count(*) FROM consumo_repuesto) || ' consumos, '
     || (SELECT count(*) FROM movimiento_inventario WHERE tipo_movimiento = 'Consumo') || ' movimientos de consumo');
psql:pruebas/23_p02_atomicidad.sql:103: NOTICE:  OK    [G02-P02-A-03] 0 consumos sin movimiento y 0 movimientos de consumo sin origen -> 4 consumos, 4 movimientos de consumo
                       verificar                       
-------------------------------------------------------
 OK G02-P02-A-03: 4 consumos, 4 movimientos de consumo
(1 row)

-- Cierre válido de U para dejar la orden coherente.
SELECT fn_registrar_participacion(pruebas.labor_id(9003, 'Borrado de códigos'), 203,
       '2026-11-06 08:00', '2026-11-06 08:30', 30, 'Borrado de códigos y prueba', 3);
 fn_registrar_participacion 
----------------------------
                         22
(1 row)

SELECT fn_registrar_prueba(pruebas.labor_id(9003, 'Borrado de códigos'), 203, '2026-11-06 08:35',
       'Prueba de emisiones', 'Favorable', 'Valores dentro de norma', 0.3, '%');
 fn_registrar_prueba 
---------------------
                  11
(1 row)

SELECT fn_completar_labor(pruebas.labor_id(9003, 'Borrado de códigos'), 203, '2026-11-06 08:40');
 fn_completar_labor 
--------------------
                 51
(1 row)

SELECT labor_id, descripcion, estado_labor FROM labor WHERE orden_id = 9003 ORDER BY labor_id;
 labor_id |                 descripcion                  | estado_labor 
----------+----------------------------------------------+--------------
      515 | Cambio de pastillas y revisión de discos     | Completada
      516 | Sustitución del sensor de oxígeno            | Completada
      517 | Purga del sistema de frenos                  | Completada
      518 | Borrado de códigos y prueba de emisiones     | Completada
      519 | Limpieza de inyectores                       | Pendiente
      520 | Ajuste de freno de mano                      | Completada
      521 | Rectificado de discos delanteros (retrabajo) | Completada
(7 rows)

```
