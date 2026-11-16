# Salida de las pruebas · P01

> Generado ejecutando de verdad, el 2026-11-16 04:07 UTC, en una base nueva (`taller_ruta27`).
>
> Comando: `psql -X -a -d taller_ruta27 -v ON_ERROR_STOP=1 -f pruebas/10_p01_validas.sql -f pruebas/11_p01_invalidas.sql -f pruebas/12_p01_limite.sql -f pruebas/13_p01_atomicidad.sql`

```text
-- =====================================================================
-- G02-P01 · Versionar propuestas y autorizar labores · VÁLIDAS
-- Orden: 9001 (María Rojas, titular con facultad Aprobar; Honda ABC123).
-- Hallazgos de preparación: 4101 pastillas, 4102 escobillas,
--   4106 alineación, 4107 líquido de frenos.
-- =====================================================================
SET search_path = taller, public;
SET
SET TIME ZONE 'America/Costa_Rica';
SET
-- ===========================================================
-- ID: G02-P01-V-01     Criterio: AC-G02-P01-01
-- Preparación: orden 9001 en diagnóstico (sin propuestas).
-- Acción: publicar la versión 1 con 3 labores nuevas (A, B, C) y sus
--   repuestos estimados, en una transacción confirmada.
-- Esperado: propuesta v1 Presentada con 3 líneas; 3 labores Pendiente.
-- ===========================================================
SELECT fn_cambiar_estado_orden(9001, 'En diagnóstico', 202, NULL, '2026-11-02 08:45');
 fn_cambiar_estado_orden 
-------------------------
                      12
(1 row)

BEGIN;
BEGIN
SELECT fn_publicar_propuesta(9001, NULL,
  '[{"clave":"A","descripcion":"Cambio de pastillas delanteras","hallazgo_id":4101,"precio_estimado":45000,
     "alcance":"Desmontar, sustituir pastillas y probar frenado",
     "repuestos":[{"repuesto_id":"FR-001","cantidad":1,"precio_unitario":25000}]},
    {"clave":"B","descripcion":"Cambio de escobillas","hallazgo_id":4102,"precio_estimado":5000,
     "alcance":"Sustituir ambas escobillas",
     "repuestos":[{"repuesto_id":"LP-001","cantidad":1,"precio_unitario":8500}]},
    {"clave":"C","descripcion":"Alineación y balanceo","hallazgo_id":4106,"precio_estimado":30000,
     "alcance":"Alinear eje delantero y balancear 4 llantas"}]'::jsonb,
  205, 'Versión inicial del presupuesto', '2026-11-02 11:00');
 fn_publicar_propuesta 
-----------------------
                   301
(1 row)

COMMIT;
COMMIT
SELECT fn_cambiar_estado_orden(9001, 'Pendiente autorización', 201, NULL, '2026-11-02 11:05');
 fn_cambiar_estado_orden 
-------------------------
                      13
(1 row)

SELECT pruebas.verificar('G02-P01-V-01', 'AC-G02-P01-01', 'v1 presentada con 3 líneas',
     (SELECT p.estado = 'Presentada' AND p.version = 1 AND (SELECT count(*) FROM linea_propuesta WHERE propuesta_id = p.propuesta_id) = 3
      FROM propuesta p WHERE p.orden_id = 9001 AND p.version = 1),
     'v1 Presentada, 3 líneas',
     (SELECT 'v' || version || ' ' || estado || ', ' || (SELECT count(*) FROM linea_propuesta WHERE propuesta_id = p.propuesta_id) || ' líneas'
      FROM propuesta p WHERE orden_id = 9001 AND version = 1));
psql:pruebas/10_p01_validas.sql:38: NOTICE:  OK    [G02-P01-V-01] v1 Presentada, 3 líneas -> v1 Presentada, 3 líneas
                verificar                 
------------------------------------------
 OK G02-P01-V-01: v1 Presentada, 3 líneas
(1 row)

-- ===========================================================
-- ID: G02-P01-V-02     Criterio: AC-G02-P01-02, AC-G02-P01-04
-- Preparación: v1 presentada.
-- Acción: María acepta A, rechaza B y deja C PENDIENTE de forma explícita
--   ("lo consultará"), todo por teléfono.
-- Esperado: 3 filas en autorizacion_labor, cada una con cliente, facultad,
--   medio y fecha; situación aplicable A=Aceptada, B=Rechazada,
--   C=Pendiente; solo A es ejecutable.
-- ===========================================================
SELECT fn_registrar_decision(pruebas.propuesta_id(9001, 1), pruebas.labor_id(9001, 'Cambio de pastillas'),
                             101, 'Aceptada',  'Teléfono', 201, '2026-11-02 11:30');
 fn_registrar_decision 
-----------------------
                   601
(1 row)

SELECT fn_registrar_decision(pruebas.propuesta_id(9001, 1), pruebas.labor_id(9001, 'Cambio de escobillas'),
                             101, 'Rechazada', 'Teléfono', 201, '2026-11-02 11:31', 'Las cambiará por su cuenta');
 fn_registrar_decision 
-----------------------
                   602
(1 row)

SELECT fn_registrar_decision(pruebas.propuesta_id(9001, 1), pruebas.labor_id(9001, 'Alineación'),
                             101, 'Pendiente', 'Teléfono', 201, '2026-11-02 11:32', 'Lo consultará; precio alto');
 fn_registrar_decision 
-----------------------
                   603
(1 row)

SELECT fn_cambiar_estado_orden(9001, 'Autorizada', 201, NULL, '2026-11-02 11:40');
 fn_cambiar_estado_orden 
-------------------------
                      14
(1 row)

SELECT labor_id, descripcion, version_vigente, situacion, decidido_por, medio_decision, fecha_hora_decision, autorizacion_id
FROM v_situacion_labor WHERE orden_id = 9001 ORDER BY labor_id;
 labor_id |          descripcion           | version_vigente | situacion | decidido_por | medio_decision |  fecha_hora_decision   | autorizacion_id 
----------+--------------------------------+-----------------+-----------+--------------+----------------+------------------------+-----------------
      501 | Cambio de pastillas delanteras |               1 | Aceptada  | María Rojas  | Teléfono       | 2026-11-02 11:30:00-06 |             601
      502 | Cambio de escobillas           |               1 | Rechazada | María Rojas  | Teléfono       | 2026-11-02 11:31:00-06 |             602
      503 | Alineación y balanceo          |               1 | Pendiente | María Rojas  | Teléfono       | 2026-11-02 11:32:00-06 |             603
(3 rows)

SELECT pruebas.verificar('G02-P01-V-02', 'AC-G02-P01-02', 'decisiones con actor, facultad, medio y fecha',
     (SELECT count(*) = 3 AND bool_and(cliente_id = 101 AND facultad_id IS NOT NULL AND medio = 'Teléfono')
      FROM autorizacion_labor WHERE orden_id = 9001),
     '3 decisiones de María por teléfono con facultad',
     (SELECT count(*) || ' decisiones: ' || string_agg(decision, ', ' ORDER BY autorizacion_id) FROM autorizacion_labor WHERE orden_id = 9001));
psql:pruebas/10_p01_validas.sql:64: NOTICE:  OK    [G02-P01-V-02] 3 decisiones de María por teléfono con facultad -> 3 decisiones: Aceptada, Rechazada, Pendiente
                           verificar                           
---------------------------------------------------------------
 OK G02-P01-V-02: 3 decisiones: Aceptada, Rechazada, Pendiente
(1 row)

SELECT pruebas.verificar('G02-P01-V-02', 'AC-G02-P01-04', 'solo A es ejecutable',
     (SELECT array_agg(labor_id) = ARRAY[pruebas.labor_id(9001, 'Cambio de pastillas')] FROM v_autorizacion_ejecutable WHERE orden_id = 9001),
     'ejecutables: {A}',
     (SELECT 'ejecutables: ' || coalesce(array_agg(labor_id)::text, '{}') FROM v_autorizacion_ejecutable WHERE orden_id = 9001));
psql:pruebas/10_p01_validas.sql:68: NOTICE:  OK    [G02-P01-V-02] ejecutables: {A} -> ejecutables: {501}
              verificar              
-------------------------------------
 OK G02-P01-V-02: ejecutables: {501}
(1 row)

-- ===========================================================
-- ID: G02-P01-V-03     Criterio: AC-G02-P01-01
-- Preparación: v1 con A aceptada, B rechazada, C pendiente.
-- Acción: emitir v2 como AMPLIACIÓN que solo añade la labor D (líquido de
--   frenos, hallazgo 4107); María acepta D.
-- Esperado: A, B y C conservan v1 como versión vigente y su decisión;
--   D vigente en v2 y Aceptada.
-- ===========================================================
SELECT fn_cambiar_estado_orden(9001, 'Pendiente autorización', 201, 'Ampliación por hallazgo de líquido de frenos', '2026-11-02 14:55');
 fn_cambiar_estado_orden 
-------------------------
                      15
(1 row)

SELECT fn_publicar_propuesta(9001, pruebas.propuesta_id(9001, 1),
  '[{"descripcion":"Purga y cambio de líquido de frenos","hallazgo_id":4107,"precio_estimado":18000,
     "alcance":"Purgar circuito y reponer DOT 4",
     "repuestos":[{"repuesto_id":"FR-002","cantidad":1,"precio_unitario":6500}]}]'::jsonb,
  205, 'Ampliación: líquido de frenos', '2026-11-02 15:00');
 fn_publicar_propuesta 
-----------------------
                   302
(1 row)

SELECT fn_registrar_decision(pruebas.propuesta_id(9001, 2), pruebas.labor_id(9001, 'Purga y cambio'),
                             101, 'Aceptada', 'Mensaje', 201, '2026-11-02 15:30');
 fn_registrar_decision 
-----------------------
                   604
(1 row)

SELECT fn_cambiar_estado_orden(9001, 'Autorizada', 201, NULL, '2026-11-02 15:35');
 fn_cambiar_estado_orden 
-------------------------
                      16
(1 row)

SELECT pruebas.verificar('G02-P01-V-03', 'AC-G02-P01-01', 'la ampliación no toca A, B y C',
     (SELECT string_agg(descripcion || '=v' || version_vigente || ':' || situacion, ', ' ORDER BY labor_id)
      FROM v_situacion_labor WHERE orden_id = 9001)
     = 'Cambio de pastillas delanteras=v1:Aceptada, Cambio de escobillas=v1:Rechazada, Alineación y balanceo=v1:Pendiente, Purga y cambio de líquido de frenos=v2:Aceptada',
     'A=v1:Aceptada, B=v1:Rechazada, C=v1:Pendiente, D=v2:Aceptada',
     (SELECT string_agg(descripcion || '=v' || version_vigente || ':' || situacion, ', ' ORDER BY labor_id)
      FROM v_situacion_labor WHERE orden_id = 9001));
psql:pruebas/10_p01_validas.sql:94: NOTICE:  OK    [G02-P01-V-03] A=v1:Aceptada, B=v1:Rechazada, C=v1:Pendiente, D=v2:Aceptada -> Cambio de pastillas delanteras=v1:Aceptada, Cambio de escobillas=v1:Rechazada, Alineación y balanceo=v1:Pendiente, Purga y cambio de líquido de frenos=v2:Aceptada
                                                                                      verificar                                                                                      
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 OK G02-P01-V-03: Cambio de pastillas delanteras=v1:Aceptada, Cambio de escobillas=v1:Rechazada, Alineación y balanceo=v1:Pendiente, Purga y cambio de líquido de frenos=v2:Aceptada
(1 row)

-- ===========================================================
-- ID: G02-P01-V-04     Criterio: AC-G02-P01-01, AC-G02-P01-04
-- Preparación: C pendiente en v1.
-- Acción: emitir v3 que solo CAMBIA EL PRECIO de C (30000 -> 25000); en
--   una consulta intermedia C queda "Sin decidir" en v3 (la decisión de v1
--   NO se arrastra); luego María acepta C sobre v3. Transacción con COMMIT.
-- Esperado: v1 intacta (C sigue a 30000 y Pendiente EN v1); C vigente en
--   v3 a 25000 y Aceptada.
-- ===========================================================
BEGIN;
BEGIN
SELECT fn_cambiar_estado_orden(9001, 'Pendiente autorización', 201, 'Nuevo precio de alineación', '2026-11-03 07:55');
 fn_cambiar_estado_orden 
-------------------------
                      17
(1 row)

SELECT fn_publicar_propuesta(9001, pruebas.propuesta_id(9001, 2),
  ('[{"labor_id":' || pruebas.labor_id(9001, 'Alineación') || ',"precio_estimado":25000,
      "alcance":"Alinear eje delantero y balancear 4 llantas (precio con descuento)"}]')::jsonb,
  205, 'Descuento en alineación', '2026-11-03 08:00');
 fn_publicar_propuesta 
-----------------------
                   303
(1 row)

SELECT labor_id, version_vigente, situacion FROM v_situacion_labor WHERE labor_id = pruebas.labor_id(9001, 'Alineación');
 labor_id | version_vigente |  situacion  
----------+-----------------+-------------
      503 |               3 | Sin decidir
(1 row)

SELECT fn_registrar_decision(pruebas.propuesta_id(9001, 3), pruebas.labor_id(9001, 'Alineación'),
                             101, 'Aceptada', 'Teléfono', 201, '2026-11-03 08:30');
 fn_registrar_decision 
-----------------------
                   605
(1 row)

SELECT fn_cambiar_estado_orden(9001, 'Autorizada', 201, NULL, '2026-11-03 08:35');
 fn_cambiar_estado_orden 
-------------------------
                      18
(1 row)

COMMIT;
COMMIT
-- Lectura posterior (nueva transacción): comparación completa de versiones.
SELECT orden_id, labor, version, precio_estimado, repuestos_estimados, decision_en_esta_version, decidido_por, medio, es_version_vigente
FROM v_comparacion_versiones WHERE orden_id = 9001 ORDER BY labor_id, version;
 orden_id |                labor                | version | precio_estimado | repuestos_estimados | decision_en_esta_version | decidido_por |  medio   | es_version_vigente 
----------+-------------------------------------+---------+-----------------+---------------------+--------------------------+--------------+----------+--------------------
     9001 | Cambio de pastillas delanteras      |       1 |        45000.00 |          25000.0000 | Aceptada                 | María Rojas  | Teléfono | t
     9001 | Cambio de escobillas                |       1 |         5000.00 |           8500.0000 | Rechazada                | María Rojas  | Teléfono | t
     9001 | Alineación y balanceo               |       1 |        30000.00 |                   0 | Pendiente                | María Rojas  | Teléfono | f
     9001 | Alineación y balanceo               |       3 |        25000.00 |                   0 | Aceptada                 | María Rojas  | Teléfono | t
     9001 | Purga y cambio de líquido de frenos |       2 |        18000.00 |           6500.0000 | Aceptada                 | María Rojas  | Mensaje  | t
(5 rows)

SELECT pruebas.verificar('G02-P01-V-04', 'AC-G02-P01-01', 'v1 intacta tras v2 y v3',
     (SELECT string_agg(labor || ':' || precio_estimado || ':' || decision_en_esta_version, ' | ' ORDER BY labor_id)
      FROM v_comparacion_versiones WHERE orden_id = 9001 AND version = 1)
     = 'Cambio de pastillas delanteras:45000.00:Aceptada | Cambio de escobillas:5000.00:Rechazada | Alineación y balanceo:30000.00:Pendiente',
     'v1: A 45000 Aceptada | B 5000 Rechazada | C 30000 Pendiente',
     (SELECT string_agg(labor || ':' || precio_estimado || ':' || decision_en_esta_version, ' | ' ORDER BY labor_id)
      FROM v_comparacion_versiones WHERE orden_id = 9001 AND version = 1));
psql:pruebas/10_p01_validas.sql:127: NOTICE:  OK    [G02-P01-V-04] v1: A 45000 Aceptada | B 5000 Rechazada | C 30000 Pendiente -> Cambio de pastillas delanteras:45000.00:Aceptada | Cambio de escobillas:5000.00:Rechazada | Alineación y balanceo:30000.00:Pendiente
                                                                       verificar                                                                       
-------------------------------------------------------------------------------------------------------------------------------------------------------
 OK G02-P01-V-04: Cambio de pastillas delanteras:45000.00:Aceptada | Cambio de escobillas:5000.00:Rechazada | Alineación y balanceo:30000.00:Pendiente
(1 row)

SELECT pruebas.verificar('G02-P01-V-04', 'AC-G02-P01-04', 'C vigente en v3 a 25000 y Aceptada',
     (SELECT version_vigente = 3 AND precio_vigente = 25000 AND situacion = 'Aceptada'
      FROM v_situacion_labor WHERE labor_id = pruebas.labor_id(9001, 'Alineación')),
     'C: v3, 25000, Aceptada',
     (SELECT 'C: v' || version_vigente || ', ' || precio_vigente || ', ' || situacion
      FROM v_situacion_labor WHERE labor_id = pruebas.labor_id(9001, 'Alineación')));
psql:pruebas/10_p01_validas.sql:133: NOTICE:  OK    [G02-P01-V-04] C: v3, 25000, Aceptada -> C: v3, 25000.00, Aceptada
                 verificar                  
--------------------------------------------
 OK G02-P01-V-04: C: v3, 25000.00, Aceptada
(1 row)

SELECT pruebas.verificar('G02-P01-V-04', 'AC-G02-P01-02', 'ninguna decisión anterior fue sobrescrita',
     (SELECT count(*) = 5 FROM autorizacion_labor WHERE orden_id = 9001)
     AND EXISTS (SELECT 1 FROM autorizacion_labor WHERE orden_id = 9001 AND decision = 'Pendiente'),
     '5 decisiones conservadas (incluida la Pendiente de C en v1)',
     (SELECT count(*) || ' decisiones: ' || string_agg(decision, ', ' ORDER BY autorizacion_id) FROM autorizacion_labor WHERE orden_id = 9001));
psql:pruebas/10_p01_validas.sql:138: NOTICE:  OK    [G02-P01-V-04] 5 decisiones conservadas (incluida la Pendiente de C en v1) -> 5 decisiones: Aceptada, Rechazada, Pendiente, Aceptada, Aceptada
                                     verificar                                     
-----------------------------------------------------------------------------------
 OK G02-P01-V-04: 5 decisiones: Aceptada, Rechazada, Pendiente, Aceptada, Aceptada
(1 row)

-- Contexto válido distinto (preparación de las inválidas): la orden 9002,
-- de Transportes del Valle, con Ana Solís DESIGNADA para aprobar.
SELECT fn_cambiar_estado_orden(9002, 'En diagnóstico', 204, NULL, '2026-11-03 09:30');
 fn_cambiar_estado_orden 
-------------------------
                      19
(1 row)

SELECT fn_publicar_propuesta(9002, NULL,
  '[{"descripcion":"Cambio de filtro de aire","hallazgo_id":4103,"precio_estimado":12000,
     "repuestos":[{"repuesto_id":"MG-001","cantidad":1,"precio_unitario":9000}]}]'::jsonb,
  205, NULL, '2026-11-03 10:30');
 fn_publicar_propuesta 
-----------------------
                   304
(1 row)

SELECT fn_registrar_decision(pruebas.propuesta_id(9002, 1), pruebas.labor_id(9002, 'Cambio de filtro'),
                             104, 'Aceptada', 'Presencial', 201, '2026-11-03 11:00', 'Ana, designada por la empresa');
 fn_registrar_decision 
-----------------------
                   606
(1 row)

SELECT f.facultad_id, f.cliente, f.tipo_facultad, f.fuente, f.otorgada_por_cliente_id, f.vigente_desde
FROM v_facultades_orden f WHERE f.orden_id IN (9001, 9002) AND f.tipo_facultad = 'Aprobar' ORDER BY f.orden_id, f.facultad_id;
 facultad_id |          cliente           | tipo_facultad |   fuente    | otorgada_por_cliente_id |     vigente_desde      
-------------+----------------------------+---------------+-------------+-------------------------+------------------------
           1 | María Rojas                | Aprobar       | Titular     |                         | 2026-11-02 08:15:00-06
           3 | Transportes del Valle S.A. | Aprobar       | Titular     |                         | 2026-11-03 09:10:00-06
           5 | Ana Solís                  | Aprobar       | Designación |                     103 | 2026-11-03 09:10:00-06
(3 rows)

-- =====================================================================
-- G02-P01 · Versionar propuestas y autorizar labores · INVÁLIDAS
-- Dos contextos válidos distintos:
--   9001 — María (101) titular; v1 (A,B,C), v2 (D), v3 (C con precio nuevo)
--   9002 — Transportes (103) titular; Ana (104) designada; v1 (filtro)
-- Tras cada intento se comprueba que NO hay filas nuevas ni cambios.
-- =====================================================================
SET search_path = taller, public;
SET
SET TIME ZONE 'America/Costa_Rica';
SET
-- Línea base para comprobar "sin efectos".
SELECT count(*) AS decisiones_9001 FROM autorizacion_labor WHERE orden_id = 9001;
 decisiones_9001 
-----------------
               5
(1 row)

-- ===========================================================
-- ID: G02-P01-I-01     Criterio: AC-G02-P01-03
-- Preparación: Ana (104) es cliente EXISTENTE y está facultada para
--   aprobar en la orden 9002, pero NO en la 9001. Pedro (108) existe y no
--   tiene facultad en ninguna orden.
-- Acción: Ana y Pedro deciden sobre la labor D de 9001 (v2); además se
--   intenta insertar "a mano" usando la facultad de Ana de la orden 9002.
-- Esperado: rechazo "no tiene facultad vigente para aprobar en la orden
--   9001" (rutina y trigger); y, aun sin el trigger, la FK compuesta de
--   contexto fk_autorizacion_facultad rechaza el INSERT. 0 filas nuevas.
-- ===========================================================
SELECT pruebas.esperar_rechazo('G02-P01-I-01', 'AC-G02-P01-03', 'Ana (facultada en 9002) decide en 9001',
     $q$ SELECT fn_registrar_decision(pruebas.propuesta_id(9001, 2), pruebas.labor_id(9001, 'Purga y cambio'),
                                      104, 'Rechazada', 'Teléfono', 201, '2026-11-03 09:00') $q$,
     'el cliente 104 no tiene facultad vigente para aprobar en la orden 9001');
psql:pruebas/11_p01_invalidas.sql:28: NOTICE:  OK    [G02-P01-I-01] rechazo esperado -> P0001: G02-P01: el cliente 104 no tiene facultad vigente para aprobar en la orden 9001
                                             esperar_rechazo                                             
---------------------------------------------------------------------------------------------------------
 OK G02-P01-I-01: P0001: G02-P01: el cliente 104 no tiene facultad vigente para aprobar en la orden 9001
(1 row)

SELECT pruebas.esperar_rechazo('G02-P01-I-01', 'AC-G02-P01-03', 'Pedro (sin facultad) decide en 9001',
     $q$ SELECT fn_registrar_decision(pruebas.propuesta_id(9001, 2), pruebas.labor_id(9001, 'Purga y cambio'),
                                      108, 'Aceptada', 'Teléfono', 201, '2026-11-03 09:00') $q$,
     'el cliente 108 no tiene facultad vigente');
psql:pruebas/11_p01_invalidas.sql:32: NOTICE:  OK    [G02-P01-I-01] rechazo esperado -> P0001: G02-P01: el cliente 108 no tiene facultad vigente para aprobar en la orden 9001
                                             esperar_rechazo                                             
---------------------------------------------------------------------------------------------------------
 OK G02-P01-I-01: P0001: G02-P01: el cliente 108 no tiene facultad vigente para aprobar en la orden 9001
(1 row)

SELECT pruebas.esperar_rechazo('G02-P01-I-01', 'AC-G02-P01-03', 'INSERT directo con la facultad de Ana en 9002',
     $q$ INSERT INTO autorizacion_labor (propuesta_id, labor_id, orden_id, facultad_id, cliente_id, decision, fecha_hora, medio, registrado_por_id)
         SELECT pruebas.propuesta_id(9001, 2), pruebas.labor_id(9001, 'Purga y cambio'), 9001, f.facultad_id, 104,
                'Rechazada', '2026-11-03 09:00', 'Teléfono', 201
         FROM facultad_orden f WHERE f.orden_id = 9002 AND f.cliente_id = 104 AND f.tipo_facultad = 'Aprobar' $q$,
     'no tiene facultad vigente para aprobar en la orden 9001');
psql:pruebas/11_p01_invalidas.sql:38: NOTICE:  OK    [G02-P01-I-01] rechazo esperado -> P0001: G02-P01: el cliente 104 no tiene facultad vigente para aprobar en la orden 9001
                                             esperar_rechazo                                             
---------------------------------------------------------------------------------------------------------
 OK G02-P01-I-01: P0001: G02-P01: el cliente 104 no tiene facultad vigente para aprobar en la orden 9001
(1 row)

-- Defensa en profundidad: con el trigger DESACTIVADO (solo dentro de la
-- subtransacción de la prueba, que se revierte), la FK compuesta
-- (facultad_id, orden_id) rechaza por sí sola la facultad de otra orden.
SELECT pruebas.esperar_rechazo('G02-P01-I-01', 'AC-G02-P01-03', 'misma inserción solo contra la FK compuesta',
     $q$ DO $b$ BEGIN
            ALTER TABLE autorizacion_labor DISABLE TRIGGER trg_autorizacion_validar;
            INSERT INTO autorizacion_labor (propuesta_id, labor_id, orden_id, facultad_id, cliente_id, decision, fecha_hora, medio, registrado_por_id)
            SELECT pruebas.propuesta_id(9001, 2), pruebas.labor_id(9001, 'Purga y cambio'), 9001, f.facultad_id, 104,
                   'Rechazada', '2026-11-03 09:00', 'Teléfono', 201
            FROM facultad_orden f WHERE f.orden_id = 9002 AND f.cliente_id = 104 AND f.tipo_facultad = 'Aprobar';
         END $b$ $q$,
     'fk_autorizacion_facultad');
psql:pruebas/11_p01_invalidas.sql:50: NOTICE:  OK    [G02-P01-I-01] rechazo esperado -> 23503: insert or update on table "autorizacion_labor" violates foreign key constraint "fk_autorizacion_facultad"
                                                          esperar_rechazo                                                          
-----------------------------------------------------------------------------------------------------------------------------------
 OK G02-P01-I-01: 23503: insert or update on table "autorizacion_labor" violates foreign key constraint "fk_autorizacion_facultad"
(1 row)

SELECT pruebas.esperar_rechazo('G02-P01-I-01', 'AC-G02-P01-03', 'INSERT directo: facultad de María pero cliente Ana',
     $q$ INSERT INTO autorizacion_labor (propuesta_id, labor_id, orden_id, facultad_id, cliente_id, decision, fecha_hora, medio, registrado_por_id)
         SELECT pruebas.propuesta_id(9001, 2), pruebas.labor_id(9001, 'Purga y cambio'), 9001, f.facultad_id, 104,
                'Rechazada', '2026-11-03 09:00', 'Teléfono', 201
         FROM facultad_orden f WHERE f.orden_id = 9001 AND f.cliente_id = 101 AND f.tipo_facultad = 'Aprobar' $q$,
     'no tiene facultad vigente para aprobar');
psql:pruebas/11_p01_invalidas.sql:56: NOTICE:  OK    [G02-P01-I-01] rechazo esperado -> P0001: G02-P01: el cliente 104 no tiene facultad vigente para aprobar en la orden 9001
                                             esperar_rechazo                                             
---------------------------------------------------------------------------------------------------------
 OK G02-P01-I-01: P0001: G02-P01: el cliente 104 no tiene facultad vigente para aprobar en la orden 9001
(1 row)

SELECT pruebas.verificar('G02-P01-I-01', 'AC-G02-P01-03', 'sin decisiones nuevas en 9001 y D sigue Aceptada',
     (SELECT count(*) = 5 FROM autorizacion_labor WHERE orden_id = 9001)
     AND (SELECT situacion = 'Aceptada' FROM v_situacion_labor WHERE labor_id = pruebas.labor_id(9001, 'Purga y cambio')),
     '5 decisiones; D Aceptada',
     (SELECT count(*) FROM autorizacion_labor WHERE orden_id = 9001) || ' decisiones; D '
     || (SELECT situacion FROM v_situacion_labor WHERE labor_id = pruebas.labor_id(9001, 'Purga y cambio')));
psql:pruebas/11_p01_invalidas.sql:62: NOTICE:  OK    [G02-P01-I-01] 5 decisiones; D Aceptada -> 5 decisiones; D Aceptada
                 verificar                 
-------------------------------------------
 OK G02-P01-I-01: 5 decisiones; D Aceptada
(1 row)

-- ===========================================================
-- ID: G02-P01-I-02     Criterio: AC-G02-P01-03
-- Preparación: la labor "Cambio de filtro de aire" pertenece a la 9002.
-- Acción: María decide sobre (propuesta v1 de 9001, labor de 9002), por la
--   rutina y por INSERT directo.
-- Esperado: la rutina y el trigger responden "no forma parte de la
--   propuesta"; aun sin el trigger, la FK compuesta fk_autorizacion_linea
--   rechaza (la labor no tiene línea en esa versión de esa orden). 0 filas.
-- ===========================================================
SELECT pruebas.esperar_rechazo('G02-P01-I-02', 'AC-G02-P01-03', 'decisión sobre labor de otra orden (rutina)',
     $q$ SELECT fn_registrar_decision(pruebas.propuesta_id(9001, 1), pruebas.labor_id(9002, 'Cambio de filtro'),
                                      101, 'Aceptada', 'Teléfono', 201, '2026-11-03 09:00') $q$,
     'no forma parte de la propuesta');
psql:pruebas/11_p01_invalidas.sql:76: NOTICE:  OK    [G02-P01-I-02] rechazo esperado -> P0001: G02-P01: la labor 505 no forma parte de la propuesta 301
                                 esperar_rechazo                                  
----------------------------------------------------------------------------------
 OK G02-P01-I-02: P0001: G02-P01: la labor 505 no forma parte de la propuesta 301
(1 row)

SELECT pruebas.esperar_rechazo('G02-P01-I-02', 'AC-G02-P01-03', 'decisión sobre labor de otra orden (INSERT directo)',
     $q$ INSERT INTO autorizacion_labor (propuesta_id, labor_id, orden_id, facultad_id, cliente_id, decision, fecha_hora, medio, registrado_por_id)
         SELECT pruebas.propuesta_id(9001, 1), pruebas.labor_id(9002, 'Cambio de filtro'), 9001, f.facultad_id, 101,
                'Aceptada', '2026-11-03 09:00', 'Teléfono', 201
         FROM facultad_orden f WHERE f.orden_id = 9001 AND f.cliente_id = 101 AND f.tipo_facultad = 'Aprobar' $q$,
     'no forma parte de la propuesta');
psql:pruebas/11_p01_invalidas.sql:82: NOTICE:  OK    [G02-P01-I-02] rechazo esperado -> P0001: G02-P01: la labor 505 no forma parte de la propuesta 301
                                 esperar_rechazo                                  
----------------------------------------------------------------------------------
 OK G02-P01-I-02: P0001: G02-P01: la labor 505 no forma parte de la propuesta 301
(1 row)

-- Defensa en profundidad: sin el trigger, la FK compuesta
-- (propuesta_id, labor_id, orden_id) -> linea_propuesta rechaza por sí sola.
SELECT pruebas.esperar_rechazo('G02-P01-I-02', 'AC-G02-P01-03', 'misma inserción solo contra la FK compuesta',
     $q$ DO $b$ BEGIN
            ALTER TABLE autorizacion_labor DISABLE TRIGGER trg_autorizacion_validar;
            INSERT INTO autorizacion_labor (propuesta_id, labor_id, orden_id, facultad_id, cliente_id, decision, fecha_hora, medio, registrado_por_id)
            SELECT pruebas.propuesta_id(9001, 1), pruebas.labor_id(9002, 'Cambio de filtro'), 9001, f.facultad_id, 101,
                   'Aceptada', '2026-11-03 09:00', 'Teléfono', 201
            FROM facultad_orden f WHERE f.orden_id = 9001 AND f.cliente_id = 101 AND f.tipo_facultad = 'Aprobar';
         END $b$ $q$,
     'fk_autorizacion_linea');
psql:pruebas/11_p01_invalidas.sql:93: NOTICE:  OK    [G02-P01-I-02] rechazo esperado -> 23503: insert or update on table "autorizacion_labor" violates foreign key constraint "fk_autorizacion_linea"
                                                        esperar_rechazo                                                         
--------------------------------------------------------------------------------------------------------------------------------
 OK G02-P01-I-02: 23503: insert or update on table "autorizacion_labor" violates foreign key constraint "fk_autorizacion_linea"
(1 row)

SELECT pruebas.esperar_rechazo('G02-P01-I-02', 'AC-G02-P01-03', 'publicar en 9001 una línea con labor de 9002',
     $q$ SELECT fn_publicar_propuesta(9001, NULL,
            ('[{"labor_id":' || pruebas.labor_id(9002, 'Cambio de filtro') || ',"precio_estimado":1000}]')::jsonb,
            205, NULL, '2026-11-03 09:00') $q$,
     'no pertenece a la orden 9001');
psql:pruebas/11_p01_invalidas.sql:98: NOTICE:  OK    [G02-P01-I-02] rechazo esperado -> P0001: G02-P01: línea 1: la labor 505 no pertenece a la orden 9001
                                   esperar_rechazo                                   
-------------------------------------------------------------------------------------
 OK G02-P01-I-02: P0001: G02-P01: línea 1: la labor 505 no pertenece a la orden 9001
(1 row)

-- ===========================================================
-- ID: G02-P01-I-03     Criterio: AC-G02-P01-03, AC-G02-P01-04
-- Preparación: la labor D solo existe en la v2 de 9001.
-- Acción: decidir sobre (propuesta v1, labor D).
-- Esperado: rechazo "no forma parte de la propuesta".
-- ===========================================================
SELECT pruebas.esperar_rechazo('G02-P01-I-03', 'AC-G02-P01-03', 'decisión sobre (v1, labor que solo está en v2)',
     $q$ SELECT fn_registrar_decision(pruebas.propuesta_id(9001, 1), pruebas.labor_id(9001, 'Purga y cambio'),
                                      101, 'Rechazada', 'Teléfono', 201, '2026-11-03 09:00') $q$,
     'no forma parte de la propuesta');
psql:pruebas/11_p01_invalidas.sql:109: NOTICE:  OK    [G02-P01-I-03] rechazo esperado -> P0001: G02-P01: la labor 504 no forma parte de la propuesta 301
                                 esperar_rechazo                                  
----------------------------------------------------------------------------------
 OK G02-P01-I-03: P0001: G02-P01: la labor 504 no forma parte de la propuesta 301
(1 row)

-- ===========================================================
-- ID: G02-P01-I-04     Criterio: AC-G02-P01-01, AC-G02-P01-02
-- Acción: UPDATE/DELETE directo sobre una línea presentada, un repuesto
--   estimado, una propuesta presentada y una autorización; INSERT de una
--   línea en una versión ya presentada.
-- Esperado: todos rechazados (inmutabilidad); los precios y decisiones de
--   v1 siguen idénticos.
-- ===========================================================
SELECT pruebas.esperar_rechazo('G02-P01-I-04', 'AC-G02-P01-01', 'UPDATE del precio de una línea presentada',
     $q$ UPDATE linea_propuesta SET precio_estimado = 1 WHERE propuesta_id = pruebas.propuesta_id(9001, 1) $q$,
     'inmutables');
psql:pruebas/11_p01_invalidas.sql:121: NOTICE:  OK    [G02-P01-I-04] rechazo esperado -> P0001: G02-P01: la propuesta 301 ya fue presentada; sus líneas y repuestos son inmutables (UPDATE sobre linea_propuesta)
                                                              esperar_rechazo                                                              
-------------------------------------------------------------------------------------------------------------------------------------------
 OK G02-P01-I-04: P0001: G02-P01: la propuesta 301 ya fue presentada; sus líneas y repuestos son inmutables (UPDATE sobre linea_propuesta)
(1 row)

SELECT pruebas.esperar_rechazo('G02-P01-I-04', 'AC-G02-P01-01', 'DELETE de una línea presentada',
     $q$ DELETE FROM linea_propuesta WHERE propuesta_id = pruebas.propuesta_id(9001, 1) $q$,
     'inmutables');
psql:pruebas/11_p01_invalidas.sql:124: NOTICE:  OK    [G02-P01-I-04] rechazo esperado -> P0001: G02-P01: la propuesta 301 ya fue presentada; sus líneas y repuestos son inmutables (DELETE sobre linea_propuesta)
                                                              esperar_rechazo                                                              
-------------------------------------------------------------------------------------------------------------------------------------------
 OK G02-P01-I-04: P0001: G02-P01: la propuesta 301 ya fue presentada; sus líneas y repuestos son inmutables (DELETE sobre linea_propuesta)
(1 row)

SELECT pruebas.esperar_rechazo('G02-P01-I-04', 'AC-G02-P01-01', 'UPDATE de un repuesto estimado presentado',
     $q$ UPDATE repuesto_propuesto SET cantidad_estimada = 5 WHERE propuesta_id = pruebas.propuesta_id(9001, 1) $q$,
     'inmutables');
psql:pruebas/11_p01_invalidas.sql:127: NOTICE:  OK    [G02-P01-I-04] rechazo esperado -> P0001: G02-P01: la propuesta 301 ya fue presentada; sus líneas y repuestos son inmutables (UPDATE sobre repuesto_propuesto)
                                                               esperar_rechazo                                                                
----------------------------------------------------------------------------------------------------------------------------------------------
 OK G02-P01-I-04: P0001: G02-P01: la propuesta 301 ya fue presentada; sus líneas y repuestos son inmutables (UPDATE sobre repuesto_propuesto)
(1 row)

SELECT pruebas.esperar_rechazo('G02-P01-I-04', 'AC-G02-P01-01', 'INSERT de una línea en v1 ya presentada',
     $q$ INSERT INTO linea_propuesta (propuesta_id, labor_id, orden_id, precio_estimado, alcance)
         VALUES (pruebas.propuesta_id(9001, 1), pruebas.labor_id(9001, 'Purga y cambio'), 9001, 100, 'colada') $q$,
     'inmutables');
psql:pruebas/11_p01_invalidas.sql:131: NOTICE:  OK    [G02-P01-I-04] rechazo esperado -> P0001: G02-P01: la propuesta 301 ya fue presentada; sus líneas y repuestos son inmutables (INSERT sobre linea_propuesta)
                                                              esperar_rechazo                                                              
-------------------------------------------------------------------------------------------------------------------------------------------
 OK G02-P01-I-04: P0001: G02-P01: la propuesta 301 ya fue presentada; sus líneas y repuestos son inmutables (INSERT sobre linea_propuesta)
(1 row)

SELECT pruebas.esperar_rechazo('G02-P01-I-04', 'AC-G02-P01-01', 'UPDATE de la observación de una propuesta presentada',
     $q$ UPDATE propuesta SET observacion = 'reescrita' WHERE propuesta_id = pruebas.propuesta_id(9001, 1) $q$,
     'ya fue presentada y es inmutable');
psql:pruebas/11_p01_invalidas.sql:134: NOTICE:  OK    [G02-P01-I-04] rechazo esperado -> P0001: G02-P01: la propuesta 301 (v1) ya fue presentada y es inmutable
                                     esperar_rechazo                                     
-----------------------------------------------------------------------------------------
 OK G02-P01-I-04: P0001: G02-P01: la propuesta 301 (v1) ya fue presentada y es inmutable
(1 row)

SELECT pruebas.esperar_rechazo('G02-P01-I-04', 'AC-G02-P01-02', 'UPDATE de una autorización (cambiar Rechazada por Aceptada)',
     $q$ UPDATE autorizacion_labor SET decision = 'Aceptada' WHERE orden_id = 9001 AND decision = 'Rechazada' $q$,
     'solo inserción');
psql:pruebas/11_p01_invalidas.sql:137: NOTICE:  OK    [G02-P01-I-04] rechazo esperado -> P0001: G02-INM: autorizacion_labor es de solo inserción; no se permite UPDATE (registre una fila nueva)
                                                     esperar_rechazo                                                      
--------------------------------------------------------------------------------------------------------------------------
 OK G02-P01-I-04: P0001: G02-INM: autorizacion_labor es de solo inserción; no se permite UPDATE (registre una fila nueva)
(1 row)

SELECT pruebas.esperar_rechazo('G02-P01-I-04', 'AC-G02-P01-02', 'DELETE de una autorización',
     $q$ DELETE FROM autorizacion_labor WHERE orden_id = 9001 $q$,
     'solo inserción');
psql:pruebas/11_p01_invalidas.sql:140: NOTICE:  OK    [G02-P01-I-04] rechazo esperado -> P0001: G02-INM: autorizacion_labor es de solo inserción; no se permite DELETE (registre una fila nueva)
                                                     esperar_rechazo                                                      
--------------------------------------------------------------------------------------------------------------------------
 OK G02-P01-I-04: P0001: G02-INM: autorizacion_labor es de solo inserción; no se permite DELETE (registre una fila nueva)
(1 row)

SELECT pruebas.verificar('G02-P01-I-04', 'AC-G02-P01-01', 'v1 sigue idéntica',
     (SELECT string_agg(precio_estimado::text || ':' || decision_en_esta_version, ',' ORDER BY labor_id)
      FROM v_comparacion_versiones WHERE orden_id = 9001 AND version = 1) = '45000.00:Aceptada,5000.00:Rechazada,30000.00:Pendiente',
     '45000 Aceptada, 5000 Rechazada, 30000 Pendiente',
     (SELECT string_agg(precio_estimado::text || ':' || decision_en_esta_version, ',' ORDER BY labor_id)
      FROM v_comparacion_versiones WHERE orden_id = 9001 AND version = 1));
psql:pruebas/11_p01_invalidas.sql:146: NOTICE:  OK    [G02-P01-I-04] 45000 Aceptada, 5000 Rechazada, 30000 Pendiente -> 45000.00:Aceptada,5000.00:Rechazada,30000.00:Pendiente
                                verificar                                
-------------------------------------------------------------------------
 OK G02-P01-I-04: 45000.00:Aceptada,5000.00:Rechazada,30000.00:Pendiente
(1 row)

-- ===========================================================
-- ID: G02-P01-I-05     Criterio: AC-G02-P01-04
-- Preparación: la versión vigente de C es la v3.
-- Acción: registrar una decisión de C sobre la v1 (versión obsoleta).
-- Esperado: rechazo "no es la vigente".
-- ===========================================================
SELECT pruebas.esperar_rechazo('G02-P01-I-05', 'AC-G02-P01-04', 'decidir sobre una versión obsoleta de la labor',
     $q$ SELECT fn_registrar_decision(pruebas.propuesta_id(9001, 1), pruebas.labor_id(9001, 'Alineación'),
                                      101, 'Rechazada', 'Teléfono', 201, '2026-11-03 09:00') $q$,
     'la versión 1 no es la vigente');
psql:pruebas/11_p01_invalidas.sql:157: NOTICE:  OK    [G02-P01-I-05] rechazo esperado -> P0001: G02-P01: la versión 1 no es la vigente para la labor 503; la vigente es la versión 3
                                               esperar_rechazo                                                
--------------------------------------------------------------------------------------------------------------
 OK G02-P01-I-05: P0001: G02-P01: la versión 1 no es la vigente para la labor 503; la vigente es la versión 3
(1 row)

-- ===========================================================
-- ID: G02-P01-I-06     Criterio: AC-G02-P01-02, AC-G02-P01-03
-- Acción: decisiones con datos fuera de dominio o incoherentes en el tiempo.
-- Esperado: rechazos por dominio, por fecha anterior a la presentación y
--   por fecha anterior a la última decisión de la línea.
-- ===========================================================
SELECT pruebas.esperar_rechazo('G02-P01-I-06', 'AC-G02-P01-02', 'decisión fuera de dominio',
     $q$ SELECT fn_registrar_decision(pruebas.propuesta_id(9002, 1), pruebas.labor_id(9002, 'Cambio de filtro'),
                                      103, 'Tal vez', 'Teléfono', 201, '2026-11-03 11:30') $q$,
     'ck_autorizacion_decision');
psql:pruebas/11_p01_invalidas.sql:168: NOTICE:  OK    [G02-P01-I-06] rechazo esperado -> 23514: new row for relation "autorizacion_labor" violates check constraint "ck_autorizacion_decision"
                                                    esperar_rechazo                                                     
------------------------------------------------------------------------------------------------------------------------
 OK G02-P01-I-06: 23514: new row for relation "autorizacion_labor" violates check constraint "ck_autorizacion_decision"
(1 row)

SELECT pruebas.esperar_rechazo('G02-P01-I-06', 'AC-G02-P01-02', 'medio fuera de dominio',
     $q$ SELECT fn_registrar_decision(pruebas.propuesta_id(9002, 1), pruebas.labor_id(9002, 'Cambio de filtro'),
                                      103, 'Aceptada', 'Paloma', 201, '2026-11-03 11:30') $q$,
     'd_medio_comunicacion');
psql:pruebas/11_p01_invalidas.sql:172: NOTICE:  OK    [G02-P01-I-06] rechazo esperado -> 23514: value for domain d_medio_comunicacion violates check constraint "ck_d_medio_comunicacion"
                                                  esperar_rechazo                                                  
-------------------------------------------------------------------------------------------------------------------
 OK G02-P01-I-06: 23514: value for domain d_medio_comunicacion violates check constraint "ck_d_medio_comunicacion"
(1 row)

SELECT pruebas.esperar_rechazo('G02-P01-I-06', 'AC-G02-P01-02', 'decisión anterior a la presentación',
     $q$ SELECT fn_registrar_decision(pruebas.propuesta_id(9002, 1), pruebas.labor_id(9002, 'Cambio de filtro'),
                                      103, 'Aceptada', 'Teléfono', 201, '2026-11-03 10:00') $q$,
     'no puede ser anterior a la presentación');
psql:pruebas/11_p01_invalidas.sql:176: NOTICE:  OK    [G02-P01-I-06] rechazo esperado -> P0001: G02-P01: la decisión (2026-11-03 10:00:00-06) no puede ser anterior a la presentación de la versión (2026-11-03 10:30:00-06)
                                                                   esperar_rechazo                                                                    
------------------------------------------------------------------------------------------------------------------------------------------------------
 OK G02-P01-I-06: P0001: G02-P01: la decisión (2026-11-03 10:00:00-06) no puede ser anterior a la presentación de la versión (2026-11-03 10:30:00-06)
(1 row)

SELECT pruebas.esperar_rechazo('G02-P01-I-06', 'AC-G02-P01-02', 'decisión anterior a la última de la línea',
     $q$ SELECT fn_registrar_decision(pruebas.propuesta_id(9002, 1), pruebas.labor_id(9002, 'Cambio de filtro'),
                                      103, 'Rechazada', 'Teléfono', 201, '2026-11-03 10:45') $q$,
     'anterior a la última decisión registrada');
psql:pruebas/11_p01_invalidas.sql:180: NOTICE:  OK    [G02-P01-I-06] rechazo esperado -> P0001: G02-P01: la decisión (2026-11-03 10:45:00-06) es anterior a la última decisión registrada sobre la línea (2026-11-03 11:00:00-06)
                                                                      esperar_rechazo                                                                      
-----------------------------------------------------------------------------------------------------------------------------------------------------------
 OK G02-P01-I-06: P0001: G02-P01: la decisión (2026-11-03 10:45:00-06) es anterior a la última decisión registrada sobre la línea (2026-11-03 11:00:00-06)
(1 row)

-- ===========================================================
-- ID: G02-P01-I-07     Criterio: AC-G02-P01-03
-- Preparación: Ana aceptó en 9002 a las 11:00. El titular revoca su
--   designación a las 12:00 (única actualización permitida de una facultad).
-- Acción: Ana vuelve a decidir a las 13:00.
-- Esperado: rechazo (facultad ya no vigente); el titular sí puede decidir.
-- ===========================================================
UPDATE facultad_orden SET vigente_hasta = '2026-11-03 12:00'
WHERE orden_id = 9002 AND cliente_id = 104 AND tipo_facultad = 'Aprobar';
UPDATE 1
SELECT pruebas.esperar_rechazo('G02-P01-I-07', 'AC-G02-P01-03', 'decisión con facultad revocada',
     $q$ SELECT fn_registrar_decision(pruebas.propuesta_id(9002, 1), pruebas.labor_id(9002, 'Cambio de filtro'),
                                      104, 'Rechazada', 'Teléfono', 201, '2026-11-03 13:00') $q$,
     'no tiene facultad vigente');
psql:pruebas/11_p01_invalidas.sql:194: NOTICE:  OK    [G02-P01-I-07] rechazo esperado -> P0001: G02-P01: el cliente 104 no tiene facultad vigente para aprobar en la orden 9002
                                             esperar_rechazo                                             
---------------------------------------------------------------------------------------------------------
 OK G02-P01-I-07: P0001: G02-P01: el cliente 104 no tiene facultad vigente para aprobar en la orden 9002
(1 row)

SELECT pruebas.esperar_rechazo('G02-P01-I-07', 'AC-G02-P01-03', 'revocar dos veces / reescribir la facultad',
     $q$ UPDATE facultad_orden SET vigente_hasta = '2026-11-04 12:00'
         WHERE orden_id = 9002 AND cliente_id = 104 AND tipo_facultad = 'Aprobar' $q$,
     'solo admite revocación');
psql:pruebas/11_p01_invalidas.sql:198: NOTICE:  OK    [G02-P01-I-07] rechazo esperado -> P0001: G02-INM: la facultad 5 solo admite revocación (fijar vigente_hasta una única vez)
                                              esperar_rechazo                                              
-----------------------------------------------------------------------------------------------------------
 OK G02-P01-I-07: P0001: G02-INM: la facultad 5 solo admite revocación (fijar vigente_hasta una única vez)
(1 row)

SELECT pruebas.verificar('G02-P01-I-07', 'AC-G02-P01-03', 'la decisión de Ana anterior a la revocación se conserva',
     (SELECT situacion = 'Aceptada' AND decidido_por = 'Ana Solís' FROM v_situacion_labor WHERE labor_id = pruebas.labor_id(9002, 'Cambio de filtro')),
     'Aceptada por Ana Solís', (SELECT situacion || ' por ' || decidido_por FROM v_situacion_labor WHERE labor_id = pruebas.labor_id(9002, 'Cambio de filtro')));
psql:pruebas/11_p01_invalidas.sql:201: NOTICE:  OK    [G02-P01-I-07] Aceptada por Ana Solís -> Aceptada por Ana Solís
                verificar                
-----------------------------------------
 OK G02-P01-I-07: Aceptada por Ana Solís
(1 row)

-- ===========================================================
-- ID: G02-P01-I-08     Criterio: AC-G02-P01-01
-- Acción: publicar versiones mal formadas: sin líneas; labor duplicada en
--   la misma versión; hallazgo de otra orden; versión base de otra orden;
--   INSERT directo de una propuesta ya Presentada o con versión con hueco.
-- Esperado: todos rechazados con causa visible.
-- ===========================================================
SELECT pruebas.esperar_rechazo('G02-P01-I-08', 'AC-G02-P01-01', 'versión sin líneas',
     $q$ SELECT fn_publicar_propuesta(9001, NULL, '[]'::jsonb, 205, NULL, '2026-11-03 09:00') $q$,
     'al menos una línea');
psql:pruebas/11_p01_invalidas.sql:212: NOTICE:  OK    [G02-P01-I-08] rechazo esperado -> P0001: G02-P01: una versión debe tener al menos una línea
                              esperar_rechazo                               
----------------------------------------------------------------------------
 OK G02-P01-I-08: P0001: G02-P01: una versión debe tener al menos una línea
(1 row)

SELECT pruebas.esperar_rechazo('G02-P01-I-08', 'AC-G02-P01-01', 'labor repetida en la misma versión',
     $q$ SELECT fn_publicar_propuesta(9001, NULL,
            ('[{"labor_id":' || pruebas.labor_id(9001, 'Alineación') || ',"precio_estimado":1},
               {"labor_id":' || pruebas.labor_id(9001, 'Alineación') || ',"precio_estimado":2}]')::jsonb,
            205, NULL, '2026-11-03 09:00') $q$,
     'aparece dos veces');
psql:pruebas/11_p01_invalidas.sql:218: NOTICE:  OK    [G02-P01-I-08] rechazo esperado -> P0001: G02-P01: línea 2: la labor 503 aparece dos veces en la misma versión
                                       esperar_rechazo                                        
----------------------------------------------------------------------------------------------
 OK G02-P01-I-08: P0001: G02-P01: línea 2: la labor 503 aparece dos veces en la misma versión
(1 row)

SELECT pruebas.esperar_rechazo('G02-P01-I-08', 'AC-G02-P01-03', 'labor nueva con hallazgo de otra orden',
     $q$ SELECT fn_publicar_propuesta(9001, NULL,
            '[{"descripcion":"Labor ajena","hallazgo_id":4103,"precio_estimado":1000}]'::jsonb, 205, NULL, '2026-11-03 09:00') $q$,
     'el hallazgo 4103 no pertenece a la orden 9001');
psql:pruebas/11_p01_invalidas.sql:222: NOTICE:  OK    [G02-P01-I-08] rechazo esperado -> P0001: G02-P01: línea 1: el hallazgo 4103 no pertenece a la orden 9001
                                     esperar_rechazo                                     
-----------------------------------------------------------------------------------------
 OK G02-P01-I-08: P0001: G02-P01: línea 1: el hallazgo 4103 no pertenece a la orden 9001
(1 row)

SELECT pruebas.esperar_rechazo('G02-P01-I-08', 'AC-G02-P01-03', 'versión base de otra orden',
     $q$ SELECT fn_publicar_propuesta(9001, pruebas.propuesta_id(9002, 1),
            '[{"descripcion":"Revisión adicional","precio_estimado":1000}]'::jsonb, 205, NULL, '2026-11-03 09:00') $q$,
     'fk_propuesta_base');
psql:pruebas/11_p01_invalidas.sql:226: NOTICE:  OK    [G02-P01-I-08] rechazo esperado -> 23503: insert or update on table "propuesta" violates foreign key constraint "fk_propuesta_base"
                                                  esperar_rechazo                                                  
-------------------------------------------------------------------------------------------------------------------
 OK G02-P01-I-08: 23503: insert or update on table "propuesta" violates foreign key constraint "fk_propuesta_base"
(1 row)

SELECT pruebas.esperar_rechazo('G02-P01-I-08', 'AC-G02-P01-01', 'INSERT directo de una propuesta ya Presentada',
     $q$ INSERT INTO propuesta (orden_id, version, estado, presentada_por_id, fecha_hora_presentacion)
         VALUES (9001, 4, 'Presentada', 205, '2026-11-03 09:00') $q$,
     'se crea en Borrador');
psql:pruebas/11_p01_invalidas.sql:230: NOTICE:  OK    [G02-P01-I-08] rechazo esperado -> P0001: G02-P01: una propuesta se crea en Borrador y se presenta junto con sus líneas
                                            esperar_rechazo                                            
-------------------------------------------------------------------------------------------------------
 OK G02-P01-I-08: P0001: G02-P01: una propuesta se crea en Borrador y se presenta junto con sus líneas
(1 row)

SELECT pruebas.esperar_rechazo('G02-P01-I-08', 'AC-G02-P01-01', 'INSERT directo con hueco de versión',
     $q$ INSERT INTO propuesta (orden_id, version, presentada_por_id) VALUES (9001, 7, 205) $q$,
     'debe ser 4');
psql:pruebas/11_p01_invalidas.sql:233: NOTICE:  OK    [G02-P01-I-08] rechazo esperado -> P0001: G02-P01: la siguiente versión de la orden 9001 debe ser 4 (se indicó 7)
                                         esperar_rechazo                                         
-------------------------------------------------------------------------------------------------
 OK G02-P01-I-08: P0001: G02-P01: la siguiente versión de la orden 9001 debe ser 4 (se indicó 7)
(1 row)

SELECT pruebas.verificar('G02-P01-I-08', 'AC-G02-P01-01', 'siguen existiendo solo v1..v3 en 9001',
     (SELECT array_agg(version ORDER BY version) = ARRAY[1, 2, 3] FROM propuesta WHERE orden_id = 9001),
     '{1,2,3}', (SELECT array_agg(version ORDER BY version)::text FROM propuesta WHERE orden_id = 9001));
psql:pruebas/11_p01_invalidas.sql:236: NOTICE:  OK    [G02-P01-I-08] {1,2,3} -> {1,2,3}
        verificar         
--------------------------
 OK G02-P01-I-08: {1,2,3}
(1 row)

-- =====================================================================
-- G02-P01 · Versionar propuestas y autorizar labores · LÍMITE
-- Se muestra con v_situacion_labor qué decisión aplica en cada caso.
-- =====================================================================
SET search_path = taller, public;
SET
SET TIME ZONE 'America/Costa_Rica';
SET
-- ===========================================================
-- ID: G02-P01-L-01     Criterio: AC-G02-P01-04
-- Preparación: en 9002 el filtro fue Aceptado en v1 (por Ana).
-- Acción: v2 que SOLO cambia su precio (12000 -> 10000).
-- Esperado: el filtro queda "Sin decidir" en v2 (no se arrastra la
--   aceptación de v1) y deja de ser ejecutable hasta una nueva decisión;
--   el titular (Transportes) acepta sobre v2 y vuelve a ser ejecutable con
--   el autorizacion_id de v2.
-- ===========================================================
SELECT fn_publicar_propuesta(9002, pruebas.propuesta_id(9002, 1),
  ('[{"labor_id":' || pruebas.labor_id(9002, 'Cambio de filtro') || ',"precio_estimado":10000,"alcance":"Precio de flota"}]')::jsonb,
  205, 'Tarifa de flota', '2026-11-03 14:00');
 fn_publicar_propuesta 
-----------------------
                   311
(1 row)

SELECT labor_id, version_vigente, precio_vigente, situacion, autorizacion_id
FROM v_situacion_labor WHERE orden_id = 9002;
 labor_id | version_vigente | precio_vigente |  situacion  | autorizacion_id 
----------+-----------------+----------------+-------------+-----------------
      505 |               2 |       10000.00 | Sin decidir |                
(1 row)

SELECT pruebas.verificar('G02-P01-L-01', 'AC-G02-P01-04', 'v2 solo-precio: la aceptación de v1 no se arrastra',
     (SELECT situacion = 'Sin decidir' AND version_vigente = 2 FROM v_situacion_labor WHERE labor_id = pruebas.labor_id(9002, 'Cambio de filtro'))
     AND NOT EXISTS (SELECT 1 FROM v_autorizacion_ejecutable WHERE orden_id = 9002),
     'v2 Sin decidir y sin autorización ejecutable',
     (SELECT 'v' || version_vigente || ' ' || situacion FROM v_situacion_labor WHERE labor_id = pruebas.labor_id(9002, 'Cambio de filtro'))
     || '; ejecutables: ' || (SELECT count(*) FROM v_autorizacion_ejecutable WHERE orden_id = 9002));
psql:pruebas/12_p01_limite.sql:27: NOTICE:  OK    [G02-P01-L-01] v2 Sin decidir y sin autorización ejecutable -> v2 Sin decidir; ejecutables: 0
                    verificar                    
-------------------------------------------------
 OK G02-P01-L-01: v2 Sin decidir; ejecutables: 0
(1 row)

SELECT fn_registrar_decision(pruebas.propuesta_id(9002, 2), pruebas.labor_id(9002, 'Cambio de filtro'),
                             103, 'Aceptada', 'Correo', 201, '2026-11-03 14:30', 'Aprobado por la jefatura de flota');
 fn_registrar_decision 
-----------------------
                   617
(1 row)

SELECT pruebas.verificar('G02-P01-L-01', 'AC-G02-P01-04', 'tras decidir sobre v2, la ejecutable es la de v2',
     (SELECT e.autorizacion_id = a.autorizacion_id AND e.version = 2
      FROM v_autorizacion_ejecutable e JOIN autorizacion_labor a ON a.propuesta_id = pruebas.propuesta_id(9002, 2)
      WHERE e.labor_id = pruebas.labor_id(9002, 'Cambio de filtro')),
     'autorización ejecutable = decisión de v2',
     (SELECT 'v' || version || ', autorizacion_id ' || autorizacion_id FROM v_autorizacion_ejecutable WHERE orden_id = 9002));
psql:pruebas/12_p01_limite.sql:35: NOTICE:  OK    [G02-P01-L-01] autorización ejecutable = decisión de v2 -> v2, autorizacion_id 617
                verificar                 
------------------------------------------
 OK G02-P01-L-01: v2, autorizacion_id 617
(1 row)

-- ===========================================================
-- ID: G02-P01-L-02     Criterio: AC-G02-P01-01, AC-G02-P01-04
-- v2 que SOLO añade una labor: ver G02-P01-V-03. Aquí se verifica de nuevo
-- que A, B y C de 9001 conservan su versión vigente y decisión de v1, y que
-- v2 contiene una sola línea.
-- ===========================================================
SELECT pruebas.verificar('G02-P01-L-02', 'AC-G02-P01-01', 'v2 de 9001 contiene solo la labor añadida',
     (SELECT count(*) = 1 FROM linea_propuesta WHERE propuesta_id = pruebas.propuesta_id(9001, 2))
     AND (SELECT situacion = 'Aceptada' AND version_vigente = 1 FROM v_situacion_labor WHERE labor_id = pruebas.labor_id(9001, 'Cambio de pastillas')),
     'v2 con 1 línea; A sigue vigente en v1 y Aceptada',
     (SELECT count(*) FROM linea_propuesta WHERE propuesta_id = pruebas.propuesta_id(9001, 2)) || ' línea(s); A v'
     || (SELECT version_vigente || ' ' || situacion FROM v_situacion_labor WHERE labor_id = pruebas.labor_id(9001, 'Cambio de pastillas')));
psql:pruebas/12_p01_limite.sql:48: NOTICE:  OK    [G02-P01-L-02] v2 con 1 línea; A sigue vigente en v1 y Aceptada -> 1 línea(s); A v1 Aceptada
                 verificar                  
--------------------------------------------
 OK G02-P01-L-02: 1 línea(s); A v1 Aceptada
(1 row)

-- ===========================================================
-- ID: G02-P01-L-03     Criterio: AC-G02-P01-04
-- Preparación: orden 9014 (Jorge Quesada, titular).
-- Acción: v1 con 3 labores: E Aceptada, F con decisión explícita
--   "Pendiente" y G SIN ninguna decisión.
-- Esperado: situaciones Aceptada / Pendiente / Sin decidir. Ni la Pendiente
--   ni la Sin decidir son ejecutables (documentado en README §6.1: ambas
--   cuentan como "no autorizada"; la Pendiente además deja constancia de
--   que el cliente fue consultado).
-- ===========================================================
SELECT fn_cambiar_estado_orden(9014, 'En diagnóstico', 204, NULL, '2026-11-08 10:30');
 fn_cambiar_estado_orden 
-------------------------
                      20
(1 row)

SELECT fn_publicar_propuesta(9014, NULL,
  '[{"descripcion":"Cambio de aceite y filtro","hallazgo_id":4115,"precio_estimado":15000,
     "repuestos":[{"repuesto_id":"MG-002","cantidad":4,"precio_unitario":7200}]},
    {"descripcion":"Cambio de filtro de aire","hallazgo_id":4116,"precio_estimado":6000,
     "repuestos":[{"repuesto_id":"MG-001","cantidad":1,"precio_unitario":9000}]},
    {"descripcion":"Cambio de escobillas","hallazgo_id":4117,"precio_estimado":4000,
     "repuestos":[{"repuesto_id":"LP-001","cantidad":1,"precio_unitario":8500}]}]'::jsonb,
  205, NULL, '2026-11-08 12:00');
 fn_publicar_propuesta 
-----------------------
                   312
(1 row)

SELECT fn_registrar_decision(pruebas.propuesta_id(9014, 1), pruebas.labor_id(9014, 'Cambio de aceite'),
                             106, 'Aceptada', 'Presencial', 206, '2026-11-08 12:30');
 fn_registrar_decision 
-----------------------
                   618
(1 row)

SELECT fn_registrar_decision(pruebas.propuesta_id(9014, 1), pruebas.labor_id(9014, 'Cambio de filtro'),
                             106, 'Pendiente', 'Presencial', 206, '2026-11-08 12:31', 'Lo decide mañana');
 fn_registrar_decision 
-----------------------
                   619
(1 row)

SELECT labor_id, descripcion, situacion, autorizacion_id FROM v_situacion_labor WHERE orden_id = 9014 ORDER BY labor_id;
 labor_id |        descripcion        |  situacion  | autorizacion_id 
----------+---------------------------+-------------+-----------------
      506 | Cambio de aceite y filtro | Aceptada    |             618
      507 | Cambio de filtro de aire  | Pendiente   |             619
      508 | Cambio de escobillas      | Sin decidir |                
(3 rows)

SELECT pruebas.verificar('G02-P01-L-03', 'AC-G02-P01-04', 'decisiones incompletas',
     (SELECT string_agg(situacion, ',' ORDER BY labor_id) = 'Aceptada,Pendiente,Sin decidir' FROM v_situacion_labor WHERE orden_id = 9014)
     AND (SELECT count(*) = 1 FROM v_autorizacion_ejecutable WHERE orden_id = 9014),
     'Aceptada,Pendiente,Sin decidir; 1 ejecutable',
     (SELECT string_agg(situacion, ',' ORDER BY labor_id) FROM v_situacion_labor WHERE orden_id = 9014)
     || '; ' || (SELECT count(*) FROM v_autorizacion_ejecutable WHERE orden_id = 9014) || ' ejecutable(s)');
psql:pruebas/12_p01_limite.sql:79: NOTICE:  OK    [G02-P01-L-03] Aceptada,Pendiente,Sin decidir; 1 ejecutable -> Aceptada,Pendiente,Sin decidir; 1 ejecutable(s)
                            verificar                             
------------------------------------------------------------------
 OK G02-P01-L-03: Aceptada,Pendiente,Sin decidir; 1 ejecutable(s)
(1 row)

SELECT pruebas.esperar_rechazo('G02-P01-L-03', 'AC-G02-P01-04', 'iniciar la labor Pendiente',
     $q$ SELECT fn_iniciar_labor(pruebas.labor_id(9014, 'Cambio de filtro'), 204, '2026-11-08 13:00') $q$,
     'situación: Pendiente');
psql:pruebas/12_p01_limite.sql:82: NOTICE:  OK    [G02-P01-L-03] rechazo esperado -> P0001: G02-P02: la labor 507 no tiene autorización aplicable Aceptada ni excepción de emergencia (situación: Pendiente)
                                                             esperar_rechazo                                                              
------------------------------------------------------------------------------------------------------------------------------------------
 OK G02-P01-L-03: P0001: G02-P02: la labor 507 no tiene autorización aplicable Aceptada ni excepción de emergencia (situación: Pendiente)
(1 row)

SELECT pruebas.esperar_rechazo('G02-P01-L-03', 'AC-G02-P01-04', 'iniciar la labor Sin decidir',
     $q$ SELECT fn_iniciar_labor(pruebas.labor_id(9014, 'Cambio de escobillas'), 204, '2026-11-08 13:00') $q$,
     'situación: Sin decidir');
psql:pruebas/12_p01_limite.sql:85: NOTICE:  OK    [G02-P01-L-03] rechazo esperado -> P0001: G02-P02: la labor 508 no tiene autorización aplicable Aceptada ni excepción de emergencia (situación: Sin decidir)
                                                              esperar_rechazo                                                               
--------------------------------------------------------------------------------------------------------------------------------------------
 OK G02-P01-L-03: P0001: G02-P02: la labor 508 no tiene autorización aplicable Aceptada ni excepción de emergencia (situación: Sin decidir)
(1 row)

-- ===========================================================
-- ID: G02-P01-L-04     Criterio: AC-G02-P01-02, AC-G02-P01-04
-- Acción: Jorge cambia de opinión sobre F en la MISMA línea:
--   Pendiente (12:31) -> Aceptada (2026-11-09 08:00).
-- Esperado: se agrega una fila (la Pendiente se conserva) y la aplicable
--   es la última: Aceptada.
-- ===========================================================
SELECT fn_registrar_decision(pruebas.propuesta_id(9014, 1), pruebas.labor_id(9014, 'Cambio de filtro'),
                             106, 'Aceptada', 'Teléfono', 206, '2026-11-09 08:00', 'Confirma el cambio de filtro', 'Pendiente');
 fn_registrar_decision 
-----------------------
                   620
(1 row)

SELECT pruebas.verificar('G02-P01-L-04', 'AC-G02-P01-04', 'cambio de decisión en la misma línea',
     (SELECT count(*) = 2 FROM autorizacion_labor WHERE labor_id = pruebas.labor_id(9014, 'Cambio de filtro'))
     AND (SELECT situacion = 'Aceptada' FROM v_situacion_labor WHERE labor_id = pruebas.labor_id(9014, 'Cambio de filtro')),
     '2 filas (Pendiente, Aceptada); aplica Aceptada',
     (SELECT string_agg(decision, ', ' ORDER BY fecha_hora) FROM autorizacion_labor WHERE labor_id = pruebas.labor_id(9014, 'Cambio de filtro'))
     || '; aplica ' || (SELECT situacion FROM v_situacion_labor WHERE labor_id = pruebas.labor_id(9014, 'Cambio de filtro')));
psql:pruebas/12_p01_limite.sql:101: NOTICE:  OK    [G02-P01-L-04] 2 filas (Pendiente, Aceptada); aplica Aceptada -> Pendiente, Aceptada; aplica Aceptada
                       verificar                       
-------------------------------------------------------
 OK G02-P01-L-04: Pendiente, Aceptada; aplica Aceptada
(1 row)

-- ===========================================================
-- ID: G02-P01-L-05     Criterio: AC-G02-P01-04
-- Preparación: B (escobillas) de 9001 fue RECHAZADA en v1.
-- Acción: re-ofrecer B en v4 a un precio menor; consultar e intentar
--   iniciarla; luego María la acepta sobre v4.
-- Esperado: en v4, B está "Sin decidir" y NO es ejecutable (iniciar se
--   rechaza); tras la aceptación sobre v4 la ejecutable es la de v4. La
--   decisión Rechazada de v1 se conserva.
-- ===========================================================
SELECT fn_cambiar_estado_orden(9001, 'Pendiente autorización', 201, 'Se vuelve a ofrecer el cambio de escobillas', '2026-11-03 09:55');
 fn_cambiar_estado_orden 
-------------------------
                      21
(1 row)

SELECT fn_publicar_propuesta(9001, pruebas.propuesta_id(9001, 3),
  ('[{"labor_id":' || pruebas.labor_id(9001, 'Cambio de escobillas') || ',"precio_estimado":3000,
      "alcance":"Sustituir ambas escobillas (precio promocional)",
      "repuestos":[{"repuesto_id":"LP-001","cantidad":1,"precio_unitario":8500}]}]')::jsonb,
  205, 'Re-oferta de escobillas', '2026-11-03 10:00');
 fn_publicar_propuesta 
-----------------------
                   313
(1 row)

SELECT labor_id, descripcion, version_vigente, situacion FROM v_situacion_labor WHERE labor_id = pruebas.labor_id(9001, 'Cambio de escobillas');
 labor_id |     descripcion      | version_vigente |  situacion  
----------+----------------------+-----------------+-------------
      502 | Cambio de escobillas |               4 | Sin decidir
(1 row)

SELECT pruebas.verificar('G02-P01-L-05', 'AC-G02-P01-04', 'labor rechazada re-ofrecida queda Sin decidir',
     (SELECT situacion = 'Sin decidir' AND version_vigente = 4 FROM v_situacion_labor WHERE labor_id = pruebas.labor_id(9001, 'Cambio de escobillas')),
     'v4 Sin decidir', (SELECT 'v' || version_vigente || ' ' || situacion FROM v_situacion_labor WHERE labor_id = pruebas.labor_id(9001, 'Cambio de escobillas')));
psql:pruebas/12_p01_limite.sql:121: NOTICE:  OK    [G02-P01-L-05] v4 Sin decidir -> v4 Sin decidir
            verificar            
---------------------------------
 OK G02-P01-L-05: v4 Sin decidir
(1 row)

SELECT pruebas.esperar_rechazo('G02-P01-L-05', 'AC-G02-P01-04', 'iniciar la labor re-ofrecida sin decisión nueva',
     $q$ SELECT fn_iniciar_labor(pruebas.labor_id(9001, 'Cambio de escobillas'), 202, '2026-11-03 10:05') $q$,
     'no tiene autorización aplicable Aceptada');
psql:pruebas/12_p01_limite.sql:124: NOTICE:  OK    [G02-P01-L-05] rechazo esperado -> P0001: G02-P02: la labor 502 no tiene autorización aplicable Aceptada ni excepción de emergencia (situación: Sin decidir)
                                                              esperar_rechazo                                                               
--------------------------------------------------------------------------------------------------------------------------------------------
 OK G02-P01-L-05: P0001: G02-P02: la labor 502 no tiene autorización aplicable Aceptada ni excepción de emergencia (situación: Sin decidir)
(1 row)

SELECT pruebas.esperar_rechazo('G02-P01-L-05', 'AC-G02-P01-04', 'INSERT directo citando la autorización vieja (Rechazada de v1)',
     $q$ INSERT INTO historial_labor (labor_id, estado_nuevo, fecha_hora, personal_id, autorizacion_id)
         SELECT labor_id, 'En proceso', '2026-11-03 10:05', 202, autorizacion_id
         FROM autorizacion_labor WHERE labor_id = pruebas.labor_id(9001, 'Cambio de escobillas') AND decision = 'Rechazada' $q$,
     'no es la decisión aplicable Aceptada');
psql:pruebas/12_p01_limite.sql:129: NOTICE:  OK    [G02-P01-L-05] rechazo esperado -> P0001: G02-P02: la autorización 602 no es la decisión aplicable Aceptada de la labor 502 (situación: Sin decidir)
                                                          esperar_rechazo                                                           
------------------------------------------------------------------------------------------------------------------------------------
 OK G02-P01-L-05: P0001: G02-P02: la autorización 602 no es la decisión aplicable Aceptada de la labor 502 (situación: Sin decidir)
(1 row)

SELECT fn_registrar_decision(pruebas.propuesta_id(9001, 4), pruebas.labor_id(9001, 'Cambio de escobillas'),
                             101, 'Aceptada', 'Teléfono', 201, '2026-11-03 10:30', 'Acepta con el precio promocional');
 fn_registrar_decision 
-----------------------
                   621
(1 row)

SELECT fn_cambiar_estado_orden(9001, 'Autorizada', 201, NULL, '2026-11-03 10:35');
 fn_cambiar_estado_orden 
-------------------------
                      22
(1 row)

SELECT pruebas.verificar('G02-P01-L-05', 'AC-G02-P01-04', 'la ejecutable de B es la aceptación de v4 y la Rechazada de v1 se conserva',
     (SELECT version = 4 FROM v_autorizacion_ejecutable WHERE labor_id = pruebas.labor_id(9001, 'Cambio de escobillas'))
     AND EXISTS (SELECT 1 FROM v_comparacion_versiones WHERE labor_id = pruebas.labor_id(9001, 'Cambio de escobillas')
                 AND version = 1 AND decision_en_esta_version = 'Rechazada'),
     'ejecutable v4; v1 Rechazada intacta',
     (SELECT string_agg('v' || version || ':' || decision_en_esta_version, ', ' ORDER BY version)
      FROM v_comparacion_versiones WHERE labor_id = pruebas.labor_id(9001, 'Cambio de escobillas')));
psql:pruebas/12_p01_limite.sql:139: NOTICE:  OK    [G02-P01-L-05] ejecutable v4; v1 Rechazada intacta -> v1:Rechazada, v4:Aceptada
                 verificar                  
--------------------------------------------
 OK G02-P01-L-05: v1:Rechazada, v4:Aceptada
(1 row)

-- Situación final de 9001 (todas las labores, con la versión y decisión aplicable).
SELECT labor_id, descripcion, version_vigente, precio_vigente, situacion, decidido_por, medio_decision, autorizacion_id
FROM v_situacion_labor WHERE orden_id = 9001 ORDER BY labor_id;
 labor_id |             descripcion             | version_vigente | precio_vigente | situacion | decidido_por | medio_decision | autorizacion_id 
----------+-------------------------------------+-----------------+----------------+-----------+--------------+----------------+-----------------
      501 | Cambio de pastillas delanteras      |               1 |       45000.00 | Aceptada  | María Rojas  | Teléfono       |             601
      502 | Cambio de escobillas                |               4 |        3000.00 | Aceptada  | María Rojas  | Teléfono       |             621
      503 | Alineación y balanceo               |               3 |       25000.00 | Aceptada  | María Rojas  | Teléfono       |             605
      504 | Purga y cambio de líquido de frenos |               2 |       18000.00 | Aceptada  | María Rojas  | Mensaje        |             604
(4 rows)

-- =====================================================================
-- G02-P01 · ATOMICIDAD de la publicación de versiones
-- Una versión con UN detalle inválido no deja NADA: ni propuesta, ni
-- labores nuevas, ni líneas, ni repuestos estimados, ni dependencias, y la
-- numeración de versiones no salta.
-- =====================================================================
SET search_path = taller, public;
SET
SET TIME ZONE 'America/Costa_Rica';
SET
-- Conteos de referencia de la orden 9001 antes de los intentos.
SELECT (SELECT count(*) FROM propuesta WHERE orden_id = 9001)        AS propuestas,
       (SELECT count(*) FROM labor WHERE orden_id = 9001)            AS labores,
       (SELECT count(*) FROM linea_propuesta WHERE orden_id = 9001)  AS lineas,
       (SELECT count(*) FROM repuesto_propuesto rp JOIN propuesta p USING (propuesta_id) WHERE p.orden_id = 9001) AS repuestos_estimados,
       (SELECT count(*) FROM labor_dependencia WHERE orden_id = 9001) AS dependencias;
 propuestas | labores | lineas | repuestos_estimados | dependencias 
------------+---------+--------+---------------------+--------------
          4 |       4 |      6 |                   4 |            0
(1 row)

-- ===========================================================
-- ID: G02-P01-A-01     Criterio: AC-G02-P01-01
-- Acción: versión con 2 labores nuevas válidas (una con repuesto) y una
--   tercera línea con PRECIO NEGATIVO.
-- Esperado: rechazo "no puede ser negativo"; conteos idénticos.
-- ===========================================================
SELECT pruebas.esperar_rechazo('G02-P01-A-01', 'AC-G02-P01-01', 'versión con una línea de precio negativo',
     $q$ SELECT fn_publicar_propuesta(9001, pruebas.propuesta_id(9001, 4),
            '[{"descripcion":"Rotación de llantas","precio_estimado":8000},
              {"descripcion":"Cambio de bombillo de freno","precio_estimado":3000,
               "repuestos":[{"repuesto_id":"LP-001","cantidad":1,"precio_unitario":1000}]},
              {"descripcion":"Lavado de motor","precio_estimado":-500}]'::jsonb,
            205, NULL, '2026-11-03 11:00') $q$,
     'no puede ser negativo');
psql:pruebas/13_p01_atomicidad.sql:30: NOTICE:  OK    [G02-P01-A-01] rechazo esperado -> P0001: G02-P01: línea 3: el precio estimado no puede ser negativo (-500)
                                      esperar_rechazo                                      
-------------------------------------------------------------------------------------------
 OK G02-P01-A-01: P0001: G02-P01: línea 3: el precio estimado no puede ser negativo (-500)
(1 row)

-- ===========================================================
-- ID: G02-P01-A-02     Criterio: AC-G02-P01-01, AC-G02-P01-03
-- Acción: versión cuya primera línea crea una labor y una dependencia
--   válidas y cuya segunda línea cita un HALLAZGO DE OTRA ORDEN (4103, de 9002).
-- Esperado: rechazo "no pertenece a la orden 9001"; la labor de la primera
--   línea tampoco queda.
-- ===========================================================
SELECT pruebas.esperar_rechazo('G02-P01-A-02', 'AC-G02-P01-01', 'versión con hallazgo de otra orden en la segunda línea',
     $q$ SELECT fn_publicar_propuesta(9001, NULL,
            '[{"clave":"X","descripcion":"Ajuste de frenos traseros","hallazgo_id":4101,"precio_estimado":9000},
              {"descripcion":"Filtro ajeno","hallazgo_id":4103,"precio_estimado":5000,"requiere":["X"]}]'::jsonb,
            205, NULL, '2026-11-03 11:00') $q$,
     'el hallazgo 4103 no pertenece a la orden 9001');
psql:pruebas/13_p01_atomicidad.sql:44: NOTICE:  OK    [G02-P01-A-02] rechazo esperado -> P0001: G02-P01: línea 2: el hallazgo 4103 no pertenece a la orden 9001
                                     esperar_rechazo                                     
-----------------------------------------------------------------------------------------
 OK G02-P01-A-02: P0001: G02-P01: línea 2: el hallazgo 4103 no pertenece a la orden 9001
(1 row)

-- ===========================================================
-- ID: G02-P01-A-03     Criterio: AC-G02-P01-01
-- Acción: versión con un repuesto estimado INEXISTENTE en la última línea.
-- Esperado: rechazo por la FK fk_rep_prop_repuesto; nada queda.
-- ===========================================================
SELECT pruebas.esperar_rechazo('G02-P01-A-03', 'AC-G02-P01-01', 'versión con repuesto inexistente',
     $q$ SELECT fn_publicar_propuesta(9001, NULL,
            '[{"descripcion":"Cambio de amortiguadores","precio_estimado":40000,
               "repuestos":[{"repuesto_id":"ZZ-999","cantidad":2,"precio_unitario":30000}]}]'::jsonb,
            205, NULL, '2026-11-03 11:00') $q$,
     'fk_rep_prop_repuesto');
psql:pruebas/13_p01_atomicidad.sql:56: NOTICE:  OK    [G02-P01-A-03] rechazo esperado -> 23503: insert or update on table "repuesto_propuesto" violates foreign key constraint "fk_rep_prop_repuesto"
                                                        esperar_rechazo                                                        
-------------------------------------------------------------------------------------------------------------------------------
 OK G02-P01-A-03: 23503: insert or update on table "repuesto_propuesto" violates foreign key constraint "fk_rep_prop_repuesto"
(1 row)

SELECT pruebas.verificar('G02-P01-A-01', 'AC-G02-P01-01', 'conteos iguales tras los tres intentos fallidos',
     (SELECT count(*) = 4 FROM propuesta WHERE orden_id = 9001)
     AND (SELECT count(*) = 4 FROM labor WHERE orden_id = 9001)
     AND (SELECT count(*) = 6 FROM linea_propuesta WHERE orden_id = 9001)
     AND (SELECT count(*) = 0 FROM labor_dependencia WHERE orden_id = 9001),
     '4 propuestas, 4 labores, 6 líneas, 0 dependencias',
     (SELECT count(*) FROM propuesta WHERE orden_id = 9001) || ' propuestas, '
     || (SELECT count(*) FROM labor WHERE orden_id = 9001) || ' labores, '
     || (SELECT count(*) FROM linea_propuesta WHERE orden_id = 9001) || ' líneas, '
     || (SELECT count(*) FROM labor_dependencia WHERE orden_id = 9001) || ' dependencias');
psql:pruebas/13_p01_atomicidad.sql:67: NOTICE:  OK    [G02-P01-A-01] 4 propuestas, 4 labores, 6 líneas, 0 dependencias -> 4 propuestas, 4 labores, 6 líneas, 0 dependencias
                             verificar                              
--------------------------------------------------------------------
 OK G02-P01-A-01: 4 propuestas, 4 labores, 6 líneas, 0 dependencias
(1 row)

-- La numeración no salta: la siguiente publicación válida obtiene la v5.
SELECT fn_publicar_propuesta(9001, pruebas.propuesta_id(9001, 4),
  '[{"descripcion":"Rotación de llantas","precio_estimado":8000,"alcance":"Rotación en cruz"}]'::jsonb,
  205, 'Ampliación válida tras los intentos fallidos', '2026-11-03 11:10');
 fn_publicar_propuesta 
-----------------------
                   317
(1 row)

SELECT pruebas.verificar('G02-P01-A-01', 'AC-G02-P01-01', 'la siguiente versión válida es la 5 (sin huecos)',
     (SELECT array_agg(version ORDER BY version) = ARRAY[1, 2, 3, 4, 5] FROM propuesta WHERE orden_id = 9001),
     '{1,2,3,4,5}', (SELECT array_agg(version ORDER BY version)::text FROM propuesta WHERE orden_id = 9001));
psql:pruebas/13_p01_atomicidad.sql:75: NOTICE:  OK    [G02-P01-A-01] {1,2,3,4,5} -> {1,2,3,4,5}
          verificar           
------------------------------
 OK G02-P01-A-01: {1,2,3,4,5}
(1 row)

```
