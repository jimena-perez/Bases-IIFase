-- G02-P02-C1 · Sesión A · A COMPLETA la labor "Revisión de calipers" (9012)
-- mientras B intenta registrar una participación sobre ella.
-- Mecanismo: todas las rutinas y triggers de ejecución bloquean la fila de
-- la labor (FOR UPDATE).
\set ON_ERROR_STOP off
SET search_path = taller, public;
SET TIME ZONE 'America/Costa_Rica';
\echo 'SESIÓN A – paso 1: BEGIN y completar la labor (toma el bloqueo de la labor)'
BEGIN;
SELECT to_char(clock_timestamp(), 'HH24:MI:SS.MS') AS a_inicio;
SELECT fn_completar_labor(labor_id, 202, now()) FROM labor WHERE orden_id = 9012 AND descripcion = 'Revisión de calipers';
\echo 'SESIÓN A – paso 2: retiene el bloqueo 3 s'
SELECT pg_sleep(3);
\echo 'SESIÓN A – paso 3: COMMIT'
COMMIT;
