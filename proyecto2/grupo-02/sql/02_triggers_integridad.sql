-- =====================================================================
-- IC-4301 Bases de Datos I · Proyecto (2.ª entrega) · Grupo 02
-- Caso: Taller Ruta 27
-- Archivo: 02_triggers_integridad.sql
-- Propósito: reglas que no se expresan con PK/FK/UNIQUE/CHECK/EXCLUDE.
--   Se aplican AUNQUE alguien inserte "a mano" sin usar las rutinas.
--
-- Prefijos de error (SQLSTATE P0001):
--   G02-INM  tabla o fila de solo inserción / inmutable
--   G02-INT  integridad general del modelo
--   G02-P01  versionado de propuestas y decisiones
--   G02-P02  ejecución, participaciones, pruebas y consumos
--   G02-P03  estados de la orden y fecha prometida
--
-- Sincronización "valor actual + historial" (corrige D4):
--   orden_trabajo.estado_actual, orden_trabajo.fecha_prometida_actual y
--   labor.estado_labor SOLO cambian desde el trigger AFTER INSERT de su
--   historial, que activa la variable de transacción taller.via_historial
--   (o taller.via_historial_labor) durante su propio UPDATE. Un UPDATE
--   directo encuentra la variable apagada y es rechazado.
-- =====================================================================

SET search_path = taller, public;

-- =====================================================================
-- 0. UTILIDADES
-- =====================================================================

-- Lanza un error de negocio con SQLSTATE P0001 y prefijo identificable.
CREATE FUNCTION fn_error(p_mensaje text)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    RAISE EXCEPTION USING ERRCODE = 'P0001', MESSAGE = p_mensaje;
END;
$$;

-- Exige que una persona del taller exista, esté activa y (opcionalmente)
-- tenga uno de los roles indicados.
CREATE FUNCTION fn_exigir_personal(p_personal_id bigint, p_roles text[], p_contexto text)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_rol    text;
    v_activo boolean;
BEGIN
    SELECT rol, activo INTO v_rol, v_activo FROM personal WHERE personal_id = p_personal_id;
    IF NOT FOUND THEN
        PERFORM fn_error(format('%s: el personal %s no existe', p_contexto, p_personal_id));
    END IF;
    IF NOT v_activo THEN
        PERFORM fn_error(format('%s: el personal %s no está activo', p_contexto, p_personal_id));
    END IF;
    IF p_roles IS NOT NULL AND NOT (v_rol = ANY (p_roles)) THEN
        PERFORM fn_error(format('%s: el personal %s tiene rol %s y se requiere %s',
                                p_contexto, p_personal_id, v_rol, array_to_string(p_roles, ' o ')));
    END IF;
END;
$$;

-- Bloquea la orden (FOR UPDATE) y devuelve su fila. Error explícito si no existe.
CREATE FUNCTION fn_bloquear_orden(p_orden_id bigint, p_contexto text)
RETURNS orden_trabajo
LANGUAGE plpgsql
AS $$
DECLARE
    v_orden orden_trabajo;
BEGIN
    SELECT * INTO v_orden FROM orden_trabajo WHERE orden_id = p_orden_id FOR UPDATE;
    IF NOT FOUND THEN
        PERFORM fn_error(format('%s: la orden %s no existe', p_contexto, p_orden_id));
    END IF;
    RETURN v_orden;
END;
$$;

-- Bloquea la labor (FOR UPDATE) y devuelve su fila. Serializa todas las
-- operaciones de ejecución sobre una misma labor (P02).
CREATE FUNCTION fn_bloquear_labor(p_labor_id bigint, p_contexto text)
RETURNS labor
LANGUAGE plpgsql
AS $$
DECLARE
    v_labor labor;
BEGIN
    SELECT * INTO v_labor FROM labor WHERE labor_id = p_labor_id FOR UPDATE;
    IF NOT FOUND THEN
        PERFORM fn_error(format('%s: la labor %s no existe', p_contexto, p_labor_id));
    END IF;
    RETURN v_labor;
END;
$$;

CREATE FUNCTION fn_es_terminal(p_estado text)
RETURNS boolean
LANGUAGE sql IMMUTABLE
AS $$ SELECT p_estado IN ('Entregada', 'Cancelada') $$;

-- =====================================================================
-- 1. INMUTABILIDAD GENÉRICA (tablas históricas de solo inserción)
-- =====================================================================

CREATE FUNCTION fn_solo_insercion()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    PERFORM fn_error(format('G02-INM: %s es de solo inserción; no se permite %s (registre una fila nueva)',
                            TG_TABLE_NAME, TG_OP));
    RETURN NULL;
END;
$$;

CREATE TRIGGER trg_historial_orden_inmutable        BEFORE UPDATE OR DELETE ON historial_orden           FOR EACH ROW EXECUTE FUNCTION fn_solo_insercion();
CREATE TRIGGER trg_hfp_inmutable                    BEFORE UPDATE OR DELETE ON historial_fecha_prometida FOR EACH ROW EXECUTE FUNCTION fn_solo_insercion();
CREATE TRIGGER trg_historial_labor_inmutable        BEFORE UPDATE OR DELETE ON historial_labor           FOR EACH ROW EXECUTE FUNCTION fn_solo_insercion();
CREATE TRIGGER trg_autorizacion_inmutable           BEFORE UPDATE OR DELETE ON autorizacion_labor        FOR EACH ROW EXECUTE FUNCTION fn_solo_insercion();
CREATE TRIGGER trg_emergencia_inmutable             BEFORE UPDATE OR DELETE ON excepcion_emergencia      FOR EACH ROW EXECUTE FUNCTION fn_solo_insercion();
CREATE TRIGGER trg_dependencia_inmutable            BEFORE UPDATE OR DELETE ON labor_dependencia         FOR EACH ROW EXECUTE FUNCTION fn_solo_insercion();
CREATE TRIGGER trg_prueba_inmutable                 BEFORE UPDATE OR DELETE ON prueba                    FOR EACH ROW EXECUTE FUNCTION fn_solo_insercion();
CREATE TRIGGER trg_consumo_inmutable                BEFORE UPDATE OR DELETE ON consumo_repuesto          FOR EACH ROW EXECUTE FUNCTION fn_solo_insercion();
CREATE TRIGGER trg_movimiento_inmutable             BEFORE UPDATE OR DELETE ON movimiento_inventario     FOR EACH ROW EXECUTE FUNCTION fn_solo_insercion();
CREATE TRIGGER trg_pieza_inmutable                  BEFORE UPDATE OR DELETE ON pieza_retirada            FOR EACH ROW EXECUTE FUNCTION fn_solo_insercion();
CREATE TRIGGER trg_entrega_inmutable                BEFORE UPDATE OR DELETE ON entrega                   FOR EACH ROW EXECUTE FUNCTION fn_solo_insercion();
CREATE TRIGGER trg_garantia_inmutable               BEFORE UPDATE OR DELETE ON garantia                  FOR EACH ROW EXECUTE FUNCTION fn_solo_insercion();
CREATE TRIGGER trg_transicion_inmutable             BEFORE UPDATE OR DELETE ON transicion_estado_orden   FOR EACH ROW EXECUTE FUNCTION fn_solo_insercion();

-- =====================================================================
-- 2. IDENTIDAD Y ROLES
-- =====================================================================

-- RN-03: al confirmar, todo cliente tiene al menos un contacto apto para
-- avisos. Constraint trigger DIFERIDO: permite insertar el cliente y sus
-- contactos en la misma transacción en cualquier orden.
CREATE FUNCTION fn_verificar_contacto_avisos()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_cliente_id bigint;
BEGIN
    IF TG_OP = 'DELETE' THEN
        v_cliente_id := OLD.cliente_id;
    ELSE
        v_cliente_id := NEW.cliente_id;
    END IF;

    IF EXISTS (SELECT 1 FROM cliente WHERE cliente_id = v_cliente_id)
       AND NOT EXISTS (SELECT 1 FROM contacto_cliente
                       WHERE cliente_id = v_cliente_id AND recibe_avisos) THEN
        PERFORM fn_error(format('G02-INT: el cliente %s debe tener al menos un contacto apto para avisos (RN-03)',
                                v_cliente_id));
    END IF;
    RETURN NULL;
END;
$$;

CREATE CONSTRAINT TRIGGER trg_cliente_contacto_avisos
    AFTER INSERT ON cliente
    DEFERRABLE INITIALLY DEFERRED
    FOR EACH ROW EXECUTE FUNCTION fn_verificar_contacto_avisos();

CREATE CONSTRAINT TRIGGER trg_contacto_avisos
    AFTER INSERT OR UPDATE OR DELETE ON contacto_cliente
    DEFERRABLE INITIALLY DEFERRED
    FOR EACH ROW EXECUTE FUNCTION fn_verificar_contacto_avisos();

-- anio <= año actual + 1 (no se usa now() en un CHECK porque no es inmutable).
CREATE FUNCTION fn_vehiculo_anio()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.anio > extract(year FROM now())::int + 1 THEN
        PERFORM fn_error(format('G02-INT: el año %s del vehículo %s supera el año actual + 1', NEW.anio, NEW.vin));
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_vehiculo_anio
    BEFORE INSERT OR UPDATE OF anio ON vehiculo
    FOR EACH ROW EXECUTE FUNCTION fn_vehiculo_anio();

