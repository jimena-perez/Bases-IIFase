-- G02-P03-C2 · Sesión B · Quiere cancelar la orden creyendo que sigue en 'Recibida'.
-- Esperado: B espera; al obtener el bloqueo ve 'En diagnóstico' y es
-- RECHAZADA explícitamente (conflicto de concurrencia), sin pisar el cambio de A.
\set ON_ERROR_STOP off
SET search_path = taller, public;
SET TIME ZONE 'America/Costa_Rica';
\echo 'SESIÓN B – paso 1: BEGIN y cancelar esperando Recibida (queda esperando)'
BEGIN;
SELECT fn_cambiar_estado_orden(9013, 'Cancelada', 201, 'El cliente desiste', now(), 'Recibida');
\echo 'SESIÓN B – paso 2: COMMIT (tras el error: ROLLBACK)'
COMMIT;
\echo 'Consulta final'
SELECT secuencia, estado_anterior, estado, motivo FROM historial_orden WHERE orden_id = 9013 ORDER BY secuencia;
