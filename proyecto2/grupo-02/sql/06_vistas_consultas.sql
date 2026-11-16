-- =====================================================================
-- IC-4301 Bases de Datos I · Proyecto (2.ª entrega) · Grupo 02
-- Caso: Taller Ruta 27
-- Archivo: 06_vistas_consultas.sql
-- Propósito: resultados observables de los procesos y consultas Q01–Q04
-- reutilizadas del Lab03 (con los rótulos de Q02 y Q04 corregidos, D5).
-- Las vistas de REGLA de P01 (v_situacion_labor, etc.) están en
-- 03_rutinas_p01.sql porque las usan los triggers.
-- =====================================================================

SET search_path = taller, public;

-- =====================================================================
-- 1. G02-P01 · Propuestas y decisiones
-- =====================================================================

-- Comparación de una misma labor entre versiones: precio, alcance y la
-- decisión registrada SOBRE ESA VERSIÓN (las versiones viejas quedan intactas).
CREATE VIEW v_comparacion_versiones AS
SELECT p.orden_id,
       lp.labor_id,
       l.descripcion                         AS labor,
       p.version,
       p.propuesta_id,
       p.propuesta_base_id,
       p.fecha_hora_presentacion,
       lp.precio_estimado,
       lp.alcance,
       coalesce(rp.total_repuestos, 0)       AS repuestos_estimados,
       coalesce(d.decision, 'Sin decidir')   AS decision_en_esta_version,
       c.nombre_razon_social                 AS decidido_por,
       d.medio,
       d.fecha_hora                          AS fecha_hora_decision,
       (vv.propuesta_id = p.propuesta_id)    AS es_version_vigente
FROM linea_propuesta lp
JOIN propuesta p ON p.propuesta_id = lp.propuesta_id AND p.estado = 'Presentada'
JOIN labor l ON l.labor_id = lp.labor_id
LEFT JOIN LATERAL (
    SELECT sum(r.cantidad_estimada * r.precio_unitario_estimado) AS total_repuestos
    FROM repuesto_propuesto r
    WHERE r.propuesta_id = lp.propuesta_id AND r.labor_id = lp.labor_id
) rp ON true
LEFT JOIN v_decision_linea d ON d.propuesta_id = lp.propuesta_id AND d.labor_id = lp.labor_id
LEFT JOIN cliente c ON c.cliente_id = d.cliente_id
LEFT JOIN v_version_vigente_labor vv ON vv.labor_id = lp.labor_id;

-- Facultades por visita y su vigencia.
CREATE VIEW v_facultades_orden AS
SELECT f.orden_id,
       f.facultad_id,
       f.cliente_id,
       c.nombre_razon_social AS cliente,
       f.tipo_facultad,
       f.fuente,
       f.otorgada_por_cliente_id,
       f.medio_verificacion,
       f.vigente_desde,
       f.vigente_hasta,
       (f.vigente_desde <= now() AND (f.vigente_hasta IS NULL OR now() < f.vigente_hasta)) AS vigente_ahora
FROM facultad_orden f
JOIN cliente c ON c.cliente_id = f.cliente_id;

-- =====================================================================
-- 2. G02-P02 · Ejecución
-- =====================================================================

CREATE VIEW v_historia_labor AS
SELECT l.orden_id,
       h.labor_id,
       l.descripcion AS labor,
       h.secuencia,
       h.estado_anterior,
       h.estado_nuevo,
       h.fecha_hora,
       p.nombre      AS registrado_por,
       h.autorizacion_id,
       h.emergencia_id,
       h.motivo
FROM historial_labor h
JOIN labor l ON l.labor_id = h.labor_id
JOIN personal p ON p.personal_id = h.personal_id;

CREATE VIEW v_participaciones AS
SELECT pt.orden_id,
       pt.labor_id,
       pt.participacion_id,
       pe.nombre                                                AS tecnico,
       et.especialidad,
       pt.inicio,
       pt.fin,
       floor(extract(epoch FROM (pt.fin - pt.inicio)) / 60)::int AS minutos_intervalo,
       pt.minutos_efectivos,
       pt.descripcion_participacion
