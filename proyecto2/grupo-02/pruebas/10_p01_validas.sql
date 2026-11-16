-- =====================================================================
-- G02-P01 · Versionar propuestas y autorizar labores · VÁLIDAS
-- Orden: 9001 (María Rojas, titular con facultad Aprobar; Honda ABC123).
-- Hallazgos de preparación: 4101 pastillas, 4102 escobillas,
--   4106 alineación, 4107 líquido de frenos.
-- =====================================================================
SET search_path = taller, public;
SET TIME ZONE 'America/Costa_Rica';

-- ===========================================================
-- ID: G02-P01-V-01     Criterio: AC-G02-P01-01
-- Preparación: orden 9001 en diagnóstico (sin propuestas).
-- Acción: publicar la versión 1 con 3 labores nuevas (A, B, C) y sus
--   repuestos estimados, en una transacción confirmada.
-- Esperado: propuesta v1 Presentada con 3 líneas; 3 labores Pendiente.
-- ===========================================================
SELECT fn_cambiar_estado_orden(9001, 'En diagnóstico', 202, NULL, '2026-11-02 08:45');

BEGIN;
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
COMMIT;
SELECT fn_cambiar_estado_orden(9001, 'Pendiente autorización', 201, NULL, '2026-11-02 11:05');

SELECT pruebas.verificar('G02-P01-V-01', 'AC-G02-P01-01', 'v1 presentada con 3 líneas',
     (SELECT p.estado = 'Presentada' AND p.version = 1 AND (SELECT count(*) FROM linea_propuesta WHERE propuesta_id = p.propuesta_id) = 3
      FROM propuesta p WHERE p.orden_id = 9001 AND p.version = 1),
     'v1 Presentada, 3 líneas',
     (SELECT 'v' || version || ' ' || estado || ', ' || (SELECT count(*) FROM linea_propuesta WHERE propuesta_id = p.propuesta_id) || ' líneas'
      FROM propuesta p WHERE orden_id = 9001 AND version = 1));

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
SELECT fn_registrar_decision(pruebas.propuesta_id(9001, 1), pruebas.labor_id(9001, 'Cambio de escobillas'),
                             101, 'Rechazada', 'Teléfono', 201, '2026-11-02 11:31', 'Las cambiará por su cuenta');
SELECT fn_registrar_decision(pruebas.propuesta_id(9001, 1), pruebas.labor_id(9001, 'Alineación'),
                             101, 'Pendiente', 'Teléfono', 201, '2026-11-02 11:32', 'Lo consultará; precio alto');
SELECT fn_cambiar_estado_orden(9001, 'Autorizada', 201, NULL, '2026-11-02 11:40');

SELECT labor_id, descripcion, version_vigente, situacion, decidido_por, medio_decision, fecha_hora_decision, autorizacion_id
FROM v_situacion_labor WHERE orden_id = 9001 ORDER BY labor_id;

SELECT pruebas.verificar('G02-P01-V-02', 'AC-G02-P01-02', 'decisiones con actor, facultad, medio y fecha',
     (SELECT count(*) = 3 AND bool_and(cliente_id = 101 AND facultad_id IS NOT NULL AND medio = 'Teléfono')
      FROM autorizacion_labor WHERE orden_id = 9001),
     '3 decisiones de María por teléfono con facultad',
     (SELECT count(*) || ' decisiones: ' || string_agg(decision, ', ' ORDER BY autorizacion_id) FROM autorizacion_labor WHERE orden_id = 9001));
SELECT pruebas.verificar('G02-P01-V-02', 'AC-G02-P01-04', 'solo A es ejecutable',
     (SELECT array_agg(labor_id) = ARRAY[pruebas.labor_id(9001, 'Cambio de pastillas')] FROM v_autorizacion_ejecutable WHERE orden_id = 9001),
     'ejecutables: {A}',
     (SELECT 'ejecutables: ' || coalesce(array_agg(labor_id)::text, '{}') FROM v_autorizacion_ejecutable WHERE orden_id = 9001));

-- ===========================================================
-- ID: G02-P01-V-03     Criterio: AC-G02-P01-01
-- Preparación: v1 con A aceptada, B rechazada, C pendiente.
-- Acción: emitir v2 como AMPLIACIÓN que solo añade la labor D (líquido de
--   frenos, hallazgo 4107); María acepta D.
-- Esperado: A, B y C conservan v1 como versión vigente y su decisión;
--   D vigente en v2 y Aceptada.
-- ===========================================================
SELECT fn_cambiar_estado_orden(9001, 'Pendiente autorización', 201, 'Ampliación por hallazgo de líquido de frenos', '2026-11-02 14:55');
SELECT fn_publicar_propuesta(9001, pruebas.propuesta_id(9001, 1),
  '[{"descripcion":"Purga y cambio de líquido de frenos","hallazgo_id":4107,"precio_estimado":18000,
     "alcance":"Purgar circuito y reponer DOT 4",
     "repuestos":[{"repuesto_id":"FR-002","cantidad":1,"precio_unitario":6500}]}]'::jsonb,
  205, 'Ampliación: líquido de frenos', '2026-11-02 15:00');
SELECT fn_registrar_decision(pruebas.propuesta_id(9001, 2), pruebas.labor_id(9001, 'Purga y cambio'),
                             101, 'Aceptada', 'Mensaje', 201, '2026-11-02 15:30');
SELECT fn_cambiar_estado_orden(9001, 'Autorizada', 201, NULL, '2026-11-02 15:35');

