-- =====================================================================
-- G02-P02 · Ejecutar reparaciones y pruebas · INVÁLIDAS
-- Orden 9003: K Rechazada, U depende de S, S se inicia aquí (válido) para
-- servir de labor En proceso; la orden 9001 es el "contexto ajeno".
-- Tras cada intento se comprueba que el estado no avanzó ni quedaron filas.
-- =====================================================================
SET search_path = taller, public;
SET TIME ZONE 'America/Costa_Rica';

-- ===========================================================
-- ID: G02-P02-I-01     Criterio: AC-G02-P02-01
-- Preparación: K fue RECHAZADA por Carlos en v1; P ya está Completada.
-- Acción: iniciar K (por la rutina y por INSERT directo citando la
--   autorización Rechazada) e iniciar de nuevo P.
-- Esperado: rechazos; K sigue Pendiente con 1 fila de historial.
-- ===========================================================
SELECT pruebas.esperar_rechazo('G02-P02-I-01', 'AC-G02-P02-01', 'iniciar labor rechazada',
     $q$ SELECT fn_iniciar_labor(pruebas.labor_id(9003, 'Limpieza de inyectores'), 202, '2026-11-05 11:00') $q$,
     'situación: Rechazada');
SELECT pruebas.esperar_rechazo('G02-P02-I-01', 'AC-G02-P02-01', 'INSERT directo citando la autorización Rechazada',
     $q$ INSERT INTO historial_labor (labor_id, estado_nuevo, fecha_hora, personal_id, autorizacion_id)
         SELECT labor_id, 'En proceso', '2026-11-05 11:00', 202, autorizacion_id
         FROM v_situacion_labor WHERE labor_id = pruebas.labor_id(9003, 'Limpieza de inyectores') $q$,
     'no es la decisión aplicable Aceptada');
SELECT pruebas.esperar_rechazo('G02-P02-I-01', 'AC-G02-P02-01', 'INSERT directo citando la autorización de OTRA labor',
     $q$ INSERT INTO historial_labor (labor_id, estado_nuevo, fecha_hora, personal_id, autorizacion_id)
         SELECT pruebas.labor_id(9003, 'Limpieza de inyectores'), 'En proceso', '2026-11-05 11:00', 202, autorizacion_id
         FROM v_situacion_labor WHERE labor_id = pruebas.labor_id(9003, 'Sustitución del sensor') $q$,
     'no es la decisión aplicable Aceptada');
-- Defensa en profundidad: con el trigger desactivado (solo dentro de la
-- subtransacción de la prueba), la FK compuesta (autorizacion_id, labor_id)
-- impide citar la autorización de otra labor.
SELECT pruebas.esperar_rechazo('G02-P02-I-01', 'AC-G02-P02-01', 'misma inserción solo contra la FK compuesta',
     $q$ DO $b$ BEGIN
            ALTER TABLE historial_labor DISABLE TRIGGER trg_historial_labor_antes;
            INSERT INTO historial_labor (labor_id, secuencia, estado_anterior, estado_nuevo, fecha_hora, personal_id, autorizacion_id)
            SELECT pruebas.labor_id(9003, 'Limpieza de inyectores'), 2, 'Pendiente', 'En proceso', '2026-11-05 11:00', 202, autorizacion_id
            FROM v_situacion_labor WHERE labor_id = pruebas.labor_id(9003, 'Sustitución del sensor');
         END $b$ $q$,
     'fk_historial_labor_autorizacion');
SELECT pruebas.esperar_rechazo('G02-P02-I-01', 'AC-G02-P02-01', 'reiniciar una labor Completada',
     $q$ SELECT fn_iniciar_labor(pruebas.labor_id(9003, 'Cambio de pastillas'), 202, '2026-11-05 11:00') $q$,
     'está Completada y no puede iniciarse');
SELECT pruebas.verificar('G02-P02-I-01', 'AC-G02-P02-01', 'K no avanzó',
     (SELECT estado_labor = 'Pendiente' FROM labor WHERE labor_id = pruebas.labor_id(9003, 'Limpieza de inyectores'))
     AND (SELECT count(*) = 1 FROM historial_labor WHERE labor_id = pruebas.labor_id(9003, 'Limpieza de inyectores')),
     'K Pendiente con 1 fila de historial',
     (SELECT estado_labor FROM labor WHERE labor_id = pruebas.labor_id(9003, 'Limpieza de inyectores')) || ' con '
     || (SELECT count(*) FROM historial_labor WHERE labor_id = pruebas.labor_id(9003, 'Limpieza de inyectores')) || ' fila(s)');

