-- =====================================================================
-- G02-P02 · Ejecutar reparaciones y pruebas · VÁLIDAS
-- Orden: 9003 (Carlos Méndez, VW Jetta DEF456). Reserva previa de 1 juego
-- de pastillas FR-001. Hallazgos: 4104 frenos, 4105 sensor de oxígeno.
-- Las autorizaciones se obtienen con el proceso P01 real (no precargadas).
-- =====================================================================
SET search_path = taller, public;
SET TIME ZONE 'America/Costa_Rica';

-- ---------------------------------------------------------------------
-- Preparación vía P01 y P03: v1 con 6 labores; Carlos acepta 5 y rechaza 1.
--   P  pastillas (requiere repuesto FR-001)      Q  purga (requiere P)
--   S  sensor de oxígeno                          U  borrado de códigos (requiere S)
--   K  limpieza de inyectores (será RECHAZADA)    W  freno de mano (sin repuestos)
-- ---------------------------------------------------------------------
SELECT fn_cambiar_estado_orden(9003, 'En diagnóstico', 202, NULL, '2026-11-04 08:30');
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
SELECT fn_cambiar_estado_orden(9003, 'Pendiente autorización', 206, NULL, '2026-11-04 10:05');
SELECT fn_registrar_decision(pruebas.propuesta_id(9003, 1), l.labor_id, 102,
                             CASE WHEN l.descripcion LIKE 'Limpieza%' THEN 'Rechazada' ELSE 'Aceptada' END,
                             'Correo', 206, '2026-11-04 10:30')
FROM labor l WHERE l.orden_id = 9003 ORDER BY l.labor_id;
SELECT fn_cambiar_estado_orden(9003, 'Autorizada', 206, NULL, '2026-11-04 10:40');
SELECT fn_cambiar_estado_orden(9003, 'En reparación', 202, NULL, '2026-11-04 13:00');
SELECT labor_id, descripcion, situacion, autorizacion_id FROM v_situacion_labor WHERE orden_id = 9003 ORDER BY labor_id;

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
SELECT fn_iniciar_labor(pruebas.labor_id(9003, 'Cambio de pastillas'), 202, '2026-11-04 13:00');
SELECT fn_registrar_participacion(pruebas.labor_id(9003, 'Cambio de pastillas'), 202,
       '2026-11-04 13:00', '2026-11-04 14:30', 85, 'Desmontaje y cambio de pastillas', 1);
SELECT fn_registrar_participacion(pruebas.labor_id(9003, 'Cambio de pastillas'), 204,
       '2026-11-04 14:30', '2026-11-04 15:15', 45, 'Medición de discos y montaje de ruedas', 4);
SELECT fn_registrar_consumo(9003, pruebas.labor_id(9003, 'Cambio de pastillas'), 'FR-001', 1, 25000, 202, '2026-11-04 14:00');
SELECT fn_registrar_prueba(pruebas.labor_id(9003, 'Cambio de pastillas'), 202, '2026-11-04 15:30',
       'Prueba de frenado en pista', 'Desfavorable',
       'Distancia de frenado a 80 km/h superior a lo esperado (< 42 m); vibración en el pedal', 48.5, 'm');
SELECT fn_registrar_retrabajo(pruebas.labor_id(9003, 'Cambio de pastillas'),
       (SELECT prueba_id FROM prueba WHERE labor_id = pruebas.labor_id(9003, 'Cambio de pastillas') AND resultado = 'Desfavorable'),
       'Rectificado de discos delanteros (retrabajo)', 205, '2026-11-04 15:45');
-- El retrabajo NO queda cubierto por la autorización original: línea propia (precio 0) y decisión.
SELECT fn_publicar_propuesta(9003, pruebas.propuesta_id(9003, 1),
       ('[{"labor_id":' || pruebas.labor_id(9003, 'Rectificado') || ',"precio_estimado":0,
           "alcance":"Retrabajo sin costo para el cliente"}]')::jsonb,
       205, 'Retrabajo por prueba desfavorable', '2026-11-04 16:00');
