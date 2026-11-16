# Diccionario de datos — Taller Ruta 27 (Proyecto 2, Grupo 02)

> **Generado desde el catálogo de PostgreSQL 17** (`information_schema`, `pg_constraint`, `pg_trigger` y los `COMMENT` de `sql/01_esquema.sql`) sobre la base construida con `sql/run_all.sql`. Por eso coincide exactamente con lo implementado. Las reglas que no son declarativas se indican en la columna *Triggers* y se explican en [`matriz_regla_mecanismo_prueba.md`](matriz_regla_mecanismo_prueba.md).

Convenciones: `PK` clave primaria · `FK→` clave foránea (las compuestas indican pertenencia a la misma orden/labor) · `UQ` única · `ck_` CHECK · `ex_` EXCLUDE (sin traslapes) · `IDENTITY` identificador generado.

## Dominios

| Dominio | Tipo base | Regla | Descripción |
|---|---|---|---|
| `d_estado_labor` | `character varying(20)` | `CHECK (((VALUE)::text = ANY ((ARRAY['Pendiente'::character varying, 'En proceso'::character varying, 'Completada'::character varying, 'Suspendida'::character varying, 'Anulada'::character varying])::text[])))` | Estados de una labor (P1 §diccionario). |
| `d_estado_orden` | `character varying(30)` | `CHECK (((VALUE)::text = ANY ((ARRAY['Recibida'::character varying, 'En diagnóstico'::character varying, 'Pendiente autorización'::character varying, 'Autorizada'::character varying, 'En reparación'::character varying, 'Lista entrega'::character varying, 'Entregada'::character varying, 'Cancelada'::character varying])::text[])))` | Estados de la orden (P1 §diccionario). Secuencia NO lineal: ver transicion_estado_orden. |
| `d_medio_comunicacion` | `character varying(20)` | `CHECK (((VALUE)::text = ANY ((ARRAY['Teléfono'::character varying, 'Correo'::character varying, 'Mensaje'::character varying, 'Presencial'::character varying, 'Otro'::character varying])::text[])))` | Medio por el que se comunica una decisión o una promesa (P1 §diccionario). |

## 1. `cliente`

Persona u organización que entrega, paga, aprueba o retira (RN-04, SD-02 del P1).

| Atributo | Tipo PostgreSQL | Nulo | Clave | Default / generación | Descripción |
|---|---|:---:|---|---|---|
| `cliente_id` | `integer` | no | PK | IDENTITY BY DEFAULT |  |
| `identificacion` | `character varying(30)` | no | UQ |  |  |
| `nombre_razon_social` | `character varying(150)` | no |  |  |  |
| `tipo_cliente` | `character varying(20)` | no |  |  |  |

**Restricciones**

| Nombre | Tipo | Definición |
|---|---|---|
| `ck_cliente_identificacion` | CHECK | `CHECK ((btrim((identificacion)::text) <> ''::text))` |
| `ck_cliente_nombre` | CHECK | `CHECK ((btrim((nombre_razon_social)::text) <> ''::text))` |
| `ck_cliente_tipo` | CHECK | `CHECK (((tipo_cliente)::text = ANY ((ARRAY['Persona'::character varying, 'Organización'::character varying])::text[])))` |
| `pk_cliente` | PRIMARY KEY | `PRIMARY KEY (cliente_id)` |
| `trg_cliente_contacto_avisos` | TRIGGER | `TRIGGER DEFERRABLE INITIALLY DEFERRED` |
| `uq_cliente_identificacion` | UNIQUE | `UNIQUE (identificacion)` |

**Triggers:** `trg_cliente_contacto_avisos`


## 2. `contacto_cliente`

Medios de contacto; al menos uno apto para avisos por cliente, verificado al COMMIT (RN-03).

| Atributo | Tipo PostgreSQL | Nulo | Clave | Default / generación | Descripción |
|---|---|:---:|---|---|---|
| `contacto_id` | `bigint` | no | PK | IDENTITY BY DEFAULT |  |
| `cliente_id` | `integer` | no | FK→taller.cliente, UQ |  |  |
| `tipo_contacto` | `character varying(10)` | no | UQ |  |  |
| `valor_contacto` | `character varying(120)` | no | UQ |  |  |
| `recibe_avisos` | `boolean` | no |  | `false` |  |

**Restricciones**

| Nombre | Tipo | Definición |
|---|---|---|
| `ck_contacto_formato` | CHECK | `CHECK (((((tipo_contacto)::text = 'Correo'::text) AND ((valor_contacto)::text ~* '^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$'::text)) OR (((tipo_contacto)::text = 'Teléfono'::text) AND ((valor_contacto)::text ~ '^\+?[0-9]{8,15}$'::text))))` |
| `ck_contacto_tipo` | CHECK | `CHECK (((tipo_contacto)::text = ANY ((ARRAY['Teléfono'::character varying, 'Correo'::character varying])::text[])))` |
| `fk_contacto_cliente_cliente` | FOREIGN KEY | `FOREIGN KEY (cliente_id) REFERENCES taller.cliente(cliente_id)` |
| `pk_contacto_cliente` | PRIMARY KEY | `PRIMARY KEY (contacto_id)` |
| `trg_contacto_avisos` | TRIGGER | `TRIGGER DEFERRABLE INITIALLY DEFERRED` |
| `uq_contacto_cliente_valor` | UNIQUE | `UNIQUE (cliente_id, tipo_contacto, valor_contacto)` |

**Triggers:** `trg_contacto_avisos`


## 3. `vehiculo`

Vehículo identificado por su VIN estable; la placa puede cambiar (RN-02).

| Atributo | Tipo PostgreSQL | Nulo | Clave | Default / generación | Descripción |
|---|---|:---:|---|---|---|
| `vin` | `character varying(17)` | no | PK |  |  |
| `placa` | `character varying(15)` | no |  |  |  |
| `marca` | `character varying(60)` | no |  |  |  |
| `modelo` | `character varying(60)` | no |  |  |  |
| `anio` | `integer` | no |  |  |  |
| `tipo_combustible` | `character varying(20)` | no |  |  |  |

**Restricciones**

| Nombre | Tipo | Definición |
|---|---|---|
| `ck_vehiculo_anio_minimo` | CHECK | `CHECK ((anio >= 1886))` |
| `ck_vehiculo_combustible` | CHECK | `CHECK (((tipo_combustible)::text = ANY ((ARRAY['Gasolina'::character varying, 'Diésel'::character varying, 'Híbrido'::character varying, 'Eléctrico'::character varying, 'Otro'::character varying])::text[])))` |
| `ck_vehiculo_marca` | CHECK | `CHECK ((btrim((marca)::text) <> ''::text))` |
| `ck_vehiculo_modelo` | CHECK | `CHECK ((btrim((modelo)::text) <> ''::text))` |
| `ck_vehiculo_placa` | CHECK | `CHECK ((btrim((placa)::text) <> ''::text))` |
| `ck_vehiculo_vin` | CHECK | `CHECK (((vin)::text ~ '^[A-HJ-NPR-Z0-9]{17}$'::text))` |
| `pk_vehiculo` | PRIMARY KEY | `PRIMARY KEY (vin)` |

**Triggers:** `trg_vehiculo_anio`, `trg_vehiculo_vin_estable`


## 4. `propiedad_vehiculo`

Propietarios del vehículo con vigencia sin traslapes (D12). No reescribe visitas.

| Atributo | Tipo PostgreSQL | Nulo | Clave | Default / generación | Descripción |
|---|---|:---:|---|---|---|
| `propiedad_id` | `bigint` | no | PK | IDENTITY BY DEFAULT |  |
| `vin` | `character varying(17)` | no | FK→taller.vehiculo |  |  |
| `cliente_id` | `integer` | no | FK→taller.cliente |  |  |
| `desde` | `date` | no |  |  |  |
| `hasta` | `date` | sí |  |  |  |

**Restricciones**

| Nombre | Tipo | Definición |
|---|---|---|
| `ck_propiedad_vigencia` | CHECK | `CHECK (((hasta IS NULL) OR (hasta > desde)))` |
| `fk_propiedad_cliente` | FOREIGN KEY | `FOREIGN KEY (cliente_id) REFERENCES taller.cliente(cliente_id)` |
| `fk_propiedad_vehiculo` | FOREIGN KEY | `FOREIGN KEY (vin) REFERENCES taller.vehiculo(vin)` |
| `pk_propiedad_vehiculo` | PRIMARY KEY | `PRIMARY KEY (propiedad_id)` |
| `ex_propiedad_sin_traslape` | EXCLUDE | `EXCLUDE USING gist (vin WITH =, daterange(desde, hasta, '[)'::text) WITH &&)` |

## 5. `personal`

Personal del taller con rol y estado activo.

