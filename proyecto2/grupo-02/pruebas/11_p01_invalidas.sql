-- =====================================================================
-- G02-P01 · Versionar propuestas y autorizar labores · INVÁLIDAS
-- Dos contextos válidos distintos:
--   9001 — María (101) titular; v1 (A,B,C), v2 (D), v3 (C con precio nuevo)
--   9002 — Transportes (103) titular; Ana (104) designada; v1 (filtro)
-- Tras cada intento se comprueba que NO hay filas nuevas ni cambios.
-- =====================================================================
SET search_path = taller, public;
SET TIME ZONE 'America/Costa_Rica';

-- Línea base para comprobar "sin efectos".
SELECT count(*) AS decisiones_9001 FROM autorizacion_labor WHERE orden_id = 9001;

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
SELECT pruebas.esperar_rechazo('G02-P01-I-01', 'AC-G02-P01-03', 'Pedro (sin facultad) decide en 9001',
     $q$ SELECT fn_registrar_decision(pruebas.propuesta_id(9001, 2), pruebas.labor_id(9001, 'Purga y cambio'),
                                      108, 'Aceptada', 'Teléfono', 201, '2026-11-03 09:00') $q$,
     'el cliente 108 no tiene facultad vigente');
SELECT pruebas.esperar_rechazo('G02-P01-I-01', 'AC-G02-P01-03', 'INSERT directo con la facultad de Ana en 9002',
     $q$ INSERT INTO autorizacion_labor (propuesta_id, labor_id, orden_id, facultad_id, cliente_id, decision, fecha_hora, medio, registrado_por_id)
         SELECT pruebas.propuesta_id(9001, 2), pruebas.labor_id(9001, 'Purga y cambio'), 9001, f.facultad_id, 104,
                'Rechazada', '2026-11-03 09:00', 'Teléfono', 201
         FROM facultad_orden f WHERE f.orden_id = 9002 AND f.cliente_id = 104 AND f.tipo_facultad = 'Aprobar' $q$,
     'no tiene facultad vigente para aprobar en la orden 9001');
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
SELECT pruebas.esperar_rechazo('G02-P01-I-01', 'AC-G02-P01-03', 'INSERT directo: facultad de María pero cliente Ana',
     $q$ INSERT INTO autorizacion_labor (propuesta_id, labor_id, orden_id, facultad_id, cliente_id, decision, fecha_hora, medio, registrado_por_id)
         SELECT pruebas.propuesta_id(9001, 2), pruebas.labor_id(9001, 'Purga y cambio'), 9001, f.facultad_id, 104,
                'Rechazada', '2026-11-03 09:00', 'Teléfono', 201
         FROM facultad_orden f WHERE f.orden_id = 9001 AND f.cliente_id = 101 AND f.tipo_facultad = 'Aprobar' $q$,
     'no tiene facultad vigente para aprobar');
SELECT pruebas.verificar('G02-P01-I-01', 'AC-G02-P01-03', 'sin decisiones nuevas en 9001 y D sigue Aceptada',
     (SELECT count(*) = 5 FROM autorizacion_labor WHERE orden_id = 9001)
     AND (SELECT situacion = 'Aceptada' FROM v_situacion_labor WHERE labor_id = pruebas.labor_id(9001, 'Purga y cambio')),
     '5 decisiones; D Aceptada',
     (SELECT count(*) FROM autorizacion_labor WHERE orden_id = 9001) || ' decisiones; D '
     || (SELECT situacion FROM v_situacion_labor WHERE labor_id = pruebas.labor_id(9001, 'Purga y cambio')));

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
SELECT pruebas.esperar_rechazo('G02-P01-I-02', 'AC-G02-P01-03', 'decisión sobre labor de otra orden (INSERT directo)',
     $q$ INSERT INTO autorizacion_labor (propuesta_id, labor_id, orden_id, facultad_id, cliente_id, decision, fecha_hora, medio, registrado_por_id)
         SELECT pruebas.propuesta_id(9001, 1), pruebas.labor_id(9002, 'Cambio de filtro'), 9001, f.facultad_id, 101,
                'Aceptada', '2026-11-03 09:00', 'Teléfono', 201
         FROM facultad_orden f WHERE f.orden_id = 9001 AND f.cliente_id = 101 AND f.tipo_facultad = 'Aprobar' $q$,
     'no forma parte de la propuesta');
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
SELECT pruebas.esperar_rechazo('G02-P01-I-02', 'AC-G02-P01-03', 'publicar en 9001 una línea con labor de 9002',
     $q$ SELECT fn_publicar_propuesta(9001, NULL,
            ('[{"labor_id":' || pruebas.labor_id(9002, 'Cambio de filtro') || ',"precio_estimado":1000}]')::jsonb,
            205, NULL, '2026-11-03 09:00') $q$,
     'no pertenece a la orden 9001');

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
SELECT pruebas.esperar_rechazo('G02-P01-I-04', 'AC-G02-P01-01', 'DELETE de una línea presentada',
     $q$ DELETE FROM linea_propuesta WHERE propuesta_id = pruebas.propuesta_id(9001, 1) $q$,
     'inmutables');
