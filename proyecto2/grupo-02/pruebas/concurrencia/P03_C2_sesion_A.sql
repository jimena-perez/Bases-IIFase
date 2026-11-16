-- G02-P03-C2 · Sesión A · Variante OPTIMISTA: A pasa 9013 a 'En diagnóstico'.
\set ON_ERROR_STOP off
SET search_path = taller, public;
SET TIME ZONE 'America/Costa_Rica';
\echo 'SESIÓN A – paso 1: BEGIN y Recibida -> En diagnóstico (esperando Recibida)'
BEGIN;
SELECT fn_cambiar_estado_orden(9013, 'En diagnóstico', 203, NULL, now(), 'Recibida');
\echo 'SESIÓN A – paso 2: retiene el bloqueo 3 s'
SELECT pg_sleep(3);
\echo 'SESIÓN A – paso 3: COMMIT'
COMMIT;