-- El VIN es la identidad estable: no se reescribe (RN-02).
CREATE FUNCTION fn_vehiculo_vin_estable()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.vin <> OLD.vin THEN
        PERFORM fn_error(format('G02-INT: el VIN %s es la identidad estable del vehículo y no se modifica (RN-02)', OLD.vin));
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_vehiculo_vin_estable
    BEFORE UPDATE OF vin ON vehiculo
    FOR EACH ROW EXECUTE FUNCTION fn_vehiculo_vin_estable();

-- Una especialidad solo se asigna a personal con rol Técnico (RN-14).
-- (No se exige que esté activo: la especialidad histórica de un técnico
-- que ya no labora se conserva.)
CREATE FUNCTION fn_especialidad_tecnico()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_rol text;
BEGIN
    SELECT rol INTO v_rol FROM personal WHERE personal_id = NEW.tecnico_id;
    IF v_rol IS DISTINCT FROM 'Técnico' THEN
        PERFORM fn_error(format('G02-INT: especialidad: el personal %s tiene rol %s y solo un Técnico tiene especialidades',
                                NEW.tecnico_id, coalesce(v_rol, 'inexistente')));
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_especialidad_tecnico
    BEFORE INSERT OR UPDATE ON especialidad_tecnico
    FOR EACH ROW EXECUTE FUNCTION fn_especialidad_tecnico();

-- Un técnico con especialidades vigentes no deja de ser técnico.
CREATE FUNCTION fn_personal_rol_estable()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF OLD.rol = 'Técnico' AND NEW.rol <> 'Técnico'
       AND EXISTS (SELECT 1 FROM especialidad_tecnico
                   WHERE tecnico_id = OLD.personal_id
                     AND (fecha_fin IS NULL OR fecha_fin >= current_date)) THEN
        PERFORM fn_error(format('G02-INT: el personal %s tiene especialidades vigentes; cierre su vigencia antes de cambiar el rol',
                                OLD.personal_id));
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_personal_rol_estable
    BEFORE UPDATE OF rol ON personal
    FOR EACH ROW EXECUTE FUNCTION fn_personal_rol_estable();

-- =====================================================================
-- 3. ORDEN DE TRABAJO, FACULTADES Y OBJETOS
-- =====================================================================

-- Antes de insertar: instantánea de la placa, receptor activo, estado inicial.
CREATE FUNCTION fn_orden_antes_insertar()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.placa_ingreso IS NULL THEN
        SELECT placa INTO NEW.placa_ingreso FROM vehiculo WHERE vin = NEW.vin;
    END IF;
    PERFORM fn_exigir_personal(NEW.receptor_id, NULL, 'G02-INT: recepción de la orden');
    IF NEW.estado_actual IS DISTINCT FROM 'Recibida' THEN
        PERFORM fn_error(format('G02-P03: una orden nueva inicia en Recibida (se indicó %s)', NEW.estado_actual));
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_orden_antes_insertar
    BEFORE INSERT ON orden_trabajo
    FOR EACH ROW EXECUTE FUNCTION fn_orden_antes_insertar();

-- Después de insertar (compatibilidad con el alta del Lab03, §4.3):
--   * crea las facultades explícitas de la visita (D2):
--       - cliente facturado: Aprobar y Retirar como Titular;
--       - autorizador distinto del facturado: Aprobar por Designación.
--   * registra la promesa original si el alta trae fecha prometida.
CREATE FUNCTION fn_orden_despues_insertar()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO facultad_orden (orden_id, cliente_id, tipo_facultad, fuente, otorgada_por_cliente_id,
                                medio_verificacion, vigente_desde, registrada_por_id)
    VALUES (NEW.orden_id, NEW.cliente_factura_id, 'Aprobar', 'Titular', NULL,
            'Titular de la orden: identificación verificada en la recepción', NEW.fecha_hora_recepcion, NEW.receptor_id),
           (NEW.orden_id, NEW.cliente_factura_id, 'Retirar', 'Titular', NULL,
            'Titular de la orden: identificación verificada en la recepción', NEW.fecha_hora_recepcion, NEW.receptor_id);

    IF NEW.autorizador_cliente_id <> NEW.cliente_factura_id THEN
        INSERT INTO facultad_orden (orden_id, cliente_id, tipo_facultad, fuente, otorgada_por_cliente_id,
                                    medio_verificacion, vigente_desde, registrada_por_id)
        VALUES (NEW.orden_id, NEW.autorizador_cliente_id, 'Aprobar', 'Designación', NEW.cliente_factura_id,
                'Designado por el titular al registrar la recepción', NEW.fecha_hora_recepcion, NEW.receptor_id);
    END IF;

    IF NEW.fecha_prometida_actual IS NOT NULL THEN
        INSERT INTO historial_fecha_prometida (orden_id, fecha_nueva, fecha_hora_comunicacion,
                                               medio_comunicacion, motivo, personal_id)
        VALUES (NEW.orden_id, NEW.fecha_prometida_actual, NEW.fecha_hora_recepcion,
                'Presencial', 'Promesa original comunicada en la recepción', NEW.receptor_id);
    END IF;
    RETURN NULL;
END;
$$;

CREATE TRIGGER trg_orden_despues_insertar
    AFTER INSERT ON orden_trabajo
    FOR EACH ROW EXECUTE FUNCTION fn_orden_despues_insertar();

-- Antes de actualizar:
--   * los datos de la recepción y los roles de la visita no se reescriben
--     (RN-04, RN-05, D12: un cambio de propietario no reescribe visitas);
--   * estado_actual y fecha_prometida_actual solo cambian vía historial (D4).
CREATE FUNCTION fn_orden_antes_actualizar()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF (NEW.orden_id, NEW.vin, NEW.placa_ingreso, NEW.cliente_factura_id, NEW.entregado_por_cliente_id,
        NEW.autorizador_cliente_id, NEW.receptor_id, NEW.fecha_hora_recepcion, NEW.kilometraje_ingreso,
        NEW.nivel_combustible, NEW.motivo_informado)
       IS DISTINCT FROM
       (OLD.orden_id, OLD.vin, OLD.placa_ingreso, OLD.cliente_factura_id, OLD.entregado_por_cliente_id,
        OLD.autorizador_cliente_id, OLD.receptor_id, OLD.fecha_hora_recepcion, OLD.kilometraje_ingreso,
        OLD.nivel_combustible, OLD.motivo_informado) THEN
        PERFORM fn_error(format('G02-INT: los datos de recepción y los roles de la orden %s quedan fijados por visita y no se modifican',
                                OLD.orden_id));
    END IF;

    IF (NEW.estado_actual IS DISTINCT FROM OLD.estado_actual
        OR NEW.fecha_prometida_actual IS DISTINCT FROM OLD.fecha_prometida_actual)
       AND coalesce(current_setting('taller.via_historial', true), 'off') <> 'on' THEN
        PERFORM fn_error(format('G02-P03: estado_actual y fecha_prometida_actual de la orden %s solo cambian mediante su historial '
                                '(use fn_cambiar_estado_orden / fn_cambiar_fecha_prometida)', OLD.orden_id));
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_orden_antes_actualizar
    BEFORE UPDATE ON orden_trabajo
    FOR EACH ROW EXECUTE FUNCTION fn_orden_antes_actualizar();

-- Una orden nunca se borra: cancelar no borra nada (P03).
CREATE FUNCTION fn_orden_sin_borrado()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    PERFORM fn_error(format('G02-INT: la orden %s no se elimina; use el estado Cancelada', OLD.orden_id));
    RETURN NULL;
END;
$$;

CREATE TRIGGER trg_orden_sin_borrado
    BEFORE DELETE ON orden_trabajo
    FOR EACH ROW EXECUTE FUNCTION fn_orden_sin_borrado();

-- Al confirmar: la orden tiene estado inicial y sus valores actuales
-- coinciden con la última fila de cada historial.
CREATE FUNCTION fn_verificar_coherencia_orden()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_orden        orden_trabajo;
    v_estado       text;
    v_promesa      timestamptz;
    v_hay_promesa  boolean;
BEGIN
    SELECT * INTO v_orden FROM orden_trabajo WHERE orden_id = NEW.orden_id;

    SELECT estado INTO v_estado
    FROM historial_orden WHERE orden_id = NEW.orden_id
    ORDER BY secuencia DESC LIMIT 1;
    IF NOT FOUND THEN
        PERFORM fn_error(format('G02-P03: la orden %s no tiene su estado inicial en historial_orden', NEW.orden_id));
    END IF;
    IF v_estado IS DISTINCT FROM v_orden.estado_actual THEN
        PERFORM fn_error(format('G02-P03: estado_actual (%s) de la orden %s no coincide con su historial (%s)',
                                v_orden.estado_actual, NEW.orden_id, v_estado));
    END IF;

    SELECT fecha_nueva, true INTO v_promesa, v_hay_promesa
    FROM historial_fecha_prometida WHERE orden_id = NEW.orden_id
    ORDER BY secuencia DESC LIMIT 1;
    IF v_promesa IS DISTINCT FROM v_orden.fecha_prometida_actual THEN
        PERFORM fn_error(format('G02-P03: fecha_prometida_actual (%s) de la orden %s no coincide con su historial (%s)',
                                v_orden.fecha_prometida_actual, NEW.orden_id, v_promesa));
    END IF;
    RETURN NULL;
END;
$$;

CREATE CONSTRAINT TRIGGER trg_orden_coherencia
    AFTER INSERT OR UPDATE ON orden_trabajo
    DEFERRABLE INITIALLY DEFERRED
    FOR EACH ROW EXECUTE FUNCTION fn_verificar_coherencia_orden();

