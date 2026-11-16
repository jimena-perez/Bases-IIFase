-- =====================================================================
-- IC-4301 · Proyecto 2 · Grupo 02 · Taller Ruta 27
-- Archivo: pruebas/run_pruebas.sql — ejecuta TODA la batería de pruebas.
-- Precondición: base recién construida con sql/run_all.sql (las pruebas
-- son secuenciales: P01 -> P02 -> P03 -> integridad).
-- Uso (desde proyecto2/grupo-02):
--   psql -U postgres -d taller_ruta27 -v ON_ERROR_STOP=1 -f sql/run_all.sql
--   psql -U postgres -d taller_ruta27 -v ON_ERROR_STOP=1 -f pruebas/run_pruebas.sql
-- Los rechazos esperados se capturan dentro de pruebas.esperar_rechazo, por
-- lo que la batería corre completa con ON_ERROR_STOP activado: cualquier
-- ERROR no capturado es un defecto real y detiene la ejecución.
-- =====================================================================
\set ON_ERROR_STOP on
\pset pager off
SET search_path = taller, public;

-- Guardia: la batería parte del estado de preparación (sin resultados de procesos).
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM taller.propuesta) THEN
        RAISE EXCEPTION 'La base ya contiene resultados de procesos: ejecute primero sql/run_all.sql (base nueva).';
    END IF;
END $$;

\echo '######## 00 utilidades de prueba'
\ir 00_utilidades_pruebas.sql
\echo '######## G02-P01 · versionar propuestas y autorizar labores'
\ir 10_p01_validas.sql
\ir 11_p01_invalidas.sql
\ir 12_p01_limite.sql
\ir 13_p01_atomicidad.sql
\echo '######## G02-P02 · ejecutar reparaciones y pruebas'
\ir 20_p02_validas.sql
\ir 21_p02_invalidas.sql
\ir 22_p02_limite.sql
\ir 23_p02_atomicidad.sql
\echo '######## G02-P03 · estados de la orden y fecha prometida'
\ir 30_p03_validas.sql
\ir 31_p03_invalidas.sql
\ir 32_p03_limite.sql
\ir 33_p03_atomicidad.sql
\echo '######## Integridad del modelo completo'
\ir 90_integridad_modelo.sql

\echo '######## RESUMEN DE EVIDENCIAS'
SELECT * FROM pruebas.v_resumen;
SELECT count(*) AS comprobaciones,
       count(*) FILTER (WHERE resultado = 'OK')    AS ok,
       count(*) FILTER (WHERE resultado = 'FALLO') AS fallos,
       count(*) FILTER (WHERE tipo = 'Rechazo')    AS rechazos_esperados,
       count(*) FILTER (WHERE tipo = 'Verificación') AS verificaciones_de_datos
FROM pruebas.evidencia;
SELECT prueba_id, accion, esperado, observado FROM pruebas.evidencia WHERE resultado = 'FALLO';

-- Sin transacciones abiertas al terminar (otra sesión ociosa en transacción
-- indicaría un residuo).
SELECT count(*) AS sesiones_en_transaccion_abierta
FROM pg_stat_activity
WHERE datname = current_database() AND state LIKE 'idle in transaction%' AND pid <> pg_backend_pid();

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pruebas.evidencia WHERE resultado = 'FALLO') THEN
        RAISE EXCEPTION 'Hay pruebas con resultado FALLO (ver la consulta anterior).';
    END IF;
    RAISE NOTICE 'BATERÍA COMPLETA: todas las comprobaciones dieron OK.';
END $$;
