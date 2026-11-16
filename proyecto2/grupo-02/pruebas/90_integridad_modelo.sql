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
SET TIME ZONE 'America/Costa_Rica';

-- #####################################################################
-- A. IDENTIDAD Y ROLES
-- #####################################################################

-- ===========================================================
-- ID: G02-INT-01   Relación: cliente      Categoría: identidad / dominio
-- ===========================================================
SELECT pruebas.esperar_rechazo('G02-INT-01', 'RN-04', 'identificación duplicada',
     $q$ INSERT INTO cliente (identificacion, nombre_razon_social, tipo_cliente) VALUES ('FICT-P001', 'Duplicada', 'Persona') $q$,
     'uq_cliente_identificacion');
SELECT pruebas.esperar_rechazo('G02-INT-01', 'RN-04', 'tipo de cliente fuera de dominio',
     $q$ INSERT INTO cliente (identificacion, nombre_razon_social, tipo_cliente) VALUES ('FICT-X01', 'Tipo raro', 'Empresa') $q$,
     'ck_cliente_tipo');
SELECT pruebas.esperar_rechazo('G02-INT-01', 'RN-04', 'nombre vacío',
     $q$ INSERT INTO cliente (identificacion, nombre_razon_social, tipo_cliente) VALUES ('FICT-X02', '   ', 'Persona') $q$,
     'ck_cliente_nombre');

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
SELECT pruebas.esperar_rechazo('G02-INT-02', 'RN-03', 'cliente con contacto que NO recibe avisos (al COMMIT)',
     $q$ DO $b$ DECLARE v integer; BEGIN
            INSERT INTO cliente (identificacion, nombre_razon_social, tipo_cliente) VALUES ('FICT-P021', 'Solo correo sin avisos', 'Persona')
            RETURNING cliente_id INTO v;
            INSERT INTO contacto_cliente (cliente_id, tipo_contacto, valor_contacto, recibe_avisos) VALUES (v, 'Correo', 'sin.avisos@ejemplo.test', false);
            SET CONSTRAINTS ALL IMMEDIATE;
         END $b$ $q$,
     'debe tener al menos un contacto apto para avisos');
SELECT pruebas.esperar_rechazo('G02-INT-02', 'RN-03', 'quitar el único contacto apto de María (al COMMIT)',
     $q$ DO $b$ BEGIN
            UPDATE contacto_cliente SET recibe_avisos = false WHERE contacto_id = 1;
            SET CONSTRAINTS ALL IMMEDIATE;
         END $b$ $q$,
     'el cliente 101 debe tener al menos un contacto apto');
SELECT pruebas.esperar_rechazo('G02-INT-02', 'RN-03', 'correo con formato inválido',
     $q$ INSERT INTO contacto_cliente (cliente_id, tipo_contacto, valor_contacto, recibe_avisos) VALUES (101, 'Correo', 'maria(arroba)ejemplo', false) $q$,
     'ck_contacto_formato');
SELECT pruebas.esperar_rechazo('G02-INT-02', 'RN-03', 'teléfono con formato inválido',
     $q$ INSERT INTO contacto_cliente (cliente_id, tipo_contacto, valor_contacto, recibe_avisos) VALUES (101, 'Teléfono', '88-AB', false) $q$,
     'ck_contacto_formato');
-- Válido: cliente y su contacto en la misma transacción (en cualquier orden).
BEGIN;
INSERT INTO cliente (cliente_id, identificacion, nombre_razon_social, tipo_cliente) VALUES (109, 'FICT-P009', 'Sara Vindas', 'Persona');
INSERT INTO contacto_cliente (cliente_id, tipo_contacto, valor_contacto, recibe_avisos) VALUES (109, 'Teléfono', '+50688880109', true);
COMMIT;
SELECT pruebas.verificar('G02-INT-02', 'RN-03', 'cliente nuevo con contacto apto confirmado',
     EXISTS (SELECT 1 FROM contacto_cliente WHERE cliente_id = 109 AND recibe_avisos)
     AND NOT EXISTS (SELECT 1 FROM cliente c WHERE NOT EXISTS (SELECT 1 FROM contacto_cliente k WHERE k.cliente_id = c.cliente_id AND k.recibe_avisos)),
     'todo cliente tiene >= 1 contacto apto',
     (SELECT count(*) || ' clientes, todos con contacto apto' FROM cliente));

-- ===========================================================
-- ID: G02-INT-03   Relación: vehiculo   Categoría: identidad / dominio (RN-02)
-- ===========================================================
SELECT pruebas.esperar_rechazo('G02-INT-03', 'RN-02', 'VIN con letra O (no permitida)',
     $q$ INSERT INTO vehiculo VALUES ('1HGCM82633AO23456', 'XYZ001', 'Honda', 'Fit', 2020, 'Gasolina') $q$,
     'ck_vehiculo_vin');
SELECT pruebas.esperar_rechazo('G02-INT-03', 'RN-02', 'VIN de 16 caracteres',
     $q$ INSERT INTO vehiculo VALUES ('1HGCM82633A12345', 'XYZ001', 'Honda', 'Fit', 2020, 'Gasolina') $q$,
     'ck_vehiculo_vin');
SELECT pruebas.esperar_rechazo('G02-INT-03', 'RN-02', 'año mayor que el actual + 1',
     $q$ INSERT INTO vehiculo VALUES ('1HGCM82633A999999', 'XYZ001', 'Honda', 'Fit', extract(year FROM now())::int + 2, 'Gasolina') $q$,
     'supera el año actual + 1');
SELECT pruebas.esperar_rechazo('G02-INT-03', 'RN-02', 'reescribir el VIN',
     $q$ UPDATE vehiculo SET vin = '1HGCM82633A000000' WHERE vin = '1HGCM82633A123456' $q$,
     'identidad estable');

-- ===========================================================
-- ID: G02-INT-04   Relación: vehiculo / orden_trabajo   Categoría: temporalidad (RN-02)
-- Acción: la placa del Hyundai cambia de PQR678 a PQR999.
-- Esperado: la orden 9006 conserva placa_ingreso = PQR678.
-- ===========================================================
UPDATE vehiculo SET placa = 'PQR999' WHERE vin = 'KMHCT41DAEU000001';
SELECT pruebas.verificar('G02-INT-04', 'RN-02', 'la placa cambia sin afectar la visita previa',
     (SELECT v.placa = 'PQR999' AND o.placa_ingreso = 'PQR678'
      FROM orden_trabajo o JOIN vehiculo v USING (vin) WHERE o.orden_id = 9006),
     'vehículo PQR999; orden 9006 ingresó con PQR678',
     (SELECT 'vehículo ' || v.placa || '; orden 9006 ingresó con ' || o.placa_ingreso
      FROM orden_trabajo o JOIN vehiculo v USING (vin) WHERE o.orden_id = 9006));