CREATE CONSTRAINT TRIGGER trg_historial_orden_coherencia
    AFTER INSERT ON historial_orden
    DEFERRABLE INITIALLY DEFERRED
    FOR EACH ROW EXECUTE FUNCTION fn_verificar_coherencia_orden();

CREATE CONSTRAINT TRIGGER trg_hfp_coherencia
    AFTER INSERT ON historial_fecha_prometida
    DEFERRABLE INITIALLY DEFERRED
    FOR EACH ROW EXECUTE FUNCTION fn_verificar_coherencia_orden();

-- FACULTAD_ORDEN: la designación o representación la otorga el titular de
-- la visita; solo se admite revocar (fijar vigente_hasta una vez).
CREATE FUNCTION fn_facultad_validar()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_orden orden_trabajo;
BEGIN
    IF TG_OP = 'DELETE' THEN
        PERFORM fn_error(format('G02-INM: la facultad %s no se elimina; revóquela fijando vigente_hasta', OLD.facultad_id));
    END IF;

    IF TG_OP = 'UPDATE' THEN
        IF OLD.vigente_hasta IS NOT NULL
           OR NEW.vigente_hasta IS NULL
           OR (NEW.facultad_id, NEW.orden_id, NEW.cliente_id, NEW.tipo_facultad, NEW.fuente,
               NEW.otorgada_por_cliente_id, NEW.medio_verificacion, NEW.vigente_desde, NEW.registrada_por_id)
              IS DISTINCT FROM
              (OLD.facultad_id, OLD.orden_id, OLD.cliente_id, OLD.tipo_facultad, OLD.fuente,
               OLD.otorgada_por_cliente_id, OLD.medio_verificacion, OLD.vigente_desde, OLD.registrada_por_id) THEN
            PERFORM fn_error(format('G02-INM: la facultad %s solo admite revocación (fijar vigente_hasta una única vez)',
                                    OLD.facultad_id));
        END IF;
        RETURN NEW;
    END IF;

    SELECT * INTO v_orden FROM orden_trabajo WHERE orden_id = NEW.orden_id;
    IF fn_es_terminal(v_orden.estado_actual) THEN
        PERFORM fn_error(format('G02-INT: la orden %s está %s; no se registran facultades nuevas',
                                NEW.orden_id, v_orden.estado_actual));
    END IF;
    IF NEW.fuente <> 'Titular' AND NEW.otorgada_por_cliente_id <> v_orden.cliente_factura_id THEN
        PERFORM fn_error(format('G02-INT: solo el titular de la orden %s (cliente %s) puede designar o hacerse representar',
                                NEW.orden_id, v_orden.cliente_factura_id));
    END IF;
    IF NEW.vigente_desde < v_orden.fecha_hora_recepcion THEN
        PERFORM fn_error(format('G02-INT: la facultad no puede regir antes de la recepción de la orden %s', NEW.orden_id));
    END IF;
    PERFORM fn_exigir_personal(NEW.registrada_por_id, NULL, 'G02-INT: registro de facultad');
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_facultad_validar
    BEFORE INSERT OR UPDATE OR DELETE ON facultad_orden
    FOR EACH ROW EXECUTE FUNCTION fn_facultad_validar();

-- OBJETO_DANO: solo se puede confirmar (false -> true); no se borra.
CREATE FUNCTION fn_objeto_dano_validar()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_estado text;
BEGIN
    IF TG_OP = 'DELETE' THEN
        PERFORM fn_error(format('G02-INM: el detalle %s de objetos/daños no se elimina', OLD.detalle_id));
    ELSIF TG_OP = 'UPDATE' THEN
        IF (NEW.detalle_id, NEW.orden_id, NEW.tipo_detalle, NEW.descripcion)
           IS DISTINCT FROM (OLD.detalle_id, OLD.orden_id, OLD.tipo_detalle, OLD.descripcion)
           OR (OLD.confirmado_cliente AND NOT NEW.confirmado_cliente) THEN
            PERFORM fn_error(format('G02-INM: el detalle %s solo admite confirmación del cliente', OLD.detalle_id));
        END IF;
        RETURN NEW;
    END IF;
    SELECT estado_actual INTO v_estado FROM orden_trabajo WHERE orden_id = NEW.orden_id;
    IF fn_es_terminal(v_estado) THEN
        PERFORM fn_error(format('G02-INT: la orden %s está %s', NEW.orden_id, v_estado));
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_objeto_dano_validar
    BEFORE INSERT OR UPDATE OR DELETE ON objeto_dano
    FOR EACH ROW EXECUTE FUNCTION fn_objeto_dano_validar();

-- =====================================================================
-- 4. HISTORIAL DE ESTADOS DE LA ORDEN (G02-P03)
-- =====================================================================

CREATE FUNCTION fn_historial_orden_antes()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_orden      orden_trabajo;
    v_max_sec    integer;
    v_ultima     timestamptz;
    v_transicion transicion_estado_orden;
BEGIN
    -- El bloqueo de la orden serializa los cambios: la secuencia es inequívoca.
    v_orden := fn_bloquear_orden(NEW.orden_id, 'G02-P03');
    PERFORM fn_exigir_personal(NEW.personal_id, NULL, 'G02-P03: cambio de estado');

    SELECT max(secuencia), max(fecha_hora) INTO v_max_sec, v_ultima
    FROM historial_orden WHERE orden_id = NEW.orden_id;

    IF NEW.secuencia IS NOT NULL AND NEW.secuencia <> coalesce(v_max_sec, 0) + 1 THEN
        PERFORM fn_error(format('G02-P03: la secuencia la asigna el sistema (esperada %s, indicada %s)',
                                coalesce(v_max_sec, 0) + 1, NEW.secuencia));
    END IF;

    IF v_max_sec IS NULL THEN
        -- Estado inicial (alta de la orden).
        NEW.secuencia := 1;
        NEW.estado_anterior := NULL;
        IF NEW.estado <> 'Recibida' THEN
            PERFORM fn_error(format('G02-P03: el primer estado de la orden %s debe ser Recibida', NEW.orden_id));
        END IF;
        IF NEW.fecha_hora < v_orden.fecha_hora_recepcion THEN
            PERFORM fn_error(format('G02-P03: el estado inicial no puede ser anterior a la recepción de la orden %s', NEW.orden_id));
        END IF;
        RETURN NEW;
    END IF;

    NEW.secuencia := v_max_sec + 1;
    IF NEW.estado_anterior IS NOT NULL AND NEW.estado_anterior <> v_orden.estado_actual THEN
        PERFORM fn_error(format('G02-P03: estado_anterior lo asigna el sistema (actual %s, indicado %s)',
                                v_orden.estado_actual, NEW.estado_anterior));
    END IF;
    NEW.estado_anterior := v_orden.estado_actual;

    IF NEW.estado = v_orden.estado_actual THEN
        PERFORM fn_error(format('G02-P03: la orden %s ya está en %s', NEW.orden_id, NEW.estado));
    END IF;

    SELECT * INTO v_transicion FROM transicion_estado_orden
    WHERE estado_desde = v_orden.estado_actual AND estado_hacia = NEW.estado;
    IF NOT FOUND THEN
        PERFORM fn_error(format('G02-P03: transición no permitida de %s a %s en la orden %s',
                                v_orden.estado_actual, NEW.estado, NEW.orden_id));
    END IF;
    IF v_transicion.requiere_motivo AND btrim(coalesce(NEW.motivo, '')) = '' THEN
        PERFORM fn_error(format('G02-P03: la transición %s -> %s requiere motivo', v_orden.estado_actual, NEW.estado));
    END IF;

    -- Mismo instante permitido; retroceder en el tiempo, no.
    IF NEW.fecha_hora < v_ultima THEN
        PERFORM fn_error(format('G02-P03: la fecha_hora %s es anterior al último cambio de estado (%s)', NEW.fecha_hora, v_ultima));
    END IF;

    -- Reglas de contexto del caso.
    IF v_orden.estado_actual = 'Recibida' AND NEW.estado <> 'Cancelada'
       AND EXISTS (SELECT 1 FROM objeto_dano WHERE orden_id = NEW.orden_id AND NOT confirmado_cliente) THEN
        PERFORM fn_error(format('G02-P03: la orden %s tiene objetos/daños sin confirmar por el cliente (RN-06)', NEW.orden_id));
    END IF;
    IF NEW.estado = 'Pendiente autorización'
       AND NOT EXISTS (SELECT 1 FROM propuesta WHERE orden_id = NEW.orden_id AND estado = 'Presentada') THEN
        PERFORM fn_error(format('G02-P03: la orden %s no tiene ninguna propuesta presentada', NEW.orden_id));
    END IF;
    IF NEW.estado = 'Autorizada'
       AND NOT EXISTS (SELECT 1 FROM v_autorizacion_ejecutable WHERE orden_id = NEW.orden_id) THEN
        PERFORM fn_error(format('G02-P03: la orden %s no tiene ninguna labor con decisión aplicable Aceptada', NEW.orden_id));
    END IF;
    IF NEW.estado = 'Lista entrega' THEN
        IF EXISTS (SELECT 1 FROM labor WHERE orden_id = NEW.orden_id AND estado_labor IN ('En proceso', 'Suspendida')) THEN
            PERFORM fn_error(format('G02-P03: la orden %s tiene labores en proceso o suspendidas', NEW.orden_id));
        END IF;
        IF NOT EXISTS (SELECT 1 FROM labor WHERE orden_id = NEW.orden_id AND estado_labor = 'Completada') THEN
            PERFORM fn_error(format('G02-P03: la orden %s no tiene ninguna labor completada', NEW.orden_id));
        END IF;
    END IF;
    IF NEW.estado = 'Entregada' AND NOT EXISTS (SELECT 1 FROM entrega WHERE orden_id = NEW.orden_id) THEN
        PERFORM fn_error(format('G02-P03: la orden %s no tiene entrega registrada', NEW.orden_id));
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_historial_orden_antes
    BEFORE INSERT ON historial_orden
    FOR EACH ROW EXECUTE FUNCTION fn_historial_orden_antes();

