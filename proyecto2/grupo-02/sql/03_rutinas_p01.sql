-- =====================================================================
-- IC-4301 Bases de Datos I · Proyecto (2.ª entrega) · Grupo 02
-- Caso: Taller Ruta 27
-- Archivo: 03_rutinas_p01.sql
-- Proceso G02-P01: Versionar propuestas y autorizar labores.
--
-- Contenido:
--   1. Vistas de REGLA (las usan los triggers y las rutinas, por eso se
--      crean aquí y no en 06): versión vigente, decisión por línea,
--      situación aplicable y autorización ejecutable.
--   2. fn_publicar_propuesta   — publica una versión completa y atómica.
--   3. fn_registrar_decision   — registra una decisión por labor y versión.
--   4. fn_anular_labor         — retira una labor de la orden (con motivo).
--
-- Regla de "decisión aplicable" (README §6.1):
--   1. La versión vigente de una labor es la versión Presentada de mayor
--      número que contiene una línea de esa labor.
--   2. La decisión aplicable es la última fila de autorizacion_labor
--      (fecha_hora, desempate autorizacion_id) sobre la línea de ESA versión.
--   3. Las decisiones NO se arrastran entre versiones.
--   4. Una ampliación que solo añade labores no cambia la versión vigente de
--      las labores que no incluye.
--   5. La autorización ejecutable se identifica por autorizacion_id; nunca
--      se deduce de orden_trabajo.autorizador_cliente_id.
-- =====================================================================

SET search_path = taller, public;

-- =====================================================================
-- 1. VISTAS DE REGLA
-- =====================================================================

-- Versión vigente de cada labor (regla 1).
CREATE VIEW v_version_vigente_labor AS
SELECT DISTINCT ON (lp.labor_id)
       lp.labor_id,
       lp.orden_id,
       p.propuesta_id,
       p.version,
       lp.precio_estimado,
       lp.alcance
FROM linea_propuesta lp
JOIN propuesta p ON p.propuesta_id = lp.propuesta_id
WHERE p.estado = 'Presentada'
ORDER BY lp.labor_id, p.version DESC;

-- Última decisión registrada sobre cada línea (propuesta, labor).
CREATE VIEW v_decision_linea AS
SELECT DISTINCT ON (a.propuesta_id, a.labor_id)
       a.propuesta_id,
       a.labor_id,
       a.autorizacion_id,
       a.decision,
       a.cliente_id,
       a.facultad_id,
       a.medio,
       a.fecha_hora,
       a.observacion
FROM autorizacion_labor a
ORDER BY a.propuesta_id, a.labor_id, a.fecha_hora DESC, a.autorizacion_id DESC;

-- Situación aplicable de cada labor (reglas 2 a 4).
CREATE VIEW v_situacion_labor AS
SELECT l.labor_id,
       l.orden_id,
       l.descripcion,
       l.estado_labor,
       l.es_emergencia,
       vv.version            AS version_vigente,
       vv.propuesta_id       AS propuesta_vigente_id,
       vv.precio_estimado    AS precio_vigente,
       CASE
           WHEN vv.propuesta_id IS NULL THEN 'Sin propuesta'
           WHEN d.autorizacion_id IS NULL THEN 'Sin decidir'
           ELSE d.decision
       END                   AS situacion,
       d.autorizacion_id,
       d.cliente_id          AS decidido_por_cliente_id,
       c.nombre_razon_social AS decidido_por,
       d.medio               AS medio_decision,
       d.fecha_hora          AS fecha_hora_decision,
       e.emergencia_id
FROM labor l
LEFT JOIN v_version_vigente_labor vv ON vv.labor_id = l.labor_id
LEFT JOIN v_decision_linea d ON d.propuesta_id = vv.propuesta_id AND d.labor_id = l.labor_id
LEFT JOIN cliente c ON c.cliente_id = d.cliente_id
LEFT JOIN excepcion_emergencia e ON e.labor_id = l.labor_id;

-- Autorización que habilita la ejecución de cada labor (regla 5).
CREATE VIEW v_autorizacion_ejecutable AS
SELECT s.labor_id,
       s.orden_id,
       s.propuesta_vigente_id AS propuesta_id,
       s.version_vigente      AS version,
       s.autorizacion_id,
       s.decidido_por_cliente_id AS cliente_id,
       s.fecha_hora_decision
FROM v_situacion_labor s
WHERE s.situacion = 'Aceptada';