-- ===========================================================
-- ID: G02-INT-05   Relación: propiedad_vehiculo   Categoría: temporalidad / contexto (D12)
-- Acción: Ana vende el Hyundai a Laura el 2026-11-10.
-- Esperado: la propiedad queda en dos periodos sin traslape; la visita
--   9006 sigue facturada a Ana; un traslape se rechaza; reescribir los roles
--   de la visita se rechaza.
-- ===========================================================
BEGIN;
UPDATE propiedad_vehiculo SET hasta = '2026-11-10' WHERE propiedad_id = 6;
INSERT INTO propiedad_vehiculo (vin, cliente_id, desde) VALUES ('KMHCT41DAEU000001', 107, '2026-11-10');
COMMIT;
SELECT * FROM propiedad_vehiculo WHERE vin = 'KMHCT41DAEU000001' ORDER BY desde;
SELECT pruebas.esperar_rechazo('G02-INT-05', 'RN-02', 'dos propietarios en el mismo periodo',
     $q$ INSERT INTO propiedad_vehiculo (vin, cliente_id, desde) VALUES ('KMHCT41DAEU000001', 108, '2026-11-15') $q$,
     'ex_propiedad_sin_traslape');
SELECT pruebas.esperar_rechazo('G02-INT-05', 'RN-04', 'reescribir a quién se facturó una visita anterior',
     $q$ UPDATE orden_trabajo SET cliente_factura_id = 107 WHERE orden_id = 9006 $q$,
     'quedan fijados por visita');
SELECT pruebas.verificar('G02-INT-05', 'RN-04', 'el cambio de propietario no reescribe la visita',
     (SELECT cliente_factura_id = 104 FROM orden_trabajo WHERE orden_id = 9006)
     AND (SELECT cliente_id = 107 FROM propiedad_vehiculo WHERE vin = 'KMHCT41DAEU000001' AND hasta IS NULL),
     'propietario actual Laura (107); visita 9006 facturada a Ana (104)',
     'propietario actual ' || (SELECT cliente_id FROM propiedad_vehiculo WHERE vin = 'KMHCT41DAEU000001' AND hasta IS NULL)
     || '; visita 9006 facturada a ' || (SELECT cliente_factura_id FROM orden_trabajo WHERE orden_id = 9006));

-- ===========================================================
-- ID: G02-INT-06   Relación: orden_trabajo   Categoría: identidad / estado (RN-01, RN-05)
-- ===========================================================
SELECT pruebas.esperar_rechazo('G02-INT-06', 'RN-01', 'segunda visita abierta del mismo vehículo',
     $q$ INSERT INTO orden_trabajo (vin, cliente_factura_id, entregado_por_cliente_id, autorizador_cliente_id, receptor_id,
                                   fecha_hora_recepcion, kilometraje_ingreso, nivel_combustible, motivo_informado)
         VALUES ('1HGCM82633A123456', 101, 101, 101, 201, '2026-11-09 08:00', 85100, '1/2', 'Otra visita') $q$,
     'uq_orden_abierta_por_vehiculo');
SELECT pruebas.esperar_rechazo('G02-INT-06', 'RN-05', 'kilometraje de ingreso negativo',
     $q$ INSERT INTO orden_trabajo (vin, cliente_factura_id, entregado_por_cliente_id, autorizador_cliente_id, receptor_id,
                                   kilometraje_ingreso, nivel_combustible, motivo_informado)
         VALUES ('2HGFC2F59KH000001', 108, 108, 108, 201, -1, '1/2', 'Km negativo') $q$,
     'ck_orden_km_ingreso');
SELECT pruebas.esperar_rechazo('G02-INT-06', 'RN-05', 'nivel de combustible fuera de dominio',
     $q$ INSERT INTO orden_trabajo (vin, cliente_factura_id, entregado_por_cliente_id, autorizador_cliente_id, receptor_id,
                                   kilometraje_ingreso, nivel_combustible, motivo_informado)
         VALUES ('2HGFC2F59KH000001', 108, 108, 108, 201, 100, '7/8', 'Combustible') $q$,
     'ck_orden_combustible');
SELECT pruebas.esperar_rechazo('G02-INT-06', 'RN-08', 'orden sin estado inicial en el historial (al COMMIT)',
     $q$ DO $b$ BEGIN
            INSERT INTO orden_trabajo (vin, cliente_factura_id, entregado_por_cliente_id, autorizador_cliente_id, receptor_id,
                                       kilometraje_ingreso, nivel_combustible, motivo_informado)
            VALUES ('2HGFC2F59KH000001', 108, 108, 108, 201, 40000, '1/2', 'Sin historial');
            SET CONSTRAINTS ALL IMMEDIATE;
         END $b$ $q$,
     'no tiene su estado inicial');
SELECT pruebas.esperar_rechazo('G02-INT-06', 'RN-08', 'orden que nace en un estado distinto de Recibida',
     $q$ INSERT INTO orden_trabajo (vin, cliente_factura_id, entregado_por_cliente_id, autorizador_cliente_id, receptor_id,
                                   kilometraje_ingreso, nivel_combustible, motivo_informado, estado_actual)
         VALUES ('2HGFC2F59KH000001', 108, 108, 108, 201, 40000, '1/2', 'Estado inicial falso', 'Autorizada') $q$,
     'inicia en Recibida');
SELECT pruebas.esperar_rechazo('G02-INT-06', 'RN-05', 'reescribir el kilometraje de ingreso',
     $q$ UPDATE orden_trabajo SET kilometraje_ingreso = 1 WHERE orden_id = 9001 $q$,
     'quedan fijados por visita');

-- Alta REUTILIZADA del Lab03 (sp_registrar_orden, sin modificar).
CALL sp_registrar_orden(9901, '2HGFC2F59KH000001', 108, 108, 108, 206, 40000, '1/2', 'Revisión general (alta reutilizada del Lab03)');
SELECT orden_id, vin, placa_ingreso, estado_actual, kilometraje_ingreso FROM orden_trabajo WHERE orden_id = 9901;
SELECT pruebas.verificar('G02-INT-06', 'RN-01', 'alta del Lab03 sobre el modelo nuevo',
     (SELECT placa_ingreso = 'KLM789' AND estado_actual = 'Recibida' FROM orden_trabajo WHERE orden_id = 9901)
     AND (SELECT count(*) = 1 AND min(secuencia) = 1 FROM historial_orden WHERE orden_id = 9901)
     AND (SELECT count(*) = 2 FROM facultad_orden WHERE orden_id = 9901),
     'placa KLM789, Recibida, historial secuencia 1, 2 facultades del titular',
     (SELECT placa_ingreso || ', ' || estado_actual FROM orden_trabajo WHERE orden_id = 9901) || ', '
     || (SELECT count(*) FROM historial_orden WHERE orden_id = 9901) || ' estado(s), '
     || (SELECT count(*) FROM facultad_orden WHERE orden_id = 9901) || ' facultades');
