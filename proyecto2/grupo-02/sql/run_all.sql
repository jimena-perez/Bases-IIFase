-- =====================================================================
-- IC-4301 Bases de Datos I · Proyecto (2.ª entrega) · Grupo 02
-- Archivo: run_all.sql — construye TODO desde una base nueva.
-- Uso (desde la carpeta proyecto2/grupo-02):
--   psql -U postgres -d taller_ruta27 -v ON_ERROR_STOP=1 -f sql/run_all.sql
-- Es el único script de sql/ con comandos de psql (\set, \echo, \ir).
-- \ir resuelve las rutas relativas a ESTE archivo, así que funciona desde
-- cualquier directorio de trabajo.
-- =====================================================================
\set ON_ERROR_STOP on
\pset pager off

\echo '== 00 reset (esquema taller limpio + btree_gist)'
\ir 00_reset.sql
\echo '== 01 esquema (32 relaciones)'
\ir 01_esquema.sql
\echo '== 02 triggers de integridad'
\ir 02_triggers_integridad.sql
\echo '== 03 rutinas P01 (propuestas y decisiones)'
\ir 03_rutinas_p01.sql
\echo '== 04 rutinas P02 (ejecución)'
\ir 04_rutinas_p02.sql
\echo '== 05 rutinas P03 (estados y fecha prometida)'
\ir 05_rutinas_p03.sql
\echo '== 06 vistas y consultas Q01-Q04'
\ir 06_vistas_consultas.sql
\echo '== 07 datos iniciales de preparación'
\ir 07_datos_iniciales.sql
\echo '== 08 rutinas reutilizadas del Lab03'
\ir 08_rutinas_lab03.sql

\echo '== Verificación: objetos creados en el esquema taller'
SELECT 'tablas' AS objeto, count(*) FROM information_schema.tables WHERE table_schema = 'taller' AND table_type = 'BASE TABLE'
UNION ALL SELECT 'vistas', count(*) FROM information_schema.views WHERE table_schema = 'taller'
UNION ALL SELECT 'funciones y procedimientos', count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace WHERE n.nspname = 'taller'
UNION ALL SELECT 'triggers', count(*) FROM pg_trigger t JOIN pg_class c ON c.oid = t.tgrelid JOIN pg_namespace n ON n.oid = c.relnamespace WHERE n.nspname = 'taller' AND NOT t.tgisinternal
UNION ALL SELECT 'restricciones con nombre', count(*) FROM pg_constraint k JOIN pg_namespace n ON n.oid = k.connamespace WHERE n.nspname = 'taller';

SELECT version();
\echo '== run_all.sql terminó sin errores'
