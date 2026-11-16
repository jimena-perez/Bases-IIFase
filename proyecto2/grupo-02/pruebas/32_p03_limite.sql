-- =====================================================================
-- G02-P03 · Gestionar estados de la orden y fecha prometida · LÍMITE
-- Órdenes: 9006 (Ana, Hyundai PQR678) y 9004 (Mensajería, sin promesa).
-- =====================================================================
SET search_path = taller, public;
SET TIME ZONE 'America/Costa_Rica';

-- ===========================================================
-- ID: G02-P03-L-01     Criterio: AC-G02-P03-04
-- Preparación: el cliente confirma el daño pendiente de 9006 (RN-06).
-- Acción: dos cambios de estado con EXACTAMENTE el mismo fecha_hora
--   (Recibida -> En diagnóstico -> Cancelada a las 2026-11-07 09:00) y dos
--   reprogramaciones comunicadas en el mismo instante.
-- Esperado: el orden lo da la secuencia (2 y 3), no se inventa ninguna
--   transición intermedia; las dos promesas quedan en secuencia 2 y 3.
-- ===========================================================
UPDATE objeto_dano SET confirmado_cliente = true WHERE detalle_id = 4;   -- confirmación (única actualización permitida)

BEGIN;
SELECT fn_cambiar_fecha_prometida(9006, '2026-11-10 12:00', '2026-11-07 08:50', 'Presencial',
                                  'Se agrega revisión de amortiguadores', 206);
SELECT fn_cambiar_fecha_prometida(9006, '2026-11-10 15:00', '2026-11-07 08:50', 'Presencial',
                                  'Corrección: la tarde del mismo día', 206);
SELECT fn_cambiar_estado_orden(9006, 'En diagnóstico', 204, NULL, '2026-11-07 09:00');
SELECT fn_cambiar_estado_orden(9006, 'Cancelada', 206,
                               'La clienta decide vender el vehículo sin repararlo', '2026-11-07 09:00');
COMMIT;

SELECT * FROM v_cronologia_estados WHERE orden_id = 9006 ORDER BY secuencia;
SELECT * FROM v_cronologia_promesas WHERE orden_id = 9006 ORDER BY secuencia;

SELECT pruebas.verificar('G02-P03-L-01', 'AC-G02-P03-04', 'mismo instante ordenado por secuencia',
     (SELECT string_agg(secuencia || ':' || estado, ',' ORDER BY secuencia) = '1:Recibida,2:En diagnóstico,3:Cancelada'
      FROM historial_orden WHERE orden_id = 9006)
     AND (SELECT count(DISTINCT fecha_hora) = 1 FROM historial_orden WHERE orden_id = 9006 AND secuencia IN (2, 3)),
     '1:Recibida,2:En diagnóstico,3:Cancelada (2 y 3 con la misma fecha_hora)',
     (SELECT string_agg(secuencia || ':' || estado || '@' || to_char(fecha_hora, 'HH24:MI'), ',' ORDER BY secuencia)
      FROM historial_orden WHERE orden_id = 9006));
SELECT pruebas.verificar('G02-P03-L-01', 'AC-G02-P03-04', 'promesas del mismo instante ordenadas por secuencia',
     (SELECT string_agg(secuencia::text, ',' ORDER BY secuencia) = '1,2,3'
             AND max(fecha_nueva) FILTER (WHERE secuencia = 3) = '2026-11-10 15:00'::timestamptz
      FROM historial_fecha_prometida WHERE orden_id = 9006),
     'secuencias 1,2,3; la vigente es la de secuencia 3 (15:00)',
     (SELECT string_agg(secuencia || ':' || to_char(fecha_nueva, 'DD HH24:MI'), ',' ORDER BY secuencia)
      FROM historial_fecha_prometida WHERE orden_id = 9006));