SELECT pruebas.esperar_rechazo('G02-P01-I-04', 'AC-G02-P01-01', 'UPDATE de un repuesto estimado presentado',
     $q$ UPDATE repuesto_propuesto SET cantidad_estimada = 5 WHERE propuesta_id = pruebas.propuesta_id(9001, 1) $q$,
     'inmutables');
SELECT pruebas.esperar_rechazo('G02-P01-I-04', 'AC-G02-P01-01', 'INSERT de una línea en v1 ya presentada',
     $q$ INSERT INTO linea_propuesta (propuesta_id, labor_id, orden_id, precio_estimado, alcance)
         VALUES (pruebas.propuesta_id(9001, 1), pruebas.labor_id(9001, 'Purga y cambio'), 9001, 100, 'colada') $q$,
     'inmutables');
SELECT pruebas.esperar_rechazo('G02-P01-I-04', 'AC-G02-P01-01', 'UPDATE de la observación de una propuesta presentada',
     $q$ UPDATE propuesta SET observacion = 'reescrita' WHERE propuesta_id = pruebas.propuesta_id(9001, 1) $q$,
     'ya fue presentada y es inmutable');
SELECT pruebas.esperar_rechazo('G02-P01-I-04', 'AC-G02-P01-02', 'UPDATE de una autorización (cambiar Rechazada por Aceptada)',
     $q$ UPDATE autorizacion_labor SET decision = 'Aceptada' WHERE orden_id = 9001 AND decision = 'Rechazada' $q$,
     'solo inserción');
SELECT pruebas.esperar_rechazo('G02-P01-I-04', 'AC-G02-P01-02', 'DELETE de una autorización',
     $q$ DELETE FROM autorizacion_labor WHERE orden_id = 9001 $q$,
     'solo inserción');
SELECT pruebas.verificar('G02-P01-I-04', 'AC-G02-P01-01', 'v1 sigue idéntica',
     (SELECT string_agg(precio_estimado::text || ':' || decision_en_esta_version, ',' ORDER BY labor_id)
      FROM v_comparacion_versiones WHERE orden_id = 9001 AND version = 1) = '45000.00:Aceptada,5000.00:Rechazada,30000.00:Pendiente',
     '45000 Aceptada, 5000 Rechazada, 30000 Pendiente',
     (SELECT string_agg(precio_estimado::text || ':' || decision_en_esta_version, ',' ORDER BY labor_id)
      FROM v_comparacion_versiones WHERE orden_id = 9001 AND version = 1));

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
SELECT pruebas.esperar_rechazo('G02-P01-I-06', 'AC-G02-P01-02', 'medio fuera de dominio',
     $q$ SELECT fn_registrar_decision(pruebas.propuesta_id(9002, 1), pruebas.labor_id(9002, 'Cambio de filtro'),
                                      103, 'Aceptada', 'Paloma', 201, '2026-11-03 11:30') $q$,
     'd_medio_comunicacion');
SELECT pruebas.esperar_rechazo('G02-P01-I-06', 'AC-G02-P01-02', 'decisión anterior a la presentación',
     $q$ SELECT fn_registrar_decision(pruebas.propuesta_id(9002, 1), pruebas.labor_id(9002, 'Cambio de filtro'),
                                      103, 'Aceptada', 'Teléfono', 201, '2026-11-03 10:00') $q$,
     'no puede ser anterior a la presentación');
SELECT pruebas.esperar_rechazo('G02-P01-I-06', 'AC-G02-P01-02', 'decisión anterior a la última de la línea',
     $q$ SELECT fn_registrar_decision(pruebas.propuesta_id(9002, 1), pruebas.labor_id(9002, 'Cambio de filtro'),
                                      103, 'Rechazada', 'Teléfono', 201, '2026-11-03 10:45') $q$,
     'anterior a la última decisión registrada');

