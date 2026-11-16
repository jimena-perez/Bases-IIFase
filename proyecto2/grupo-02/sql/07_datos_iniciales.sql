-- =====================================================================
-- IC-4301 Bases de Datos I · Proyecto (2.ª entrega) · Grupo 02
-- Caso: Taller Ruta 27
-- Archivo: 07_datos_iniciales.sql
-- Propósito: datos FICTICIOS de PREPARACIÓN (catálogos, clientes,
-- vehículos, personal, inventario, órdenes recién recibidas y hallazgos).
--
-- NO contiene resultados de los procesos asignados: no hay propuestas,
-- decisiones, labores, participaciones, pruebas, consumos ni cambios de
-- estado o de promesa. Todo eso lo producen las rutinas en pruebas/.
-- Las órdenes quedan en 'Recibida' (alta), igual que con el alta del Lab03.
--
-- Contextos válidos diferenciados (para probar pertenencia, no solo
-- inexistencia):
--   * 9001 (María, titular) y 9002 (Transportes, titular; Ana designada):
--     dos órdenes con clientes facultados distintos.
--   * 9003 (Carlos) con reserva de repuesto; 9004 (Mensajería; Jorge
--     designado) con hallazgo crítico para emergencia.
--   * 9005 / 9006 (Ana) para estados y promesas; 9006 con un daño sin
--     confirmar.
--   * 9007 (Laura) para entrega y garantía.
--   * 9011 / 9012 / 9013 reservadas para las pruebas de concurrencia.
--   * Técnicos con especialidades distintas, un técnico inactivo y personal
--     que existe pero no es técnico.
-- IDs fijos y conocidos; luego se ajustan las secuencias IDENTITY.
-- =====================================================================

SET search_path = taller, public;
SET TIME ZONE 'America/Costa_Rica';

BEGIN;

-- ---------------------------------------------------------------------
-- 1. Clientes (5 del Lab03 + 3 nuevos) y contactos (RN-03)
-- ---------------------------------------------------------------------
INSERT INTO cliente (cliente_id, identificacion, nombre_razon_social, tipo_cliente) VALUES
 (101, 'FICT-P001', 'María Rojas',                'Persona'),
 (102, 'FICT-P002', 'Carlos Méndez',              'Persona'),
 (103, 'FICT-O003', 'Transportes del Valle S.A.', 'Organización'),
 (104, 'FICT-P004', 'Ana Solís',                  'Persona'),
 (105, 'FICT-O005', 'Mensajería Central S.A.',    'Organización'),
 (106, 'FICT-P006', 'Jorge Quesada',              'Persona'),
 (107, 'FICT-P007', 'Laura Jiménez',              'Persona'),
 (108, 'FICT-P008', 'Pedro Alvarado',             'Persona');

INSERT INTO contacto_cliente (contacto_id, cliente_id, tipo_contacto, valor_contacto, recibe_avisos) VALUES
 (1, 101, 'Teléfono', '+50688880101',           true),
 (2, 101, 'Correo',   'maria.rojas@ejemplo.test', false),
 (3, 102, 'Correo',   'carlos.mendez@ejemplo.test', true),
 (4, 103, 'Teléfono', '+50622220103',           true),
 (5, 103, 'Correo',   'flota@transvalle.test',  true),
 (6, 104, 'Teléfono', '+50688880104',           true),
 (7, 105, 'Correo',   'taller@mensajeria.test', true),
 (8, 106, 'Teléfono', '+50688880106',           true),
 (9, 107, 'Correo',   'laura.jimenez@ejemplo.test', true),
 (10, 108, 'Teléfono', '+50688880108',          true);

-- ---------------------------------------------------------------------
-- 2. Vehículos (4 del Lab03 + 8 nuevos) y propiedad con vigencias (D12)
-- ---------------------------------------------------------------------
INSERT INTO vehiculo (vin, placa, marca, modelo, anio, tipo_combustible) VALUES
 ('1HGCM82633A123456', 'ABC123', 'Honda',      'Accord',  2018, 'Gasolina'),
 ('3VWFE21C04M000001', 'DEF456', 'Volkswagen', 'Jetta',   2020, 'Gasolina'),
 ('1FTFW1ET1EFA00001', 'GHI789', 'Ford',       'F-150',   2022, 'Diésel'),
 ('2T1BURHE5JC000001', 'JKL012', 'Toyota',     'Corolla', 2021, 'Híbrido'),
 ('JN1AZ4EH7DM000001', 'MNO345', 'Nissan',     'Leaf',    2023, 'Eléctrico'),
 ('KMHCT41DAEU000001', 'PQR678', 'Hyundai',    'Accent',  2019, 'Gasolina'),
 ('5YJ3E1EA7KF000001', 'STU901', 'Tesla',      'Model 3', 2019, 'Eléctrico'),
 ('WVWZZZ1JZXW000001', 'VWX234', 'Volkswagen', 'Golf',    2017, 'Gasolina'),
 ('1N4AL3AP8JC000001', 'YZA567', 'Nissan',     'Altima',  2018, 'Gasolina'),
 ('3FADP4BJ7FM000001', 'BCD890', 'Ford',       'Fiesta',  2015, 'Gasolina'),
 ('JTDKB20U793000001', 'EFG123', 'Toyota',     'Prius',   2009, 'Híbrido'),
 ('1G1ZD5ST0JF000001', 'HIJ456', 'Chevrolet',  'Malibu',  2018, 'Gasolina');