-- ===========================================================
-- ID: G02-P03-L-02     Criterio: AC-G02-P03-04
-- Preparación: orden 9006 Cancelada.
-- Acción: consultar su historia completa; intentar cambiarle el estado,
--   la promesa o borrarla.
-- Esperado: la orden y TODA su historia siguen consultables; Cancelada es
--   terminal (no se reabre) y la orden no se borra.
-- ===========================================================
SELECT * FROM v_estado_actual_orden WHERE orden_id = 9006;
SELECT pruebas.verificar('G02-P03-L-02', 'AC-G02-P03-04', 'orden cancelada consultable con toda su historia',
     (SELECT estado_actual = 'Cancelada' FROM orden_trabajo WHERE orden_id = 9006)
     AND (SELECT count(*) = 3 FROM v_cronologia_estados WHERE orden_id = 9006)
     AND (SELECT count(*) = 3 FROM v_cronologia_promesas WHERE orden_id = 9006),
     'Cancelada; 3 estados y 3 promesas visibles',
     (SELECT estado_actual FROM orden_trabajo WHERE orden_id = 9006) || '; '
     || (SELECT count(*) FROM v_cronologia_estados WHERE orden_id = 9006) || ' estados y '
     || (SELECT count(*) FROM v_cronologia_promesas WHERE orden_id = 9006) || ' promesas');
SELECT pruebas.esperar_rechazo('G02-P03-L-02', 'AC-G02-P03-04', 'reabrir una orden Cancelada',
     $q$ SELECT fn_cambiar_estado_orden(9006, 'En diagnóstico', 204, 'Reabrir', '2026-11-08 09:00') $q$,
     'transición no permitida de Cancelada');
SELECT pruebas.esperar_rechazo('G02-P03-L-02', 'AC-G02-P03-04', 'reprogramar una orden Cancelada',
     $q$ SELECT fn_cambiar_fecha_prometida(9006, '2026-11-20 12:00', '2026-11-08 09:00', 'Correo', 'x', 206) $q$,
     'está Cancelada');
SELECT pruebas.esperar_rechazo('G02-P03-L-02', 'AC-G02-P03-04', 'borrar la orden cancelada',
     $q$ DELETE FROM orden_trabajo WHERE orden_id = 9006 $q$,
     'no se elimina');

-- ===========================================================
-- ID: G02-P03-L-03     Criterio: AC-G02-P03-02
-- Preparación: orden 9004 se recibió SIN fecha prometida.
-- Acción: registrar la primera promesa sin motivo.
-- Esperado: aceptada como promesa ORIGINAL (secuencia 1, fecha_anterior
--   NULL); el motivo solo es obligatorio en las reprogramaciones.
-- ===========================================================
SELECT fn_cambiar_fecha_prometida(9004, '2026-11-08 17:00', '2026-11-05 09:30', 'Teléfono', NULL, 201);
SELECT pruebas.verificar('G02-P03-L-03', 'AC-G02-P03-02', 'primera promesa sin motivo = promesa original',
     (SELECT secuencia = 1 AND fecha_anterior IS NULL AND motivo IS NULL
      FROM historial_fecha_prometida WHERE orden_id = 9004)
     AND (SELECT fecha_prometida_actual = '2026-11-08 17:00'::timestamptz FROM orden_trabajo WHERE orden_id = 9004),
     'secuencia 1, fecha_anterior NULL, actual 2026-11-08 17:00',
     (SELECT 'secuencia ' || secuencia || ', anterior ' || coalesce(fecha_anterior::text, 'NULL') || ', nueva ' || fecha_nueva
      FROM historial_fecha_prometida WHERE orden_id = 9004));

-- ===========================================================
-- ID: G02-P03-L-04     Criterio: AC-G02-P03-01
-- Retroceso permitido: ver G02-P03-V-01 (En reparación -> En diagnóstico
-- con motivo). Aquí se comprueba que el catálogo NO impone una
-- prohibición universal de retroceso: lista los retrocesos admitidos.
-- ===========================================================
SELECT estado_desde, estado_hacia, requiere_motivo, descripcion
FROM transicion_estado_orden WHERE descripcion LIKE 'Retroceso%' ORDER BY estado_desde, estado_hacia;
SELECT pruebas.verificar('G02-P03-L-04', 'AC-G02-P03-01', 'retrocesos admitidos y todos con motivo obligatorio',
     (SELECT count(*) >= 5 AND bool_and(requiere_motivo) FROM transicion_estado_orden WHERE descripcion LIKE 'Retroceso%'),
     '>= 5 retrocesos, todos con motivo',
     (SELECT count(*) || ' retrocesos; con motivo: ' || bool_and(requiere_motivo) FROM transicion_estado_orden WHERE descripcion LIKE 'Retroceso%'));