-- ===========================================================
-- ID: G02-P01-I-07     Criterio: AC-G02-P01-03
-- Preparación: Ana aceptó en 9002 a las 11:00. El titular revoca su
--   designación a las 12:00 (única actualización permitida de una facultad).
-- Acción: Ana vuelve a decidir a las 13:00.
-- Esperado: rechazo (facultad ya no vigente); el titular sí puede decidir.
-- ===========================================================
UPDATE facultad_orden SET vigente_hasta = '2026-11-03 12:00'
WHERE orden_id = 9002 AND cliente_id = 104 AND tipo_facultad = 'Aprobar';
SELECT pruebas.esperar_rechazo('G02-P01-I-07', 'AC-G02-P01-03', 'decisión con facultad revocada',
     $q$ SELECT fn_registrar_decision(pruebas.propuesta_id(9002, 1), pruebas.labor_id(9002, 'Cambio de filtro'),
                                      104, 'Rechazada', 'Teléfono', 201, '2026-11-03 13:00') $q$,
     'no tiene facultad vigente');
SELECT pruebas.esperar_rechazo('G02-P01-I-07', 'AC-G02-P01-03', 'revocar dos veces / reescribir la facultad',
     $q$ UPDATE facultad_orden SET vigente_hasta = '2026-11-04 12:00'
         WHERE orden_id = 9002 AND cliente_id = 104 AND tipo_facultad = 'Aprobar' $q$,
     'solo admite revocación');
SELECT pruebas.verificar('G02-P01-I-07', 'AC-G02-P01-03', 'la decisión de Ana anterior a la revocación se conserva',
     (SELECT situacion = 'Aceptada' AND decidido_por = 'Ana Solís' FROM v_situacion_labor WHERE labor_id = pruebas.labor_id(9002, 'Cambio de filtro')),
     'Aceptada por Ana Solís', (SELECT situacion || ' por ' || decidido_por FROM v_situacion_labor WHERE labor_id = pruebas.labor_id(9002, 'Cambio de filtro')));

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
SELECT pruebas.esperar_rechazo('G02-P01-I-08', 'AC-G02-P01-01', 'labor repetida en la misma versión',
     $q$ SELECT fn_publicar_propuesta(9001, NULL,
            ('[{"labor_id":' || pruebas.labor_id(9001, 'Alineación') || ',"precio_estimado":1},
               {"labor_id":' || pruebas.labor_id(9001, 'Alineación') || ',"precio_estimado":2}]')::jsonb,
            205, NULL, '2026-11-03 09:00') $q$,
     'aparece dos veces');
SELECT pruebas.esperar_rechazo('G02-P01-I-08', 'AC-G02-P01-03', 'labor nueva con hallazgo de otra orden',
     $q$ SELECT fn_publicar_propuesta(9001, NULL,
            '[{"descripcion":"Labor ajena","hallazgo_id":4103,"precio_estimado":1000}]'::jsonb, 205, NULL, '2026-11-03 09:00') $q$,
     'el hallazgo 4103 no pertenece a la orden 9001');
SELECT pruebas.esperar_rechazo('G02-P01-I-08', 'AC-G02-P01-03', 'versión base de otra orden',
     $q$ SELECT fn_publicar_propuesta(9001, pruebas.propuesta_id(9002, 1),
            '[{"descripcion":"Revisión adicional","precio_estimado":1000}]'::jsonb, 205, NULL, '2026-11-03 09:00') $q$,
     'fk_propuesta_base');
SELECT pruebas.esperar_rechazo('G02-P01-I-08', 'AC-G02-P01-01', 'INSERT directo de una propuesta ya Presentada',
     $q$ INSERT INTO propuesta (orden_id, version, estado, presentada_por_id, fecha_hora_presentacion)
         VALUES (9001, 4, 'Presentada', 205, '2026-11-03 09:00') $q$,
     'se crea en Borrador');
SELECT pruebas.esperar_rechazo('G02-P01-I-08', 'AC-G02-P01-01', 'INSERT directo con hueco de versión',
     $q$ INSERT INTO propuesta (orden_id, version, presentada_por_id) VALUES (9001, 7, 205) $q$,
     'debe ser 4');
SELECT pruebas.verificar('G02-P01-I-08', 'AC-G02-P01-01', 'siguen existiendo solo v1..v3 en 9001',
     (SELECT array_agg(version ORDER BY version) = ARRAY[1, 2, 3] FROM propuesta WHERE orden_id = 9001),
     '{1,2,3}', (SELECT array_agg(version ORDER BY version)::text FROM propuesta WHERE orden_id = 9001));
