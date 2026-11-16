-- =====================================================================
-- IC-4301 Bases de Datos I · Proyecto (2.ª entrega) · Grupo 02
-- Caso: Taller Ruta 27
-- Archivo: 05_rutinas_p03.sql
-- Proceso G02-P03: Gestionar estados de la orden y fecha prometida.
--
-- Mecanismo (corrige D4 del Lab03):
--   * La ÚNICA vía de cambio es insertar en el historial; el trigger
--     AFTER INSERT del historial actualiza el valor actual de la orden en
--     la MISMA transacción. Un UPDATE directo de estado_actual o de
--     fecha_prometida_actual es rechazado (trg_orden_antes_actualizar).
--   * Las rutinas bloquean la orden (SELECT ... FOR UPDATE), dan un error
--     explícito si la orden no existe y, opcionalmente, aplican control
--     optimista con el valor esperado (p_*_esperado / p_fecha_esperada).
--   * El orden inequívoco lo da "secuencia", asignada bajo el bloqueo, no
--     fecha_hora: dos cambios con el mismo instante quedan ordenados.
--   * Al COMMIT, un constraint trigger diferido verifica que el valor
--     actual coincida con la última fila de cada historial.
-- =====================================================================

SET search_path = taller, public;

-- ---------------------------------------------------------------------
-- fn_cambiar_estado_orden
-- ---------------------------------------------------------------------
CREATE FUNCTION fn_cambiar_estado_orden(
    p_orden_id         bigint,
    p_estado_nuevo     text,
    p_personal_id      bigint,
    p_motivo           text        DEFAULT NULL,
    p_fecha_hora       timestamptz DEFAULT now(),
    p_estado_esperado  text        DEFAULT NULL
)
RETURNS bigint
LANGUAGE plpgsql
AS $$
DECLARE
    v_orden orden_trabajo;
    v_id    bigint;
BEGIN
    v_orden := fn_bloquear_orden(p_orden_id, 'G02-P03');

    IF p_estado_esperado IS NOT NULL AND v_orden.estado_actual <> p_estado_esperado THEN
        PERFORM fn_error(format('G02-P03: conflicto de concurrencia: se esperaba el estado "%s" y la orden %s está en "%s"',
                                p_estado_esperado, p_orden_id, v_orden.estado_actual));
    END IF;

    INSERT INTO historial_orden (orden_id, estado, fecha_hora, personal_id, motivo)
    VALUES (p_orden_id, p_estado_nuevo, p_fecha_hora, p_personal_id, p_motivo)
    RETURNING historial_id INTO v_id;
    RETURN v_id;
END;
$$;

COMMENT ON FUNCTION fn_cambiar_estado_orden(bigint, text, bigint, text, timestamptz, text) IS
    'G02-P03: única vía para cambiar el estado de una orden; historial y valor actual en la misma transacción.';

-- ---------------------------------------------------------------------
-- fn_cambiar_fecha_prometida
-- La primera promesa (si la orden no traía una) no exige motivo; toda
-- reprogramación sí (RN-07).
-- ---------------------------------------------------------------------
CREATE FUNCTION fn_cambiar_fecha_prometida(
    p_orden_id        bigint,
    p_fecha_nueva     timestamptz,
    p_comunicada_en   timestamptz,
    p_medio           text,
    p_motivo          text,
    p_personal_id     bigint,
    p_fecha_esperada  timestamptz DEFAULT NULL
)
RETURNS bigint
LANGUAGE plpgsql
AS $$
DECLARE
    v_orden orden_trabajo;
    v_id    bigint;
BEGIN
    v_orden := fn_bloquear_orden(p_orden_id, 'G02-P03');

    IF p_fecha_esperada IS NOT NULL AND v_orden.fecha_prometida_actual IS DISTINCT FROM p_fecha_esperada THEN
        PERFORM fn_error(format('G02-P03: conflicto de concurrencia: se esperaba la fecha prometida %s y la orden %s tiene %s',
                                p_fecha_esperada, p_orden_id, v_orden.fecha_prometida_actual));
    END IF;

    INSERT INTO historial_fecha_prometida (orden_id, fecha_nueva, fecha_hora_comunicacion, medio_comunicacion,
                                           motivo, personal_id)
    VALUES (p_orden_id, p_fecha_nueva, p_comunicada_en, p_medio, p_motivo, p_personal_id)
    RETURNING cambio_fecha_id INTO v_id;
    RETURN v_id;
END;
$$;

COMMENT ON FUNCTION fn_cambiar_fecha_prometida(bigint, timestamptz, timestamptz, text, text, bigint, timestamptz) IS
    'G02-P03: única vía para reprogramar la fecha prometida; conserva la promesa anterior, motivo, medio y responsable.';
