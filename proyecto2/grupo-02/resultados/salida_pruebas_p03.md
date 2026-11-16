# Salida de las pruebas · P03

> Generado ejecutando de verdad, el 2026-11-16 04:07 UTC, en una base nueva (`taller_ruta27`).
>
> Comando: `psql -X -a -d taller_ruta27 -v ON_ERROR_STOP=1 -f pruebas/30_p03_validas.sql -f pruebas/31_p03_invalidas.sql -f pruebas/32_p03_limite.sql -f pruebas/33_p03_atomicidad.sql`

```text
-- =====================================================================
-- G02-P03 · Gestionar estados de la orden y fecha prometida · VÁLIDAS
-- Orden de trabajo: 9005 (Ana Solís, Nissan Leaf MNO345).
-- Promesa original (alta): 2026-11-10 17:00.
-- =====================================================================
SET search_path = taller, public;
SET
SET TIME ZONE 'America/Costa_Rica';
SET
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
BEGIN
SELECT fn_cambiar_estado_orden(9005, 'En diagnóstico', 203, NULL, '2026-11-06 11:30');
 fn_cambiar_estado_orden 
-------------------------
                      28
(1 row)

SELECT fn_publicar_propuesta(9005, NULL,
    '[{"clave":"BAT","descripcion":"Reemplazo de batería auxiliar 12 V","hallazgo_id":4110,
       "precio_estimado":15000,"alcance":"Sustituir batería y verificar carga",
       "repuestos":[{"repuesto_id":"EL-002","cantidad":1,"precio_unitario":52000}]}]'::jsonb,
    205, 'Presupuesto inicial', '2026-11-06 13:00');
 fn_publicar_propuesta 
-----------------------
                   321
(1 row)

SELECT fn_cambiar_estado_orden(9005, 'Pendiente autorización', 201, NULL, '2026-11-06 13:05');
 fn_cambiar_estado_orden 
-------------------------
                      29
(1 row)

SELECT fn_registrar_decision(pruebas.propuesta_id(9005, 1), pruebas.labor_id(9005, 'Reemplazo de batería'),
                             104, 'Aceptada', 'Teléfono', 201, '2026-11-06 14:00', 'Acepta por teléfono');
 fn_registrar_decision 
-----------------------
                   629
(1 row)

SELECT fn_cambiar_estado_orden(9005, 'Autorizada', 201, NULL, '2026-11-06 14:05');
 fn_cambiar_estado_orden 
-------------------------
                      30
(1 row)

SELECT fn_cambiar_estado_orden(9005, 'En reparación', 203, NULL, '2026-11-07 08:00');
 fn_cambiar_estado_orden 
-------------------------
                      31
(1 row)

SELECT fn_cambiar_estado_orden(9005, 'En diagnóstico', 203,
                               'Al reemplazar la batería se detecta falla en el convertidor DC-DC',
                               '2026-11-07 10:00');
 fn_cambiar_estado_orden 
-------------------------
                      32
(1 row)

SELECT fn_cambiar_estado_orden(9005, 'Pendiente autorización', 201, NULL, '2026-11-07 11:00');
 fn_cambiar_estado_orden 
-------------------------
                      33
(1 row)

SELECT fn_cambiar_estado_orden(9005, 'Autorizada', 201, NULL, '2026-11-07 11:30');
 fn_cambiar_estado_orden 
-------------------------
                      34
(1 row)

COMMIT;
COMMIT
-- Lectura posterior en una transacción NUEVA (persistencia).
SELECT * FROM v_cronologia_estados WHERE orden_id = 9005 ORDER BY secuencia;
 orden_id | secuencia |    estado_anterior     |      estado_nuevo      |       fecha_hora       | responsable  |                              motivo                               
----------+-----------+------------------------+------------------------+------------------------+--------------+-------------------------------------------------------------------
     9005 |         1 |                        | Recibida               | 2026-11-06 10:00:00-06 | Pablo Núñez  | 
     9005 |         2 | Recibida               | En diagnóstico         | 2026-11-06 11:30:00-06 | Sofía Arias  | 
     9005 |         3 | En diagnóstico         | Pendiente autorización | 2026-11-06 13:05:00-06 | Lucía Vargas | 
     9005 |         4 | Pendiente autorización | Autorizada             | 2026-11-06 14:05:00-06 | Lucía Vargas | 
     9005 |         5 | Autorizada             | En reparación          | 2026-11-07 08:00:00-06 | Sofía Arias  | 
     9005 |         6 | En reparación          | En diagnóstico         | 2026-11-07 10:00:00-06 | Sofía Arias  | Al reemplazar la batería se detecta falla en el convertidor DC-DC
     9005 |         7 | En diagnóstico         | Pendiente autorización | 2026-11-07 11:00:00-06 | Lucía Vargas | 
     9005 |         8 | Pendiente autorización | Autorizada             | 2026-11-07 11:30:00-06 | Lucía Vargas | 
(8 rows)

SELECT pruebas.verificar('G02-P03-V-01', 'AC-G02-P03-01', 'historial de estados de 9005 tras COMMIT',
     (SELECT count(*) = 8 AND min(secuencia) = 1 AND max(secuencia) = 8 FROM historial_orden WHERE orden_id = 9005),
     '8 cambios, secuencia 1..8 sin huecos',
     (SELECT count(*) || ' cambios, secuencia ' || min(secuencia) || '..' || max(secuencia) FROM historial_orden WHERE orden_id = 9005));
psql:pruebas/30_p03_validas.sql:49: NOTICE:  OK    [G02-P03-V-01] 8 cambios, secuencia 1..8 sin huecos -> 8 cambios, secuencia 1..8
                 verificar                  
--------------------------------------------
 OK G02-P03-V-01: 8 cambios, secuencia 1..8
(1 row)

SELECT pruebas.verificar('G02-P03-V-01', 'AC-G02-P03-01', 'retroceso En reparación -> En diagnóstico con motivo',
     EXISTS (SELECT 1 FROM historial_orden WHERE orden_id = 9005 AND estado_anterior = 'En reparación'
             AND estado = 'En diagnóstico' AND motivo LIKE '%convertidor DC-DC%'),
     'retroceso registrado con su motivo',
     (SELECT estado_anterior || ' -> ' || estado || ' | ' || motivo FROM historial_orden
      WHERE orden_id = 9005 AND estado_anterior = 'En reparación'));
psql:pruebas/30_p03_validas.sql:56: NOTICE:  OK    [G02-P03-V-01] retroceso registrado con su motivo -> En reparación -> En diagnóstico | Al reemplazar la batería se detecta falla en el convertidor DC-DC
                                                      verificar                                                       
----------------------------------------------------------------------------------------------------------------------
 OK G02-P03-V-01: En reparación -> En diagnóstico | Al reemplazar la batería se detecta falla en el convertidor DC-DC
(1 row)

SELECT pruebas.verificar('G02-P03-V-01', 'AC-G02-P03-03', 'valor actual = último estado del historial',
     (SELECT o.estado_actual = 'Autorizada' AND o.estado_actual = (SELECT estado FROM historial_orden WHERE orden_id = 9005 ORDER BY secuencia DESC LIMIT 1)
      FROM orden_trabajo o WHERE orden_id = 9005),
     'estado_actual Autorizada, igual al historial',
     (SELECT estado_actual FROM orden_trabajo WHERE orden_id = 9005));
psql:pruebas/30_p03_validas.sql:62: NOTICE:  OK    [G02-P03-V-01] estado_actual Autorizada, igual al historial -> Autorizada
          verificar          
-----------------------------
 OK G02-P03-V-01: Autorizada
(1 row)

-- ===========================================================
-- ID: G02-P03-V-02     Criterio: AC-G02-P03-02
-- Preparación: orden 9005 con promesa original 2026-11-10 17:00.
-- Acción: dos reprogramaciones comunicadas (teléfono y correo) con motivo.
-- Esperado: 3 filas (original + 2); cada una conserva la fecha anterior,
--   medio, motivo y responsable; promesa actual 2026-11-13 12:00.
-- ===========================================================
BEGIN;
BEGIN
SELECT fn_cambiar_fecha_prometida(9005, '2026-11-12 17:00', '2026-11-07 10:15', 'Teléfono',
                                  'Se requiere diagnóstico adicional del convertidor DC-DC', 203);
 fn_cambiar_fecha_prometida 
----------------------------
                          9
(1 row)

SELECT fn_cambiar_fecha_prometida(9005, '2026-11-13 12:00', '2026-11-08 09:00', 'Correo',
                                  'El repuesto llega un día después de lo previsto', 201);
 fn_cambiar_fecha_prometida 
----------------------------
                         10
(1 row)

COMMIT;
COMMIT
SELECT * FROM v_cronologia_promesas WHERE orden_id = 9005 ORDER BY secuencia;
 orden_id | secuencia |     fecha_anterior     |      fecha_nueva       | fecha_hora_comunicacion | medio_comunicacion |                         motivo                          | responsable  | es_promesa_original 
----------+-----------+------------------------+------------------------+-------------------------+--------------------+---------------------------------------------------------+--------------+---------------------
     9005 |         1 |                        | 2026-11-10 17:00:00-06 | 2026-11-06 10:00:00-06  | Presencial         | Promesa original comunicada en la recepción             | Pablo Núñez  | t
     9005 |         2 | 2026-11-10 17:00:00-06 | 2026-11-12 17:00:00-06 | 2026-11-07 10:15:00-06  | Teléfono           | Se requiere diagnóstico adicional del convertidor DC-DC | Sofía Arias  | f
     9005 |         3 | 2026-11-12 17:00:00-06 | 2026-11-13 12:00:00-06 | 2026-11-08 09:00:00-06  | Correo             | El repuesto llega un día después de lo previsto         | Lucía Vargas | f
(3 rows)

SELECT * FROM v_promesas WHERE orden_id = 9005;
 orden_id |    promesa_original    |     promesa_actual     | reprogramaciones |                  ultimo_motivo                  
----------+------------------------+------------------------+------------------+-------------------------------------------------
     9005 | 2026-11-10 17:00:00-06 | 2026-11-13 12:00:00-06 |                2 | El repuesto llega un día después de lo previsto
(1 row)

SELECT pruebas.verificar('G02-P03-V-02', 'AC-G02-P03-02', 'promesa original, actual y número de cambios',
     (SELECT promesa_original = '2026-11-10 17:00'::timestamptz AND promesa_actual = '2026-11-13 12:00'::timestamptz
             AND reprogramaciones = 2 FROM v_promesas WHERE orden_id = 9005),
     'original 2026-11-10 17:00, actual 2026-11-13 12:00, 2 reprogramaciones',
     (SELECT 'original ' || promesa_original || ', actual ' || promesa_actual || ', ' || reprogramaciones || ' reprogramaciones'
      FROM v_promesas WHERE orden_id = 9005));
psql:pruebas/30_p03_validas.sql:86: NOTICE:  OK    [G02-P03-V-02] original 2026-11-10 17:00, actual 2026-11-13 12:00, 2 reprogramaciones -> original 2026-11-10 17:00:00-06, actual 2026-11-13 12:00:00-06, 2 reprogramaciones
                                              verificar                                              
-----------------------------------------------------------------------------------------------------
 OK G02-P03-V-02: original 2026-11-10 17:00:00-06, actual 2026-11-13 12:00:00-06, 2 reprogramaciones
(1 row)

SELECT pruebas.verificar('G02-P03-V-02', 'AC-G02-P03-02', 'cada cambio conserva la fecha anterior (no se sobrescribe)',
     (SELECT bool_and(fecha_anterior = lag_nueva) FROM (
         SELECT fecha_anterior, lag(fecha_nueva) OVER (ORDER BY secuencia) AS lag_nueva, secuencia
         FROM historial_fecha_prometida WHERE orden_id = 9005) x WHERE secuencia > 1),
     'fecha_anterior(n) = fecha_nueva(n-1) en toda la cadena',
     (SELECT string_agg(secuencia || ': ' || coalesce(fecha_anterior::text, 'NULL') || ' -> ' || fecha_nueva, ' | ' ORDER BY secuencia)
      FROM historial_fecha_prometida WHERE orden_id = 9005));
psql:pruebas/30_p03_validas.sql:94: NOTICE:  OK    [G02-P03-V-02] fecha_anterior(n) = fecha_nueva(n-1) en toda la cadena -> 1: NULL -> 2026-11-10 17:00:00-06 | 2: 2026-11-10 17:00:00-06 -> 2026-11-12 17:00:00-06 | 3: 2026-11-12 17:00:00-06 -> 2026-11-13 12:00:00-06
                                                                           verificar                                                                            
----------------------------------------------------------------------------------------------------------------------------------------------------------------
 OK G02-P03-V-02: 1: NULL -> 2026-11-10 17:00:00-06 | 2: 2026-11-10 17:00:00-06 -> 2026-11-12 17:00:00-06 | 3: 2026-11-12 17:00:00-06 -> 2026-11-13 12:00:00-06
(1 row)

-- Resultado observable final de la orden (estado y promesa en vistas separadas).
SELECT * FROM v_estado_actual_orden WHERE orden_id = 9005;
 orden_id |        vin        | placa_ingreso | cliente_factura | estado_actual |         desde          | registrado_por | fecha_prometida_actual 
----------+-------------------+---------------+-----------------+---------------+------------------------+----------------+------------------------
     9005 | JN1AZ4EH7DM000001 | MNO345        | Ana Solís       | Autorizada    | 2026-11-07 11:30:00-06 | Lucía Vargas   | 2026-11-13 12:00:00-06
(1 row)

-- =====================================================================
-- G02-P03 · Gestionar estados de la orden y fecha prometida · INVÁLIDAS
-- Cada intento debe rechazarse con causa visible; la lectura posterior
-- demuestra que ni el historial ni el valor actual cambiaron.
-- Órdenes: 9005 (Autorizada tras V-01) y 9006 (Recibida, con un daño sin
-- confirmar).
-- =====================================================================
SET search_path = taller, public;
SET
SET TIME ZONE 'America/Costa_Rica';
SET
-- ===========================================================
-- ID: G02-P03-I-01     Criterio: AC-G02-P03-03
-- Preparación: no existe la orden 99999.
-- Acción: cambiar su estado y su promesa.
-- Esperado: error explícito "la orden 99999 no existe" (no "0 filas").
-- ===========================================================
SELECT pruebas.esperar_rechazo('G02-P03-I-01', 'AC-G02-P03-03', 'cambio de estado de orden inexistente',
     $q$ SELECT fn_cambiar_estado_orden(99999, 'En diagnóstico', 201, NULL, '2026-11-08 10:00') $q$,
     'la orden 99999 no existe');
psql:pruebas/31_p03_invalidas.sql:19: NOTICE:  OK    [G02-P03-I-01] rechazo esperado -> P0001: G02-P03: la orden 99999 no existe
                      esperar_rechazo                      
-----------------------------------------------------------
 OK G02-P03-I-01: P0001: G02-P03: la orden 99999 no existe
(1 row)

SELECT pruebas.esperar_rechazo('G02-P03-I-01', 'AC-G02-P03-03', 'cambio de promesa de orden inexistente',
     $q$ SELECT fn_cambiar_fecha_prometida(99999, '2026-11-20 10:00', '2026-11-08 10:00', 'Teléfono', 'x', 201) $q$,
     'la orden 99999 no existe');
psql:pruebas/31_p03_invalidas.sql:22: NOTICE:  OK    [G02-P03-I-01] rechazo esperado -> P0001: G02-P03: la orden 99999 no existe
                      esperar_rechazo                      
-----------------------------------------------------------
 OK G02-P03-I-01: P0001: G02-P03: la orden 99999 no existe
(1 row)

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
psql:pruebas/31_p03_invalidas.sql:33: NOTICE:  OK    [G02-P03-I-02] rechazo esperado -> P0001: G02-P03: el cambio de fecha prometida de la orden 9006 requiere motivo (RN-07)
                                            esperar_rechazo                                             
--------------------------------------------------------------------------------------------------------
 OK G02-P03-I-02: P0001: G02-P03: el cambio de fecha prometida de la orden 9006 requiere motivo (RN-07)
(1 row)

SELECT pruebas.esperar_rechazo('G02-P03-I-02', 'AC-G02-P03-02', 'reprogramar 9006 con motivo vacío',
     $q$ SELECT fn_cambiar_fecha_prometida(9006, '2026-11-11 12:00', '2026-11-07 09:00', 'Teléfono', '   ', 206) $q$,
     'requiere motivo');
psql:pruebas/31_p03_invalidas.sql:36: NOTICE:  OK    [G02-P03-I-02] rechazo esperado -> P0001: G02-P03: el cambio de fecha prometida de la orden 9006 requiere motivo (RN-07)
                                            esperar_rechazo                                             
--------------------------------------------------------------------------------------------------------
 OK G02-P03-I-02: P0001: G02-P03: el cambio de fecha prometida de la orden 9006 requiere motivo (RN-07)
(1 row)

SELECT pruebas.verificar('G02-P03-I-02', 'AC-G02-P03-02', 'sin efectos en la promesa de 9006',
     (SELECT o.fecha_prometida_actual = '2026-11-09 12:00'::timestamptz
             AND (SELECT count(*) FROM historial_fecha_prometida WHERE orden_id = 9006) = 1
      FROM orden_trabajo o WHERE o.orden_id = 9006),
     'promesa 2026-11-09 12:00 y 1 fila de historial',
     (SELECT fecha_prometida_actual || ' y ' || (SELECT count(*) FROM historial_fecha_prometida WHERE orden_id = 9006) || ' fila(s)'
      FROM orden_trabajo WHERE orden_id = 9006));
psql:pruebas/31_p03_invalidas.sql:43: NOTICE:  OK    [G02-P03-I-02] promesa 2026-11-09 12:00 y 1 fila de historial -> 2026-11-09 12:00:00-06 y 1 fila(s)
                      verificar                      
-----------------------------------------------------
 OK G02-P03-I-02: 2026-11-09 12:00:00-06 y 1 fila(s)
(1 row)

-- ===========================================================
-- ID: G02-P03-I-03     Criterio: AC-G02-P03-01
-- Preparación: orden 9005 en 'Autorizada'.
-- Acción: retroceder a 'En diagnóstico' sin motivo.
-- Esperado: rechazo "requiere motivo"; 9005 sigue en Autorizada con 8 filas.
-- ===========================================================
SELECT pruebas.esperar_rechazo('G02-P03-I-03', 'AC-G02-P03-01', 'retroceso Autorizada -> En diagnóstico sin motivo',
     $q$ SELECT fn_cambiar_estado_orden(9005, 'En diagnóstico', 203, NULL, '2026-11-08 10:00') $q$,
     'requiere motivo');
psql:pruebas/31_p03_invalidas.sql:53: NOTICE:  OK    [G02-P03-I-03] rechazo esperado -> P0001: G02-P03: la transición Autorizada -> En diagnóstico requiere motivo
                                       esperar_rechazo                                       
---------------------------------------------------------------------------------------------
 OK G02-P03-I-03: P0001: G02-P03: la transición Autorizada -> En diagnóstico requiere motivo
(1 row)

SELECT pruebas.verificar('G02-P03-I-03', 'AC-G02-P03-01', 'sin efectos en 9005',
     (SELECT estado_actual = 'Autorizada' AND (SELECT count(*) FROM historial_orden WHERE orden_id = 9005) = 8
      FROM orden_trabajo WHERE orden_id = 9005),
     'Autorizada con 8 filas de historial',
     (SELECT estado_actual || ' con ' || (SELECT count(*) FROM historial_orden WHERE orden_id = 9005) || ' filas'
      FROM orden_trabajo WHERE orden_id = 9005));
psql:pruebas/31_p03_invalidas.sql:59: NOTICE:  OK    [G02-P03-I-03] Autorizada con 8 filas de historial -> Autorizada con 8 filas
                verificar                
-----------------------------------------
 OK G02-P03-I-03: Autorizada con 8 filas
(1 row)

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
psql:pruebas/31_p03_invalidas.sql:70: NOTICE:  OK    [G02-P03-I-04] rechazo esperado -> P0001: G02-P03: estado_actual y fecha_prometida_actual de la orden 9006 solo cambian mediante su historial (use fn_cambiar_estado_orden / fn_cambiar_fecha_prometida)
                                                                                    esperar_rechazo                                                                                     
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 OK G02-P03-I-04: P0001: G02-P03: estado_actual y fecha_prometida_actual de la orden 9006 solo cambian mediante su historial (use fn_cambiar_estado_orden / fn_cambiar_fecha_prometida)
(1 row)

SELECT pruebas.esperar_rechazo('G02-P03-I-04', 'AC-G02-P03-03', 'UPDATE directo de estado_actual',
     $q$ UPDATE orden_trabajo SET estado_actual = 'Cancelada' WHERE orden_id = 9006 $q$,
     'solo cambian mediante su historial');
psql:pruebas/31_p03_invalidas.sql:73: NOTICE:  OK    [G02-P03-I-04] rechazo esperado -> P0001: G02-P03: estado_actual y fecha_prometida_actual de la orden 9006 solo cambian mediante su historial (use fn_cambiar_estado_orden / fn_cambiar_fecha_prometida)
                                                                                    esperar_rechazo                                                                                     
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 OK G02-P03-I-04: P0001: G02-P03: estado_actual y fecha_prometida_actual de la orden 9006 solo cambian mediante su historial (use fn_cambiar_estado_orden / fn_cambiar_fecha_prometida)
(1 row)

SELECT pruebas.verificar('G02-P03-I-04', 'AC-G02-P03-03', 'valores actuales de 9006 intactos',
     (SELECT estado_actual = 'Recibida' AND fecha_prometida_actual = '2026-11-09 12:00'::timestamptz
      FROM orden_trabajo WHERE orden_id = 9006),
     'Recibida / 2026-11-09 12:00',
     (SELECT estado_actual || ' / ' || fecha_prometida_actual FROM orden_trabajo WHERE orden_id = 9006));
psql:pruebas/31_p03_invalidas.sql:78: NOTICE:  OK    [G02-P03-I-04] Recibida / 2026-11-09 12:00 -> Recibida / 2026-11-09 12:00:00-06
                     verificar                      
----------------------------------------------------
 OK G02-P03-I-04: Recibida / 2026-11-09 12:00:00-06
(1 row)

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
psql:pruebas/31_p03_invalidas.sql:93: NOTICE:  OK    [G02-P03-I-05] rechazo esperado -> P0001: G02-P03: la orden 9006 tiene objetos/daños sin confirmar por el cliente (RN-06)
                                             esperar_rechazo                                             
---------------------------------------------------------------------------------------------------------
 OK G02-P03-I-05: P0001: G02-P03: la orden 9006 tiene objetos/daños sin confirmar por el cliente (RN-06)
(1 row)

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
psql:pruebas/31_p03_invalidas.sql:103: NOTICE:  OK    [G02-P03-I-05] Recibida, promesa 2026-11-09 12:00, 1 + 1 filas -> Recibida, 2026-11-09 12:00:00-06, 1 + 1 filas
                           verificar                            
----------------------------------------------------------------
 OK G02-P03-I-05: Recibida, 2026-11-09 12:00:00-06, 1 + 1 filas
(1 row)

-- ===========================================================
-- ID: G02-P03-I-06     Criterio: AC-G02-P03-01
-- Acción: transiciones que no existen en el catálogo y "no cambios".
-- Esperado: rechazo "transición no permitida" / "ya está en".
-- ===========================================================
SELECT pruebas.esperar_rechazo('G02-P03-I-06', 'AC-G02-P03-01', 'Recibida -> Autorizada (salta diagnóstico)',
     $q$ SELECT fn_cambiar_estado_orden(9006, 'Autorizada', 206, NULL, '2026-11-07 09:00') $q$,
     'transición no permitida');
psql:pruebas/31_p03_invalidas.sql:112: NOTICE:  OK    [G02-P03-I-06] rechazo esperado -> P0001: G02-P03: transición no permitida de Recibida a Autorizada en la orden 9006
                                          esperar_rechazo                                           
----------------------------------------------------------------------------------------------------
 OK G02-P03-I-06: P0001: G02-P03: transición no permitida de Recibida a Autorizada en la orden 9006
(1 row)

SELECT pruebas.esperar_rechazo('G02-P03-I-06', 'AC-G02-P03-01', 'Autorizada -> Autorizada',
     $q$ SELECT fn_cambiar_estado_orden(9005, 'Autorizada', 201, NULL, '2026-11-08 10:00') $q$,
     'ya está en Autorizada');
psql:pruebas/31_p03_invalidas.sql:115: NOTICE:  OK    [G02-P03-I-06] rechazo esperado -> P0001: G02-P03: la orden 9005 ya está en Autorizada
                           esperar_rechazo                            
----------------------------------------------------------------------
 OK G02-P03-I-06: P0001: G02-P03: la orden 9005 ya está en Autorizada
(1 row)

SELECT pruebas.esperar_rechazo('G02-P03-I-06', 'AC-G02-P03-01', 'estado fuera del dominio',
     $q$ SELECT fn_cambiar_estado_orden(9006, 'Archivada', 206, NULL, '2026-11-07 09:00') $q$,
     'd_estado_orden');
psql:pruebas/31_p03_invalidas.sql:118: NOTICE:  OK    [G02-P03-I-06] rechazo esperado -> 23514: value for domain d_estado_orden violates check constraint "ck_d_estado_orden"
                                            esperar_rechazo                                            
-------------------------------------------------------------------------------------------------------
 OK G02-P03-I-06: 23514: value for domain d_estado_orden violates check constraint "ck_d_estado_orden"
(1 row)

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
psql:pruebas/31_p03_invalidas.sql:130: NOTICE:  OK    [G02-P03-I-07] rechazo esperado -> P0001: G02-P03: la secuencia la asigna el sistema (esperada 9, indicada 50)
                                       esperar_rechazo                                        
----------------------------------------------------------------------------------------------
 OK G02-P03-I-07: P0001: G02-P03: la secuencia la asigna el sistema (esperada 9, indicada 50)
(1 row)

SELECT pruebas.esperar_rechazo('G02-P03-I-07', 'AC-G02-P03-03', 'INSERT con estado_anterior falso',
     $q$ INSERT INTO historial_orden (orden_id, estado_anterior, estado, fecha_hora, personal_id)
         VALUES (9005, 'Lista entrega', 'En reparación', '2026-11-08 10:00', 203) $q$,
     'estado_anterior lo asigna el sistema');
psql:pruebas/31_p03_invalidas.sql:134: NOTICE:  OK    [G02-P03-I-07] rechazo esperado -> P0001: G02-P03: estado_anterior lo asigna el sistema (actual Autorizada, indicado Lista entrega)
                                                  esperar_rechazo                                                  
-------------------------------------------------------------------------------------------------------------------
 OK G02-P03-I-07: P0001: G02-P03: estado_anterior lo asigna el sistema (actual Autorizada, indicado Lista entrega)
(1 row)

SELECT pruebas.esperar_rechazo('G02-P03-I-07', 'AC-G02-P03-01', 'cambio con fecha anterior al último',
     $q$ SELECT fn_cambiar_estado_orden(9005, 'En reparación', 203, NULL, '2026-11-01 10:00') $q$,
     'anterior al último cambio');
psql:pruebas/31_p03_invalidas.sql:137: NOTICE:  OK    [G02-P03-I-07] rechazo esperado -> P0001: G02-P03: la fecha_hora 2026-11-01 10:00:00-06 es anterior al último cambio de estado (2026-11-07 11:30:00-06)
                                                            esperar_rechazo                                                            
---------------------------------------------------------------------------------------------------------------------------------------
 OK G02-P03-I-07: P0001: G02-P03: la fecha_hora 2026-11-01 10:00:00-06 es anterior al último cambio de estado (2026-11-07 11:30:00-06)
(1 row)

SELECT pruebas.esperar_rechazo('G02-P03-I-07', 'AC-G02-P03-03', 'UPDATE de una fila del historial',
     $q$ UPDATE historial_orden SET motivo = 'reescrito' WHERE orden_id = 9005 AND secuencia = 6 $q$,
     'solo inserción');
psql:pruebas/31_p03_invalidas.sql:140: NOTICE:  OK    [G02-P03-I-07] rechazo esperado -> P0001: G02-INM: historial_orden es de solo inserción; no se permite UPDATE (registre una fila nueva)
                                                    esperar_rechazo                                                    
-----------------------------------------------------------------------------------------------------------------------
 OK G02-P03-I-07: P0001: G02-INM: historial_orden es de solo inserción; no se permite UPDATE (registre una fila nueva)
(1 row)

SELECT pruebas.esperar_rechazo('G02-P03-I-07', 'AC-G02-P03-02', 'DELETE de una promesa',
     $q$ DELETE FROM historial_fecha_prometida WHERE orden_id = 9005 AND secuencia = 2 $q$,
     'solo inserción');
psql:pruebas/31_p03_invalidas.sql:143: NOTICE:  OK    [G02-P03-I-07] rechazo esperado -> P0001: G02-INM: historial_fecha_prometida es de solo inserción; no se permite DELETE (registre una fila nueva)
                                                         esperar_rechazo                                                         
---------------------------------------------------------------------------------------------------------------------------------
 OK G02-P03-I-07: P0001: G02-INM: historial_fecha_prometida es de solo inserción; no se permite DELETE (registre una fila nueva)
(1 row)

SELECT pruebas.esperar_rechazo('G02-P03-I-07', 'AC-G02-P03-01', 'cambio registrado por personal inactivo',
     $q$ SELECT fn_cambiar_estado_orden(9005, 'En reparación', 207, NULL, '2026-11-08 10:00') $q$,
     'no está activo');
psql:pruebas/31_p03_invalidas.sql:146: NOTICE:  OK    [G02-P03-I-07] rechazo esperado -> P0001: G02-P03: cambio de estado: el personal 207 no está activo
                                  esperar_rechazo                                  
-----------------------------------------------------------------------------------
 OK G02-P03-I-07: P0001: G02-P03: cambio de estado: el personal 207 no está activo
(1 row)

SELECT pruebas.verificar('G02-P03-I-07', 'AC-G02-P03-03', 'historial de 9005 intacto',
     (SELECT count(*) = 8 FROM historial_orden WHERE orden_id = 9005)
     AND (SELECT count(*) = 3 FROM historial_fecha_prometida WHERE orden_id = 9005),
     '8 estados y 3 promesas',
     (SELECT count(*) FROM historial_orden WHERE orden_id = 9005) || ' estados y '
     || (SELECT count(*) FROM historial_fecha_prometida WHERE orden_id = 9005) || ' promesas');
psql:pruebas/31_p03_invalidas.sql:152: NOTICE:  OK    [G02-P03-I-07] 8 estados y 3 promesas -> 8 estados y 3 promesas
                verificar                
-----------------------------------------
 OK G02-P03-I-07: 8 estados y 3 promesas
(1 row)

-- =====================================================================
-- G02-P03 · Gestionar estados de la orden y fecha prometida · LÍMITE
-- Órdenes: 9006 (Ana, Hyundai PQR678) y 9004 (Mensajería, sin promesa).
-- =====================================================================
SET search_path = taller, public;
SET
SET TIME ZONE 'America/Costa_Rica';
SET
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
UPDATE 1
BEGIN;
BEGIN
SELECT fn_cambiar_fecha_prometida(9006, '2026-11-10 12:00', '2026-11-07 08:50', 'Presencial',
                                  'Se agrega revisión de amortiguadores', 206);
 fn_cambiar_fecha_prometida 
----------------------------
                         14
(1 row)

SELECT fn_cambiar_fecha_prometida(9006, '2026-11-10 15:00', '2026-11-07 08:50', 'Presencial',
                                  'Corrección: la tarde del mismo día', 206);
 fn_cambiar_fecha_prometida 
----------------------------
                         15
(1 row)

SELECT fn_cambiar_estado_orden(9006, 'En diagnóstico', 204, NULL, '2026-11-07 09:00');
 fn_cambiar_estado_orden 
-------------------------
                      44
(1 row)

SELECT fn_cambiar_estado_orden(9006, 'Cancelada', 206,
                               'La clienta decide vender el vehículo sin repararlo', '2026-11-07 09:00');
 fn_cambiar_estado_orden 
-------------------------
                      45
(1 row)

COMMIT;
COMMIT
SELECT * FROM v_cronologia_estados WHERE orden_id = 9006 ORDER BY secuencia;
 orden_id | secuencia | estado_anterior |  estado_nuevo  |       fecha_hora       |  responsable  |                       motivo                       
----------+-----------+-----------------+----------------+------------------------+---------------+----------------------------------------------------
     9006 |         1 |                 | Recibida       | 2026-11-06 11:00:00-06 | Pablo Núñez   | 
     9006 |         2 | Recibida        | En diagnóstico | 2026-11-07 09:00:00-06 | Andrés Castro | 
     9006 |         3 | En diagnóstico  | Cancelada      | 2026-11-07 09:00:00-06 | Pablo Núñez   | La clienta decide vender el vehículo sin repararlo
(3 rows)

SELECT * FROM v_cronologia_promesas WHERE orden_id = 9006 ORDER BY secuencia;
 orden_id | secuencia |     fecha_anterior     |      fecha_nueva       | fecha_hora_comunicacion | medio_comunicacion |                   motivo                    | responsable | es_promesa_original 
----------+-----------+------------------------+------------------------+-------------------------+--------------------+---------------------------------------------+-------------+---------------------
     9006 |         1 |                        | 2026-11-09 12:00:00-06 | 2026-11-06 11:00:00-06  | Presencial         | Promesa original comunicada en la recepción | Pablo Núñez | t
     9006 |         2 | 2026-11-09 12:00:00-06 | 2026-11-10 12:00:00-06 | 2026-11-07 08:50:00-06  | Presencial         | Se agrega revisión de amortiguadores        | Pablo Núñez | f
     9006 |         3 | 2026-11-10 12:00:00-06 | 2026-11-10 15:00:00-06 | 2026-11-07 08:50:00-06  | Presencial         | Corrección: la tarde del mismo día          | Pablo Núñez | f
(3 rows)

SELECT pruebas.verificar('G02-P03-L-01', 'AC-G02-P03-04', 'mismo instante ordenado por secuencia',
     (SELECT string_agg(secuencia || ':' || estado, ',' ORDER BY secuencia) = '1:Recibida,2:En diagnóstico,3:Cancelada'
      FROM historial_orden WHERE orden_id = 9006)
     AND (SELECT count(DISTINCT fecha_hora) = 1 FROM historial_orden WHERE orden_id = 9006 AND secuencia IN (2, 3)),
     '1:Recibida,2:En diagnóstico,3:Cancelada (2 y 3 con la misma fecha_hora)',
     (SELECT string_agg(secuencia || ':' || estado || '@' || to_char(fecha_hora, 'HH24:MI'), ',' ORDER BY secuencia)
      FROM historial_orden WHERE orden_id = 9006));
psql:pruebas/32_p03_limite.sql:38: NOTICE:  OK    [G02-P03-L-01] 1:Recibida,2:En diagnóstico,3:Cancelada (2 y 3 con la misma fecha_hora) -> 1:Recibida@11:00,2:En diagnóstico@09:00,3:Cancelada@09:00
                                 verificar                                  
----------------------------------------------------------------------------
 OK G02-P03-L-01: 1:Recibida@11:00,2:En diagnóstico@09:00,3:Cancelada@09:00
(1 row)

SELECT pruebas.verificar('G02-P03-L-01', 'AC-G02-P03-04', 'promesas del mismo instante ordenadas por secuencia',
     (SELECT string_agg(secuencia::text, ',' ORDER BY secuencia) = '1,2,3'
             AND max(fecha_nueva) FILTER (WHERE secuencia = 3) = '2026-11-10 15:00'::timestamptz
      FROM historial_fecha_prometida WHERE orden_id = 9006),
     'secuencias 1,2,3; la vigente es la de secuencia 3 (15:00)',
     (SELECT string_agg(secuencia || ':' || to_char(fecha_nueva, 'DD HH24:MI'), ',' ORDER BY secuencia)
      FROM historial_fecha_prometida WHERE orden_id = 9006));
psql:pruebas/32_p03_limite.sql:45: NOTICE:  OK    [G02-P03-L-01] secuencias 1,2,3; la vigente es la de secuencia 3 (15:00) -> 1:09 12:00,2:10 12:00,3:10 15:00
                     verificar                     
---------------------------------------------------
 OK G02-P03-L-01: 1:09 12:00,2:10 12:00,3:10 15:00
(1 row)

-- ===========================================================
-- ID: G02-P03-L-02     Criterio: AC-G02-P03-04
-- Preparación: orden 9006 Cancelada.
-- Acción: consultar su historia completa; intentar cambiarle el estado,
--   la promesa o borrarla.
-- Esperado: la orden y TODA su historia siguen consultables; Cancelada es
--   terminal (no se reabre) y la orden no se borra.
-- ===========================================================
SELECT * FROM v_estado_actual_orden WHERE orden_id = 9006;
 orden_id |        vin        | placa_ingreso | cliente_factura | estado_actual |         desde          | registrado_por | fecha_prometida_actual 
----------+-------------------+---------------+-----------------+---------------+------------------------+----------------+------------------------
     9006 | KMHCT41DAEU000001 | PQR678        | Ana Solís       | Cancelada     | 2026-11-07 09:00:00-06 | Pablo Núñez    | 2026-11-10 15:00:00-06
(1 row)

SELECT pruebas.verificar('G02-P03-L-02', 'AC-G02-P03-04', 'orden cancelada consultable con toda su historia',
     (SELECT estado_actual = 'Cancelada' FROM orden_trabajo WHERE orden_id = 9006)
     AND (SELECT count(*) = 3 FROM v_cronologia_estados WHERE orden_id = 9006)
     AND (SELECT count(*) = 3 FROM v_cronologia_promesas WHERE orden_id = 9006),
     'Cancelada; 3 estados y 3 promesas visibles',
     (SELECT estado_actual FROM orden_trabajo WHERE orden_id = 9006) || '; '
     || (SELECT count(*) FROM v_cronologia_estados WHERE orden_id = 9006) || ' estados y '
     || (SELECT count(*) FROM v_cronologia_promesas WHERE orden_id = 9006) || ' promesas');
psql:pruebas/32_p03_limite.sql:63: NOTICE:  OK    [G02-P03-L-02] Cancelada; 3 estados y 3 promesas visibles -> Cancelada; 3 estados y 3 promesas
                     verificar                      
----------------------------------------------------
 OK G02-P03-L-02: Cancelada; 3 estados y 3 promesas
(1 row)

SELECT pruebas.esperar_rechazo('G02-P03-L-02', 'AC-G02-P03-04', 'reabrir una orden Cancelada',
     $q$ SELECT fn_cambiar_estado_orden(9006, 'En diagnóstico', 204, 'Reabrir', '2026-11-08 09:00') $q$,
     'transición no permitida de Cancelada');
psql:pruebas/32_p03_limite.sql:66: NOTICE:  OK    [G02-P03-L-02] rechazo esperado -> P0001: G02-P03: transición no permitida de Cancelada a En diagnóstico en la orden 9006
                                             esperar_rechazo                                             
---------------------------------------------------------------------------------------------------------
 OK G02-P03-L-02: P0001: G02-P03: transición no permitida de Cancelada a En diagnóstico en la orden 9006
(1 row)

SELECT pruebas.esperar_rechazo('G02-P03-L-02', 'AC-G02-P03-04', 'reprogramar una orden Cancelada',
     $q$ SELECT fn_cambiar_fecha_prometida(9006, '2026-11-20 12:00', '2026-11-08 09:00', 'Correo', 'x', 206) $q$,
     'está Cancelada');
psql:pruebas/32_p03_limite.sql:69: NOTICE:  OK    [G02-P03-L-02] rechazo esperado -> P0001: G02-P03: la orden 9006 está Cancelada; su fecha prometida ya no se modifica
                                           esperar_rechazo                                           
-----------------------------------------------------------------------------------------------------
 OK G02-P03-L-02: P0001: G02-P03: la orden 9006 está Cancelada; su fecha prometida ya no se modifica
(1 row)

SELECT pruebas.esperar_rechazo('G02-P03-L-02', 'AC-G02-P03-04', 'borrar la orden cancelada',
     $q$ DELETE FROM orden_trabajo WHERE orden_id = 9006 $q$,
     'no se elimina');
psql:pruebas/32_p03_limite.sql:72: NOTICE:  OK    [G02-P03-L-02] rechazo esperado -> P0001: G02-INT: la orden 9006 no se elimina; use el estado Cancelada
                                    esperar_rechazo                                    
---------------------------------------------------------------------------------------
 OK G02-P03-L-02: P0001: G02-INT: la orden 9006 no se elimina; use el estado Cancelada
(1 row)

-- ===========================================================
-- ID: G02-P03-L-03     Criterio: AC-G02-P03-02
-- Preparación: orden 9004 se recibió SIN fecha prometida.
-- Acción: registrar la primera promesa sin motivo.
-- Esperado: aceptada como promesa ORIGINAL (secuencia 1, fecha_anterior
--   NULL); el motivo solo es obligatorio en las reprogramaciones.
-- ===========================================================
SELECT fn_cambiar_fecha_prometida(9004, '2026-11-08 17:00', '2026-11-05 09:30', 'Teléfono', NULL, 201);
 fn_cambiar_fecha_prometida 
----------------------------
                         17
(1 row)

SELECT pruebas.verificar('G02-P03-L-03', 'AC-G02-P03-02', 'primera promesa sin motivo = promesa original',
     (SELECT secuencia = 1 AND fecha_anterior IS NULL AND motivo IS NULL
      FROM historial_fecha_prometida WHERE orden_id = 9004)
     AND (SELECT fecha_prometida_actual = '2026-11-08 17:00'::timestamptz FROM orden_trabajo WHERE orden_id = 9004),
     'secuencia 1, fecha_anterior NULL, actual 2026-11-08 17:00',
     (SELECT 'secuencia ' || secuencia || ', anterior ' || coalesce(fecha_anterior::text, 'NULL') || ', nueva ' || fecha_nueva
      FROM historial_fecha_prometida WHERE orden_id = 9004));
psql:pruebas/32_p03_limite.sql:88: NOTICE:  OK    [G02-P03-L-03] secuencia 1, fecha_anterior NULL, actual 2026-11-08 17:00 -> secuencia 1, anterior NULL, nueva 2026-11-08 17:00:00-06
                                 verificar                                 
---------------------------------------------------------------------------
 OK G02-P03-L-03: secuencia 1, anterior NULL, nueva 2026-11-08 17:00:00-06
(1 row)

-- ===========================================================
-- ID: G02-P03-L-04     Criterio: AC-G02-P03-01
-- Retroceso permitido: ver G02-P03-V-01 (En reparación -> En diagnóstico
-- con motivo). Aquí se comprueba que el catálogo NO impone una
-- prohibición universal de retroceso: lista los retrocesos admitidos.
-- ===========================================================
SELECT estado_desde, estado_hacia, requiere_motivo, descripcion
FROM transicion_estado_orden WHERE descripcion LIKE 'Retroceso%' ORDER BY estado_desde, estado_hacia;
      estado_desde      |      estado_hacia      | requiere_motivo |                   descripcion                   
------------------------+------------------------+-----------------+-------------------------------------------------
 Autorizada             | En diagnóstico         | t               | Retroceso: se requiere diagnóstico adicional
 Autorizada             | Pendiente autorización | t               | Retroceso: nueva versión de propuesta
 En reparación          | En diagnóstico         | t               | Retroceso: hallazgo nuevo durante la reparación
 En reparación          | Pendiente autorización | t               | Retroceso: ampliación que requiere decisión
 Lista entrega          | En reparación          | t               | Retroceso: retrabajo antes de entregar
 Pendiente autorización | En diagnóstico         | t               | Retroceso: se requiere diagnóstico adicional
(6 rows)

SELECT pruebas.verificar('G02-P03-L-04', 'AC-G02-P03-01', 'retrocesos admitidos y todos con motivo obligatorio',
     (SELECT count(*) >= 5 AND bool_and(requiere_motivo) FROM transicion_estado_orden WHERE descripcion LIKE 'Retroceso%'),
     '>= 5 retrocesos, todos con motivo',
     (SELECT count(*) || ' retrocesos; con motivo: ' || bool_and(requiere_motivo) FROM transicion_estado_orden WHERE descripcion LIKE 'Retroceso%'));
psql:pruebas/32_p03_limite.sql:101: NOTICE:  OK    [G02-P03-L-04] >= 5 retrocesos, todos con motivo -> 6 retrocesos; con motivo: true
                    verificar                    
-------------------------------------------------
 OK G02-P03-L-04: 6 retrocesos; con motivo: true
(1 row)

-- =====================================================================
-- G02-P03 · ATOMICIDAD
-- =====================================================================
SET search_path = taller, public;
SET
SET TIME ZONE 'America/Costa_Rica';
SET
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
psql:pruebas/33_p03_atomicidad.sql:22: NOTICE:  OK    [G02-P03-A-01] rechazo esperado -> 23514: new row for relation "historial_fecha_prometida" violates check constraint "ck_hfp_promesa_futura"
                                                      esperar_rechazo                                                       
----------------------------------------------------------------------------------------------------------------------------
 OK G02-P03-A-01: 23514: new row for relation "historial_fecha_prometida" violates check constraint "ck_hfp_promesa_futura"
(1 row)

SELECT pruebas.verificar('G02-P03-A-01', 'AC-G02-P03-03', 'nada quedó del bloque fallido',
     (SELECT estado_actual = 'Autorizada' AND fecha_prometida_actual = '2026-11-13 12:00'::timestamptz
      FROM orden_trabajo WHERE orden_id = 9005)
     AND (SELECT count(*) = 8 FROM historial_orden WHERE orden_id = 9005)
     AND (SELECT count(*) = 3 FROM historial_fecha_prometida WHERE orden_id = 9005),
     'Autorizada / 2026-11-13 12:00 / 8 estados / 3 promesas',
     (SELECT estado_actual || ' / ' || fecha_prometida_actual FROM orden_trabajo WHERE orden_id = 9005)
     || ' / ' || (SELECT count(*) FROM historial_orden WHERE orden_id = 9005) || ' estados / '
     || (SELECT count(*) FROM historial_fecha_prometida WHERE orden_id = 9005) || ' promesas');
psql:pruebas/33_p03_atomicidad.sql:31: NOTICE:  OK    [G02-P03-A-01] Autorizada / 2026-11-13 12:00 / 8 estados / 3 promesas -> Autorizada / 2026-11-13 12:00:00-06 / 8 estados / 3 promesas
                                   verificar                                   
-------------------------------------------------------------------------------
 OK G02-P03-A-01: Autorizada / 2026-11-13 12:00:00-06 / 8 estados / 3 promesas
(1 row)

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
psql:pruebas/33_p03_atomicidad.sql:50: NOTICE:  OK    [G02-P03-A-02] rechazo esperado -> P0001: G02-P03: estado_actual (En reparación) de la orden 9013 no coincide con su historial (Recibida)
                                                     esperar_rechazo                                                     
-------------------------------------------------------------------------------------------------------------------------
 OK G02-P03-A-02: P0001: G02-P03: estado_actual (En reparación) de la orden 9013 no coincide con su historial (Recibida)
(1 row)

SELECT pruebas.verificar('G02-P03-A-02', 'AC-G02-P03-03', '9013 sigue coherente',
     (SELECT estado_actual = 'Recibida' FROM orden_trabajo WHERE orden_id = 9013),
     'Recibida', (SELECT estado_actual FROM orden_trabajo WHERE orden_id = 9013));
psql:pruebas/33_p03_atomicidad.sql:53: NOTICE:  OK    [G02-P03-A-02] Recibida -> Recibida
         verificar         
---------------------------
 OK G02-P03-A-02: Recibida
(1 row)

```