-- Valor actual + historia en la misma transacción.
CREATE FUNCTION fn_historial_orden_despues()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.secuencia > 1 THEN
        PERFORM set_config('taller.via_historial', 'on', true);
        UPDATE orden_trabajo SET estado_actual = NEW.estado WHERE orden_id = NEW.orden_id;
        PERFORM set_config('taller.via_historial', 'off', true);
    END IF;
    RETURN NULL;
END;
$$;

CREATE TRIGGER trg_historial_orden_despues
    AFTER INSERT ON historial_orden
    FOR EACH ROW EXECUTE FUNCTION fn_historial_orden_despues();

-- =====================================================================
-- 5. HISTORIAL DE FECHA PROMETIDA (G02-P03)
-- =====================================================================

CREATE FUNCTION fn_hfp_antes()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_orden          orden_trabajo;
    v_max_sec        integer;
    v_ultima_com     timestamptz;
BEGIN
    v_orden := fn_bloquear_orden(NEW.orden_id, 'G02-P03');
    PERFORM fn_exigir_personal(NEW.personal_id, NULL, 'G02-P03: cambio de fecha prometida');

    IF fn_es_terminal(v_orden.estado_actual) THEN
        PERFORM fn_error(format('G02-P03: la orden %s está %s; su fecha prometida ya no se modifica',
                                NEW.orden_id, v_orden.estado_actual));
    END IF;

    SELECT max(secuencia), max(fecha_hora_comunicacion) INTO v_max_sec, v_ultima_com
    FROM historial_fecha_prometida WHERE orden_id = NEW.orden_id;

    IF NEW.secuencia IS NOT NULL AND NEW.secuencia <> coalesce(v_max_sec, 0) + 1 THEN
        PERFORM fn_error(format('G02-P03: la secuencia la asigna el sistema (esperada %s, indicada %s)',
                                coalesce(v_max_sec, 0) + 1, NEW.secuencia));
    END IF;
    NEW.secuencia := coalesce(v_max_sec, 0) + 1;

    IF v_max_sec IS NULL THEN
        NEW.fecha_anterior := NULL;                       -- promesa original
    ELSE
        IF NEW.fecha_anterior IS NOT NULL AND NEW.fecha_anterior <> v_orden.fecha_prometida_actual THEN
            PERFORM fn_error(format('G02-P03: fecha_anterior la asigna el sistema (actual %s, indicada %s)',
                                    v_orden.fecha_prometida_actual, NEW.fecha_anterior));
        END IF;
        NEW.fecha_anterior := v_orden.fecha_prometida_actual;
        IF btrim(coalesce(NEW.motivo, '')) = '' THEN
            PERFORM fn_error(format('G02-P03: el cambio de fecha prometida de la orden %s requiere motivo (RN-07)', NEW.orden_id));
        END IF;
        IF NEW.fecha_hora_comunicacion < v_ultima_com THEN
            PERFORM fn_error(format('G02-P03: la comunicación %s es anterior a la última registrada (%s)',
                                    NEW.fecha_hora_comunicacion, v_ultima_com));
        END IF;
    END IF;

    IF NEW.fecha_hora_comunicacion < v_orden.fecha_hora_recepcion THEN
        PERFORM fn_error(format('G02-P03: la comunicación no puede ser anterior a la recepción de la orden %s', NEW.orden_id));
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_hfp_antes
    BEFORE INSERT ON historial_fecha_prometida
    FOR EACH ROW EXECUTE FUNCTION fn_hfp_antes();

CREATE FUNCTION fn_hfp_despues()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    PERFORM set_config('taller.via_historial', 'on', true);
    UPDATE orden_trabajo SET fecha_prometida_actual = NEW.fecha_nueva
    WHERE orden_id = NEW.orden_id AND fecha_prometida_actual IS DISTINCT FROM NEW.fecha_nueva;
    PERFORM set_config('taller.via_historial', 'off', true);
    RETURN NULL;
END;
$$;

CREATE TRIGGER trg_hfp_despues
    AFTER INSERT ON historial_fecha_prometida
    FOR EACH ROW EXECUTE FUNCTION fn_hfp_despues();

-- =====================================================================
-- 6. DIAGNÓSTICO Y PROPUESTA (G02-P01)
-- =====================================================================

-- HALLAZGO: autor técnico activo (D1), momento coherente, orden abierta.
CREATE FUNCTION fn_hallazgo_validar()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_orden orden_trabajo;
BEGIN
    IF TG_OP = 'UPDATE' AND (NEW.orden_id, NEW.diagnosticado_por_id, NEW.fecha_hora)
                            IS DISTINCT FROM (OLD.orden_id, OLD.diagnosticado_por_id, OLD.fecha_hora) THEN
        PERFORM fn_error(format('G02-INT: la orden, el autor y el momento del hallazgo %s no se modifican', OLD.hallazgo_id));
    END IF;
    IF TG_OP = 'INSERT' THEN
        PERFORM fn_exigir_personal(NEW.diagnosticado_por_id, ARRAY['Técnico'], 'G02-INT: autor del hallazgo');
        SELECT * INTO v_orden FROM orden_trabajo WHERE orden_id = NEW.orden_id;
        IF FOUND AND fn_es_terminal(v_orden.estado_actual) THEN
            PERFORM fn_error(format('G02-INT: la orden %s está %s', NEW.orden_id, v_orden.estado_actual));
        END IF;
        IF FOUND AND NEW.fecha_hora < v_orden.fecha_hora_recepcion THEN
            PERFORM fn_error(format('G02-INT: el hallazgo no puede ser anterior a la recepción de la orden %s', NEW.orden_id));
        END IF;
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_hallazgo_validar
    BEFORE INSERT OR UPDATE ON hallazgo
    FOR EACH ROW EXECUTE FUNCTION fn_hallazgo_validar();

-- PROPUESTA: versión consecutiva bajo bloqueo; se crea en Borrador; una vez
-- Presentada es inmutable (RN-10).
CREATE FUNCTION fn_propuesta_validar()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_orden     orden_trabajo;
    v_max_ver   integer;
    v_base      propuesta;
BEGIN
    IF TG_OP = 'DELETE' THEN
        IF OLD.estado = 'Presentada' THEN
            PERFORM fn_error(format('G02-P01: la propuesta %s (v%s) ya fue presentada y es inmutable', OLD.propuesta_id, OLD.version));
        END IF;
        RETURN OLD;
    END IF;

    IF TG_OP = 'UPDATE' THEN
        IF OLD.estado = 'Presentada' THEN
            PERFORM fn_error(format('G02-P01: la propuesta %s (v%s) ya fue presentada y es inmutable', OLD.propuesta_id, OLD.version));
        END IF;
        IF (NEW.propuesta_id, NEW.orden_id, NEW.version, NEW.propuesta_base_id)
           IS DISTINCT FROM (OLD.propuesta_id, OLD.orden_id, OLD.version, OLD.propuesta_base_id) THEN
            PERFORM fn_error('G02-P01: la orden, la versión y la base de una propuesta no se modifican');
        END IF;
        IF NEW.estado = 'Presentada' THEN
            IF NOT EXISTS (SELECT 1 FROM linea_propuesta WHERE propuesta_id = NEW.propuesta_id) THEN
                PERFORM fn_error(format('G02-P01: la propuesta %s no tiene líneas y no puede presentarse', NEW.propuesta_id));
            END IF;
            SELECT * INTO v_orden FROM orden_trabajo WHERE orden_id = NEW.orden_id;
            IF NEW.fecha_hora_presentacion < v_orden.fecha_hora_recepcion THEN
                PERFORM fn_error('G02-P01: la presentación no puede ser anterior a la recepción');
            END IF;
        END IF;
        RETURN NEW;
    END IF;

    -- INSERT
    v_orden := fn_bloquear_orden(NEW.orden_id, 'G02-P01');
    IF fn_es_terminal(v_orden.estado_actual) THEN
        PERFORM fn_error(format('G02-P01: la orden %s está %s; no admite propuestas', NEW.orden_id, v_orden.estado_actual));
    END IF;
    IF NEW.estado <> 'Borrador' THEN
        PERFORM fn_error('G02-P01: una propuesta se crea en Borrador y se presenta junto con sus líneas');
    END IF;
    PERFORM fn_exigir_personal(NEW.presentada_por_id, NULL, 'G02-P01: propuesta');

    SELECT max(version) INTO v_max_ver FROM propuesta WHERE orden_id = NEW.orden_id;
    IF NEW.version <> coalesce(v_max_ver, 0) + 1 THEN
        PERFORM fn_error(format('G02-P01: la siguiente versión de la orden %s debe ser %s (se indicó %s)',
                                NEW.orden_id, coalesce(v_max_ver, 0) + 1, NEW.version));
    END IF;
    IF NEW.propuesta_base_id IS NOT NULL THEN
        SELECT * INTO v_base FROM propuesta WHERE propuesta_id = NEW.propuesta_base_id;
        IF FOUND AND v_base.estado <> 'Presentada' THEN
            PERFORM fn_error(format('G02-P01: la versión base %s no está presentada', NEW.propuesta_base_id));
        END IF;
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_propuesta_validar
    BEFORE INSERT OR UPDATE OR DELETE ON propuesta
    FOR EACH ROW EXECUTE FUNCTION fn_propuesta_validar();

