-- G02-P02-C1 · Sesión B · Registra una participación en la labor que A está completando.
-- Esperado: B espera; al confirmar A la labor ya está Completada y B es
-- RECHAZADA; ninguna participación se pierde (la de A se conserva) ni queda
-- una participación sobre una labor completada.
\set ON_ERROR_STOP off
SET search_path = taller, public;
SET TIME ZONE 'America/Costa_Rica';
\echo 'SESIÓN B – paso 1: BEGIN y registrar participación (queda esperando)'
BEGIN;
SELECT to_char(clock_timestamp(), 'HH24:MI:SS.MS') AS b_solicita;
SELECT fn_registrar_participacion(labor_id, 204, now() - interval '20 minutes', now() - interval '5 minutes', 10,
                                  'Ajuste adicional (sesión B)', 4)
FROM labor WHERE orden_id = 9012 AND descripcion = 'Revisión de calipers';
\echo 'SESIÓN B – paso 2: COMMIT (tras el error: ROLLBACK)'
COMMIT;
\echo 'Consulta final'
SELECT l.labor_id, l.descripcion, l.estado_labor,
       (SELECT count(*) FROM participacion_tecnica p WHERE p.labor_id = l.labor_id) AS participaciones
FROM labor l WHERE l.orden_id = 9012 AND l.descripcion = 'Revisión de calipers';
