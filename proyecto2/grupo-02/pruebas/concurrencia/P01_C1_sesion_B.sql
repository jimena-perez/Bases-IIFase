-- G02-P01-C1 · Sesión B · Publica otra versión sobre la orden 9011 mientras A
-- retiene el bloqueo. Esperado: B ESPERA, y al confirmar A obtiene version + 1
-- (ninguna publicación se pierde; UNIQUE (orden_id, version) nunca se viola).
\set ON_ERROR_STOP off
SET search_path = taller, public;
SET TIME ZONE 'America/Costa_Rica';
\echo 'SESIÓN B – paso 1: BEGIN y publicar versión (queda esperando el bloqueo de A)'
BEGIN;
SELECT to_char(clock_timestamp(), 'HH24:MI:SS.MS') AS b_solicita;
SELECT fn_publicar_propuesta(9011, NULL,
  '[{"descripcion":"Revisión de líquido de frenos","precio_estimado":8000}]'::jsonb,
  205, 'Publicada por la sesión B') AS propuesta_b;
SELECT to_char(clock_timestamp(), 'HH24:MI:SS.MS') AS b_obtiene_bloqueo_y_termina;
\echo 'SESIÓN B – paso 2: COMMIT'
COMMIT;
\echo 'Consulta final (datos confirmados)'
SELECT version, estado, observacion FROM propuesta WHERE orden_id = 9011 ORDER BY version;