| Atributo | Tipo PostgreSQL | Nulo | Clave | Default / generación | Descripción |
|---|---|:---:|---|---|---|
| `personal_id` | `integer` | no | PK | IDENTITY BY DEFAULT |  |
| `nombre` | `character varying(120)` | no |  |  |  |
| `rol` | `character varying(20)` | no |  |  |  |
| `activo` | `boolean` | no |  | `true` |  |

**Restricciones**

| Nombre | Tipo | Definición |
|---|---|---|
| `ck_personal_nombre` | CHECK | `CHECK ((btrim((nombre)::text) <> ''::text))` |
| `ck_personal_rol` | CHECK | `CHECK (((rol)::text = ANY ((ARRAY['Recepción'::character varying, 'Técnico'::character varying, 'Otro'::character varying])::text[])))` |
| `pk_personal` | PRIMARY KEY | `PRIMARY KEY (personal_id)` |

**Triggers:** `trg_personal_rol_estable`


## 6. `especialidad_tecnico`

Especialidades de un técnico con vigencia sin traslapes (RN-14).

| Atributo | Tipo PostgreSQL | Nulo | Clave | Default / generación | Descripción |
|---|---|:---:|---|---|---|
| `especialidad_id` | `bigint` | no | PK, UQ | IDENTITY BY DEFAULT |  |
| `tecnico_id` | `integer` | no | FK→taller.personal, UQ |  |  |
| `especialidad` | `character varying(30)` | no |  |  |  |
| `fecha_inicio` | `date` | no |  |  |  |
| `fecha_fin` | `date` | sí |  |  |  |

**Restricciones**

| Nombre | Tipo | Definición |
|---|---|---|
| `ck_especialidad_valor` | CHECK | `CHECK (((especialidad)::text = ANY ((ARRAY['Electricidad'::character varying, 'Frenos'::character varying, 'Mecánica general'::character varying, 'Otra'::character varying])::text[])))` |
| `ck_especialidad_vigencia` | CHECK | `CHECK (((fecha_fin IS NULL) OR (fecha_fin >= fecha_inicio)))` |
| `fk_especialidad_tecnico` | FOREIGN KEY | `FOREIGN KEY (tecnico_id) REFERENCES taller.personal(personal_id)` |
| `pk_especialidad_tecnico` | PRIMARY KEY | `PRIMARY KEY (especialidad_id)` |
| `uq_especialidad_tecnico_ctx` | UNIQUE | `UNIQUE (especialidad_id, tecnico_id)` |
| `ex_especialidad_sin_traslape` | EXCLUDE | `EXCLUDE USING gist (tecnico_id WITH =, especialidad WITH =, daterange(fecha_inicio, fecha_fin, '[]'::text) WITH &&)` |

**Triggers:** `trg_especialidad_tecnico`


## 7. `repuesto`

Catálogo de repuestos con código interno (RN-17).

| Atributo | Tipo PostgreSQL | Nulo | Clave | Default / generación | Descripción |
|---|---|:---:|---|---|---|
| `repuesto_id` | `character varying(20)` | no | PK |  |  |
| `descripcion` | `character varying(150)` | no |  |  |  |
| `marca` | `character varying(60)` | sí |  |  |  |
| `unidad_manejo` | `character varying(10)` | no |  |  |  |

**Restricciones**

| Nombre | Tipo | Definición |
|---|---|---|
| `ck_repuesto_codigo` | CHECK | `CHECK (((repuesto_id)::text ~ '^[A-Z]{2,4}-[0-9]{3,6}$'::text))` |
| `ck_repuesto_descripcion` | CHECK | `CHECK ((btrim((descripcion)::text) <> ''::text))` |
| `ck_repuesto_unidad` | CHECK | `CHECK (((unidad_manejo)::text = ANY ((ARRAY['Unidad'::character varying, 'Juego'::character varying, 'Litro'::character varying, 'Metro'::character varying, 'Otro'::character varying])::text[])))` |
| `pk_repuesto` | PRIMARY KEY | `PRIMARY KEY (repuesto_id)` |

## 8. `proveedor`

Proveedores de repuestos (datos mínimos; sin flujo de compras).

| Atributo | Tipo PostgreSQL | Nulo | Clave | Default / generación | Descripción |
|---|---|:---:|---|---|---|
| `proveedor_id` | `bigint` | no | PK | IDENTITY BY DEFAULT |  |
| `nombre` | `character varying(150)` | no | UQ |  |  |
| `identificacion` | `character varying(30)` | sí | UQ |  |  |

**Restricciones**

| Nombre | Tipo | Definición |
|---|---|---|
| `ck_proveedor_nombre` | CHECK | `CHECK ((btrim((nombre)::text) <> ''::text))` |
| `pk_proveedor` | PRIMARY KEY | `PRIMARY KEY (proveedor_id)` |
| `uq_proveedor_identificacion` | UNIQUE | `UNIQUE (identificacion)` |
| `uq_proveedor_nombre` | UNIQUE | `UNIQUE (nombre)` |

## 9. `proveedor_repuesto`

Código y precio de referencia de un repuesto en un proveedor (RN-17).

| Atributo | Tipo PostgreSQL | Nulo | Clave | Default / generación | Descripción |
|---|---|:---:|---|---|---|
| `proveedor_repuesto_id` | `bigint` | no | PK | IDENTITY BY DEFAULT |  |
| `proveedor_id` | `bigint` | no | FK→taller.proveedor, UQ |  |  |
| `repuesto_id` | `character varying(20)` | no | FK→taller.repuesto, UQ |  |  |
| `codigo_proveedor` | `character varying(40)` | no | UQ |  |  |
| `precio_referencia` | `numeric(12,2)` | sí |  |  |  |

**Restricciones**

| Nombre | Tipo | Definición |
|---|---|---|
| `ck_prov_rep_codigo` | CHECK | `CHECK ((btrim((codigo_proveedor)::text) <> ''::text))` |
| `ck_prov_rep_precio` | CHECK | `CHECK (((precio_referencia IS NULL) OR (precio_referencia >= (0)::numeric)))` |
| `fk_prov_rep_proveedor` | FOREIGN KEY | `FOREIGN KEY (proveedor_id) REFERENCES taller.proveedor(proveedor_id)` |
| `fk_prov_rep_repuesto` | FOREIGN KEY | `FOREIGN KEY (repuesto_id) REFERENCES taller.repuesto(repuesto_id)` |
| `pk_proveedor_repuesto` | PRIMARY KEY | `PRIMARY KEY (proveedor_repuesto_id)` |
| `uq_prov_rep_codigo` | UNIQUE | `UNIQUE (proveedor_id, codigo_proveedor)` |
| `uq_prov_rep_repuesto` | UNIQUE | `UNIQUE (proveedor_id, repuesto_id)` |

## 10. `orden_trabajo`

Una visita de un vehículo (RN-01). estado_actual/fecha_prometida_actual solo cambian vía historial (D4).

| Atributo | Tipo PostgreSQL | Nulo | Clave | Default / generación | Descripción |
|---|---|:---:|---|---|---|
| `orden_id` | `integer` | no | PK, UQ | IDENTITY BY DEFAULT |  |
| `vin` | `character varying(17)` | no | FK→taller.vehiculo, UQ |  |  |
| `placa_ingreso` | `character varying(15)` | no |  |  | Instantánea de la placa al ingresar; no cambia si luego cambia la placa del vehículo (RN-02). |
| `cliente_factura_id` | `integer` | no | FK→taller.cliente |  |  |
| `entregado_por_cliente_id` | `integer` | no | FK→taller.cliente |  |  |
| `autorizador_cliente_id` | `integer` | no | FK→taller.cliente |  | Se conserva por compatibilidad con el alta del Lab03; la facultad real está en facultad_orden (D2). |
| `receptor_id` | `integer` | no | FK→taller.personal |  |  |
| `fecha_hora_recepcion` | `timestamp with time zone` | no |  | `now()` |  |
| `kilometraje_ingreso` | `integer` | no |  |  |  |
| `nivel_combustible` | `character varying(10)` | no |  |  |  |
| `motivo_informado` | `text` | no |  |  |  |
| `observaciones_visibles` | `text` | sí |  |  |  |
| `fecha_prometida_actual` | `timestamp with time zone` | sí |  |  |  |
| `estado_actual` | `taller.d_estado_orden` | no |  | `'Recibida'::character varying` |  |

**Restricciones**

