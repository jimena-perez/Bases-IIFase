-- =====================================================================
-- G02-P02 · Ejecutar reparaciones y pruebas · LÍMITE
-- =====================================================================
SET search_path = taller, public;
SET TIME ZONE 'America/Costa_Rica';

-- ===========================================================
-- ID: G02-P02-L-01     Criterio: AC-G02-P02-03, AC-G02-P02-04
-- Preparación: W (freno de mano) de 9003, aceptada y sin repuestos.
-- Acción: ejecutarla sin consumir repuestos y con una prueba SOLO
--   descriptiva (sin valor ni unidad); completarla.
-- Esperado: válido: W Completada, 0 consumos, prueba sin medición.
-- ===========================================================
SELECT fn_iniciar_labor(pruebas.labor_id(9003, 'Ajuste de freno de mano'), 204, '2026-11-05 12:30');
SELECT fn_registrar_participacion(pruebas.labor_id(9003, 'Ajuste de freno de mano'), 204,
       '2026-11-05 12:30', '2026-11-05 13:00', 25, 'Ajuste de cable y palanca', 4);
SELECT fn_registrar_prueba(pruebas.labor_id(9003, 'Ajuste de freno de mano'), 204, '2026-11-05 13:05',
       'Prueba en pendiente', 'Favorable', 'El vehículo se sostiene en la rampa con 4 clics de palanca');
SELECT fn_completar_labor(pruebas.labor_id(9003, 'Ajuste de freno de mano'), 204, '2026-11-05 13:10');
SELECT pruebas.verificar('G02-P02-L-01', 'AC-G02-P02-03', 'labor sin repuestos y prueba descriptiva',
     (SELECT estado_labor = 'Completada' FROM labor WHERE labor_id = pruebas.labor_id(9003, 'Ajuste de freno de mano'))
     AND (SELECT count(*) = 0 FROM consumo_repuesto WHERE labor_id = pruebas.labor_id(9003, 'Ajuste de freno de mano'))
     AND (SELECT medicion_valor IS NULL AND unidad IS NULL FROM prueba WHERE labor_id = pruebas.labor_id(9003, 'Ajuste de freno de mano')),
     'Completada, 0 consumos, prueba sin medición',
     (SELECT estado_labor FROM labor WHERE labor_id = pruebas.labor_id(9003, 'Ajuste de freno de mano')) || ', '
     || (SELECT count(*) FROM consumo_repuesto WHERE labor_id = pruebas.labor_id(9003, 'Ajuste de freno de mano')) || ' consumos, medición '
     || coalesce((SELECT medicion_valor::text FROM prueba WHERE labor_id = pruebas.labor_id(9003, 'Ajuste de freno de mano')), 'NULL'));

-- ===========================================================
-- ID: G02-P02-L-02     Criterio: AC-G02-P02-01
-- Preparación: orden 9004 (Mensajería): hallazgo CRÍTICO 4108 (fuga de
--   frenos) y una v1 con "Cambio de bujes" SIN decisión del cliente.
-- Acción: registrar una emergencia justificada que crea la labor MÍNIMA y
--   su excepción; ejecutarla de punta a punta. Luego intentar iniciar la
--   labor pendiente de la misma propuesta.
-- Esperado: la emergencia habilita SOLO su labor (se inicia citando su
--   emergencia_id); los bujes se rechazan (situación Sin decidir); la
--   propuesta no cambia (1 línea).
-- ===========================================================
SELECT fn_cambiar_estado_orden(9004, 'En diagnóstico', 202, NULL, '2026-11-05 07:45');
SELECT fn_publicar_propuesta(9004, NULL,
  '[{"descripcion":"Cambio de bujes de suspensión","hallazgo_id":4109,"precio_estimado":35000}]'::jsonb,
  205, 'Pendiente de respuesta del cliente', '2026-11-05 08:45');
SELECT fn_registrar_emergencia(9004, 4108,
       'Reparación mínima de la fuga en el cilindro de rueda trasero izquierdo',
       'Vehículo sin capacidad de frenado; riesgo de accidente al moverlo',
       'El cliente no responde y el vehículo debe salir del área de recepción; solo se detiene la fuga',
       'Sustituir el cilindro de rueda y purgar ese circuito; nada más', 205, '2026-11-05 09:00');