SELECT pruebas.esperar_rechazo('G02-INT-06', 'RN-05', 'alta del Lab03 con kilometraje negativo (validación propia del Lab03)',
     $q$ CALL sp_registrar_orden(9902, '2HGFC2F59KH000001', 108, 108, 108, 206, -50, '1/2', 'Km inválido') $q$,
     'no puede ser negativo');

-- ===========================================================
-- ID: G02-INT-07   Relación: facultad_orden   Categoría: contexto / temporalidad (D2)
-- ===========================================================
SELECT pruebas.esperar_rechazo('G02-INT-07', 'RN-04', 'designación otorgada por quien no es el titular',
     $q$ INSERT INTO facultad_orden (orden_id, cliente_id, tipo_facultad, fuente, otorgada_por_cliente_id, medio_verificacion, vigente_desde, registrada_por_id)
         VALUES (9002, 108, 'Retirar', 'Designación', 104, 'Nota firmada por Ana', '2026-11-03 12:00', 201) $q$,
     'solo el titular de la orden 9002');
SELECT pruebas.esperar_rechazo('G02-INT-07', 'RN-04', 'misma facultad vigente duplicada',
     $q$ INSERT INTO facultad_orden (orden_id, cliente_id, tipo_facultad, fuente, medio_verificacion, vigente_desde, registrada_por_id)
         VALUES (9001, 101, 'Aprobar', 'Titular', 'Duplicada', '2026-11-03 12:00', 201) $q$,
     'ex_facultad_sin_traslape');
SELECT pruebas.esperar_rechazo('G02-INT-07', 'RN-04', 'titular con otorgante',
     $q$ INSERT INTO facultad_orden (orden_id, cliente_id, tipo_facultad, fuente, otorgada_por_cliente_id, medio_verificacion, vigente_desde, registrada_por_id)
         VALUES (9001, 102, 'Retirar', 'Titular', 101, 'x', '2026-11-03 12:00', 201) $q$,
     'ck_facultad_otorgante');
SELECT pruebas.esperar_rechazo('G02-INT-07', 'RN-04', 'facultad vigente antes de la recepción',
     $q$ INSERT INTO facultad_orden (orden_id, cliente_id, tipo_facultad, fuente, otorgada_por_cliente_id, medio_verificacion, vigente_desde, registrada_por_id)
         VALUES (9001, 102, 'Retirar', 'Designación', 101, 'Nota', '2026-11-01 12:00', 201) $q$,
     'antes de la recepción');
SELECT pruebas.esperar_rechazo('G02-INT-07', 'RN-04', 'borrar una facultad',
     $q$ DELETE FROM facultad_orden WHERE orden_id = 9001 $q$,
     'no se elimina');

-- ===========================================================
-- ID: G02-INT-08   Relación: objeto_dano   Categoría: estado (RN-06)
-- ===========================================================
SELECT pruebas.esperar_rechazo('G02-INT-08', 'RN-06', 'reescribir la descripción de un daño',
     $q$ UPDATE objeto_dano SET descripcion = 'Sin daños' WHERE detalle_id = 1 $q$,
     'solo admite confirmación');
SELECT pruebas.esperar_rechazo('G02-INT-08', 'RN-06', 'desconfirmar un objeto',
     $q$ UPDATE objeto_dano SET confirmado_cliente = false WHERE detalle_id = 2 $q$,
     'solo admite confirmación');
SELECT pruebas.esperar_rechazo('G02-INT-08', 'RN-06', 'borrar un objeto o daño',
     $q$ DELETE FROM objeto_dano WHERE detalle_id = 3 $q$,
     'no se elimina');

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
SELECT pruebas.esperar_rechazo('G02-INT-09', 'RN-09', 'autor que no es técnico',
     $q$ INSERT INTO hallazgo (orden_id, diagnosticado_por_id, fecha_hora, sintoma_comprobado, urgencia, recomendacion)
         VALUES (9014, 201, '2026-11-08 12:00', 'Ruido', 'Baja', 'Revisar') $q$,
     'tiene rol Recepción y se requiere Técnico');
SELECT pruebas.esperar_rechazo('G02-INT-09', 'RN-09', 'hallazgo anterior a la recepción',
     $q$ INSERT INTO hallazgo (orden_id, diagnosticado_por_id, fecha_hora, sintoma_comprobado, urgencia, recomendacion)
         VALUES (9014, 202, '2026-11-01 12:00', 'Ruido', 'Baja', 'Revisar') $q$,
     'anterior a la recepción');
SELECT pruebas.esperar_rechazo('G02-INT-09', 'RN-09', 'cambiar el autor de un hallazgo',
     $q$ UPDATE hallazgo SET diagnosticado_por_id = 203 WHERE hallazgo_id = 4101 $q$,
     'no se modifican');
SELECT pruebas.esperar_rechazo('G02-INT-09', 'RN-09', 'urgencia fuera de dominio',
     $q$ INSERT INTO hallazgo (orden_id, diagnosticado_por_id, fecha_hora, sintoma_comprobado, urgencia, recomendacion)
         VALUES (9014, 202, '2026-11-08 12:00', 'Ruido', 'Urgentísima', 'Revisar') $q$,
     'ck_hallazgo_urgencia');

-- ===========================================================
-- ID: G02-INT-10   Relación: especialidad_tecnico   Categoría: temporalidad / contexto (RN-14)
-- ===========================================================
SELECT pruebas.esperar_rechazo('G02-INT-10', 'RN-14', 'especialidad traslapada',
     $q$ INSERT INTO especialidad_tecnico (tecnico_id, especialidad, fecha_inicio) VALUES (202, 'Frenos', '2024-01-01') $q$,
     'ex_especialidad_sin_traslape');
SELECT pruebas.esperar_rechazo('G02-INT-10', 'RN-14', 'especialidad a personal que no es técnico',
     $q$ INSERT INTO especialidad_tecnico (tecnico_id, especialidad, fecha_inicio) VALUES (205, 'Electricidad', '2024-01-01') $q$,
     'solo un Técnico tiene especialidades');
SELECT pruebas.esperar_rechazo('G02-INT-10', 'RN-14', 'fin anterior al inicio',
     $q$ INSERT INTO especialidad_tecnico (tecnico_id, especialidad, fecha_inicio, fecha_fin) VALUES (203, 'Otra', '2024-01-01', '2023-01-01') $q$,
     'ck_especialidad_vigencia');
SELECT pruebas.esperar_rechazo('G02-INT-10', 'RN-14', 'quitar el rol Técnico con especialidades vigentes',
     $q$ UPDATE personal SET rol = 'Otro' WHERE personal_id = 203 $q$,
     'tiene especialidades vigentes');