| Nombre | Tipo | Definición |
|---|---|---|
| `ck_orden_combustible` | CHECK | `CHECK (((nivel_combustible)::text = ANY ((ARRAY['Vacío'::character varying, '1/4'::character varying, '1/2'::character varying, '3/4'::character varying, 'Lleno'::character varying])::text[])))` |
| `ck_orden_fecha_prometida` | CHECK | `CHECK (((fecha_prometida_actual IS NULL) OR (fecha_prometida_actual > fecha_hora_recepcion)))` |
| `ck_orden_id_positivo` | CHECK | `CHECK ((orden_id > 0))` |
| `ck_orden_km_ingreso` | CHECK | `CHECK ((kilometraje_ingreso >= 0))` |
| `ck_orden_motivo` | CHECK | `CHECK ((btrim(motivo_informado) <> ''::text))` |
| `ck_orden_placa_ingreso` | CHECK | `CHECK ((btrim((placa_ingreso)::text) <> ''::text))` |
| `fk_orden_cliente_autoriza` | FOREIGN KEY | `FOREIGN KEY (autorizador_cliente_id) REFERENCES taller.cliente(cliente_id)` |
| `fk_orden_cliente_entrega` | FOREIGN KEY | `FOREIGN KEY (entregado_por_cliente_id) REFERENCES taller.cliente(cliente_id)` |
| `fk_orden_cliente_factura` | FOREIGN KEY | `FOREIGN KEY (cliente_factura_id) REFERENCES taller.cliente(cliente_id)` |
| `fk_orden_receptor` | FOREIGN KEY | `FOREIGN KEY (receptor_id) REFERENCES taller.personal(personal_id)` |
| `fk_orden_vehiculo` | FOREIGN KEY | `FOREIGN KEY (vin) REFERENCES taller.vehiculo(vin)` |
| `pk_orden_trabajo` | PRIMARY KEY | `PRIMARY KEY (orden_id)` |
| `trg_orden_coherencia` | TRIGGER | `TRIGGER DEFERRABLE INITIALLY DEFERRED` |
| `uq_orden_trabajo_vin` | UNIQUE | `UNIQUE (orden_id, vin)` |
| `uq_orden_abierta_por_vehiculo` | ÍNDICE | `btree (vin) WHERE ((estado_actual)::text <> ALL ((ARRAY['Entregada'::character varying, 'Cancelada'::character varying])::text[]))` |

**Triggers:** `trg_orden_antes_actualizar`, `trg_orden_antes_insertar`, `trg_orden_coherencia`, `trg_orden_despues_insertar`, `trg_orden_sin_borrado`


## 11. `facultad_orden`

Facultades por visita (Aprobar/Retirar) con fuente, verificación y vigencia (D2).

| Atributo | Tipo PostgreSQL | Nulo | Clave | Default / generación | Descripción |
|---|---|:---:|---|---|---|
| `facultad_id` | `bigint` | no | PK, UQ | IDENTITY BY DEFAULT |  |
| `orden_id` | `integer` | no | FK→taller.orden_trabajo, UQ |  |  |
| `cliente_id` | `integer` | no | FK→taller.cliente |  |  |
| `tipo_facultad` | `character varying(10)` | no |  |  |  |
| `fuente` | `character varying(25)` | no |  |  |  |
| `otorgada_por_cliente_id` | `integer` | sí | FK→taller.cliente |  |  |
| `medio_verificacion` | `text` | no |  |  |  |
| `vigente_desde` | `timestamp with time zone` | no |  |  |  |
| `vigente_hasta` | `timestamp with time zone` | sí |  |  |  |
| `registrada_por_id` | `integer` | no | FK→taller.personal |  |  |

**Restricciones**

| Nombre | Tipo | Definición |
|---|---|---|
| `ck_facultad_fuente` | CHECK | `CHECK (((fuente)::text = ANY ((ARRAY['Titular'::character varying, 'Designación'::character varying, 'Representación legal'::character varying])::text[])))` |
| `ck_facultad_otorgante` | CHECK | `CHECK (((((fuente)::text = 'Titular'::text) AND (otorgada_por_cliente_id IS NULL)) OR (((fuente)::text <> 'Titular'::text) AND (otorgada_por_cliente_id IS NOT NULL) AND (otorgada_por_cliente_id <> cliente_id))))` |
| `ck_facultad_tipo` | CHECK | `CHECK (((tipo_facultad)::text = ANY ((ARRAY['Aprobar'::character varying, 'Retirar'::character varying])::text[])))` |
| `ck_facultad_verificacion` | CHECK | `CHECK ((btrim(medio_verificacion) <> ''::text))` |
| `ck_facultad_vigencia` | CHECK | `CHECK (((vigente_hasta IS NULL) OR (vigente_hasta > vigente_desde)))` |
| `fk_facultad_cliente` | FOREIGN KEY | `FOREIGN KEY (cliente_id) REFERENCES taller.cliente(cliente_id)` |
| `fk_facultad_orden` | FOREIGN KEY | `FOREIGN KEY (orden_id) REFERENCES taller.orden_trabajo(orden_id)` |
| `fk_facultad_otorgante` | FOREIGN KEY | `FOREIGN KEY (otorgada_por_cliente_id) REFERENCES taller.cliente(cliente_id)` |
| `fk_facultad_registrador` | FOREIGN KEY | `FOREIGN KEY (registrada_por_id) REFERENCES taller.personal(personal_id)` |
| `pk_facultad_orden` | PRIMARY KEY | `PRIMARY KEY (facultad_id)` |
| `uq_facultad_orden_ctx` | UNIQUE | `UNIQUE (facultad_id, orden_id)` |
| `ex_facultad_sin_traslape` | EXCLUDE | `EXCLUDE USING gist (orden_id WITH =, cliente_id WITH =, tipo_facultad WITH =, tstzrange(vigente_desde, vigente_hasta, '[)'::text) WITH &&)` |
| `idx_facultad_busqueda` | ÍNDICE | `btree (orden_id, cliente_id, tipo_facultad)` |

**Triggers:** `trg_facultad_validar`


## 12. `objeto_dano`

Objetos dejados y daños visibles confirmados por el cliente (RN-06).

| Atributo | Tipo PostgreSQL | Nulo | Clave | Default / generación | Descripción |
|---|---|:---:|---|---|---|
| `detalle_id` | `bigint` | no | PK | IDENTITY BY DEFAULT |  |
| `orden_id` | `integer` | no | FK→taller.orden_trabajo |  |  |
| `tipo_detalle` | `character varying(10)` | no |  |  |  |
| `descripcion` | `text` | no |  |  |  |
| `confirmado_cliente` | `boolean` | no |  | `false` |  |

**Restricciones**

| Nombre | Tipo | Definición |
|---|---|---|
| `ck_objeto_dano_descripcion` | CHECK | `CHECK ((btrim(descripcion) <> ''::text))` |
| `ck_objeto_dano_tipo` | CHECK | `CHECK (((tipo_detalle)::text = ANY ((ARRAY['Objeto'::character varying, 'Daño'::character varying])::text[])))` |
| `fk_objeto_dano_orden` | FOREIGN KEY | `FOREIGN KEY (orden_id) REFERENCES taller.orden_trabajo(orden_id)` |
| `pk_objeto_dano` | PRIMARY KEY | `PRIMARY KEY (detalle_id)` |

**Triggers:** `trg_objeto_dano_validar`


## 13. `historial_orden`

Cambios de estado de la orden con responsable, momento, motivo y secuencia (RN-08). Solo inserción.

| Atributo | Tipo PostgreSQL | Nulo | Clave | Default / generación | Descripción |
|---|---|:---:|---|---|---|
| `historial_id` | `bigint` | no | PK | IDENTITY ALWAYS |  |
| `orden_id` | `integer` | no | FK→taller.orden_trabajo, UQ |  |  |
| `secuencia` | `integer` | no | UQ |  |  |
| `estado_anterior` | `taller.d_estado_orden` | sí |  |  |  |
| `estado` | `taller.d_estado_orden` | no |  |  |  |
| `fecha_hora` | `timestamp with time zone` | no |  | `CURRENT_TIMESTAMP` |  |
| `personal_id` | `integer` | no | FK→taller.personal |  |  |
| `motivo` | `text` | sí |  |  |  |
| `registrado_en` | `timestamp with time zone` | no |  | `clock_timestamp()` |  |

**Restricciones**

| Nombre | Tipo | Definición |
|---|---|---|
| `ck_historial_orden_inicio` | CHECK | `CHECK ((((secuencia = 1) AND (estado_anterior IS NULL) AND ((estado)::text = 'Recibida'::text)) OR ((secuencia > 1) AND (estado_anterior IS NOT NULL) AND ((estado_anterior)::text <> (estado)::text))))` |
| `ck_historial_orden_motivo` | CHECK | `CHECK (((motivo IS NULL) OR (btrim(motivo) <> ''::text)))` |
| `ck_historial_orden_secuencia` | CHECK | `CHECK ((secuencia >= 1))` |
| `fk_historial_orden_orden` | FOREIGN KEY | `FOREIGN KEY (orden_id) REFERENCES taller.orden_trabajo(orden_id)` |
| `fk_historial_orden_personal` | FOREIGN KEY | `FOREIGN KEY (personal_id) REFERENCES taller.personal(personal_id)` |
| `pk_historial_orden` | PRIMARY KEY | `PRIMARY KEY (historial_id)` |
| `trg_historial_orden_coherencia` | TRIGGER | `TRIGGER DEFERRABLE INITIALLY DEFERRED` |
| `uq_historial_orden_secuencia` | UNIQUE | `UNIQUE (orden_id, secuencia)` |
| `idx_historial_orden_ultimo` | ÍNDICE | `btree (orden_id, fecha_hora DESC, historial_id DESC)` |

