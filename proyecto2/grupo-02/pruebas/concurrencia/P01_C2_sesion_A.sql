-- G02-P01-C2 · Sesión A · A ACEPTA y B RECHAZA la MISMA línea a la vez.
-- Mecanismo: fn_registrar_decision bloquea la fila de linea_propuesta
-- (FOR UPDATE); las decisiones quedan serializadas.
\set ON_ERROR_STOP off
SET search_path = taller, public;
SET TIME ZONE 'America/Costa_Rica';
\echo 'SESIÓN A – paso 1: BEGIN y aceptar "Cambio de pastillas delanteras" (v1 de 9011)'
BEGIN;
SELECT to_char(clock_timestamp(), 'HH24:MI:SS.MS') AS a_inicio;
SELECT fn_registrar_decision(p.propuesta_id, l.labor_id, 101, 'Aceptada', 'Teléfono', 201, now(), 'Sesión A: acepta')
FROM propuesta p JOIN linea_propuesta lp USING (propuesta_id) JOIN labor l ON l.labor_id = lp.labor_id
WHERE p.orden_id = 9011 AND p.version = 1;
\echo 'SESIÓN A – paso 2: retiene el bloqueo de la línea 3 s'
SELECT pg_sleep(3);
\echo 'SESIÓN A – paso 3: COMMIT'
COMMIT;