INSERT INTO propiedad_vehiculo (propiedad_id, vin, cliente_id, desde, hasta) VALUES
 (1,  '1HGCM82633A123456', 101, '2018-03-01', NULL),
 (2,  '3VWFE21C04M000001', 102, '2020-06-15', NULL),
 (3,  '1FTFW1ET1EFA00001', 103, '2022-01-10', NULL),
 (4,  '2T1BURHE5JC000001', 105, '2021-02-01', NULL),
 (5,  'JN1AZ4EH7DM000001', 104, '2023-05-20', NULL),
 (6,  'KMHCT41DAEU000001', 104, '2019-08-01', NULL),
 (7,  '5YJ3E1EA7KF000001', 107, '2024-04-01', NULL),
 (8,  'WVWZZZ1JZXW000001', 102, '2017-09-01', NULL),
 (9,  '1N4AL3AP8JC000001', 101, '2018-11-01', NULL),
 (10, '3FADP4BJ7FM000001', 102, '2015-07-01', NULL),
 (11, 'JTDKB20U793000001', 104, '2012-01-01', NULL),
 (12, '1G1ZD5ST0JF000001', 106, '2019-01-01', NULL);

-- ---------------------------------------------------------------------
-- 3. Personal (3 del Lab03 + 4 nuevos) y especialidades con vigencia
-- ---------------------------------------------------------------------
INSERT INTO personal (personal_id, nombre, rol, activo) VALUES
 (201, 'Lucía Vargas',  'Recepción', true),
 (202, 'Diego Mora',    'Técnico',   true),
 (203, 'Sofía Arias',   'Técnico',   true),
 (204, 'Andrés Castro', 'Técnico',   true),
 (205, 'Marta León',    'Otro',      true),   -- jefa de taller
 (206, 'Pablo Núñez',   'Recepción', true),
 (207, 'Elena Brenes',  'Técnico',   false);  -- técnica inactiva

INSERT INTO especialidad_tecnico (especialidad_id, tecnico_id, especialidad, fecha_inicio, fecha_fin) VALUES
 (1, 202, 'Frenos',           '2020-01-01', NULL),
 (2, 202, 'Mecánica general', '2021-03-01', NULL),
 (3, 203, 'Electricidad',     '2019-07-01', NULL),
 (4, 204, 'Mecánica general', '2022-02-01', NULL),
 (5, 204, 'Frenos',           '2023-01-01', '2025-12-31'),  -- vencida
 (6, 207, 'Frenos',           '2018-01-01', NULL);

-- ---------------------------------------------------------------------
-- 4. Repuestos, proveedores y códigos de proveedor (RN-17)
-- ---------------------------------------------------------------------
INSERT INTO repuesto (repuesto_id, descripcion, marca, unidad_manejo) VALUES
 ('FR-001', 'Pastillas de freno delanteras', 'Bosch',   'Juego'),
 ('FR-002', 'Líquido de frenos DOT 4',       'Castrol', 'Litro'),
 ('FR-003', 'Disco de freno delantero',      'Brembo',  'Unidad'),
 ('EL-001', 'Sensor de oxígeno',             'Denso',   'Unidad'),
 ('EL-002', 'Batería 12 V auxiliar',         'Varta',   'Unidad'),
 ('MG-001', 'Filtro de aire',                'Mann',    'Unidad'),
 ('MG-002', 'Aceite de motor 5W-30',         'Mobil',   'Litro'),
 ('LP-001', 'Escobillas limpiaparabrisas',   'Bosch',   'Juego');

INSERT INTO proveedor (proveedor_id, nombre, identificacion) VALUES
 (1, 'Repuestos La Uruca S.A.',     'FICT-J-3101-001'),
 (2, 'Distribuidora Frenos CR',     'FICT-J-3101-002'),
 (3, 'ElectroAuto del Este',        NULL);