SELECT pruebas.verificar('G02-P01-V-03', 'AC-G02-P01-01', 'la ampliación no toca A, B y C',
     (SELECT string_agg(descripcion || '=v' || version_vigente || ':' || situacion, ', ' ORDER BY labor_id)
      FROM v_situacion_labor WHERE orden_id = 9001)
     = 'Cambio de pastillas delanteras=v1:Aceptada, Cambio de escobillas=v1:Rechazada, Alineación y balanceo=v1:Pendiente, Purga y cambio de líquido de frenos=v2:Aceptada',
     'A=v1:Aceptada, B=v1:Rechazada, C=v1:Pendiente, D=v2:Aceptada',
     (SELECT string_agg(descripcion || '=v' || version_vigente || ':' || situacion, ', ' ORDER BY labor_id)
      FROM v_situacion_labor WHERE orden_id = 9001));

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
SELECT fn_cambiar_estado_orden(9001, 'Pendiente autorización', 201, 'Nuevo precio de alineación', '2026-11-03 07:55');
SELECT fn_publicar_propuesta(9001, pruebas.propuesta_id(9001, 2),
  ('[{"labor_id":' || pruebas.labor_id(9001, 'Alineación') || ',"precio_estimado":25000,
      "alcance":"Alinear eje delantero y balancear 4 llantas (precio con descuento)"}]')::jsonb,
  205, 'Descuento en alineación', '2026-11-03 08:00');
SELECT labor_id, version_vigente, situacion FROM v_situacion_labor WHERE labor_id = pruebas.labor_id(9001, 'Alineación');
SELECT fn_registrar_decision(pruebas.propuesta_id(9001, 3), pruebas.labor_id(9001, 'Alineación'),
                             101, 'Aceptada', 'Teléfono', 201, '2026-11-03 08:30');
SELECT fn_cambiar_estado_orden(9001, 'Autorizada', 201, NULL, '2026-11-03 08:35');
COMMIT;

-- Lectura posterior (nueva transacción): comparación completa de versiones.
SELECT orden_id, labor, version, precio_estimado, repuestos_estimados, decision_en_esta_version, decidido_por, medio, es_version_vigente
FROM v_comparacion_versiones WHERE orden_id = 9001 ORDER BY labor_id, version;

SELECT pruebas.verificar('G02-P01-V-04', 'AC-G02-P01-01', 'v1 intacta tras v2 y v3',
     (SELECT string_agg(labor || ':' || precio_estimado || ':' || decision_en_esta_version, ' | ' ORDER BY labor_id)
      FROM v_comparacion_versiones WHERE orden_id = 9001 AND version = 1)
     = 'Cambio de pastillas delanteras:45000.00:Aceptada | Cambio de escobillas:5000.00:Rechazada | Alineación y balanceo:30000.00:Pendiente',
     'v1: A 45000 Aceptada | B 5000 Rechazada | C 30000 Pendiente',
     (SELECT string_agg(labor || ':' || precio_estimado || ':' || decision_en_esta_version, ' | ' ORDER BY labor_id)
      FROM v_comparacion_versiones WHERE orden_id = 9001 AND version = 1));
SELECT pruebas.verificar('G02-P01-V-04', 'AC-G02-P01-04', 'C vigente en v3 a 25000 y Aceptada',
     (SELECT version_vigente = 3 AND precio_vigente = 25000 AND situacion = 'Aceptada'
      FROM v_situacion_labor WHERE labor_id = pruebas.labor_id(9001, 'Alineación')),
     'C: v3, 25000, Aceptada',
     (SELECT 'C: v' || version_vigente || ', ' || precio_vigente || ', ' || situacion
      FROM v_situacion_labor WHERE labor_id = pruebas.labor_id(9001, 'Alineación')));
SELECT pruebas.verificar('G02-P01-V-04', 'AC-G02-P01-02', 'ninguna decisión anterior fue sobrescrita',
     (SELECT count(*) = 5 FROM autorizacion_labor WHERE orden_id = 9001)
     AND EXISTS (SELECT 1 FROM autorizacion_labor WHERE orden_id = 9001 AND decision = 'Pendiente'),
     '5 decisiones conservadas (incluida la Pendiente de C en v1)',
     (SELECT count(*) || ' decisiones: ' || string_agg(decision, ', ' ORDER BY autorizacion_id) FROM autorizacion_labor WHERE orden_id = 9001));

-- Contexto válido distinto (preparación de las inválidas): la orden 9002,
-- de Transportes del Valle, con Ana Solís DESIGNADA para aprobar.
SELECT fn_cambiar_estado_orden(9002, 'En diagnóstico', 204, NULL, '2026-11-03 09:30');
SELECT fn_publicar_propuesta(9002, NULL,
  '[{"descripcion":"Cambio de filtro de aire","hallazgo_id":4103,"precio_estimado":12000,
     "repuestos":[{"repuesto_id":"MG-001","cantidad":1,"precio_unitario":9000}]}]'::jsonb,
  205, NULL, '2026-11-03 10:30');
SELECT fn_registrar_decision(pruebas.propuesta_id(9002, 1), pruebas.labor_id(9002, 'Cambio de filtro'),
                             104, 'Aceptada', 'Presencial', 201, '2026-11-03 11:00', 'Ana, designada por la empresa');
SELECT f.facultad_id, f.cliente, f.tipo_facultad, f.fuente, f.otorgada_por_cliente_id, f.vigente_desde
FROM v_facultades_orden f WHERE f.orden_id IN (9001, 9002) AND f.tipo_facultad = 'Aprobar' ORDER BY f.orden_id, f.facultad_id;
