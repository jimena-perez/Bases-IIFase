-- =====================================================================
-- IC-4301 Bases de Datos I · Proyecto (2.ª entrega) · Grupo 02
-- Caso: Taller Ruta 27
-- Archivo: 04_rutinas_p02.sql
-- Proceso G02-P02: Ejecutar reparaciones y pruebas (incluye consumo de
-- repuestos).
--
-- Todas las rutinas bloquean la labor (FOR UPDATE) antes de actuar, de modo
-- que completar una labor y registrar sobre ella una participación, una
-- prueba o un consumo quedan serializados. Las reglas se vuelven a
-- verificar en los triggers de 02_triggers_integridad.sql, de modo que
-- también se cumplen si alguien inserta "a mano".
--
--   fn_iniciar_labor           Pendiente/Suspendida -> En proceso (con habilitante)
--   fn_registrar_emergencia    labor mínima de emergencia + excepción justificada
--   fn_registrar_participacion participación de un técnico (abierta o cerrada)
--   fn_cerrar_participacion    cierra una participación abierta
--   fn_registrar_prueba        prueba con resultado categórico
--   fn_registrar_consumo       consumo + movimiento (y liberación de reserva)
--   fn_suspender_labor         En proceso -> Suspendida (con motivo)
--   fn_completar_labor         En proceso -> Completada
--   fn_registrar_retrabajo     labor nueva ligada a la revisada y a la prueba
-- =====================================================================

SET search_path = taller, public;

-- ---------------------------------------------------------------------
-- fn_iniciar_labor
-- Habilitante: la autorización APLICABLE y Aceptada (v_situacion_labor) o,
-- si la labor es de emergencia, su excepción. Las dependencias deben estar
-- completadas (lo verifica el trigger de historial_labor).
-- ---------------------------------------------------------------------
CREATE FUNCTION fn_iniciar_labor(
    p_labor_id     bigint,
    p_personal_id  bigint,
    p_fecha_hora   timestamptz DEFAULT now()
)
RETURNS bigint
LANGUAGE plpgsql
AS $$
DECLARE
    v_labor          labor;
    v_situacion      text;
    v_autorizacion   bigint;
    v_emergencia     bigint;
    v_id             bigint;
BEGIN
    v_labor := fn_bloquear_labor(p_labor_id, 'G02-P02');
    IF v_labor.estado_labor NOT IN ('Pendiente', 'Suspendida') THEN
        PERFORM fn_error(format('G02-P02: la labor %s está %s y no puede iniciarse', p_labor_id, v_labor.estado_labor));
    END IF;

    SELECT situacion, autorizacion_id, emergencia_id
    INTO v_situacion, v_autorizacion, v_emergencia
    FROM v_situacion_labor WHERE labor_id = p_labor_id;

    IF v_situacion = 'Aceptada' THEN
        v_emergencia := NULL;
    ELSIF v_labor.es_emergencia AND v_emergencia IS NOT NULL THEN
        v_autorizacion := NULL;
    ELSE
        PERFORM fn_error(format('G02-P02: la labor %s no tiene autorización aplicable Aceptada ni excepción de emergencia (situación: %s)',
                                p_labor_id, v_situacion));
    END IF;

    INSERT INTO historial_labor (labor_id, estado_nuevo, fecha_hora, personal_id, autorizacion_id, emergencia_id)
    VALUES (p_labor_id, 'En proceso', p_fecha_hora, p_personal_id, v_autorizacion, v_emergencia)
    RETURNING historial_labor_id INTO v_id;
    RETURN v_id;
END;
$$;

-- ---------------------------------------------------------------------
-- fn_registrar_emergencia
-- Crea la labor MÍNIMA de emergencia y su excepción justificada. No toca
-- las demás labores ni la propuesta: la excepción habilita solo esa labor.
-- ---------------------------------------------------------------------
CREATE FUNCTION fn_registrar_emergencia(
    p_orden_id           bigint,
    p_hallazgo_id        bigint,
    p_descripcion        text,
    p_riesgo             text,
    p_justificacion      text,
    p_alcance_minimo     text,
    p_autorizada_por_id  bigint,
    p_fecha_hora         timestamptz DEFAULT now()
)
RETURNS bigint
LANGUAGE plpgsql
AS $$
DECLARE
    v_labor_id bigint;
BEGIN
    PERFORM fn_bloquear_orden(p_orden_id, 'G02-P02');
    IF p_hallazgo_id IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM hallazgo WHERE hallazgo_id = p_hallazgo_id AND orden_id = p_orden_id) THEN
        PERFORM fn_error(format('G02-P02: el hallazgo %s no pertenece a la orden %s', p_hallazgo_id, p_orden_id));
    END IF;

    INSERT INTO labor (orden_id, hallazgo_id, descripcion, es_emergencia, creada_por_id, creada_en)
    VALUES (p_orden_id, p_hallazgo_id, p_descripcion, true, p_autorizada_por_id, p_fecha_hora)
    RETURNING labor_id INTO v_labor_id;

    INSERT INTO excepcion_emergencia (labor_id, orden_id, riesgo, justificacion, alcance_minimo, autorizada_por_id, fecha_hora)
    VALUES (v_labor_id, p_orden_id, p_riesgo, p_justificacion, p_alcance_minimo, p_autorizada_por_id, p_fecha_hora);

    RETURN v_labor_id;
