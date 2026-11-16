-- =====================================================================
-- G02-P02 · ATOMICIDAD
-- Preparación: U (borrado de códigos, 9003) En proceso.
-- =====================================================================
SET search_path = taller, public;
SET TIME ZONE 'America/Costa_Rica';

SELECT repuesto_id, fisico, reservado, disponible FROM v_existencias WHERE repuesto_id IN ('MG-002', 'EL-002') ORDER BY 1;

-- ===========================================================
-- ID: G02-P02-A-01     Criterio: AC-G02-P02-04
-- Acción: en UN bloque: participación válida, consumo válido de 2 L de
--   aceite, consumo de una batería SIN existencias y completar la labor.
-- Esperado: rechazo por existencias y NADA queda: ni participación, ni
--   consumo de aceite, ni movimientos, ni labor completada.
-- ===========================================================
SELECT pruebas.esperar_rechazo('G02-P02-A-01', 'AC-G02-P02-04', 'bloque con consumo sin existencias a mitad',
     $q$ DO $b$ BEGIN
            PERFORM fn_registrar_participacion(pruebas.labor_id(9003, 'Borrado de códigos'), 203,
                    '2026-11-06 08:00', '2026-11-06 08:30', 30, 'Borrado de códigos', 3);
            PERFORM fn_registrar_consumo(9003, pruebas.labor_id(9003, 'Borrado de códigos'), 'MG-002', 2, 7200, 203, '2026-11-06 08:10');
            PERFORM fn_registrar_consumo(9003, pruebas.labor_id(9003, 'Borrado de códigos'), 'EL-002', 1, 52000, 203, '2026-11-06 08:20');
            PERFORM fn_completar_labor(pruebas.labor_id(9003, 'Borrado de códigos'), 203, '2026-11-06 08:40');
         END $b$ $q$,
     'existencias insuficientes de EL-002');
SELECT pruebas.verificar('G02-P02-A-01', 'AC-G02-P02-04', 'ni labor completada ni consumo huérfano',
     (SELECT estado_labor = 'En proceso' FROM labor WHERE labor_id = pruebas.labor_id(9003, 'Borrado de códigos'))
     AND (SELECT count(*) = 0 FROM consumo_repuesto WHERE labor_id = pruebas.labor_id(9003, 'Borrado de códigos'))
     AND (SELECT count(*) = 0 FROM participacion_tecnica WHERE labor_id = pruebas.labor_id(9003, 'Borrado de códigos'))
     AND (SELECT fisico = 20 FROM v_existencias WHERE repuesto_id = 'MG-002'),
     'U En proceso, 0 consumos, 0 participaciones, MG-002 físico 20',
     (SELECT estado_labor FROM labor WHERE labor_id = pruebas.labor_id(9003, 'Borrado de códigos')) || ', '
     || (SELECT count(*) FROM consumo_repuesto WHERE labor_id = pruebas.labor_id(9003, 'Borrado de códigos')) || ' consumos, '
     || (SELECT count(*) FROM participacion_tecnica WHERE labor_id = pruebas.labor_id(9003, 'Borrado de códigos')) || ' participaciones, MG-002 '
     || (SELECT fisico FROM v_existencias WHERE repuesto_id = 'MG-002'));

-- ===========================================================
-- ID: G02-P02-A-02     Criterio: AC-G02-P02-03
-- Acción: en UN bloque: participación cerrada, prueba Desfavorable y
--   completar (no hay retrabajo).
-- Esperado: rechazo "es Desfavorable y no tiene retrabajo completado"; la
--   participación y la prueba del bloque tampoco quedan.
-- ===========================================================
SELECT pruebas.esperar_rechazo('G02-P02-A-02', 'AC-G02-P02-03', 'completar con última prueba Desfavorable',
     $q$ DO $b$ BEGIN
            PERFORM fn_registrar_participacion(pruebas.labor_id(9003, 'Borrado de códigos'), 203,
                    '2026-11-06 08:00', '2026-11-06 08:30', 30, 'Borrado de códigos', 3);
            PERFORM fn_registrar_prueba(pruebas.labor_id(9003, 'Borrado de códigos'), 203, '2026-11-06 08:35',
                    'Prueba de emisiones', 'Desfavorable', 'CO por encima del límite', 1.8, '%');
            PERFORM fn_completar_labor(pruebas.labor_id(9003, 'Borrado de códigos'), 203, '2026-11-06 08:40');
         END $b$ $q$,
     'es Desfavorable y no tiene retrabajo completado');
SELECT pruebas.verificar('G02-P02-A-02', 'AC-G02-P02-03', 'nada quedó del bloque',
     (SELECT count(*) = 0 FROM prueba WHERE labor_id = pruebas.labor_id(9003, 'Borrado de códigos'))
     AND (SELECT count(*) = 0 FROM participacion_tecnica WHERE labor_id = pruebas.labor_id(9003, 'Borrado de códigos')),
     '0 pruebas, 0 participaciones en U',
     (SELECT count(*) FROM prueba WHERE labor_id = pruebas.labor_id(9003, 'Borrado de códigos')) || ' pruebas, '
     || (SELECT count(*) FROM participacion_tecnica WHERE labor_id = pruebas.labor_id(9003, 'Borrado de códigos')) || ' participaciones');

