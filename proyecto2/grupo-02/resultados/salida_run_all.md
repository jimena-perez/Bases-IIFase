# Salida de sql/run_all.sql (construcción desde base nueva)

> Generado ejecutando de verdad, el 2026-11-16 04:07 UTC, en una base nueva (`taller_ruta27`).
>
> Comando: `psql -X -a -d taller_ruta27 -v ON_ERROR_STOP=1 -f sql/run_all.sql`

```text
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
Pager usage is off.
\echo '== 00 reset (esquema taller limpio + btree_gist)'
== 00 reset (esquema taller limpio + btree_gist)
\ir 00_reset.sql
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
psql:sql/00_reset.sql:14: NOTICE:  schema "pruebas" does not exist, skipping
DROP SCHEMA
DROP SCHEMA IF EXISTS taller CASCADE;
psql:sql/00_reset.sql:15: NOTICE:  schema "taller" does not exist, skipping
DROP SCHEMA
CREATE SCHEMA taller;
CREATE SCHEMA
COMMENT ON SCHEMA taller IS
    'Taller Ruta 27 - Proyecto 2 Grupo 02: modelo relacional completo, reglas, procesos P01-P03 y vistas.';
COMMENT
-- btree_gist es una extensión "trusted" desde PostgreSQL 13: puede
-- instalarla el dueño de la base sin ser superusuario.
CREATE EXTENSION IF NOT EXISTS btree_gist WITH SCHEMA public;
CREATE EXTENSION
\echo '== 01 esquema (32 relaciones)'
== 01 esquema (32 relaciones)
\ir 01_esquema.sql
-- =====================================================================
-- IC-4301 Bases de Datos I · Proyecto (2.ª entrega) · Grupo 02
-- Caso: Taller Ruta 27
-- Archivo: 01_esquema.sql
-- Propósito: implementar el 100 % del modelo relacional final.
--   32 relaciones (31 tablas de negocio + 1 catálogo de transiciones),
--   con PK, FK (incluidas FK compuestas de contexto), UNIQUE, CHECK,
--   EXCLUDE y dominios. Las reglas que no se pueden expresar de forma
--   declarativa se implementan en 02_triggers_integridad.sql.
--
-- Convenciones:
--   * Identificadores en snake_case, sin tildes ni ñ.
--   * PK sustitutas IDENTITY (BY DEFAULT: permite cargar IDs fijos y
--     conservar el alta del Lab03, que recibe orden_id como parámetro).
--     Las relaciones que vienen del Lab03 (cliente, personal, orden_trabajo,
--     hallazgo) mantienen integer en su PK y en todas sus FK, porque las
--     rutinas reutilizadas sin modificación reciben INTEGER; las relaciones
--     nuevas usan bigint. Excepciones naturales: vehiculo.vin y
--     repuesto.repuesto_id.
--   * Tiempos: timestamptz; vigencias por día: date; dinero numeric(12,2);
--     cantidades numeric(10,2).
--   * Restricciones con nombre: pk_, fk_, uq_, ck_, ex_.
-- =====================================================================
SET search_path = taller, public;
SET
-- =====================================================================
-- 0. DOMINIOS REUTILIZADOS
-- =====================================================================
CREATE DOMAIN d_estado_orden AS varchar(30)
    CONSTRAINT ck_d_estado_orden CHECK (VALUE IN (
        'Recibida', 'En diagnóstico', 'Pendiente autorización', 'Autorizada',
        'En reparación', 'Lista entrega', 'Entregada', 'Cancelada'));
CREATE DOMAIN
CREATE DOMAIN d_estado_labor AS varchar(20)
    CONSTRAINT ck_d_estado_labor CHECK (VALUE IN (
        'Pendiente', 'En proceso', 'Completada', 'Suspendida', 'Anulada'));
CREATE DOMAIN
CREATE DOMAIN d_medio_comunicacion AS varchar(20)
    CONSTRAINT ck_d_medio_comunicacion CHECK (VALUE IN (
        'Teléfono', 'Correo', 'Mensaje', 'Presencial', 'Otro'));
CREATE DOMAIN
COMMENT ON DOMAIN d_estado_orden IS 'Estados de la orden (P1 §diccionario). Secuencia NO lineal: ver transicion_estado_orden.';
COMMENT
COMMENT ON DOMAIN d_estado_labor IS 'Estados de una labor (P1 §diccionario).';
COMMENT
COMMENT ON DOMAIN d_medio_comunicacion IS 'Medio por el que se comunica una decisión o una promesa (P1 §diccionario).';
COMMENT
-- =====================================================================
-- 1. MAESTROS E IDENTIDAD
-- =====================================================================
-- 1) CLIENTE: persona u organización. Quien entrega, aprueba o retira se
--    registra aquí aunque no sea el titular (SD-02 del Proyecto 1).
CREATE TABLE cliente (
    cliente_id           integer GENERATED BY DEFAULT AS IDENTITY,
    identificacion       varchar(30)  NOT NULL,
    nombre_razon_social  varchar(150) NOT NULL,
    tipo_cliente         varchar(20)  NOT NULL,
    CONSTRAINT pk_cliente PRIMARY KEY (cliente_id),
    CONSTRAINT uq_cliente_identificacion UNIQUE (identificacion),
    CONSTRAINT ck_cliente_identificacion CHECK (btrim(identificacion) <> ''),
    CONSTRAINT ck_cliente_nombre CHECK (btrim(nombre_razon_social) <> ''),
    CONSTRAINT ck_cliente_tipo CHECK (tipo_cliente IN ('Persona', 'Organización'))
);
CREATE TABLE
-- 2) CONTACTO_CLIENTE: varios contactos por cliente; al menos uno apto
--    para avisos (RN-03, verificado al COMMIT por constraint trigger).
CREATE TABLE contacto_cliente (
    contacto_id     bigint GENERATED BY DEFAULT AS IDENTITY,
    cliente_id      integer      NOT NULL,
    tipo_contacto   varchar(10) NOT NULL,
    valor_contacto  varchar(120) NOT NULL,
    recibe_avisos   boolean     NOT NULL DEFAULT false,
    CONSTRAINT pk_contacto_cliente PRIMARY KEY (contacto_id),
    CONSTRAINT fk_contacto_cliente_cliente FOREIGN KEY (cliente_id) REFERENCES cliente (cliente_id),
    CONSTRAINT uq_contacto_cliente_valor UNIQUE (cliente_id, tipo_contacto, valor_contacto),
    CONSTRAINT ck_contacto_tipo CHECK (tipo_contacto IN ('Teléfono', 'Correo')),
    CONSTRAINT ck_contacto_formato CHECK (
        (tipo_contacto = 'Correo'   AND valor_contacto ~* '^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$')
     OR (tipo_contacto = 'Teléfono' AND valor_contacto ~ '^\+?[0-9]{8,15}$'))
);
CREATE TABLE
-- 3) VEHICULO: el VIN es la identidad estable; la placa puede cambiar (RN-02).
CREATE TABLE vehiculo (
    vin               varchar(17) NOT NULL,
    placa             varchar(15) NOT NULL,
    marca             varchar(60) NOT NULL,
    modelo            varchar(60) NOT NULL,
    anio              integer     NOT NULL,
    tipo_combustible  varchar(20) NOT NULL,
    CONSTRAINT pk_vehiculo PRIMARY KEY (vin),
    -- VIN ISO 3779: 17 caracteres, sin I, O ni Q.
    CONSTRAINT ck_vehiculo_vin CHECK (vin ~ '^[A-HJ-NPR-Z0-9]{17}$'),
    CONSTRAINT ck_vehiculo_placa CHECK (btrim(placa) <> ''),
    CONSTRAINT ck_vehiculo_marca CHECK (btrim(marca) <> ''),
    CONSTRAINT ck_vehiculo_modelo CHECK (btrim(modelo) <> ''),
    -- Cota inferior fija aquí; la superior (año actual + 1) depende de now()
    -- y por eso se valida con trigger (trg_vehiculo_anio).
    CONSTRAINT ck_vehiculo_anio_minimo CHECK (anio >= 1886),
    CONSTRAINT ck_vehiculo_combustible CHECK (tipo_combustible IN ('Gasolina', 'Diésel', 'Híbrido', 'Eléctrico', 'Otro'))
);
CREATE TABLE
-- 4) PROPIEDAD_VEHICULO (nueva, D12): propietario con vigencias. Cambiar de
--    propietario no reescribe las visitas anteriores.
CREATE TABLE propiedad_vehiculo (
    propiedad_id  bigint GENERATED BY DEFAULT AS IDENTITY,
    vin           varchar(17) NOT NULL,
    cliente_id    integer      NOT NULL,
    desde         date        NOT NULL,
    hasta         date,
    CONSTRAINT pk_propiedad_vehiculo PRIMARY KEY (propiedad_id),
    CONSTRAINT fk_propiedad_vehiculo FOREIGN KEY (vin) REFERENCES vehiculo (vin),
    CONSTRAINT fk_propiedad_cliente FOREIGN KEY (cliente_id) REFERENCES cliente (cliente_id),
    CONSTRAINT ck_propiedad_vigencia CHECK (hasta IS NULL OR hasta > desde),
    -- Un vehículo no puede tener dos propietarios en el mismo periodo.
    CONSTRAINT ex_propiedad_sin_traslape EXCLUDE USING gist (
        vin WITH =, daterange(desde, hasta, '[)') WITH &&)
);
CREATE TABLE
-- 5) PERSONAL
CREATE TABLE personal (
    personal_id  integer GENERATED BY DEFAULT AS IDENTITY,
    nombre       varchar(120) NOT NULL,
    rol          varchar(20)  NOT NULL,
    activo       boolean      NOT NULL DEFAULT true,
    CONSTRAINT pk_personal PRIMARY KEY (personal_id),
    CONSTRAINT ck_personal_nombre CHECK (btrim(nombre) <> ''),
    CONSTRAINT ck_personal_rol CHECK (rol IN ('Recepción', 'Técnico', 'Otro'))
);
CREATE TABLE
-- 6) ESPECIALIDAD_TECNICO: especialidades con vigencia (RN-14).
CREATE TABLE especialidad_tecnico (
    especialidad_id  bigint GENERATED BY DEFAULT AS IDENTITY,
    tecnico_id       integer      NOT NULL,
    especialidad     varchar(30) NOT NULL,
    fecha_inicio     date        NOT NULL,
    fecha_fin        date,
    CONSTRAINT pk_especialidad_tecnico PRIMARY KEY (especialidad_id),
    CONSTRAINT uq_especialidad_tecnico_ctx UNIQUE (especialidad_id, tecnico_id),
    CONSTRAINT fk_especialidad_tecnico FOREIGN KEY (tecnico_id) REFERENCES personal (personal_id),
    CONSTRAINT ck_especialidad_valor CHECK (especialidad IN ('Electricidad', 'Frenos', 'Mecánica general', 'Otra')),
    CONSTRAINT ck_especialidad_vigencia CHECK (fecha_fin IS NULL OR fecha_fin >= fecha_inicio),
    -- La misma especialidad no puede tener periodos traslapados para un técnico.
    CONSTRAINT ex_especialidad_sin_traslape EXCLUDE USING gist (
        tecnico_id WITH =, especialidad WITH =, daterange(fecha_inicio, fecha_fin, '[]') WITH &&)
);
CREATE TABLE
-- 7) REPUESTO: código interno de texto (ej. FR-001), distinto del código del
--    proveedor (RN-17).
CREATE TABLE repuesto (
    repuesto_id    varchar(20)  NOT NULL,
    descripcion    varchar(150) NOT NULL,
    marca          varchar(60),
    unidad_manejo  varchar(10)  NOT NULL,
    CONSTRAINT pk_repuesto PRIMARY KEY (repuesto_id),
    CONSTRAINT ck_repuesto_codigo CHECK (repuesto_id ~ '^[A-Z]{2,4}-[0-9]{3,6}$'),
    CONSTRAINT ck_repuesto_descripcion CHECK (btrim(descripcion) <> ''),
    CONSTRAINT ck_repuesto_unidad CHECK (unidad_manejo IN ('Unidad', 'Juego', 'Litro', 'Metro', 'Otro'))
);
CREATE TABLE
-- 8) PROVEEDOR (nueva): resuelve la ambigüedad del P1, que solo guardaba el
--    nombre del proveedor como texto dentro de PROVEEDOR_REPUESTO.
CREATE TABLE proveedor (
    proveedor_id    bigint GENERATED BY DEFAULT AS IDENTITY,
    nombre          varchar(150) NOT NULL,
    identificacion  varchar(30),
    CONSTRAINT pk_proveedor PRIMARY KEY (proveedor_id),
    CONSTRAINT uq_proveedor_nombre UNIQUE (nombre),
    CONSTRAINT uq_proveedor_identificacion UNIQUE (identificacion),
    CONSTRAINT ck_proveedor_nombre CHECK (btrim(nombre) <> '')
);
CREATE TABLE
-- 9) PROVEEDOR_REPUESTO: código y precio de referencia por proveedor.
CREATE TABLE proveedor_repuesto (
    proveedor_repuesto_id  bigint GENERATED BY DEFAULT AS IDENTITY,
    proveedor_id           bigint       NOT NULL,
    repuesto_id            varchar(20)  NOT NULL,
    codigo_proveedor       varchar(40)  NOT NULL,
    precio_referencia      numeric(12,2),
    CONSTRAINT pk_proveedor_repuesto PRIMARY KEY (proveedor_repuesto_id),
    CONSTRAINT fk_prov_rep_proveedor FOREIGN KEY (proveedor_id) REFERENCES proveedor (proveedor_id),
    CONSTRAINT fk_prov_rep_repuesto FOREIGN KEY (repuesto_id) REFERENCES repuesto (repuesto_id),
    CONSTRAINT uq_prov_rep_codigo UNIQUE (proveedor_id, codigo_proveedor),
    CONSTRAINT uq_prov_rep_repuesto UNIQUE (proveedor_id, repuesto_id),
    CONSTRAINT ck_prov_rep_codigo CHECK (btrim(codigo_proveedor) <> ''),
    CONSTRAINT ck_prov_rep_precio CHECK (precio_referencia IS NULL OR precio_referencia >= 0)
);
CREATE TABLE
-- =====================================================================
-- 2. VISITA / RECEPCIÓN
-- =====================================================================
-- 10) ORDEN_TRABAJO: una orden = una visita de un vehículo (RN-01).
--     Los roles (factura / entrega / autoriza / recibe) quedan fijados por
--     visita (RN-04). estado_actual y fecha_prometida_actual son valores
--     vigentes que SOLO se modifican desde sus historiales (corrige D4).
CREATE TABLE orden_trabajo (
    orden_id                  integer GENERATED BY DEFAULT AS IDENTITY,
    vin                       varchar(17)  NOT NULL,
    placa_ingreso             varchar(15)  NOT NULL,
    cliente_factura_id        integer       NOT NULL,
    entregado_por_cliente_id  integer       NOT NULL,
    autorizador_cliente_id    integer       NOT NULL,
    receptor_id               integer       NOT NULL,
    fecha_hora_recepcion      timestamptz  NOT NULL DEFAULT now(),
    kilometraje_ingreso       integer      NOT NULL,
    nivel_combustible         varchar(10)  NOT NULL,
    motivo_informado          text         NOT NULL,
    observaciones_visibles    text,
    fecha_prometida_actual    timestamptz,
    estado_actual             d_estado_orden NOT NULL DEFAULT 'Recibida',
    CONSTRAINT pk_orden_trabajo PRIMARY KEY (orden_id),
    CONSTRAINT uq_orden_trabajo_vin UNIQUE (orden_id, vin),
    CONSTRAINT fk_orden_vehiculo FOREIGN KEY (vin) REFERENCES vehiculo (vin),
    CONSTRAINT fk_orden_cliente_factura FOREIGN KEY (cliente_factura_id) REFERENCES cliente (cliente_id),
    CONSTRAINT fk_orden_cliente_entrega FOREIGN KEY (entregado_por_cliente_id) REFERENCES cliente (cliente_id),
    CONSTRAINT fk_orden_cliente_autoriza FOREIGN KEY (autorizador_cliente_id) REFERENCES cliente (cliente_id),
    CONSTRAINT fk_orden_receptor FOREIGN KEY (receptor_id) REFERENCES personal (personal_id),
    CONSTRAINT ck_orden_id_positivo CHECK (orden_id > 0),
    CONSTRAINT ck_orden_km_ingreso CHECK (kilometraje_ingreso >= 0),
    CONSTRAINT ck_orden_combustible CHECK (nivel_combustible IN ('Vacío', '1/4', '1/2', '3/4', 'Lleno')),
    CONSTRAINT ck_orden_motivo CHECK (btrim(motivo_informado) <> ''),
    CONSTRAINT ck_orden_placa_ingreso CHECK (btrim(placa_ingreso) <> ''),
    CONSTRAINT ck_orden_fecha_prometida CHECK (fecha_prometida_actual IS NULL OR fecha_prometida_actual > fecha_hora_recepcion)
);
CREATE TABLE
-- 11) FACULTAD_ORDEN (nueva, D2): facultad real para Aprobar o Retirar en
--     una visita concreta, con fuente, verificación y vigencia.
CREATE TABLE facultad_orden (
    facultad_id              bigint GENERATED BY DEFAULT AS IDENTITY,
    orden_id                 integer       NOT NULL,
    cliente_id               integer       NOT NULL,
    tipo_facultad            varchar(10)  NOT NULL,
    fuente                   varchar(25)  NOT NULL,
    otorgada_por_cliente_id  integer,
    medio_verificacion       text         NOT NULL,
    vigente_desde            timestamptz  NOT NULL,
    vigente_hasta            timestamptz,
    registrada_por_id        integer       NOT NULL,
    CONSTRAINT pk_facultad_orden PRIMARY KEY (facultad_id),
    CONSTRAINT uq_facultad_orden_ctx UNIQUE (facultad_id, orden_id),
    CONSTRAINT fk_facultad_orden FOREIGN KEY (orden_id) REFERENCES orden_trabajo (orden_id),
    CONSTRAINT fk_facultad_cliente FOREIGN KEY (cliente_id) REFERENCES cliente (cliente_id),
    CONSTRAINT fk_facultad_otorgante FOREIGN KEY (otorgada_por_cliente_id) REFERENCES cliente (cliente_id),
    CONSTRAINT fk_facultad_registrador FOREIGN KEY (registrada_por_id) REFERENCES personal (personal_id),
    CONSTRAINT ck_facultad_tipo CHECK (tipo_facultad IN ('Aprobar', 'Retirar')),
    CONSTRAINT ck_facultad_fuente CHECK (fuente IN ('Titular', 'Designación', 'Representación legal')),
    -- Titular: no la otorga nadie. Designación / representación: la otorga alguien.
    CONSTRAINT ck_facultad_otorgante CHECK (
        (fuente = 'Titular' AND otorgada_por_cliente_id IS NULL)
     OR (fuente <> 'Titular' AND otorgada_por_cliente_id IS NOT NULL AND otorgada_por_cliente_id <> cliente_id)),
    CONSTRAINT ck_facultad_verificacion CHECK (btrim(medio_verificacion) <> ''),
    CONSTRAINT ck_facultad_vigencia CHECK (vigente_hasta IS NULL OR vigente_hasta > vigente_desde),
    -- No se duplica la misma facultad vigente para la misma persona en la visita.
    CONSTRAINT ex_facultad_sin_traslape EXCLUDE USING gist (
        orden_id WITH =, cliente_id WITH =, tipo_facultad WITH =,
        tstzrange(vigente_desde, vigente_hasta, '[)') WITH &&)
);
CREATE TABLE
-- 12) OBJETO_DANO: objetos dejados y daños visibles confirmados (RN-06).
CREATE TABLE objeto_dano (
    detalle_id          bigint GENERATED BY DEFAULT AS IDENTITY,
    orden_id            integer      NOT NULL,
    tipo_detalle        varchar(10) NOT NULL,
    descripcion         text        NOT NULL,
    confirmado_cliente  boolean     NOT NULL DEFAULT false,
    CONSTRAINT pk_objeto_dano PRIMARY KEY (detalle_id),
    CONSTRAINT fk_objeto_dano_orden FOREIGN KEY (orden_id) REFERENCES orden_trabajo (orden_id),
    CONSTRAINT ck_objeto_dano_tipo CHECK (tipo_detalle IN ('Objeto', 'Daño')),
    CONSTRAINT ck_objeto_dano_descripcion CHECK (btrim(descripcion) <> '')
);
CREATE TABLE
-- 13) HISTORIAL_ORDEN: cambios de estado con responsable y momento (RN-08).
--     Se conserva el nombre de columna "estado" (= estado nuevo) del Lab03
--     para que el alta reutilizada siga funcionando sin cambios.
--     "secuencia" (asignada bajo bloqueo de la orden) da el orden inequívoco.
CREATE TABLE historial_orden (
    historial_id     bigint GENERATED ALWAYS AS IDENTITY,
    orden_id         integer         NOT NULL,
    secuencia        integer        NOT NULL,
    estado_anterior  d_estado_orden,
    estado           d_estado_orden NOT NULL,
    fecha_hora       timestamptz    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    personal_id      integer         NOT NULL,
    motivo           text,
    registrado_en    timestamptz    NOT NULL DEFAULT clock_timestamp(),
    CONSTRAINT pk_historial_orden PRIMARY KEY (historial_id),
    CONSTRAINT fk_historial_orden_orden FOREIGN KEY (orden_id) REFERENCES orden_trabajo (orden_id),
    CONSTRAINT fk_historial_orden_personal FOREIGN KEY (personal_id) REFERENCES personal (personal_id),
    CONSTRAINT uq_historial_orden_secuencia UNIQUE (orden_id, secuencia),
    CONSTRAINT ck_historial_orden_secuencia CHECK (secuencia >= 1),
    -- La primera fila es el alta: sin estado anterior y en 'Recibida'.
    CONSTRAINT ck_historial_orden_inicio CHECK (
        (secuencia = 1 AND estado_anterior IS NULL AND estado = 'Recibida')
     OR (secuencia > 1 AND estado_anterior IS NOT NULL AND estado_anterior <> estado)),
    CONSTRAINT ck_historial_orden_motivo CHECK (motivo IS NULL OR btrim(motivo) <> '')
);
CREATE TABLE
-- 14) HISTORIAL_FECHA_PROMETIDA: cada promesa con fecha comunicada, medio,
--     motivo y responsable, sin sobrescribir (RN-07). La fila con
--     fecha_anterior NULL es la promesa original.
CREATE TABLE historial_fecha_prometida (
    cambio_fecha_id          bigint GENERATED ALWAYS AS IDENTITY,
    orden_id                 integer       NOT NULL,
    secuencia                integer      NOT NULL,
    fecha_anterior           timestamptz,
    fecha_nueva              timestamptz  NOT NULL,
    fecha_hora_comunicacion  timestamptz  NOT NULL,
    medio_comunicacion       d_medio_comunicacion NOT NULL,
    motivo                   text,
    personal_id              integer       NOT NULL,
    registrado_en            timestamptz  NOT NULL DEFAULT clock_timestamp(),
    CONSTRAINT pk_historial_fecha_prometida PRIMARY KEY (cambio_fecha_id),
    CONSTRAINT fk_hfp_orden FOREIGN KEY (orden_id) REFERENCES orden_trabajo (orden_id),
    CONSTRAINT fk_hfp_personal FOREIGN KEY (personal_id) REFERENCES personal (personal_id),
    CONSTRAINT uq_hfp_secuencia UNIQUE (orden_id, secuencia),
    CONSTRAINT ck_hfp_secuencia CHECK (secuencia >= 1),
    CONSTRAINT ck_hfp_original CHECK ((secuencia = 1) = (fecha_anterior IS NULL)),
    -- Toda reprogramación (no la promesa original) exige motivo.
    CONSTRAINT ck_hfp_motivo CHECK (fecha_anterior IS NULL OR btrim(coalesce(motivo, '')) <> ''),
    CONSTRAINT ck_hfp_cambio_real CHECK (fecha_anterior IS NULL OR fecha_nueva <> fecha_anterior),
    CONSTRAINT ck_hfp_promesa_futura CHECK (fecha_nueva > fecha_hora_comunicacion)
);
CREATE TABLE
-- 15) TRANSICION_ESTADO_ORDEN (catálogo): pares permitidos. La secuencia NO
--     es lineal: hay retrocesos legítimos con motivo obligatorio.
CREATE TABLE transicion_estado_orden (
    estado_desde     d_estado_orden NOT NULL,
    estado_hacia     d_estado_orden NOT NULL,
    requiere_motivo  boolean        NOT NULL,
    descripcion      text           NOT NULL,
    CONSTRAINT pk_transicion_estado_orden PRIMARY KEY (estado_desde, estado_hacia),
    CONSTRAINT ck_transicion_distinta CHECK (estado_desde <> estado_hacia),
    CONSTRAINT ck_transicion_terminal CHECK (estado_desde NOT IN ('Entregada', 'Cancelada'))
);
CREATE TABLE
INSERT INTO transicion_estado_orden (estado_desde, estado_hacia, requiere_motivo, descripcion) VALUES
 ('Recibida',               'En diagnóstico',         false, 'Inicio del diagnóstico'),
 ('Recibida',               'Cancelada',              true,  'Cancelación antes del diagnóstico'),
 ('En diagnóstico',         'Pendiente autorización', false, 'Propuesta presentada al cliente'),
 ('En diagnóstico',         'Cancelada',              true,  'Cancelación durante el diagnóstico'),
 ('Pendiente autorización', 'Autorizada',             false, 'El cliente aceptó al menos una labor'),
 ('Pendiente autorización', 'En diagnóstico',         true,  'Retroceso: se requiere diagnóstico adicional'),
 ('Pendiente autorización', 'Cancelada',              true,  'El cliente no autoriza ninguna labor'),
 ('Autorizada',             'En reparación',          false, 'Inicio de la ejecución'),
 ('Autorizada',             'Pendiente autorización', true,  'Retroceso: nueva versión de propuesta'),
 ('Autorizada',             'En diagnóstico',         true,  'Retroceso: se requiere diagnóstico adicional'),
 ('Autorizada',             'Cancelada',              true,  'Cancelación antes de reparar'),
 ('En reparación',          'Lista entrega',          false, 'Labores terminadas y probadas'),
 ('En reparación',          'En diagnóstico',         true,  'Retroceso: hallazgo nuevo durante la reparación'),
 ('En reparación',          'Pendiente autorización', true,  'Retroceso: ampliación que requiere decisión'),
 ('En reparación',          'Cancelada',              true,  'Cancelación durante la reparación'),
 ('Lista entrega',          'Entregada',              false, 'Entrega registrada'),
 ('Lista entrega',          'En reparación',          true,  'Retroceso: retrabajo antes de entregar'),
 ('Lista entrega',          'Cancelada',              true,  'Cancelación con el vehículo listo');
INSERT 0 18
-- =====================================================================
-- 3. DIAGNÓSTICO Y PRESUPUESTO (G02-P01)
-- =====================================================================
-- 16) HALLAZGO: con autor y momento (corrige D1).
CREATE TABLE hallazgo (
    hallazgo_id           integer GENERATED BY DEFAULT AS IDENTITY,
    orden_id              integer      NOT NULL,
    diagnosticado_por_id  integer      NOT NULL,
    fecha_hora            timestamptz NOT NULL DEFAULT now(),
    sintoma_comprobado    text        NOT NULL,
    posible_causa         text,
    urgencia              varchar(12) NOT NULL,
    recomendacion         text        NOT NULL,
    CONSTRAINT pk_hallazgo PRIMARY KEY (hallazgo_id),
    CONSTRAINT uq_hallazgo_orden UNIQUE (hallazgo_id, orden_id),
    CONSTRAINT fk_hallazgo_orden FOREIGN KEY (orden_id) REFERENCES orden_trabajo (orden_id),
    CONSTRAINT fk_hallazgo_autor FOREIGN KEY (diagnosticado_por_id) REFERENCES personal (personal_id),
    CONSTRAINT ck_hallazgo_sintoma CHECK (btrim(sintoma_comprobado) <> ''),
    CONSTRAINT ck_hallazgo_urgencia CHECK (urgencia IN ('Baja', 'Media', 'Alta', 'Crítica')),
    CONSTRAINT ck_hallazgo_recomendacion CHECK (btrim(recomendacion) <> '')
);
CREATE TABLE
-- 17) PROPUESTA: versiones de la propuesta de una orden (RN-10). Una versión
--     'Presentada' es inmutable, igual que sus líneas.
CREATE TABLE propuesta (
    propuesta_id             bigint GENERATED BY DEFAULT AS IDENTITY,
    orden_id                 integer       NOT NULL,
    version                  integer      NOT NULL,
    estado                   varchar(12)  NOT NULL DEFAULT 'Borrador',
    propuesta_base_id        bigint,
    presentada_por_id        integer       NOT NULL,
    fecha_hora_presentacion  timestamptz,
    observacion              text,
    creada_en                timestamptz  NOT NULL DEFAULT clock_timestamp(),
    CONSTRAINT pk_propuesta PRIMARY KEY (propuesta_id),
    CONSTRAINT uq_propuesta_version UNIQUE (orden_id, version),
    CONSTRAINT uq_propuesta_orden UNIQUE (propuesta_id, orden_id),
    CONSTRAINT fk_propuesta_orden FOREIGN KEY (orden_id) REFERENCES orden_trabajo (orden_id),
    -- La versión base debe ser de la MISMA orden.
    CONSTRAINT fk_propuesta_base FOREIGN KEY (propuesta_base_id, orden_id) REFERENCES propuesta (propuesta_id, orden_id),
    CONSTRAINT fk_propuesta_personal FOREIGN KEY (presentada_por_id) REFERENCES personal (personal_id),
    CONSTRAINT ck_propuesta_version CHECK (version >= 1),
    CONSTRAINT ck_propuesta_estado CHECK (estado IN ('Borrador', 'Presentada')),
    CONSTRAINT ck_propuesta_presentacion CHECK ((estado = 'Presentada') = (fecha_hora_presentacion IS NOT NULL)),
    CONSTRAINT ck_propuesta_base_distinta CHECK (propuesta_base_id IS NULL OR propuesta_base_id <> propuesta_id)
);
CREATE TABLE
-- 18) LABOR: trabajo estable de la orden (separado de su precio en cada
--     versión, corrige D6). Un retrabajo referencia la labor revisada y la
--     prueba que lo originó (RN-15).
CREATE TABLE labor (
    labor_id           bigint GENERATED BY DEFAULT AS IDENTITY,
    orden_id           integer         NOT NULL,
    hallazgo_id        integer,
    descripcion        text           NOT NULL,
    es_emergencia      boolean        NOT NULL DEFAULT false,
    labor_revisada_id  bigint,
    prueba_origen_id   bigint,
    estado_labor       d_estado_labor NOT NULL DEFAULT 'Pendiente',
    creada_por_id      integer         NOT NULL,
    creada_en          timestamptz    NOT NULL DEFAULT now(),
    CONSTRAINT pk_labor PRIMARY KEY (labor_id),
    CONSTRAINT uq_labor_orden UNIQUE (labor_id, orden_id),
    CONSTRAINT fk_labor_orden FOREIGN KEY (orden_id) REFERENCES orden_trabajo (orden_id),
    -- El hallazgo que origina la labor debe ser de la MISMA orden.
    CONSTRAINT fk_labor_hallazgo FOREIGN KEY (hallazgo_id, orden_id) REFERENCES hallazgo (hallazgo_id, orden_id),
    -- El retrabajo revisa una labor de la MISMA orden (el de garantía va por reclamo_garantia).
    CONSTRAINT fk_labor_revisada FOREIGN KEY (labor_revisada_id, orden_id) REFERENCES labor (labor_id, orden_id),
    CONSTRAINT fk_labor_creador FOREIGN KEY (creada_por_id) REFERENCES personal (personal_id),
    CONSTRAINT ck_labor_descripcion CHECK (btrim(descripcion) <> ''),
    CONSTRAINT ck_labor_no_autorrevision CHECK (labor_revisada_id IS NULL OR labor_revisada_id <> labor_id),
    CONSTRAINT ck_labor_prueba_origen CHECK (prueba_origen_id IS NULL OR labor_revisada_id IS NOT NULL)
    -- fk_labor_prueba_origen se agrega después de crear PRUEBA.
);
CREATE TABLE
-- 19) LINEA_PROPUESTA (nueva, D6): la labor dentro de una versión, con su
--     precio y alcance. Permite comparar la misma labor entre versiones.
CREATE TABLE linea_propuesta (
    propuesta_id     bigint        NOT NULL,
    labor_id         bigint        NOT NULL,
    orden_id         integer        NOT NULL,
    precio_estimado  numeric(12,2) NOT NULL,
    alcance          text          NOT NULL,
    CONSTRAINT pk_linea_propuesta PRIMARY KEY (propuesta_id, labor_id),
    CONSTRAINT uq_linea_propuesta_ctx UNIQUE (propuesta_id, labor_id, orden_id),
    -- Propuesta y labor deben pertenecer a la MISMA orden.
    CONSTRAINT fk_linea_propuesta FOREIGN KEY (propuesta_id, orden_id) REFERENCES propuesta (propuesta_id, orden_id),
    CONSTRAINT fk_linea_labor FOREIGN KEY (labor_id, orden_id) REFERENCES labor (labor_id, orden_id),
    CONSTRAINT ck_linea_precio CHECK (precio_estimado >= 0),
    CONSTRAINT ck_linea_alcance CHECK (btrim(alcance) <> '')
);
CREATE TABLE
-- 20) REPUESTO_PROPUESTO: repuestos estimados por línea de versión (RN-18).
CREATE TABLE repuesto_propuesto (
    propuesta_id              bigint        NOT NULL,
    labor_id                  bigint        NOT NULL,
    repuesto_id               varchar(20)   NOT NULL,
    cantidad_estimada         numeric(10,2) NOT NULL,
    precio_unitario_estimado  numeric(12,2) NOT NULL,
    CONSTRAINT pk_repuesto_propuesto PRIMARY KEY (propuesta_id, labor_id, repuesto_id),
    CONSTRAINT fk_rep_prop_linea FOREIGN KEY (propuesta_id, labor_id) REFERENCES linea_propuesta (propuesta_id, labor_id),
    CONSTRAINT fk_rep_prop_repuesto FOREIGN KEY (repuesto_id) REFERENCES repuesto (repuesto_id),
    CONSTRAINT ck_rep_prop_cantidad CHECK (cantidad_estimada > 0),
    CONSTRAINT ck_rep_prop_precio CHECK (precio_unitario_estimado >= 0)
);
CREATE TABLE
-- 21) AUTORIZACION_LABOR: decisión por labor y versión (RN-11), solo
--     inserción. Referencia la facultad con la que se decidió (D2).
CREATE TABLE autorizacion_labor (
    autorizacion_id    bigint GENERATED BY DEFAULT AS IDENTITY,
    propuesta_id       bigint      NOT NULL,
    labor_id           bigint      NOT NULL,
    orden_id           integer      NOT NULL,
    facultad_id        bigint      NOT NULL,
    cliente_id         integer      NOT NULL,
    decision           varchar(10) NOT NULL,
    fecha_hora         timestamptz NOT NULL,
    medio              d_medio_comunicacion NOT NULL,
    observacion        text,
    registrado_por_id  integer      NOT NULL,
    registrado_en      timestamptz NOT NULL DEFAULT clock_timestamp(),
    CONSTRAINT pk_autorizacion_labor PRIMARY KEY (autorizacion_id),
    CONSTRAINT uq_autorizacion_labor_ctx UNIQUE (autorizacion_id, labor_id),
    -- La decisión es sobre una línea existente de ESA versión y ESA orden.
    CONSTRAINT fk_autorizacion_linea FOREIGN KEY (propuesta_id, labor_id, orden_id)
        REFERENCES linea_propuesta (propuesta_id, labor_id, orden_id),
    -- La facultad usada debe ser de la MISMA orden.
    CONSTRAINT fk_autorizacion_facultad FOREIGN KEY (facultad_id, orden_id) REFERENCES facultad_orden (facultad_id, orden_id),
    CONSTRAINT fk_autorizacion_cliente FOREIGN KEY (cliente_id) REFERENCES cliente (cliente_id),
    CONSTRAINT fk_autorizacion_registrador FOREIGN KEY (registrado_por_id) REFERENCES personal (personal_id),
    CONSTRAINT ck_autorizacion_decision CHECK (decision IN ('Aceptada', 'Rechazada', 'Pendiente'))
);
CREATE TABLE
-- =====================================================================
-- 4. EJECUCIÓN (G02-P02)
-- =====================================================================
-- 22) EXCEPCION_EMERGENCIA (nueva, D8): habilita SOLO su labor (RN-12).
CREATE TABLE excepcion_emergencia (
    emergencia_id      bigint GENERATED BY DEFAULT AS IDENTITY,
    labor_id           bigint      NOT NULL,
    orden_id           integer      NOT NULL,
    riesgo             text        NOT NULL,
    justificacion      text        NOT NULL,
    alcance_minimo     text        NOT NULL,
    autorizada_por_id  integer      NOT NULL,
    fecha_hora         timestamptz NOT NULL,
    CONSTRAINT pk_excepcion_emergencia PRIMARY KEY (emergencia_id),
    CONSTRAINT uq_emergencia_labor UNIQUE (labor_id),
    CONSTRAINT uq_emergencia_ctx UNIQUE (emergencia_id, labor_id),
    CONSTRAINT fk_emergencia_labor FOREIGN KEY (labor_id, orden_id) REFERENCES labor (labor_id, orden_id),
    CONSTRAINT fk_emergencia_personal FOREIGN KEY (autorizada_por_id) REFERENCES personal (personal_id),
    CONSTRAINT ck_emergencia_riesgo CHECK (btrim(riesgo) <> ''),
    CONSTRAINT ck_emergencia_justificacion CHECK (char_length(btrim(justificacion)) >= 20),
    CONSTRAINT ck_emergencia_alcance CHECK (btrim(alcance_minimo) <> '')
);
CREATE TABLE
-- 23) LABOR_DEPENDENCIA (nueva, D7): N:M recursiva entre labores de la
--     misma orden; sin ciclos (trigger).
CREATE TABLE labor_dependencia (
    labor_id           bigint NOT NULL,
    requiere_labor_id  bigint NOT NULL,
    orden_id           integer NOT NULL,
    CONSTRAINT pk_labor_dependencia PRIMARY KEY (labor_id, requiere_labor_id),
    CONSTRAINT fk_dependencia_labor FOREIGN KEY (labor_id, orden_id) REFERENCES labor (labor_id, orden_id),
    CONSTRAINT fk_dependencia_requerida FOREIGN KEY (requiere_labor_id, orden_id) REFERENCES labor (labor_id, orden_id),
    CONSTRAINT ck_dependencia_distinta CHECK (labor_id <> requiere_labor_id)
);
CREATE TABLE
-- 24) HISTORIAL_LABOR (nueva, D9): estados de la labor con la autorización
--     o emergencia que habilitó su ejecución.
CREATE TABLE historial_labor (
    historial_labor_id  bigint GENERATED ALWAYS AS IDENTITY,
    labor_id            bigint         NOT NULL,
    secuencia           integer        NOT NULL,
    estado_anterior     d_estado_labor,
    estado_nuevo        d_estado_labor NOT NULL,
    fecha_hora          timestamptz    NOT NULL DEFAULT now(),
    personal_id         integer         NOT NULL,
    autorizacion_id     bigint,
    emergencia_id       bigint,
    motivo              text,
    registrado_en       timestamptz    NOT NULL DEFAULT clock_timestamp(),
    CONSTRAINT pk_historial_labor PRIMARY KEY (historial_labor_id),
    CONSTRAINT uq_historial_labor_secuencia UNIQUE (labor_id, secuencia),
    CONSTRAINT fk_historial_labor_labor FOREIGN KEY (labor_id) REFERENCES labor (labor_id),
    CONSTRAINT fk_historial_labor_personal FOREIGN KEY (personal_id) REFERENCES personal (personal_id),
    -- La autorización / emergencia citada debe ser de ESA labor.
    CONSTRAINT fk_historial_labor_autorizacion FOREIGN KEY (autorizacion_id, labor_id)
        REFERENCES autorizacion_labor (autorizacion_id, labor_id),
    CONSTRAINT fk_historial_labor_emergencia FOREIGN KEY (emergencia_id, labor_id)
        REFERENCES excepcion_emergencia (emergencia_id, labor_id),
    CONSTRAINT ck_historial_labor_inicio CHECK (
        (secuencia = 1 AND estado_anterior IS NULL AND estado_nuevo = 'Pendiente')
     OR (secuencia > 1 AND estado_anterior IS NOT NULL AND estado_anterior <> estado_nuevo)),
    -- Pasar a 'En proceso' exige exactamente un habilitante; los demás cambios, ninguno.
    CONSTRAINT ck_historial_labor_habilitante CHECK (
        (estado_nuevo = 'En proceso' AND num_nonnulls(autorizacion_id, emergencia_id) = 1)
     OR (estado_nuevo <> 'En proceso' AND num_nonnulls(autorizacion_id, emergencia_id) = 0)),
    CONSTRAINT ck_historial_labor_motivo CHECK (motivo IS NULL OR btrim(motivo) <> '')
);
CREATE TABLE
-- 25) PARTICIPACION_TECNICA: varios técnicos con tiempos (RN-13).
--     minutos_efectivos (antes minutos_dedicados) puede ser menor que la
--     duración del intervalo (pausas), nunca mayor.
CREATE TABLE participacion_tecnica (
    participacion_id           bigint GENERATED BY DEFAULT AS IDENTITY,
    labor_id                   bigint      NOT NULL,
    orden_id                   integer      NOT NULL,
    tecnico_id                 integer      NOT NULL,
    especialidad_id            bigint,
    inicio                     timestamptz NOT NULL,
    fin                        timestamptz,
    minutos_efectivos          integer,
    descripcion_participacion  text        NOT NULL,
    CONSTRAINT pk_participacion_tecnica PRIMARY KEY (participacion_id),
    CONSTRAINT fk_participacion_labor FOREIGN KEY (labor_id, orden_id) REFERENCES labor (labor_id, orden_id),
    CONSTRAINT fk_participacion_tecnico FOREIGN KEY (tecnico_id) REFERENCES personal (personal_id),
    -- La especialidad citada debe ser DEL técnico que participa.
    CONSTRAINT fk_participacion_especialidad FOREIGN KEY (especialidad_id, tecnico_id)
        REFERENCES especialidad_tecnico (especialidad_id, tecnico_id),
    CONSTRAINT ck_participacion_intervalo CHECK (fin IS NULL OR fin > inicio),
    CONSTRAINT ck_participacion_cierre CHECK (
        (fin IS NULL AND minutos_efectivos IS NULL)
     OR (fin IS NOT NULL AND minutos_efectivos IS NOT NULL AND minutos_efectivos > 0)),
    -- Coherencia minutos / intervalo (validación posterior del P1).
    CONSTRAINT ck_participacion_minutos CHECK (
        fin IS NULL OR minutos_efectivos <= floor(extract(epoch FROM (fin - inicio)) / 60)),
    CONSTRAINT ck_participacion_descripcion CHECK (btrim(descripcion_participacion) <> ''),
    -- Un técnico no puede estar en dos intervenciones al mismo tiempo.
    CONSTRAINT ex_participacion_tecnico EXCLUDE USING gist (
        tecnico_id WITH =, tstzrange(inicio, fin, '[)') WITH &&)
);
CREATE TABLE
-- 26) PRUEBA: qué, quién, cuándo y resultado categórico (RN-16, corrige D10).
CREATE TABLE prueba (
    prueba_id              bigint GENERATED BY DEFAULT AS IDENTITY,
    labor_id               bigint        NOT NULL,
    orden_id               integer        NOT NULL,
    personal_id            integer        NOT NULL,
    fecha_hora             timestamptz   NOT NULL,
    tipo_prueba            varchar(60)   NOT NULL,
    resultado              varchar(20)   NOT NULL,
    medicion_valor         numeric(12,3),
    unidad                 varchar(20),
    descripcion_resultado  text          NOT NULL,
    CONSTRAINT pk_prueba PRIMARY KEY (prueba_id),
    CONSTRAINT uq_prueba_labor UNIQUE (prueba_id, labor_id),
    CONSTRAINT fk_prueba_labor FOREIGN KEY (labor_id, orden_id) REFERENCES labor (labor_id, orden_id),
    CONSTRAINT fk_prueba_personal FOREIGN KEY (personal_id) REFERENCES personal (personal_id),
    CONSTRAINT ck_prueba_tipo CHECK (btrim(tipo_prueba) <> ''),
    CONSTRAINT ck_prueba_resultado CHECK (resultado IN ('Favorable', 'Desfavorable', 'No concluyente')),
    CONSTRAINT ck_prueba_medicion CHECK ((medicion_valor IS NULL) = (unidad IS NULL)),
    CONSTRAINT ck_prueba_unidad CHECK (unidad IS NULL OR btrim(unidad) <> ''),
    CONSTRAINT ck_prueba_descripcion CHECK (btrim(descripcion_resultado) <> '')
);
CREATE TABLE
-- Ahora que existe PRUEBA: la prueba que origina un retrabajo debe ser una
-- prueba DE la labor revisada.
ALTER TABLE labor
    ADD CONSTRAINT fk_labor_prueba_origen FOREIGN KEY (prueba_origen_id, labor_revisada_id)
        REFERENCES prueba (prueba_id, labor_id);
ALTER TABLE
-- 27) CONSUMO_REPUESTO: lo realmente utilizado (≠ lo estimado, RN-18).
CREATE TABLE consumo_repuesto (
    consumo_id               bigint GENERATED BY DEFAULT AS IDENTITY,
    labor_id                 bigint        NOT NULL,
    orden_id                 integer        NOT NULL,
    repuesto_id              varchar(20)   NOT NULL,
    cantidad_utilizada       numeric(10,2) NOT NULL,
    precio_unitario_cargado  numeric(12,2) NOT NULL,
    fecha_hora               timestamptz   NOT NULL DEFAULT now(),
    registrado_por_id        integer        NOT NULL,
    CONSTRAINT pk_consumo_repuesto PRIMARY KEY (consumo_id),
    CONSTRAINT uq_consumo_ctx UNIQUE (consumo_id, repuesto_id, orden_id),
    CONSTRAINT fk_consumo_labor FOREIGN KEY (labor_id, orden_id) REFERENCES labor (labor_id, orden_id),
    CONSTRAINT fk_consumo_repuesto FOREIGN KEY (repuesto_id) REFERENCES repuesto (repuesto_id),
    CONSTRAINT fk_consumo_registrador FOREIGN KEY (registrado_por_id) REFERENCES personal (personal_id),
    CONSTRAINT ck_consumo_cantidad CHECK (cantidad_utilizada > 0),
    CONSTRAINT ck_consumo_precio CHECK (precio_unitario_cargado >= 0)
);
CREATE TABLE
-- 28) MOVIMIENTO_INVENTARIO: entradas, reservas, liberaciones, consumos y
--     ajustes (RN-19). cantidad > 0; el signo lo da el tipo. Un consumo
--     siempre tiene origen (corrige D11).
CREATE TABLE movimiento_inventario (
    movimiento_id      bigint GENERATED BY DEFAULT AS IDENTITY,
    repuesto_id        varchar(20)   NOT NULL,
    orden_id           integer,
    tipo_movimiento    varchar(20)   NOT NULL,
    cantidad           numeric(10,2) NOT NULL,
    fecha_hora         timestamptz   NOT NULL DEFAULT now(),
    consumo_id         bigint,
    registrado_por_id  integer        NOT NULL,
    motivo             text,
    CONSTRAINT pk_movimiento_inventario PRIMARY KEY (movimiento_id),
    CONSTRAINT uq_movimiento_consumo UNIQUE (consumo_id),
    CONSTRAINT fk_movimiento_repuesto FOREIGN KEY (repuesto_id) REFERENCES repuesto (repuesto_id),
    CONSTRAINT fk_movimiento_orden FOREIGN KEY (orden_id) REFERENCES orden_trabajo (orden_id),
    -- El movimiento de consumo coincide en repuesto y orden con su consumo.
    CONSTRAINT fk_movimiento_consumo FOREIGN KEY (consumo_id, repuesto_id, orden_id)
        REFERENCES consumo_repuesto (consumo_id, repuesto_id, orden_id),
    CONSTRAINT fk_movimiento_registrador FOREIGN KEY (registrado_por_id) REFERENCES personal (personal_id),
    CONSTRAINT ck_movimiento_tipo CHECK (tipo_movimiento IN (
        'Entrada', 'Reserva', 'Liberación', 'Consumo', 'Ajuste positivo', 'Ajuste negativo')),
    CONSTRAINT ck_movimiento_cantidad CHECK (cantidad > 0),
    CONSTRAINT ck_movimiento_consumo_origen CHECK ((tipo_movimiento = 'Consumo') = (consumo_id IS NOT NULL)),
    CONSTRAINT ck_movimiento_orden CHECK (
        tipo_movimiento NOT IN ('Reserva', 'Liberación', 'Consumo') OR orden_id IS NOT NULL),
    CONSTRAINT ck_movimiento_ajuste_motivo CHECK (
        tipo_movimiento NOT LIKE 'Ajuste%' OR btrim(coalesce(motivo, '')) <> '')
);
CREATE TABLE
-- 29) PIEZA_RETIRADA: piezas sustituidas y su destino.
CREATE TABLE pieza_retirada (
    pieza_retirada_id  bigint GENERATED BY DEFAULT AS IDENTITY,
    labor_id           bigint      NOT NULL,
    orden_id           integer      NOT NULL,
    descripcion        text        NOT NULL,
    destino            varchar(30) NOT NULL,
    fecha_hora         timestamptz NOT NULL DEFAULT now(),
    registrado_por_id  integer      NOT NULL,
    CONSTRAINT pk_pieza_retirada PRIMARY KEY (pieza_retirada_id),
    CONSTRAINT fk_pieza_labor FOREIGN KEY (labor_id, orden_id) REFERENCES labor (labor_id, orden_id),
    CONSTRAINT fk_pieza_registrador FOREIGN KEY (registrado_por_id) REFERENCES personal (personal_id),
    CONSTRAINT ck_pieza_descripcion CHECK (btrim(descripcion) <> ''),
    CONSTRAINT ck_pieza_destino CHECK (destino IN ('Entregada cliente', 'Desechada autorizada', 'Conservada temporalmente'))
);
CREATE TABLE
-- =====================================================================
-- 5. ENTREGA Y GARANTÍA (solo integridad)
-- =====================================================================
-- 30) ENTREGA: máximo una por orden; quien retira debe tener facultad
--     'Retirar' vigente (RN-20, D2).
CREATE TABLE entrega (
    entrega_id               bigint GENERATED BY DEFAULT AS IDENTITY,
    orden_id                 integer      NOT NULL,
    retira_cliente_id        integer      NOT NULL,
    facultad_id              bigint      NOT NULL,
    entregado_por_id         integer      NOT NULL,
    fecha_hora               timestamptz NOT NULL,
    kilometraje_salida       integer     NOT NULL,
    revision_final           text        NOT NULL,
    recomendaciones_futuras  text,
    conformidad              varchar(12) NOT NULL,
    observaciones            text,
    CONSTRAINT pk_entrega PRIMARY KEY (entrega_id),
    CONSTRAINT uq_entrega_orden UNIQUE (orden_id),
    CONSTRAINT uq_entrega_ctx UNIQUE (entrega_id, orden_id),
    CONSTRAINT fk_entrega_orden FOREIGN KEY (orden_id) REFERENCES orden_trabajo (orden_id),
    CONSTRAINT fk_entrega_cliente FOREIGN KEY (retira_cliente_id) REFERENCES cliente (cliente_id),
    CONSTRAINT fk_entrega_facultad FOREIGN KEY (facultad_id, orden_id) REFERENCES facultad_orden (facultad_id, orden_id),
    CONSTRAINT fk_entrega_personal FOREIGN KEY (entregado_por_id) REFERENCES personal (personal_id),
    CONSTRAINT ck_entrega_km CHECK (kilometraje_salida >= 0),
    CONSTRAINT ck_entrega_revision CHECK (btrim(revision_final) <> ''),
    CONSTRAINT ck_entrega_conformidad CHECK (conformidad IN ('Conforme', 'Inconforme')),
    CONSTRAINT ck_entrega_inconformidad CHECK (conformidad = 'Conforme' OR btrim(coalesce(observaciones, '')) <> '')
);
CREATE TABLE
-- 31) GARANTIA (nueva, D3): otorgada al entregar, por labor completada.
--     Existe aunque nunca haya reclamo.
CREATE TABLE garantia (
    garantia_id  bigint GENERATED BY DEFAULT AS IDENTITY,
    entrega_id   bigint  NOT NULL,
    orden_id     integer  NOT NULL,
    labor_id     bigint  NOT NULL,
    dias         integer,
    km           integer,
    condiciones  text,
    CONSTRAINT pk_garantia PRIMARY KEY (garantia_id),
    CONSTRAINT uq_garantia_labor UNIQUE (entrega_id, labor_id),
    -- Entrega y labor de la MISMA orden.
    CONSTRAINT fk_garantia_entrega FOREIGN KEY (entrega_id, orden_id) REFERENCES entrega (entrega_id, orden_id),
    CONSTRAINT fk_garantia_labor FOREIGN KEY (labor_id, orden_id) REFERENCES labor (labor_id, orden_id),
    CONSTRAINT ck_garantia_limite CHECK (dias IS NOT NULL OR km IS NOT NULL),
    CONSTRAINT ck_garantia_dias CHECK (dias IS NULL OR dias > 0),
    CONSTRAINT ck_garantia_km CHECK (km IS NULL OR km > 0)
);
CREATE TABLE
-- 32) RECLAMO_GARANTIA (reemplaza GARANTIA_RECLAMO, D3): posterior a la
--     entrega, abre una orden nueva del MISMO vehículo (RN-21) y solo se
--     acepta dentro de ambos límites: vence lo que ocurra primero (RN-22).
CREATE TABLE reclamo_garantia (
    reclamo_id       bigint GENERATED BY DEFAULT AS IDENTITY,
    garantia_id      bigint      NOT NULL,
    orden_nueva_id   integer      NOT NULL,
    fecha_reclamo    timestamptz NOT NULL,
    km_reclamo       integer     NOT NULL,
    evaluacion       text        NOT NULL,
    decision         varchar(10) NOT NULL,
    justificacion    text,
    evaluado_por_id  integer      NOT NULL,
    CONSTRAINT pk_reclamo_garantia PRIMARY KEY (reclamo_id),
    CONSTRAINT uq_reclamo_orden_nueva UNIQUE (orden_nueva_id),
    CONSTRAINT fk_reclamo_garantia FOREIGN KEY (garantia_id) REFERENCES garantia (garantia_id),
    CONSTRAINT fk_reclamo_orden FOREIGN KEY (orden_nueva_id) REFERENCES orden_trabajo (orden_id),
    CONSTRAINT fk_reclamo_personal FOREIGN KEY (evaluado_por_id) REFERENCES personal (personal_id),
    CONSTRAINT ck_reclamo_km CHECK (km_reclamo >= 0),
    CONSTRAINT ck_reclamo_evaluacion CHECK (btrim(evaluacion) <> ''),
    CONSTRAINT ck_reclamo_decision CHECK (decision IN ('Aceptada', 'Rechazada', 'Pendiente')),
    CONSTRAINT ck_reclamo_justificacion CHECK (decision = 'Pendiente' OR btrim(coalesce(justificacion, '')) <> '')
);
CREATE TABLE
-- =====================================================================
-- 6. ÍNDICES ADICIONALES (solo con razón técnica distinta de PK/UQ)
-- =====================================================================
-- RN-01: un vehículo no puede estar en dos visitas abiertas a la vez
-- (índice único parcial: solo cuenta órdenes no terminales).
CREATE UNIQUE INDEX uq_orden_abierta_por_vehiculo
    ON orden_trabajo (vin)
    WHERE estado_actual NOT IN ('Entregada', 'Cancelada');
CREATE INDEX
-- Heredado del Lab03 (Q01/Q04): último estado por orden.
CREATE INDEX idx_historial_orden_ultimo ON historial_orden (orden_id, fecha_hora DESC, historial_id DESC);
CREATE INDEX
-- Búsqueda de la última decisión de cada línea (regla de decisión aplicable).
CREATE INDEX idx_autorizacion_linea ON autorizacion_labor (propuesta_id, labor_id, fecha_hora DESC, autorizacion_id DESC);
CREATE INDEX
-- Cálculo de existencias por repuesto (se recalcula en cada movimiento).
CREATE INDEX idx_movimiento_repuesto ON movimiento_inventario (repuesto_id, tipo_movimiento);
CREATE INDEX
-- Facultades vigentes por orden y cliente (cada decisión y cada entrega).
CREATE INDEX idx_facultad_busqueda ON facultad_orden (orden_id, cliente_id, tipo_facultad);
CREATE INDEX
-- FK sin índice propio usadas en validaciones frecuentes.
CREATE INDEX idx_labor_orden ON labor (orden_id);
CREATE INDEX
CREATE INDEX idx_participacion_labor ON participacion_tecnica (labor_id);
CREATE INDEX
CREATE INDEX idx_prueba_labor ON prueba (labor_id, fecha_hora DESC);
CREATE INDEX
CREATE INDEX idx_consumo_labor ON consumo_repuesto (labor_id);
CREATE INDEX
-- =====================================================================
-- 7. COMENTARIOS DE DOCUMENTACIÓN (diccionario dentro de la base)
-- =====================================================================
COMMENT ON TABLE cliente IS 'Persona u organización que entrega, paga, aprueba o retira (RN-04, SD-02 del P1).';
COMMENT
COMMENT ON TABLE contacto_cliente IS 'Medios de contacto; al menos uno apto para avisos por cliente, verificado al COMMIT (RN-03).';
COMMENT
COMMENT ON TABLE vehiculo IS 'Vehículo identificado por su VIN estable; la placa puede cambiar (RN-02).';
COMMENT
COMMENT ON TABLE propiedad_vehiculo IS 'Propietarios del vehículo con vigencia sin traslapes (D12). No reescribe visitas.';
COMMENT
COMMENT ON TABLE personal IS 'Personal del taller con rol y estado activo.';
COMMENT
COMMENT ON TABLE especialidad_tecnico IS 'Especialidades de un técnico con vigencia sin traslapes (RN-14).';
COMMENT
COMMENT ON TABLE repuesto IS 'Catálogo de repuestos con código interno (RN-17).';
COMMENT
COMMENT ON TABLE proveedor IS 'Proveedores de repuestos (datos mínimos; sin flujo de compras).';
COMMENT
COMMENT ON TABLE proveedor_repuesto IS 'Código y precio de referencia de un repuesto en un proveedor (RN-17).';
COMMENT
COMMENT ON TABLE orden_trabajo IS 'Una visita de un vehículo (RN-01). estado_actual/fecha_prometida_actual solo cambian vía historial (D4).';
COMMENT
COMMENT ON TABLE objeto_dano IS 'Objetos dejados y daños visibles confirmados por el cliente (RN-06).';
COMMENT
COMMENT ON TABLE historial_orden IS 'Cambios de estado de la orden con responsable, momento, motivo y secuencia (RN-08). Solo inserción.';
COMMENT
COMMENT ON TABLE historial_fecha_prometida IS 'Promesa original y reprogramaciones con comunicación, medio, motivo y responsable (RN-07). Solo inserción.';
COMMENT
COMMENT ON TABLE transicion_estado_orden IS 'Catálogo de transiciones de estado permitidas (no lineal; retrocesos con motivo).';
COMMENT
COMMENT ON TABLE hallazgo IS 'Hallazgos del diagnóstico con autor técnico y momento (RN-09, D1).';
COMMENT
COMMENT ON TABLE propuesta IS 'Versiones de la propuesta de una orden; una versión presentada es inmutable (RN-10).';
COMMENT
COMMENT ON TABLE labor IS 'Trabajo estable de la orden, separado de su precio en cada versión (D6); retrabajos ligados (RN-15).';
COMMENT
COMMENT ON TABLE repuesto_propuesto IS 'Repuestos estimados por línea de versión (lo estimado, RN-18).';
COMMENT
COMMENT ON TABLE excepcion_emergencia IS 'Excepción justificada que habilita solo su labor de emergencia (RN-12, D8).';
COMMENT
COMMENT ON TABLE labor_dependencia IS 'Dependencias N:M entre labores de la misma orden, sin ciclos (RN-15, D7).';
COMMENT
COMMENT ON TABLE participacion_tecnica IS 'Participación de un técnico en una labor con intervalo y minutos efectivos (RN-13).';
COMMENT
COMMENT ON TABLE prueba IS 'Pruebas de una labor: qué, quién, cuándo y resultado categórico (RN-16, D10). Solo inserción.';
COMMENT
COMMENT ON TABLE consumo_repuesto IS 'Repuestos realmente utilizados (≠ estimados, RN-18); siempre con su movimiento de inventario.';
COMMENT
COMMENT ON TABLE pieza_retirada IS 'Piezas sustituidas y su destino.';
COMMENT
COMMENT ON TABLE entrega IS 'Entrega del vehículo (máx. 1 por orden) a quien tiene facultad Retirar (RN-20).';
COMMENT
COMMENT ON COLUMN orden_trabajo.placa_ingreso IS 'Instantánea de la placa al ingresar; no cambia si luego cambia la placa del vehículo (RN-02).';
COMMENT
COMMENT ON COLUMN orden_trabajo.autorizador_cliente_id IS 'Se conserva por compatibilidad con el alta del Lab03; la facultad real está en facultad_orden (D2).';
COMMENT
COMMENT ON TABLE facultad_orden IS 'Facultades por visita (Aprobar/Retirar) con fuente, verificación y vigencia (D2).';
COMMENT
COMMENT ON TABLE linea_propuesta IS 'Componente de versión: la labor con su precio y alcance en una versión concreta (D6).';
COMMENT
COMMENT ON TABLE autorizacion_labor IS 'Solo inserción. La decisión aplicable es la última sobre la línea de la versión vigente (ver README §P01).';
COMMENT
COMMENT ON TABLE historial_labor IS 'Estados de la labor con la autorización o emergencia habilitante (D9).';
COMMENT
COMMENT ON TABLE movimiento_inventario IS 'Físico = Entrada + Ajuste positivo - Ajuste negativo - Consumo; Disponible = Físico - (Reserva - Liberación). Nunca negativos.';
COMMENT
COMMENT ON TABLE garantia IS 'Garantía otorgada al entregar, por labor completada (D3). Vence lo que ocurra primero: días o km.';
COMMENT
COMMENT ON TABLE reclamo_garantia IS 'Reclamo posterior que abre una orden nueva del mismo VIN (RN-21, RN-22, D3).';
COMMENT
COMMENT ON COLUMN participacion_tecnica.minutos_efectivos IS 'Antes minutos_dedicados (P1). Puede ser menor que la duración del intervalo (pausas), nunca mayor.';
COMMENT
\echo '== 02 triggers de integridad'
== 02 triggers de integridad
\ir 02_triggers_integridad.sql
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
SET
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
CREATE FUNCTION
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
    -- La obligatoriedad la impone NOT NULL de forma declarativa.
    IF p_personal_id IS NULL THEN
        RETURN;
    END IF;
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
CREATE FUNCTION
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
CREATE FUNCTION
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
CREATE FUNCTION
CREATE FUNCTION fn_es_terminal(p_estado text)
RETURNS boolean
LANGUAGE sql IMMUTABLE
AS $$ SELECT p_estado IN ('Entregada', 'Cancelada') $$;
CREATE FUNCTION
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
CREATE FUNCTION
CREATE TRIGGER trg_historial_orden_inmutable        BEFORE UPDATE OR DELETE ON historial_orden           FOR EACH ROW EXECUTE FUNCTION fn_solo_insercion();
CREATE TRIGGER
CREATE TRIGGER trg_hfp_inmutable                    BEFORE UPDATE OR DELETE ON historial_fecha_prometida FOR EACH ROW EXECUTE FUNCTION fn_solo_insercion();
CREATE TRIGGER
CREATE TRIGGER trg_historial_labor_inmutable        BEFORE UPDATE OR DELETE ON historial_labor           FOR EACH ROW EXECUTE FUNCTION fn_solo_insercion();
CREATE TRIGGER
CREATE TRIGGER trg_autorizacion_inmutable           BEFORE UPDATE OR DELETE ON autorizacion_labor        FOR EACH ROW EXECUTE FUNCTION fn_solo_insercion();
CREATE TRIGGER
CREATE TRIGGER trg_emergencia_inmutable             BEFORE UPDATE OR DELETE ON excepcion_emergencia      FOR EACH ROW EXECUTE FUNCTION fn_solo_insercion();
CREATE TRIGGER
CREATE TRIGGER trg_dependencia_inmutable            BEFORE UPDATE OR DELETE ON labor_dependencia         FOR EACH ROW EXECUTE FUNCTION fn_solo_insercion();
CREATE TRIGGER
CREATE TRIGGER trg_prueba_inmutable                 BEFORE UPDATE OR DELETE ON prueba                    FOR EACH ROW EXECUTE FUNCTION fn_solo_insercion();
CREATE TRIGGER
CREATE TRIGGER trg_consumo_inmutable                BEFORE UPDATE OR DELETE ON consumo_repuesto          FOR EACH ROW EXECUTE FUNCTION fn_solo_insercion();
CREATE TRIGGER
CREATE TRIGGER trg_movimiento_inmutable             BEFORE UPDATE OR DELETE ON movimiento_inventario     FOR EACH ROW EXECUTE FUNCTION fn_solo_insercion();
CREATE TRIGGER
CREATE TRIGGER trg_pieza_inmutable                  BEFORE UPDATE OR DELETE ON pieza_retirada            FOR EACH ROW EXECUTE FUNCTION fn_solo_insercion();
CREATE TRIGGER
CREATE TRIGGER trg_entrega_inmutable                BEFORE UPDATE OR DELETE ON entrega                   FOR EACH ROW EXECUTE FUNCTION fn_solo_insercion();
CREATE TRIGGER
CREATE TRIGGER trg_garantia_inmutable               BEFORE UPDATE OR DELETE ON garantia                  FOR EACH ROW EXECUTE FUNCTION fn_solo_insercion();
CREATE TRIGGER
CREATE TRIGGER trg_transicion_inmutable             BEFORE UPDATE OR DELETE ON transicion_estado_orden   FOR EACH ROW EXECUTE FUNCTION fn_solo_insercion();
CREATE TRIGGER
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
CREATE FUNCTION
CREATE CONSTRAINT TRIGGER trg_cliente_contacto_avisos
    AFTER INSERT ON cliente
    DEFERRABLE INITIALLY DEFERRED
    FOR EACH ROW EXECUTE FUNCTION fn_verificar_contacto_avisos();
CREATE TRIGGER
CREATE CONSTRAINT TRIGGER trg_contacto_avisos
    AFTER INSERT OR UPDATE OR DELETE ON contacto_cliente
    DEFERRABLE INITIALLY DEFERRED
    FOR EACH ROW EXECUTE FUNCTION fn_verificar_contacto_avisos();
CREATE TRIGGER
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
CREATE FUNCTION
CREATE TRIGGER trg_vehiculo_anio
    BEFORE INSERT OR UPDATE OF anio ON vehiculo
    FOR EACH ROW EXECUTE FUNCTION fn_vehiculo_anio();
CREATE TRIGGER
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
CREATE FUNCTION
CREATE TRIGGER trg_vehiculo_vin_estable
    BEFORE UPDATE OF vin ON vehiculo
    FOR EACH ROW EXECUTE FUNCTION fn_vehiculo_vin_estable();
CREATE TRIGGER
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
CREATE FUNCTION
CREATE TRIGGER trg_especialidad_tecnico
    BEFORE INSERT OR UPDATE ON especialidad_tecnico
    FOR EACH ROW EXECUTE FUNCTION fn_especialidad_tecnico();
CREATE TRIGGER
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
CREATE FUNCTION
CREATE TRIGGER trg_personal_rol_estable
    BEFORE UPDATE OF rol ON personal
    FOR EACH ROW EXECUTE FUNCTION fn_personal_rol_estable();
CREATE TRIGGER
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
CREATE FUNCTION
CREATE TRIGGER trg_orden_antes_insertar
    BEFORE INSERT ON orden_trabajo
    FOR EACH ROW EXECUTE FUNCTION fn_orden_antes_insertar();
CREATE TRIGGER
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
CREATE FUNCTION
CREATE TRIGGER trg_orden_despues_insertar
    AFTER INSERT ON orden_trabajo
    FOR EACH ROW EXECUTE FUNCTION fn_orden_despues_insertar();
CREATE TRIGGER
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
CREATE FUNCTION
CREATE TRIGGER trg_orden_antes_actualizar
    BEFORE UPDATE ON orden_trabajo
    FOR EACH ROW EXECUTE FUNCTION fn_orden_antes_actualizar();
CREATE TRIGGER
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
CREATE FUNCTION
CREATE TRIGGER trg_orden_sin_borrado
    BEFORE DELETE ON orden_trabajo
    FOR EACH ROW EXECUTE FUNCTION fn_orden_sin_borrado();
CREATE TRIGGER
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
CREATE FUNCTION
CREATE CONSTRAINT TRIGGER trg_orden_coherencia
    AFTER INSERT OR UPDATE ON orden_trabajo
    DEFERRABLE INITIALLY DEFERRED
    FOR EACH ROW EXECUTE FUNCTION fn_verificar_coherencia_orden();
CREATE TRIGGER
CREATE CONSTRAINT TRIGGER trg_historial_orden_coherencia
    AFTER INSERT ON historial_orden
    DEFERRABLE INITIALLY DEFERRED
    FOR EACH ROW EXECUTE FUNCTION fn_verificar_coherencia_orden();
CREATE TRIGGER
CREATE CONSTRAINT TRIGGER trg_hfp_coherencia
    AFTER INSERT ON historial_fecha_prometida
    DEFERRABLE INITIALLY DEFERRED
    FOR EACH ROW EXECUTE FUNCTION fn_verificar_coherencia_orden();
CREATE TRIGGER
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
CREATE FUNCTION
CREATE TRIGGER trg_facultad_validar
    BEFORE INSERT OR UPDATE OR DELETE ON facultad_orden
    FOR EACH ROW EXECUTE FUNCTION fn_facultad_validar();
CREATE TRIGGER
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
CREATE FUNCTION
CREATE TRIGGER trg_objeto_dano_validar
    BEFORE INSERT OR UPDATE OR DELETE ON objeto_dano
    FOR EACH ROW EXECUTE FUNCTION fn_objeto_dano_validar();
CREATE TRIGGER
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
CREATE FUNCTION
CREATE TRIGGER trg_historial_orden_antes
    BEFORE INSERT ON historial_orden
    FOR EACH ROW EXECUTE FUNCTION fn_historial_orden_antes();
CREATE TRIGGER
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
CREATE FUNCTION
CREATE TRIGGER trg_historial_orden_despues
    AFTER INSERT ON historial_orden
    FOR EACH ROW EXECUTE FUNCTION fn_historial_orden_despues();
CREATE TRIGGER
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
CREATE FUNCTION
CREATE TRIGGER trg_hfp_antes
    BEFORE INSERT ON historial_fecha_prometida
    FOR EACH ROW EXECUTE FUNCTION fn_hfp_antes();
CREATE TRIGGER
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
CREATE FUNCTION
CREATE TRIGGER trg_hfp_despues
    AFTER INSERT ON historial_fecha_prometida
    FOR EACH ROW EXECUTE FUNCTION fn_hfp_despues();
CREATE TRIGGER
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
CREATE FUNCTION
CREATE TRIGGER trg_hallazgo_validar
    BEFORE INSERT OR UPDATE ON hallazgo
    FOR EACH ROW EXECUTE FUNCTION fn_hallazgo_validar();
CREATE TRIGGER
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
CREATE FUNCTION
CREATE TRIGGER trg_propuesta_validar
    BEFORE INSERT OR UPDATE OR DELETE ON propuesta
    FOR EACH ROW EXECUTE FUNCTION fn_propuesta_validar();
CREATE TRIGGER
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
CREATE FUNCTION
CREATE TRIGGER trg_linea_validar
    BEFORE INSERT OR UPDATE OR DELETE ON linea_propuesta
    FOR EACH ROW EXECUTE FUNCTION fn_linea_validar();
CREATE TRIGGER
CREATE TRIGGER trg_repuesto_propuesto_validar
    BEFORE INSERT OR UPDATE OR DELETE ON repuesto_propuesto
    FOR EACH ROW EXECUTE FUNCTION fn_linea_validar();
CREATE TRIGGER
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
CREATE FUNCTION
CREATE TRIGGER trg_autorizacion_validar
    BEFORE INSERT ON autorizacion_labor
    FOR EACH ROW EXECUTE FUNCTION fn_autorizacion_validar();
CREATE TRIGGER
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
CREATE FUNCTION
CREATE TRIGGER trg_labor_validar
    BEFORE INSERT OR UPDATE OR DELETE ON labor
    FOR EACH ROW EXECUTE FUNCTION fn_labor_validar();
CREATE TRIGGER
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
CREATE FUNCTION
CREATE TRIGGER trg_labor_estado_inicial
    AFTER INSERT ON labor
    FOR EACH ROW EXECUTE FUNCTION fn_labor_estado_inicial();
CREATE TRIGGER
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
CREATE FUNCTION
CREATE TRIGGER trg_historial_labor_antes
    BEFORE INSERT ON historial_labor
    FOR EACH ROW EXECUTE FUNCTION fn_historial_labor_antes();
CREATE TRIGGER
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
CREATE FUNCTION
CREATE TRIGGER trg_historial_labor_despues
    AFTER INSERT ON historial_labor
    FOR EACH ROW EXECUTE FUNCTION fn_historial_labor_despues();
CREATE TRIGGER
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
CREATE FUNCTION
CREATE TRIGGER trg_emergencia_validar
    BEFORE INSERT ON excepcion_emergencia
    FOR EACH ROW EXECUTE FUNCTION fn_emergencia_validar();
CREATE TRIGGER
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
CREATE FUNCTION
CREATE TRIGGER trg_dependencia_sin_ciclos
    BEFORE INSERT ON labor_dependencia
    FOR EACH ROW EXECUTE FUNCTION fn_dependencia_sin_ciclos();
CREATE TRIGGER
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
CREATE FUNCTION
CREATE TRIGGER trg_participacion_validar
    BEFORE INSERT OR UPDATE OR DELETE ON participacion_tecnica
    FOR EACH ROW EXECUTE FUNCTION fn_participacion_validar();
CREATE TRIGGER
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
CREATE FUNCTION
CREATE TRIGGER trg_prueba_validar
    BEFORE INSERT ON prueba
    FOR EACH ROW EXECUTE FUNCTION fn_prueba_validar();
CREATE TRIGGER
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
CREATE FUNCTION
CREATE TRIGGER trg_consumo_validar
    BEFORE INSERT ON consumo_repuesto
    FOR EACH ROW EXECUTE FUNCTION fn_consumo_validar();
CREATE TRIGGER
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
CREATE FUNCTION
CREATE CONSTRAINT TRIGGER trg_consumo_con_movimiento
    AFTER INSERT ON consumo_repuesto
    DEFERRABLE INITIALLY DEFERRED
    FOR EACH ROW EXECUTE FUNCTION fn_consumo_con_movimiento();
CREATE TRIGGER
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
CREATE FUNCTION
CREATE TRIGGER trg_movimiento_validar
    BEFORE INSERT ON movimiento_inventario
    FOR EACH ROW EXECUTE FUNCTION fn_movimiento_validar();
CREATE TRIGGER
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
CREATE FUNCTION
CREATE TRIGGER trg_pieza_validar
    BEFORE INSERT ON pieza_retirada
    FOR EACH ROW EXECUTE FUNCTION fn_pieza_validar();
CREATE TRIGGER
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
CREATE FUNCTION
CREATE TRIGGER trg_entrega_validar
    BEFORE INSERT ON entrega
    FOR EACH ROW EXECUTE FUNCTION fn_entrega_validar();
CREATE TRIGGER
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
CREATE FUNCTION
CREATE TRIGGER trg_garantia_validar
    BEFORE INSERT ON garantia
    FOR EACH ROW EXECUTE FUNCTION fn_garantia_validar();
CREATE TRIGGER
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
    -- El kilometraje del reclamo es el kilometraje con que ingresa la orden nueva.
    IF NEW.km_reclamo IS NULL THEN
        NEW.km_reclamo := v_orden_nueva.kilometraje_ingreso;
    ELSIF NEW.km_reclamo <> v_orden_nueva.kilometraje_ingreso THEN
        PERFORM fn_error(format('G02-INT: el kilometraje del reclamo (%s) debe ser el de ingreso de la orden nueva %s (%s)',
                                NEW.km_reclamo, NEW.orden_nueva_id, v_orden_nueva.kilometraje_ingreso));
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
        PERFORM fn_error(format('G02-INT: garantía %s vencida (vence lo primero): dentro del plazo de días: %s; dentro del límite de km: %s; '
                                'el reclamo solo puede registrarse como Rechazada con justificación (RN-22)',
                                NEW.garantia_id,
                                CASE WHEN v_dentro_dias THEN 'sí' ELSE 'no' END,
                                CASE WHEN v_dentro_km THEN 'sí' ELSE 'no' END));
    END IF;
    RETURN NEW;
END;
$$;
CREATE FUNCTION
CREATE TRIGGER trg_reclamo_validar
    BEFORE INSERT OR UPDATE OR DELETE ON reclamo_garantia
    FOR EACH ROW EXECUTE FUNCTION fn_reclamo_validar();
CREATE TRIGGER
\echo '== 03 rutinas P01 (propuestas y decisiones)'
== 03 rutinas P01 (propuestas y decisiones)
\ir 03_rutinas_p01.sql
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
SET
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
CREATE VIEW
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
CREATE VIEW
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
CREATE VIEW
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
CREATE VIEW
COMMENT ON VIEW v_situacion_labor IS 'G02-P01: decisión aplicable por labor (última decisión sobre la línea de la versión vigente).';
COMMENT
COMMENT ON VIEW v_autorizacion_ejecutable IS 'G02-P01: autorizacion_id que habilita la ejecución de cada labor (solo situación Aceptada).';
COMMENT
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
CREATE FUNCTION
COMMENT ON FUNCTION fn_publicar_propuesta(bigint, bigint, jsonb, bigint, text, timestamptz) IS
    'G02-P01: publica una versión completa (labores, líneas, repuestos estimados, dependencias) de forma atómica.';
COMMENT
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
CREATE FUNCTION
COMMENT ON FUNCTION fn_registrar_decision(bigint, bigint, bigint, text, text, bigint, timestamptz, text, text) IS
    'G02-P01: registra una decisión (Aceptada/Rechazada/Pendiente) por labor y versión, con facultad vigente; solo inserción.';
COMMENT
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
CREATE FUNCTION
\echo '== 04 rutinas P02 (ejecución)'
== 04 rutinas P02 (ejecución)
\ir 04_rutinas_p02.sql
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
SET
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
CREATE FUNCTION
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
CREATE FUNCTION
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
CREATE FUNCTION
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
CREATE FUNCTION
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
CREATE FUNCTION
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
CREATE FUNCTION
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
CREATE FUNCTION
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
CREATE FUNCTION
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
CREATE FUNCTION
\echo '== 05 rutinas P03 (estados y fecha prometida)'
== 05 rutinas P03 (estados y fecha prometida)
\ir 05_rutinas_p03.sql
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
SET
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
CREATE FUNCTION
COMMENT ON FUNCTION fn_cambiar_estado_orden(bigint, text, bigint, text, timestamptz, text) IS
    'G02-P03: única vía para cambiar el estado de una orden; historial y valor actual en la misma transacción.';
COMMENT
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
CREATE FUNCTION
COMMENT ON FUNCTION fn_cambiar_fecha_prometida(bigint, timestamptz, timestamptz, text, text, bigint, timestamptz) IS
    'G02-P03: única vía para reprogramar la fecha prometida; conserva la promesa anterior, motivo, medio y responsable.';
COMMENT
\echo '== 06 vistas y consultas Q01-Q04'
== 06 vistas y consultas Q01-Q04
\ir 06_vistas_consultas.sql
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
SET
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
CREATE VIEW
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
CREATE VIEW
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
CREATE VIEW
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
CREATE VIEW
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
CREATE VIEW
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
CREATE VIEW
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
CREATE VIEW
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
CREATE VIEW
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
CREATE VIEW
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
CREATE VIEW
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
CREATE VIEW
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
CREATE VIEW
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
CREATE VIEW
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
CREATE VIEW
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
CREATE VIEW
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
CREATE VIEW
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
CREATE VIEW
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
CREATE VIEW
\echo '== 07 datos iniciales de preparación'
== 07 datos iniciales de preparación
\ir 07_datos_iniciales.sql
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
--   * 9014 (Jorge) para decisiones incompletas (P01-L).
--   * El vehículo KLM789 queda sin visita para demostrar el alta del Lab03.
--   * Técnicos con especialidades distintas, un técnico inactivo y personal
--     que existe pero no es técnico.
-- IDs fijos y conocidos; luego se ajustan las secuencias IDENTITY.
-- =====================================================================
SET search_path = taller, public;
SET
SET TIME ZONE 'America/Costa_Rica';
SET
BEGIN;
BEGIN
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
INSERT 0 8
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
INSERT 0 10
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
 ('1G1ZD5ST0JF000001', 'HIJ456', 'Chevrolet',  'Malibu',  2018, 'Gasolina'),
 ('2HGFC2F59KH000001', 'KLM789', 'Honda',      'Civic',   2019, 'Gasolina');
INSERT 0 13
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
 (12, '1G1ZD5ST0JF000001', 106, '2019-01-01', NULL),
 (13, '2HGFC2F59KH000001', 108, '2019-06-01', NULL);
INSERT 0 13
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
INSERT 0 7
INSERT INTO especialidad_tecnico (especialidad_id, tecnico_id, especialidad, fecha_inicio, fecha_fin) VALUES
 (1, 202, 'Frenos',           '2020-01-01', NULL),
 (2, 202, 'Mecánica general', '2021-03-01', NULL),
 (3, 203, 'Electricidad',     '2019-07-01', NULL),
 (4, 204, 'Mecánica general', '2022-02-01', NULL),
 (5, 204, 'Frenos',           '2023-01-01', '2025-12-31'),  -- vencida
 (6, 207, 'Frenos',           '2018-01-01', NULL);
INSERT 0 6
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
INSERT 0 8
INSERT INTO proveedor (proveedor_id, nombre, identificacion) VALUES
 (1, 'Repuestos La Uruca S.A.',     'FICT-J-3101-001'),
 (2, 'Distribuidora Frenos CR',     'FICT-J-3101-002'),
 (3, 'ElectroAuto del Este',        NULL);
INSERT 0 3
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
INSERT 0 9
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
INSERT 0 7
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
        'Revisión híbrida (concurrencia P03)', NULL, '2026-11-12 17:00'),
 (9014, '1G1ZD5ST0JF000001', 106, 106, 106, 206, '2026-11-08 10:00', 54000, '1/2',
        'Servicio de mantenimiento mayor', NULL, '2026-11-11 16:00');
INSERT 0 11
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
 (9013, 'Recibida', '2026-11-08 09:00', 201),
 (9014, 'Recibida', '2026-11-08 10:00', 206);
INSERT 0 11
-- Facultades adicionales verificadas en la recepción (D2):
--   Jorge Quesada (106) también puede RETIRAR el vehículo de Mensajería (9004).
INSERT INTO facultad_orden (orden_id, cliente_id, tipo_facultad, fuente, otorgada_por_cliente_id,
                            medio_verificacion, vigente_desde, registrada_por_id) VALUES
 (9004, 106, 'Retirar', 'Representación legal', 105,
  'Personería jurídica vigente presentada en la recepción', '2026-11-05 07:30', 201);
INSERT 0 1
-- Objetos dejados y daños visibles (RN-06). 9006 tiene un daño SIN confirmar.
INSERT INTO objeto_dano (detalle_id, orden_id, tipo_detalle, descripcion, confirmado_cliente) VALUES
 (1, 9001, 'Daño',   'Rayón leve en puerta del conductor', true),
 (2, 9005, 'Objeto', 'Silla de bebé en el asiento trasero', true),
 (3, 9005, 'Daño',   'Rayón en parachoques trasero', true),
 (4, 9006, 'Daño',   'Abolladura en puerta trasera derecha', false);
INSERT 0 4
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
        'Limpiar ventilador'),
 (4115, 9014, 204, '2026-11-08 11:00', 'Aceite degradado', 'Kilometraje de servicio', 'Media',
        'Cambiar aceite y filtro'),
 (4116, 9014, 204, '2026-11-08 11:15', 'Filtro de aire saturado', 'Intervalo de mantenimiento', 'Baja',
        'Cambiar filtro de aire'),
 (4117, 9014, 202, '2026-11-08 11:30', 'Escobillas cristalizadas', 'Exposición al sol', 'Baja',
        'Cambiar escobillas');
INSERT 0 17
-- Reserva de repuesto para la orden 9003 (preparación: el taller apartó un
-- juego de pastillas al diagnosticar). El consumo en P02 la liberará.
INSERT INTO movimiento_inventario (repuesto_id, orden_id, tipo_movimiento, cantidad, fecha_hora, registrado_por_id, motivo) VALUES
 ('FR-001', 9003, 'Reserva', 1, '2026-11-04 09:05', 205, 'Apartado tras el diagnóstico');
INSERT 0 1
COMMIT;
COMMIT
-- ---------------------------------------------------------------------
-- 7. Ajuste de secuencias IDENTITY tras cargar IDs fijos
--    (las filas nuevas creadas por los procesos empiezan en rangos legibles)
-- ---------------------------------------------------------------------
SELECT setval(pg_get_serial_sequence('taller.cliente', 'cliente_id'), 900);
 setval 
--------
    900
(1 row)

SELECT setval(pg_get_serial_sequence('taller.contacto_cliente', 'contacto_id'), 100);
 setval 
--------
    100
(1 row)

SELECT setval(pg_get_serial_sequence('taller.propiedad_vehiculo', 'propiedad_id'), 100);
 setval 
--------
    100
(1 row)

SELECT setval(pg_get_serial_sequence('taller.personal', 'personal_id'), 900);
 setval 
--------
    900
(1 row)

SELECT setval(pg_get_serial_sequence('taller.especialidad_tecnico', 'especialidad_id'), 100);
 setval 
--------
    100
(1 row)

SELECT setval(pg_get_serial_sequence('taller.proveedor', 'proveedor_id'), 100);
 setval 
--------
    100
(1 row)

SELECT setval(pg_get_serial_sequence('taller.proveedor_repuesto', 'proveedor_repuesto_id'), 100);
 setval 
--------
    100
(1 row)

SELECT setval(pg_get_serial_sequence('taller.orden_trabajo', 'orden_id'), 9900);
 setval 
--------
   9900
(1 row)

SELECT setval(pg_get_serial_sequence('taller.objeto_dano', 'detalle_id'), 100);
 setval 
--------
    100
(1 row)

SELECT setval(pg_get_serial_sequence('taller.hallazgo', 'hallazgo_id'), 4900);
 setval 
--------
   4900
(1 row)

SELECT setval(pg_get_serial_sequence('taller.facultad_orden', 'facultad_id'), 700);
 setval 
--------
    700
(1 row)

SELECT setval(pg_get_serial_sequence('taller.movimiento_inventario', 'movimiento_id'), 800);
 setval 
--------
    800
(1 row)

SELECT setval(pg_get_serial_sequence('taller.propuesta', 'propuesta_id'), 300);
 setval 
--------
    300
(1 row)

SELECT setval(pg_get_serial_sequence('taller.labor', 'labor_id'), 500);
 setval 
--------
    500
(1 row)

SELECT setval(pg_get_serial_sequence('taller.autorizacion_labor', 'autorizacion_id'), 600);
 setval 
--------
    600
(1 row)

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
              tabla              | count 
---------------------------------+-------
 cliente                         |     8
 contacto_cliente                |    10
 vehiculo                        |    13
 propiedad_vehiculo              |    13
 personal                        |     7
 especialidad_tecnico            |     6
 repuesto                        |     8
 proveedor                       |     3
 proveedor_repuesto              |     9
 orden_trabajo                   |    11
 facultad_orden                  |    25
 historial_orden                 |    11
 historial_fecha_prometida       |     8
 objeto_dano                     |     4
 hallazgo                        |    17
 movimiento_inventario           |     8
 propuesta (debe ser 0)          |     0
 labor (debe ser 0)              |     0
 autorizacion_labor (debe ser 0) |     0
(19 rows)

\echo '== 08 rutinas reutilizadas del Lab03'
== 08 rutinas reutilizadas del Lab03
\ir 08_rutinas_lab03.sql
-- =====================================================================
-- IC-4301 Bases de Datos I · Proyecto (2.ª entrega) · Grupo 02
-- Caso: Taller Ruta 27
-- Archivo: 08_rutinas_lab03.sql
-- REUTILIZACIÓN SIN MODIFICACIÓN del Lab03 (lab03/grupo-02/sql/04_rutinas.sql,
-- rama lab03-grupo02-entrega del repositorio del curso).
--
-- Única adaptación: estas dos líneas de encabezado (search_path y zona
-- horaria), necesarias porque el modelo vive ahora en el esquema "taller".
-- El cuerpo de fn_total_ordenes_cliente, fn_prioridad_orden,
-- sp_registrar_orden y la demostración de la tabla temporal es idéntico
-- al del Lab03 y funciona contra el modelo nuevo porque:
--   * orden_trabajo.orden_id es IDENTITY BY DEFAULT (admite el id recibido);
--   * placa_ingreso lo completa trg_orden_antes_insertar;
--   * historial_orden conserva la columna "estado" y su trigger asigna la
--     secuencia 1 al estado inicial 'Recibida';
--   * las facultades de la visita las crea trg_orden_despues_insertar.
-- Ver Control_de_Cambios.md, sección "Reutilización sin modificación".
-- =====================================================================
SET search_path = taller, public;
SET
SET TIME ZONE 'America/Costa_Rica';
SET
-- LABORATORIO 3 - TALLER RUTA 27
-- ==========================================
-- FUNCION 1: TOTAL DE ORDENES POR CLIENTE
-- ==========================================
-- Cuenta las visitas facturadas a un cliente.
CREATE OR REPLACE FUNCTION fn_total_ordenes_cliente(
    p_cliente_id INTEGER
)
RETURNS INTEGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_total INTEGER;
BEGIN
    SELECT COUNT(*)::INTEGER INTO v_total
    FROM orden_trabajo
    WHERE cliente_factura_id = p_cliente_id;

    RETURN v_total;
END;
$$;
CREATE FUNCTION
-- ==========================================
-- FUNCION 2: PRIORIDAD DE UNA ORDEN
-- ==========================================
-- Determina la prioridad segun el hallazgo
-- mas urgente registrado en una orden.
CREATE OR REPLACE FUNCTION fn_prioridad_orden(
    p_orden_id INTEGER
)
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
    v_nivel INTEGER;
BEGIN
    SELECT MAX(
        CASE urgencia
            WHEN 'Baja' THEN 1
            WHEN 'Media' THEN 2
            WHEN 'Alta' THEN 3
            WHEN 'Crítica' THEN 4
        END
    )
    INTO v_nivel
    FROM hallazgo
    WHERE orden_id = p_orden_id;

    IF v_nivel IS NULL THEN
        RETURN 'Sin hallazgos';

    ELSIF v_nivel = 4 THEN
        RETURN 'Atención inmediata';

    ELSIF v_nivel = 3 THEN
        RETURN 'Revisión prioritaria';

    ELSIF v_nivel = 2 THEN
        RETURN 'Atención programada';

    ELSE
        RETURN 'Baja prioridad';
    END IF;
END;
$$;
CREATE FUNCTION
-- ==========================================
-- PROCEDIMIENTO: REGISTRAR ORDEN
-- ==========================================
-- Registra una orden de trabajo y su estado
-- inicial, despues de validar condiciones.
CREATE OR REPLACE PROCEDURE sp_registrar_orden(
    p_orden_id INTEGER,
    p_vin VARCHAR(17),
    p_cliente_factura_id INTEGER,
    p_entregado_por_cliente_id INTEGER,
    p_autorizador_cliente_id INTEGER,
    p_receptor_id INTEGER,
    p_kilometraje_ingreso INTEGER,
    p_nivel_combustible VARCHAR(10),
    p_motivo_informado TEXT
)
LANGUAGE plpgsql
AS $$
BEGIN
    -- Validar identificador.
    IF p_orden_id IS NULL OR p_orden_id <= 0 THEN
        RAISE EXCEPTION
            'El identificador de orden debe ser positivo';
    END IF;

    -- Validar kilometraje.
    IF p_kilometraje_ingreso IS NULL
       OR p_kilometraje_ingreso < 0 THEN
        RAISE EXCEPTION
            'El kilometraje de ingreso no puede ser negativo ni nulo';
    END IF;

    -- Comprobar que el vehiculo exista.
    IF NOT EXISTS (
        SELECT 1
        FROM vehiculo
        WHERE vin = p_vin
    ) THEN
        RAISE EXCEPTION
            'No existe el vehículo con VIN %', p_vin;
    END IF;

    -- Evitar registrar una orden duplicada.
    IF EXISTS (
        SELECT 1
        FROM orden_trabajo
        WHERE orden_id = p_orden_id
    ) THEN
        RAISE EXCEPTION
            'Ya existe la orden %', p_orden_id;
    END IF;

    -- Crear la orden de trabajo.
    INSERT INTO orden_trabajo (
        orden_id,
        vin,
        cliente_factura_id,
        entregado_por_cliente_id,
        autorizador_cliente_id,
        receptor_id,
        kilometraje_ingreso,
        nivel_combustible,
        motivo_informado
    )
    VALUES (
        p_orden_id,
        p_vin,
        p_cliente_factura_id,
        p_entregado_por_cliente_id,
        p_autorizador_cliente_id,
        p_receptor_id,
        p_kilometraje_ingreso,
        p_nivel_combustible,
        p_motivo_informado
    );

    -- Registrar el estado inicial.
    INSERT INTO historial_orden (
        orden_id,
        estado,
        personal_id
    )
    VALUES (
        p_orden_id,
        'Recibida',
        p_receptor_id
    );
END;
$$;
CREATE PROCEDURE
-- ==========================================
-- COMPROBACION DE FUNCIONES
-- ==========================================
-- El cliente 101 tiene dos ordenes.
SELECT fn_total_ordenes_cliente(101)
    AS visitas_cliente_101;
 visitas_cliente_101 
---------------------
                   2
(1 row)

-- La orden 9003 tiene un hallazgo critico.
SELECT fn_prioridad_orden(9003)
    AS prioridad_orden_9003;
 prioridad_orden_9003 
----------------------
 Revisión prioritaria
(1 row)

-- La orden 9005 no tiene hallazgos.
SELECT fn_prioridad_orden(9005)
    AS prioridad_orden_sin_hallazgos;
 prioridad_orden_sin_hallazgos 
-------------------------------
 Revisión prioritaria
(1 row)

-- ==========================================
-- TECNICA ADICIONAL: TABLA TEMPORAL
-- ==========================================
-- Crea un resumen de las prioridades
-- de las ordenes durante esta sesion.
DROP TABLE IF EXISTS pg_temp.tmp_resumen_prioridades;
psql:sql/08_rutinas_lab03.sql:210: NOTICE:  schema "pg_temp" does not exist, skipping
DROP TABLE
CREATE TEMP TABLE tmp_resumen_prioridades AS
SELECT
    o.orden_id,
    v.placa,
    fn_prioridad_orden(o.orden_id) AS prioridad
FROM orden_trabajo o
JOIN vehiculo v
    ON v.vin = o.vin;
SELECT 11
-- Mostrar los resultados.
SELECT *
FROM tmp_resumen_prioridades
ORDER BY orden_id;
 orden_id | placa  |      prioridad       
----------+--------+----------------------
     9001 | ABC123 | Atención programada
     9002 | GHI789 | Baja prioridad
     9003 | DEF456 | Revisión prioritaria
     9004 | JKL012 | Atención inmediata
     9005 | MNO345 | Revisión prioritaria
     9006 | PQR678 | Sin hallazgos
     9007 | STU901 | Baja prioridad
     9011 | YZA567 | Atención programada
     9012 | BCD890 | Revisión prioritaria
     9013 | EFG123 | Atención programada
     9014 | HIJ456 | Atención programada
(11 rows)

-- ALTERNATIVA SIN TABLA TEMPORAL:
-- Esta consulta directa es mas sencilla
-- cuando el resumen solo se utiliza una vez.
-- SELECT
--     o.orden_id,
--     v.placa,
--     fn_prioridad_orden(o.orden_id) AS prioridad
-- FROM orden_trabajo o
-- JOIN vehiculo v
--     ON v.vin = o.vin;
\echo '== Verificación: objetos creados en el esquema taller'
== Verificación: objetos creados en el esquema taller
SELECT 'tablas' AS objeto, count(*) FROM information_schema.tables WHERE table_schema = 'taller' AND table_type = 'BASE TABLE'
UNION ALL SELECT 'vistas', count(*) FROM information_schema.views WHERE table_schema = 'taller'
UNION ALL SELECT 'funciones y procedimientos', count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace WHERE n.nspname = 'taller'
UNION ALL SELECT 'triggers', count(*) FROM pg_trigger t JOIN pg_class c ON c.oid = t.tgrelid JOIN pg_namespace n ON n.oid = c.relnamespace WHERE n.nspname = 'taller' AND NOT t.tgisinternal
UNION ALL SELECT 'restricciones con nombre', count(*) FROM pg_constraint k JOIN pg_namespace n ON n.oid = k.connamespace WHERE n.nspname = 'taller';
           objeto           | count 
----------------------------+-------
 tablas                     |    32
 vistas                     |    22
 funciones y procedimientos |    58
 triggers                   |    52
 restricciones con nombre   |   237
(5 rows)

SELECT version();
                                               version                                                
------------------------------------------------------------------------------------------------------
 PostgreSQL 17.10 on x86_64-pc-linux-gnu, compiled by gcc (Ubuntu 7.5.0-3ubuntu1~18.04) 7.5.0, 64-bit
(1 row)

\echo '== run_all.sql terminó sin errores'
== run_all.sql terminó sin errores
```