**Triggers:** `trg_historial_orden_antes`, `trg_historial_orden_coherencia`, `trg_historial_orden_despues`, `trg_historial_orden_inmutable`


## 14. `historial_fecha_prometida`

Promesa original y reprogramaciones con comunicación, medio, motivo y responsable (RN-07). Solo inserción.

| Atributo | Tipo PostgreSQL | Nulo | Clave | Default / generación | Descripción |
|---|---|:---:|---|---|---|
| `cambio_fecha_id` | `bigint` | no | PK | IDENTITY ALWAYS |  |
| `orden_id` | `integer` | no | FK→taller.orden_trabajo, UQ |  |  |
| `secuencia` | `integer` | no | UQ |  |  |
| `fecha_anterior` | `timestamp with time zone` | sí |  |  |  |
| `fecha_nueva` | `timestamp with time zone` | no |  |  |  |
| `fecha_hora_comunicacion` | `timestamp with time zone` | no |  |  |  |
| `medio_comunicacion` | `taller.d_medio_comunicacion` | no |  |  |  |
| `motivo` | `text` | sí |  |  |  |
| `personal_id` | `integer` | no | FK→taller.personal |  |  |
| `registrado_en` | `timestamp with time zone` | no |  | `clock_timestamp()` |  |

**Restricciones**

| Nombre | Tipo | Definición |
|---|---|---|
| `ck_hfp_cambio_real` | CHECK | `CHECK (((fecha_anterior IS NULL) OR (fecha_nueva <> fecha_anterior)))` |
| `ck_hfp_motivo` | CHECK | `CHECK (((fecha_anterior IS NULL) OR (btrim(COALESCE(motivo, ''::text)) <> ''::text)))` |
| `ck_hfp_original` | CHECK | `CHECK (((secuencia = 1) = (fecha_anterior IS NULL)))` |
| `ck_hfp_promesa_futura` | CHECK | `CHECK ((fecha_nueva > fecha_hora_comunicacion))` |
| `ck_hfp_secuencia` | CHECK | `CHECK ((secuencia >= 1))` |
| `fk_hfp_orden` | FOREIGN KEY | `FOREIGN KEY (orden_id) REFERENCES taller.orden_trabajo(orden_id)` |
| `fk_hfp_personal` | FOREIGN KEY | `FOREIGN KEY (personal_id) REFERENCES taller.personal(personal_id)` |
| `pk_historial_fecha_prometida` | PRIMARY KEY | `PRIMARY KEY (cambio_fecha_id)` |
| `trg_hfp_coherencia` | TRIGGER | `TRIGGER DEFERRABLE INITIALLY DEFERRED` |
| `uq_hfp_secuencia` | UNIQUE | `UNIQUE (orden_id, secuencia)` |

**Triggers:** `trg_hfp_antes`, `trg_hfp_coherencia`, `trg_hfp_despues`, `trg_hfp_inmutable`


## 15. `transicion_estado_orden`

Catálogo de transiciones de estado permitidas (no lineal; retrocesos con motivo).

| Atributo | Tipo PostgreSQL | Nulo | Clave | Default / generación | Descripción |
|---|---|:---:|---|---|---|
| `estado_desde` | `taller.d_estado_orden` | no | PK |  |  |
| `estado_hacia` | `taller.d_estado_orden` | no | PK |  |  |
| `requiere_motivo` | `boolean` | no |  |  |  |
| `descripcion` | `text` | no |  |  |  |

**Restricciones**

| Nombre | Tipo | Definición |
|---|---|---|
| `ck_transicion_distinta` | CHECK | `CHECK (((estado_desde)::text <> (estado_hacia)::text))` |
| `ck_transicion_terminal` | CHECK | `CHECK (((estado_desde)::text <> ALL ((ARRAY['Entregada'::character varying, 'Cancelada'::character varying])::text[])))` |
| `pk_transicion_estado_orden` | PRIMARY KEY | `PRIMARY KEY (estado_desde, estado_hacia)` |

**Triggers:** `trg_transicion_inmutable`


## 16. `hallazgo`

Hallazgos del diagnóstico con autor técnico y momento (RN-09, D1).

| Atributo | Tipo PostgreSQL | Nulo | Clave | Default / generación | Descripción |
|---|---|:---:|---|---|---|
| `hallazgo_id` | `integer` | no | PK, UQ | IDENTITY BY DEFAULT |  |
| `orden_id` | `integer` | no | FK→taller.orden_trabajo, UQ |  |  |
| `diagnosticado_por_id` | `integer` | no | FK→taller.personal |  |  |
| `fecha_hora` | `timestamp with time zone` | no |  | `now()` |  |
| `sintoma_comprobado` | `text` | no |  |  |  |
| `posible_causa` | `text` | sí |  |  |  |
| `urgencia` | `character varying(12)` | no |  |  |  |
| `recomendacion` | `text` | no |  |  |  |

**Restricciones**

| Nombre | Tipo | Definición |
|---|---|---|
| `ck_hallazgo_recomendacion` | CHECK | `CHECK ((btrim(recomendacion) <> ''::text))` |
| `ck_hallazgo_sintoma` | CHECK | `CHECK ((btrim(sintoma_comprobado) <> ''::text))` |
| `ck_hallazgo_urgencia` | CHECK | `CHECK (((urgencia)::text = ANY ((ARRAY['Baja'::character varying, 'Media'::character varying, 'Alta'::character varying, 'Crítica'::character varying])::text[])))` |
| `fk_hallazgo_autor` | FOREIGN KEY | `FOREIGN KEY (diagnosticado_por_id) REFERENCES taller.personal(personal_id)` |
| `fk_hallazgo_orden` | FOREIGN KEY | `FOREIGN KEY (orden_id) REFERENCES taller.orden_trabajo(orden_id)` |
| `pk_hallazgo` | PRIMARY KEY | `PRIMARY KEY (hallazgo_id)` |
| `uq_hallazgo_orden` | UNIQUE | `UNIQUE (hallazgo_id, orden_id)` |

**Triggers:** `trg_hallazgo_validar`


## 17. `propuesta`

Versiones de la propuesta de una orden; una versión presentada es inmutable (RN-10).

| Atributo | Tipo PostgreSQL | Nulo | Clave | Default / generación | Descripción |
|---|---|:---:|---|---|---|
| `propuesta_id` | `bigint` | no | PK, UQ | IDENTITY BY DEFAULT |  |
| `orden_id` | `integer` | no | FK→taller.propuesta, FK→taller.orden_trabajo, UQ |  |  |
| `version` | `integer` | no | UQ |  |  |
| `estado` | `character varying(12)` | no |  | `'Borrador'::character varying` |  |
| `propuesta_base_id` | `bigint` | sí | FK→taller.propuesta |  |  |
| `presentada_por_id` | `integer` | no | FK→taller.personal |  |  |
| `fecha_hora_presentacion` | `timestamp with time zone` | sí |  |  |  |
| `observacion` | `text` | sí |  |  |  |
| `creada_en` | `timestamp with time zone` | no |  | `clock_timestamp()` |  |

**Restricciones**

| Nombre | Tipo | Definición |
|---|---|---|
| `ck_propuesta_base_distinta` | CHECK | `CHECK (((propuesta_base_id IS NULL) OR (propuesta_base_id <> propuesta_id)))` |
| `ck_propuesta_estado` | CHECK | `CHECK (((estado)::text = ANY ((ARRAY['Borrador'::character varying, 'Presentada'::character varying])::text[])))` |
| `ck_propuesta_presentacion` | CHECK | `CHECK ((((estado)::text = 'Presentada'::text) = (fecha_hora_presentacion IS NOT NULL)))` |
| `ck_propuesta_version` | CHECK | `CHECK ((version >= 1))` |
| `fk_propuesta_base` | FOREIGN KEY | `FOREIGN KEY (propuesta_base_id, orden_id) REFERENCES taller.propuesta(propuesta_id, orden_id)` |
| `fk_propuesta_orden` | FOREIGN KEY | `FOREIGN KEY (orden_id) REFERENCES taller.orden_trabajo(orden_id)` |
| `fk_propuesta_personal` | FOREIGN KEY | `FOREIGN KEY (presentada_por_id) REFERENCES taller.personal(personal_id)` |
| `pk_propuesta` | PRIMARY KEY | `PRIMARY KEY (propuesta_id)` |
| `uq_propuesta_orden` | UNIQUE | `UNIQUE (propuesta_id, orden_id)` |
| `uq_propuesta_version` | UNIQUE | `UNIQUE (orden_id, version)` |

**Triggers:** `trg_propuesta_validar`


## 18. `labor`

