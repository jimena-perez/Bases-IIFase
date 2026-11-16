-- =====================================================================
-- G02-P03 · Gestionar estados de la orden y fecha prometida · INVÁLIDAS
-- Cada intento debe rechazarse con causa visible; la lectura posterior
-- demuestra que ni el historial ni el valor actual cambiaron.
-- Órdenes: 9005 (Autorizada tras V-01) y 9006 (Recibida, con un daño sin
-- confirmar).
-- =====================================================================
SET search_path = taller, public;
SET TIME ZONE 'America/Costa_Rica';

-- ===========================================================
-- ID: G02-P03-I-01     Criterio: AC-G02-P03-03
-- Preparación: no existe la orden 99999.
-- Acción: cambiar su estado y su promesa.
-- Esperado: error explícito "la orden 99999 no existe" (no "0 filas").
-- ===========================================================
SELECT pruebas.esperar_rechazo('G02-P03-I-01', 'AC-G02-P03-03', 'cambio de estado de orden inexistente',
     $q$ SELECT fn_cambiar_estado_orden(99999, 'En diagnóstico', 201, NULL, '2026-11-08 10:00') $q$,
     'la orden 99999 no existe');
SELECT pruebas.esperar_rechazo('G02-P03-I-01', 'AC-G02-P03-03', 'cambio de promesa de orden inexistente',
     $q$ SELECT fn_cambiar_fecha_prometida(99999, '2026-11-20 10:00', '2026-11-08 10:00', 'Teléfono', 'x', 201) $q$,
     'la orden 99999 no existe');

-- ===========================================================
-- ID: G02-P03-I-02     Criterio: AC-G02-P03-02
-- Preparación: orden 9006 con promesa original 2026-11-09 12:00.
-- Acción: reprogramar sin motivo (NULL y texto vacío).
-- Esperado: rechazo "requiere motivo"; la promesa sigue igual y el
--   historial de promesas sigue con 1 fila.
-- ===========================================================
SELECT pruebas.esperar_rechazo('G02-P03-I-02', 'AC-G02-P03-02', 'reprogramar 9006 sin motivo',
     $q$ SELECT fn_cambiar_fecha_prometida(9006, '2026-11-11 12:00', '2026-11-07 09:00', 'Teléfono', NULL, 206) $q$,
     'requiere motivo');
SELECT pruebas.esperar_rechazo('G02-P03-I-02', 'AC-G02-P03-02', 'reprogramar 9006 con motivo vacío',
     $q$ SELECT fn_cambiar_fecha_prometida(9006, '2026-11-11 12:00', '2026-11-07 09:00', 'Teléfono', '   ', 206) $q$,
     'requiere motivo');
SELECT pruebas.verificar('G02-P03-I-02', 'AC-G02-P03-02', 'sin efectos en la promesa de 9006',
     (SELECT o.fecha_prometida_actual = '2026-11-09 12:00'::timestamptz
             AND (SELECT count(*) FROM historial_fecha_prometida WHERE orden_id = 9006) = 1
      FROM orden_trabajo o WHERE o.orden_id = 9006),
     'promesa 2026-11-09 12:00 y 1 fila de historial',
     (SELECT fecha_prometida_actual || ' y ' || (SELECT count(*) FROM historial_fecha_prometida WHERE orden_id = 9006) || ' fila(s)'
      FROM orden_trabajo WHERE orden_id = 9006));

-- ===========================================================
-- ID: G02-P03-I-03     Criterio: AC-G02-P03-01
-- Preparación: orden 9005 en 'Autorizada'.
-- Acción: retroceder a 'En diagnóstico' sin motivo.
-- Esperado: rechazo "requiere motivo"; 9005 sigue en Autorizada con 8 filas.
-- ===========================================================
SELECT pruebas.esperar_rechazo('G02-P03-I-03', 'AC-G02-P03-01', 'retroceso Autorizada -> En diagnóstico sin motivo',
     $q$ SELECT fn_cambiar_estado_orden(9005, 'En diagnóstico', 203, NULL, '2026-11-08 10:00') $q$,
     'requiere motivo');
