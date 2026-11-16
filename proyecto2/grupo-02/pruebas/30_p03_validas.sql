-- =====================================================================
-- G02-P03 · Gestionar estados de la orden y fecha prometida · VÁLIDAS
-- Orden de trabajo: 9005 (Ana Solís, Nissan Leaf MNO345).
-- Promesa original (alta): 2026-11-10 17:00.
-- =====================================================================
SET search_path = taller, public;
SET TIME ZONE 'America/Costa_Rica';

-- ===========================================================
-- ID: G02-P03-V-01     Criterio: AC-G02-P03-01, AC-G02-P03-03
-- Preparación: orden 9005 en 'Recibida' con objetos/daños confirmados.
--   Para pasar a 'Pendiente autorización' y 'Autorizada' se usa el proceso
--   P01 real (propuesta presentada y decisión aceptada), no datos precargados.
-- Acción: Recibida -> En diagnóstico -> Pendiente autorización -> Autorizada
--         -> En reparación -> En diagnóstico (RETROCESO con motivo)
--         -> Pendiente autorización -> Autorizada.
--   Todo en una transacción explícita confirmada con COMMIT.
-- Esperado: 8 filas de historial con secuencia 1..8, estado_anterior
--   correcto, responsable y momento; el retroceso conserva su motivo;
--   estado_actual = 'Autorizada'.
-- ===========================================================
BEGIN;
SELECT fn_cambiar_estado_orden(9005, 'En diagnóstico', 203, NULL, '2026-11-06 11:30');

SELECT fn_publicar_propuesta(9005, NULL,
    '[{"clave":"BAT","descripcion":"Reemplazo de batería auxiliar 12 V","hallazgo_id":4110,
       "precio_estimado":15000,"alcance":"Sustituir batería y verificar carga",
       "repuestos":[{"repuesto_id":"EL-002","cantidad":1,"precio_unitario":52000}]}]'::jsonb,
    205, 'Presupuesto inicial', '2026-11-06 13:00');
SELECT fn_cambiar_estado_orden(9005, 'Pendiente autorización', 201, NULL, '2026-11-06 13:05');

SELECT fn_registrar_decision(pruebas.propuesta_id(9005, 1), pruebas.labor_id(9005, 'Reemplazo de batería'),
                             104, 'Aceptada', 'Teléfono', 201, '2026-11-06 14:00', 'Acepta por teléfono');
SELECT fn_cambiar_estado_orden(9005, 'Autorizada', 201, NULL, '2026-11-06 14:05');
SELECT fn_cambiar_estado_orden(9005, 'En reparación', 203, NULL, '2026-11-07 08:00');
SELECT fn_cambiar_estado_orden(9005, 'En diagnóstico', 203,
                               'Al reemplazar la batería se detecta falla en el convertidor DC-DC',
                               '2026-11-07 10:00');
SELECT fn_cambiar_estado_orden(9005, 'Pendiente autorización', 201, NULL, '2026-11-07 11:00');
SELECT fn_cambiar_estado_orden(9005, 'Autorizada', 201, NULL, '2026-11-07 11:30');
COMMIT;

-- Lectura posterior en una transacción NUEVA (persistencia).
SELECT * FROM v_cronologia_estados WHERE orden_id = 9005 ORDER BY secuencia;

SELECT pruebas.verificar('G02-P03-V-01', 'AC-G02-P03-01', 'historial de estados de 9005 tras COMMIT',
     (SELECT count(*) = 8 AND min(secuencia) = 1 AND max(secuencia) = 8 FROM historial_orden WHERE orden_id = 9005),
     '8 cambios, secuencia 1..8 sin huecos',
     (SELECT count(*) || ' cambios, secuencia ' || min(secuencia) || '..' || max(secuencia) FROM historial_orden WHERE orden_id = 9005));

SELECT pruebas.verificar('G02-P03-V-01', 'AC-G02-P03-01', 'retroceso En reparación -> En diagnóstico con motivo',
     EXISTS (SELECT 1 FROM historial_orden WHERE orden_id = 9005 AND estado_anterior = 'En reparación'
             AND estado = 'En diagnóstico' AND motivo LIKE '%convertidor DC-DC%'),
     'retroceso registrado con su motivo',
     (SELECT estado_anterior || ' -> ' || estado || ' | ' || motivo FROM historial_orden
      WHERE orden_id = 9005 AND estado_anterior = 'En reparación'));

SELECT pruebas.verificar('G02-P03-V-01', 'AC-G02-P03-03', 'valor actual = último estado del historial',
     (SELECT o.estado_actual = 'Autorizada' AND o.estado_actual = (SELECT estado FROM historial_orden WHERE orden_id = 9005 ORDER BY secuencia DESC LIMIT 1)
      FROM orden_trabajo o WHERE orden_id = 9005),
     'estado_actual Autorizada, igual al historial',
     (SELECT estado_actual FROM orden_trabajo WHERE orden_id = 9005));

-- ===========================================================
-- ID: G02-P03-V-02     Criterio: AC-G02-P03-02
-- Preparación: orden 9005 con promesa original 2026-11-10 17:00.
-- Acción: dos reprogramaciones comunicadas (teléfono y correo) con motivo.
-- Esperado: 3 filas (original + 2); cada una conserva la fecha anterior,
--   medio, motivo y responsable; promesa actual 2026-11-13 12:00.
-- ===========================================================
BEGIN;
SELECT fn_cambiar_fecha_prometida(9005, '2026-11-12 17:00', '2026-11-07 10:15', 'Teléfono',
                                  'Se requiere diagnóstico adicional del convertidor DC-DC', 203);
SELECT fn_cambiar_fecha_prometida(9005, '2026-11-13 12:00', '2026-11-08 09:00', 'Correo',
                                  'El repuesto llega un día después de lo previsto', 201);
COMMIT;

SELECT * FROM v_cronologia_promesas WHERE orden_id = 9005 ORDER BY secuencia;
SELECT * FROM v_promesas WHERE orden_id = 9005;

SELECT pruebas.verificar('G02-P03-V-02', 'AC-G02-P03-02', 'promesa original, actual y número de cambios',
     (SELECT promesa_original = '2026-11-10 17:00'::timestamptz AND promesa_actual = '2026-11-13 12:00'::timestamptz
             AND reprogramaciones = 2 FROM v_promesas WHERE orden_id = 9005),
     'original 2026-11-10 17:00, actual 2026-11-13 12:00, 2 reprogramaciones',
     (SELECT 'original ' || promesa_original || ', actual ' || promesa_actual || ', ' || reprogramaciones || ' reprogramaciones'
      FROM v_promesas WHERE orden_id = 9005));

SELECT pruebas.verificar('G02-P03-V-02', 'AC-G02-P03-02', 'cada cambio conserva la fecha anterior (no se sobrescribe)',
     (SELECT bool_and(fecha_anterior = lag_nueva) FROM (
         SELECT fecha_anterior, lag(fecha_nueva) OVER (ORDER BY secuencia) AS lag_nueva, secuencia
         FROM historial_fecha_prometida WHERE orden_id = 9005) x WHERE secuencia > 1),
     'fecha_anterior(n) = fecha_nueva(n-1) en toda la cadena',
     (SELECT string_agg(secuencia || ': ' || coalesce(fecha_anterior::text, 'NULL') || ' -> ' || fecha_nueva, ' | ' ORDER BY secuencia)
      FROM historial_fecha_prometida WHERE orden_id = 9005));

-- Resultado observable final de la orden (estado y promesa en vistas separadas).
SELECT * FROM v_estado_actual_orden WHERE orden_id = 9005;