SELECT fn_iniciar_labor(pruebas.labor_id(9004, 'Reparación mínima'), 202, '2026-11-05 09:05');
SELECT fn_registrar_participacion(pruebas.labor_id(9004, 'Reparación mínima'), 202,
       '2026-11-05 09:05', '2026-11-05 10:05', 50, 'Cambio de cilindro y purga', 1);
SELECT fn_registrar_consumo(9004, pruebas.labor_id(9004, 'Reparación mínima'), 'FR-002', 1, 6500, 202, '2026-11-05 09:30');
SELECT fn_registrar_prueba(pruebas.labor_id(9004, 'Reparación mínima'), 202, '2026-11-05 10:10',
       'Prueba de pedal', 'Favorable', 'Pedal firme, sin fuga visible');
SELECT fn_completar_labor(pruebas.labor_id(9004, 'Reparación mínima'), 202, '2026-11-05 10:20');

SELECT * FROM v_historia_labor WHERE orden_id = 9004 ORDER BY labor_id, secuencia;
SELECT pruebas.verificar('G02-P02-L-02', 'AC-G02-P02-01', 'la emergencia habilitó su labor citando la excepción',
     (SELECT h.emergencia_id IS NOT NULL AND h.autorizacion_id IS NULL FROM historial_labor h
      WHERE h.labor_id = pruebas.labor_id(9004, 'Reparación mínima') AND h.estado_nuevo = 'En proceso')
     AND (SELECT estado_labor = 'Completada' FROM labor WHERE labor_id = pruebas.labor_id(9004, 'Reparación mínima')),
     'inicio con emergencia_id, labor Completada',
     (SELECT 'emergencia_id ' || h.emergencia_id || ', ' || l.estado_labor FROM historial_labor h JOIN labor l USING (labor_id)
      WHERE h.labor_id = pruebas.labor_id(9004, 'Reparación mínima') AND h.estado_nuevo = 'En proceso'));
SELECT pruebas.esperar_rechazo('G02-P02-L-02', 'AC-G02-P02-01', 'la emergencia NO habilita otra labor de la propuesta',
     $q$ SELECT fn_iniciar_labor(pruebas.labor_id(9004, 'Cambio de bujes'), 204, '2026-11-05 10:30') $q$,
     'situación: Sin decidir');
SELECT pruebas.esperar_rechazo('G02-P02-L-02', 'AC-G02-P02-01', 'INSERT directo citando la emergencia en otra labor',
     $q$ INSERT INTO historial_labor (labor_id, estado_nuevo, fecha_hora, personal_id, emergencia_id)
         SELECT pruebas.labor_id(9004, 'Cambio de bujes'), 'En proceso', '2026-11-05 10:30', 204, emergencia_id
         FROM excepcion_emergencia WHERE orden_id = 9004 $q$,
     'no es de emergencia');
-- Defensa en profundidad: sin el trigger, la FK compuesta
-- (emergencia_id, labor_id) impide usar la excepción en otra labor.
SELECT pruebas.esperar_rechazo('G02-P02-L-02', 'AC-G02-P02-01', 'misma inserción solo contra la FK compuesta',
     $q$ DO $b$ BEGIN
            ALTER TABLE historial_labor DISABLE TRIGGER trg_historial_labor_antes;
            INSERT INTO historial_labor (labor_id, secuencia, estado_anterior, estado_nuevo, fecha_hora, personal_id, emergencia_id)
            SELECT pruebas.labor_id(9004, 'Cambio de bujes'), 2, 'Pendiente', 'En proceso', '2026-11-05 10:30', 204, emergencia_id
            FROM excepcion_emergencia WHERE orden_id = 9004;
         END $b$ $q$,
     'fk_historial_labor_emergencia');