INSERT INTO proveedor_repuesto (proveedor_repuesto_id, proveedor_id, repuesto_id, codigo_proveedor, precio_referencia) VALUES
 (1, 2, 'FR-001', 'BOS-0986-494', 24000.00),
 (2, 1, 'FR-001', 'URU-PF-118',   25500.00),
 (3, 2, 'FR-002', 'CAS-DOT4-1L',   6500.00),
 (4, 2, 'FR-003', 'BRE-09-A',     38000.00),
 (5, 3, 'EL-001', 'DEN-234-4209', 41000.00),
 (6, 3, 'EL-002', 'VAR-12V-AUX',  52000.00),
 (7, 1, 'MG-001', 'URU-FA-220',    9000.00),
 (8, 1, 'MG-002', 'URU-AC-5W30',   7200.00),
 (9, 1, 'LP-001', 'URU-ESC-24',    8500.00);

-- Entradas de inventario (existencias físicas iniciales). EL-002 sin
-- existencias a propósito; FR-003 con una sola unidad (concurrencia).
INSERT INTO movimiento_inventario (repuesto_id, orden_id, tipo_movimiento, cantidad, fecha_hora, registrado_por_id, motivo) VALUES
 ('FR-001', NULL, 'Entrada', 10, '2026-11-01 07:00', 205, 'Inventario inicial'),
 ('FR-002', NULL, 'Entrada',  8, '2026-11-01 07:00', 205, 'Inventario inicial'),
 ('FR-003', NULL, 'Entrada',  1, '2026-11-01 07:00', 205, 'Inventario inicial'),
 ('EL-001', NULL, 'Entrada',  3, '2026-11-01 07:00', 205, 'Inventario inicial'),
 ('MG-001', NULL, 'Entrada',  6, '2026-11-01 07:00', 205, 'Inventario inicial'),
 ('MG-002', NULL, 'Entrada', 20, '2026-11-01 07:00', 205, 'Inventario inicial'),
 ('LP-001', NULL, 'Entrada',  5, '2026-11-01 07:00', 205, 'Inventario inicial');

-- ---------------------------------------------------------------------
-- 5. Órdenes recién recibidas (alta) + su estado inicial 'Recibida'.
--    Los triggers crean las facultades de la visita y la promesa original.
-- ---------------------------------------------------------------------
INSERT INTO orden_trabajo (orden_id, vin, cliente_factura_id, entregado_por_cliente_id, autorizador_cliente_id,
                           receptor_id, fecha_hora_recepcion, kilometraje_ingreso, nivel_combustible,
                           motivo_informado, observaciones_visibles, fecha_prometida_actual) VALUES
 (9001, '1HGCM82633A123456', 101, 101, 101, 201, '2026-11-02 08:15', 85000, '1/2',
        'Ruido al frenar y escobillas gastadas', 'Rayón leve en puerta', '2026-11-06 16:00'),
 (9002, '1FTFW1ET1EFA00001', 103, 104, 104, 201, '2026-11-03 09:10', 99000, 'Lleno',
        'Mantenimiento preventivo de flota', NULL, '2026-11-05 15:00'),
 (9003, '3VWFE21C04M000001', 102, 102, 102, 206, '2026-11-04 08:00', 42000, '3/4',
        'Chirrido en frenos y testigo de motor encendido', NULL, '2026-11-07 17:00'),
 (9004, '2T1BURHE5JC000001', 105, 106, 106, 201, '2026-11-05 07:30', 23000, '1/4',
        'El pedal de freno se hunde', 'Ingresa en grúa', NULL),
 (9005, 'JN1AZ4EH7DM000001', 104, 104, 104, 206, '2026-11-06 10:00', 15000, 'Lleno',
        'No enciende por las mañanas', NULL, '2026-11-10 17:00'),
 (9006, 'KMHCT41DAEU000001', 104, 104, 104, 206, '2026-11-06 11:00', 60000, '1/2',
        'Revisión de suspensión', 'Abolladura en puerta trasera', '2026-11-09 12:00'),
 (9007, '5YJ3E1EA7KF000001', 107, 107, 107, 201, '2026-11-07 08:00', 30000, 'Lleno',
        'Cambio de filtro y revisión general', NULL, '2026-11-07 17:00'),
 (9011, '1N4AL3AP8JC000001', 101, 101, 101, 201, '2026-11-08 08:00', 70000, '1/2',
        'Revisión de frenos (concurrencia P01)', NULL, NULL),
 (9012, '3FADP4BJ7FM000001', 102, 102, 102, 201, '2026-11-08 08:30', 120000, '1/4',
        'Cambio de discos (concurrencia P02)', NULL, NULL),
 (9013, 'JTDKB20U793000001', 104, 104, 104, 201, '2026-11-08 09:00', 210000, '3/4',
        'Revisión híbrida (concurrencia P03)', NULL, '2026-11-12 17:00');