SELECT fn_registrar_decision(pruebas.propuesta_id(9003, 2), pruebas.labor_id(9003, 'Rectificado'),
       102, 'Aceptada', 'Teléfono', 206, '2026-11-04 16:15', 'Acepta el retrabajo sin costo');
SELECT fn_iniciar_labor(pruebas.labor_id(9003, 'Rectificado'), 202, '2026-11-05 08:00');
SELECT fn_registrar_participacion(pruebas.labor_id(9003, 'Rectificado'), 202,
       '2026-11-05 08:00', '2026-11-05 09:00', 55, 'Rectificado en torno y montaje', 1);
SELECT fn_registrar_prueba(pruebas.labor_id(9003, 'Rectificado'), 202, '2026-11-05 09:10',
       'Prueba de frenado en pista', 'Favorable', 'Distancia de frenado dentro de lo esperado; sin vibración', 38.2, 'm');
SELECT fn_completar_labor(pruebas.labor_id(9003, 'Rectificado'), 202, '2026-11-05 09:20');
SELECT fn_completar_labor(pruebas.labor_id(9003, 'Cambio de pastillas'), 202, '2026-11-05 09:30');
COMMIT;

-- Lectura posterior (nueva transacción).
SELECT * FROM v_historia_labor WHERE orden_id = 9003 AND (labor LIKE 'Cambio de pastillas%' OR labor LIKE 'Rectificado%') ORDER BY labor_id, secuencia;
SELECT * FROM v_participaciones WHERE orden_id = 9003 ORDER BY participacion_id;
SELECT * FROM v_pruebas WHERE orden_id = 9003 ORDER BY prueba_id;
SELECT * FROM v_retrabajos WHERE orden_id = 9003;

SELECT pruebas.verificar('G02-P02-V-01', 'AC-G02-P02-01', 'P inició con SU autorización aplicable Aceptada',
     (SELECT h.autorizacion_id = s.autorizacion_id FROM historial_labor h JOIN v_situacion_labor s USING (labor_id)
      WHERE h.labor_id = pruebas.labor_id(9003, 'Cambio de pastillas') AND h.estado_nuevo = 'En proceso'),
     'autorizacion_id del inicio = decisión aplicable',
     (SELECT 'inicio con autorizacion_id ' || autorizacion_id FROM historial_labor
      WHERE labor_id = pruebas.labor_id(9003, 'Cambio de pastillas') AND estado_nuevo = 'En proceso'));
SELECT pruebas.verificar('G02-P02-V-01', 'AC-G02-P02-02', '2 técnicos; efectivo (85) menor que el intervalo (90)',
     (SELECT count(DISTINCT tecnico) = 2 AND bool_or(minutos_efectivos < minutos_intervalo)
      FROM v_participaciones WHERE labor_id = pruebas.labor_id(9003, 'Cambio de pastillas')),
     '2 técnicos, uno con 85 de 90 minutos',
     (SELECT string_agg(tecnico || ' ' || minutos_efectivos || '/' || minutos_intervalo, '; ' ORDER BY participacion_id)
      FROM v_participaciones WHERE labor_id = pruebas.labor_id(9003, 'Cambio de pastillas')));
SELECT pruebas.verificar('G02-P02-V-01', 'AC-G02-P02-03', 'retrabajo ligado a P y a la prueba Desfavorable; ambos Completados',
     (SELECT estado_retrabajo = 'Completada' AND estado_labor_revisada = 'Completada' AND resultado_prueba_origen = 'Desfavorable'
      FROM v_retrabajos WHERE labor_revisada_id = pruebas.labor_id(9003, 'Cambio de pastillas')),
     'retrabajo Completada, P Completada, origen Desfavorable',
     (SELECT 'retrabajo ' || estado_retrabajo || ', P ' || estado_labor_revisada || ', origen ' || resultado_prueba_origen
      FROM v_retrabajos WHERE labor_revisada_id = pruebas.labor_id(9003, 'Cambio de pastillas')));