SELECT pruebas.esperar_rechazo('G02-P02-L-02', 'AC-G02-P02-01', 'excepción de emergencia sobre una labor no marcada como emergencia',
     $q$ INSERT INTO excepcion_emergencia (labor_id, orden_id, riesgo, justificacion, alcance_minimo, autorizada_por_id, fecha_hora)
         VALUES (pruebas.labor_id(9004, 'Cambio de bujes'), 9004, 'Ruido', 'Justificación suficientemente larga', 'Bujes', 205, '2026-11-05 10:30') $q$,
     'no está marcada como emergencia');
SELECT pruebas.esperar_rechazo('G02-P02-L-02', 'AC-G02-P02-01', 'emergencia con justificación insuficiente',
     $q$ SELECT fn_registrar_emergencia(9004, 4109, 'Bujes urgentes', 'Ruido', 'Porque sí', 'Cambiar bujes', 205, '2026-11-05 10:30') $q$,
     'ck_emergencia_justificacion');
SELECT pruebas.verificar('G02-P02-L-02', 'AC-G02-P02-01', 'la propuesta y las demás labores no cambiaron',
     (SELECT count(*) = 1 FROM linea_propuesta WHERE orden_id = 9004)
     AND (SELECT count(*) = 2 FROM labor WHERE orden_id = 9004)
     AND (SELECT estado_labor = 'Pendiente' FROM labor WHERE labor_id = pruebas.labor_id(9004, 'Cambio de bujes')),
     '1 línea, 2 labores, bujes Pendiente',
     (SELECT count(*) FROM linea_propuesta WHERE orden_id = 9004) || ' línea, '
     || (SELECT count(*) FROM labor WHERE orden_id = 9004) || ' labores, bujes '
     || (SELECT estado_labor FROM labor WHERE labor_id = pruebas.labor_id(9004, 'Cambio de bujes')));

-- ===========================================================
-- ID: G02-P02-L-03     Criterio: AC-G02-P02-02
-- Preparación: S (sensor) de 9003 En proceso.
-- Acción: participación de Sofía con intervalo de 120 min y 75 efectivos;
--   otra con intervalo de 120 y exactamente 120 efectivos (borde).
-- Esperado: ambas válidas.
-- ===========================================================
SELECT fn_registrar_participacion(pruebas.labor_id(9003, 'Sustitución del sensor'), 203,
       '2026-11-05 13:00', '2026-11-05 15:00', 75, 'Diagnóstico eléctrico con pausas por espera de repuesto', 3);
SELECT fn_registrar_participacion(pruebas.labor_id(9003, 'Sustitución del sensor'), 203,
       '2026-11-05 15:00', '2026-11-05 17:00', 120, 'Montaje y calibración sin pausas', 3);
SELECT pruebas.verificar('G02-P02-L-03', 'AC-G02-P02-02', 'intervalo 120 / efectivos 75 y 120 / 120',
     (SELECT string_agg(minutos_efectivos || '/' || minutos_intervalo, ',' ORDER BY participacion_id) = '75/120,120/120'
      FROM v_participaciones WHERE labor_id = pruebas.labor_id(9003, 'Sustitución del sensor')),
     '75/120,120/120',
     (SELECT string_agg(minutos_efectivos || '/' || minutos_intervalo, ',' ORDER BY participacion_id)
      FROM v_participaciones WHERE labor_id = pruebas.labor_id(9003, 'Sustitución del sensor')));

-- ===========================================================
-- ID: G02-P02-L-04     Criterio: AC-G02-P02-02, AC-G02-P02-03
-- Acción: participación ABIERTA de Andrés en S; intentar completar S;
--   cerrarla; consumir el sensor; registrar la prueba; completar S. Luego
--   U (que dependía de S) ya puede iniciarse.
-- Esperado: completar con participación abierta se rechaza; tras cerrarla
--   se completa; U inicia porque su dependencia ya está Completada.
-- ===========================================================
SELECT fn_registrar_participacion(pruebas.labor_id(9003, 'Sustitución del sensor'), 204,
       '2026-11-05 17:00', NULL, NULL, 'Revisión de cableado (en curso)', 4);
