-- G02-P02-C2 · Sesión B · Consume la misma última unidad en otra labor.
-- Esperado: B espera el bloqueo del repuesto; al confirmar A ya no hay
-- existencias y B es RECHAZADA; existencia final 0 (nunca negativa) y un
-- solo consumo, con su movimiento.
\set ON_ERROR_STOP off
SET search_path = taller, public;
SET TIME ZONE 'America/Costa_Rica';
\echo 'SESIÓN B – paso 1: BEGIN y consumir 1 FR-003 en "Cambio de disco delantero derecho" (queda esperando)'
BEGIN;
SELECT to_char(clock_timestamp(), 'HH24:MI:SS.MS') AS b_solicita;
SELECT fn_registrar_consumo(9012, labor_id, 'FR-003', 1, 38000, 204, now()) AS consumo_b
FROM labor WHERE orden_id = 9012 AND descripcion = 'Cambio de disco delantero derecho';
\echo 'SESIÓN B – paso 2: COMMIT (tras el error: ROLLBACK)'
COMMIT;
\echo 'Consulta final'
SELECT repuesto_id, fisico, reservado, disponible FROM v_existencias WHERE repuesto_id = 'FR-003';
SELECT c.consumo_id, l.descripcion, c.cantidad_utilizada, m.movimiento_id, m.tipo_movimiento
FROM consumo_repuesto c JOIN labor l USING (labor_id) LEFT JOIN movimiento_inventario m ON m.consumo_id = c.consumo_id
WHERE c.repuesto_id = 'FR-003';