-- ===========================================================
-- ID: G02-P02-I-02     Criterio: AC-G02-P02-01
-- Preparación: U (aceptada) depende de S, que no está Completada.
-- Acción: iniciar U.
-- Esperado: rechazo "depende de la labor ..., que no está Completada".
-- ===========================================================
SELECT pruebas.esperar_rechazo('G02-P02-I-02', 'AC-G02-P02-01', 'iniciar labor con dependencia sin completar',
     $q$ SELECT fn_iniciar_labor(pruebas.labor_id(9003, 'Borrado de códigos'), 203, '2026-11-05 11:00') $q$,
     'que no está Completada');
SELECT pruebas.verificar('G02-P02-I-02', 'AC-G02-P02-01', 'U sigue Pendiente',
     (SELECT estado_labor = 'Pendiente' FROM labor WHERE labor_id = pruebas.labor_id(9003, 'Borrado de códigos')),
     'Pendiente', (SELECT estado_labor FROM labor WHERE labor_id = pruebas.labor_id(9003, 'Borrado de códigos')));

-- Preparación válida para el resto: S pasa a En proceso.
SELECT fn_iniciar_labor(pruebas.labor_id(9003, 'Sustitución del sensor'), 203, '2026-11-05 11:00');

-- ===========================================================
-- ID: G02-P02-I-03     Criterio: AC-G02-P02-02
-- Acción: participación en S con un técnico INEXISTENTE (999).
-- Esperado: rechazo "el personal 999 no existe"; 0 participaciones en S.
-- ===========================================================
SELECT pruebas.esperar_rechazo('G02-P02-I-03', 'AC-G02-P02-02', 'participación con técnico inexistente',
     $q$ SELECT fn_registrar_participacion(pruebas.labor_id(9003, 'Sustitución del sensor'), 999,
                '2026-11-05 11:00', '2026-11-05 11:30', 30, 'Intento con técnico inexistente') $q$,
     'el personal 999 no existe');

-- ===========================================================
-- ID: G02-P02-I-04     Criterio: AC-G02-P02-02
-- Preparación: 201 existe pero es de Recepción; 207 es técnica INACTIVA;
--   la especialidad 3 es de Sofía (203), no de Diego (202); la 5 (Frenos de
--   Andrés) venció el 2025-12-31.
-- Acción: participaciones con cada uno de esos contextos válidos distintos.
-- Esperado: rechazo por rol, por inactividad, por especialidad de otro
--   técnico y por especialidad vencida.
-- ===========================================================
SELECT pruebas.esperar_rechazo('G02-P02-I-04', 'AC-G02-P02-02', 'participación de personal que no es técnico',
     $q$ SELECT fn_registrar_participacion(pruebas.labor_id(9003, 'Sustitución del sensor'), 201,
                '2026-11-05 11:00', '2026-11-05 11:30', 30, 'Recepcionista intentando participar') $q$,
     'tiene rol Recepción y se requiere Técnico');
SELECT pruebas.esperar_rechazo('G02-P02-I-04', 'AC-G02-P02-02', 'participación de técnica inactiva',
     $q$ SELECT fn_registrar_participacion(pruebas.labor_id(9003, 'Sustitución del sensor'), 207,
                '2026-11-05 11:00', '2026-11-05 11:30', 30, 'Técnica inactiva') $q$,
     'no está activo');
SELECT pruebas.esperar_rechazo('G02-P02-I-04', 'AC-G02-P02-02', 'especialidad de otro técnico',
     $q$ SELECT fn_registrar_participacion(pruebas.labor_id(9003, 'Sustitución del sensor'), 202,
                '2026-11-05 11:00', '2026-11-05 11:30', 30, 'Diego con la especialidad de Sofía', 3) $q$,
     'la especialidad 3 no está vigente para el técnico 202');
SELECT pruebas.esperar_rechazo('G02-P02-I-04', 'AC-G02-P02-02', 'especialidad vencida',
     $q$ SELECT fn_registrar_participacion(pruebas.labor_id(9003, 'Sustitución del sensor'), 204,
                '2026-11-05 11:00', '2026-11-05 11:30', 30, 'Andrés con Frenos vencida', 5) $q$,
     'la especialidad 5 no está vigente');
