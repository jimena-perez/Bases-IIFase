-- =====================================================================
-- IC-4301 Bases de Datos I · Proyecto (2.ª entrega) · Grupo 02
-- Archivo: pruebas/00_utilidades_pruebas.sql
-- Propósito: utilidades de la batería de pruebas (esquema "pruebas").
--   * pruebas.evidencia: bitácora de cada prueba (ID, criterio, acción,
--     esperado, observado, resultado). Se consulta al final de
--     run_pruebas.sql y se copia a resultados/.
--   * pruebas.esperar_rechazo: ejecuta una sentencia que DEBE fallar dentro
--     de una subtransacción, compara la causa con el patrón esperado y
--     registra SQLSTATE + mensaje. Si la sentencia NO falla, se registra
--     FALLO y sus efectos se revierten igualmente.
--   * pruebas.verificar: registra una comprobación de datos (lectura
--     posterior). Un aviso de éxito no basta: cada acción va seguida de una
--     verificación sobre los datos.
-- El esquema "pruebas" no forma parte del modelo; 00_reset.sql lo elimina.
-- =====================================================================

SET search_path = taller, public;

DROP SCHEMA IF EXISTS pruebas CASCADE;
CREATE SCHEMA pruebas;

CREATE TABLE pruebas.evidencia (
    evidencia_id   integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    prueba_id      text        NOT NULL,
    criterio       text        NOT NULL,
    tipo           text        NOT NULL CHECK (tipo IN ('Rechazo', 'Verificación')),
    accion         text        NOT NULL,
    esperado       text        NOT NULL,
    observado      text        NOT NULL,
    resultado      text        NOT NULL CHECK (resultado IN ('OK', 'FALLO')),
    registrado_en  timestamptz NOT NULL DEFAULT clock_timestamp()
);

-- ---------------------------------------------------------------------
-- SELECT pruebas.esperar_rechazo(id, criterio, accion, sentencia, patron)
-- ---------------------------------------------------------------------
CREATE FUNCTION pruebas.esperar_rechazo(
    p_prueba_id  text,
    p_criterio   text,
    p_accion     text,
    p_sentencia  text,
    p_patron     text
)
RETURNS text
LANGUAGE plpgsql
AS $$
DECLARE
    v_estado    text;
    v_mensaje   text;
    v_resultado text;
    v_observado text;
BEGIN
    BEGIN
        EXECUTE p_sentencia;
        -- Si llega aquí no hubo rechazo: se fuerza un error propio para
        -- revertir los efectos de la sentencia dentro de la subtransacción.
        RAISE EXCEPTION USING ERRCODE = 'PT001', MESSAGE = 'la sentencia se ACEPTÓ (efectos revertidos)';
    EXCEPTION WHEN OTHERS THEN
        v_estado  := SQLSTATE;
        v_mensaje := SQLERRM;
    END;

    IF v_estado = 'PT001' THEN
        v_resultado := 'FALLO';
    ELSIF v_mensaje ILIKE '%' || p_patron || '%' THEN
        v_resultado := 'OK';
    ELSE
        v_resultado := 'FALLO';
    END IF;
    v_observado := v_estado || ': ' || v_mensaje;

    INSERT INTO pruebas.evidencia (prueba_id, criterio, tipo, accion, esperado, observado, resultado)
    VALUES (p_prueba_id, p_criterio, 'Rechazo', p_accion, 'Rechazo: ' || p_patron, v_observado, v_resultado);

    IF v_resultado = 'OK' THEN
        RAISE NOTICE 'OK    [%] rechazo esperado -> %', p_prueba_id, v_observado;
    ELSE
        RAISE WARNING 'FALLO [%] se esperaba rechazo "%" y se obtuvo -> %', p_prueba_id, p_patron, v_observado;
    END IF;
    RETURN v_resultado || ' ' || p_prueba_id || ': ' || v_observado;
END;
$$;

-- ---------------------------------------------------------------------
-- SELECT pruebas.verificar(id, criterio, accion, condicion, esperado, observado)
-- ---------------------------------------------------------------------
CREATE FUNCTION pruebas.verificar(
    p_prueba_id  text,
    p_criterio   text,
    p_accion     text,
    p_condicion  boolean,
    p_esperado   text,
    p_observado  text
)
RETURNS text
LANGUAGE plpgsql
AS $$
DECLARE
    v_resultado text := CASE WHEN coalesce(p_condicion, false) THEN 'OK' ELSE 'FALLO' END;
BEGIN
    INSERT INTO pruebas.evidencia (prueba_id, criterio, tipo, accion, esperado, observado, resultado)
    VALUES (p_prueba_id, p_criterio, 'Verificación', p_accion, p_esperado, coalesce(p_observado, '(nulo)'), v_resultado);
    IF v_resultado = 'OK' THEN
        RAISE NOTICE 'OK    [%] % -> %', p_prueba_id, p_esperado, coalesce(p_observado, '(nulo)');
    ELSE
        RAISE WARNING 'FALLO [%] esperado: % | observado: %', p_prueba_id, p_esperado, coalesce(p_observado, '(nulo)');
    END IF;
    RETURN v_resultado || ' ' || p_prueba_id || ': ' || coalesce(p_observado, '(nulo)');
END;
$$;

-- Atajos de lectura para las pruebas.
CREATE FUNCTION pruebas.labor_id(p_orden_id integer, p_descripcion_prefijo text)
RETURNS bigint
LANGUAGE sql STABLE
AS $$
    SELECT labor_id FROM taller.labor
    WHERE orden_id = p_orden_id AND descripcion LIKE p_descripcion_prefijo || '%'
    ORDER BY labor_id LIMIT 1
$$;

CREATE FUNCTION pruebas.propuesta_id(p_orden_id integer, p_version integer)
RETURNS bigint
LANGUAGE sql STABLE
AS $$
    SELECT propuesta_id FROM taller.propuesta WHERE orden_id = p_orden_id AND version = p_version
$$;

CREATE FUNCTION pruebas.conteo(p_sql text)
RETURNS bigint
LANGUAGE plpgsql
AS $$
DECLARE
    v bigint;
BEGIN
    EXECUTE p_sql INTO v;
    RETURN v;
END;
$$;

CREATE VIEW pruebas.v_resumen AS
SELECT split_part(prueba_id, '-', 2) || '-' || split_part(prueba_id, '-', 3) AS bloque,
       count(*)                                         AS comprobaciones,
       count(*) FILTER (WHERE resultado = 'OK')         AS ok,
       count(*) FILTER (WHERE resultado = 'FALLO')      AS fallos
FROM pruebas.evidencia
GROUP BY 1
ORDER BY 1;