SELECT pruebas.esperar_rechazo('G02-P02-L-04', 'AC-G02-P02-03', 'completar con una participación abierta',
     $q$ SELECT fn_completar_labor(pruebas.labor_id(9003, 'Sustitución del sensor'), 203, '2026-11-05 17:10') $q$,
     'tiene participaciones abiertas');
SELECT fn_cerrar_participacion((SELECT participacion_id FROM participacion_tecnica
                                WHERE labor_id = pruebas.labor_id(9003, 'Sustitución del sensor') AND fin IS NULL),
                               '2026-11-05 17:30', 25);
SELECT fn_registrar_consumo(9003, pruebas.labor_id(9003, 'Sustitución del sensor'), 'EL-001', 1, 41000, 203, '2026-11-05 15:30');
SELECT fn_registrar_prueba(pruebas.labor_id(9003, 'Sustitución del sensor'), 203, '2026-11-05 17:35',
       'Lectura del sensor con escáner', 'Favorable', 'Señal oscilando entre 0,1 y 0,9 V', 0.45, 'V');
SELECT fn_completar_labor(pruebas.labor_id(9003, 'Sustitución del sensor'), 203, '2026-11-05 17:40');
SELECT fn_iniciar_labor(pruebas.labor_id(9003, 'Borrado de códigos'), 203, '2026-11-05 17:45');
SELECT pruebas.verificar('G02-P02-L-04', 'AC-G02-P02-01', 'S Completada y U iniciada tras cumplir su dependencia',
     (SELECT estado_labor = 'Completada' FROM labor WHERE labor_id = pruebas.labor_id(9003, 'Sustitución del sensor'))
     AND (SELECT estado_labor = 'En proceso' FROM labor WHERE labor_id = pruebas.labor_id(9003, 'Borrado de códigos')),
     'S Completada; U En proceso',
     'S ' || (SELECT estado_labor FROM labor WHERE labor_id = pruebas.labor_id(9003, 'Sustitución del sensor'))
     || '; U ' || (SELECT estado_labor FROM labor WHERE labor_id = pruebas.labor_id(9003, 'Borrado de códigos')));

-- ===========================================================
-- ID: G02-P02-L-05     Criterio: AC-G02-P02-01
-- Acción: suspender U sin motivo (rechazo), suspenderla con motivo y
--   reanudarla.
-- Esperado: al reanudar se vuelve a exigir y registrar el habilitante (la
--   misma autorización aplicable); la historia conserva la suspensión.
-- ===========================================================
SELECT pruebas.esperar_rechazo('G02-P02-L-05', 'AC-G02-P02-01', 'suspender sin motivo',
     $q$ SELECT fn_suspender_labor(pruebas.labor_id(9003, 'Borrado de códigos'), 203, NULL, '2026-11-05 17:50') $q$,
     'requiere motivo');
SELECT fn_suspender_labor(pruebas.labor_id(9003, 'Borrado de códigos'), 203, 'Falta el equipo analizador de gases', '2026-11-05 17:50');
SELECT fn_iniciar_labor(pruebas.labor_id(9003, 'Borrado de códigos'), 203, '2026-11-06 08:00');
SELECT * FROM v_historia_labor WHERE labor_id = pruebas.labor_id(9003, 'Borrado de códigos') ORDER BY secuencia;
SELECT pruebas.verificar('G02-P02-L-05', 'AC-G02-P02-01', 'suspensión y reanudación con habilitante',
     (SELECT string_agg(estado_nuevo, ' -> ' ORDER BY secuencia) = 'Pendiente -> En proceso -> Suspendida -> En proceso'
      FROM historial_labor WHERE labor_id = pruebas.labor_id(9003, 'Borrado de códigos'))
     AND (SELECT count(*) = 2 FROM historial_labor WHERE labor_id = pruebas.labor_id(9003, 'Borrado de códigos') AND autorizacion_id IS NOT NULL),
     'Pendiente -> En proceso -> Suspendida -> En proceso (2 inicios con autorización)',
     (SELECT string_agg(estado_nuevo, ' -> ' ORDER BY secuencia) FROM historial_labor WHERE labor_id = pruebas.labor_id(9003, 'Borrado de códigos')));