SELECT pruebas.esperar_rechazo('G02-P02-I-04', 'AC-G02-P02-02', 'participación antes de iniciar la labor',
     $q$ SELECT fn_registrar_participacion(pruebas.labor_id(9003, 'Sustitución del sensor'), 203,
                '2026-11-05 10:00', '2026-11-05 10:30', 30, 'Antes del inicio') $q$,
     'no puede iniciar antes de que la labor');
SELECT pruebas.verificar('G02-P02-I-04', 'AC-G02-P02-02', 'S sin participaciones',
     (SELECT count(*) = 0 FROM participacion_tecnica WHERE labor_id = pruebas.labor_id(9003, 'Sustitución del sensor')),
     '0 participaciones', (SELECT count(*) || ' participaciones' FROM participacion_tecnica WHERE labor_id = pruebas.labor_id(9003, 'Sustitución del sensor')));

-- ===========================================================
-- ID: G02-P02-I-05     Criterio: AC-G02-P02-04
-- Acción: cargar a la orden 9001 un consumo de la labor S (que es de 9003),
--   por la rutina y por INSERT directo.
-- Esperado: la rutina responde "no pertenece a la orden 9001"; el INSERT
--   falla por la FK compuesta fk_consumo_labor. 0 consumos/movimientos.
-- ===========================================================
SELECT pruebas.esperar_rechazo('G02-P02-I-05', 'AC-G02-P02-04', 'consumo sobre labor de otra orden (rutina)',
     $q$ SELECT fn_registrar_consumo(9001, pruebas.labor_id(9003, 'Sustitución del sensor'), 'EL-001', 1, 41000, 203, '2026-11-05 11:10') $q$,
     'no pertenece a la orden 9001');
SELECT pruebas.esperar_rechazo('G02-P02-I-05', 'AC-G02-P02-04', 'consumo sobre labor de otra orden (INSERT directo)',
     $q$ INSERT INTO consumo_repuesto (labor_id, orden_id, repuesto_id, cantidad_utilizada, precio_unitario_cargado, registrado_por_id)
         VALUES (pruebas.labor_id(9003, 'Sustitución del sensor'), 9001, 'EL-001', 1, 41000, 203) $q$,
     'fk_consumo_labor');

-- ===========================================================
-- ID: G02-P02-I-06     Criterio: AC-G02-P02-04
-- Preparación: EL-002 (batería) no tiene existencias.
-- Acción: consumir 1 unidad en S.
-- Esperado: rechazo "existencias insuficientes"; no queda consumo ni
--   movimiento (ni consumo sin movimiento, ni movimiento sin origen).
-- ===========================================================
SELECT pruebas.esperar_rechazo('G02-P02-I-06', 'AC-G02-P02-04', 'consumo sin existencias',
     $q$ SELECT fn_registrar_consumo(9003, pruebas.labor_id(9003, 'Sustitución del sensor'), 'EL-002', 1, 52000, 203, '2026-11-05 11:10') $q$,
     'existencias insuficientes de EL-002');
SELECT pruebas.verificar('G02-P02-I-06', 'AC-G02-P02-04', 'sin consumo ni movimiento de EL-002',
     (SELECT count(*) = 0 FROM consumo_repuesto WHERE labor_id = pruebas.labor_id(9003, 'Sustitución del sensor'))
     AND (SELECT count(*) = 0 FROM movimiento_inventario WHERE repuesto_id = 'EL-002'),
     '0 consumos en S, 0 movimientos de EL-002',
     (SELECT count(*) FROM consumo_repuesto WHERE labor_id = pruebas.labor_id(9003, 'Sustitución del sensor')) || ' consumos, '
     || (SELECT count(*) FROM movimiento_inventario WHERE repuesto_id = 'EL-002') || ' movimientos');

-- ===========================================================
-- ID: G02-P02-I-07     Criterio: AC-G02-P02-03
-- Acción: completar S, que no tiene ninguna participación.
-- Esperado: rechazo "sin participación técnica cerrada"; S sigue En proceso.
-- ===========================================================
SELECT pruebas.esperar_rechazo('G02-P02-I-07', 'AC-G02-P02-03', 'completar sin participación',
     $q$ SELECT fn_completar_labor(pruebas.labor_id(9003, 'Sustitución del sensor'), 203, '2026-11-05 11:20') $q$,
     'sin participación técnica cerrada');