INSERT INTO historial_orden (orden_id, estado, fecha_hora, personal_id) VALUES
 (9001, 'Recibida', '2026-11-02 08:15', 201),
 (9002, 'Recibida', '2026-11-03 09:10', 201),
 (9003, 'Recibida', '2026-11-04 08:00', 206),
 (9004, 'Recibida', '2026-11-05 07:30', 201),
 (9005, 'Recibida', '2026-11-06 10:00', 206),
 (9006, 'Recibida', '2026-11-06 11:00', 206),
 (9007, 'Recibida', '2026-11-07 08:00', 201),
 (9011, 'Recibida', '2026-11-08 08:00', 201),
 (9012, 'Recibida', '2026-11-08 08:30', 201),
 (9013, 'Recibida', '2026-11-08 09:00', 201);

-- Facultades adicionales verificadas en la recepción (D2):
--   Jorge Quesada (106) también puede RETIRAR el vehículo de Mensajería (9004).
INSERT INTO facultad_orden (orden_id, cliente_id, tipo_facultad, fuente, otorgada_por_cliente_id,
                            medio_verificacion, vigente_desde, registrada_por_id) VALUES
 (9004, 106, 'Retirar', 'Representación legal', 105,
  'Personería jurídica vigente presentada en la recepción', '2026-11-05 07:30', 201);

-- Objetos dejados y daños visibles (RN-06). 9006 tiene un daño SIN confirmar.
INSERT INTO objeto_dano (detalle_id, orden_id, tipo_detalle, descripcion, confirmado_cliente) VALUES
 (1, 9001, 'Daño',   'Rayón leve en puerta del conductor', true),
 (2, 9005, 'Objeto', 'Silla de bebé en el asiento trasero', true),
 (3, 9005, 'Daño',   'Rayón en parachoques trasero', true),
 (4, 9006, 'Daño',   'Abolladura en puerta trasera derecha', false);

-- ---------------------------------------------------------------------
-- 6. Hallazgos del diagnóstico (con autor técnico y momento, D1)
-- ---------------------------------------------------------------------
INSERT INTO hallazgo (hallazgo_id, orden_id, diagnosticado_por_id, fecha_hora, sintoma_comprobado,
                      posible_causa, urgencia, recomendacion) VALUES
 (4101, 9001, 202, '2026-11-02 09:00', 'Vibración y ruido al frenar', 'Pastillas desgastadas', 'Media',
        'Reemplazar pastillas delanteras'),
 (4102, 9001, 202, '2026-11-02 09:20', 'Escobillas dejan franjas', 'Uso normal', 'Baja',
        'Sustituir escobillas'),
 (4106, 9001, 204, '2026-11-02 09:40', 'Desgaste irregular de llantas delanteras', 'Desalineación', 'Baja',
        'Alinear y balancear'),
 (4107, 9001, 202, '2026-11-02 10:00', 'Líquido de frenos oscuro', 'Humedad en el sistema', 'Media',
        'Purgar y reemplazar líquido de frenos'),
 (4103, 9002, 204, '2026-11-03 10:00', 'Filtro de aire sucio', 'Intervalo de mantenimiento', 'Baja',
        'Cambiar filtro durante el servicio'),
 (4104, 9003, 202, '2026-11-04 09:00', 'Chirrido metálico al frenar', 'Pastillas al límite', 'Alta',
        'Cambiar pastillas y revisar discos'),
 (4105, 9003, 203, '2026-11-04 09:30', 'Testigo de motor por sensor de oxígeno', 'Sensor defectuoso', 'Media',
        'Sustituir sensor de oxígeno'),
 (4108, 9004, 202, '2026-11-05 08:00', 'Pedal de freno se hunde; fuga visible', 'Fuga en cilindro de rueda', 'Crítica',
        'No circular: reparar fuga del sistema de frenos'),
 (4109, 9004, 204, '2026-11-05 08:30', 'Ruido en suspensión delantera', 'Bujes gastados', 'Media',
        'Cambiar bujes de suspensión'),
 (4110, 9005, 203, '2026-11-06 11:00', 'Batería auxiliar de 12 V con baja carga', 'Batería al final de su vida útil', 'Alta',
        'Reemplazar batería auxiliar'),
 (4111, 9007, 204, '2026-11-07 09:00', 'Filtro de aire de cabina obstruido', 'Intervalo de mantenimiento', 'Baja',
        'Cambiar filtro'),
 (4112, 9011, 202, '2026-11-08 08:30', 'Pastillas al 20 %', 'Desgaste normal', 'Media',
        'Cambiar pastillas'),
 (4113, 9012, 202, '2026-11-08 09:00', 'Discos con surcos profundos', 'Desgaste', 'Alta',
        'Cambiar disco delantero'),
 (4114, 9013, 203, '2026-11-08 09:30', 'Ventilador de batería híbrida ruidoso', 'Suciedad', 'Media',
        'Limpiar ventilador');