-- Válido: misma especialidad en un periodo NO traslapado (renovación de Frenos de Andrés).
INSERT INTO especialidad_tecnico (tecnico_id, especialidad, fecha_inicio) VALUES (204, 'Frenos', '2026-12-01');
SELECT pruebas.verificar('G02-INT-10', 'RN-14', 'renovación sin traslape aceptada',
     (SELECT count(*) = 2 FROM especialidad_tecnico WHERE tecnico_id = 204 AND especialidad = 'Frenos'),
     '2 periodos de Frenos para Andrés',
     (SELECT string_agg(fecha_inicio || '..' || coalesce(fecha_fin::text, '∞'), ', ' ORDER BY fecha_inicio)
      FROM especialidad_tecnico WHERE tecnico_id = 204 AND especialidad = 'Frenos'));

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
SELECT pruebas.esperar_rechazo('G02-INT-11', 'RN-17', 'unidad de manejo fuera de dominio',
     $q$ INSERT INTO repuesto (repuesto_id, descripcion, unidad_manejo) VALUES ('FR-010', 'Unidad rara', 'Caja') $q$,
     'ck_repuesto_unidad');
SELECT pruebas.esperar_rechazo('G02-INT-11', 'RN-17', 'mismo código de proveedor dos veces en el mismo proveedor',
     $q$ INSERT INTO proveedor_repuesto (proveedor_id, repuesto_id, codigo_proveedor, precio_referencia) VALUES (2, 'FR-003', 'BOS-0986-494', 1000) $q$,
     'uq_prov_rep_codigo');
SELECT pruebas.esperar_rechazo('G02-INT-11', 'RN-17', 'precio de referencia negativo',
     $q$ INSERT INTO proveedor_repuesto (proveedor_id, repuesto_id, codigo_proveedor, precio_referencia) VALUES (3, 'FR-003', 'EA-1', -1) $q$,
     'ck_prov_rep_precio');
SELECT pruebas.esperar_rechazo('G02-INT-11', 'RN-17', 'proveedor duplicado',
     $q$ INSERT INTO proveedor (nombre) VALUES ('Distribuidora Frenos CR') $q$,
     'uq_proveedor_nombre');
-- Válido: el MISMO código de proveedor en OTRO proveedor (contexto distinto).
INSERT INTO proveedor_repuesto (proveedor_id, repuesto_id, codigo_proveedor, precio_referencia) VALUES (1, 'FR-003', 'BOS-0986-494', 39000);
SELECT pruebas.verificar('G02-INT-11', 'RN-17', 'mismo código de proveedor en proveedores distintos',
     (SELECT count(DISTINCT proveedor_id) = 2 FROM proveedor_repuesto WHERE codigo_proveedor = 'BOS-0986-494'),
     '2 proveedores con el código BOS-0986-494',
     (SELECT string_agg(proveedor_id || ':' || repuesto_id, ', ') FROM proveedor_repuesto WHERE codigo_proveedor = 'BOS-0986-494'));

-- ===========================================================
-- ID: G02-INT-12   Relación: movimiento_inventario   Categoría: dominio / estado (RN-19, D11)
-- Preparación: FR-003 (disco) tiene 1 unidad física y 0 reservadas.
-- ===========================================================
SELECT pruebas.esperar_rechazo('G02-INT-12', 'RN-19', 'ajuste negativo mayor que la existencia física',
     $q$ INSERT INTO movimiento_inventario (repuesto_id, tipo_movimiento, cantidad, registrado_por_id, motivo)
         VALUES ('FR-003', 'Ajuste negativo', 5, 205, 'Conteo físico') $q$,
     'existencias insuficientes de FR-003');
SELECT pruebas.esperar_rechazo('G02-INT-12', 'RN-19', 'reserva mayor que lo disponible',
     $q$ INSERT INTO movimiento_inventario (repuesto_id, orden_id, tipo_movimiento, cantidad, registrado_por_id)
         VALUES ('FR-003', 9014, 'Reserva', 2, 205) $q$,
     'disponibles');
SELECT pruebas.esperar_rechazo('G02-INT-12', 'RN-19', 'liberar más de lo reservado por la orden',
     $q$ INSERT INTO movimiento_inventario (repuesto_id, orden_id, tipo_movimiento, cantidad, registrado_por_id)
         VALUES ('FR-003', 9014, 'Liberación', 1, 205) $q$,
     'no se puede liberar');
SELECT pruebas.esperar_rechazo('G02-INT-12', 'RN-19', 'reserva sin orden',
     $q$ INSERT INTO movimiento_inventario (repuesto_id, tipo_movimiento, cantidad, registrado_por_id) VALUES ('FR-001', 'Reserva', 1, 205) $q$,
     'ck_movimiento_orden');
SELECT pruebas.esperar_rechazo('G02-INT-12', 'RN-19', 'ajuste sin motivo',
     $q$ INSERT INTO movimiento_inventario (repuesto_id, tipo_movimiento, cantidad, registrado_por_id) VALUES ('FR-001', 'Ajuste positivo', 1, 205) $q$,
     'ck_movimiento_ajuste_motivo');
SELECT pruebas.esperar_rechazo('G02-INT-12', 'RN-19', 'cantidad cero',
     $q$ INSERT INTO movimiento_inventario (repuesto_id, tipo_movimiento, cantidad, registrado_por_id) VALUES ('FR-001', 'Entrada', 0, 205) $q$,
     'ck_movimiento_cantidad');
SELECT pruebas.esperar_rechazo('G02-INT-12', 'RN-19', 'modificar un movimiento',
     $q$ UPDATE movimiento_inventario SET cantidad = 100 WHERE repuesto_id = 'FR-001' AND tipo_movimiento = 'Entrada' $q$,
     'solo inserción');
-- Válido: ajuste positivo con motivo.
INSERT INTO movimiento_inventario (repuesto_id, tipo_movimiento, cantidad, fecha_hora, registrado_por_id, motivo)
VALUES ('MG-002', 'Ajuste positivo', 1, '2026-11-06 18:00', 205, 'Conteo físico encontró un litro adicional');
SELECT * FROM v_existencias ORDER BY repuesto_id;
SELECT pruebas.verificar('G02-INT-12', 'RN-19', 'ninguna existencia física ni disponible es negativa',
     NOT EXISTS (SELECT 1 FROM v_existencias WHERE fisico < 0 OR disponible < 0),
     'todas las existencias >= 0',
     (SELECT string_agg(repuesto_id || '=' || fisico || '/' || disponible, ', ' ORDER BY repuesto_id) FROM v_existencias));

-- ===========================================================
-- ID: G02-INT-13   Relación: pieza_retirada   Categoría: contexto / estado
-- ===========================================================
SELECT pruebas.esperar_rechazo('G02-INT-13', 'RN-18', 'pieza retirada de una labor de OTRA orden',
     $q$ INSERT INTO pieza_retirada (labor_id, orden_id, descripcion, destino, registrado_por_id)
         VALUES (pruebas.labor_id(9003, 'Cambio de pastillas'), 9001, 'Pastillas usadas', 'Entregada cliente', 202) $q$,
     'fk_pieza_labor');