-- LINEA_PROPUESTA y REPUESTO_PROPUESTO: inmutables si la propuesta está
-- Presentada; la labor ofrecida debe seguir abierta.
CREATE FUNCTION fn_linea_validar()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_propuesta_id bigint;
    v_labor_id     bigint;
    v_estado       text;
    v_estado_labor text;
BEGIN
    IF TG_OP = 'DELETE' THEN
        v_propuesta_id := OLD.propuesta_id;
    ELSE
        v_propuesta_id := NEW.propuesta_id;
    END IF;
    SELECT estado INTO v_estado FROM propuesta WHERE propuesta_id = v_propuesta_id;
    IF v_estado = 'Presentada' THEN
        PERFORM fn_error(format('G02-P01: la propuesta %s ya fue presentada; sus líneas y repuestos son inmutables (%s sobre %s)',
                                v_propuesta_id, TG_OP, TG_TABLE_NAME));
    END IF;
    IF TG_OP = 'INSERT' AND TG_TABLE_NAME = 'linea_propuesta' THEN
        v_labor_id := NEW.labor_id;
        SELECT estado_labor INTO v_estado_labor FROM labor WHERE labor_id = v_labor_id;
        IF v_estado_labor IN ('Anulada', 'Completada') THEN
            PERFORM fn_error(format('G02-P01: la labor %s está %s y no puede ofrecerse en una versión nueva',
                                    v_labor_id, v_estado_labor));
        END IF;
    END IF;
    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_linea_validar
    BEFORE INSERT OR UPDATE OR DELETE ON linea_propuesta
    FOR EACH ROW EXECUTE FUNCTION fn_linea_validar();

CREATE TRIGGER trg_repuesto_propuesto_validar
    BEFORE INSERT OR UPDATE OR DELETE ON repuesto_propuesto
    FOR EACH ROW EXECUTE FUNCTION fn_linea_validar();

-- AUTORIZACION_LABOR: decisión con facultad 'Aprobar' vigente del mismo
-- cliente, sobre la línea de la versión vigente, nunca hacia atrás en el
-- tiempo. El bloqueo de la línea serializa decisiones concurrentes (RN-11,
-- RN-12, D2).
CREATE FUNCTION fn_autorizacion_validar()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_prop       propuesta;
    v_labor      labor;
    v_facultad   facultad_orden;
    v_orden      orden_trabajo;
    v_vigente    integer;
    v_ultima     timestamptz;
BEGIN
    -- Serializa decisiones sobre la misma línea.
    PERFORM 1 FROM linea_propuesta
    WHERE propuesta_id = NEW.propuesta_id AND labor_id = NEW.labor_id FOR UPDATE;
    IF NOT FOUND THEN
        PERFORM fn_error(format('G02-P01: la labor %s no forma parte de la propuesta %s', NEW.labor_id, NEW.propuesta_id));
    END IF;

    SELECT * INTO v_prop FROM propuesta WHERE propuesta_id = NEW.propuesta_id;
    IF v_prop.estado <> 'Presentada' THEN
        PERFORM fn_error(format('G02-P01: la propuesta %s no está presentada', NEW.propuesta_id));
    END IF;
    IF NEW.fecha_hora < v_prop.fecha_hora_presentacion THEN
        PERFORM fn_error(format('G02-P01: la decisión (%s) no puede ser anterior a la presentación de la versión (%s)',
                                NEW.fecha_hora, v_prop.fecha_hora_presentacion));
    END IF;

    SELECT * INTO v_orden FROM orden_trabajo WHERE orden_id = v_prop.orden_id;
    IF fn_es_terminal(v_orden.estado_actual) THEN
        PERFORM fn_error(format('G02-P01: la orden %s está %s', v_orden.orden_id, v_orden.estado_actual));
    END IF;

    SELECT * INTO v_labor FROM labor WHERE labor_id = NEW.labor_id;
    IF v_labor.estado_labor NOT IN ('Pendiente', 'Suspendida') THEN
        PERFORM fn_error(format('G02-P01: la labor %s está %s y ya no admite decisiones', NEW.labor_id, v_labor.estado_labor));
    END IF;

    -- Solo se decide sobre la versión vigente de la labor (regla 5.1.1).
    SELECT max(p.version) INTO v_vigente
    FROM linea_propuesta lp JOIN propuesta p ON p.propuesta_id = lp.propuesta_id
    WHERE lp.labor_id = NEW.labor_id AND p.estado = 'Presentada';
    IF v_prop.version <> v_vigente THEN
        PERFORM fn_error(format('G02-P01: la versión %s no es la vigente para la labor %s; la vigente es la versión %s',
                                v_prop.version, NEW.labor_id, v_vigente));
    END IF;

    -- Facultad: tipo Aprobar, del MISMO cliente, de ESTA orden, vigente en fecha_hora.
    SELECT * INTO v_facultad FROM facultad_orden WHERE facultad_id = NEW.facultad_id;
    IF NOT FOUND
       OR v_facultad.orden_id <> v_prop.orden_id
       OR v_facultad.cliente_id <> NEW.cliente_id
       OR v_facultad.tipo_facultad <> 'Aprobar'
       OR NEW.fecha_hora < v_facultad.vigente_desde
       OR (v_facultad.vigente_hasta IS NOT NULL AND NEW.fecha_hora >= v_facultad.vigente_hasta) THEN
        PERFORM fn_error(format('G02-P01: el cliente %s no tiene facultad vigente para aprobar en la orden %s',
                                NEW.cliente_id, v_prop.orden_id));
    END IF;

    SELECT max(fecha_hora) INTO v_ultima FROM autorizacion_labor
    WHERE propuesta_id = NEW.propuesta_id AND labor_id = NEW.labor_id;
    IF NEW.fecha_hora < v_ultima THEN
        PERFORM fn_error(format('G02-P01: la decisión (%s) es anterior a la última decisión registrada sobre la línea (%s)',
                                NEW.fecha_hora, v_ultima));
    END IF;

    PERFORM fn_exigir_personal(NEW.registrado_por_id, NULL, 'G02-P01: registro de decisión');
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_autorizacion_validar
    BEFORE INSERT ON autorizacion_labor
    FOR EACH ROW EXECUTE FUNCTION fn_autorizacion_validar();

-- =====================================================================
-- 7. LABOR Y SU HISTORIAL (G02-P02)
-- =====================================================================

CREATE FUNCTION fn_labor_validar()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_estado_orden text;
    v_resultado    text;
BEGIN
    IF TG_OP = 'DELETE' THEN
        PERFORM fn_error(format('G02-INM: la labor %s no se elimina; anúlela con motivo', OLD.labor_id));
    END IF;

    IF TG_OP = 'UPDATE' THEN
        IF (NEW.labor_id, NEW.orden_id, NEW.hallazgo_id, NEW.descripcion, NEW.es_emergencia, NEW.labor_revisada_id,
            NEW.prueba_origen_id, NEW.creada_por_id, NEW.creada_en)
           IS DISTINCT FROM
           (OLD.labor_id, OLD.orden_id, OLD.hallazgo_id, OLD.descripcion, OLD.es_emergencia, OLD.labor_revisada_id,
            OLD.prueba_origen_id, OLD.creada_por_id, OLD.creada_en) THEN
            PERFORM fn_error(format('G02-INM: la labor %s no se reescribe; registre un retrabajo o una labor nueva (RN-15)', OLD.labor_id));
        END IF;
        IF NEW.estado_labor IS DISTINCT FROM OLD.estado_labor
           AND coalesce(current_setting('taller.via_historial_labor', true), 'off') <> 'on' THEN
            PERFORM fn_error(format('G02-P02: el estado de la labor %s solo cambia mediante historial_labor', OLD.labor_id));
        END IF;
        RETURN NEW;
    END IF;

    -- INSERT
    SELECT estado_actual INTO v_estado_orden FROM orden_trabajo WHERE orden_id = NEW.orden_id;
    IF fn_es_terminal(v_estado_orden) THEN
        PERFORM fn_error(format('G02-P02: la orden %s está %s; no admite labores nuevas', NEW.orden_id, v_estado_orden));
    END IF;
    IF NEW.estado_labor <> 'Pendiente' THEN
        PERFORM fn_error('G02-P02: una labor nueva inicia en Pendiente');
    END IF;
    PERFORM fn_exigir_personal(NEW.creada_por_id, NULL, 'G02-P02: registro de labor');
    IF NEW.prueba_origen_id IS NOT NULL THEN
        SELECT resultado INTO v_resultado FROM prueba WHERE prueba_id = NEW.prueba_origen_id;
        IF v_resultado IS DISTINCT FROM 'Desfavorable' THEN
            PERFORM fn_error(format('G02-P02: un retrabajo solo se origina en una prueba Desfavorable (la prueba %s es %s)',
                                    NEW.prueba_origen_id, coalesce(v_resultado, 'inexistente')));
        END IF;
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_labor_validar
    BEFORE INSERT OR UPDATE OR DELETE ON labor
    FOR EACH ROW EXECUTE FUNCTION fn_labor_validar();