FROM participacion_tecnica pt
JOIN personal pe ON pe.personal_id = pt.tecnico_id
LEFT JOIN especialidad_tecnico et ON et.especialidad_id = pt.especialidad_id;

CREATE VIEW v_pruebas AS
SELECT pr.orden_id,
       pr.labor_id,
       pr.prueba_id,
       pr.fecha_hora,
       pe.nombre AS realizada_por,
       pr.tipo_prueba,
       pr.resultado,
       pr.medicion_valor,
       pr.unidad,
       pr.descripcion_resultado
FROM prueba pr
JOIN personal pe ON pe.personal_id = pr.personal_id;

CREATE VIEW v_retrabajos AS
SELECT r.orden_id,
       r.labor_id           AS retrabajo_id,
       r.descripcion        AS retrabajo,
       r.estado_labor       AS estado_retrabajo,
       r.labor_revisada_id,
       o.descripcion        AS labor_revisada,
       o.estado_labor       AS estado_labor_revisada,
       r.prueba_origen_id,
       pr.resultado         AS resultado_prueba_origen,
       pr.descripcion_resultado AS hallazgo_prueba_origen
FROM labor r
JOIN labor o ON o.labor_id = r.labor_revisada_id
LEFT JOIN prueba pr ON pr.prueba_id = r.prueba_origen_id;

-- Propuesto (línea de la versión vigente) vs ejecutado (consumos y tiempos).
CREATE VIEW v_propuesto_vs_ejecutado AS
SELECT l.orden_id,
       l.labor_id,
       l.descripcion,
       l.estado_labor,
       vv.version                                AS version_vigente,
       vv.precio_estimado                        AS mano_obra_estimada,
       coalesce(est.repuestos_estimados, 0)      AS repuestos_estimados,
       coalesce(con.repuestos_consumidos, 0)     AS repuestos_consumidos,
       coalesce(par.minutos_efectivos, 0)        AS minutos_efectivos,
       coalesce(par.tecnicos, 0)                 AS tecnicos
FROM labor l
LEFT JOIN v_version_vigente_labor vv ON vv.labor_id = l.labor_id
LEFT JOIN LATERAL (
    SELECT sum(r.cantidad_estimada * r.precio_unitario_estimado) AS repuestos_estimados
    FROM repuesto_propuesto r WHERE r.propuesta_id = vv.propuesta_id AND r.labor_id = l.labor_id
) est ON true
LEFT JOIN LATERAL (
    SELECT sum(c.cantidad_utilizada * c.precio_unitario_cargado) AS repuestos_consumidos
    FROM consumo_repuesto c WHERE c.labor_id = l.labor_id
) con ON true
LEFT JOIN LATERAL (
    SELECT sum(p.minutos_efectivos) AS minutos_efectivos, count(DISTINCT p.tecnico_id) AS tecnicos
    FROM participacion_tecnica p WHERE p.labor_id = l.labor_id
) par ON true;

-- Existencias derivadas (RN-19): nunca se guardan, siempre se calculan.
CREATE VIEW v_existencias AS
SELECT r.repuesto_id,
       r.descripcion,
       r.unidad_manejo,
       coalesce(sum(CASE m.tipo_movimiento
                        WHEN 'Entrada' THEN m.cantidad
                        WHEN 'Ajuste positivo' THEN m.cantidad
                        WHEN 'Ajuste negativo' THEN -m.cantidad
                        WHEN 'Consumo' THEN -m.cantidad END), 0) AS fisico,
       coalesce(sum(CASE m.tipo_movimiento
                        WHEN 'Reserva' THEN m.cantidad
                        WHEN 'Liberación' THEN -m.cantidad END), 0) AS reservado,
       coalesce(sum(CASE m.tipo_movimiento
                        WHEN 'Entrada' THEN m.cantidad
                        WHEN 'Ajuste positivo' THEN m.cantidad
                        WHEN 'Ajuste negativo' THEN -m.cantidad
                        WHEN 'Consumo' THEN -m.cantidad
                        WHEN 'Reserva' THEN -m.cantidad
                        WHEN 'Liberación' THEN m.cantidad END), 0) AS disponible
