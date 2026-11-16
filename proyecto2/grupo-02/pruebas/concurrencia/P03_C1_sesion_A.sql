-- G02-P03-C1 · Sesión A · Dos sesiones reprograman la promesa de la orden 9013.
-- Mecanismo: bloqueo pesimista de la orden (FOR UPDATE) en el trigger del historial.
\set ON_ERROR_STOP off
SET search_path = taller, public;
SET TIME ZONE 'America/Costa_Rica';
\echo 'SESIÓN A – paso 1: BEGIN y reprogramar a dentro de 3 días'
BEGIN;
SELECT to_char(clock_timestamp(), 'HH24:MI:SS.MS') AS a_inicio;
SELECT fn_cambiar_fecha_prometida(9013, date_trunc('hour', now()) + interval '3 days', now(), 'Teléfono', 'Sesión A: espera de repuesto', 201);
\echo 'SESIÓN A – paso 2: retiene el bloqueo 3 s'
SELECT pg_sleep(3);
\echo 'SESIÓN A – paso 3: COMMIT'
COMMIT;