Trabajo estable de la orden, separado de su precio en cada versión (D6); retrabajos ligados (RN-15).

| Atributo | Tipo PostgreSQL | Nulo | Clave | Default / generación | Descripción |
|---|---|:---:|---|---|---|
| `labor_id` | `bigint` | no | PK, UQ | IDENTITY BY DEFAULT |  |
| `orden_id` | `integer` | no | FK→taller.hallazgo, FK→taller.orden_trabajo, FK→taller.labor, UQ |  |  |
| `hallazgo_id` | `integer` | sí | FK→taller.hallazgo |  |  |
| `descripcion` | `text` | no |  |  |  |
| `es_emergencia` | `boolean` | no |  | `false` |  |
| `labor_revisada_id` | `bigint` | sí | FK→taller.prueba, FK→taller.labor |  |  |
| `prueba_origen_id` | `bigint` | sí | FK→taller.prueba |  |  |
| `estado_labor` | `taller.d_estado_labor` | no |  | `'Pendiente'::character varying` |  |
| `creada_por_id` | `integer` | no | FK→taller.personal |  |  |
| `creada_en` | `timestamp with time zone` | no |  | `now()` |  |

**Restricciones**

| Nombre | Tipo | Definición |
|---|---|---|
| `ck_labor_descripcion` | CHECK | `CHECK ((btrim(descripcion) <> ''::text))` |
| `ck_labor_no_autorrevision` | CHECK | `CHECK (((labor_revisada_id IS NULL) OR (labor_revisada_id <> labor_id)))` |
| `ck_labor_prueba_origen` | CHECK | `CHECK (((prueba_origen_id IS NULL) OR (labor_revisada_id IS NOT NULL)))` |
| `fk_labor_creador` | FOREIGN KEY | `FOREIGN KEY (creada_por_id) REFERENCES taller.personal(personal_id)` |
| `fk_labor_hallazgo` | FOREIGN KEY | `FOREIGN KEY (hallazgo_id, orden_id) REFERENCES taller.hallazgo(hallazgo_id, orden_id)` |
| `fk_labor_orden` | FOREIGN KEY | `FOREIGN KEY (orden_id) REFERENCES taller.orden_trabajo(orden_id)` |
| `fk_labor_prueba_origen` | FOREIGN KEY | `FOREIGN KEY (prueba_origen_id, labor_revisada_id) REFERENCES taller.prueba(prueba_id, labor_id)` |
| `fk_labor_revisada` | FOREIGN KEY | `FOREIGN KEY (labor_revisada_id, orden_id) REFERENCES taller.labor(labor_id, orden_id)` |
| `pk_labor` | PRIMARY KEY | `PRIMARY KEY (labor_id)` |
| `uq_labor_orden` | UNIQUE | `UNIQUE (labor_id, orden_id)` |
| `idx_labor_orden` | ÍNDICE | `btree (orden_id)` |

**Triggers:** `trg_labor_estado_inicial`, `trg_labor_validar`


## 19. `linea_propuesta`

Componente de versión: la labor con su precio y alcance en una versión concreta (D6).

| Atributo | Tipo PostgreSQL | Nulo | Clave | Default / generación | Descripción |
|---|---|:---:|---|---|---|
| `propuesta_id` | `bigint` | no | FK→taller.propuesta, PK, UQ |  |  |
| `labor_id` | `bigint` | no | FK→taller.labor, PK, UQ |  |  |
| `orden_id` | `integer` | no | FK→taller.labor, FK→taller.propuesta, UQ |  |  |
| `precio_estimado` | `numeric(12,2)` | no |  |  |  |
| `alcance` | `text` | no |  |  |  |

**Restricciones**

| Nombre | Tipo | Definición |
|---|---|---|
| `ck_linea_alcance` | CHECK | `CHECK ((btrim(alcance) <> ''::text))` |
| `ck_linea_precio` | CHECK | `CHECK ((precio_estimado >= (0)::numeric))` |
| `fk_linea_labor` | FOREIGN KEY | `FOREIGN KEY (labor_id, orden_id) REFERENCES taller.labor(labor_id, orden_id)` |
| `fk_linea_propuesta` | FOREIGN KEY | `FOREIGN KEY (propuesta_id, orden_id) REFERENCES taller.propuesta(propuesta_id, orden_id)` |
| `pk_linea_propuesta` | PRIMARY KEY | `PRIMARY KEY (propuesta_id, labor_id)` |
| `uq_linea_propuesta_ctx` | UNIQUE | `UNIQUE (propuesta_id, labor_id, orden_id)` |

**Triggers:** `trg_linea_validar`


## 20. `repuesto_propuesto`

Repuestos estimados por línea de versión (lo estimado, RN-18).

| Atributo | Tipo PostgreSQL | Nulo | Clave | Default / generación | Descripción |
|---|---|:---:|---|---|---|
| `propuesta_id` | `bigint` | no | FK→taller.linea_propuesta, PK |  |  |
| `labor_id` | `bigint` | no | FK→taller.linea_propuesta, PK |  |  |
| `repuesto_id` | `character varying(20)` | no | FK→taller.repuesto, PK |  |  |
| `cantidad_estimada` | `numeric(10,2)` | no |  |  |  |
| `precio_unitario_estimado` | `numeric(12,2)` | no |  |  |  |

**Restricciones**

| Nombre | Tipo | Definición |
|---|---|---|
| `ck_rep_prop_cantidad` | CHECK | `CHECK ((cantidad_estimada > (0)::numeric))` |
| `ck_rep_prop_precio` | CHECK | `CHECK ((precio_unitario_estimado >= (0)::numeric))` |
| `fk_rep_prop_linea` | FOREIGN KEY | `FOREIGN KEY (propuesta_id, labor_id) REFERENCES taller.linea_propuesta(propuesta_id, labor_id)` |
| `fk_rep_prop_repuesto` | FOREIGN KEY | `FOREIGN KEY (repuesto_id) REFERENCES taller.repuesto(repuesto_id)` |
| `pk_repuesto_propuesto` | PRIMARY KEY | `PRIMARY KEY (propuesta_id, labor_id, repuesto_id)` |

**Triggers:** `trg_repuesto_propuesto_validar`


## 21. `autorizacion_labor`

Solo inserción. La decisión aplicable es la última sobre la línea de la versión vigente (ver README §P01).

| Atributo | Tipo PostgreSQL | Nulo | Clave | Default / generación | Descripción |
|---|---|:---:|---|---|---|
| `autorizacion_id` | `bigint` | no | PK, UQ | IDENTITY BY DEFAULT |  |
| `propuesta_id` | `bigint` | no | FK→taller.linea_propuesta |  |  |
| `labor_id` | `bigint` | no | FK→taller.linea_propuesta, UQ |  |  |
| `orden_id` | `integer` | no | FK→taller.facultad_orden, FK→taller.linea_propuesta |  |  |
| `facultad_id` | `bigint` | no | FK→taller.facultad_orden |  |  |
| `cliente_id` | `integer` | no | FK→taller.cliente |  |  |
| `decision` | `character varying(10)` | no |  |  |  |
| `fecha_hora` | `timestamp with time zone` | no |  |  |  |
| `medio` | `taller.d_medio_comunicacion` | no |  |  |  |
| `observacion` | `text` | sí |  |  |  |
| `registrado_por_id` | `integer` | no | FK→taller.personal |  |  |
| `registrado_en` | `timestamp with time zone` | no |  | `clock_timestamp()` |  |

**Restricciones**

| Nombre | Tipo | Definición |
|---|---|---|
| `ck_autorizacion_decision` | CHECK | `CHECK (((decision)::text = ANY ((ARRAY['Aceptada'::character varying, 'Rechazada'::character varying, 'Pendiente'::character varying])::text[])))` |
| `fk_autorizacion_cliente` | FOREIGN KEY | `FOREIGN KEY (cliente_id) REFERENCES taller.cliente(cliente_id)` |
| `fk_autorizacion_facultad` | FOREIGN KEY | `FOREIGN KEY (facultad_id, orden_id) REFERENCES taller.facultad_orden(facultad_id, orden_id)` |
| `fk_autorizacion_linea` | FOREIGN KEY | `FOREIGN KEY (propuesta_id, labor_id, orden_id) REFERENCES taller.linea_propuesta(propuesta_id, labor_id, orden_id)` |
| `fk_autorizacion_registrador` | FOREIGN KEY | `FOREIGN KEY (registrado_por_id) REFERENCES taller.personal(personal_id)` |
| `pk_autorizacion_labor` | PRIMARY KEY | `PRIMARY KEY (autorizacion_id)` |
| `uq_autorizacion_labor_ctx` | UNIQUE | `UNIQUE (autorizacion_id, labor_id)` |
| `idx_autorizacion_linea` | ÍNDICE | `btree (propuesta_id, labor_id, fecha_hora DESC, autorizacion_id DESC)` |