SELECT pruebas.esperar_rechazo('G02-INT-13', 'RN-18', 'pieza de una labor que no se ejecutó',
     $q$ INSERT INTO pieza_retirada (labor_id, orden_id, descripcion, destino, registrado_por_id)
         VALUES (pruebas.labor_id(9003, 'Limpieza de inyectores'), 9003, 'Inyector', 'Desechada autorizada', 202) $q$,
     'no tiene piezas retiradas');
SELECT pruebas.esperar_rechazo('G02-INT-13', 'RN-18', 'destino fuera de dominio',
     $q$ INSERT INTO pieza_retirada (labor_id, orden_id, descripcion, destino, registrado_por_id)
         VALUES (pruebas.labor_id(9003, 'Cambio de pastillas'), 9003, 'Pastillas usadas', 'Vendida', 202) $q$,
     'ck_pieza_destino');
INSERT INTO pieza_retirada (labor_id, orden_id, descripcion, destino, fecha_hora, registrado_por_id)
VALUES (pruebas.labor_id(9003, 'Cambio de pastillas'), 9003, 'Juego de pastillas delanteras usadas', 'Entregada cliente', '2026-11-05 09:35', 202),
       (pruebas.labor_id(9003, 'Sustitución del sensor'), 9003, 'Sensor de oxígeno defectuoso', 'Desechada autorizada', '2026-11-05 17:40', 203);

-- ===========================================================
-- ID: G02-INT-14   Distinguir presupuesto / reserva / consumo / pieza retirada (RN-18)
-- ===========================================================
SELECT concepto, labor_id, referencia, cantidad, precio_unitario FROM v_insumos_orden WHERE orden_id = 9003 ORDER BY concepto, labor_id;
SELECT pruebas.verificar('G02-INT-14', 'RN-18', 'una consulta distingue los cuatro conceptos',
     (SELECT count(DISTINCT split_part(concepto, ' ', 1)) >= 4 FROM v_insumos_orden WHERE orden_id = 9003),
     'Presupuesto, Reserva, Liberación, Consumo y Pieza en la orden 9003',
     (SELECT string_agg(DISTINCT split_part(concepto, ' (', 1), ', ') FROM v_insumos_orden WHERE orden_id = 9003));

-- ===========================================================
-- ID: G02-INT-15   Relación: labor_dependencia   Categoría: contexto (RN-15, D7)
-- ===========================================================
SELECT pruebas.esperar_rechazo('G02-INT-15', 'RN-15', 'dependencia circular',
     $q$ INSERT INTO labor_dependencia (labor_id, requiere_labor_id, orden_id)
         VALUES (pruebas.labor_id(9003, 'Cambio de pastillas'), pruebas.labor_id(9003, 'Purga'), 9003) $q$,
     'formaría un ciclo');
SELECT pruebas.esperar_rechazo('G02-INT-15', 'RN-15', 'dependencia con una labor de otra orden',
     $q$ INSERT INTO labor_dependencia (labor_id, requiere_labor_id, orden_id)
         VALUES (pruebas.labor_id(9001, 'Rotación'), pruebas.labor_id(9003, 'Purga'), 9001) $q$,
     'fk_dependencia_requerida');
SELECT pruebas.esperar_rechazo('G02-INT-15', 'RN-15', 'labor que depende de sí misma',
     $q$ INSERT INTO labor_dependencia (labor_id, requiere_labor_id, orden_id)
         VALUES (pruebas.labor_id(9001, 'Rotación'), pruebas.labor_id(9001, 'Rotación'), 9001) $q$,
     'ck_dependencia_distinta');
-- Válido: una labor puede depender de VARIAS (N:M). La rotación de 9001
-- requiere la alineación y el cambio de pastillas.
INSERT INTO labor_dependencia (labor_id, requiere_labor_id, orden_id)
VALUES (pruebas.labor_id(9001, 'Rotación'), pruebas.labor_id(9001, 'Alineación'), 9001),
       (pruebas.labor_id(9001, 'Rotación'), pruebas.labor_id(9001, 'Cambio de pastillas'), 9001);
SELECT pruebas.verificar('G02-INT-15', 'RN-15', 'una labor con dos dependencias',
     (SELECT count(*) = 2 FROM labor_dependencia WHERE labor_id = pruebas.labor_id(9001, 'Rotación')),
     '2 dependencias', (SELECT count(*) || ' dependencias' FROM labor_dependencia WHERE labor_id = pruebas.labor_id(9001, 'Rotación')));

-- #####################################################################
-- D. ENTREGA Y GARANTÍA (solo integridad; la preparación usa P01/P02/P03)
-- Orden 9007: Laura Jiménez, Tesla STU901, km de ingreso 30000.
-- #####################################################################
SELECT fn_cambiar_estado_orden(9007, 'En diagnóstico', 204, NULL, '2026-11-07 08:45');
SELECT fn_publicar_propuesta(9007, NULL,
  '[{"descripcion":"Cambio de filtro de cabina","hallazgo_id":4111,"precio_estimado":9000,
     "repuestos":[{"repuesto_id":"MG-001","cantidad":1,"precio_unitario":9000}]},
    {"descripcion":"Revisión general de 30 puntos","precio_estimado":15000},
    {"descripcion":"Lavado de motor","precio_estimado":10000}]'::jsonb,
  205, NULL, '2026-11-07 09:30');
SELECT fn_cambiar_estado_orden(9007, 'Pendiente autorización', 201, NULL, '2026-11-07 09:35');
SELECT fn_registrar_decision(pruebas.propuesta_id(9007, 1), l.labor_id, 107,
       CASE WHEN l.descripcion LIKE 'Lavado%' THEN 'Rechazada' ELSE 'Aceptada' END, 'Mensaje', 201, '2026-11-07 10:00')
