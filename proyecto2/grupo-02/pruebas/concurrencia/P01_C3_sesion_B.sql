-- G02-P01-C3 · Sesión B · Rechaza la misma línea indicando que esperaba "Sin decidir".
-- Esperado: B espera el bloqueo; al ver que la decisión vigente ya es
-- "Aceptada", se RECHAZA explícitamente (no sobrescribe en silencio).
\set ON_ERROR_STOP off
SET search_path = taller, public;
SET TIME ZONE 'America/Costa_Rica';
\echo 'SESIÓN B – paso 1: BEGIN y rechazar esperando "Sin decidir" (queda esperando)'
BEGIN;
SELECT fn_registrar_decision(p.propuesta_id, l.labor_id, 101, 'Rechazada', 'Teléfono', 201, now(), 'Sesión B', 'Sin decidir')
FROM propuesta p JOIN linea_propuesta lp USING (propuesta_id) JOIN labor l ON l.labor_id = lp.labor_id
WHERE p.orden_id = 9011 AND p.version = 2;
\echo 'SESIÓN B – paso 2: COMMIT (tras el error, PostgreSQL revierte: ROLLBACK)'
COMMIT;
\echo 'Consulta final: solo quedó la decisión de A'
SELECT a.autorizacion_id, a.decision, a.observacion FROM autorizacion_labor a JOIN propuesta p USING (propuesta_id)
WHERE p.orden_id = 9011 AND p.version = 2 ORDER BY a.autorizacion_id;
