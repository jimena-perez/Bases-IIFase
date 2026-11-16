-- =====================================================================
-- IC-4301 · Proyecto 2 · Grupo 02 · Concurrencia — PREPARACIÓN
-- Ejecutar UNA vez, después de sql/run_all.sql (y, si se desea, después de
-- pruebas/run_pruebas.sql: usa solo las órdenes 9011, 9012 y 9013, que la
-- batería no modifica). Deja:
--   9011 (María)  En diagnóstico, sin propuestas           -> P01
--   9012 (Carlos) 3 labores aceptadas En proceso; D3 con una
--                 participación cerrada; FR-003 con 1 unidad -> P02
--   9013 (Ana)    Recibida, promesa 2026-11-12 17:00         -> P03
-- Toda la preparación usa las rutinas de los procesos.
-- =====================================================================
\set ON_ERROR_STOP on
SET search_path = taller, public;
SET TIME ZONE 'America/Costa_Rica';

BEGIN;
SELECT fn_cambiar_estado_orden(9011, 'En diagnóstico', 202, NULL, '2026-11-08 08:40');

SELECT fn_cambiar_estado_orden(9012, 'En diagnóstico', 202, NULL, '2026-11-08 08:50');
SELECT fn_publicar_propuesta(9012, NULL,
  '[{"descripcion":"Cambio de disco delantero izquierdo","hallazgo_id":4113,"precio_estimado":20000,
     "repuestos":[{"repuesto_id":"FR-003","cantidad":1,"precio_unitario":38000}]},
    {"descripcion":"Cambio de disco delantero derecho","hallazgo_id":4113,"precio_estimado":20000,
     "repuestos":[{"repuesto_id":"FR-003","cantidad":1,"precio_unitario":38000}]},
    {"descripcion":"Revisión de calipers","hallazgo_id":4113,"precio_estimado":10000}]'::jsonb,
  205, NULL, '2026-11-08 09:10');
SELECT fn_cambiar_estado_orden(9012, 'Pendiente autorización', 201, NULL, '2026-11-08 09:15');
SELECT fn_registrar_decision(pruebas_p.propuesta_id, l.labor_id, 102, 'Aceptada', 'Teléfono', 201, '2026-11-08 09:30')
FROM labor l CROSS JOIN (SELECT propuesta_id FROM propuesta WHERE orden_id = 9012 AND version = 1) pruebas_p
WHERE l.orden_id = 9012 ORDER BY l.labor_id;
SELECT fn_cambiar_estado_orden(9012, 'Autorizada', 201, NULL, '2026-11-08 09:35');
SELECT fn_cambiar_estado_orden(9012, 'En reparación', 202, NULL, '2026-11-08 10:00');
SELECT fn_iniciar_labor(labor_id, 202, '2026-11-08 10:00') FROM labor WHERE orden_id = 9012 ORDER BY labor_id;
SELECT fn_registrar_participacion(labor_id, 202, '2026-11-08 10:00', '2026-11-08 10:30', 25, 'Revisión de calipers', 1)
FROM labor WHERE orden_id = 9012 AND descripcion = 'Revisión de calipers';
COMMIT;

SELECT orden_id, estado_actual, fecha_prometida_actual FROM orden_trabajo WHERE orden_id IN (9011, 9012, 9013) ORDER BY 1;
SELECT labor_id, descripcion, estado_labor FROM labor WHERE orden_id = 9012 ORDER BY labor_id;
SELECT repuesto_id, fisico, reservado, disponible FROM v_existencias WHERE repuesto_id = 'FR-003';