-- Reserva de repuesto para la orden 9003 (preparación: el taller apartó un
-- juego de pastillas al diagnosticar). El consumo en P02 la liberará.
INSERT INTO movimiento_inventario (repuesto_id, orden_id, tipo_movimiento, cantidad, fecha_hora, registrado_por_id, motivo) VALUES
 ('FR-001', 9003, 'Reserva', 1, '2026-11-04 09:05', 205, 'Apartado tras el diagnóstico');

COMMIT;

-- ---------------------------------------------------------------------
-- 7. Ajuste de secuencias IDENTITY tras cargar IDs fijos
--    (las filas nuevas creadas por los procesos empiezan en rangos legibles)
-- ---------------------------------------------------------------------
SELECT setval(pg_get_serial_sequence('taller.cliente', 'cliente_id'), 900);
SELECT setval(pg_get_serial_sequence('taller.contacto_cliente', 'contacto_id'), 100);
SELECT setval(pg_get_serial_sequence('taller.propiedad_vehiculo', 'propiedad_id'), 100);
SELECT setval(pg_get_serial_sequence('taller.personal', 'personal_id'), 900);
SELECT setval(pg_get_serial_sequence('taller.especialidad_tecnico', 'especialidad_id'), 100);
SELECT setval(pg_get_serial_sequence('taller.proveedor', 'proveedor_id'), 100);
SELECT setval(pg_get_serial_sequence('taller.proveedor_repuesto', 'proveedor_repuesto_id'), 100);
SELECT setval(pg_get_serial_sequence('taller.orden_trabajo', 'orden_id'), 9900);
SELECT setval(pg_get_serial_sequence('taller.objeto_dano', 'detalle_id'), 100);
SELECT setval(pg_get_serial_sequence('taller.hallazgo', 'hallazgo_id'), 4900);
SELECT setval(pg_get_serial_sequence('taller.facultad_orden', 'facultad_id'), 700);
SELECT setval(pg_get_serial_sequence('taller.movimiento_inventario', 'movimiento_id'), 800);
SELECT setval(pg_get_serial_sequence('taller.propuesta', 'propuesta_id'), 300);
SELECT setval(pg_get_serial_sequence('taller.labor', 'labor_id'), 500);
SELECT setval(pg_get_serial_sequence('taller.autorizacion_labor', 'autorizacion_id'), 600);

-- Resumen de la preparación
SELECT 'cliente' AS tabla, count(*) FROM cliente
UNION ALL SELECT 'contacto_cliente', count(*) FROM contacto_cliente
UNION ALL SELECT 'vehiculo', count(*) FROM vehiculo
UNION ALL SELECT 'propiedad_vehiculo', count(*) FROM propiedad_vehiculo
UNION ALL SELECT 'personal', count(*) FROM personal
UNION ALL SELECT 'especialidad_tecnico', count(*) FROM especialidad_tecnico
UNION ALL SELECT 'repuesto', count(*) FROM repuesto
UNION ALL SELECT 'proveedor', count(*) FROM proveedor
UNION ALL SELECT 'proveedor_repuesto', count(*) FROM proveedor_repuesto
UNION ALL SELECT 'orden_trabajo', count(*) FROM orden_trabajo
UNION ALL SELECT 'facultad_orden', count(*) FROM facultad_orden
UNION ALL SELECT 'historial_orden', count(*) FROM historial_orden
UNION ALL SELECT 'historial_fecha_prometida', count(*) FROM historial_fecha_prometida
UNION ALL SELECT 'objeto_dano', count(*) FROM objeto_dano
UNION ALL SELECT 'hallazgo', count(*) FROM hallazgo
UNION ALL SELECT 'movimiento_inventario', count(*) FROM movimiento_inventario
UNION ALL SELECT 'propuesta (debe ser 0)', count(*) FROM propuesta
UNION ALL SELECT 'labor (debe ser 0)', count(*) FROM labor
UNION ALL SELECT 'autorizacion_labor (debe ser 0)', count(*) FROM autorizacion_labor;