SELECT pruebas.verificar('G02-P02-I-07', 'AC-G02-P02-03', 'S sigue En proceso',
     (SELECT estado_labor = 'En proceso' FROM labor WHERE labor_id = pruebas.labor_id(9003, 'Sustitución del sensor')),
     'En proceso', (SELECT estado_labor FROM labor WHERE labor_id = pruebas.labor_id(9003, 'Sustitución del sensor')));

-- ===========================================================
-- ID: G02-P02-I-08     Criterio: AC-G02-P02-01
-- Acción: participación, prueba y consumo sobre K (no está En proceso).
-- Esperado: rechazo "no está En proceso".
-- ===========================================================
SELECT pruebas.esperar_rechazo('G02-P02-I-08', 'AC-G02-P02-01', 'participación en labor no iniciada',
     $q$ SELECT fn_registrar_participacion(pruebas.labor_id(9003, 'Limpieza de inyectores'), 202,
                '2026-11-05 11:00', '2026-11-05 11:30', 30, 'Sin autorización') $q$,
     'no está En proceso');
SELECT pruebas.esperar_rechazo('G02-P02-I-08', 'AC-G02-P02-01', 'prueba en labor no iniciada',
     $q$ SELECT fn_registrar_prueba(pruebas.labor_id(9003, 'Limpieza de inyectores'), 202, '2026-11-05 11:00',
                'Prueba', 'Favorable', 'Sin autorización') $q$,
     'no está En proceso');
SELECT pruebas.esperar_rechazo('G02-P02-I-08', 'AC-G02-P02-01', 'consumo en labor no iniciada',
     $q$ SELECT fn_registrar_consumo(9003, pruebas.labor_id(9003, 'Limpieza de inyectores'), 'MG-002', 1, 7200, 202, '2026-11-05 11:00') $q$,
     'no está En proceso');

-- ===========================================================
-- ID: G02-P02-I-09     Criterio: AC-G02-P02-02
-- Acción: minutos efectivos mayores que el intervalo (61 en 60 min) y un
--   técnico en dos intervenciones superpuestas.
-- Esperado: rechazo por ck_participacion_minutos y por
--   ex_participacion_tecnico.
-- ===========================================================
SELECT pruebas.esperar_rechazo('G02-P02-I-09', 'AC-G02-P02-02', 'efectivos > intervalo',
     $q$ SELECT fn_registrar_participacion(pruebas.labor_id(9003, 'Sustitución del sensor'), 203,
                '2026-11-05 11:00', '2026-11-05 12:00', 61, 'Minutos inflados', 3) $q$,
     'ck_participacion_minutos');
SELECT pruebas.esperar_rechazo('G02-P02-I-09', 'AC-G02-P02-02', 'técnico en dos intervenciones a la vez',
     $q$ DO $b$ BEGIN
            PERFORM fn_registrar_participacion(pruebas.labor_id(9003, 'Sustitución del sensor'), 203,
                    '2026-11-05 11:00', '2026-11-05 12:00', 50, 'Cambio del sensor', 3);
            PERFORM fn_registrar_participacion(pruebas.labor_id(9003, 'Sustitución del sensor'), 203,
                    '2026-11-05 11:30', '2026-11-05 11:45', 15, 'Superpuesta', 3);
         END $b$ $q$,
     'ex_participacion_tecnico');

-- ===========================================================
-- ID: G02-P02-I-10     Criterio: AC-G02-P02-03
-- Acción: reescribir la historia: UPDATE del estado o la descripción de una
--   labor, DELETE de una labor, UPDATE de una prueba, DELETE de un consumo,
--   UPDATE de una participación cerrada.
-- Esperado: todos rechazados (RN-15: revisar sin borrar).
-- ===========================================================
SELECT pruebas.esperar_rechazo('G02-P02-I-10', 'AC-G02-P02-03', 'UPDATE directo del estado de una labor',
     $q$ UPDATE labor SET estado_labor = 'Completada' WHERE labor_id = pruebas.labor_id(9003, 'Sustitución del sensor') $q$,
     'solo cambia mediante historial_labor');
SELECT pruebas.esperar_rechazo('G02-P02-I-10', 'AC-G02-P02-03', 'UPDATE de la descripción de una labor',
     $q$ UPDATE labor SET descripcion = 'Otra cosa' WHERE labor_id = pruebas.labor_id(9003, 'Cambio de pastillas') $q$,
     'no se reescribe');