END;
$$;

-- ---------------------------------------------------------------------
-- fn_registrar_participacion
-- p_fin y p_minutos_efectivos NULL => participación abierta.
-- ---------------------------------------------------------------------
CREATE FUNCTION fn_registrar_participacion(
    p_labor_id           bigint,
    p_tecnico_id         bigint,
    p_inicio             timestamptz,
    p_fin                timestamptz,
    p_minutos_efectivos  integer,
    p_descripcion        text,
    p_especialidad_id    bigint DEFAULT NULL
)
RETURNS bigint
LANGUAGE plpgsql
AS $$
DECLARE
    v_labor labor;
    v_id    bigint;
BEGIN
    v_labor := fn_bloquear_labor(p_labor_id, 'G02-P02');
    INSERT INTO participacion_tecnica (labor_id, orden_id, tecnico_id, especialidad_id, inicio, fin,
                                       minutos_efectivos, descripcion_participacion)
    VALUES (p_labor_id, v_labor.orden_id, p_tecnico_id, p_especialidad_id, p_inicio, p_fin,
            p_minutos_efectivos, p_descripcion)
    RETURNING participacion_id INTO v_id;
    RETURN v_id;
END;
$$;

CREATE FUNCTION fn_cerrar_participacion(
    p_participacion_id   bigint,
    p_fin                timestamptz,
    p_minutos_efectivos  integer
)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE participacion_tecnica
    SET fin = p_fin, minutos_efectivos = p_minutos_efectivos
    WHERE participacion_id = p_participacion_id;
    IF NOT FOUND THEN
        PERFORM fn_error(format('G02-P02: la participación %s no existe', p_participacion_id));
    END IF;
END;
$$;

-- ---------------------------------------------------------------------
-- fn_registrar_prueba
-- Resultado categórico obligatorio; medición (valor + unidad) opcional.
-- ---------------------------------------------------------------------
CREATE FUNCTION fn_registrar_prueba(
    p_labor_id     bigint,
    p_personal_id  bigint,
    p_fecha_hora   timestamptz,
    p_tipo         text,
    p_resultado    text,
    p_descripcion  text,
    p_valor        numeric DEFAULT NULL,
    p_unidad       text    DEFAULT NULL
)
RETURNS bigint
LANGUAGE plpgsql
AS $$
DECLARE
    v_labor labor;
    v_id    bigint;
BEGIN
    v_labor := fn_bloquear_labor(p_labor_id, 'G02-P02');
    INSERT INTO prueba (labor_id, orden_id, personal_id, fecha_hora, tipo_prueba, resultado,
                        medicion_valor, unidad, descripcion_resultado)
    VALUES (p_labor_id, v_labor.orden_id, p_personal_id, p_fecha_hora, p_tipo, p_resultado,
            p_valor, p_unidad, p_descripcion)
    RETURNING prueba_id INTO v_id;
    RETURN v_id;
END;
$$;

-- ---------------------------------------------------------------------
-- fn_registrar_consumo
-- En la MISMA transacción: consumo + (liberación de la reserva de la orden,
-- si existía) + movimiento de Consumo con origen. Si no hay existencias,
-- el trigger de inventario rechaza y se revierte todo: no queda consumo sin
-- movimiento ni movimiento sin origen.
-- p_orden_id es la orden a la que se carga el repuesto: debe coincidir con
-- la orden de la labor.
-- ---------------------------------------------------------------------
CREATE FUNCTION fn_registrar_consumo(
    p_orden_id         bigint,
    p_labor_id         bigint,
    p_repuesto_id      text,
    p_cantidad         numeric,
    p_precio_unitario  numeric,
    p_personal_id      bigint,
    p_fecha_hora       timestamptz DEFAULT now()
)
RETURNS bigint
LANGUAGE plpgsql
AS $$
DECLARE
    v_labor      labor;
    v_consumo_id bigint;
    v_reservado  numeric;
    v_liberar    numeric;
