# Salida de las pruebas · INTEGRIDAD

> Generado ejecutando de verdad, el 2026-11-16 04:07 UTC, en una base nueva (`taller_ruta27`).
>
> Comando: `psql -X -a -d taller_ruta27 -v ON_ERROR_STOP=1 -f pruebas/90_integridad_modelo.sql`

```text
-- =====================================================================
-- IC-4301 · Proyecto 2 · Grupo 02 · Taller Ruta 27
-- Archivo: pruebas/90_integridad_modelo.sql
-- Integridad del MODELO COMPLETO (relaciones fuera de los procesos y
-- validaciones que en el P1 quedaron como "validación posterior").
-- Categorías: identidad, referencia, dominio, contexto, temporalidad,
-- estado. Cada rechazo muestra SQLSTATE + causa y va seguido de una
-- lectura que demuestra la ausencia de efectos; cada caso válido, de su
-- lectura posterior. Matriz completa: docs/matriz_regla_mecanismo_prueba.md
-- =====================================================================
SET search_path = taller, public;
SET
SET TIME ZONE 'America/Costa_Rica';
SET
-- #####################################################################
-- A. IDENTIDAD Y ROLES
-- #####################################################################
-- ===========================================================
-- ID: G02-INT-01   Relación: cliente      Categoría: identidad / dominio
-- ===========================================================
SELECT pruebas.esperar_rechazo('G02-INT-01', 'RN-04', 'identificación duplicada',
     $q$ INSERT INTO cliente (identificacion, nombre_razon_social, tipo_cliente) VALUES ('FICT-P001', 'Duplicada', 'Persona') $q$,
     'uq_cliente_identificacion');
psql:pruebas/90_integridad_modelo.sql:23: NOTICE:  OK    [G02-INT-01] rechazo esperado -> 23505: duplicate key value violates unique constraint "uq_cliente_identificacion"
                                         esperar_rechazo                                          
--------------------------------------------------------------------------------------------------
 OK G02-INT-01: 23505: duplicate key value violates unique constraint "uq_cliente_identificacion"
(1 row)

SELECT pruebas.esperar_rechazo('G02-INT-01', 'RN-04', 'tipo de cliente fuera de dominio',
     $q$ INSERT INTO cliente (identificacion, nombre_razon_social, tipo_cliente) VALUES ('FICT-X01', 'Tipo raro', 'Empresa') $q$,
     'ck_cliente_tipo');
psql:pruebas/90_integridad_modelo.sql:26: NOTICE:  OK    [G02-INT-01] rechazo esperado -> 23514: new row for relation "cliente" violates check constraint "ck_cliente_tipo"
                                         esperar_rechazo                                          
--------------------------------------------------------------------------------------------------
 OK G02-INT-01: 23514: new row for relation "cliente" violates check constraint "ck_cliente_tipo"
(1 row)

SELECT pruebas.esperar_rechazo('G02-INT-01', 'RN-04', 'nombre vacío',
     $q$ INSERT INTO cliente (identificacion, nombre_razon_social, tipo_cliente) VALUES ('FICT-X02', '   ', 'Persona') $q$,
     'ck_cliente_nombre');
psql:pruebas/90_integridad_modelo.sql:29: NOTICE:  OK    [G02-INT-01] rechazo esperado -> 23514: new row for relation "cliente" violates check constraint "ck_cliente_nombre"
                                          esperar_rechazo                                           
----------------------------------------------------------------------------------------------------
 OK G02-INT-01: 23514: new row for relation "cliente" violates check constraint "ck_cliente_nombre"
(1 row)

-- ===========================================================
-- ID: G02-INT-02   Relación: contacto_cliente   Categoría: identidad / dominio (RN-03)
-- Mecanismo: constraint trigger DIFERIDO (se evalúa al COMMIT). En la prueba
-- se fuerza con SET CONSTRAINTS ALL IMMEDIATE dentro de la subtransacción.
-- ===========================================================
SELECT pruebas.esperar_rechazo('G02-INT-02', 'RN-03', 'cliente sin contacto apto para avisos (al COMMIT)',
     $q$ DO $b$ BEGIN
            INSERT INTO cliente (identificacion, nombre_razon_social, tipo_cliente) VALUES ('FICT-P020', 'Sin contacto', 'Persona');
            SET CONSTRAINTS ALL IMMEDIATE;
         END $b$ $q$,
     'debe tener al menos un contacto apto para avisos');
psql:pruebas/90_integridad_modelo.sql:41: NOTICE:  OK    [G02-INT-02] rechazo esperado -> P0001: G02-INT: el cliente 904 debe tener al menos un contacto apto para avisos (RN-03)
                                            esperar_rechazo                                             
--------------------------------------------------------------------------------------------------------
 OK G02-INT-02: P0001: G02-INT: el cliente 904 debe tener al menos un contacto apto para avisos (RN-03)
(1 row)

SELECT pruebas.esperar_rechazo('G02-INT-02', 'RN-03', 'cliente con contacto que NO recibe avisos (al COMMIT)',
     $q$ DO $b$ DECLARE v integer; BEGIN
            INSERT INTO cliente (identificacion, nombre_razon_social, tipo_cliente) VALUES ('FICT-P021', 'Solo correo sin avisos', 'Persona')
            RETURNING cliente_id INTO v;
            INSERT INTO contacto_cliente (cliente_id, tipo_contacto, valor_contacto, recibe_avisos) VALUES (v, 'Correo', 'sin.avisos@ejemplo.test', false);
            SET CONSTRAINTS ALL IMMEDIATE;
         END $b$ $q$,
     'debe tener al menos un contacto apto para avisos');
psql:pruebas/90_integridad_modelo.sql:49: NOTICE:  OK    [G02-INT-02] rechazo esperado -> P0001: G02-INT: el cliente 905 debe tener al menos un contacto apto para avisos (RN-03)
                                            esperar_rechazo                                             
--------------------------------------------------------------------------------------------------------
 OK G02-INT-02: P0001: G02-INT: el cliente 905 debe tener al menos un contacto apto para avisos (RN-03)
(1 row)

SELECT pruebas.esperar_rechazo('G02-INT-02', 'RN-03', 'quitar el único contacto apto de María (al COMMIT)',
     $q$ DO $b$ BEGIN
            UPDATE contacto_cliente SET recibe_avisos = false WHERE contacto_id = 1;
            SET CONSTRAINTS ALL IMMEDIATE;
         END $b$ $q$,
     'el cliente 101 debe tener al menos un contacto apto');
psql:pruebas/90_integridad_modelo.sql:55: NOTICE:  OK    [G02-INT-02] rechazo esperado -> P0001: G02-INT: el cliente 101 debe tener al menos un contacto apto para avisos (RN-03)
                                            esperar_rechazo                                             
--------------------------------------------------------------------------------------------------------
 OK G02-INT-02: P0001: G02-INT: el cliente 101 debe tener al menos un contacto apto para avisos (RN-03)
(1 row)

SELECT pruebas.esperar_rechazo('G02-INT-02', 'RN-03', 'correo con formato inválido',
     $q$ INSERT INTO contacto_cliente (cliente_id, tipo_contacto, valor_contacto, recibe_avisos) VALUES (101, 'Correo', 'maria(arroba)ejemplo', false) $q$,
     'ck_contacto_formato');
psql:pruebas/90_integridad_modelo.sql:58: NOTICE:  OK    [G02-INT-02] rechazo esperado -> 23514: new row for relation "contacto_cliente" violates check constraint "ck_contacto_formato"
                                                esperar_rechazo                                                
---------------------------------------------------------------------------------------------------------------
 OK G02-INT-02: 23514: new row for relation "contacto_cliente" violates check constraint "ck_contacto_formato"
(1 row)

SELECT pruebas.esperar_rechazo('G02-INT-02', 'RN-03', 'teléfono con formato inválido',
     $q$ INSERT INTO contacto_cliente (cliente_id, tipo_contacto, valor_contacto, recibe_avisos) VALUES (101, 'Teléfono', '88-AB', false) $q$,
     'ck_contacto_formato');
psql:pruebas/90_integridad_modelo.sql:61: NOTICE:  OK    [G02-INT-02] rechazo esperado -> 23514: new row for relation "contacto_cliente" violates check constraint "ck_contacto_formato"
                                                esperar_rechazo                                                
---------------------------------------------------------------------------------------------------------------
 OK G02-INT-02: 23514: new row for relation "contacto_cliente" violates check constraint "ck_contacto_formato"
(1 row)

-- Válido: cliente y su contacto en la misma transacción (en cualquier orden).
BEGIN;
BEGIN
INSERT INTO cliente (cliente_id, identificacion, nombre_razon_social, tipo_cliente) VALUES (109, 'FICT-P009', 'Sara Vindas', 'Persona');
INSERT 0 1
INSERT INTO contacto_cliente (cliente_id, tipo_contacto, valor_contacto, recibe_avisos) VALUES (109, 'Teléfono', '+50688880109', true);
INSERT 0 1
COMMIT;
COMMIT
SELECT pruebas.verificar('G02-INT-02', 'RN-03', 'cliente nuevo con contacto apto confirmado',
     EXISTS (SELECT 1 FROM contacto_cliente WHERE cliente_id = 109 AND recibe_avisos)
     AND NOT EXISTS (SELECT 1 FROM cliente c WHERE NOT EXISTS (SELECT 1 FROM contacto_cliente k WHERE k.cliente_id = c.cliente_id AND k.recibe_avisos)),
     'todo cliente tiene >= 1 contacto apto',
     (SELECT count(*) || ' clientes, todos con contacto apto' FROM cliente));
psql:pruebas/90_integridad_modelo.sql:71: NOTICE:  OK    [G02-INT-02] todo cliente tiene >= 1 contacto apto -> 9 clientes, todos con contacto apto
                     verificar                      
----------------------------------------------------
 OK G02-INT-02: 9 clientes, todos con contacto apto
(1 row)

-- ===========================================================
-- ID: G02-INT-03   Relación: vehiculo   Categoría: identidad / dominio (RN-02)
-- ===========================================================
SELECT pruebas.esperar_rechazo('G02-INT-03', 'RN-02', 'VIN con letra O (no permitida)',
     $q$ INSERT INTO vehiculo VALUES ('1HGCM82633AO23456', 'XYZ001', 'Honda', 'Fit', 2020, 'Gasolina') $q$,
     'ck_vehiculo_vin');
psql:pruebas/90_integridad_modelo.sql:78: NOTICE:  OK    [G02-INT-03] rechazo esperado -> 23514: new row for relation "vehiculo" violates check constraint "ck_vehiculo_vin"
                                          esperar_rechazo                                          
---------------------------------------------------------------------------------------------------
 OK G02-INT-03: 23514: new row for relation "vehiculo" violates check constraint "ck_vehiculo_vin"
(1 row)

SELECT pruebas.esperar_rechazo('G02-INT-03', 'RN-02', 'VIN de 16 caracteres',
     $q$ INSERT INTO vehiculo VALUES ('1HGCM82633A12345', 'XYZ001', 'Honda', 'Fit', 2020, 'Gasolina') $q$,
     'ck_vehiculo_vin');
psql:pruebas/90_integridad_modelo.sql:81: NOTICE:  OK    [G02-INT-03] rechazo esperado -> 23514: new row for relation "vehiculo" violates check constraint "ck_vehiculo_vin"
                                          esperar_rechazo                                          
---------------------------------------------------------------------------------------------------
 OK G02-INT-03: 23514: new row for relation "vehiculo" violates check constraint "ck_vehiculo_vin"
(1 row)

SELECT pruebas.esperar_rechazo('G02-INT-03', 'RN-02', 'año mayor que el actual + 1',
     $q$ INSERT INTO vehiculo VALUES ('1HGCM82633A999999', 'XYZ001', 'Honda', 'Fit', extract(year FROM now())::int + 2, 'Gasolina') $q$,
     'supera el año actual + 1');
psql:pruebas/90_integridad_modelo.sql:84: NOTICE:  OK    [G02-INT-03] rechazo esperado -> P0001: G02-INT: el año 2028 del vehículo 1HGCM82633A999999 supera el año actual + 1
                                          esperar_rechazo                                           
----------------------------------------------------------------------------------------------------
 OK G02-INT-03: P0001: G02-INT: el año 2028 del vehículo 1HGCM82633A999999 supera el año actual + 1
(1 row)

SELECT pruebas.esperar_rechazo('G02-INT-03', 'RN-02', 'reescribir el VIN',
     $q$ UPDATE vehiculo SET vin = '1HGCM82633A000000' WHERE vin = '1HGCM82633A123456' $q$,
     'identidad estable');
psql:pruebas/90_integridad_modelo.sql:87: NOTICE:  OK    [G02-INT-03] rechazo esperado -> P0001: G02-INT: el VIN 1HGCM82633A123456 es la identidad estable del vehículo y no se modifica (RN-02)
                                                    esperar_rechazo                                                    
-----------------------------------------------------------------------------------------------------------------------
 OK G02-INT-03: P0001: G02-INT: el VIN 1HGCM82633A123456 es la identidad estable del vehículo y no se modifica (RN-02)
(1 row)

-- ===========================================================
-- ID: G02-INT-04   Relación: vehiculo / orden_trabajo   Categoría: temporalidad (RN-02)
-- Acción: la placa del Hyundai cambia de PQR678 a PQR999.
-- Esperado: la orden 9006 conserva placa_ingreso = PQR678.
-- ===========================================================
UPDATE vehiculo SET placa = 'PQR999' WHERE vin = 'KMHCT41DAEU000001';
UPDATE 1
SELECT pruebas.verificar('G02-INT-04', 'RN-02', 'la placa cambia sin afectar la visita previa',
     (SELECT v.placa = 'PQR999' AND o.placa_ingreso = 'PQR678'
      FROM orden_trabajo o JOIN vehiculo v USING (vin) WHERE o.orden_id = 9006),
     'vehículo PQR999; orden 9006 ingresó con PQR678',
     (SELECT 'vehículo ' || v.placa || '; orden 9006 ingresó con ' || o.placa_ingreso
      FROM orden_trabajo o JOIN vehiculo v USING (vin) WHERE o.orden_id = 9006));
psql:pruebas/90_integridad_modelo.sql:100: NOTICE:  OK    [G02-INT-04] vehículo PQR999; orden 9006 ingresó con PQR678 -> vehículo PQR999; orden 9006 ingresó con PQR678
                           verificar                           
---------------------------------------------------------------
 OK G02-INT-04: vehículo PQR999; orden 9006 ingresó con PQR678
(1 row)

-- ===========================================================
-- ID: G02-INT-05   Relación: propiedad_vehiculo   Categoría: temporalidad / contexto (D12)
-- Acción: Ana vende el Hyundai a Laura el 2026-11-10.
-- Esperado: la propiedad queda en dos periodos sin traslape; la visita
--   9006 sigue facturada a Ana; un traslape se rechaza; reescribir los roles
--   de la visita se rechaza.
-- ===========================================================
BEGIN;
BEGIN
UPDATE propiedad_vehiculo SET hasta = '2026-11-10' WHERE propiedad_id = 6;
UPDATE 1
INSERT INTO propiedad_vehiculo (vin, cliente_id, desde) VALUES ('KMHCT41DAEU000001', 107, '2026-11-10');
INSERT 0 1
COMMIT;
COMMIT
SELECT * FROM propiedad_vehiculo WHERE vin = 'KMHCT41DAEU000001' ORDER BY desde;
 propiedad_id |        vin        | cliente_id |   desde    |   hasta    
--------------+-------------------+------------+------------+------------
            6 | KMHCT41DAEU000001 |        104 | 2019-08-01 | 2026-11-10
          101 | KMHCT41DAEU000001 |        107 | 2026-11-10 | 
(2 rows)

SELECT pruebas.esperar_rechazo('G02-INT-05', 'RN-02', 'dos propietarios en el mismo periodo',
     $q$ INSERT INTO propiedad_vehiculo (vin, cliente_id, desde) VALUES ('KMHCT41DAEU000001', 108, '2026-11-15') $q$,
     'ex_propiedad_sin_traslape');
psql:pruebas/90_integridad_modelo.sql:116: NOTICE:  OK    [G02-INT-05] rechazo esperado -> 23P01: conflicting key value violates exclusion constraint "ex_propiedad_sin_traslape"
                                            esperar_rechazo                                            
-------------------------------------------------------------------------------------------------------
 OK G02-INT-05: 23P01: conflicting key value violates exclusion constraint "ex_propiedad_sin_traslape"
(1 row)

SELECT pruebas.esperar_rechazo('G02-INT-05', 'RN-04', 'reescribir a quién se facturó una visita anterior',
     $q$ UPDATE orden_trabajo SET cliente_factura_id = 107 WHERE orden_id = 9006 $q$,
     'quedan fijados por visita');
psql:pruebas/90_integridad_modelo.sql:119: NOTICE:  OK    [G02-INT-05] rechazo esperado -> P0001: G02-INT: los datos de recepción y los roles de la orden 9006 quedan fijados por visita y no se modifican
                                                        esperar_rechazo                                                         
--------------------------------------------------------------------------------------------------------------------------------
 OK G02-INT-05: P0001: G02-INT: los datos de recepción y los roles de la orden 9006 quedan fijados por visita y no se modifican
(1 row)

SELECT pruebas.verificar('G02-INT-05', 'RN-04', 'el cambio de propietario no reescribe la visita',
     (SELECT cliente_factura_id = 104 FROM orden_trabajo WHERE orden_id = 9006)
     AND (SELECT cliente_id = 107 FROM propiedad_vehiculo WHERE vin = 'KMHCT41DAEU000001' AND hasta IS NULL),
     'propietario actual Laura (107); visita 9006 facturada a Ana (104)',
     'propietario actual ' || (SELECT cliente_id FROM propiedad_vehiculo WHERE vin = 'KMHCT41DAEU000001' AND hasta IS NULL)
     || '; visita 9006 facturada a ' || (SELECT cliente_factura_id FROM orden_trabajo WHERE orden_id = 9006));
psql:pruebas/90_integridad_modelo.sql:125: NOTICE:  OK    [G02-INT-05] propietario actual Laura (107); visita 9006 facturada a Ana (104) -> propietario actual 107; visita 9006 facturada a 104
                             verificar                              
--------------------------------------------------------------------
 OK G02-INT-05: propietario actual 107; visita 9006 facturada a 104
(1 row)

-- ===========================================================
-- ID: G02-INT-06   Relación: orden_trabajo   Categoría: identidad / estado (RN-01, RN-05)
-- ===========================================================
SELECT pruebas.esperar_rechazo('G02-INT-06', 'RN-01', 'segunda visita abierta del mismo vehículo',
     $q$ INSERT INTO orden_trabajo (vin, cliente_factura_id, entregado_por_cliente_id, autorizador_cliente_id, receptor_id,
                                   fecha_hora_recepcion, kilometraje_ingreso, nivel_combustible, motivo_informado)
         VALUES ('1HGCM82633A123456', 101, 101, 101, 201, '2026-11-09 08:00', 85100, '1/2', 'Otra visita') $q$,
     'uq_orden_abierta_por_vehiculo');
psql:pruebas/90_integridad_modelo.sql:134: NOTICE:  OK    [G02-INT-06] rechazo esperado -> 23505: duplicate key value violates unique constraint "uq_orden_abierta_por_vehiculo"
                                           esperar_rechazo                                            
------------------------------------------------------------------------------------------------------
 OK G02-INT-06: 23505: duplicate key value violates unique constraint "uq_orden_abierta_por_vehiculo"
(1 row)

SELECT pruebas.esperar_rechazo('G02-INT-06', 'RN-05', 'kilometraje de ingreso negativo',
     $q$ INSERT INTO orden_trabajo (vin, cliente_factura_id, entregado_por_cliente_id, autorizador_cliente_id, receptor_id,
                                   kilometraje_ingreso, nivel_combustible, motivo_informado)
         VALUES ('2HGFC2F59KH000001', 108, 108, 108, 201, -1, '1/2', 'Km negativo') $q$,
     'ck_orden_km_ingreso');
psql:pruebas/90_integridad_modelo.sql:139: NOTICE:  OK    [G02-INT-06] rechazo esperado -> 23514: new row for relation "orden_trabajo" violates check constraint "ck_orden_km_ingreso"
                                              esperar_rechazo                                               
------------------------------------------------------------------------------------------------------------
 OK G02-INT-06: 23514: new row for relation "orden_trabajo" violates check constraint "ck_orden_km_ingreso"
(1 row)

SELECT pruebas.esperar_rechazo('G02-INT-06', 'RN-05', 'nivel de combustible fuera de dominio',
     $q$ INSERT INTO orden_trabajo (vin, cliente_factura_id, entregado_por_cliente_id, autorizador_cliente_id, receptor_id,
                                   kilometraje_ingreso, nivel_combustible, motivo_informado)
         VALUES ('2HGFC2F59KH000001', 108, 108, 108, 201, 100, '7/8', 'Combustible') $q$,
     'ck_orden_combustible');
psql:pruebas/90_integridad_modelo.sql:144: NOTICE:  OK    [G02-INT-06] rechazo esperado -> 23514: new row for relation "orden_trabajo" violates check constraint "ck_orden_combustible"
                                               esperar_rechazo                                               
-------------------------------------------------------------------------------------------------------------
 OK G02-INT-06: 23514: new row for relation "orden_trabajo" violates check constraint "ck_orden_combustible"
(1 row)

SELECT pruebas.esperar_rechazo('G02-INT-06', 'RN-08', 'orden sin estado inicial en el historial (al COMMIT)',
     $q$ DO $b$ BEGIN
            INSERT INTO orden_trabajo (vin, cliente_factura_id, entregado_por_cliente_id, autorizador_cliente_id, receptor_id,
                                       kilometraje_ingreso, nivel_combustible, motivo_informado)
            VALUES ('2HGFC2F59KH000001', 108, 108, 108, 201, 40000, '1/2', 'Sin historial');
            SET CONSTRAINTS ALL IMMEDIATE;
         END $b$ $q$,
     'no tiene su estado inicial');
psql:pruebas/90_integridad_modelo.sql:152: NOTICE:  OK    [G02-INT-06] rechazo esperado -> P0001: G02-P03: la orden 9904 no tiene su estado inicial en historial_orden
                                      esperar_rechazo                                       
--------------------------------------------------------------------------------------------
 OK G02-INT-06: P0001: G02-P03: la orden 9904 no tiene su estado inicial en historial_orden
(1 row)

SELECT pruebas.esperar_rechazo('G02-INT-06', 'RN-08', 'orden que nace en un estado distinto de Recibida',
     $q$ INSERT INTO orden_trabajo (vin, cliente_factura_id, entregado_por_cliente_id, autorizador_cliente_id, receptor_id,
                                   kilometraje_ingreso, nivel_combustible, motivo_informado, estado_actual)
         VALUES ('2HGFC2F59KH000001', 108, 108, 108, 201, 40000, '1/2', 'Estado inicial falso', 'Autorizada') $q$,
     'inicia en Recibida');
psql:pruebas/90_integridad_modelo.sql:157: NOTICE:  OK    [G02-INT-06] rechazo esperado -> P0001: G02-P03: una orden nueva inicia en Recibida (se indicó Autorizada)
                                     esperar_rechazo                                      
------------------------------------------------------------------------------------------
 OK G02-INT-06: P0001: G02-P03: una orden nueva inicia en Recibida (se indicó Autorizada)
(1 row)

SELECT pruebas.esperar_rechazo('G02-INT-06', 'RN-05', 'reescribir el kilometraje de ingreso',
     $q$ UPDATE orden_trabajo SET kilometraje_ingreso = 1 WHERE orden_id = 9001 $q$,
     'quedan fijados por visita');
psql:pruebas/90_integridad_modelo.sql:160: NOTICE:  OK    [G02-INT-06] rechazo esperado -> P0001: G02-INT: los datos de recepción y los roles de la orden 9001 quedan fijados por visita y no se modifican
                                                        esperar_rechazo                                                         
--------------------------------------------------------------------------------------------------------------------------------
 OK G02-INT-06: P0001: G02-INT: los datos de recepción y los roles de la orden 9001 quedan fijados por visita y no se modifican
(1 row)

-- Alta REUTILIZADA del Lab03 (sp_registrar_orden, sin modificar).
CALL sp_registrar_orden(9901, '2HGFC2F59KH000001', 108, 108, 108, 206, 40000, '1/2', 'Revisión general (alta reutilizada del Lab03)');
CALL
SELECT orden_id, vin, placa_ingreso, estado_actual, kilometraje_ingreso FROM orden_trabajo WHERE orden_id = 9901;
 orden_id |        vin        | placa_ingreso | estado_actual | kilometraje_ingreso 
----------+-------------------+---------------+---------------+---------------------
     9901 | 2HGFC2F59KH000001 | KLM789        | Recibida      |               40000
(1 row)

SELECT pruebas.verificar('G02-INT-06', 'RN-01', 'alta del Lab03 sobre el modelo nuevo',
     (SELECT placa_ingreso = 'KLM789' AND estado_actual = 'Recibida' FROM orden_trabajo WHERE orden_id = 9901)
     AND (SELECT count(*) = 1 AND min(secuencia) = 1 FROM historial_orden WHERE orden_id = 9901)
     AND (SELECT count(*) = 2 FROM facultad_orden WHERE orden_id = 9901),
     'placa KLM789, Recibida, historial secuencia 1, 2 facultades del titular',
     (SELECT placa_ingreso || ', ' || estado_actual FROM orden_trabajo WHERE orden_id = 9901) || ', '
     || (SELECT count(*) FROM historial_orden WHERE orden_id = 9901) || ' estado(s), '
     || (SELECT count(*) FROM facultad_orden WHERE orden_id = 9901) || ' facultades');
psql:pruebas/90_integridad_modelo.sql:172: NOTICE:  OK    [G02-INT-06] placa KLM789, Recibida, historial secuencia 1, 2 facultades del titular -> KLM789, Recibida, 1 estado(s), 2 facultades
                         verificar                          
------------------------------------------------------------
 OK G02-INT-06: KLM789, Recibida, 1 estado(s), 2 facultades
(1 row)

SELECT pruebas.esperar_rechazo('G02-INT-06', 'RN-05', 'alta del Lab03 con kilometraje negativo (validación propia del Lab03)',
     $q$ CALL sp_registrar_orden(9902, '2HGFC2F59KH000001', 108, 108, 108, 206, -50, '1/2', 'Km inválido') $q$,
     'no puede ser negativo');
psql:pruebas/90_integridad_modelo.sql:175: NOTICE:  OK    [G02-INT-06] rechazo esperado -> P0001: El kilometraje de ingreso no puede ser negativo ni nulo
                                esperar_rechazo                                
-------------------------------------------------------------------------------
 OK G02-INT-06: P0001: El kilometraje de ingreso no puede ser negativo ni nulo
(1 row)

-- ===========================================================
-- ID: G02-INT-07   Relación: facultad_orden   Categoría: contexto / temporalidad (D2)
-- ===========================================================
SELECT pruebas.esperar_rechazo('G02-INT-07', 'RN-04', 'designación otorgada por quien no es el titular',
     $q$ INSERT INTO facultad_orden (orden_id, cliente_id, tipo_facultad, fuente, otorgada_por_cliente_id, medio_verificacion, vigente_desde, registrada_por_id)
         VALUES (9002, 108, 'Retirar', 'Designación', 104, 'Nota firmada por Ana', '2026-11-03 12:00', 201) $q$,
     'solo el titular de la orden 9002');
psql:pruebas/90_integridad_modelo.sql:183: NOTICE:  OK    [G02-INT-07] rechazo esperado -> P0001: G02-INT: solo el titular de la orden 9002 (cliente 103) puede designar o hacerse representar
                                                  esperar_rechazo                                                   
--------------------------------------------------------------------------------------------------------------------
 OK G02-INT-07: P0001: G02-INT: solo el titular de la orden 9002 (cliente 103) puede designar o hacerse representar
(1 row)

SELECT pruebas.esperar_rechazo('G02-INT-07', 'RN-04', 'misma facultad vigente duplicada',
     $q$ INSERT INTO facultad_orden (orden_id, cliente_id, tipo_facultad, fuente, medio_verificacion, vigente_desde, registrada_por_id)
         VALUES (9001, 101, 'Aprobar', 'Titular', 'Duplicada', '2026-11-03 12:00', 201) $q$,
     'ex_facultad_sin_traslape');
psql:pruebas/90_integridad_modelo.sql:187: NOTICE:  OK    [G02-INT-07] rechazo esperado -> 23P01: conflicting key value violates exclusion constraint "ex_facultad_sin_traslape"
                                           esperar_rechazo                                            
------------------------------------------------------------------------------------------------------
 OK G02-INT-07: 23P01: conflicting key value violates exclusion constraint "ex_facultad_sin_traslape"
(1 row)

SELECT pruebas.esperar_rechazo('G02-INT-07', 'RN-04', 'titular con otorgante',
     $q$ INSERT INTO facultad_orden (orden_id, cliente_id, tipo_facultad, fuente, otorgada_por_cliente_id, medio_verificacion, vigente_desde, registrada_por_id)
         VALUES (9001, 102, 'Retirar', 'Titular', 101, 'x', '2026-11-03 12:00', 201) $q$,
     'ck_facultad_otorgante');
psql:pruebas/90_integridad_modelo.sql:191: NOTICE:  OK    [G02-INT-07] rechazo esperado -> 23514: new row for relation "facultad_orden" violates check constraint "ck_facultad_otorgante"
                                                esperar_rechazo                                                
---------------------------------------------------------------------------------------------------------------
 OK G02-INT-07: 23514: new row for relation "facultad_orden" violates check constraint "ck_facultad_otorgante"
(1 row)

SELECT pruebas.esperar_rechazo('G02-INT-07', 'RN-04', 'facultad vigente antes de la recepción',
     $q$ INSERT INTO facultad_orden (orden_id, cliente_id, tipo_facultad, fuente, otorgada_por_cliente_id, medio_verificacion, vigente_desde, registrada_por_id)
         VALUES (9001, 102, 'Retirar', 'Designación', 101, 'Nota', '2026-11-01 12:00', 201) $q$,
     'antes de la recepción');
psql:pruebas/90_integridad_modelo.sql:195: NOTICE:  OK    [G02-INT-07] rechazo esperado -> P0001: G02-INT: la facultad no puede regir antes de la recepción de la orden 9001
                                         esperar_rechazo                                          
--------------------------------------------------------------------------------------------------
 OK G02-INT-07: P0001: G02-INT: la facultad no puede regir antes de la recepción de la orden 9001
(1 row)

SELECT pruebas.esperar_rechazo('G02-INT-07', 'RN-04', 'borrar una facultad',
     $q$ DELETE FROM facultad_orden WHERE orden_id = 9001 $q$,
     'no se elimina');
psql:pruebas/90_integridad_modelo.sql:198: NOTICE:  OK    [G02-INT-07] rechazo esperado -> P0001: G02-INM: la facultad 1 no se elimina; revóquela fijando vigente_hasta
                                       esperar_rechazo                                       
---------------------------------------------------------------------------------------------
 OK G02-INT-07: P0001: G02-INM: la facultad 1 no se elimina; revóquela fijando vigente_hasta
(1 row)

-- ===========================================================
-- ID: G02-INT-08   Relación: objeto_dano   Categoría: estado (RN-06)
-- ===========================================================
SELECT pruebas.esperar_rechazo('G02-INT-08', 'RN-06', 'reescribir la descripción de un daño',
     $q$ UPDATE objeto_dano SET descripcion = 'Sin daños' WHERE detalle_id = 1 $q$,
     'solo admite confirmación');
psql:pruebas/90_integridad_modelo.sql:205: NOTICE:  OK    [G02-INT-08] rechazo esperado -> P0001: G02-INM: el detalle 1 solo admite confirmación del cliente
                                 esperar_rechazo                                  
----------------------------------------------------------------------------------
 OK G02-INT-08: P0001: G02-INM: el detalle 1 solo admite confirmación del cliente
(1 row)

SELECT pruebas.esperar_rechazo('G02-INT-08', 'RN-06', 'desconfirmar un objeto',
     $q$ UPDATE objeto_dano SET confirmado_cliente = false WHERE detalle_id = 2 $q$,
     'solo admite confirmación');
psql:pruebas/90_integridad_modelo.sql:208: NOTICE:  OK    [G02-INT-08] rechazo esperado -> P0001: G02-INM: el detalle 2 solo admite confirmación del cliente
                                 esperar_rechazo                                  
----------------------------------------------------------------------------------
 OK G02-INT-08: P0001: G02-INM: el detalle 2 solo admite confirmación del cliente
(1 row)

SELECT pruebas.esperar_rechazo('G02-INT-08', 'RN-06', 'borrar un objeto o daño',
     $q$ DELETE FROM objeto_dano WHERE detalle_id = 3 $q$,
     'no se elimina');
psql:pruebas/90_integridad_modelo.sql:211: NOTICE:  OK    [G02-INT-08] rechazo esperado -> P0001: G02-INM: el detalle 3 de objetos/daños no se elimina
                              esperar_rechazo                               
----------------------------------------------------------------------------
 OK G02-INT-08: P0001: G02-INM: el detalle 3 de objetos/daños no se elimina
(1 row)

-- #####################################################################
-- B. AUTORÍA Y PARTICIPACIÓN
-- #####################################################################
-- ===========================================================
-- ID: G02-INT-09   Relación: hallazgo   Categoría: identidad / contexto (D1, RN-09)
-- ===========================================================
SELECT pruebas.esperar_rechazo('G02-INT-09', 'RN-09', 'hallazgo sin autor',
     $q$ INSERT INTO hallazgo (orden_id, fecha_hora, sintoma_comprobado, urgencia, recomendacion)
         VALUES (9014, '2026-11-08 12:00', 'Ruido', 'Baja', 'Revisar') $q$,
     'diagnosticado_por_id');
psql:pruebas/90_integridad_modelo.sql:223: NOTICE:  OK    [G02-INT-09] rechazo esperado -> 23502: null value in column "diagnosticado_por_id" of relation "hallazgo" violates not-null constraint
                                                    esperar_rechazo                                                    
-----------------------------------------------------------------------------------------------------------------------
 OK G02-INT-09: 23502: null value in column "diagnosticado_por_id" of relation "hallazgo" violates not-null constraint
(1 row)

SELECT pruebas.esperar_rechazo('G02-INT-09', 'RN-09', 'autor que no es técnico',
     $q$ INSERT INTO hallazgo (orden_id, diagnosticado_por_id, fecha_hora, sintoma_comprobado, urgencia, recomendacion)
         VALUES (9014, 201, '2026-11-08 12:00', 'Ruido', 'Baja', 'Revisar') $q$,
     'tiene rol Recepción y se requiere Técnico');
psql:pruebas/90_integridad_modelo.sql:227: NOTICE:  OK    [G02-INT-09] rechazo esperado -> P0001: G02-INT: autor del hallazgo: el personal 201 tiene rol Recepción y se requiere Técnico
                                               esperar_rechazo                                                
--------------------------------------------------------------------------------------------------------------
 OK G02-INT-09: P0001: G02-INT: autor del hallazgo: el personal 201 tiene rol Recepción y se requiere Técnico
(1 row)

SELECT pruebas.esperar_rechazo('G02-INT-09', 'RN-09', 'hallazgo anterior a la recepción',
     $q$ INSERT INTO hallazgo (orden_id, diagnosticado_por_id, fecha_hora, sintoma_comprobado, urgencia, recomendacion)
         VALUES (9014, 202, '2026-11-01 12:00', 'Ruido', 'Baja', 'Revisar') $q$,
     'anterior a la recepción');
psql:pruebas/90_integridad_modelo.sql:231: NOTICE:  OK    [G02-INT-09] rechazo esperado -> P0001: G02-INT: el hallazgo no puede ser anterior a la recepción de la orden 9014
                                         esperar_rechazo                                          
--------------------------------------------------------------------------------------------------
 OK G02-INT-09: P0001: G02-INT: el hallazgo no puede ser anterior a la recepción de la orden 9014
(1 row)

SELECT pruebas.esperar_rechazo('G02-INT-09', 'RN-09', 'cambiar el autor de un hallazgo',
     $q$ UPDATE hallazgo SET diagnosticado_por_id = 203 WHERE hallazgo_id = 4101 $q$,
     'no se modifican');
psql:pruebas/90_integridad_modelo.sql:234: NOTICE:  OK    [G02-INT-09] rechazo esperado -> P0001: G02-INT: la orden, el autor y el momento del hallazgo 4101 no se modifican
                                         esperar_rechazo                                          
--------------------------------------------------------------------------------------------------
 OK G02-INT-09: P0001: G02-INT: la orden, el autor y el momento del hallazgo 4101 no se modifican
(1 row)

SELECT pruebas.esperar_rechazo('G02-INT-09', 'RN-09', 'urgencia fuera de dominio',
     $q$ INSERT INTO hallazgo (orden_id, diagnosticado_por_id, fecha_hora, sintoma_comprobado, urgencia, recomendacion)
         VALUES (9014, 202, '2026-11-08 12:00', 'Ruido', 'Urgentísima', 'Revisar') $q$,
     'ck_hallazgo_urgencia');
psql:pruebas/90_integridad_modelo.sql:238: NOTICE:  OK    [G02-INT-09] rechazo esperado -> 23514: new row for relation "hallazgo" violates check constraint "ck_hallazgo_urgencia"
                                            esperar_rechazo                                             
--------------------------------------------------------------------------------------------------------
 OK G02-INT-09: 23514: new row for relation "hallazgo" violates check constraint "ck_hallazgo_urgencia"
(1 row)

-- ===========================================================
-- ID: G02-INT-10   Relación: especialidad_tecnico   Categoría: temporalidad / contexto (RN-14)
-- ===========================================================
SELECT pruebas.esperar_rechazo('G02-INT-10', 'RN-14', 'especialidad traslapada',
     $q$ INSERT INTO especialidad_tecnico (tecnico_id, especialidad, fecha_inicio) VALUES (202, 'Frenos', '2024-01-01') $q$,
     'ex_especialidad_sin_traslape');
psql:pruebas/90_integridad_modelo.sql:245: NOTICE:  OK    [G02-INT-10] rechazo esperado -> 23P01: conflicting key value violates exclusion constraint "ex_especialidad_sin_traslape"
                                             esperar_rechazo                                              
----------------------------------------------------------------------------------------------------------
 OK G02-INT-10: 23P01: conflicting key value violates exclusion constraint "ex_especialidad_sin_traslape"
(1 row)

SELECT pruebas.esperar_rechazo('G02-INT-10', 'RN-14', 'especialidad a personal que no es técnico',
     $q$ INSERT INTO especialidad_tecnico (tecnico_id, especialidad, fecha_inicio) VALUES (205, 'Electricidad', '2024-01-01') $q$,
     'solo un Técnico tiene especialidades');
psql:pruebas/90_integridad_modelo.sql:248: NOTICE:  OK    [G02-INT-10] rechazo esperado -> P0001: G02-INT: especialidad: el personal 205 tiene rol Otro y solo un Técnico tiene especialidades
                                                  esperar_rechazo                                                   
--------------------------------------------------------------------------------------------------------------------
 OK G02-INT-10: P0001: G02-INT: especialidad: el personal 205 tiene rol Otro y solo un Técnico tiene especialidades
(1 row)

SELECT pruebas.esperar_rechazo('G02-INT-10', 'RN-14', 'fin anterior al inicio',
     $q$ INSERT INTO especialidad_tecnico (tecnico_id, especialidad, fecha_inicio, fecha_fin) VALUES (203, 'Otra', '2024-01-01', '2023-01-01') $q$,
     'ck_especialidad_vigencia');
psql:pruebas/90_integridad_modelo.sql:251: NOTICE:  OK    [G02-INT-10] rechazo esperado -> 23514: new row for relation "especialidad_tecnico" violates check constraint "ck_especialidad_vigencia"
                                                    esperar_rechazo                                                     
------------------------------------------------------------------------------------------------------------------------
 OK G02-INT-10: 23514: new row for relation "especialidad_tecnico" violates check constraint "ck_especialidad_vigencia"
(1 row)

SELECT pruebas.esperar_rechazo('G02-INT-10', 'RN-14', 'quitar el rol Técnico con especialidades vigentes',
     $q$ UPDATE personal SET rol = 'Otro' WHERE personal_id = 203 $q$,
     'tiene especialidades vigentes');
psql:pruebas/90_integridad_modelo.sql:254: NOTICE:  OK    [G02-INT-10] rechazo esperado -> P0001: G02-INT: el personal 203 tiene especialidades vigentes; cierre su vigencia antes de cambiar el rol
                                                     esperar_rechazo                                                      
--------------------------------------------------------------------------------------------------------------------------
 OK G02-INT-10: P0001: G02-INT: el personal 203 tiene especialidades vigentes; cierre su vigencia antes de cambiar el rol
(1 row)

-- Válido: misma especialidad en un periodo NO traslapado (renovación de Frenos de Andrés).
INSERT INTO especialidad_tecnico (tecnico_id, especialidad, fecha_inicio) VALUES (204, 'Frenos', '2026-12-01');
INSERT 0 1
SELECT pruebas.verificar('G02-INT-10', 'RN-14', 'renovación sin traslape aceptada',
     (SELECT count(*) = 2 FROM especialidad_tecnico WHERE tecnico_id = 204 AND especialidad = 'Frenos'),
     '2 periodos de Frenos para Andrés',
     (SELECT string_agg(fecha_inicio || '..' || coalesce(fecha_fin::text, '∞'), ', ' ORDER BY fecha_inicio)
      FROM especialidad_tecnico WHERE tecnico_id = 204 AND especialidad = 'Frenos'));
psql:pruebas/90_integridad_modelo.sql:261: NOTICE:  OK    [G02-INT-10] 2 periodos de Frenos para Andrés -> 2023-01-01..2025-12-31, 2026-12-01..∞
                      verificar                       
------------------------------------------------------
 OK G02-INT-10: 2023-01-01..2025-12-31, 2026-12-01..∞
(1 row)

-- #####################################################################
-- C. REPUESTOS Y MOVIMIENTOS
-- #####################################################################
-- ===========================================================
-- ID: G02-INT-11   Relación: repuesto / proveedor / proveedor_repuesto
-- Categoría: identidad / dominio (RN-17)
-- ===========================================================
SELECT pruebas.esperar_rechazo('G02-INT-11', 'RN-17', 'código interno con formato inválido',
     $q$ INSERT INTO repuesto (repuesto_id, descripcion, unidad_manejo) VALUES ('fr1', 'Mal código', 'Unidad') $q$,
     'ck_repuesto_codigo');
psql:pruebas/90_integridad_modelo.sql:273: NOTICE:  OK    [G02-INT-11] rechazo esperado -> 23514: new row for relation "repuesto" violates check constraint "ck_repuesto_codigo"
                                           esperar_rechazo                                            
------------------------------------------------------------------------------------------------------
 OK G02-INT-11: 23514: new row for relation "repuesto" violates check constraint "ck_repuesto_codigo"
(1 row)

SELECT pruebas.esperar_rechazo('G02-INT-11', 'RN-17', 'unidad de manejo fuera de dominio',
     $q$ INSERT INTO repuesto (repuesto_id, descripcion, unidad_manejo) VALUES ('FR-010', 'Unidad rara', 'Caja') $q$,
     'ck_repuesto_unidad');
psql:pruebas/90_integridad_modelo.sql:276: NOTICE:  OK    [G02-INT-11] rechazo esperado -> 23514: new row for relation "repuesto" violates check constraint "ck_repuesto_unidad"
                                           esperar_rechazo                                            
------------------------------------------------------------------------------------------------------
 OK G02-INT-11: 23514: new row for relation "repuesto" violates check constraint "ck_repuesto_unidad"
(1 row)

SELECT pruebas.esperar_rechazo('G02-INT-11', 'RN-17', 'mismo código de proveedor dos veces en el mismo proveedor',
     $q$ INSERT INTO proveedor_repuesto (proveedor_id, repuesto_id, codigo_proveedor, precio_referencia) VALUES (2, 'FR-003', 'BOS-0986-494', 1000) $q$,
     'uq_prov_rep_codigo');
psql:pruebas/90_integridad_modelo.sql:279: NOTICE:  OK    [G02-INT-11] rechazo esperado -> 23505: duplicate key value violates unique constraint "uq_prov_rep_codigo"
                                      esperar_rechazo                                      
-------------------------------------------------------------------------------------------
 OK G02-INT-11: 23505: duplicate key value violates unique constraint "uq_prov_rep_codigo"
(1 row)

SELECT pruebas.esperar_rechazo('G02-INT-11', 'RN-17', 'precio de referencia negativo',
     $q$ INSERT INTO proveedor_repuesto (proveedor_id, repuesto_id, codigo_proveedor, precio_referencia) VALUES (3, 'FR-003', 'EA-1', -1) $q$,
     'ck_prov_rep_precio');
psql:pruebas/90_integridad_modelo.sql:282: NOTICE:  OK    [G02-INT-11] rechazo esperado -> 23514: new row for relation "proveedor_repuesto" violates check constraint "ck_prov_rep_precio"
                                                esperar_rechazo                                                 
----------------------------------------------------------------------------------------------------------------
 OK G02-INT-11: 23514: new row for relation "proveedor_repuesto" violates check constraint "ck_prov_rep_precio"
(1 row)

SELECT pruebas.esperar_rechazo('G02-INT-11', 'RN-17', 'proveedor duplicado',
     $q$ INSERT INTO proveedor (nombre) VALUES ('Distribuidora Frenos CR') $q$,
     'uq_proveedor_nombre');
psql:pruebas/90_integridad_modelo.sql:285: NOTICE:  OK    [G02-INT-11] rechazo esperado -> 23505: duplicate key value violates unique constraint "uq_proveedor_nombre"
                                      esperar_rechazo                                       
--------------------------------------------------------------------------------------------
 OK G02-INT-11: 23505: duplicate key value violates unique constraint "uq_proveedor_nombre"
(1 row)

-- Válido: el MISMO código de proveedor en OTRO proveedor (contexto distinto).
INSERT INTO proveedor_repuesto (proveedor_id, repuesto_id, codigo_proveedor, precio_referencia) VALUES (1, 'FR-003', 'BOS-0986-494', 39000);
INSERT 0 1
SELECT pruebas.verificar('G02-INT-11', 'RN-17', 'mismo código de proveedor en proveedores distintos',
     (SELECT count(DISTINCT proveedor_id) = 2 FROM proveedor_repuesto WHERE codigo_proveedor = 'BOS-0986-494'),
     '2 proveedores con el código BOS-0986-494',
     (SELECT string_agg(proveedor_id || ':' || repuesto_id, ', ') FROM proveedor_repuesto WHERE codigo_proveedor = 'BOS-0986-494'));
psql:pruebas/90_integridad_modelo.sql:291: NOTICE:  OK    [G02-INT-11] 2 proveedores con el código BOS-0986-494 -> 2:FR-001, 1:FR-003
             verificar             
-----------------------------------
 OK G02-INT-11: 2:FR-001, 1:FR-003
(1 row)

-- ===========================================================
-- ID: G02-INT-12   Relación: movimiento_inventario   Categoría: dominio / estado (RN-19, D11)
-- Preparación: FR-003 (disco) tiene 1 unidad física y 0 reservadas.
-- ===========================================================
SELECT pruebas.esperar_rechazo('G02-INT-12', 'RN-19', 'ajuste negativo mayor que la existencia física',
     $q$ INSERT INTO movimiento_inventario (repuesto_id, tipo_movimiento, cantidad, registrado_por_id, motivo)
         VALUES ('FR-003', 'Ajuste negativo', 5, 205, 'Conteo físico') $q$,
     'existencias insuficientes de FR-003');
psql:pruebas/90_integridad_modelo.sql:300: NOTICE:  OK    [G02-INT-12] rechazo esperado -> P0001: G02-INT: existencias insuficientes de FR-003: el movimiento dejaría -4.00 físicas
                                             esperar_rechazo                                             
---------------------------------------------------------------------------------------------------------
 OK G02-INT-12: P0001: G02-INT: existencias insuficientes de FR-003: el movimiento dejaría -4.00 físicas
(1 row)

SELECT pruebas.esperar_rechazo('G02-INT-12', 'RN-19', 'reserva mayor que lo disponible',
     $q$ INSERT INTO movimiento_inventario (repuesto_id, orden_id, tipo_movimiento, cantidad, registrado_por_id)
         VALUES ('FR-003', 9014, 'Reserva', 2, 205) $q$,
     'disponibles');
psql:pruebas/90_integridad_modelo.sql:304: NOTICE:  OK    [G02-INT-12] rechazo esperado -> P0001: G02-INT: existencias insuficientes de FR-003: el movimiento dejaría -1.00 disponibles (físico 1.00, reservado 2.00)
                                                              esperar_rechazo                                                              
-------------------------------------------------------------------------------------------------------------------------------------------
 OK G02-INT-12: P0001: G02-INT: existencias insuficientes de FR-003: el movimiento dejaría -1.00 disponibles (físico 1.00, reservado 2.00)
(1 row)

SELECT pruebas.esperar_rechazo('G02-INT-12', 'RN-19', 'liberar más de lo reservado por la orden',
     $q$ INSERT INTO movimiento_inventario (repuesto_id, orden_id, tipo_movimiento, cantidad, registrado_por_id)
         VALUES ('FR-003', 9014, 'Liberación', 1, 205) $q$,
     'no se puede liberar');
psql:pruebas/90_integridad_modelo.sql:308: NOTICE:  OK    [G02-INT-12] rechazo esperado -> P0001: G02-INT: no se puede liberar 1.00 de FR-003; la orden 9014 solo tiene 0 reservado
                                             esperar_rechazo                                             
---------------------------------------------------------------------------------------------------------
 OK G02-INT-12: P0001: G02-INT: no se puede liberar 1.00 de FR-003; la orden 9014 solo tiene 0 reservado
(1 row)

SELECT pruebas.esperar_rechazo('G02-INT-12', 'RN-19', 'reserva sin orden',
     $q$ INSERT INTO movimiento_inventario (repuesto_id, tipo_movimiento, cantidad, registrado_por_id) VALUES ('FR-001', 'Reserva', 1, 205) $q$,
     'ck_movimiento_orden');
psql:pruebas/90_integridad_modelo.sql:311: NOTICE:  OK    [G02-INT-12] rechazo esperado -> 23514: new row for relation "movimiento_inventario" violates check constraint "ck_movimiento_orden"
                                                  esperar_rechazo                                                   
--------------------------------------------------------------------------------------------------------------------
 OK G02-INT-12: 23514: new row for relation "movimiento_inventario" violates check constraint "ck_movimiento_orden"
(1 row)

SELECT pruebas.esperar_rechazo('G02-INT-12', 'RN-19', 'ajuste sin motivo',
     $q$ INSERT INTO movimiento_inventario (repuesto_id, tipo_movimiento, cantidad, registrado_por_id) VALUES ('FR-001', 'Ajuste positivo', 1, 205) $q$,
     'ck_movimiento_ajuste_motivo');
psql:pruebas/90_integridad_modelo.sql:314: NOTICE:  OK    [G02-INT-12] rechazo esperado -> 23514: new row for relation "movimiento_inventario" violates check constraint "ck_movimiento_ajuste_motivo"
                                                      esperar_rechazo                                                       
----------------------------------------------------------------------------------------------------------------------------
 OK G02-INT-12: 23514: new row for relation "movimiento_inventario" violates check constraint "ck_movimiento_ajuste_motivo"
(1 row)

SELECT pruebas.esperar_rechazo('G02-INT-12', 'RN-19', 'cantidad cero',
     $q$ INSERT INTO movimiento_inventario (repuesto_id, tipo_movimiento, cantidad, registrado_por_id) VALUES ('FR-001', 'Entrada', 0, 205) $q$,
     'ck_movimiento_cantidad');
psql:pruebas/90_integridad_modelo.sql:317: NOTICE:  OK    [G02-INT-12] rechazo esperado -> 23514: new row for relation "movimiento_inventario" violates check constraint "ck_movimiento_cantidad"
                                                    esperar_rechazo                                                    
-----------------------------------------------------------------------------------------------------------------------
 OK G02-INT-12: 23514: new row for relation "movimiento_inventario" violates check constraint "ck_movimiento_cantidad"
(1 row)

SELECT pruebas.esperar_rechazo('G02-INT-12', 'RN-19', 'modificar un movimiento',
     $q$ UPDATE movimiento_inventario SET cantidad = 100 WHERE repuesto_id = 'FR-001' AND tipo_movimiento = 'Entrada' $q$,
     'solo inserción');
psql:pruebas/90_integridad_modelo.sql:320: NOTICE:  OK    [G02-INT-12] rechazo esperado -> P0001: G02-INM: movimiento_inventario es de solo inserción; no se permite UPDATE (registre una fila nueva)
                                                      esperar_rechazo                                                      
---------------------------------------------------------------------------------------------------------------------------
 OK G02-INT-12: P0001: G02-INM: movimiento_inventario es de solo inserción; no se permite UPDATE (registre una fila nueva)
(1 row)

-- Válido: ajuste positivo con motivo.
INSERT INTO movimiento_inventario (repuesto_id, tipo_movimiento, cantidad, fecha_hora, registrado_por_id, motivo)
VALUES ('MG-002', 'Ajuste positivo', 1, '2026-11-06 18:00', 205, 'Conteo físico encontró un litro adicional');
INSERT 0 1
SELECT * FROM v_existencias ORDER BY repuesto_id;
 repuesto_id |          descripcion          | unidad_manejo | fisico | reservado | disponible 
-------------+-------------------------------+---------------+--------+-----------+------------
 EL-001      | Sensor de oxígeno             | Unidad        |   2.00 |         0 |       2.00
 EL-002      | Batería 12 V auxiliar         | Unidad        |      0 |         0 |          0
 FR-001      | Pastillas de freno delanteras | Juego         |   9.00 |      0.00 |       9.00
 FR-002      | Líquido de frenos DOT 4       | Litro         |   6.00 |         0 |       6.00
 FR-003      | Disco de freno delantero      | Unidad        |   1.00 |         0 |       1.00
 LP-001      | Escobillas limpiaparabrisas   | Juego         |   5.00 |         0 |       5.00
 MG-001      | Filtro de aire                | Unidad        |   6.00 |         0 |       6.00
 MG-002      | Aceite de motor 5W-30         | Litro         |  21.00 |         0 |      21.00
(8 rows)

SELECT pruebas.verificar('G02-INT-12', 'RN-19', 'ninguna existencia física ni disponible es negativa',
     NOT EXISTS (SELECT 1 FROM v_existencias WHERE fisico < 0 OR disponible < 0),
     'todas las existencias >= 0',
     (SELECT string_agg(repuesto_id || '=' || fisico || '/' || disponible, ', ' ORDER BY repuesto_id) FROM v_existencias));
psql:pruebas/90_integridad_modelo.sql:328: NOTICE:  OK    [G02-INT-12] todas las existencias >= 0 -> EL-001=2.00/2.00, EL-002=0/0, FR-001=9.00/9.00, FR-002=6.00/6.00, FR-003=1.00/1.00, LP-001=5.00/5.00, MG-001=6.00/6.00, MG-002=21.00/21.00
                                                                         verificar                                                                         
-----------------------------------------------------------------------------------------------------------------------------------------------------------
 OK G02-INT-12: EL-001=2.00/2.00, EL-002=0/0, FR-001=9.00/9.00, FR-002=6.00/6.00, FR-003=1.00/1.00, LP-001=5.00/5.00, MG-001=6.00/6.00, MG-002=21.00/21.00
(1 row)

-- ===========================================================
-- ID: G02-INT-13   Relación: pieza_retirada   Categoría: contexto / estado
-- ===========================================================
SELECT pruebas.esperar_rechazo('G02-INT-13', 'RN-18', 'pieza retirada de una labor de OTRA orden',
     $q$ INSERT INTO pieza_retirada (labor_id, orden_id, descripcion, destino, registrado_por_id)
         VALUES (pruebas.labor_id(9003, 'Cambio de pastillas'), 9001, 'Pastillas usadas', 'Entregada cliente', 202) $q$,
     'fk_pieza_labor');
psql:pruebas/90_integridad_modelo.sql:336: NOTICE:  OK    [G02-INT-13] rechazo esperado -> 23503: insert or update on table "pieza_retirada" violates foreign key constraint "fk_pieza_labor"
                                                  esperar_rechazo                                                  
-------------------------------------------------------------------------------------------------------------------
 OK G02-INT-13: 23503: insert or update on table "pieza_retirada" violates foreign key constraint "fk_pieza_labor"
(1 row)

SELECT pruebas.esperar_rechazo('G02-INT-13', 'RN-18', 'pieza de una labor que no se ejecutó',
     $q$ INSERT INTO pieza_retirada (labor_id, orden_id, descripcion, destino, registrado_por_id)
         VALUES (pruebas.labor_id(9003, 'Limpieza de inyectores'), 9003, 'Inyector', 'Desechada autorizada', 202) $q$,
     'no tiene piezas retiradas');
psql:pruebas/90_integridad_modelo.sql:340: NOTICE:  OK    [G02-INT-13] rechazo esperado -> P0001: G02-INT: la labor 519 está Pendiente; no tiene piezas retiradas
                                    esperar_rechazo                                    
---------------------------------------------------------------------------------------
 OK G02-INT-13: P0001: G02-INT: la labor 519 está Pendiente; no tiene piezas retiradas
(1 row)

SELECT pruebas.esperar_rechazo('G02-INT-13', 'RN-18', 'destino fuera de dominio',
     $q$ INSERT INTO pieza_retirada (labor_id, orden_id, descripcion, destino, registrado_por_id)
         VALUES (pruebas.labor_id(9003, 'Cambio de pastillas'), 9003, 'Pastillas usadas', 'Vendida', 202) $q$,
     'ck_pieza_destino');
psql:pruebas/90_integridad_modelo.sql:344: NOTICE:  OK    [G02-INT-13] rechazo esperado -> 23514: new row for relation "pieza_retirada" violates check constraint "ck_pieza_destino"
                                             esperar_rechazo                                              
----------------------------------------------------------------------------------------------------------
 OK G02-INT-13: 23514: new row for relation "pieza_retirada" violates check constraint "ck_pieza_destino"
(1 row)

INSERT INTO pieza_retirada (labor_id, orden_id, descripcion, destino, fecha_hora, registrado_por_id)
VALUES (pruebas.labor_id(9003, 'Cambio de pastillas'), 9003, 'Juego de pastillas delanteras usadas', 'Entregada cliente', '2026-11-05 09:35', 202),
       (pruebas.labor_id(9003, 'Sustitución del sensor'), 9003, 'Sensor de oxígeno defectuoso', 'Desechada autorizada', '2026-11-05 17:40', 203);
INSERT 0 2
-- ===========================================================
-- ID: G02-INT-14   Distinguir presupuesto / reserva / consumo / pieza retirada (RN-18)
-- ===========================================================
SELECT concepto, labor_id, referencia, cantidad, precio_unitario FROM v_insumos_orden WHERE orden_id = 9003 ORDER BY concepto, labor_id;
               concepto                | labor_id |              referencia              | cantidad | precio_unitario 
---------------------------------------+----------+--------------------------------------+----------+-----------------
 Consumo                               |      515 | FR-001                               |     1.00 |        25000.00
 Consumo                               |      516 | EL-001                               |     1.00 |        41000.00
 Consumo                               |      517 | FR-002                               |     1.00 |         6500.00
 Liberación de reserva                 |          | FR-001                               |     1.00 |                
 Pieza retirada (Desechada autorizada) |      516 | Sensor de oxígeno defectuoso         |        1 |                
 Pieza retirada (Entregada cliente)    |      515 | Juego de pastillas delanteras usadas |        1 |                
 Presupuesto (v1)                      |      515 | FR-001                               |     1.00 |        25000.00
 Presupuesto (v1)                      |      516 | EL-001                               |     1.00 |        41000.00
 Presupuesto (v1)                      |      517 | FR-002                               |     1.00 |         6500.00
 Reserva                               |          | FR-001                               |     1.00 |                
(10 rows)

SELECT pruebas.verificar('G02-INT-14', 'RN-18', 'una consulta distingue los cuatro conceptos',
     (SELECT count(DISTINCT split_part(concepto, ' ', 1)) >= 4 FROM v_insumos_orden WHERE orden_id = 9003),
     'Presupuesto, Reserva, Liberación, Consumo y Pieza en la orden 9003',
     (SELECT string_agg(DISTINCT split_part(concepto, ' (', 1), ', ') FROM v_insumos_orden WHERE orden_id = 9003));
psql:pruebas/90_integridad_modelo.sql:356: NOTICE:  OK    [G02-INT-14] Presupuesto, Reserva, Liberación, Consumo y Pieza en la orden 9003 -> Consumo, Liberación de reserva, Pieza retirada, Presupuesto, Reserva
                                      verificar                                      
-------------------------------------------------------------------------------------
 OK G02-INT-14: Consumo, Liberación de reserva, Pieza retirada, Presupuesto, Reserva
(1 row)

-- ===========================================================
-- ID: G02-INT-15   Relación: labor_dependencia   Categoría: contexto (RN-15, D7)
-- ===========================================================
SELECT pruebas.esperar_rechazo('G02-INT-15', 'RN-15', 'dependencia circular',
     $q$ INSERT INTO labor_dependencia (labor_id, requiere_labor_id, orden_id)
         VALUES (pruebas.labor_id(9003, 'Cambio de pastillas'), pruebas.labor_id(9003, 'Purga'), 9003) $q$,
     'formaría un ciclo');
psql:pruebas/90_integridad_modelo.sql:364: NOTICE:  OK    [G02-INT-15] rechazo esperado -> P0001: G02-P02: la dependencia 515 -> 517 formaría un ciclo
                              esperar_rechazo                               
----------------------------------------------------------------------------
 OK G02-INT-15: P0001: G02-P02: la dependencia 515 -> 517 formaría un ciclo
(1 row)

SELECT pruebas.esperar_rechazo('G02-INT-15', 'RN-15', 'dependencia con una labor de otra orden',
     $q$ INSERT INTO labor_dependencia (labor_id, requiere_labor_id, orden_id)
         VALUES (pruebas.labor_id(9001, 'Rotación'), pruebas.labor_id(9003, 'Purga'), 9001) $q$,
     'fk_dependencia_requerida');
psql:pruebas/90_integridad_modelo.sql:368: NOTICE:  OK    [G02-INT-15] rechazo esperado -> 23503: insert or update on table "labor_dependencia" violates foreign key constraint "fk_dependencia_requerida"
                                                        esperar_rechazo                                                         
--------------------------------------------------------------------------------------------------------------------------------
 OK G02-INT-15: 23503: insert or update on table "labor_dependencia" violates foreign key constraint "fk_dependencia_requerida"
(1 row)

SELECT pruebas.esperar_rechazo('G02-INT-15', 'RN-15', 'labor que depende de sí misma',
     $q$ INSERT INTO labor_dependencia (labor_id, requiere_labor_id, orden_id)
         VALUES (pruebas.labor_id(9001, 'Rotación'), pruebas.labor_id(9001, 'Rotación'), 9001) $q$,
     'ck_dependencia_distinta');
psql:pruebas/90_integridad_modelo.sql:372: NOTICE:  OK    [G02-INT-15] rechazo esperado -> 23514: new row for relation "labor_dependencia" violates check constraint "ck_dependencia_distinta"
                                                  esperar_rechazo                                                   
--------------------------------------------------------------------------------------------------------------------
 OK G02-INT-15: 23514: new row for relation "labor_dependencia" violates check constraint "ck_dependencia_distinta"
(1 row)

-- Válido: una labor puede depender de VARIAS (N:M). La rotación de 9001
-- requiere la alineación y el cambio de pastillas.
INSERT INTO labor_dependencia (labor_id, requiere_labor_id, orden_id)
VALUES (pruebas.labor_id(9001, 'Rotación'), pruebas.labor_id(9001, 'Alineación'), 9001),
       (pruebas.labor_id(9001, 'Rotación'), pruebas.labor_id(9001, 'Cambio de pastillas'), 9001);
INSERT 0 2
SELECT pruebas.verificar('G02-INT-15', 'RN-15', 'una labor con dos dependencias',
     (SELECT count(*) = 2 FROM labor_dependencia WHERE labor_id = pruebas.labor_id(9001, 'Rotación')),
     '2 dependencias', (SELECT count(*) || ' dependencias' FROM labor_dependencia WHERE labor_id = pruebas.labor_id(9001, 'Rotación')));
psql:pruebas/90_integridad_modelo.sql:380: NOTICE:  OK    [G02-INT-15] 2 dependencias -> 2 dependencias
           verificar           
-------------------------------
 OK G02-INT-15: 2 dependencias
(1 row)

-- #####################################################################
-- D. ENTREGA Y GARANTÍA (solo integridad; la preparación usa P01/P02/P03)
-- Orden 9007: Laura Jiménez, Tesla STU901, km de ingreso 30000.
-- #####################################################################
SELECT fn_cambiar_estado_orden(9007, 'En diagnóstico', 204, NULL, '2026-11-07 08:45');
 fn_cambiar_estado_orden 
-------------------------
                      49
(1 row)

SELECT fn_publicar_propuesta(9007, NULL,
  '[{"descripcion":"Cambio de filtro de cabina","hallazgo_id":4111,"precio_estimado":9000,
     "repuestos":[{"repuesto_id":"MG-001","cantidad":1,"precio_unitario":9000}]},
    {"descripcion":"Revisión general de 30 puntos","precio_estimado":15000},
    {"descripcion":"Lavado de motor","precio_estimado":10000}]'::jsonb,
  205, NULL, '2026-11-07 09:30');
 fn_publicar_propuesta 
-----------------------
                   322
(1 row)

SELECT fn_cambiar_estado_orden(9007, 'Pendiente autorización', 201, NULL, '2026-11-07 09:35');
 fn_cambiar_estado_orden 
-------------------------
                      50
(1 row)

SELECT fn_registrar_decision(pruebas.propuesta_id(9007, 1), l.labor_id, 107,
       CASE WHEN l.descripcion LIKE 'Lavado%' THEN 'Rechazada' ELSE 'Aceptada' END, 'Mensaje', 201, '2026-11-07 10:00')
FROM labor l WHERE l.orden_id = 9007 ORDER BY l.labor_id;
 fn_registrar_decision 
-----------------------
                   630
                   631
                   632
(3 rows)

SELECT fn_cambiar_estado_orden(9007, 'Autorizada', 201, NULL, '2026-11-07 10:05');
 fn_cambiar_estado_orden 
-------------------------
                      51
(1 row)

SELECT fn_cambiar_estado_orden(9007, 'En reparación', 204, NULL, '2026-11-07 10:30');
 fn_cambiar_estado_orden 
-------------------------
                      52
(1 row)

SELECT fn_iniciar_labor(pruebas.labor_id(9007, 'Cambio de filtro'), 204, '2026-11-07 10:30');
 fn_iniciar_labor 
------------------
               56
(1 row)

SELECT fn_registrar_participacion(pruebas.labor_id(9007, 'Cambio de filtro'), 204, '2026-11-07 10:30', '2026-11-07 11:00', 25, 'Cambio de filtro', 4);
 fn_registrar_participacion 
----------------------------
                         23
(1 row)

SELECT fn_registrar_consumo(9007, pruebas.labor_id(9007, 'Cambio de filtro'), 'MG-001', 1, 9000, 204, '2026-11-07 10:40');
 fn_registrar_consumo 
----------------------
                   12
(1 row)

SELECT fn_registrar_prueba(pruebas.labor_id(9007, 'Cambio de filtro'), 204, '2026-11-07 11:05', 'Flujo de aire', 'Favorable', 'Flujo normal');
 fn_registrar_prueba 
---------------------
                  12
(1 row)

SELECT fn_completar_labor(pruebas.labor_id(9007, 'Cambio de filtro'), 204, '2026-11-07 11:10');
 fn_completar_labor 
--------------------
                 57
(1 row)

SELECT fn_iniciar_labor(pruebas.labor_id(9007, 'Revisión general'), 202, '2026-11-07 11:15');
 fn_iniciar_labor 
------------------
               58
(1 row)

SELECT fn_registrar_participacion(pruebas.labor_id(9007, 'Revisión general'), 202, '2026-11-07 11:15', '2026-11-07 12:15', 60, 'Revisión de 30 puntos', 2);
 fn_registrar_participacion 
----------------------------
                         24
(1 row)

SELECT fn_registrar_prueba(pruebas.labor_id(9007, 'Revisión general'), 202, '2026-11-07 12:20', 'Lista de verificación', 'Favorable', 'Sin observaciones críticas');
 fn_registrar_prueba 
---------------------
                  13
(1 row)

SELECT fn_completar_labor(pruebas.labor_id(9007, 'Revisión general'), 202, '2026-11-07 12:25');
 fn_completar_labor 
--------------------
                 59
(1 row)

SELECT fn_cambiar_estado_orden(9007, 'Lista entrega', 204, NULL, '2026-11-07 12:30');
 fn_cambiar_estado_orden 
-------------------------
                      53
(1 row)

-- ===========================================================
-- ID: G02-INT-16   Relación: entrega   Categoría: contexto / temporalidad / estado (RN-20, D2)
-- ===========================================================
SELECT pruebas.esperar_rechazo('G02-INT-16', 'RN-20', 'entregar una orden que no está Lista entrega',
     $q$ INSERT INTO entrega (orden_id, retira_cliente_id, entregado_por_id, fecha_hora, kilometraje_salida, revision_final, conformidad)
         VALUES (9014, 106, 201, '2026-11-09 10:00', 54010, 'Revisión', 'Conforme') $q$,
     'no está Lista entrega');
psql:pruebas/90_integridad_modelo.sql:416: NOTICE:  OK    [G02-INT-16] rechazo esperado -> P0001: G02-INT: la orden 9014 no está Lista entrega (estado: En diagnóstico)
                                       esperar_rechazo                                       
---------------------------------------------------------------------------------------------
 OK G02-INT-16: P0001: G02-INT: la orden 9014 no está Lista entrega (estado: En diagnóstico)
(1 row)

SELECT pruebas.esperar_rechazo('G02-INT-16', 'RN-20', 'retira una persona sin facultad Retirar',
     $q$ INSERT INTO entrega (orden_id, retira_cliente_id, entregado_por_id, fecha_hora, kilometraje_salida, revision_final, conformidad)
         VALUES (9007, 108, 201, '2026-11-07 17:30', 30015, 'Revisión final', 'Conforme') $q$,
     'el cliente 108 no tiene facultad vigente para retirar');
psql:pruebas/90_integridad_modelo.sql:420: NOTICE:  OK    [G02-INT-16] rechazo esperado -> P0001: G02-INT: el cliente 108 no tiene facultad vigente para retirar el vehículo de la orden 9007
                                                  esperar_rechazo                                                  
-------------------------------------------------------------------------------------------------------------------
 OK G02-INT-16: P0001: G02-INT: el cliente 108 no tiene facultad vigente para retirar el vehículo de la orden 9007
(1 row)

SELECT pruebas.esperar_rechazo('G02-INT-16', 'RN-20', 'retira con la facultad Aprobar (no Retirar)',
     $q$ INSERT INTO entrega (orden_id, retira_cliente_id, facultad_id, entregado_por_id, fecha_hora, kilometraje_salida, revision_final, conformidad)
         SELECT 9007, 107, facultad_id, 201, '2026-11-07 17:30', 30015, 'Revisión final', 'Conforme'
         FROM facultad_orden WHERE orden_id = 9007 AND tipo_facultad = 'Aprobar' $q$,
     'no tiene facultad vigente para retirar');
psql:pruebas/90_integridad_modelo.sql:425: NOTICE:  OK    [G02-INT-16] rechazo esperado -> P0001: G02-INT: el cliente 107 no tiene facultad vigente para retirar el vehículo de la orden 9007
                                                  esperar_rechazo                                                  
-------------------------------------------------------------------------------------------------------------------
 OK G02-INT-16: P0001: G02-INT: el cliente 107 no tiene facultad vigente para retirar el vehículo de la orden 9007
(1 row)

SELECT pruebas.esperar_rechazo('G02-INT-16', 'RN-20', 'kilometraje de salida menor que el de ingreso',
     $q$ INSERT INTO entrega (orden_id, retira_cliente_id, entregado_por_id, fecha_hora, kilometraje_salida, revision_final, conformidad)
         VALUES (9007, 107, 201, '2026-11-07 17:30', 29990, 'Revisión final', 'Conforme') $q$,
     'menor que el de ingreso');
psql:pruebas/90_integridad_modelo.sql:429: NOTICE:  OK    [G02-INT-16] rechazo esperado -> P0001: G02-INT: el kilometraje de salida (29990) es menor que el de ingreso (30000)
                                          esperar_rechazo                                           
----------------------------------------------------------------------------------------------------
 OK G02-INT-16: P0001: G02-INT: el kilometraje de salida (29990) es menor que el de ingreso (30000)
(1 row)

SELECT pruebas.esperar_rechazo('G02-INT-16', 'RN-20', 'entrega anterior a la recepción',
     $q$ INSERT INTO entrega (orden_id, retira_cliente_id, entregado_por_id, fecha_hora, kilometraje_salida, revision_final, conformidad)
         VALUES (9007, 107, 201, '2026-11-06 17:30', 30015, 'Revisión final', 'Conforme') $q$,
     'no tiene facultad vigente para retirar');
psql:pruebas/90_integridad_modelo.sql:433: NOTICE:  OK    [G02-INT-16] rechazo esperado -> P0001: G02-INT: el cliente 107 no tiene facultad vigente para retirar el vehículo de la orden 9007
                                                  esperar_rechazo                                                  
-------------------------------------------------------------------------------------------------------------------
 OK G02-INT-16: P0001: G02-INT: el cliente 107 no tiene facultad vigente para retirar el vehículo de la orden 9007
(1 row)

SELECT pruebas.esperar_rechazo('G02-INT-16', 'RN-20', 'inconforme sin observaciones',
     $q$ INSERT INTO entrega (orden_id, retira_cliente_id, entregado_por_id, fecha_hora, kilometraje_salida, revision_final, conformidad)
         VALUES (9007, 107, 201, '2026-11-07 17:30', 30015, 'Revisión final', 'Inconforme') $q$,
     'ck_entrega_inconformidad');
psql:pruebas/90_integridad_modelo.sql:437: NOTICE:  OK    [G02-INT-16] rechazo esperado -> 23514: new row for relation "entrega" violates check constraint "ck_entrega_inconformidad"
                                              esperar_rechazo                                              
-----------------------------------------------------------------------------------------------------------
 OK G02-INT-16: 23514: new row for relation "entrega" violates check constraint "ck_entrega_inconformidad"
(1 row)

-- Válido: Laura (titular, facultad Retirar) retira el vehículo.
INSERT INTO entrega (orden_id, retira_cliente_id, entregado_por_id, fecha_hora, kilometraje_salida, revision_final,
                     recomendaciones_futuras, conformidad)
VALUES (9007, 107, 201, '2026-11-07 17:30', 30015, 'Filtro nuevo y revisión de 30 puntos sin hallazgos críticos',
        'Revisar llantas en 5 000 km', 'Conforme');
INSERT 0 1
SELECT pruebas.esperar_rechazo('G02-INT-16', 'RN-20', 'segunda entrega de la misma orden',
     $q$ INSERT INTO entrega (orden_id, retira_cliente_id, entregado_por_id, fecha_hora, kilometraje_salida, revision_final, conformidad)
         VALUES (9007, 107, 201, '2026-11-07 18:00', 30015, 'Otra', 'Conforme') $q$,
     'uq_entrega_orden');
psql:pruebas/90_integridad_modelo.sql:446: NOTICE:  OK    [G02-INT-16] rechazo esperado -> 23505: duplicate key value violates unique constraint "uq_entrega_orden"
                                     esperar_rechazo                                     
-----------------------------------------------------------------------------------------
 OK G02-INT-16: 23505: duplicate key value violates unique constraint "uq_entrega_orden"
(1 row)

SELECT fn_cambiar_estado_orden(9007, 'Entregada', 201, NULL, '2026-11-07 17:35');
 fn_cambiar_estado_orden 
-------------------------
                      54
(1 row)

SELECT e.entrega_id, e.orden_id, c.nombre_razon_social AS retira, f.tipo_facultad, f.fuente, e.kilometraje_salida, e.conformidad
FROM entrega e JOIN cliente c ON c.cliente_id = e.retira_cliente_id JOIN facultad_orden f ON f.facultad_id = e.facultad_id;
 entrega_id | orden_id |    retira     | tipo_facultad | fuente  | kilometraje_salida | conformidad 
------------+----------+---------------+---------------+---------+--------------------+-------------
          7 |     9007 | Laura Jiménez | Retirar       | Titular |              30015 | Conforme
(1 row)

SELECT pruebas.verificar('G02-INT-16', 'RN-20', 'entrega válida con facultad Retirar y orden Entregada',
     (SELECT f.tipo_facultad = 'Retirar' AND o.estado_actual = 'Entregada'
      FROM entrega e JOIN facultad_orden f USING (facultad_id) JOIN orden_trabajo o ON o.orden_id = e.orden_id WHERE e.orden_id = 9007),
     'facultad Retirar; orden Entregada',
     (SELECT 'facultad ' || f.tipo_facultad || '; orden ' || o.estado_actual
      FROM entrega e JOIN facultad_orden f USING (facultad_id) JOIN orden_trabajo o ON o.orden_id = e.orden_id WHERE e.orden_id = 9007));
psql:pruebas/90_integridad_modelo.sql:455: NOTICE:  OK    [G02-INT-16] facultad Retirar; orden Entregada -> facultad Retirar; orden Entregada
                    verificar                     
--------------------------------------------------
 OK G02-INT-16: facultad Retirar; orden Entregada
(1 row)

-- ===========================================================
-- ID: G02-INT-17   Relación: garantia   Categoría: contexto / estado (D3)
-- ===========================================================
INSERT INTO garantia (entrega_id, orden_id, labor_id, dias, km, condiciones)
SELECT e.entrega_id, 9007, pruebas.labor_id(9007, 'Cambio de filtro'), 30, 1000, 'Defectos del filtro instalado'
FROM entrega e WHERE e.orden_id = 9007;
INSERT 0 1
INSERT INTO garantia (entrega_id, orden_id, labor_id, dias, km, condiciones)
SELECT e.entrega_id, 9007, pruebas.labor_id(9007, 'Revisión general'), 5, 5000, 'Diagnóstico de la revisión'
FROM entrega e WHERE e.orden_id = 9007;
INSERT 0 1
SELECT pruebas.esperar_rechazo('G02-INT-17', 'RN-22', 'garantía sobre una labor no completada',
     $q$ INSERT INTO garantia (entrega_id, orden_id, labor_id, dias)
         SELECT e.entrega_id, 9007, pruebas.labor_id(9007, 'Lavado'), 30 FROM entrega e WHERE e.orden_id = 9007 $q$,
     'solo se otorga garantía sobre labores Completadas');
psql:pruebas/90_integridad_modelo.sql:469: NOTICE:  OK    [G02-INT-17] rechazo esperado -> P0001: G02-INT: solo se otorga garantía sobre labores Completadas (la labor 529 está Pendiente)
                                                esperar_rechazo                                                 
----------------------------------------------------------------------------------------------------------------
 OK G02-INT-17: P0001: G02-INT: solo se otorga garantía sobre labores Completadas (la labor 529 está Pendiente)
(1 row)

SELECT pruebas.esperar_rechazo('G02-INT-17', 'RN-22', 'garantía sobre una labor de otra orden',
     $q$ INSERT INTO garantia (entrega_id, orden_id, labor_id, dias)
         SELECT e.entrega_id, 9007, pruebas.labor_id(9003, 'Cambio de pastillas'), 30 FROM entrega e WHERE e.orden_id = 9007 $q$,
     'fk_garantia_labor');
psql:pruebas/90_integridad_modelo.sql:473: NOTICE:  OK    [G02-INT-17] rechazo esperado -> 23503: insert or update on table "garantia" violates foreign key constraint "fk_garantia_labor"
                                                esperar_rechazo                                                 
----------------------------------------------------------------------------------------------------------------
 OK G02-INT-17: 23503: insert or update on table "garantia" violates foreign key constraint "fk_garantia_labor"
(1 row)

SELECT pruebas.esperar_rechazo('G02-INT-17', 'RN-22', 'garantía sin ningún límite',
     $q$ INSERT INTO garantia (entrega_id, orden_id, labor_id)
         SELECT e.entrega_id, 9007, pruebas.labor_id(9007, 'Revisión general') FROM entrega e WHERE e.orden_id = 9007 $q$,
     'ck_garantia_limite');
psql:pruebas/90_integridad_modelo.sql:477: NOTICE:  OK    [G02-INT-17] rechazo esperado -> 23514: new row for relation "garantia" violates check constraint "ck_garantia_limite"
                                           esperar_rechazo                                            
------------------------------------------------------------------------------------------------------
 OK G02-INT-17: 23514: new row for relation "garantia" violates check constraint "ck_garantia_limite"
(1 row)

-- ===========================================================
-- ID: G02-INT-18   Relación: reclamo_garantia   Categoría: contexto / temporalidad (RN-21, RN-22)
-- Garantías de 9007 (entregada 2026-11-07 17:30 con 30 015 km):
--   G1 filtro: 30 días o 1 000 km   G2 revisión: 5 días o 5 000 km
-- Órdenes nuevas (alta de preparación):
--   9010 Tesla 2026-11-15 con 31 600 km  (+1 585 km: fuera de km de G1)
--   9008 Tesla 2026-11-18 con 30 215 km  (+200 km, día 11: fuera de días de G2, dentro de G1)
--   9009 Golf (OTRO VIN) 2026-11-18
-- ===========================================================
BEGIN;
BEGIN
INSERT INTO orden_trabajo (orden_id, vin, cliente_factura_id, entregado_por_cliente_id, autorizador_cliente_id, receptor_id,
                           fecha_hora_recepcion, kilometraje_ingreso, nivel_combustible, motivo_informado)
VALUES (9010, '5YJ3E1EA7KF000001', 107, 107, 107, 201, '2026-11-15 09:00', 31600, 'Lleno', 'Ruido en ventilación (reclamo de garantía)');
INSERT 0 1
INSERT INTO historial_orden (orden_id, estado, fecha_hora, personal_id) VALUES (9010, 'Recibida', '2026-11-15 09:00', 201);
INSERT 0 1
COMMIT;
COMMIT
SELECT pruebas.esperar_rechazo('G02-INT-18', 'RN-22', 'aceptar un reclamo fuera del límite de km (vence lo primero)',
     $q$ INSERT INTO reclamo_garantia (garantia_id, orden_nueva_id, fecha_reclamo, evaluacion, decision, justificacion, evaluado_por_id)
         SELECT g.garantia_id, 9010, '2026-11-15 09:30', 'Ruido por filtro mal asentado', 'Aceptada', 'Cubre', 205
         FROM garantia g WHERE g.labor_id = pruebas.labor_id(9007, 'Cambio de filtro') $q$,
     'dentro del límite de km: no');
psql:pruebas/90_integridad_modelo.sql:499: NOTICE:  OK    [G02-INT-18] rechazo esperado -> P0001: G02-INT: garantía 1 vencida (vence lo primero): dentro del plazo de días: sí; dentro del límite de km: no; el reclamo solo puede registrarse como Rechazada con justificación (RN-22)
                                                                                               esperar_rechazo                                                                                               
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 OK G02-INT-18: P0001: G02-INT: garantía 1 vencida (vence lo primero): dentro del plazo de días: sí; dentro del límite de km: no; el reclamo solo puede registrarse como Rechazada con justificación (RN-22)
(1 row)

SELECT pruebas.esperar_rechazo('G02-INT-18', 'RN-22', 'rechazar sin justificación',
     $q$ INSERT INTO reclamo_garantia (garantia_id, orden_nueva_id, fecha_reclamo, evaluacion, decision, evaluado_por_id)
         SELECT g.garantia_id, 9010, '2026-11-15 09:30', 'Fuera de km', 'Rechazada', 205
         FROM garantia g WHERE g.labor_id = pruebas.labor_id(9007, 'Cambio de filtro') $q$,
     'ck_reclamo_justificacion');
psql:pruebas/90_integridad_modelo.sql:504: NOTICE:  OK    [G02-INT-18] rechazo esperado -> 23514: new row for relation "reclamo_garantia" violates check constraint "ck_reclamo_justificacion"
                                                  esperar_rechazo                                                   
--------------------------------------------------------------------------------------------------------------------
 OK G02-INT-18: 23514: new row for relation "reclamo_garantia" violates check constraint "ck_reclamo_justificacion"
(1 row)

SELECT pruebas.esperar_rechazo('G02-INT-18', 'RN-21', 'kilometraje del reclamo distinto al de ingreso de la orden nueva',
     $q$ INSERT INTO reclamo_garantia (garantia_id, orden_nueva_id, fecha_reclamo, km_reclamo, evaluacion, decision, justificacion, evaluado_por_id)
         SELECT g.garantia_id, 9010, '2026-11-15 09:30', 30500, 'Km maquillado', 'Aceptada', 'Cubre', 205
         FROM garantia g WHERE g.labor_id = pruebas.labor_id(9007, 'Cambio de filtro') $q$,
     'debe ser el de ingreso de la orden nueva');
psql:pruebas/90_integridad_modelo.sql:509: NOTICE:  OK    [G02-INT-18] rechazo esperado -> P0001: G02-INT: el kilometraje del reclamo (30500) debe ser el de ingreso de la orden nueva 9010 (31600)
                                                     esperar_rechazo                                                     
-------------------------------------------------------------------------------------------------------------------------
 OK G02-INT-18: P0001: G02-INT: el kilometraje del reclamo (30500) debe ser el de ingreso de la orden nueva 9010 (31600)
(1 row)

-- Válido: fuera de límite se registra como Rechazada con justificación.
INSERT INTO reclamo_garantia (garantia_id, orden_nueva_id, fecha_reclamo, evaluacion, decision, justificacion, evaluado_por_id)
SELECT g.garantia_id, 9010, '2026-11-15 09:30', 'Ruido por filtro mal asentado', 'Rechazada',
       'Se superó el límite de 1 000 km de la garantía (1 585 km recorridos desde la entrega)', 205
FROM garantia g WHERE g.labor_id = pruebas.labor_id(9007, 'Cambio de filtro');
INSERT 0 1
SELECT fn_cambiar_estado_orden(9010, 'Cancelada', 201, 'Reclamo rechazado; la clienta retira el vehículo sin reparación', '2026-11-15 10:00');
 fn_cambiar_estado_orden 
-------------------------
                      56
(1 row)

BEGIN;
BEGIN
INSERT INTO orden_trabajo (orden_id, vin, cliente_factura_id, entregado_por_cliente_id, autorizador_cliente_id, receptor_id,
                           fecha_hora_recepcion, kilometraje_ingreso, nivel_combustible, motivo_informado)
VALUES (9008, '5YJ3E1EA7KF000001', 107, 107, 107, 201, '2026-11-18 10:00', 30215, 'Lleno', 'Olor en la ventilación (reclamo de garantía)'),
       (9009, 'WVWZZZ1JZXW000001', 102, 102, 102, 201, '2026-11-18 11:00', 88000, '1/2', 'Ruido en ventilación');
INSERT 0 2
INSERT INTO historial_orden (orden_id, estado, fecha_hora, personal_id)
VALUES (9008, 'Recibida', '2026-11-18 10:00', 201), (9009, 'Recibida', '2026-11-18 11:00', 201);
INSERT 0 2
COMMIT;
COMMIT
SELECT pruebas.esperar_rechazo('G02-INT-18', 'RN-22', 'aceptar un reclamo fuera del límite de días (vence lo primero)',
     $q$ INSERT INTO reclamo_garantia (garantia_id, orden_nueva_id, fecha_reclamo, evaluacion, decision, justificacion, evaluado_por_id)
         SELECT g.garantia_id, 9008, '2026-11-18 10:30', 'Falla no detectada en la revisión', 'Aceptada', 'Cubre', 205
         FROM garantia g WHERE g.labor_id = pruebas.labor_id(9007, 'Revisión general') $q$,
     'dentro del plazo de días: no');
psql:pruebas/90_integridad_modelo.sql:530: NOTICE:  OK    [G02-INT-18] rechazo esperado -> P0001: G02-INT: garantía 2 vencida (vence lo primero): dentro del plazo de días: no; dentro del límite de km: sí; el reclamo solo puede registrarse como Rechazada con justificación (RN-22)
                                                                                               esperar_rechazo                                                                                               
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 OK G02-INT-18: P0001: G02-INT: garantía 2 vencida (vence lo primero): dentro del plazo de días: no; dentro del límite de km: sí; el reclamo solo puede registrarse como Rechazada con justificación (RN-22)
(1 row)

SELECT pruebas.esperar_rechazo('G02-INT-18', 'RN-21', 'reclamo con orden de OTRO vehículo',
     $q$ INSERT INTO reclamo_garantia (garantia_id, orden_nueva_id, fecha_reclamo, evaluacion, decision, evaluado_por_id)
         SELECT g.garantia_id, 9009, '2026-11-18 11:30', 'Otro vehículo', 'Pendiente', 205
         FROM garantia g WHERE g.labor_id = pruebas.labor_id(9007, 'Cambio de filtro') $q$,
     'no del vehículo garantizado');
psql:pruebas/90_integridad_modelo.sql:535: NOTICE:  OK    [G02-INT-18] rechazo esperado -> P0001: G02-INT: la orden nueva 9009 es del vehículo WVWZZZ1JZXW000001, no del vehículo garantizado 5YJ3E1EA7KF000001
                                                           esperar_rechazo                                                           
-------------------------------------------------------------------------------------------------------------------------------------
 OK G02-INT-18: P0001: G02-INT: la orden nueva 9009 es del vehículo WVWZZZ1JZXW000001, no del vehículo garantizado 5YJ3E1EA7KF000001
(1 row)

SELECT pruebas.esperar_rechazo('G02-INT-18', 'RN-21', 'reclamo sobre la misma orden garantizada',
     $q$ INSERT INTO reclamo_garantia (garantia_id, orden_nueva_id, fecha_reclamo, evaluacion, decision, evaluado_por_id)
         SELECT g.garantia_id, 9007, '2026-11-18 11:30', 'Misma orden', 'Pendiente', 205
         FROM garantia g WHERE g.labor_id = pruebas.labor_id(9007, 'Cambio de filtro') $q$,
     'debe abrir una orden nueva');
psql:pruebas/90_integridad_modelo.sql:540: NOTICE:  OK    [G02-INT-18] rechazo esperado -> P0001: G02-INT: el reclamo debe abrir una orden nueva, distinta de la orden garantizada (RN-21)
                                                esperar_rechazo                                                 
----------------------------------------------------------------------------------------------------------------
 OK G02-INT-18: P0001: G02-INT: el reclamo debe abrir una orden nueva, distinta de la orden garantizada (RN-21)
(1 row)

-- Válido: dentro de AMBOS límites de G1 (11 días < 30 y 200 km < 1 000).
INSERT INTO reclamo_garantia (garantia_id, orden_nueva_id, fecha_reclamo, evaluacion, decision, justificacion, evaluado_por_id)
SELECT g.garantia_id, 9008, '2026-11-18 10:30', 'Filtro con defecto de fábrica', 'Aceptada',
       'Dentro de 30 días y 1 000 km desde la entrega', 205
FROM garantia g WHERE g.labor_id = pruebas.labor_id(9007, 'Cambio de filtro');
INSERT 0 1
SELECT pruebas.esperar_rechazo('G02-INT-18', 'RN-21', 'segundo reclamo con la misma orden nueva',
     $q$ INSERT INTO reclamo_garantia (garantia_id, orden_nueva_id, fecha_reclamo, evaluacion, decision, justificacion, evaluado_por_id)
         SELECT g.garantia_id, 9008, '2026-11-18 10:40', 'Duplicado', 'Rechazada', 'Duplicado', 205
         FROM garantia g WHERE g.labor_id = pruebas.labor_id(9007, 'Cambio de filtro') $q$,
     'uq_reclamo_orden_nueva');
psql:pruebas/90_integridad_modelo.sql:550: NOTICE:  OK    [G02-INT-18] rechazo esperado -> 23505: duplicate key value violates unique constraint "uq_reclamo_orden_nueva"
                                        esperar_rechazo                                        
-----------------------------------------------------------------------------------------------
 OK G02-INT-18: 23505: duplicate key value violates unique constraint "uq_reclamo_orden_nueva"
(1 row)

SELECT pruebas.esperar_rechazo('G02-INT-18', 'RN-21', 'reevaluar un reclamo ya decidido',
     $q$ UPDATE reclamo_garantia SET decision = 'Rechazada' WHERE orden_nueva_id = 9008 $q$,
     'solo se reevalúa mientras está Pendiente');
psql:pruebas/90_integridad_modelo.sql:553: NOTICE:  OK    [G02-INT-18] rechazo esperado -> P0001: G02-INM: el reclamo 8 solo se reevalúa mientras está Pendiente
                                   esperar_rechazo                                    
--------------------------------------------------------------------------------------
 OK G02-INT-18: P0001: G02-INM: el reclamo 8 solo se reevalúa mientras está Pendiente
(1 row)

SELECT g.garantia_id, l.descripcion AS labor, g.dias, g.km, r.orden_nueva_id, r.fecha_reclamo, r.km_reclamo, r.decision, r.justificacion
FROM garantia g JOIN labor l ON l.labor_id = g.labor_id LEFT JOIN reclamo_garantia r ON r.garantia_id = g.garantia_id
ORDER BY g.garantia_id, r.reclamo_id;
 garantia_id |             labor             | dias |  km  | orden_nueva_id |     fecha_reclamo      | km_reclamo | decision  |                                     justificacion                                     
-------------+-------------------------------+------+------+----------------+------------------------+------------+-----------+---------------------------------------------------------------------------------------
           1 | Cambio de filtro de cabina    |   30 | 1000 |           9010 | 2026-11-15 09:30:00-06 |      31600 | Rechazada | Se superó el límite de 1 000 km de la garantía (1 585 km recorridos desde la entrega)
           1 | Cambio de filtro de cabina    |   30 | 1000 |           9008 | 2026-11-18 10:30:00-06 |      30215 | Aceptada  | Dentro de 30 días y 1 000 km desde la entrega
           2 | Revisión general de 30 puntos |    5 | 5000 |                |                        |            |           | 
(3 rows)

SELECT pruebas.verificar('G02-INT-18', 'RN-22', 'garantía sin reclamo existe; G1 con un reclamo rechazado y uno aceptado',
     (SELECT count(*) = 0 FROM reclamo_garantia r JOIN garantia g USING (garantia_id) WHERE g.labor_id = pruebas.labor_id(9007, 'Revisión general'))
     AND (SELECT string_agg(r.decision, ',' ORDER BY r.reclamo_id) = 'Rechazada,Aceptada'
          FROM reclamo_garantia r JOIN garantia g USING (garantia_id) WHERE g.labor_id = pruebas.labor_id(9007, 'Cambio de filtro')),
     'G2 sin reclamos; G1: Rechazada, Aceptada',
     'G2 ' || (SELECT count(*) FROM reclamo_garantia r JOIN garantia g USING (garantia_id) WHERE g.labor_id = pruebas.labor_id(9007, 'Revisión general'))
     || ' reclamos; G1: ' || (SELECT string_agg(r.decision, ',' ORDER BY r.reclamo_id)
          FROM reclamo_garantia r JOIN garantia g USING (garantia_id) WHERE g.labor_id = pruebas.labor_id(9007, 'Cambio de filtro')));
psql:pruebas/90_integridad_modelo.sql:565: NOTICE:  OK    [G02-INT-18] G2 sin reclamos; G1: Rechazada, Aceptada -> G2 0 reclamos; G1: Rechazada,Aceptada
                      verificar                       
------------------------------------------------------
 OK G02-INT-18: G2 0 reclamos; G1: Rechazada,Aceptada
(1 row)

-- #####################################################################
-- E. HISTORIA (estados y promesas): cubierta por P03 — ver 30..33.
-- F. CONSULTAS REUTILIZADAS DEL LAB03 (rótulos corregidos, D5)
-- #####################################################################
SELECT * FROM v_q01_ordenes_pendientes_atencion;
 orden_id | placa  |          cliente           |     estado     |  fecha_hora_recepcion  
----------+--------+----------------------------+----------------+------------------------
     9002 | GHI789 | Transportes del Valle S.A. | En diagnóstico | 2026-11-03 09:10:00-06
     9004 | JKL012 | Mensajería Central S.A.    | En diagnóstico | 2026-11-05 07:30:00-06
     9014 | HIJ456 | Jorge Quesada              | En diagnóstico | 2026-11-08 10:00:00-06
(3 rows)

SELECT * FROM v_q02_visitas_por_vehiculo;      -- Q02: VISITAS POR VEHÍCULO
 placa  |   marca    | modelo  | total_visitas 
--------+------------+---------+---------------
 STU901 | Tesla      | Model 3 |             3
 ABC123 | Honda      | Accord  |             1
 BCD890 | Ford       | Fiesta  |             1
 DEF456 | Volkswagen | Jetta   |             1
 EFG123 | Toyota     | Prius   |             1
 GHI789 | Ford       | F-150   |             1
 HIJ456 | Chevrolet  | Malibu  |             1
 JKL012 | Toyota     | Corolla |             1
 KLM789 | Honda      | Civic   |             1
 MNO345 | Nissan     | Leaf    |             1
 PQR999 | Hyundai    | Accent  |             1
 VWX234 | Volkswagen | Golf    |             1
 YZA567 | Nissan     | Altima  |             1
(13 rows)

SELECT * FROM v_q03_hallazgos_alta_urgencia;
 hallazgo_id | orden_id | placa  |           sintoma_comprobado            | urgencia |                  recomendacion                  
-------------+----------+--------+-----------------------------------------+----------+-------------------------------------------------
        4108 |     9004 | JKL012 | Pedal de freno se hunde; fuga visible   | Crítica  | No circular: reparar fuga del sistema de frenos
        4104 |     9003 | DEF456 | Chirrido metálico al frenar             | Alta     | Cambiar pastillas y revisar discos
        4110 |     9005 | MNO345 | Batería auxiliar de 12 V con baja carga | Alta     | Reemplazar batería auxiliar
        4113 |     9012 | BCD890 | Discos con surcos profundos             | Alta     | Cambiar disco delantero
(4 rows)

SELECT * FROM v_q04_conteo_ordenes_por_estado; -- Q04: CONTEO DE ÓRDENES POR ESTADO
     estado     | cantidad_ordenes 
----------------+------------------
 Autorizada     |                2
 Cancelada      |                2
 En diagnóstico |                3
 En reparación  |                1
 Entregada      |                1
 Recibida       |                6
(6 rows)

SELECT fn_total_ordenes_cliente(101) AS visitas_facturadas_a_maria, fn_prioridad_orden(9004) AS prioridad_9004;
 visitas_facturadas_a_maria |   prioridad_9004   
----------------------------+--------------------
                          2 | Atención inmediata
(1 row)

SELECT pruebas.verificar('G02-INT-19', 'D5', 'Q04 cuenta las órdenes por estado y coincide con estado_actual',
     (SELECT sum(cantidad_ordenes) = (SELECT count(*) FROM orden_trabajo) FROM v_q04_conteo_ordenes_por_estado)
     AND NOT EXISTS (SELECT estado, cantidad_ordenes FROM v_q04_conteo_ordenes_por_estado
                     EXCEPT SELECT estado_actual, count(*) FROM orden_trabajo GROUP BY estado_actual),
     'Q04 = conteo por estado_actual',
     (SELECT string_agg(estado || ':' || cantidad_ordenes, ', ' ORDER BY estado) FROM v_q04_conteo_ordenes_por_estado));
psql:pruebas/90_integridad_modelo.sql:581: NOTICE:  OK    [G02-INT-19] Q04 = conteo por estado_actual -> Autorizada:2, Cancelada:2, En diagnóstico:3, En reparación:1, Entregada:1, Recibida:6
                                              verificar                                               
------------------------------------------------------------------------------------------------------
 OK G02-INT-19: Autorizada:2, Cancelada:2, En diagnóstico:3, En reparación:1, Entregada:1, Recibida:6
(1 row)

SELECT pruebas.verificar('G02-INT-19', 'D5', 'Q02 cuenta visitas por vehículo (el Tesla tiene 3: 9007, 9008, 9010)',
     (SELECT total_visitas = 3 FROM v_q02_visitas_por_vehiculo WHERE placa = 'STU901'),
     'STU901: 3 visitas', (SELECT placa || ': ' || total_visitas || ' visitas' FROM v_q02_visitas_por_vehiculo WHERE placa = 'STU901'));
psql:pruebas/90_integridad_modelo.sql:584: NOTICE:  OK    [G02-INT-19] STU901: 3 visitas -> STU901: 3 visitas
            verificar             
----------------------------------
 OK G02-INT-19: STU901: 3 visitas
(1 row)

-- Coherencia global al final de toda la batería.
SELECT pruebas.verificar('G02-INT-20', 'D4', 'todas las órdenes: valor actual = última fila de cada historial',
     NOT EXISTS (
        SELECT 1 FROM orden_trabajo o
        WHERE o.estado_actual IS DISTINCT FROM (SELECT estado FROM historial_orden h WHERE h.orden_id = o.orden_id ORDER BY secuencia DESC LIMIT 1)
           OR o.fecha_prometida_actual IS DISTINCT FROM (SELECT fecha_nueva FROM historial_fecha_prometida f WHERE f.orden_id = o.orden_id ORDER BY secuencia DESC LIMIT 1)),
     '0 órdenes incoherentes', (SELECT count(*) || ' órdenes revisadas' FROM orden_trabajo));
psql:pruebas/90_integridad_modelo.sql:592: NOTICE:  OK    [G02-INT-20] 0 órdenes incoherentes -> 15 órdenes revisadas
              verificar              
-------------------------------------
 OK G02-INT-20: 15 órdenes revisadas
(1 row)

SELECT pruebas.verificar('G02-INT-20', 'D9', 'todas las labores: estado = última fila de su historial',
     NOT EXISTS (SELECT 1 FROM labor l
                 WHERE l.estado_labor IS DISTINCT FROM (SELECT estado_nuevo FROM historial_labor h WHERE h.labor_id = l.labor_id ORDER BY secuencia DESC LIMIT 1)),
     '0 labores incoherentes', (SELECT count(*) || ' labores revisadas' FROM labor));
psql:pruebas/90_integridad_modelo.sql:596: NOTICE:  OK    [G02-INT-20] 0 labores incoherentes -> 22 labores revisadas
              verificar              
-------------------------------------
 OK G02-INT-20: 22 labores revisadas
(1 row)

```
