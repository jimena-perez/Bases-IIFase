-- G02-P01-C3 · Sesión A · Variante con control OPTIMISTA: A acepta la línea de v2.
\set ON_ERROR_STOP off
SET search_path = taller, public;
SET TIME ZONE 'America/Costa_Rica';
\echo 'SESIÓN A – paso 1: BEGIN y aceptar "Revisión de líquido de frenos" (v2) esperando "Sin decidir"'
BEGIN;
SELECT fn_registrar_decision(p.propuesta_id, l.labor_id, 101, 'Aceptada', 'Presencial', 201, now(), 'Sesión A', 'Sin decidir')
FROM propuesta p JOIN linea_propuesta lp USING (propuesta_id) JOIN labor l ON l.labor_id = lp.labor_id
WHERE p.orden_id = 9011 AND p.version = 2;
\echo 'SESIÓN A – paso 2: retiene el bloqueo 3 s'
SELECT pg_sleep(3);
\echo 'SESIÓN A – paso 3: COMMIT'
COMMIT;