**Triggers:** `trg_autorizacion_inmutable`, `trg_autorizacion_validar`


## 22. `excepcion_emergencia`

Excepción justificada que habilita solo su labor de emergencia (RN-12, D8).

| Atributo | Tipo PostgreSQL | Nulo | Clave | Default / generación | Descripción |
|---|---|:---:|---|---|---|
| `emergencia_id` | `bigint` | no | PK, UQ | IDENTITY BY DEFAULT |  |
| `labor_id` | `bigint` | no | FK→taller.labor, UQ |  |  |
| `orden_id` | `integer` | no | FK→taller.labor |  |  |
| `riesgo` | `text` | no |  |  |  |
| `justificacion` | `text` | no |  |  |  |
| `alcance_minimo` | `text` | no |  |  |  |
| `autorizada_por_id` | `integer` | no | FK→taller.personal |  |  |
| `fecha_hora` | `timestamp with time zone` | no |  |  |  |

**Restricciones**

| Nombre | Tipo | Definición |
|---|---|---|
| `ck_emergencia_alcance` | CHECK | `CHECK ((btrim(alcance_minimo) <> ''::text))` |
| `ck_emergencia_justificacion` | CHECK | `CHECK ((char_length(btrim(justificacion)) >= 20))` |
| `ck_emergencia_riesgo` | CHECK | `CHECK ((btrim(riesgo) <> ''::text))` |
| `fk_emergencia_labor` | FOREIGN KEY | `FOREIGN KEY (labor_id, orden_id) REFERENCES taller.labor(labor_id, orden_id)` |
| `fk_emergencia_personal` | FOREIGN KEY | `FOREIGN KEY (autorizada_por_id) REFERENCES taller.personal(personal_id)` |
| `pk_excepcion_emergencia` | PRIMARY KEY | `PRIMARY KEY (emergencia_id)` |
| `uq_emergencia_ctx` | UNIQUE | `UNIQUE (emergencia_id, labor_id)` |
| `uq_emergencia_labor` | UNIQUE | `UNIQUE (labor_id)` |

**Triggers:** `trg_emergencia_inmutable`, `trg_emergencia_validar`


## 23. `labor_dependencia`

Dependencias N:M entre labores de la misma orden, sin ciclos (RN-15, D7).

| Atributo | Tipo PostgreSQL | Nulo | Clave | Default / generación | Descripción |
|---|---|:---:|---|---|---|
| `labor_id` | `bigint` | no | FK→taller.labor, PK |  |  |
| `requiere_labor_id` | `bigint` | no | FK→taller.labor, PK |  |  |
| `orden_id` | `integer` | no | FK→taller.labor |  |  |

**Restricciones**

| Nombre | Tipo | Definición |
|---|---|---|
| `ck_dependencia_distinta` | CHECK | `CHECK ((labor_id <> requiere_labor_id))` |
| `fk_dependencia_labor` | FOREIGN KEY | `FOREIGN KEY (labor_id, orden_id) REFERENCES taller.labor(labor_id, orden_id)` |
| `fk_dependencia_requerida` | FOREIGN KEY | `FOREIGN KEY (requiere_labor_id, orden_id) REFERENCES taller.labor(labor_id, orden_id)` |
| `pk_labor_dependencia` | PRIMARY KEY | `PRIMARY KEY (labor_id, requiere_labor_id)` |

**Triggers:** `trg_dependencia_inmutable`, `trg_dependencia_sin_ciclos`


## 24. `historial_labor`

Estados de la labor con la autorización o emergencia habilitante (D9).

| Atributo | Tipo PostgreSQL | Nulo | Clave | Default / generación | Descripción |
|---|---|:---:|---|---|---|
| `historial_labor_id` | `bigint` | no | PK | IDENTITY ALWAYS |  |
| `labor_id` | `bigint` | no | FK→taller.autorizacion_labor, FK→taller.excepcion_emergencia, FK→taller.labor, UQ |  |  |
| `secuencia` | `integer` | no | UQ |  |  |
| `estado_anterior` | `taller.d_estado_labor` | sí |  |  |  |
| `estado_nuevo` | `taller.d_estado_labor` | no |  |  |  |
| `fecha_hora` | `timestamp with time zone` | no |  | `now()` |  |
| `personal_id` | `integer` | no | FK→taller.personal |  |  |
| `autorizacion_id` | `bigint` | sí | FK→taller.autorizacion_labor |  |  |
| `emergencia_id` | `bigint` | sí | FK→taller.excepcion_emergencia |  |  |
| `motivo` | `text` | sí |  |  |  |
| `registrado_en` | `timestamp with time zone` | no |  | `clock_timestamp()` |  |

**Restricciones**

| Nombre | Tipo | Definición |
|---|---|---|
| `ck_historial_labor_habilitante` | CHECK | `CHECK (((((estado_nuevo)::text = 'En proceso'::text) AND (num_nonnulls(autorizacion_id, emergencia_id) = 1)) OR (((estado_nuevo)::text <> 'En proceso'::text) AND (num_nonnulls(autorizacion_id, emergencia_id) = 0))))` |
| `ck_historial_labor_inicio` | CHECK | `CHECK ((((secuencia = 1) AND (estado_anterior IS NULL) AND ((estado_nuevo)::text = 'Pendiente'::text)) OR ((secuencia > 1) AND (estado_anterior IS NOT NULL) AND ((estado_anterior)::text <> (estado_nuevo)::text))))` |
| `ck_historial_labor_motivo` | CHECK | `CHECK (((motivo IS NULL) OR (btrim(motivo) <> ''::text)))` |
| `fk_historial_labor_autorizacion` | FOREIGN KEY | `FOREIGN KEY (autorizacion_id, labor_id) REFERENCES taller.autorizacion_labor(autorizacion_id, labor_id)` |
| `fk_historial_labor_emergencia` | FOREIGN KEY | `FOREIGN KEY (emergencia_id, labor_id) REFERENCES taller.excepcion_emergencia(emergencia_id, labor_id)` |
| `fk_historial_labor_labor` | FOREIGN KEY | `FOREIGN KEY (labor_id) REFERENCES taller.labor(labor_id)` |
| `fk_historial_labor_personal` | FOREIGN KEY | `FOREIGN KEY (personal_id) REFERENCES taller.personal(personal_id)` |
| `pk_historial_labor` | PRIMARY KEY | `PRIMARY KEY (historial_labor_id)` |
| `uq_historial_labor_secuencia` | UNIQUE | `UNIQUE (labor_id, secuencia)` |

**Triggers:** `trg_historial_labor_antes`, `trg_historial_labor_despues`, `trg_historial_labor_inmutable`


## 25. `participacion_tecnica`

Participación de un técnico en una labor con intervalo y minutos efectivos (RN-13).

| Atributo | Tipo PostgreSQL | Nulo | Clave | Default / generación | Descripción |
|---|---|:---:|---|---|---|
| `participacion_id` | `bigint` | no | PK | IDENTITY BY DEFAULT |  |
| `labor_id` | `bigint` | no | FK→taller.labor |  |  |
| `orden_id` | `integer` | no | FK→taller.labor |  |  |
| `tecnico_id` | `integer` | no | FK→taller.especialidad_tecnico, FK→taller.personal |  |  |
| `especialidad_id` | `bigint` | sí | FK→taller.especialidad_tecnico |  |  |
| `inicio` | `timestamp with time zone` | no |  |  |  |
| `fin` | `timestamp with time zone` | sí |  |  |  |
| `minutos_efectivos` | `integer` | sí |  |  | Antes minutos_dedicados (P1). Puede ser menor que la duración del intervalo (pausas), nunca mayor. |
| `descripcion_participacion` | `text` | no |  |  |  |

**Restricciones**

| Nombre | Tipo | Definición |
|---|---|---|
| `ck_participacion_cierre` | CHECK | `CHECK ((((fin IS NULL) AND (minutos_efectivos IS NULL)) OR ((fin IS NOT NULL) AND (minutos_efectivos IS NOT NULL) AND (minutos_efectivos > 0))))` |
| `ck_participacion_descripcion` | CHECK | `CHECK ((btrim(descripcion_participacion) <> ''::text))` |
| `ck_participacion_intervalo` | CHECK | `CHECK (((fin IS NULL) OR (fin > inicio)))` |
| `ck_participacion_minutos` | CHECK | `CHECK (((fin IS NULL) OR ((minutos_efectivos)::numeric <= floor((EXTRACT(epoch FROM (fin - inicio)) / (60)::numeric)))))` |
| `fk_participacion_especialidad` | FOREIGN KEY | `FOREIGN KEY (especialidad_id, tecnico_id) REFERENCES taller.especialidad_tecnico(especialidad_id, tecnico_id)` |
| `fk_participacion_labor` | FOREIGN KEY | `FOREIGN KEY (labor_id, orden_id) REFERENCES taller.labor(labor_id, orden_id)` |
| `fk_participacion_tecnico` | FOREIGN KEY | `FOREIGN KEY (tecnico_id) REFERENCES taller.personal(personal_id)` |
| `pk_participacion_tecnica` | PRIMARY KEY | `PRIMARY KEY (participacion_id)` |
| `ex_participacion_tecnico` | EXCLUDE | `EXCLUDE USING gist (tecnico_id WITH =, tstzrange(inicio, fin, '[)'::text) WITH &&)` |
| `idx_participacion_labor` | ÍNDICE | `btree (labor_id)` |