SELECT pruebas.verificar('G02-P03-I-03', 'AC-G02-P03-01', 'sin efectos en 9005',
     (SELECT estado_actual = 'Autorizada' AND (SELECT count(*) FROM historial_orden WHERE orden_id = 9005) = 8
      FROM orden_trabajo WHERE orden_id = 9005),
     'Autorizada con 8 filas de historial',
     (SELECT estado_actual || ' con ' || (SELECT count(*) FROM historial_orden WHERE orden_id = 9005) || ' filas'
      FROM orden_trabajo WHERE orden_id = 9005));

-- ===========================================================
-- ID: G02-P03-I-04     Criterio: AC-G02-P03-03 (corrige el defecto D4 del Lab03)
-- Preparación: orden 9006.
-- Acción: UPDATE directo de fecha_prometida_actual y de estado_actual,
--   tal como lo permitía el Lab03.
-- Esperado: rechazo "solo cambian mediante su historial"; valores intactos.
-- ===========================================================
SELECT pruebas.esperar_rechazo('G02-P03-I-04', 'AC-G02-P03-03', 'UPDATE directo de fecha_prometida_actual',
     $q$ UPDATE orden_trabajo SET fecha_prometida_actual = '2026-11-30 10:00' WHERE orden_id = 9006 $q$,
     'solo cambian mediante su historial');
SELECT pruebas.esperar_rechazo('G02-P03-I-04', 'AC-G02-P03-03', 'UPDATE directo de estado_actual',
     $q$ UPDATE orden_trabajo SET estado_actual = 'Cancelada' WHERE orden_id = 9006 $q$,
     'solo cambian mediante su historial');
SELECT pruebas.verificar('G02-P03-I-04', 'AC-G02-P03-03', 'valores actuales de 9006 intactos',
     (SELECT estado_actual = 'Recibida' AND fecha_prometida_actual = '2026-11-09 12:00'::timestamptz
      FROM orden_trabajo WHERE orden_id = 9006),
     'Recibida / 2026-11-09 12:00',
     (SELECT estado_actual || ' / ' || fecha_prometida_actual FROM orden_trabajo WHERE orden_id = 9006));

-- ===========================================================
-- ID: G02-P03-I-05     Criterio: AC-G02-P03-03
-- Preparación: orden 9006 en Recibida con un daño SIN confirmar (RN-06).
-- Acción: en UN mismo bloque, primero una reprogramación válida y luego un
--   cambio de estado que falla a mitad (daño sin confirmar).
-- Esperado: rechazo por RN-06 y NADA queda: ni la promesa nueva ni el estado.
-- ===========================================================
SELECT pruebas.esperar_rechazo('G02-P03-I-05', 'AC-G02-P03-03', 'fallo inducido a mitad del registro',
     $q$ DO $b$ BEGIN
            PERFORM fn_cambiar_fecha_prometida(9006, '2026-11-10 12:00', '2026-11-07 08:30', 'Teléfono',
                                               'Se agrega revisión de amortiguadores', 206);
            PERFORM fn_cambiar_estado_orden(9006, 'En diagnóstico', 204, NULL, '2026-11-07 08:45');
         END $b$ $q$,
     'objetos/daños sin confirmar');
SELECT pruebas.verificar('G02-P03-I-05', 'AC-G02-P03-03', 'ni historial ni valor actual cambiaron',
     (SELECT o.estado_actual = 'Recibida' AND o.fecha_prometida_actual = '2026-11-09 12:00'::timestamptz
             AND (SELECT count(*) FROM historial_orden WHERE orden_id = 9006) = 1
             AND (SELECT count(*) FROM historial_fecha_prometida WHERE orden_id = 9006) = 1
      FROM orden_trabajo o WHERE o.orden_id = 9006),
     'Recibida, promesa 2026-11-09 12:00, 1 + 1 filas',
     (SELECT estado_actual || ', ' || fecha_prometida_actual || ', '
             || (SELECT count(*) FROM historial_orden WHERE orden_id = 9006) || ' + '
             || (SELECT count(*) FROM historial_fecha_prometida WHERE orden_id = 9006) || ' filas'
      FROM orden_trabajo WHERE orden_id = 9006));