BEGIN
    v_labor := fn_bloquear_labor(p_labor_id, 'G02-P02');
    IF v_labor.orden_id <> p_orden_id THEN
        PERFORM fn_error(format('G02-P02: la labor %s no pertenece a la orden %s (es de la orden %s)',
                                p_labor_id, p_orden_id, v_labor.orden_id));
    END IF;

    INSERT INTO consumo_repuesto (labor_id, orden_id, repuesto_id, cantidad_utilizada, precio_unitario_cargado,
                                  fecha_hora, registrado_por_id)
    VALUES (p_labor_id, p_orden_id, p_repuesto_id, p_cantidad, p_precio_unitario, p_fecha_hora, p_personal_id)
    RETURNING consumo_id INTO v_consumo_id;

    -- Si la orden tenía reservado este repuesto, el consumo usa primero la
    -- reserva: se libera lo que se consume (hasta lo reservado).
    SELECT coalesce(sum(CASE tipo_movimiento WHEN 'Reserva' THEN cantidad
                                             WHEN 'Liberación' THEN -cantidad END), 0)
    INTO v_reservado
    FROM movimiento_inventario
    WHERE repuesto_id = p_repuesto_id AND orden_id = p_orden_id AND tipo_movimiento IN ('Reserva', 'Liberación');

    v_liberar := least(v_reservado, p_cantidad);
    IF v_liberar > 0 THEN
        INSERT INTO movimiento_inventario (repuesto_id, orden_id, tipo_movimiento, cantidad, fecha_hora,
                                           registrado_por_id, motivo)
        VALUES (p_repuesto_id, p_orden_id, 'Liberación', v_liberar, p_fecha_hora, p_personal_id,
                format('Reserva usada por el consumo %s', v_consumo_id));
    END IF;

    INSERT INTO movimiento_inventario (repuesto_id, orden_id, tipo_movimiento, cantidad, fecha_hora,
                                       consumo_id, registrado_por_id, motivo)
    VALUES (p_repuesto_id, p_orden_id, 'Consumo', p_cantidad, p_fecha_hora, v_consumo_id, p_personal_id,
            format('Consumo en la labor %s', p_labor_id));

    RETURN v_consumo_id;
END;
$$;

-- ---------------------------------------------------------------------
-- fn_suspender_labor / fn_completar_labor
-- Completar exige (trigger): >= 1 participación cerrada, ninguna abierta y,
-- si la última prueba es Desfavorable, un retrabajo de esa prueba Completado.
-- ---------------------------------------------------------------------
CREATE FUNCTION fn_suspender_labor(
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
    PERFORM fn_bloquear_labor(p_labor_id, 'G02-P02');
    INSERT INTO historial_labor (labor_id, estado_nuevo, fecha_hora, personal_id, motivo)
    VALUES (p_labor_id, 'Suspendida', p_fecha_hora, p_personal_id, p_motivo)
    RETURNING historial_labor_id INTO v_id;
    RETURN v_id;
END;
$$;

CREATE FUNCTION fn_completar_labor(
    p_labor_id     bigint,
    p_personal_id  bigint,
    p_fecha_hora   timestamptz DEFAULT now()
)
RETURNS bigint
LANGUAGE plpgsql
AS $$
DECLARE
    v_id bigint;
BEGIN
    PERFORM fn_bloquear_labor(p_labor_id, 'G02-P02');
    INSERT INTO historial_labor (labor_id, estado_nuevo, fecha_hora, personal_id)
    VALUES (p_labor_id, 'Completada', p_fecha_hora, p_personal_id)
    RETURNING historial_labor_id INTO v_id;
    RETURN v_id;
END;
$$;

-- ---------------------------------------------------------------------
-- fn_registrar_retrabajo
-- Nueva labor ligada a la labor revisada y a la prueba Desfavorable que la
-- origina. NO borra ni modifica la intervención original. El retrabajo NO
-- queda cubierto por la autorización original (docs/ambiguedades.md A-01):
-- requiere su propia línea en una versión nueva (puede ser a precio 0) y
-- una decisión Aceptada, o una excepción de emergencia si hay riesgo.
-- ---------------------------------------------------------------------
CREATE FUNCTION fn_registrar_retrabajo(
    p_labor_revisada_id  bigint,
    p_prueba_origen_id   bigint,
    p_descripcion        text,
    p_personal_id        bigint,
    p_fecha_hora         timestamptz DEFAULT now()
)
RETURNS bigint
LANGUAGE plpgsql
AS $$
DECLARE
    v_revisada labor;
    v_id       bigint;
BEGIN
    v_revisada := fn_bloquear_labor(p_labor_revisada_id, 'G02-P02');
    IF NOT EXISTS (SELECT 1 FROM prueba WHERE prueba_id = p_prueba_origen_id AND labor_id = p_labor_revisada_id) THEN
        PERFORM fn_error(format('G02-P02: la prueba %s no es de la labor %s', p_prueba_origen_id, p_labor_revisada_id));
    END IF;
    INSERT INTO labor (orden_id, hallazgo_id, descripcion, es_emergencia, labor_revisada_id, prueba_origen_id,
                       creada_por_id, creada_en)
    VALUES (v_revisada.orden_id, v_revisada.hallazgo_id, p_descripcion, false, p_labor_revisada_id, p_prueba_origen_id,
            p_personal_id, p_fecha_hora)
    RETURNING labor_id INTO v_id;
    RETURN v_id;
END;
$$;