FROM labor l WHERE l.orden_id = 9007 ORDER BY l.labor_id;
SELECT fn_cambiar_estado_orden(9007, 'Autorizada', 201, NULL, '2026-11-07 10:05');
SELECT fn_cambiar_estado_orden(9007, 'En reparación', 204, NULL, '2026-11-07 10:30');
SELECT fn_iniciar_labor(pruebas.labor_id(9007, 'Cambio de filtro'), 204, '2026-11-07 10:30');
SELECT fn_registrar_participacion(pruebas.labor_id(9007, 'Cambio de filtro'), 204, '2026-11-07 10:30', '2026-11-07 11:00', 25, 'Cambio de filtro', 4);
SELECT fn_registrar_consumo(9007, pruebas.labor_id(9007, 'Cambio de filtro'), 'MG-001', 1, 9000, 204, '2026-11-07 10:40');
SELECT fn_registrar_prueba(pruebas.labor_id(9007, 'Cambio de filtro'), 204, '2026-11-07 11:05', 'Flujo de aire', 'Favorable', 'Flujo normal');
SELECT fn_completar_labor(pruebas.labor_id(9007, 'Cambio de filtro'), 204, '2026-11-07 11:10');
SELECT fn_iniciar_labor(pruebas.labor_id(9007, 'Revisión general'), 202, '2026-11-07 11:15');
SELECT fn_registrar_participacion(pruebas.labor_id(9007, 'Revisión general'), 202, '2026-11-07 11:15', '2026-11-07 12:15', 60, 'Revisión de 30 puntos', 2);
SELECT fn_registrar_prueba(pruebas.labor_id(9007, 'Revisión general'), 202, '2026-11-07 12:20', 'Lista de verificación', 'Favorable', 'Sin observaciones críticas');
SELECT fn_completar_labor(pruebas.labor_id(9007, 'Revisión general'), 202, '2026-11-07 12:25');
SELECT fn_cambiar_estado_orden(9007, 'Lista entrega', 204, NULL, '2026-11-07 12:30');

-- ===========================================================
-- ID: G02-INT-16   Relación: entrega   Categoría: contexto / temporalidad / estado (RN-20, D2)
-- ===========================================================
SELECT pruebas.esperar_rechazo('G02-INT-16', 'RN-20', 'entregar una orden que no está Lista entrega',
     $q$ INSERT INTO entrega (orden_id, retira_cliente_id, entregado_por_id, fecha_hora, kilometraje_salida, revision_final, conformidad)
         VALUES (9014, 106, 201, '2026-11-09 10:00', 54010, 'Revisión', 'Conforme') $q$,
     'no está Lista entrega');
SELECT pruebas.esperar_rechazo('G02-INT-16', 'RN-20', 'retira una persona sin facultad Retirar',
     $q$ INSERT INTO entrega (orden_id, retira_cliente_id, entregado_por_id, fecha_hora, kilometraje_salida, revision_final, conformidad)
         VALUES (9007, 108, 201, '2026-11-07 17:30', 30015, 'Revisión final', 'Conforme') $q$,
     'el cliente 108 no tiene facultad vigente para retirar');
SELECT pruebas.esperar_rechazo('G02-INT-16', 'RN-20', 'retira con la facultad Aprobar (no Retirar)',
     $q$ INSERT INTO entrega (orden_id, retira_cliente_id, facultad_id, entregado_por_id, fecha_hora, kilometraje_salida, revision_final, conformidad)
         SELECT 9007, 107, facultad_id, 201, '2026-11-07 17:30', 30015, 'Revisión final', 'Conforme'
         FROM facultad_orden WHERE orden_id = 9007 AND tipo_facultad = 'Aprobar' $q$,
     'no tiene facultad vigente para retirar');
SELECT pruebas.esperar_rechazo('G02-INT-16', 'RN-20', 'kilometraje de salida menor que el de ingreso',
     $q$ INSERT INTO entrega (orden_id, retira_cliente_id, entregado_por_id, fecha_hora, kilometraje_salida, revision_final, conformidad)
         VALUES (9007, 107, 201, '2026-11-07 17:30', 29990, 'Revisión final', 'Conforme') $q$,
     'menor que el de ingreso');
SELECT pruebas.esperar_rechazo('G02-INT-16', 'RN-20', 'entrega anterior a la recepción',
     $q$ INSERT INTO entrega (orden_id, retira_cliente_id, entregado_por_id, fecha_hora, kilometraje_salida, revision_final, conformidad)
         VALUES (9007, 107, 201, '2026-11-06 17:30', 30015, 'Revisión final', 'Conforme') $q$,
     'no tiene facultad vigente para retirar');
SELECT pruebas.esperar_rechazo('G02-INT-16', 'RN-20', 'inconforme sin observaciones',
     $q$ INSERT INTO entrega (orden_id, retira_cliente_id, entregado_por_id, fecha_hora, kilometraje_salida, revision_final, conformidad)
         VALUES (9007, 107, 201, '2026-11-07 17:30', 30015, 'Revisión final', 'Inconforme') $q$,
     'ck_entrega_inconformidad');
-- Válido: Laura (titular, facultad Retirar) retira el vehículo.
INSERT INTO entrega (orden_id, retira_cliente_id, entregado_por_id, fecha_hora, kilometraje_salida, revision_final,
                     recomendaciones_futuras, conformidad)
VALUES (9007, 107, 201, '2026-11-07 17:30', 30015, 'Filtro nuevo y revisión de 30 puntos sin hallazgos críticos',
        'Revisar llantas en 5 000 km', 'Conforme');
SELECT pruebas.esperar_rechazo('G02-INT-16', 'RN-20', 'segunda entrega de la misma orden',
     $q$ INSERT INTO entrega (orden_id, retira_cliente_id, entregado_por_id, fecha_hora, kilometraje_salida, revision_final, conformidad)
         VALUES (9007, 107, 201, '2026-11-07 18:00', 30015, 'Otra', 'Conforme') $q$,
     'uq_entrega_orden');
SELECT fn_cambiar_estado_orden(9007, 'Entregada', 201, NULL, '2026-11-07 17:35');
SELECT e.entrega_id, e.orden_id, c.nombre_razon_social AS retira, f.tipo_facultad, f.fuente, e.kilometraje_salida, e.conformidad
FROM entrega e JOIN cliente c ON c.cliente_id = e.retira_cliente_id JOIN facultad_orden f ON f.facultad_id = e.facultad_id;
SELECT pruebas.verificar('G02-INT-16', 'RN-20', 'entrega válida con facultad Retirar y orden Entregada',
     (SELECT f.tipo_facultad = 'Retirar' AND o.estado_actual = 'Entregada'
      FROM entrega e JOIN facultad_orden f USING (facultad_id) JOIN orden_trabajo o ON o.orden_id = e.orden_id WHERE e.orden_id = 9007),
     'facultad Retirar; orden Entregada',
     (SELECT 'facultad ' || f.tipo_facultad || '; orden ' || o.estado_actual
      FROM entrega e JOIN facultad_orden f USING (facultad_id) JOIN orden_trabajo o ON o.orden_id = e.orden_id WHERE e.orden_id = 9007));

-- ===========================================================
-- ID: G02-INT-17   Relación: garantia   Categoría: contexto / estado (D3)
-- ===========================================================
INSERT INTO garantia (entrega_id, orden_id, labor_id, dias, km, condiciones)
SELECT e.entrega_id, 9007, pruebas.labor_id(9007, 'Cambio de filtro'), 30, 1000, 'Defectos del filtro instalado'
FROM entrega e WHERE e.orden_id = 9007;
INSERT INTO garantia (entrega_id, orden_id, labor_id, dias, km, condiciones)
SELECT e.entrega_id, 9007, pruebas.labor_id(9007, 'Revisión general'), 5, 5000, 'Diagnóstico de la revisión'
FROM entrega e WHERE e.orden_id = 9007;
SELECT pruebas.esperar_rechazo('G02-INT-17', 'RN-22', 'garantía sobre una labor no completada',
     $q$ INSERT INTO garantia (entrega_id, orden_id, labor_id, dias)
         SELECT e.entrega_id, 9007, pruebas.labor_id(9007, 'Lavado'), 30 FROM entrega e WHERE e.orden_id = 9007 $q$,
     'solo se otorga garantía sobre labores Completadas');