-- ===========================================================
-- ID: G02-P02-A-03     Criterio: AC-G02-P02-04
-- Acción: saltarse la rutina: (a) INSERT de un consumo sin su movimiento
--   (se fuerzan las restricciones diferidas como al COMMIT); (b) movimiento
--   'Consumo' sin consumo de origen; (c) movimiento de Consumo por una
--   cantidad distinta a la del consumo.
-- Esperado: (a) "no tiene su movimiento de inventario"; (b) "requiere el
--   consumo de origen" (trigger) y, sin el trigger, el CHECK
--   ck_movimiento_consumo_origen; (c) "no coincide con la cantidad".
-- ===========================================================
SELECT pruebas.esperar_rechazo('G02-P02-A-03', 'AC-G02-P02-04', 'consumo sin movimiento (al COMMIT)',
     $q$ DO $b$ BEGIN
            INSERT INTO consumo_repuesto (labor_id, orden_id, repuesto_id, cantidad_utilizada, precio_unitario_cargado, fecha_hora, registrado_por_id)
            VALUES (pruebas.labor_id(9003, 'Borrado de códigos'), 9003, 'MG-002', 1, 7200, '2026-11-06 08:10', 203);
            SET CONSTRAINTS ALL IMMEDIATE;
         END $b$ $q$,
     'no tiene su movimiento de inventario');
SELECT pruebas.esperar_rechazo('G02-P02-A-03', 'AC-G02-P02-04', 'movimiento Consumo sin origen',
     $q$ INSERT INTO movimiento_inventario (repuesto_id, orden_id, tipo_movimiento, cantidad, registrado_por_id)
         VALUES ('MG-002', 9003, 'Consumo', 1, 203) $q$,
     'requiere el consumo de origen');
SELECT pruebas.esperar_rechazo('G02-P02-A-03', 'AC-G02-P02-04', 'movimiento Consumo sin origen (solo contra el CHECK)',
     $q$ DO $b$ BEGIN
            ALTER TABLE movimiento_inventario DISABLE TRIGGER trg_movimiento_validar;
            INSERT INTO movimiento_inventario (repuesto_id, orden_id, tipo_movimiento, cantidad, registrado_por_id)
            VALUES ('MG-002', 9003, 'Consumo', 1, 203);
         END $b$ $q$,
     'ck_movimiento_consumo_origen');
SELECT pruebas.esperar_rechazo('G02-P02-A-03', 'AC-G02-P02-04', 'movimiento con cantidad distinta a la del consumo',
     $q$ DO $b$ DECLARE v bigint; BEGIN
            INSERT INTO consumo_repuesto (labor_id, orden_id, repuesto_id, cantidad_utilizada, precio_unitario_cargado, fecha_hora, registrado_por_id)
            VALUES (pruebas.labor_id(9003, 'Borrado de códigos'), 9003, 'MG-002', 1, 7200, '2026-11-06 08:10', 203)
            RETURNING consumo_id INTO v;
            INSERT INTO movimiento_inventario (repuesto_id, orden_id, tipo_movimiento, cantidad, consumo_id, registrado_por_id)
            VALUES ('MG-002', 9003, 'Consumo', 3, v, 203);
         END $b$ $q$,
     'no coincide con la cantidad');
SELECT pruebas.verificar('G02-P02-A-03', 'AC-G02-P02-04', 'todo consumo tiene exactamente su movimiento',
     NOT EXISTS (SELECT 1 FROM consumo_repuesto c
                 WHERE NOT EXISTS (SELECT 1 FROM movimiento_inventario m WHERE m.consumo_id = c.consumo_id))
     AND NOT EXISTS (SELECT 1 FROM movimiento_inventario WHERE tipo_movimiento = 'Consumo' AND consumo_id IS NULL),
     '0 consumos sin movimiento y 0 movimientos de consumo sin origen',
     (SELECT count(*) FROM consumo_repuesto) || ' consumos, '
     || (SELECT count(*) FROM movimiento_inventario WHERE tipo_movimiento = 'Consumo') || ' movimientos de consumo');

-- Cierre válido de U para dejar la orden coherente.
SELECT fn_registrar_participacion(pruebas.labor_id(9003, 'Borrado de códigos'), 203,
       '2026-11-06 08:00', '2026-11-06 08:30', 30, 'Borrado de códigos y prueba', 3);
SELECT fn_registrar_prueba(pruebas.labor_id(9003, 'Borrado de códigos'), 203, '2026-11-06 08:35',
       'Prueba de emisiones', 'Favorable', 'Valores dentro de norma', 0.3, '%');
SELECT fn_completar_labor(pruebas.labor_id(9003, 'Borrado de códigos'), 203, '2026-11-06 08:40');
SELECT labor_id, descripcion, estado_labor FROM labor WHERE orden_id = 9003 ORDER BY labor_id;