-- Toda labor nace con su primer estado en el historial.
CREATE FUNCTION fn_labor_estado_inicial()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO historial_labor (labor_id, estado_nuevo, fecha_hora, personal_id, motivo)
    VALUES (NEW.labor_id, 'Pendiente', NEW.creada_en, NEW.creada_por_id, 'Registro de la labor');
    RETURN NULL;
END;
$$;

CREATE TRIGGER trg_labor_estado_inicial
    AFTER INSERT ON labor
    FOR EACH ROW EXECUTE FUNCTION fn_labor_estado_inicial();

CREATE FUNCTION fn_historial_labor_antes()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_labor        labor;
    v_estado_orden text;
    v_max_sec      integer;
    v_ultima       timestamptz;
    v_aplicable    bigint;
    v_situacion    text;
    v_dep          bigint;
    v_prueba       prueba;
BEGIN
    v_labor := fn_bloquear_labor(NEW.labor_id, 'G02-P02');
    PERFORM fn_exigir_personal(NEW.personal_id, NULL, 'G02-P02: cambio de estado de labor');

    SELECT max(secuencia), max(fecha_hora) INTO v_max_sec, v_ultima
    FROM historial_labor WHERE labor_id = NEW.labor_id;

    IF NEW.secuencia IS NOT NULL AND NEW.secuencia <> coalesce(v_max_sec, 0) + 1 THEN
        PERFORM fn_error(format('G02-P02: la secuencia la asigna el sistema (esperada %s, indicada %s)',
                                coalesce(v_max_sec, 0) + 1, NEW.secuencia));
    END IF;

    IF v_max_sec IS NULL THEN
        NEW.secuencia := 1;
        NEW.estado_anterior := NULL;
        RETURN NEW;
    END IF;

    NEW.secuencia := v_max_sec + 1;
    NEW.estado_anterior := v_labor.estado_labor;

    IF NOT ((v_labor.estado_labor = 'Pendiente'  AND NEW.estado_nuevo IN ('En proceso', 'Anulada'))
         OR (v_labor.estado_labor = 'En proceso' AND NEW.estado_nuevo IN ('Completada', 'Suspendida', 'Anulada'))
         OR (v_labor.estado_labor = 'Suspendida' AND NEW.estado_nuevo IN ('En proceso', 'Anulada'))) THEN
        PERFORM fn_error(format('G02-P02: transición de labor no permitida de %s a %s (labor %s)',
                                v_labor.estado_labor, NEW.estado_nuevo, NEW.labor_id));
    END IF;
    IF NEW.estado_nuevo IN ('Suspendida', 'Anulada') AND btrim(coalesce(NEW.motivo, '')) = '' THEN
        PERFORM fn_error(format('G02-P02: pasar la labor %s a %s requiere motivo', NEW.labor_id, NEW.estado_nuevo));
    END IF;
    IF NEW.fecha_hora < v_ultima THEN
        PERFORM fn_error(format('G02-P02: la fecha_hora %s es anterior al último cambio de la labor (%s)', NEW.fecha_hora, v_ultima));
    END IF;

    SELECT estado_actual INTO v_estado_orden FROM orden_trabajo WHERE orden_id = v_labor.orden_id;
    IF NEW.estado_nuevo IN ('En proceso', 'Completada') AND fn_es_terminal(v_estado_orden) THEN
        PERFORM fn_error(format('G02-P02: la orden %s está %s', v_labor.orden_id, v_estado_orden));
    END IF;

    IF NEW.estado_nuevo = 'En proceso' THEN
        -- RN-15: todas las labores requeridas deben estar completadas.
        SELECT d.requiere_labor_id INTO v_dep
        FROM labor_dependencia d JOIN labor r ON r.labor_id = d.requiere_labor_id
        WHERE d.labor_id = NEW.labor_id AND r.estado_labor <> 'Completada'
        ORDER BY d.requiere_labor_id LIMIT 1;
        IF FOUND THEN
            PERFORM fn_error(format('G02-P02: la labor %s depende de la labor %s, que no está Completada', NEW.labor_id, v_dep));
        END IF;

        IF NEW.autorizacion_id IS NOT NULL THEN
            -- RN-11/RN-12: la autorización citada debe ser LA decisión aplicable y Aceptada.
            SELECT autorizacion_id, situacion INTO v_aplicable, v_situacion
            FROM v_situacion_labor WHERE labor_id = NEW.labor_id;
            IF v_situacion IS DISTINCT FROM 'Aceptada' OR v_aplicable IS DISTINCT FROM NEW.autorizacion_id THEN
                PERFORM fn_error(format('G02-P02: la autorización %s no es la decisión aplicable Aceptada de la labor %s (situación: %s)',
                                        NEW.autorizacion_id, NEW.labor_id, coalesce(v_situacion, 'Sin propuesta')));
            END IF;
        ELSIF NOT v_labor.es_emergencia THEN
            -- La FK compuesta ya garantiza que la emergencia es DE esta labor.
            PERFORM fn_error(format('G02-P02: la labor %s no es de emergencia', NEW.labor_id));
        END IF;
    END IF;

    IF NEW.estado_nuevo = 'Completada' THEN
        IF NOT EXISTS (SELECT 1 FROM participacion_tecnica WHERE labor_id = NEW.labor_id AND fin IS NOT NULL) THEN
            PERFORM fn_error(format('G02-P02: no se puede completar la labor %s sin participación técnica cerrada', NEW.labor_id));
        END IF;
        IF EXISTS (SELECT 1 FROM participacion_tecnica WHERE labor_id = NEW.labor_id AND fin IS NULL) THEN
            PERFORM fn_error(format('G02-P02: la labor %s tiene participaciones abiertas', NEW.labor_id));
        END IF;
        SELECT * INTO v_prueba FROM prueba WHERE labor_id = NEW.labor_id
        ORDER BY fecha_hora DESC, prueba_id DESC LIMIT 1;
        IF FOUND AND v_prueba.resultado = 'Desfavorable'
           AND NOT EXISTS (SELECT 1 FROM labor r
                           WHERE r.labor_revisada_id = NEW.labor_id
                             AND r.prueba_origen_id = v_prueba.prueba_id
                             AND r.estado_labor = 'Completada') THEN
            PERFORM fn_error(format('G02-P02: la última prueba (%s) de la labor %s es Desfavorable y no tiene retrabajo completado',
                                    v_prueba.prueba_id, NEW.labor_id));
        END IF;
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_historial_labor_antes
    BEFORE INSERT ON historial_labor
    FOR EACH ROW EXECUTE FUNCTION fn_historial_labor_antes();

CREATE FUNCTION fn_historial_labor_despues()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.secuencia > 1 THEN
        PERFORM set_config('taller.via_historial_labor', 'on', true);
        UPDATE labor SET estado_labor = NEW.estado_nuevo WHERE labor_id = NEW.labor_id;
        PERFORM set_config('taller.via_historial_labor', 'off', true);
    END IF;
    RETURN NULL;
END;
$$;

CREATE TRIGGER trg_historial_labor_despues
    AFTER INSERT ON historial_labor
    FOR EACH ROW EXECUTE FUNCTION fn_historial_labor_despues();

-- EXCEPCION_EMERGENCIA: solo sobre una labor marcada como emergencia y
-- todavía pendiente; no toca otras labores ni la propuesta (RN-12, D8).
CREATE FUNCTION fn_emergencia_validar()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_labor labor;
    v_orden orden_trabajo;
BEGIN
    v_labor := fn_bloquear_labor(NEW.labor_id, 'G02-P02');
    IF NOT v_labor.es_emergencia THEN
        PERFORM fn_error(format('G02-P02: la labor %s no está marcada como emergencia; no admite excepción', NEW.labor_id));
    END IF;
    IF v_labor.estado_labor <> 'Pendiente' THEN
        PERFORM fn_error(format('G02-P02: la labor %s está %s', NEW.labor_id, v_labor.estado_labor));
    END IF;
    SELECT * INTO v_orden FROM orden_trabajo WHERE orden_id = NEW.orden_id;
    IF fn_es_terminal(v_orden.estado_actual) THEN
        PERFORM fn_error(format('G02-P02: la orden %s está %s', NEW.orden_id, v_orden.estado_actual));
    END IF;
    IF NEW.fecha_hora < v_orden.fecha_hora_recepcion THEN
        PERFORM fn_error('G02-P02: la excepción no puede ser anterior a la recepción');
    END IF;
    PERFORM fn_exigir_personal(NEW.autorizada_por_id, ARRAY['Técnico', 'Otro'], 'G02-P02: autorización de emergencia');
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_emergencia_validar
    BEFORE INSERT ON excepcion_emergencia
    FOR EACH ROW EXECUTE FUNCTION fn_emergencia_validar();

-- LABOR_DEPENDENCIA: sin ciclos (RN-15, D7).
CREATE FUNCTION fn_dependencia_sin_ciclos()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF EXISTS (
        WITH RECURSIVE alcanzables (labor_id) AS (
            SELECT d.requiere_labor_id FROM labor_dependencia d WHERE d.labor_id = NEW.requiere_labor_id
            UNION
            SELECT d.requiere_labor_id FROM labor_dependencia d JOIN alcanzables a ON d.labor_id = a.labor_id
        )
        SELECT 1 FROM alcanzables WHERE labor_id = NEW.labor_id
    ) THEN
        PERFORM fn_error(format('G02-P02: la dependencia %s -> %s formaría un ciclo', NEW.labor_id, NEW.requiere_labor_id));
    END IF;
    IF EXISTS (SELECT 1 FROM labor WHERE labor_id = NEW.requiere_labor_id AND estado_labor = 'Anulada') THEN
        PERFORM fn_error(format('G02-P02: la labor requerida %s está Anulada', NEW.requiere_labor_id));
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_dependencia_sin_ciclos
    BEFORE INSERT ON labor_dependencia
    FOR EACH ROW EXECUTE FUNCTION fn_dependencia_sin_ciclos();