**Triggers:** `trg_participacion_validar`


## 26. `prueba`

Pruebas de una labor: qué, quién, cuándo y resultado categórico (RN-16, D10). Solo inserción.

| Atributo | Tipo PostgreSQL | Nulo | Clave | Default / generación | Descripción |
|---|---|:---:|---|---|---|
| `prueba_id` | `bigint` | no | PK, UQ | IDENTITY BY DEFAULT |  |
| `labor_id` | `bigint` | no | FK→taller.labor, UQ |  |  |
| `orden_id` | `integer` | no | FK→taller.labor |  |  |
| `personal_id` | `integer` | no | FK→taller.personal |  |  |
| `fecha_hora` | `timestamp with time zone` | no |  |  |  |
| `tipo_prueba` | `character varying(60)` | no |  |  |  |
| `resultado` | `character varying(20)` | no |  |  |  |
| `medicion_valor` | `numeric(12,3)` | sí |  |  |  |
| `unidad` | `character varying(20)` | sí |  |  |  |
| `descripcion_resultado` | `text` | no |  |  |  |

**Restricciones**

| Nombre | Tipo | Definición |
|---|---|---|
| `ck_prueba_descripcion` | CHECK | `CHECK ((btrim(descripcion_resultado) <> ''::text))` |
| `ck_prueba_medicion` | CHECK | `CHECK (((medicion_valor IS NULL) = (unidad IS NULL)))` |
| `ck_prueba_resultado` | CHECK | `CHECK (((resultado)::text = ANY ((ARRAY['Favorable'::character varying, 'Desfavorable'::character varying, 'No concluyente'::character varying])::text[])))` |
| `ck_prueba_tipo` | CHECK | `CHECK ((btrim((tipo_prueba)::text) <> ''::text))` |
| `ck_prueba_unidad` | CHECK | `CHECK (((unidad IS NULL) OR (btrim((unidad)::text) <> ''::text)))` |
| `fk_prueba_labor` | FOREIGN KEY | `FOREIGN KEY (labor_id, orden_id) REFERENCES taller.labor(labor_id, orden_id)` |
| `fk_prueba_personal` | FOREIGN KEY | `FOREIGN KEY (personal_id) REFERENCES taller.personal(personal_id)` |
| `pk_prueba` | PRIMARY KEY | `PRIMARY KEY (prueba_id)` |
| `uq_prueba_labor` | UNIQUE | `UNIQUE (prueba_id, labor_id)` |
| `idx_prueba_labor` | ÍNDICE | `btree (labor_id, fecha_hora DESC)` |

**Triggers:** `trg_prueba_inmutable`, `trg_prueba_validar`


## 27. `consumo_repuesto`

Repuestos realmente utilizados (≠ estimados, RN-18); siempre con su movimiento de inventario.

| Atributo | Tipo PostgreSQL | Nulo | Clave | Default / generación | Descripción |
|---|---|:---:|---|---|---|
| `consumo_id` | `bigint` | no | PK, UQ | IDENTITY BY DEFAULT |  |
| `labor_id` | `bigint` | no | FK→taller.labor |  |  |
| `orden_id` | `integer` | no | FK→taller.labor, UQ |  |  |
| `repuesto_id` | `character varying(20)` | no | FK→taller.repuesto, UQ |  |  |
| `cantidad_utilizada` | `numeric(10,2)` | no |  |  |  |
| `precio_unitario_cargado` | `numeric(12,2)` | no |  |  |  |
| `fecha_hora` | `timestamp with time zone` | no |  | `now()` |  |
| `registrado_por_id` | `integer` | no | FK→taller.personal |  |  |

**Restricciones**

| Nombre | Tipo | Definición |
|---|---|---|
| `ck_consumo_cantidad` | CHECK | `CHECK ((cantidad_utilizada > (0)::numeric))` |
| `ck_consumo_precio` | CHECK | `CHECK ((precio_unitario_cargado >= (0)::numeric))` |
| `fk_consumo_labor` | FOREIGN KEY | `FOREIGN KEY (labor_id, orden_id) REFERENCES taller.labor(labor_id, orden_id)` |
| `fk_consumo_registrador` | FOREIGN KEY | `FOREIGN KEY (registrado_por_id) REFERENCES taller.personal(personal_id)` |
| `fk_consumo_repuesto` | FOREIGN KEY | `FOREIGN KEY (repuesto_id) REFERENCES taller.repuesto(repuesto_id)` |
| `pk_consumo_repuesto` | PRIMARY KEY | `PRIMARY KEY (consumo_id)` |
| `trg_consumo_con_movimiento` | TRIGGER | `TRIGGER DEFERRABLE INITIALLY DEFERRED` |
| `uq_consumo_ctx` | UNIQUE | `UNIQUE (consumo_id, repuesto_id, orden_id)` |
| `idx_consumo_labor` | ÍNDICE | `btree (labor_id)` |

**Triggers:** `trg_consumo_con_movimiento`, `trg_consumo_inmutable`, `trg_consumo_validar`


## 28. `movimiento_inventario`

Físico = Entrada + Ajuste positivo - Ajuste negativo - Consumo; Disponible = Físico - (Reserva - Liberación). Nunca negativos.

| Atributo | Tipo PostgreSQL | Nulo | Clave | Default / generación | Descripción |
|---|---|:---:|---|---|---|
| `movimiento_id` | `bigint` | no | PK | IDENTITY BY DEFAULT |  |
| `repuesto_id` | `character varying(20)` | no | FK→taller.consumo_repuesto, FK→taller.repuesto |  |  |
| `orden_id` | `integer` | sí | FK→taller.consumo_repuesto, FK→taller.orden_trabajo |  |  |
| `tipo_movimiento` | `character varying(20)` | no |  |  |  |
| `cantidad` | `numeric(10,2)` | no |  |  |  |
| `fecha_hora` | `timestamp with time zone` | no |  | `now()` |  |
| `consumo_id` | `bigint` | sí | FK→taller.consumo_repuesto, UQ |  |  |
| `registrado_por_id` | `integer` | no | FK→taller.personal |  |  |
| `motivo` | `text` | sí |  |  |  |

**Restricciones**

| Nombre | Tipo | Definición |
|---|---|---|
| `ck_movimiento_ajuste_motivo` | CHECK | `CHECK ((((tipo_movimiento)::text !~~ 'Ajuste%'::text) OR (btrim(COALESCE(motivo, ''::text)) <> ''::text)))` |
| `ck_movimiento_cantidad` | CHECK | `CHECK ((cantidad > (0)::numeric))` |
| `ck_movimiento_consumo_origen` | CHECK | `CHECK ((((tipo_movimiento)::text = 'Consumo'::text) = (consumo_id IS NOT NULL)))` |
| `ck_movimiento_orden` | CHECK | `CHECK ((((tipo_movimiento)::text <> ALL ((ARRAY['Reserva'::character varying, 'Liberación'::character varying, 'Consumo'::character varying])::text[])) OR (orden_id IS NOT NULL)))` |
| `ck_movimiento_tipo` | CHECK | `CHECK (((tipo_movimiento)::text = ANY ((ARRAY['Entrada'::character varying, 'Reserva'::character varying, 'Liberación'::character varying, 'Consumo'::character varying, 'Ajuste positivo'::character varying, 'Ajuste negativo'::character varying])::text[])))` |
| `fk_movimiento_consumo` | FOREIGN KEY | `FOREIGN KEY (consumo_id, repuesto_id, orden_id) REFERENCES taller.consumo_repuesto(consumo_id, repuesto_id, orden_id)` |
| `fk_movimiento_orden` | FOREIGN KEY | `FOREIGN KEY (orden_id) REFERENCES taller.orden_trabajo(orden_id)` |
| `fk_movimiento_registrador` | FOREIGN KEY | `FOREIGN KEY (registrado_por_id) REFERENCES taller.personal(personal_id)` |
| `fk_movimiento_repuesto` | FOREIGN KEY | `FOREIGN KEY (repuesto_id) REFERENCES taller.repuesto(repuesto_id)` |
| `pk_movimiento_inventario` | PRIMARY KEY | `PRIMARY KEY (movimiento_id)` |
| `uq_movimiento_consumo` | UNIQUE | `UNIQUE (consumo_id)` |
| `idx_movimiento_repuesto` | ÍNDICE | `btree (repuesto_id, tipo_movimiento)` |