-- ===========================================================
-- ID: G02-P03-I-06     Criterio: AC-G02-P03-01
-- Acción: transiciones que no existen en el catálogo y "no cambios".
-- Esperado: rechazo "transición no permitida" / "ya está en".
-- ===========================================================
SELECT pruebas.esperar_rechazo('G02-P03-I-06', 'AC-G02-P03-01', 'Recibida -> Autorizada (salta diagnóstico)',
     $q$ SELECT fn_cambiar_estado_orden(9006, 'Autorizada', 206, NULL, '2026-11-07 09:00') $q$,
     'transición no permitida');
SELECT pruebas.esperar_rechazo('G02-P03-I-06', 'AC-G02-P03-01', 'Autorizada -> Autorizada',
     $q$ SELECT fn_cambiar_estado_orden(9005, 'Autorizada', 201, NULL, '2026-11-08 10:00') $q$,
     'ya está en Autorizada');
SELECT pruebas.esperar_rechazo('G02-P03-I-06', 'AC-G02-P03-01', 'estado fuera del dominio',
     $q$ SELECT fn_cambiar_estado_orden(9006, 'Archivada', 206, NULL, '2026-11-07 09:00') $q$,
     'd_estado_orden');

-- ===========================================================
-- ID: G02-P03-I-07     Criterio: AC-G02-P03-01, AC-G02-P03-03
-- Acción: INSERT "a mano" en el historial saltándose la rutina: con
--   secuencia inventada, con estado anterior falso, con fecha anterior al
--   último cambio, y UPDATE/DELETE de una fila del historial.
-- Esperado: el trigger aplica las mismas reglas que la rutina.
-- ===========================================================
SELECT pruebas.esperar_rechazo('G02-P03-I-07', 'AC-G02-P03-03', 'INSERT con secuencia inventada',
     $q$ INSERT INTO historial_orden (orden_id, secuencia, estado, fecha_hora, personal_id)
         VALUES (9005, 50, 'En reparación', '2026-11-08 10:00', 203) $q$,
     'la secuencia la asigna el sistema');
SELECT pruebas.esperar_rechazo('G02-P03-I-07', 'AC-G02-P03-03', 'INSERT con estado_anterior falso',
     $q$ INSERT INTO historial_orden (orden_id, estado_anterior, estado, fecha_hora, personal_id)
         VALUES (9005, 'Lista entrega', 'En reparación', '2026-11-08 10:00', 203) $q$,
     'estado_anterior lo asigna el sistema');
SELECT pruebas.esperar_rechazo('G02-P03-I-07', 'AC-G02-P03-01', 'cambio con fecha anterior al último',
     $q$ SELECT fn_cambiar_estado_orden(9005, 'En reparación', 203, NULL, '2026-11-01 10:00') $q$,
     'anterior al último cambio');
SELECT pruebas.esperar_rechazo('G02-P03-I-07', 'AC-G02-P03-03', 'UPDATE de una fila del historial',
     $q$ UPDATE historial_orden SET motivo = 'reescrito' WHERE orden_id = 9005 AND secuencia = 6 $q$,
     'solo inserción');
SELECT pruebas.esperar_rechazo('G02-P03-I-07', 'AC-G02-P03-02', 'DELETE de una promesa',
     $q$ DELETE FROM historial_fecha_prometida WHERE orden_id = 9005 AND secuencia = 2 $q$,
     'solo inserción');
SELECT pruebas.esperar_rechazo('G02-P03-I-07', 'AC-G02-P03-01', 'cambio registrado por personal inactivo',
     $q$ SELECT fn_cambiar_estado_orden(9005, 'En reparación', 207, NULL, '2026-11-08 10:00') $q$,
     'no está activo');
SELECT pruebas.verificar('G02-P03-I-07', 'AC-G02-P03-03', 'historial de 9005 intacto',
     (SELECT count(*) = 8 FROM historial_orden WHERE orden_id = 9005)
     AND (SELECT count(*) = 3 FROM historial_fecha_prometida WHERE orden_id = 9005),
     '8 estados y 3 promesas',
     (SELECT count(*) FROM historial_orden WHERE orden_id = 9005) || ' estados y '
     || (SELECT count(*) FROM historial_fecha_prometida WHERE orden_id = 9005) || ' promesas');