-- =====================================================================
-- 8. PARTICIPACIONES, PRUEBAS, CONSUMOS E INVENTARIO (G02-P02)
-- =====================================================================

-- PARTICIPACION_TECNICA: técnico activo, especialidad vigente del mismo
-- técnico, labor En proceso (bloqueada). Solo se permite cerrarla una vez.
CREATE FUNCTION fn_participacion_validar()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_labor        labor;
    v_inicio_labor    timestamptz;
BEGIN
    IF TG_OP = 'DELETE' THEN
        PERFORM fn_error(format('G02-INM: la participación %s no se elimina', OLD.participacion_id));
    END IF;

    v_labor := fn_bloquear_labor(NEW.labor_id, 'G02-P02');

    IF TG_OP = 'UPDATE' THEN
        IF OLD.fin IS NOT NULL
           OR NEW.fin IS NULL
           OR (NEW.participacion_id, NEW.labor_id, NEW.orden_id, NEW.tecnico_id, NEW.especialidad_id, NEW.inicio,
               NEW.descripcion_participacion)
              IS DISTINCT FROM
              (OLD.participacion_id, OLD.labor_id, OLD.orden_id, OLD.tecnico_id, OLD.especialidad_id, OLD.inicio,
               OLD.descripcion_participacion) THEN
            PERFORM fn_error(format('G02-INM: la participación %s solo admite su cierre (fin y minutos), una vez', OLD.participacion_id));
        END IF;
    END IF;

    IF v_labor.estado_labor <> 'En proceso' THEN
        PERFORM fn_error(format('G02-P02: la labor %s no está En proceso (estado: %s)', NEW.labor_id, v_labor.estado_labor));
    END IF;

    IF TG_OP = 'INSERT' THEN
        PERFORM fn_exigir_personal(NEW.tecnico_id, ARRAY['Técnico'], 'G02-P02: participación');
        IF NEW.especialidad_id IS NOT NULL AND NOT EXISTS (
            SELECT 1 FROM especialidad_tecnico
            WHERE especialidad_id = NEW.especialidad_id AND tecnico_id = NEW.tecnico_id
              AND NEW.inicio::date >= fecha_inicio
              AND (fecha_fin IS NULL OR NEW.inicio::date <= fecha_fin)) THEN
            PERFORM fn_error(format('G02-P02: la especialidad %s no está vigente para el técnico %s en %s',
                                    NEW.especialidad_id, NEW.tecnico_id, NEW.inicio::date));
        END IF;
        -- Coherencia temporal: no se trabaja en una labor antes de iniciarla.
        SELECT max(fecha_hora) INTO v_inicio_labor FROM historial_labor
        WHERE labor_id = NEW.labor_id AND estado_nuevo = 'En proceso';
        IF NEW.inicio < v_inicio_labor THEN
            PERFORM fn_error(format('G02-P02: la participación (%s) no puede iniciar antes de que la labor %s pasara a En proceso (%s)',
                                    NEW.inicio, NEW.labor_id, v_inicio_labor));
        END IF;
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_participacion_validar
    BEFORE INSERT OR UPDATE OR DELETE ON participacion_tecnica
    FOR EACH ROW EXECUTE FUNCTION fn_participacion_validar();

-- PRUEBA: sobre una labor En proceso (bloqueada), por personal activo.
CREATE FUNCTION fn_prueba_validar()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_labor     labor;
    v_recepcion timestamptz;
BEGIN
    v_labor := fn_bloquear_labor(NEW.labor_id, 'G02-P02');
    IF v_labor.estado_labor <> 'En proceso' THEN
        PERFORM fn_error(format('G02-P02: la labor %s no está En proceso (estado: %s)', NEW.labor_id, v_labor.estado_labor));
    END IF;
    PERFORM fn_exigir_personal(NEW.personal_id, NULL, 'G02-P02: prueba');
    SELECT fecha_hora_recepcion INTO v_recepcion FROM orden_trabajo WHERE orden_id = NEW.orden_id;
    IF NEW.fecha_hora < v_recepcion THEN
        PERFORM fn_error('G02-P02: la prueba no puede ser anterior a la recepción');
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_prueba_validar
    BEFORE INSERT ON prueba
    FOR EACH ROW EXECUTE FUNCTION fn_prueba_validar();

-- CONSUMO_REPUESTO: sobre una labor En proceso (bloqueada).
CREATE FUNCTION fn_consumo_validar()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_labor labor;
BEGIN
    v_labor := fn_bloquear_labor(NEW.labor_id, 'G02-P02');
    IF v_labor.estado_labor <> 'En proceso' THEN
        PERFORM fn_error(format('G02-P02: la labor %s no está En proceso (estado: %s)', NEW.labor_id, v_labor.estado_labor));
    END IF;
    PERFORM fn_exigir_personal(NEW.registrado_por_id, NULL, 'G02-P02: consumo');
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_consumo_validar
    BEFORE INSERT ON consumo_repuesto
    FOR EACH ROW EXECUTE FUNCTION fn_consumo_validar();

-- Al confirmar: todo consumo tiene exactamente su movimiento de Consumo por
-- la misma cantidad (no queda consumo sin movimiento).
CREATE FUNCTION fn_consumo_con_movimiento()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM movimiento_inventario
                   WHERE consumo_id = NEW.consumo_id AND tipo_movimiento = 'Consumo'
                     AND cantidad = NEW.cantidad_utilizada) THEN
        PERFORM fn_error(format('G02-P02: el consumo %s no tiene su movimiento de inventario de Consumo', NEW.consumo_id));
    END IF;
    RETURN NULL;
END;
$$;

CREATE CONSTRAINT TRIGGER trg_consumo_con_movimiento
    AFTER INSERT ON consumo_repuesto
    DEFERRABLE INITIALLY DEFERRED
    FOR EACH ROW EXECUTE FUNCTION fn_consumo_con_movimiento();

-- MOVIMIENTO_INVENTARIO: existencias físicas y disponibles nunca negativas
-- (RN-19, D11). El bloqueo de la fila del repuesto serializa los
-- movimientos concurrentes del mismo repuesto.
CREATE FUNCTION fn_movimiento_validar()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_fisico          numeric;
    v_reservado       numeric;
    v_reservado_orden numeric;
    v_consumo         consumo_repuesto;
BEGIN
    PERFORM 1 FROM repuesto WHERE repuesto_id = NEW.repuesto_id FOR UPDATE;
    IF NOT FOUND THEN
        PERFORM fn_error(format('G02-INT: el repuesto %s no existe', NEW.repuesto_id));
    END IF;
    PERFORM fn_exigir_personal(NEW.registrado_por_id, NULL, 'G02-INT: movimiento de inventario');

    SELECT coalesce(sum(CASE tipo_movimiento
                            WHEN 'Entrada' THEN cantidad
                            WHEN 'Ajuste positivo' THEN cantidad
                            WHEN 'Ajuste negativo' THEN -cantidad
                            WHEN 'Consumo' THEN -cantidad
                            ELSE 0 END), 0),
           coalesce(sum(CASE tipo_movimiento
                            WHEN 'Reserva' THEN cantidad
                            WHEN 'Liberación' THEN -cantidad
                            ELSE 0 END), 0),
           coalesce(sum(CASE WHEN orden_id IS NOT DISTINCT FROM NEW.orden_id THEN
                            CASE tipo_movimiento
                                WHEN 'Reserva' THEN cantidad
                                WHEN 'Liberación' THEN -cantidad
                                ELSE 0 END
                            ELSE 0 END), 0)
    INTO v_fisico, v_reservado, v_reservado_orden
    FROM movimiento_inventario WHERE repuesto_id = NEW.repuesto_id;

    CASE NEW.tipo_movimiento
        WHEN 'Entrada', 'Ajuste positivo' THEN
            v_fisico := v_fisico + NEW.cantidad;
        WHEN 'Ajuste negativo' THEN
            v_fisico := v_fisico - NEW.cantidad;
        WHEN 'Consumo' THEN
            IF NEW.consumo_id IS NULL THEN
                PERFORM fn_error('G02-INT: un movimiento de Consumo requiere el consumo de origen (consumo_id), D11');
            END IF;
            SELECT * INTO v_consumo FROM consumo_repuesto WHERE consumo_id = NEW.consumo_id;
            IF v_consumo.cantidad_utilizada IS DISTINCT FROM NEW.cantidad THEN
                PERFORM fn_error(format('G02-INT: el movimiento de Consumo (%s) no coincide con la cantidad del consumo %s (%s)',
                                        NEW.cantidad, NEW.consumo_id, v_consumo.cantidad_utilizada));
            END IF;
            v_fisico := v_fisico - NEW.cantidad;
        WHEN 'Reserva' THEN
            v_reservado := v_reservado + NEW.cantidad;
        WHEN 'Liberación' THEN
            IF NEW.cantidad > v_reservado_orden THEN
                PERFORM fn_error(format('G02-INT: no se puede liberar %s de %s; la orden %s solo tiene %s reservado',
                                        NEW.cantidad, NEW.repuesto_id, NEW.orden_id, v_reservado_orden));
            END IF;
            v_reservado := v_reservado - NEW.cantidad;
    END CASE;

    IF v_fisico < 0 THEN
        PERFORM fn_error(format('G02-INT: existencias insuficientes de %s: el movimiento dejaría %s físicas',
                                NEW.repuesto_id, v_fisico));
    END IF;
    IF v_fisico - v_reservado < 0 THEN
        PERFORM fn_error(format('G02-INT: existencias insuficientes de %s: el movimiento dejaría %s disponibles (físico %s, reservado %s)',
                                NEW.repuesto_id, v_fisico - v_reservado, v_fisico, v_reservado));
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_movimiento_validar
    BEFORE INSERT ON movimiento_inventario
    FOR EACH ROW EXECUTE FUNCTION fn_movimiento_validar();