SELECT pruebas.esperar_rechazo('G02-INT-17', 'RN-22', 'garantía sobre una labor de otra orden',
     $q$ INSERT INTO garantia (entrega_id, orden_id, labor_id, dias)
         SELECT e.entrega_id, 9007, pruebas.labor_id(9003, 'Cambio de pastillas'), 30 FROM entrega e WHERE e.orden_id = 9007 $q$,
     'fk_garantia_labor');
SELECT pruebas.esperar_rechazo('G02-INT-17', 'RN-22', 'garantía sin ningún límite',
     $q$ INSERT INTO garantia (entrega_id, orden_id, labor_id)
         SELECT e.entrega_id, 9007, pruebas.labor_id(9007, 'Revisión general') FROM entrega e WHERE e.orden_id = 9007 $q$,
     'ck_garantia_limite');

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
INSERT INTO orden_trabajo (orden_id, vin, cliente_factura_id, entregado_por_cliente_id, autorizador_cliente_id, receptor_id,
                           fecha_hora_recepcion, kilometraje_ingreso, nivel_combustible, motivo_informado)
VALUES (9010, '5YJ3E1EA7KF000001', 107, 107, 107, 201, '2026-11-15 09:00', 31600, 'Lleno', 'Ruido en ventilación (reclamo de garantía)');
INSERT INTO historial_orden (orden_id, estado, fecha_hora, personal_id) VALUES (9010, 'Recibida', '2026-11-15 09:00', 201);
COMMIT;

SELECT pruebas.esperar_rechazo('G02-INT-18', 'RN-22', 'aceptar un reclamo fuera del límite de km (vence lo primero)',
     $q$ INSERT INTO reclamo_garantia (garantia_id, orden_nueva_id, fecha_reclamo, evaluacion, decision, justificacion, evaluado_por_id)
         SELECT g.garantia_id, 9010, '2026-11-15 09:30', 'Ruido por filtro mal asentado', 'Aceptada', 'Cubre', 205
         FROM garantia g WHERE g.labor_id = pruebas.labor_id(9007, 'Cambio de filtro') $q$,
     'dentro del límite de km: no');
SELECT pruebas.esperar_rechazo('G02-INT-18', 'RN-22', 'rechazar sin justificación',
     $q$ INSERT INTO reclamo_garantia (garantia_id, orden_nueva_id, fecha_reclamo, evaluacion, decision, evaluado_por_id)
         SELECT g.garantia_id, 9010, '2026-11-15 09:30', 'Fuera de km', 'Rechazada', 205
         FROM garantia g WHERE g.labor_id = pruebas.labor_id(9007, 'Cambio de filtro') $q$,
     'ck_reclamo_justificacion');
SELECT pruebas.esperar_rechazo('G02-INT-18', 'RN-21', 'kilometraje del reclamo distinto al de ingreso de la orden nueva',
     $q$ INSERT INTO reclamo_garantia (garantia_id, orden_nueva_id, fecha_reclamo, km_reclamo, evaluacion, decision, justificacion, evaluado_por_id)
         SELECT g.garantia_id, 9010, '2026-11-15 09:30', 30500, 'Km maquillado', 'Aceptada', 'Cubre', 205
         FROM garantia g WHERE g.labor_id = pruebas.labor_id(9007, 'Cambio de filtro') $q$,
     'debe ser el de ingreso de la orden nueva');
-- Válido: fuera de límite se registra como Rechazada con justificación.
INSERT INTO reclamo_garantia (garantia_id, orden_nueva_id, fecha_reclamo, evaluacion, decision, justificacion, evaluado_por_id)
SELECT g.garantia_id, 9010, '2026-11-15 09:30', 'Ruido por filtro mal asentado', 'Rechazada',
       'Se superó el límite de 1 000 km de la garantía (1 585 km recorridos desde la entrega)', 205
FROM garantia g WHERE g.labor_id = pruebas.labor_id(9007, 'Cambio de filtro');
SELECT fn_cambiar_estado_orden(9010, 'Cancelada', 201, 'Reclamo rechazado; la clienta retira el vehículo sin reparación', '2026-11-15 10:00');

BEGIN;
INSERT INTO orden_trabajo (orden_id, vin, cliente_factura_id, entregado_por_cliente_id, autorizador_cliente_id, receptor_id,
                           fecha_hora_recepcion, kilometraje_ingreso, nivel_combustible, motivo_informado)
VALUES (9008, '5YJ3E1EA7KF000001', 107, 107, 107, 201, '2026-11-18 10:00', 30215, 'Lleno', 'Olor en la ventilación (reclamo de garantía)'),
       (9009, 'WVWZZZ1JZXW000001', 102, 102, 102, 201, '2026-11-18 11:00', 88000, '1/2', 'Ruido en ventilación');
INSERT INTO historial_orden (orden_id, estado, fecha_hora, personal_id)
VALUES (9008, 'Recibida', '2026-11-18 10:00', 201), (9009, 'Recibida', '2026-11-18 11:00', 201);
COMMIT;

SELECT pruebas.esperar_rechazo('G02-INT-18', 'RN-22', 'aceptar un reclamo fuera del límite de días (vence lo primero)',
     $q$ INSERT INTO reclamo_garantia (garantia_id, orden_nueva_id, fecha_reclamo, evaluacion, decision, justificacion, evaluado_por_id)
         SELECT g.garantia_id, 9008, '2026-11-18 10:30', 'Falla no detectada en la revisión', 'Aceptada', 'Cubre', 205
         FROM garantia g WHERE g.labor_id = pruebas.labor_id(9007, 'Revisión general') $q$,
     'dentro del plazo de días: no');
SELECT pruebas.esperar_rechazo('G02-INT-18', 'RN-21', 'reclamo con orden de OTRO vehículo',
     $q$ INSERT INTO reclamo_garantia (garantia_id, orden_nueva_id, fecha_reclamo, evaluacion, decision, evaluado_por_id)
         SELECT g.garantia_id, 9009, '2026-11-18 11:30', 'Otro vehículo', 'Pendiente', 205
         FROM garantia g WHERE g.labor_id = pruebas.labor_id(9007, 'Cambio de filtro') $q$,
     'no del vehículo garantizado');
