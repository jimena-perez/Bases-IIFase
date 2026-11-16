-- G02-P02-C2 · Sesión A · Dos consumos simultáneos de la ÚLTIMA unidad de FR-003
-- en dos labores distintas de 9012. Mecanismo: el trigger de inventario
-- bloquea la fila del repuesto (FOR UPDATE) y recalcula existencias.
\set ON_ERROR_STOP off
SET search_path = taller, public;
SET TIME ZONE 'America/Costa_Rica';
\echo 'SESIÓN A – paso 1: BEGIN y consumir 1 FR-003 en "Cambio de disco delantero izquierdo"'
BEGIN;
SELECT to_char(clock_timestamp(), 'HH24:MI:SS.MS') AS a_inicio;
SELECT fn_registrar_consumo(9012, labor_id, 'FR-003', 1, 38000, 202, now()) AS consumo_a
FROM labor WHERE orden_id = 9012 AND descripcion = 'Cambio de disco delantero izquierdo';
\echo 'SESIÓN A – paso 2: retiene el bloqueo del repuesto 3 s'
SELECT pg_sleep(3);
\echo 'SESIÓN A – paso 3: COMMIT'
COMMIT;
