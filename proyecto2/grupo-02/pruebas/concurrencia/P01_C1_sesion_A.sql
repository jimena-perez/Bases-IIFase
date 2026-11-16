-- G02-P01-C1 · Sesión A · Dos sesiones publican versión sobre la MISMA orden (9011).
-- Mecanismo: bloqueo pesimista SELECT ... FOR UPDATE de la orden dentro de
-- fn_publicar_propuesta. A toma el bloqueo y lo retiene 3 s antes de confirmar.
\set ON_ERROR_STOP off
SET search_path = taller, public;
SET TIME ZONE 'America/Costa_Rica';
\echo 'SESIÓN A – paso 1: BEGIN y publicar versión (toma el bloqueo de la orden 9011)'
BEGIN;
SELECT to_char(clock_timestamp(), 'HH24:MI:SS.MS') AS a_inicio;
SELECT fn_publicar_propuesta(9011, NULL,
  '[{"descripcion":"Cambio de pastillas delanteras","hallazgo_id":4112,"precio_estimado":30000}]'::jsonb,
  205, 'Publicada por la sesión A') AS propuesta_a;
SELECT version AS version_obtenida_por_a FROM propuesta WHERE orden_id = 9011 AND observacion LIKE '%sesión A';
\echo 'SESIÓN A – paso 2: retiene el bloqueo 3 s (en el video: esperar a que B quede bloqueada)'
SELECT pg_sleep(3);
\echo 'SESIÓN A – paso 3: COMMIT'
COMMIT;
SELECT to_char(clock_timestamp(), 'HH24:MI:SS.MS') AS a_commit;
