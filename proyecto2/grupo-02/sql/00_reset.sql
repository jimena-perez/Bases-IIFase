-- =====================================================================
-- IC-4301 Bases de Datos I · Proyecto (2.ª entrega) · Grupo 02
-- Caso: Taller Ruta 27
-- Archivo: 00_reset.sql
-- Propósito: dejar la base en un estado limpio y reproducible.
--   * Elimina (si existen) los esquemas propios del proyecto:
--       taller  -> modelo, reglas, rutinas y vistas
--       pruebas -> utilidades y bitácora de evidencias de las pruebas
--   * Crea de nuevo el esquema taller.
--   * Instala btree_gist (restricciones EXCLUDE de vigencias).
-- No toca ningún otro esquema ni objeto de la base de datos.
-- =====================================================================

DROP SCHEMA IF EXISTS pruebas CASCADE;
DROP SCHEMA IF EXISTS taller CASCADE;

CREATE SCHEMA taller;
COMMENT ON SCHEMA taller IS
    'Taller Ruta 27 - Proyecto 2 Grupo 02: modelo relacional completo, reglas, procesos P01-P03 y vistas.';

-- btree_gist es una extensión "trusted" desde PostgreSQL 13: puede
-- instalarla el dueño de la base sin ser superusuario.
CREATE EXTENSION IF NOT EXISTS btree_gist WITH SCHEMA public;