FROM repuesto r
LEFT JOIN movimiento_inventario m ON m.repuesto_id = r.repuesto_id
GROUP BY r.repuesto_id, r.descripcion, r.unidad_manejo;

-- Distingue presupuesto / reserva / consumo / pieza retirada por orden.
CREATE VIEW v_insumos_orden AS
SELECT lp.orden_id, 'Presupuesto (v' || p.version || ')' AS concepto, rp.labor_id,
       rp.repuesto_id AS referencia, rp.cantidad_estimada AS cantidad, rp.precio_unitario_estimado AS precio_unitario
FROM repuesto_propuesto rp
JOIN linea_propuesta lp ON lp.propuesta_id = rp.propuesta_id AND lp.labor_id = rp.labor_id
JOIN propuesta p ON p.propuesta_id = rp.propuesta_id
UNION ALL
SELECT m.orden_id, 'Reserva', NULL, m.repuesto_id, m.cantidad, NULL
FROM movimiento_inventario m WHERE m.tipo_movimiento = 'Reserva'
UNION ALL
SELECT m.orden_id, 'Liberación de reserva', NULL, m.repuesto_id, m.cantidad, NULL
FROM movimiento_inventario m WHERE m.tipo_movimiento = 'Liberación'
UNION ALL
SELECT c.orden_id, 'Consumo', c.labor_id, c.repuesto_id, c.cantidad_utilizada, c.precio_unitario_cargado
FROM consumo_repuesto c
UNION ALL
SELECT pr.orden_id, 'Pieza retirada (' || pr.destino || ')', pr.labor_id, pr.descripcion, 1, NULL
FROM pieza_retirada pr;

-- =====================================================================
-- 3. G02-P03 · Estados y promesas (en vistas separadas, sin mezclarlos)
-- =====================================================================

CREATE VIEW v_estado_actual_orden AS
SELECT o.orden_id,
       o.vin,
       o.placa_ingreso,
       c.nombre_razon_social AS cliente_factura,
       o.estado_actual,
       h.fecha_hora          AS desde,
       pe.nombre             AS registrado_por,
       o.fecha_prometida_actual
FROM orden_trabajo o
JOIN cliente c ON c.cliente_id = o.cliente_factura_id
JOIN LATERAL (
    SELECT * FROM historial_orden x WHERE x.orden_id = o.orden_id ORDER BY x.secuencia DESC LIMIT 1
) h ON true
JOIN personal pe ON pe.personal_id = h.personal_id;

CREATE VIEW v_cronologia_estados AS
SELECT h.orden_id,
       h.secuencia,
       h.estado_anterior,
       h.estado      AS estado_nuevo,
       h.fecha_hora,
       pe.nombre     AS responsable,
       h.motivo
FROM historial_orden h
JOIN personal pe ON pe.personal_id = h.personal_id;

CREATE VIEW v_cronologia_promesas AS
SELECT f.orden_id,
       f.secuencia,
       f.fecha_anterior,
       f.fecha_nueva,
       f.fecha_hora_comunicacion,
       f.medio_comunicacion,
       f.motivo,
       pe.nombre     AS responsable,
       (f.secuencia = 1) AS es_promesa_original
FROM historial_fecha_prometida f
JOIN personal pe ON pe.personal_id = f.personal_id;

CREATE VIEW v_promesas AS
SELECT o.orden_id,
       orig.fecha_nueva                       AS promesa_original,
       o.fecha_prometida_actual               AS promesa_actual,
       coalesce(n.cambios, 0)                 AS reprogramaciones,
       ult.motivo                             AS ultimo_motivo
FROM orden_trabajo o
LEFT JOIN historial_fecha_prometida orig ON orig.orden_id = o.orden_id AND orig.secuencia = 1
LEFT JOIN LATERAL (
    SELECT count(*) - 1 AS cambios FROM historial_fecha_prometida x WHERE x.orden_id = o.orden_id
) n ON true
LEFT JOIN LATERAL (
    SELECT x.motivo FROM historial_fecha_prometida x
    WHERE x.orden_id = o.orden_id AND x.secuencia > 1 ORDER BY x.secuencia DESC LIMIT 1
) ult ON true;