SELECT pruebas.verificar('G02-P02-V-01', 'AC-G02-P02-03', 'la intervención original y su prueba Desfavorable se conservan',
     (SELECT count(*) = 2 FROM prueba WHERE labor_id = pruebas.labor_id(9003, 'Cambio de pastillas') OR labor_id = pruebas.labor_id(9003, 'Rectificado'))
     AND (SELECT count(*) = 2 FROM participacion_tecnica WHERE labor_id = pruebas.labor_id(9003, 'Cambio de pastillas')),
     '2 pruebas (Desfavorable + Favorable) y 2 participaciones de P intactas',
     (SELECT string_agg(resultado, ' + ' ORDER BY prueba_id) FROM prueba WHERE orden_id = 9003));
SELECT pruebas.verificar('G02-P02-V-01', 'AC-G02-P02-04', 'consumo con movimiento y liberación de la reserva',
     (SELECT count(*) = 1 FROM movimiento_inventario m JOIN consumo_repuesto c USING (consumo_id)
      WHERE c.labor_id = pruebas.labor_id(9003, 'Cambio de pastillas') AND m.tipo_movimiento = 'Consumo')
     AND (SELECT fisico = 9 AND reservado = 0 AND disponible = 9 FROM v_existencias WHERE repuesto_id = 'FR-001'),
     'FR-001: físico 9, reservado 0, disponible 9',
     (SELECT 'FR-001: físico ' || fisico || ', reservado ' || reservado || ', disponible ' || disponible FROM v_existencias WHERE repuesto_id = 'FR-001'));

-- ===========================================================
-- ID: G02-P02-V-02     Criterio: AC-G02-P02-01, AC-G02-P02-04
-- Preparación: Q depende de P (ya Completada).
-- Acción: iniciar Q, participación, consumo de líquido de frenos, prueba
--   con medición y completar.
-- Esperado: Q Completada; la dependencia se respetó; propuesto vs ejecutado.
-- ===========================================================
SELECT fn_iniciar_labor(pruebas.labor_id(9003, 'Purga'), 204, '2026-11-05 09:40');
SELECT fn_registrar_participacion(pruebas.labor_id(9003, 'Purga'), 204, '2026-11-05 09:40', '2026-11-05 10:20', 40,
       'Purga por las cuatro ruedas', 4);
SELECT fn_registrar_consumo(9003, pruebas.labor_id(9003, 'Purga'), 'FR-002', 1, 6500, 204, '2026-11-05 09:50');
SELECT fn_registrar_prueba(pruebas.labor_id(9003, 'Purga'), 204, '2026-11-05 10:25', 'Prueba de recorrido del pedal',
       'Favorable', 'Pedal firme, sin aire en el circuito', 35, 'mm');
SELECT fn_completar_labor(pruebas.labor_id(9003, 'Purga'), 204, '2026-11-05 10:30');

SELECT * FROM v_propuesto_vs_ejecutado WHERE orden_id = 9003 ORDER BY labor_id;
SELECT * FROM v_insumos_orden WHERE orden_id = 9003 ORDER BY concepto, referencia;
SELECT pruebas.verificar('G02-P02-V-02', 'AC-G02-P02-04', 'propuesto vs ejecutado de P y Q',
     (SELECT string_agg(repuestos_estimados || '/' || repuestos_consumidos || '/' || minutos_efectivos, ',' ORDER BY labor_id)
      FROM v_propuesto_vs_ejecutado WHERE labor_id IN (pruebas.labor_id(9003, 'Cambio de pastillas'), pruebas.labor_id(9003, 'Purga')))
     = '25000.0000/25000.0000/130,6500.0000/6500.0000/40',
     'P 25000/25000/130 min; Q 6500/6500/40 min',
     (SELECT string_agg(repuestos_estimados || '/' || repuestos_consumidos || '/' || minutos_efectivos, ',' ORDER BY labor_id)
      FROM v_propuesto_vs_ejecutado WHERE labor_id IN (pruebas.labor_id(9003, 'Cambio de pastillas'), pruebas.labor_id(9003, 'Purga'))));