-- PIEZA_RETIRADA: de una labor que se está ejecutando o ya se completó.
CREATE FUNCTION fn_pieza_validar()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_estado text;
BEGIN
    SELECT estado_labor INTO v_estado FROM labor WHERE labor_id = NEW.labor_id;
    IF v_estado NOT IN ('En proceso', 'Completada') THEN
        PERFORM fn_error(format('G02-INT: la labor %s está %s; no tiene piezas retiradas', NEW.labor_id, v_estado));
    END IF;
    PERFORM fn_exigir_personal(NEW.registrado_por_id, NULL, 'G02-INT: pieza retirada');
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_pieza_validar
    BEFORE INSERT ON pieza_retirada
    FOR EACH ROW EXECUTE FUNCTION fn_pieza_validar();

-- =====================================================================
-- 9. ENTREGA Y GARANTÍA
-- =====================================================================

-- ENTREGA: orden Lista entrega; quien retira tiene facultad Retirar vigente;
-- km de salida >= km de ingreso; no antes de la recepción (RN-20, D2).
CREATE FUNCTION fn_entrega_validar()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_orden    orden_trabajo;
    v_facultad facultad_orden;
BEGIN
    v_orden := fn_bloquear_orden(NEW.orden_id, 'G02-INT');
    IF v_orden.estado_actual <> 'Lista entrega' THEN
        PERFORM fn_error(format('G02-INT: la orden %s no está Lista entrega (estado: %s)', NEW.orden_id, v_orden.estado_actual));
    END IF;

    IF NEW.facultad_id IS NULL THEN
        SELECT * INTO v_facultad FROM facultad_orden
        WHERE orden_id = NEW.orden_id AND cliente_id = NEW.retira_cliente_id AND tipo_facultad = 'Retirar'
          AND vigente_desde <= NEW.fecha_hora AND (vigente_hasta IS NULL OR NEW.fecha_hora < vigente_hasta)
        ORDER BY vigente_desde DESC LIMIT 1;
        NEW.facultad_id := v_facultad.facultad_id;
    ELSE
        SELECT * INTO v_facultad FROM facultad_orden WHERE facultad_id = NEW.facultad_id;
    END IF;
    IF v_facultad.facultad_id IS NULL
       OR v_facultad.orden_id <> NEW.orden_id
       OR v_facultad.cliente_id <> NEW.retira_cliente_id
       OR v_facultad.tipo_facultad <> 'Retirar'
       OR NEW.fecha_hora < v_facultad.vigente_desde
       OR (v_facultad.vigente_hasta IS NOT NULL AND NEW.fecha_hora >= v_facultad.vigente_hasta) THEN
        PERFORM fn_error(format('G02-INT: el cliente %s no tiene facultad vigente para retirar el vehículo de la orden %s',
                                NEW.retira_cliente_id, NEW.orden_id));
    END IF;

    IF NEW.kilometraje_salida < v_orden.kilometraje_ingreso THEN
        PERFORM fn_error(format('G02-INT: el kilometraje de salida (%s) es menor que el de ingreso (%s)',
                                NEW.kilometraje_salida, v_orden.kilometraje_ingreso));
    END IF;
    IF NEW.fecha_hora < v_orden.fecha_hora_recepcion THEN
        PERFORM fn_error('G02-INT: la entrega no puede ser anterior a la recepción');
    END IF;
    PERFORM fn_exigir_personal(NEW.entregado_por_id, NULL, 'G02-INT: entrega');
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_entrega_validar
    BEFORE INSERT ON entrega
    FOR EACH ROW EXECUTE FUNCTION fn_entrega_validar();

-- GARANTIA: solo sobre labores completadas de la orden entregada (D3).
CREATE FUNCTION fn_garantia_validar()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_estado text;
BEGIN
    SELECT estado_labor INTO v_estado FROM labor WHERE labor_id = NEW.labor_id;
    IF v_estado IS DISTINCT FROM 'Completada' THEN
        PERFORM fn_error(format('G02-INT: solo se otorga garantía sobre labores Completadas (la labor %s está %s)',
                                NEW.labor_id, coalesce(v_estado, 'inexistente')));
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_garantia_validar
    BEFORE INSERT ON garantia
    FOR EACH ROW EXECUTE FUNCTION fn_garantia_validar();

-- RECLAMO_GARANTIA: orden nueva distinta, del MISMO VIN, posterior a la
-- entrega; aceptada o pendiente solo dentro de AMBOS límites (vence lo que
-- ocurra primero, RN-21, RN-22). Solo se reevalúa un reclamo Pendiente.
CREATE FUNCTION fn_reclamo_validar()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_garantia    garantia;
    v_entrega     entrega;
    v_vin_origen  text;
    v_orden_nueva orden_trabajo;
    v_dentro_dias boolean;
    v_dentro_km   boolean;
BEGIN
    IF TG_OP = 'DELETE' THEN
        PERFORM fn_error(format('G02-INM: el reclamo %s no se elimina', OLD.reclamo_id));
    END IF;
    IF TG_OP = 'UPDATE' THEN
        IF OLD.decision <> 'Pendiente'
           OR (NEW.reclamo_id, NEW.garantia_id, NEW.orden_nueva_id, NEW.fecha_reclamo, NEW.km_reclamo)
              IS DISTINCT FROM (OLD.reclamo_id, OLD.garantia_id, OLD.orden_nueva_id, OLD.fecha_reclamo, OLD.km_reclamo) THEN
            PERFORM fn_error(format('G02-INM: el reclamo %s solo se reevalúa mientras está Pendiente', OLD.reclamo_id));
        END IF;
    END IF;

    SELECT * INTO v_garantia FROM garantia WHERE garantia_id = NEW.garantia_id;
    IF NOT FOUND THEN
        PERFORM fn_error(format('G02-INT: la garantía %s no existe', NEW.garantia_id));
    END IF;
    SELECT * INTO v_entrega FROM entrega WHERE entrega_id = v_garantia.entrega_id;
    SELECT vin INTO v_vin_origen FROM orden_trabajo WHERE orden_id = v_garantia.orden_id;
    SELECT * INTO v_orden_nueva FROM orden_trabajo WHERE orden_id = NEW.orden_nueva_id;
    IF NOT FOUND THEN
        PERFORM fn_error(format('G02-INT: la orden nueva %s no existe', NEW.orden_nueva_id));
    END IF;

    IF NEW.orden_nueva_id = v_garantia.orden_id THEN
        PERFORM fn_error('G02-INT: el reclamo debe abrir una orden nueva, distinta de la orden garantizada (RN-21)');
    END IF;
    IF v_orden_nueva.vin <> v_vin_origen THEN
        PERFORM fn_error(format('G02-INT: la orden nueva %s es del vehículo %s, no del vehículo garantizado %s',
                                NEW.orden_nueva_id, v_orden_nueva.vin, v_vin_origen));
    END IF;
    IF NEW.fecha_reclamo <= v_entrega.fecha_hora OR v_orden_nueva.fecha_hora_recepcion <= v_entrega.fecha_hora THEN
        PERFORM fn_error('G02-INT: el reclamo y su orden nueva deben ser posteriores a la entrega');
    END IF;
    IF NEW.km_reclamo IS NULL THEN
        NEW.km_reclamo := v_orden_nueva.kilometraje_ingreso;
    END IF;
    IF NEW.km_reclamo < v_entrega.kilometraje_salida THEN
        PERFORM fn_error(format('G02-INT: el kilometraje del reclamo (%s) es menor que el de la entrega (%s)',
                                NEW.km_reclamo, v_entrega.kilometraje_salida));
    END IF;
    PERFORM fn_exigir_personal(NEW.evaluado_por_id, NULL, 'G02-INT: evaluación de reclamo');

    v_dentro_dias := v_garantia.dias IS NULL
                     OR NEW.fecha_reclamo <= v_entrega.fecha_hora + make_interval(days => v_garantia.dias);
    v_dentro_km   := v_garantia.km IS NULL
                     OR NEW.km_reclamo - v_entrega.kilometraje_salida <= v_garantia.km;
    IF NEW.decision IN ('Aceptada', 'Pendiente') AND NOT (v_dentro_dias AND v_dentro_km) THEN
        PERFORM fn_error(format('G02-INT: garantía %s vencida (vence lo primero): dentro de días=%s, dentro de km=%s; '
                                'el reclamo solo puede registrarse como Rechazada con justificación (RN-22)',
                                NEW.garantia_id, v_dentro_dias, v_dentro_km));
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_reclamo_validar
    BEFORE INSERT OR UPDATE OR DELETE ON reclamo_garantia
    FOR EACH ROW EXECUTE FUNCTION fn_reclamo_validar();