-- Pendientes: reutiliza la idea de Q01 del Lab03 sobre el estado actual
-- (órdenes no terminales; pendientes de autorización o de entrega).
CREATE VIEW v_pendientes AS
SELECT o.orden_id,
       o.placa_ingreso,
       c.nombre_razon_social AS cliente,
       o.estado_actual,
       o.fecha_prometida_actual,
       CASE o.estado_actual
           WHEN 'Pendiente autorización' THEN 'Esperando decisión del cliente'
           WHEN 'Lista entrega' THEN 'Esperando retiro del vehículo'
           ELSE 'En atención'
       END AS pendiente_de,
       (o.fecha_prometida_actual IS NOT NULL AND o.fecha_prometida_actual < now()) AS promesa_vencida
FROM orden_trabajo o
JOIN cliente c ON c.cliente_id = o.cliente_factura_id
WHERE NOT fn_es_terminal(o.estado_actual);

-- =====================================================================
-- 4. CONSULTAS DEL LAB03 (lógica sin cambios; rótulos corregidos)
-- =====================================================================

-- Q01 · Órdenes pendientes de atención
-- Pregunta: ¿Qué vehículos están en diagnóstico o pendientes de autorización?
CREATE VIEW v_q01_ordenes_pendientes_atencion AS
WITH ultimo_estado AS (
    SELECT DISTINCT ON (orden_id)
        orden_id,
        estado,
        fecha_hora
    FROM historial_orden
    ORDER BY orden_id,
             fecha_hora DESC,
             historial_id DESC
)
SELECT
    o.orden_id,
    v.placa,
    c.nombre_razon_social AS cliente,
    u.estado,
    o.fecha_hora_recepcion
FROM orden_trabajo o
JOIN vehiculo v
    ON o.vin = v.vin
JOIN cliente c
    ON o.cliente_factura_id = c.cliente_id
JOIN ultimo_estado u
    ON o.orden_id = u.orden_id
WHERE u.estado IN (
    'En diagnóstico',
    'Pendiente autorización'
)
ORDER BY o.orden_id;

-- Q02 · VISITAS POR VEHÍCULO (rótulo corregido, D5)
-- Pregunta: ¿Cuántas veces ha ingresado cada vehículo al taller?
CREATE VIEW v_q02_visitas_por_vehiculo AS
SELECT
    v.placa,
    v.marca,
    v.modelo,
    COUNT(o.orden_id) AS total_visitas
FROM vehiculo v
LEFT JOIN orden_trabajo o
    ON v.vin = o.vin
GROUP BY
    v.vin,
    v.placa,
    v.marca,
    v.modelo
ORDER BY total_visitas DESC, v.placa;

-- Q03 · Hallazgos de alta urgencia
-- Pregunta: ¿Qué vehículos presentan problemas de urgencia alta o crítica?
CREATE VIEW v_q03_hallazgos_alta_urgencia AS
SELECT
    h.hallazgo_id,
    o.orden_id,
    v.placa,
    h.sintoma_comprobado,
    h.urgencia,
    h.recomendacion
FROM hallazgo h
JOIN orden_trabajo o
    ON h.orden_id = o.orden_id
JOIN vehiculo v
    ON o.vin = v.vin
WHERE h.urgencia IN ('Alta', 'Crítica')
ORDER BY
    CASE h.urgencia
        WHEN 'Crítica' THEN 1
        WHEN 'Alta' THEN 2
    END,
    o.orden_id;

-- Q04 · CONTEO DE ÓRDENES POR ESTADO (rótulo corregido, D5)
-- Pregunta: ¿Cuántas órdenes hay en cada estado actual?
CREATE VIEW v_q04_conteo_ordenes_por_estado AS
WITH ultimo_estado AS (
    SELECT DISTINCT ON (orden_id)
        orden_id,
        estado
    FROM historial_orden
    ORDER BY orden_id,
             fecha_hora DESC,
             historial_id DESC
)
SELECT
    estado,
    COUNT(*) AS cantidad_ordenes
FROM ultimo_estado
GROUP BY estado
ORDER BY estado;