COMMENT ON VIEW v_situacion_labor IS 'G02-P01: decisión aplicable por labor (última decisión sobre la línea de la versión vigente).';
COMMENT ON VIEW v_autorizacion_ejecutable IS 'G02-P01: autorizacion_id que habilita la ejecución de cada labor (solo situación Aceptada).';

-- =====================================================================
-- 2. fn_publicar_propuesta
-- =====================================================================
-- Publica una versión completa en UNA transacción:
--   bloquea la orden, calcula version = max + 1, crea labores nuevas,
--   inserta líneas, repuestos estimados y dependencias, y la presenta.
-- Cualquier detalle inválido lanza excepción y NO queda nada (ni
-- propuesta a medias, ni labores, ni líneas).
--
-- p_lineas (jsonb, arreglo con >= 1 elemento). Cada elemento:
--   { "labor_id": 123 }                       labor existente de la orden
--   { "clave": "A", "descripcion": "...",     labor nueva (clave opcional,
--     "hallazgo_id": 4101 }                     para citarla en "requiere")
--   y además, en ambos casos:
--   "precio_estimado": 45000,  "alcance": "...",
--   "repuestos": [ { "repuesto_id": "FR-001", "cantidad": 1, "precio_unitario": 25000 } ],
--   "requiere":  [ 123, "A" ]                  labores (id o clave) requeridas
CREATE FUNCTION fn_publicar_propuesta(
    p_orden_id           bigint,
    p_propuesta_base_id  bigint,
    p_lineas             jsonb,
    p_personal_id        bigint,
    p_observacion        text        DEFAULT NULL,
    p_fecha_hora         timestamptz DEFAULT now()
)
RETURNS bigint
LANGUAGE plpgsql
AS $$
DECLARE
    v_orden         orden_trabajo;
    v_version       integer;
    v_propuesta_id  bigint;
    v_linea         jsonb;
    v_rep           jsonb;
    v_req           jsonb;
    v_labor_id      bigint;
    v_req_id        bigint;
    v_hallazgo_id   bigint;
    v_precio        numeric;
    v_alcance       text;
    v_claves        jsonb := '{}'::jsonb;
    v_labores       bigint[] := ARRAY[]::bigint[];
    v_i             integer := 0;
