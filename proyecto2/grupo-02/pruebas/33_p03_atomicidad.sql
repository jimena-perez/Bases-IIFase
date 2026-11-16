-- =====================================================================
-- G02-P03 · ATOMICIDAD
-- =====================================================================
SET search_path = taller, public;
SET TIME ZONE 'America/Costa_Rica';

-- ===========================================================
-- ID: G02-P03-A-01     Criterio: AC-G02-P03-03
-- Preparación: orden 9005 (Autorizada, 8 estados, 3 promesas).
-- Acción: en UN bloque: cambio de estado válido (Autorizada -> En
--   reparación), reprogramación válida y, al final, una reprogramación
--   inválida (fecha prometida anterior a su comunicación).
-- Esperado: rechazo por ck_hfp_promesa_futura y NINGUNO de los tres cambios
--   queda (conteos y valores actuales iguales antes y después).
-- ===========================================================
SELECT pruebas.esperar_rechazo('G02-P03-A-01', 'AC-G02-P03-03', 'bloque con fallo al final',
     $q$ DO $b$ BEGIN
            PERFORM fn_cambiar_estado_orden(9005, 'En reparación', 203, NULL, '2026-11-08 10:00');
            PERFORM fn_cambiar_fecha_prometida(9005, '2026-11-14 12:00', '2026-11-08 10:05', 'Teléfono', 'Ajuste de agenda', 201);
            PERFORM fn_cambiar_fecha_prometida(9005, '2026-11-01 12:00', '2026-11-08 10:10', 'Teléfono', 'Fecha errónea', 201);
         END $b$ $q$,
     'ck_hfp_promesa_futura');
SELECT pruebas.verificar('G02-P03-A-01', 'AC-G02-P03-03', 'nada quedó del bloque fallido',
     (SELECT estado_actual = 'Autorizada' AND fecha_prometida_actual = '2026-11-13 12:00'::timestamptz
      FROM orden_trabajo WHERE orden_id = 9005)
     AND (SELECT count(*) = 8 FROM historial_orden WHERE orden_id = 9005)
     AND (SELECT count(*) = 3 FROM historial_fecha_prometida WHERE orden_id = 9005),
     'Autorizada / 2026-11-13 12:00 / 8 estados / 3 promesas',
     (SELECT estado_actual || ' / ' || fecha_prometida_actual FROM orden_trabajo WHERE orden_id = 9005)
     || ' / ' || (SELECT count(*) FROM historial_orden WHERE orden_id = 9005) || ' estados / '
     || (SELECT count(*) FROM historial_fecha_prometida WHERE orden_id = 9005) || ' promesas');

-- ===========================================================
-- ID: G02-P03-A-02     Criterio: AC-G02-P03-03
-- Preparación: orden 9013.
-- Acción: un usuario malicioso enciende a mano la variable de la rutina
--   (SET LOCAL taller.via_historial = 'on') y cambia estado_actual sin
--   historial. Se fuerzan las restricciones diferidas (SET CONSTRAINTS ALL
--   IMMEDIATE) para ver lo que ocurriría al COMMIT.
-- Esperado: el constraint trigger diferido de coherencia lo rechaza:
--   "estado_actual (...) no coincide con su historial". Segunda línea de
--   defensa además del trigger BEFORE UPDATE.
-- ===========================================================
SELECT pruebas.esperar_rechazo('G02-P03-A-02', 'AC-G02-P03-03', 'saltarse la rutina activando la variable a mano',
     $q$ DO $b$ BEGIN
            PERFORM set_config('taller.via_historial', 'on', true);
            UPDATE orden_trabajo SET estado_actual = 'En reparación' WHERE orden_id = 9013;
            SET CONSTRAINTS ALL IMMEDIATE;
         END $b$ $q$,
     'no coincide con su historial');
SELECT pruebas.verificar('G02-P03-A-02', 'AC-G02-P03-03', '9013 sigue coherente',
     (SELECT estado_actual = 'Recibida' FROM orden_trabajo WHERE orden_id = 9013),
     'Recibida', (SELECT estado_actual FROM orden_trabajo WHERE orden_id = 9013));