**Triggers:** `trg_movimiento_inmutable`, `trg_movimiento_validar`


## 29. `pieza_retirada`

Piezas sustituidas y su destino.

| Atributo | Tipo PostgreSQL | Nulo | Clave | Default / generación | Descripción |
|---|---|:---:|---|---|---|
| `pieza_retirada_id` | `bigint` | no | PK | IDENTITY BY DEFAULT |  |
| `labor_id` | `bigint` | no | FK→taller.labor |  |  |
| `orden_id` | `integer` | no | FK→taller.labor |  |  |
| `descripcion` | `text` | no |  |  |  |
| `destino` | `character varying(30)` | no |  |  |  |
| `fecha_hora` | `timestamp with time zone` | no |  | `now()` |  |
| `registrado_por_id` | `integer` | no | FK→taller.personal |  |  |

**Restricciones**

| Nombre | Tipo | Definición |
|---|---|---|
| `ck_pieza_descripcion` | CHECK | `CHECK ((btrim(descripcion) <> ''::text))` |
| `ck_pieza_destino` | CHECK | `CHECK (((destino)::text = ANY ((ARRAY['Entregada cliente'::character varying, 'Desechada autorizada'::character varying, 'Conservada temporalmente'::character varying])::text[])))` |
| `fk_pieza_labor` | FOREIGN KEY | `FOREIGN KEY (labor_id, orden_id) REFERENCES taller.labor(labor_id, orden_id)` |
| `fk_pieza_registrador` | FOREIGN KEY | `FOREIGN KEY (registrado_por_id) REFERENCES taller.personal(personal_id)` |
| `pk_pieza_retirada` | PRIMARY KEY | `PRIMARY KEY (pieza_retirada_id)` |

**Triggers:** `trg_pieza_inmutable`, `trg_pieza_validar`


## 30. `entrega`

Entrega del vehículo (máx. 1 por orden) a quien tiene facultad Retirar (RN-20).

| Atributo | Tipo PostgreSQL | Nulo | Clave | Default / generación | Descripción |
|---|---|:---:|---|---|---|
| `entrega_id` | `bigint` | no | PK, UQ | IDENTITY BY DEFAULT |  |
| `orden_id` | `integer` | no | FK→taller.facultad_orden, FK→taller.orden_trabajo, UQ |  |  |
| `retira_cliente_id` | `integer` | no | FK→taller.cliente |  |  |
| `facultad_id` | `bigint` | no | FK→taller.facultad_orden |  |  |
| `entregado_por_id` | `integer` | no | FK→taller.personal |  |  |
| `fecha_hora` | `timestamp with time zone` | no |  |  |  |
| `kilometraje_salida` | `integer` | no |  |  |  |
| `revision_final` | `text` | no |  |  |  |
| `recomendaciones_futuras` | `text` | sí |  |  |  |
| `conformidad` | `character varying(12)` | no |  |  |  |
| `observaciones` | `text` | sí |  |  |  |

**Restricciones**

| Nombre | Tipo | Definición |
|---|---|---|
| `ck_entrega_conformidad` | CHECK | `CHECK (((conformidad)::text = ANY ((ARRAY['Conforme'::character varying, 'Inconforme'::character varying])::text[])))` |
| `ck_entrega_inconformidad` | CHECK | `CHECK ((((conformidad)::text = 'Conforme'::text) OR (btrim(COALESCE(observaciones, ''::text)) <> ''::text)))` |
| `ck_entrega_km` | CHECK | `CHECK ((kilometraje_salida >= 0))` |
| `ck_entrega_revision` | CHECK | `CHECK ((btrim(revision_final) <> ''::text))` |
| `fk_entrega_cliente` | FOREIGN KEY | `FOREIGN KEY (retira_cliente_id) REFERENCES taller.cliente(cliente_id)` |
| `fk_entrega_facultad` | FOREIGN KEY | `FOREIGN KEY (facultad_id, orden_id) REFERENCES taller.facultad_orden(facultad_id, orden_id)` |
| `fk_entrega_orden` | FOREIGN KEY | `FOREIGN KEY (orden_id) REFERENCES taller.orden_trabajo(orden_id)` |
| `fk_entrega_personal` | FOREIGN KEY | `FOREIGN KEY (entregado_por_id) REFERENCES taller.personal(personal_id)` |
| `pk_entrega` | PRIMARY KEY | `PRIMARY KEY (entrega_id)` |
| `uq_entrega_ctx` | UNIQUE | `UNIQUE (entrega_id, orden_id)` |
| `uq_entrega_orden` | UNIQUE | `UNIQUE (orden_id)` |

**Triggers:** `trg_entrega_inmutable`, `trg_entrega_validar`


## 31. `garantia`

Garantía otorgada al entregar, por labor completada (D3). Vence lo que ocurra primero: días o km.

| Atributo | Tipo PostgreSQL | Nulo | Clave | Default / generación | Descripción |
|---|---|:---:|---|---|---|
| `garantia_id` | `bigint` | no | PK | IDENTITY BY DEFAULT |  |
| `entrega_id` | `bigint` | no | FK→taller.entrega, UQ |  |  |
| `orden_id` | `integer` | no | FK→taller.entrega, FK→taller.labor |  |  |
| `labor_id` | `bigint` | no | FK→taller.labor, UQ |  |  |
| `dias` | `integer` | sí |  |  |  |
| `km` | `integer` | sí |  |  |  |
| `condiciones` | `text` | sí |  |  |  |

**Restricciones**

| Nombre | Tipo | Definición |
|---|---|---|
| `ck_garantia_dias` | CHECK | `CHECK (((dias IS NULL) OR (dias > 0)))` |
| `ck_garantia_km` | CHECK | `CHECK (((km IS NULL) OR (km > 0)))` |
| `ck_garantia_limite` | CHECK | `CHECK (((dias IS NOT NULL) OR (km IS NOT NULL)))` |
| `fk_garantia_entrega` | FOREIGN KEY | `FOREIGN KEY (entrega_id, orden_id) REFERENCES taller.entrega(entrega_id, orden_id)` |
| `fk_garantia_labor` | FOREIGN KEY | `FOREIGN KEY (labor_id, orden_id) REFERENCES taller.labor(labor_id, orden_id)` |
| `pk_garantia` | PRIMARY KEY | `PRIMARY KEY (garantia_id)` |
| `uq_garantia_labor` | UNIQUE | `UNIQUE (entrega_id, labor_id)` |

**Triggers:** `trg_garantia_inmutable`, `trg_garantia_validar`


## 32. `reclamo_garantia`

Reclamo posterior que abre una orden nueva del mismo VIN (RN-21, RN-22, D3).

| Atributo | Tipo PostgreSQL | Nulo | Clave | Default / generación | Descripción |
|---|---|:---:|---|---|---|
| `reclamo_id` | `bigint` | no | PK | IDENTITY BY DEFAULT |  |
| `garantia_id` | `bigint` | no | FK→taller.garantia |  |  |
| `orden_nueva_id` | `integer` | no | FK→taller.orden_trabajo, UQ |  |  |
| `fecha_reclamo` | `timestamp with time zone` | no |  |  |  |
| `km_reclamo` | `integer` | no |  |  |  |
| `evaluacion` | `text` | no |  |  |  |
| `decision` | `character varying(10)` | no |  |  |  |
| `justificacion` | `text` | sí |  |  |  |
| `evaluado_por_id` | `integer` | no | FK→taller.personal |  |  |

**Restricciones**

| Nombre | Tipo | Definición |
|---|---|---|
| `ck_reclamo_decision` | CHECK | `CHECK (((decision)::text = ANY ((ARRAY['Aceptada'::character varying, 'Rechazada'::character varying, 'Pendiente'::character varying])::text[])))` |
| `ck_reclamo_evaluacion` | CHECK | `CHECK ((btrim(evaluacion) <> ''::text))` |
| `ck_reclamo_justificacion` | CHECK | `CHECK ((((decision)::text = 'Pendiente'::text) OR (btrim(COALESCE(justificacion, ''::text)) <> ''::text)))` |
| `ck_reclamo_km` | CHECK | `CHECK ((km_reclamo >= 0))` |
| `fk_reclamo_garantia` | FOREIGN KEY | `FOREIGN KEY (garantia_id) REFERENCES taller.garantia(garantia_id)` |
| `fk_reclamo_orden` | FOREIGN KEY | `FOREIGN KEY (orden_nueva_id) REFERENCES taller.orden_trabajo(orden_id)` |
| `fk_reclamo_personal` | FOREIGN KEY | `FOREIGN KEY (evaluado_por_id) REFERENCES taller.personal(personal_id)` |
| `pk_reclamo_garantia` | PRIMARY KEY | `PRIMARY KEY (reclamo_id)` |
| `uq_reclamo_orden_nueva` | UNIQUE | `UNIQUE (orden_nueva_id)` |

**Triggers:** `trg_reclamo_validar`