SELECT pruebas.esperar_rechazo('G02-INT-18', 'RN-21', 'reclamo sobre la misma orden garantizada',
     $q$ INSERT INTO reclamo_garantia (garantia_id, orden_nueva_id, fecha_reclamo, evaluacion, decision, evaluado_por_id)
         SELECT g.garantia_id, 9007, '2026-11-18 11:30', 'Misma orden', 'Pendiente', 205
         FROM garantia g WHERE g.labor_id = pruebas.labor_id(9007, 'Cambio de filtro') $q$,
     'debe abrir una orden nueva');
-- Válido: dentro de AMBOS límites de G1 (11 días < 30 y 200 km < 1 000).
INSERT INTO reclamo_garantia (garantia_id, orden_nueva_id, fecha_reclamo, evaluacion, decision, justificacion, evaluado_por_id)
SELECT g.garantia_id, 9008, '2026-11-18 10:30', 'Filtro con defecto de fábrica', 'Aceptada',
       'Dentro de 30 días y 1 000 km desde la entrega', 205
FROM garantia g WHERE g.labor_id = pruebas.labor_id(9007, 'Cambio de filtro');
SELECT pruebas.esperar_rechazo('G02-INT-18', 'RN-21', 'segundo reclamo con la misma orden nueva',
     $q$ INSERT INTO reclamo_garantia (garantia_id, orden_nueva_id, fecha_reclamo, evaluacion, decision, justificacion, evaluado_por_id)
         SELECT g.garantia_id, 9008, '2026-11-18 10:40', 'Duplicado', 'Rechazada', 'Duplicado', 205
         FROM garantia g WHERE g.labor_id = pruebas.labor_id(9007, 'Cambio de filtro') $q$,
     'uq_reclamo_orden_nueva');
SELECT pruebas.esperar_rechazo('G02-INT-18', 'RN-21', 'reevaluar un reclamo ya decidido',
     $q$ UPDATE reclamo_garantia SET decision = 'Rechazada' WHERE orden_nueva_id = 9008 $q$,
     'solo se reevalúa mientras está Pendiente');

SELECT g.garantia_id, l.descripcion AS labor, g.dias, g.km, r.orden_nueva_id, r.fecha_reclamo, r.km_reclamo, r.decision, r.justificacion
FROM garantia g JOIN labor l ON l.labor_id = g.labor_id LEFT JOIN reclamo_garantia r ON r.garantia_id = g.garantia_id
ORDER BY g.garantia_id, r.reclamo_id;
SELECT pruebas.verificar('G02-INT-18', 'RN-22', 'garantía sin reclamo existe; G1 con un reclamo rechazado y uno aceptado',
     (SELECT count(*) = 0 FROM reclamo_garantia r JOIN garantia g USING (garantia_id) WHERE g.labor_id = pruebas.labor_id(9007, 'Revisión general'))
     AND (SELECT string_agg(r.decision, ',' ORDER BY r.reclamo_id) = 'Rechazada,Aceptada'
          FROM reclamo_garantia r JOIN garantia g USING (garantia_id) WHERE g.labor_id = pruebas.labor_id(9007, 'Cambio de filtro')),
     'G2 sin reclamos; G1: Rechazada, Aceptada',
     'G2 ' || (SELECT count(*) FROM reclamo_garantia r JOIN garantia g USING (garantia_id) WHERE g.labor_id = pruebas.labor_id(9007, 'Revisión general'))
     || ' reclamos; G1: ' || (SELECT string_agg(r.decision, ',' ORDER BY r.reclamo_id)
          FROM reclamo_garantia r JOIN garantia g USING (garantia_id) WHERE g.labor_id = pruebas.labor_id(9007, 'Cambio de filtro')));

-- #####################################################################
-- E. HISTORIA (estados y promesas): cubierta por P03 — ver 30..33.
-- F. CONSULTAS REUTILIZADAS DEL LAB03 (rótulos corregidos, D5)
-- #####################################################################
SELECT * FROM v_q01_ordenes_pendientes_atencion;
SELECT * FROM v_q02_visitas_por_vehiculo;      -- Q02: VISITAS POR VEHÍCULO
SELECT * FROM v_q03_hallazgos_alta_urgencia;
SELECT * FROM v_q04_conteo_ordenes_por_estado; -- Q04: CONTEO DE ÓRDENES POR ESTADO
SELECT fn_total_ordenes_cliente(101) AS visitas_facturadas_a_maria, fn_prioridad_orden(9004) AS prioridad_9004;
SELECT pruebas.verificar('G02-INT-19', 'D5', 'Q04 cuenta las órdenes por estado y coincide con estado_actual',
     (SELECT sum(cantidad_ordenes) = (SELECT count(*) FROM orden_trabajo) FROM v_q04_conteo_ordenes_por_estado)
     AND NOT EXISTS (SELECT estado, cantidad_ordenes FROM v_q04_conteo_ordenes_por_estado
                     EXCEPT SELECT estado_actual, count(*) FROM orden_trabajo GROUP BY estado_actual),
     'Q04 = conteo por estado_actual',
     (SELECT string_agg(estado || ':' || cantidad_ordenes, ', ' ORDER BY estado) FROM v_q04_conteo_ordenes_por_estado));
SELECT pruebas.verificar('G02-INT-19', 'D5', 'Q02 cuenta visitas por vehículo (el Tesla tiene 3: 9007, 9008, 9010)',
     (SELECT total_visitas = 3 FROM v_q02_visitas_por_vehiculo WHERE placa = 'STU901'),
     'STU901: 3 visitas', (SELECT placa || ': ' || total_visitas || ' visitas' FROM v_q02_visitas_por_vehiculo WHERE placa = 'STU901'));

-- Coherencia global al final de toda la batería.
SELECT pruebas.verificar('G02-INT-20', 'D4', 'todas las órdenes: valor actual = última fila de cada historial',
     NOT EXISTS (
        SELECT 1 FROM orden_trabajo o
        WHERE o.estado_actual IS DISTINCT FROM (SELECT estado FROM historial_orden h WHERE h.orden_id = o.orden_id ORDER BY secuencia DESC LIMIT 1)
           OR o.fecha_prometida_actual IS DISTINCT FROM (SELECT fecha_nueva FROM historial_fecha_prometida f WHERE f.orden_id = o.orden_id ORDER BY secuencia DESC LIMIT 1)),
     '0 órdenes incoherentes', (SELECT count(*) || ' órdenes revisadas' FROM orden_trabajo));
SELECT pruebas.verificar('G02-INT-20', 'D9', 'todas las labores: estado = última fila de su historial',
     NOT EXISTS (SELECT 1 FROM labor l
                 WHERE l.estado_labor IS DISTINCT FROM (SELECT estado_nuevo FROM historial_labor h WHERE h.labor_id = l.labor_id ORDER BY secuencia DESC LIMIT 1)),
     '0 labores incoherentes', (SELECT count(*) || ' labores revisadas' FROM labor));