BEGIN
    -- Bloqueo pesimista: dos publicaciones simultáneas sobre la misma orden
    -- se serializan y obtienen versiones consecutivas, sin perder ninguna.
    v_orden := fn_bloquear_orden(p_orden_id, 'G02-P01');

    IF p_lineas IS NULL OR jsonb_typeof(p_lineas) <> 'array' OR jsonb_array_length(p_lineas) = 0 THEN
        PERFORM fn_error('G02-P01: una versión debe tener al menos una línea');
    END IF;

    SELECT coalesce(max(version), 0) + 1 INTO v_version FROM propuesta WHERE orden_id = p_orden_id;

    INSERT INTO propuesta (orden_id, version, estado, propuesta_base_id, presentada_por_id, observacion)
    VALUES (p_orden_id, v_version, 'Borrador', p_propuesta_base_id, p_personal_id, p_observacion)
    RETURNING propuesta_id INTO v_propuesta_id;

    -- Primera pasada: labores y líneas.
    FOR v_linea IN SELECT value FROM jsonb_array_elements(p_lineas) LOOP
        v_i := v_i + 1;

        IF v_linea ? 'labor_id' THEN
            v_labor_id := (v_linea ->> 'labor_id')::bigint;
            IF NOT EXISTS (SELECT 1 FROM labor WHERE labor_id = v_labor_id) THEN
                PERFORM fn_error(format('G02-P01: línea %s: la labor %s no existe', v_i, v_labor_id));
            END IF;
            IF NOT EXISTS (SELECT 1 FROM labor WHERE labor_id = v_labor_id AND orden_id = p_orden_id) THEN
                PERFORM fn_error(format('G02-P01: línea %s: la labor %s no pertenece a la orden %s', v_i, v_labor_id, p_orden_id));
            END IF;
        ELSE
            IF btrim(coalesce(v_linea ->> 'descripcion', '')) = '' THEN
                PERFORM fn_error(format('G02-P01: línea %s: una labor nueva requiere descripción', v_i));
            END IF;
            v_hallazgo_id := (v_linea ->> 'hallazgo_id')::bigint;
            IF v_hallazgo_id IS NOT NULL
               AND NOT EXISTS (SELECT 1 FROM hallazgo WHERE hallazgo_id = v_hallazgo_id AND orden_id = p_orden_id) THEN
                PERFORM fn_error(format('G02-P01: línea %s: el hallazgo %s no pertenece a la orden %s', v_i, v_hallazgo_id, p_orden_id));
            END IF;
            INSERT INTO labor (orden_id, hallazgo_id, descripcion, es_emergencia, creada_por_id, creada_en)
            VALUES (p_orden_id, v_hallazgo_id, v_linea ->> 'descripcion', false, p_personal_id, p_fecha_hora)
            RETURNING labor_id INTO v_labor_id;
            IF v_linea ? 'clave' THEN
                v_claves := v_claves || jsonb_build_object(v_linea ->> 'clave', v_labor_id);
            END IF;
        END IF;

        IF v_labor_id = ANY (v_labores) THEN
            PERFORM fn_error(format('G02-P01: línea %s: la labor %s aparece dos veces en la misma versión', v_i, v_labor_id));
        END IF;
        v_labores := v_labores || v_labor_id;

        v_precio := (v_linea ->> 'precio_estimado')::numeric;
        IF v_precio IS NULL THEN
            PERFORM fn_error(format('G02-P01: línea %s: precio_estimado es obligatorio', v_i));
        END IF;
        IF v_precio < 0 THEN
            PERFORM fn_error(format('G02-P01: línea %s: el precio estimado no puede ser negativo (%s)', v_i, v_precio));
        END IF;
        v_alcance := coalesce(v_linea ->> 'alcance', v_linea ->> 'descripcion',
                              (SELECT descripcion FROM labor WHERE labor_id = v_labor_id));

        INSERT INTO linea_propuesta (propuesta_id, labor_id, orden_id, precio_estimado, alcance)
        VALUES (v_propuesta_id, v_labor_id, p_orden_id, v_precio, v_alcance);

        FOR v_rep IN SELECT value FROM jsonb_array_elements(coalesce(v_linea -> 'repuestos', '[]'::jsonb)) LOOP
            INSERT INTO repuesto_propuesto (propuesta_id, labor_id, repuesto_id, cantidad_estimada, precio_unitario_estimado)
            VALUES (v_propuesta_id, v_labor_id, v_rep ->> 'repuesto_id',
                    (v_rep ->> 'cantidad')::numeric, (v_rep ->> 'precio_unitario')::numeric);
        END LOOP;
    END LOOP;

    -- Segunda pasada: dependencias (las claves ya están resueltas).
    v_i := 0;
    FOR v_linea IN SELECT value FROM jsonb_array_elements(p_lineas) LOOP
        v_i := v_i + 1;
        v_labor_id := v_labores[v_i];
        FOR v_req IN SELECT value FROM jsonb_array_elements(coalesce(v_linea -> 'requiere', '[]'::jsonb)) LOOP
            IF jsonb_typeof(v_req) = 'string' THEN
                IF NOT v_claves ? (v_req #>> '{}') THEN
                    PERFORM fn_error(format('G02-P01: línea %s: la clave %s no corresponde a ninguna labor nueva', v_i, v_req #>> '{}'));
                END IF;
                v_req_id := (v_claves ->> (v_req #>> '{}'))::bigint;
            ELSE
                v_req_id := (v_req #>> '{}')::bigint;
            END IF;
            IF NOT EXISTS (SELECT 1 FROM labor WHERE labor_id = v_req_id AND orden_id = p_orden_id) THEN
                PERFORM fn_error(format('G02-P01: línea %s: la labor requerida %s no pertenece a la orden %s', v_i, v_req_id, p_orden_id));
            END IF;
            INSERT INTO labor_dependencia (labor_id, requiere_labor_id, orden_id)
            VALUES (v_labor_id, v_req_id, p_orden_id)
            ON CONFLICT DO NOTHING;
        END LOOP;
    END LOOP;

    -- Presentar: desde aquí la versión y sus líneas son inmutables.
    UPDATE propuesta
    SET estado = 'Presentada', fecha_hora_presentacion = p_fecha_hora
    WHERE propuesta_id = v_propuesta_id;

    RETURN v_propuesta_id;
END;
$$;

COMMENT ON FUNCTION fn_publicar_propuesta(bigint, bigint, jsonb, bigint, text, timestamptz) IS
    'G02-P01: publica una versión completa (labores, líneas, repuestos estimados, dependencias) de forma atómica.';

-- =====================================================================
-- 3. fn_registrar_decision
-- =====================================================================
-- Registra la decisión de un cliente sobre la línea (propuesta, labor).
--   * Resuelve la facultad 'Aprobar' vigente del cliente en ESA orden.
--   * Bloquea la línea (FOR UPDATE): decisiones simultáneas sobre la
--     misma línea quedan serializadas; la aplicable es la última confirmada.
--   * Control optimista opcional: p_decision_esperada ('Sin decidir',
--     'Pendiente', 'Aceptada', 'Rechazada'); si la decisión vigente de la
--     línea cambió, se rechaza en lugar de sobrescribir en silencio.
--   * Solo inserta; nunca actualiza una decisión anterior.
CREATE FUNCTION fn_registrar_decision(
    p_propuesta_id       bigint,
    p_labor_id           bigint,
    p_cliente_id         bigint,
    p_decision           text,
    p_medio              text,
    p_registrado_por_id  bigint,
    p_fecha_hora         timestamptz DEFAULT now(),
    p_observacion        text        DEFAULT NULL,
    p_decision_esperada  text        DEFAULT NULL
)
RETURNS bigint
LANGUAGE plpgsql
AS $$
DECLARE
    v_orden_id     bigint;
    v_facultad_id  bigint;
    v_actual       text;
    v_id           bigint;
BEGIN
    SELECT lp.orden_id INTO v_orden_id
    FROM linea_propuesta lp
    WHERE lp.propuesta_id = p_propuesta_id AND lp.labor_id = p_labor_id
    FOR UPDATE;
    IF NOT FOUND THEN
        PERFORM fn_error(format('G02-P01: la labor %s no forma parte de la propuesta %s', p_labor_id, p_propuesta_id));
    END IF;

    SELECT f.facultad_id INTO v_facultad_id
    FROM facultad_orden f
    WHERE f.orden_id = v_orden_id
      AND f.cliente_id = p_cliente_id
      AND f.tipo_facultad = 'Aprobar'
      AND f.vigente_desde <= p_fecha_hora
      AND (f.vigente_hasta IS NULL OR p_fecha_hora < f.vigente_hasta)
    ORDER BY f.vigente_desde DESC
    LIMIT 1;
    IF NOT FOUND THEN
        PERFORM fn_error(format('G02-P01: el cliente %s no tiene facultad vigente para aprobar en la orden %s',
                                p_cliente_id, v_orden_id));
    END IF;

    IF p_decision_esperada IS NOT NULL THEN
        SELECT coalesce((SELECT d.decision FROM v_decision_linea d
                         WHERE d.propuesta_id = p_propuesta_id AND d.labor_id = p_labor_id), 'Sin decidir')
        INTO v_actual;
        IF v_actual <> p_decision_esperada THEN
            PERFORM fn_error(format('G02-P01: conflicto de concurrencia: se esperaba "%s" y la decisión vigente de la línea es "%s"',
                                    p_decision_esperada, v_actual));
        END IF;
    END IF;

    INSERT INTO autorizacion_labor (propuesta_id, labor_id, orden_id, facultad_id, cliente_id,
                                    decision, fecha_hora, medio, observacion, registrado_por_id)
    VALUES (p_propuesta_id, p_labor_id, v_orden_id, v_facultad_id, p_cliente_id,
            p_decision, p_fecha_hora, p_medio, p_observacion, p_registrado_por_id)
    RETURNING autorizacion_id INTO v_id;
    RETURN v_id;
END;
$$;

COMMENT ON FUNCTION fn_registrar_decision(bigint, bigint, bigint, text, text, bigint, timestamptz, text, text) IS
    'G02-P01: registra una decisión (Aceptada/Rechazada/Pendiente) por labor y versión, con facultad vigente; solo inserción.';

-- =====================================================================
-- 4. fn_anular_labor
-- =====================================================================
-- Retira una labor de la orden sin borrar nada (ambigüedad "versión que
-- retira una labor", docs/ambiguedades.md A-03): la labor pasa a Anulada
-- con motivo en su historial y ya no puede ofrecerse ni ejecutarse.
CREATE FUNCTION fn_anular_labor(
    p_labor_id     bigint,
    p_personal_id  bigint,
    p_motivo       text,
    p_fecha_hora   timestamptz DEFAULT now()
)
RETURNS bigint
LANGUAGE plpgsql
AS $$
DECLARE
    v_id bigint;
BEGIN
    PERFORM fn_bloquear_labor(p_labor_id, 'G02-P01');
    INSERT INTO historial_labor (labor_id, estado_nuevo, fecha_hora, personal_id, motivo)
    VALUES (p_labor_id, 'Anulada', p_fecha_hora, p_personal_id, p_motivo)
    RETURNING historial_labor_id INTO v_id;
    RETURN v_id;
END;
$$;
