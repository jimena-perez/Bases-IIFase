-- G02-P03-C1 · Sesión B · Reprograma la misma orden mientras A la tiene bloqueada.
-- Esperado: B espera y se aplica DESPUÉS de A: los dos cambios quedan en la
-- historia en el orden confirmado y el anterior de B es la fecha de A
-- (no hay pérdida silenciosa).
\set ON_ERROR_STOP off
SET search_path = taller, public;
SET TIME ZONE 'America/Costa_Rica';
\echo 'SESIÓN B – paso 1: BEGIN y reprogramar a dentro de 4 días (queda esperando)'
BEGIN;
SELECT to_char(clock_timestamp(), 'HH24:MI:SS.MS') AS b_solicita;
SELECT fn_cambiar_fecha_prometida(9013, date_trunc('hour', now()) + interval '4 days', now(), 'Correo', 'Sesión B: ajuste de agenda del taller', 206);
SELECT to_char(clock_timestamp(), 'HH24:MI:SS.MS') AS b_termina;
\echo 'SESIÓN B – paso 2: COMMIT'
COMMIT;
\echo 'Consulta final'
SELECT secuencia, fecha_anterior, fecha_nueva, medio_comunicacion, motivo FROM historial_fecha_prometida WHERE orden_id = 9013 ORDER BY secuencia;
SELECT orden_id, fecha_prometida_actual FROM orden_trabajo WHERE orden_id = 9013;
