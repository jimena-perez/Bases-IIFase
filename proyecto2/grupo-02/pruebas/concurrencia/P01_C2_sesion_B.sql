-- G02-P01-C2 · Sesión B · Rechaza la misma línea mientras A la tiene bloqueada.
-- Esperado: B espera; al confirmar A, B registra su decisión DESPUÉS. Ambas
-- filas se conservan y la decisión aplicable es la última confirmada (B).
\set ON_ERROR_STOP off
SET search_path = taller, public;
SET TIME ZONE 'America/Costa_Rica';
\echo 'SESIÓN B – paso 1: BEGIN y rechazar la misma línea (queda esperando)'
BEGIN;
SELECT to_char(clock_timestamp(), 'HH24:MI:SS.MS') AS b_solicita;
SELECT fn_registrar_decision(p.propuesta_id, l.labor_id, 101, 'Rechazada', 'Correo', 201, now(), 'Sesión B: rechaza')
FROM propuesta p JOIN linea_propuesta lp USING (propuesta_id) JOIN labor l ON l.labor_id = lp.labor_id
WHERE p.orden_id = 9011 AND p.version = 1;
SELECT to_char(clock_timestamp(), 'HH24:MI:SS.MS') AS b_termina;
\echo 'SESIÓN B – paso 2: COMMIT'
COMMIT;
\echo 'Consulta final: historia de decisiones de la línea y decisión aplicable'
SELECT a.autorizacion_id, a.decision, a.medio, a.observacion, to_char(a.registrado_en, 'HH24:MI:SS.MS') AS confirmada_en
FROM autorizacion_labor a JOIN propuesta p USING (propuesta_id) WHERE p.orden_id = 9011 AND p.version = 1 ORDER BY a.autorizacion_id;
SELECT labor_id, descripcion, version_vigente, situacion, autorizacion_id FROM v_situacion_labor WHERE orden_id = 9011 ORDER BY labor_id;