SELECT pruebas.esperar_rechazo('G02-P02-I-10', 'AC-G02-P02-03', 'DELETE de una labor',
     $q$ DELETE FROM labor WHERE labor_id = pruebas.labor_id(9003, 'Limpieza de inyectores') $q$,
     'no se elimina');
SELECT pruebas.esperar_rechazo('G02-P02-I-10', 'AC-G02-P02-03', 'UPDATE del resultado de una prueba',
     $q$ UPDATE prueba SET resultado = 'Favorable' WHERE resultado = 'Desfavorable' AND orden_id = 9003 $q$,
     'solo inserción');
SELECT pruebas.esperar_rechazo('G02-P02-I-10', 'AC-G02-P02-04', 'DELETE de un consumo',
     $q$ DELETE FROM consumo_repuesto WHERE orden_id = 9003 $q$,
     'solo inserción');
SELECT pruebas.esperar_rechazo('G02-P02-I-10', 'AC-G02-P02-02', 'UPDATE de una participación cerrada',
     $q$ UPDATE participacion_tecnica SET minutos_efectivos = 10 WHERE labor_id = pruebas.labor_id(9003, 'Cambio de pastillas') $q$,
     'solo admite su cierre');

-- ===========================================================
-- ID: G02-P02-I-11     Criterio: AC-G02-P02-03
-- Acción: retrabajo originado en una prueba Favorable; retrabajo citando
--   una prueba de OTRA labor; prueba con valor sin unidad; resultado fuera
--   de dominio.
-- Esperado: rechazos con causa visible.
-- ===========================================================
SELECT pruebas.esperar_rechazo('G02-P02-I-11', 'AC-G02-P02-03', 'retrabajo desde prueba Favorable',
     $q$ SELECT fn_registrar_retrabajo(pruebas.labor_id(9003, 'Rectificado'),
            (SELECT prueba_id FROM prueba WHERE labor_id = pruebas.labor_id(9003, 'Rectificado')),
            'Retrabajo injustificado', 205, '2026-11-05 11:30') $q$,
     'solo se origina en una prueba Desfavorable');
SELECT pruebas.esperar_rechazo('G02-P02-I-11', 'AC-G02-P02-03', 'retrabajo con prueba de otra labor',
     $q$ SELECT fn_registrar_retrabajo(pruebas.labor_id(9003, 'Purga'),
            (SELECT prueba_id FROM prueba WHERE labor_id = pruebas.labor_id(9003, 'Cambio de pastillas')),
            'Retrabajo cruzado', 205, '2026-11-05 11:30') $q$,
     'no es de la labor');
SELECT pruebas.esperar_rechazo('G02-P02-I-11', 'AC-G02-P02-03', 'medición sin unidad',
     $q$ SELECT fn_registrar_prueba(pruebas.labor_id(9003, 'Sustitución del sensor'), 203, '2026-11-05 11:40',
                'Lectura del sensor', 'Favorable', 'Lectura estable', 0.45, NULL) $q$,
     'ck_prueba_medicion');
SELECT pruebas.esperar_rechazo('G02-P02-I-11', 'AC-G02-P02-03', 'resultado fuera de dominio',
     $q$ SELECT fn_registrar_prueba(pruebas.labor_id(9003, 'Sustitución del sensor'), 203, '2026-11-05 11:40',
                'Lectura del sensor', 'Excelente', 'Lectura estable') $q$,
     'ck_prueba_resultado');
SELECT pruebas.verificar('G02-P02-I-11', 'AC-G02-P02-03', 'S sigue En proceso sin pruebas ni participaciones',
     (SELECT estado_labor = 'En proceso' FROM labor WHERE labor_id = pruebas.labor_id(9003, 'Sustitución del sensor'))
     AND (SELECT count(*) = 0 FROM prueba WHERE labor_id = pruebas.labor_id(9003, 'Sustitución del sensor'))
     AND (SELECT count(*) = 0 FROM participacion_tecnica WHERE labor_id = pruebas.labor_id(9003, 'Sustitución del sensor')),
     'En proceso, 0 pruebas, 0 participaciones',
     (SELECT estado_labor FROM labor WHERE labor_id = pruebas.labor_id(9003, 'Sustitución del sensor')) || ', '
     || (SELECT count(*) FROM prueba WHERE labor_id = pruebas.labor_id(9003, 'Sustitución del sensor')) || ' pruebas, '
     || (SELECT count(*) FROM participacion_tecnica WHERE labor_id = pruebas.labor_id(9003, 'Sustitución del sensor')) || ' participaciones');
