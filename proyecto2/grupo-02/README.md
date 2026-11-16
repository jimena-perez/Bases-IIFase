# Proyecto 2 — Implementación del modelo completo · Taller Ruta 27

**Instituto Tecnológico de Costa Rica · Escuela de Ingeniería en Computación**
**Curso:** IC-4301 Bases de Datos I · **Profesor:** Jonathan Arturo Cortés Seas
**Grupo:** 02 · **Integrantes:** Jimena Pérez Alfaro · Rachel Priscilla Ramírez González
**Caso:** Taller Ruta 27 (taller de reparación de vehículos)
**Motor:** PostgreSQL 17

Esta entrega implementa en PostgreSQL el **100 % del modelo relacional final**: 32 relaciones que cubren las 23 del Proyecto 1, corregidas y ampliadas. Implementa también **exactamente tres procesos**, cada uno con atomicidad, concurrencia demostrada con dos sesiones y evidencias válidas (V), inválidas (I) y límite (L):

| Proceso | Nombre |
|---|---|
| **G02-P01** | Versionar propuestas y autorizar labores |
| **G02-P02** | Ejecutar reparaciones y pruebas (incluye consumo de repuestos) |
| **G02-P03** | Gestionar estados de la orden y fecha prometida |

Las relaciones fuera de los procesos tienen datos ficticios válidos y pruebas de integridad.

**Resultado de la ejecución desde una base nueva:** el esquema carga sin errores con `ON_ERROR_STOP`, y la batería registra **250 comprobaciones, 250 OK y 0 fallos** (177 rechazos esperados con causa visible y 73 verificaciones de datos). Además se ejecutaron 7 escenarios de concurrencia con dos sesiones `psql` reales. Ver [`resultados/`](resultados/).

---

## Índice

1. [Entorno y versión](#1-entorno-y-versión)
2. [Cómo ejecutar desde cero](#2-cómo-ejecutar-desde-cero)
3. [Orden de los scripts](#3-orden-de-los-scripts)
4. [Estructura de la entrega](#4-estructura-de-la-entrega)
5. [Resumen del modelo](#5-resumen-del-modelo)
6. [Procesos implementados](#6-procesos-implementados)
7. [Evidencias](#7-evidencias)
8. [Continuidad con el Lab03 y el Proyecto 1](#8-continuidad-con-el-lab03-y-el-proyecto-1)
9. [Limitaciones y supuestos](#9-limitaciones-y-supuestos)
10. [Checklist de aceptación](#10-checklist-de-aceptación)

---

## 1. Entorno y versión

Salida real (también en [`resultados/entorno.md`](resultados/entorno.md)):

```text
SELECT version();
PostgreSQL 17.10 on x86_64-pc-linux-gnu, compiled by gcc (Ubuntu 7.5.0-3ubuntu1~18.04) 7.5.0, 64-bit

psql --version
psql (PostgreSQL) 16.15 (Ubuntu 16.15-0ubuntu0.24.04.1)

Extensiones: btree_gist 1.7, plpgsql 1.0 · Codificación: UTF8 · Aislamiento: read committed
```

- **Servidor:** PostgreSQL **17.10**, el mismo motor mayor que el Lab03.
- **Cliente:** el entorno de ejecución tenía `psql` 16.15. Es compatible con el servidor 17 y no se usó ningún comando de `psql` exclusivo de la 17.
- **Extensión requerida:** `btree_gist`, para las restricciones `EXCLUDE` de vigencias. Es *trusted* desde PostgreSQL 13, así que la instala el dueño de la base sin ser superusuario. `00_reset.sql` la crea.
- **Base:** debe crearse en **UTF8** (los dominios usan tildes, como 'En diagnóstico').

## 2. Cómo ejecutar desde cero

Desde la carpeta `proyecto2/grupo-02` (Linux, WSL o macOS):

```bash
createdb -U postgres -E UTF8 -T template0 taller_ruta27
```

```bash
psql -U postgres -d taller_ruta27 -v ON_ERROR_STOP=1 -f sql/run_all.sql
```

```bash
psql -U postgres -d taller_ruta27 -v ON_ERROR_STOP=1 -f pruebas/run_pruebas.sql > salida_pruebas_local.txt 2>&1
```

Concurrencia (dos terminales; pasos en `pruebas/concurrencia/P0x_instrucciones.md`):

```bash
psql -U postgres -d taller_ruta27 -f pruebas/concurrencia/00_preparacion_concurrencia.sql
```

**Con Docker** (equivalente al contenedor del Lab03), desde `proyecto2/grupo-02`. Se monta la carpeta al crear el contenedor:

```bash
docker run -d --name taller-pg17 -e POSTGRES_PASSWORD=postgres -v "$PWD":/work postgres:17
```

```bash
docker exec -i taller-pg17 createdb -U postgres -E UTF8 -T template0 taller_ruta27
```

```bash
docker exec -i -w /work taller-pg17 psql -U postgres -d taller_ruta27 -v ON_ERROR_STOP=1 -f sql/run_all.sql
```

```bash
docker exec -i -w /work taller-pg17 psql -U postgres -d taller_ruta27 -v ON_ERROR_STOP=1 -f pruebas/run_pruebas.sql
```

**Windows con pgAdmin:**
1. Crear la base `taller_ruta27` con *Encoding* UTF8 y *Template* template0.
2. Abrir *PSQL Tool* sobre esa base y ejecutar `\cd 'C:/ruta/al/repo/proyecto2/grupo-02'`.
3. Ejecutar `\i sql/run_all.sql` y luego `\i pruebas/run_pruebas.sql`.

`run_all.sql` y `run_pruebas.sql` usan `\ir`, que resuelve las rutas relativas al propio archivo, por lo que funcionan desde cualquier directorio de trabajo.

**Repetir sin residuos:** `run_all.sql` empieza con `00_reset.sql`, que elimina y recrea solo los esquemas `taller` y `pruebas`. Basta con volver a correr `run_all.sql` y luego `run_pruebas.sql`. Ningún script deja una transacción abierta: `run_pruebas.sql` lo comprueba al final. La batería parte del estado de preparación y se niega a correr sobre una base que ya tiene resultados de procesos.

## 3. Orden de los scripts

| # | Archivo | Qué hace |
|---:|---|---|
| 0 | `sql/00_reset.sql` | `DROP SCHEMA taller/pruebas CASCADE`, `CREATE SCHEMA taller` y extensión `btree_gist`. |
| 1 | `sql/01_esquema.sql` | 32 tablas, dominios, PK, FK (incluidas las FK compuestas de contexto), UQ, CHECK, EXCLUDE, índices justificados, catálogo de transiciones y comentarios. |
| 2 | `sql/02_triggers_integridad.sql` | Inmutabilidad, reglas de contexto, facultades, sincronización "valor actual + historial", existencias, entrega, garantía y reclamo. |
| 3 | `sql/03_rutinas_p01.sql` | Vistas de regla (decisión aplicable) y `fn_publicar_propuesta`, `fn_registrar_decision`, `fn_anular_labor`. |
| 4 | `sql/04_rutinas_p02.sql` | `fn_iniciar_labor`, `fn_registrar_emergencia`, `fn_registrar_participacion`, `fn_cerrar_participacion`, `fn_registrar_prueba`, `fn_registrar_consumo`, `fn_suspender_labor`, `fn_completar_labor`, `fn_registrar_retrabajo`. |
| 5 | `sql/05_rutinas_p03.sql` | `fn_cambiar_estado_orden` y `fn_cambiar_fecha_prometida`. |
| 6 | `sql/06_vistas_consultas.sql` | Vistas observables de P01, P02 y P03, y Q01–Q04 del Lab03 con rótulos corregidos. |
| 7 | `sql/07_datos_iniciales.sql` | Datos ficticios de **preparación**, sin resultados de procesos; IDs fijos y secuencias ajustadas. |
| 8 | `sql/08_rutinas_lab03.sql` | Rutinas del Lab03 **reutilizadas sin modificación**, entre ellas el alta `sp_registrar_orden`. |
| — | `sql/run_all.sql` | Ejecuta 00 → 08 con `ON_ERROR_STOP` y muestra el conteo de objetos y `version()`. |
| — | `pruebas/run_pruebas.sql` | Ejecuta 00_utilidades → P01 → P02 → P03 → integridad y muestra el resumen. Falla si hay algún FALLO. |

Objetos creados: 32 tablas · 22 vistas · 58 funciones y procedimientos · 52 triggers · más de 230 restricciones con nombre.

## 4. Estructura de la entrega

```text
proyecto2/grupo-02/
├── README.md                     ← este documento
├── Control_de_Cambios.md         ← D1–D12, C-01…C-17 y "Reutilización sin modificación"
├── Uso_de_IA.md
├── Defensa.md                    ← enlaces de video (pendientes) y guion por integrante
├── docs/
│   ├── modelo_relacional.md      ← esquema final + diagrama Mermaid + decisiones físicas
│   ├── diccionario_datos.md      ← generado desde el catálogo de PostgreSQL
│   ├── correspondencia_P1_actual.md
│   ├── trazabilidad.md           ← RN / validaciones posteriores / D / AC → mecanismo → prueba
│   ├── matriz_regla_mecanismo_prueba.md
│   └── ambiguedades.md           ← A-01 … A-16
├── sql/                          ← 00 … 08 + run_all.sql
├── pruebas/
│   ├── 00_utilidades_pruebas.sql ← esquema "pruebas": bitácora y utilidades
│   ├── 10…13 (P01) · 20…23 (P02) · 30…33 (P03) · 90_integridad_modelo.sql
│   ├── run_pruebas.sql
│   └── concurrencia/             ← preparación, sesiones A/B por escenario, instrucciones
└── resultados/                   ← salidas REALES (en .md, ver C-16)
    ├── entorno.md · salida_run_all.md
    ├── salida_pruebas_p01.md · _p02.md · _p03.md · _integridad.md
    ├── evidencias_observadas.md  ← tabla de las 250 comprobaciones con SQLSTATE y mensaje
    └── concurrencia.md           ← 7 escenarios con dos sesiones reales
```

## 5. Resumen del modelo

32 relaciones en 5 áreas (detalle en [`docs/modelo_relacional.md`](docs/modelo_relacional.md) y [`docs/diccionario_datos.md`](docs/diccionario_datos.md)):

| Área | Relaciones |
|---|---|
| Maestros e identidad | `cliente`, `contacto_cliente`, `vehiculo`, `propiedad_vehiculo`*, `personal`, `especialidad_tecnico`, `repuesto`, `proveedor`*, `proveedor_repuesto` |
| Visita y recepción | `orden_trabajo`, `facultad_orden`*, `objeto_dano`, `historial_orden`, `historial_fecha_prometida`, `transicion_estado_orden`* |
| Diagnóstico y presupuesto (P01) | `hallazgo`, `propuesta`, `labor`, `linea_propuesta`*, `repuesto_propuesto`, `autorizacion_labor` |
| Ejecución (P02) | `excepcion_emergencia`*, `labor_dependencia`*, `historial_labor`*, `participacion_tecnica`, `prueba`, `consumo_repuesto`, `movimiento_inventario`, `pieza_retirada` |
| Entrega y garantía | `entrega`, `garantia`*, `reclamo_garantia` |

\* Relación nueva respecto del P1 (correspondencia completa en [`docs/correspondencia_P1_actual.md`](docs/correspondencia_P1_actual.md)).

**Técnicas clave:**

- **FK compuestas de contexto**, que demuestran *pertenencia* a la misma orden o labor y no solo existencia.
- **Valor actual + historial** sincronizados en la misma transacción: el UPDATE directo se rechaza y un constraint trigger diferido verifica la coherencia al COMMIT.
- **Tablas de solo inserción.**
- **`EXCLUDE`** para las vigencias.
- **Existencias derivadas**, que nunca son negativas.
- **Errores de negocio** con `SQLSTATE P0001` y prefijo `G02-…`, para que cada rechazo sea legible en las evidencias.

## 6. Procesos implementados

Todas las rutinas son funciones PL/pgSQL. Cada llamada es **atómica**: una excepción en cualquier paso revierte todo lo hecho por esa llamada. Las reglas se aplican además en **triggers**, de modo que también se cumplen si alguien inserta "a mano".

### 6.1 G02-P01 — Versionar propuestas y autorizar labores

| Rutina / vista | Función |
|---|---|
| `fn_publicar_propuesta(orden, base, lineas jsonb, personal, observacion, fecha_hora)` | En **una** transacción: bloquea la orden (`FOR UPDATE`), calcula `version = max + 1`, crea las labores nuevas, inserta líneas, repuestos estimados y dependencias, valida todo (≥ 1 línea, precios ≥ 0, hallazgos y labores de la misma orden, sin duplicados) y la marca **Presentada**. Si un detalle es inválido no queda nada. |
| `fn_registrar_decision(propuesta, labor, cliente, decision, medio, registrado_por, fecha_hora, observacion, decision_esperada)` | Resuelve la facultad *Aprobar* vigente del cliente en **esa** orden, bloquea la línea (`FOR UPDATE`) y **solo inserta**. Con `decision_esperada` aplica control optimista. |
| `fn_anular_labor` | Retira una labor (Anulada, con motivo) sin borrar nada (ambigüedad A-03). |
| `v_situacion_labor`, `v_autorizacion_ejecutable`, `v_comparacion_versiones`, `v_decision_linea`, `v_version_vigente_labor`, `v_facultades_orden` | Resultados observables y reglas. |

**Regla de "decisión aplicable"** (implementada en `v_situacion_labor` y usada por los triggers):

1. La **versión vigente** de una labor es la versión *Presentada* de mayor número que contiene una línea de esa labor.
2. La **decisión aplicable** es la última fila de `autorizacion_labor` (por `fecha_hora`, con desempate por `autorizacion_id`) **sobre la línea de la versión vigente**. Para que "última" coincida con "última confirmada", el trigger rechaza una decisión con fecha anterior a la última registrada en su línea.
3. Las decisiones **no se arrastran** entre versiones: si la v2 vuelve a incluir una labor (por ejemplo, porque cambió el precio), esa labor queda *Sin decidir* en v2 aunque en v1 estuviera aceptada. Una labor rechazada en v1 y re-ofrecida en v2 no queda autorizada hasta que haya una decisión *Aceptada* sobre la línea de v2.
4. Una ampliación que solo **añade** labores no toca las que no incluye: estas conservan su versión vigente y su decisión.
5. La autorización ejecutable se identifica por **`autorizacion_id`**: `historial_labor` la cita al pasar a *En proceso*. **Nunca** se deduce de `orden_trabajo.autorizador_cliente_id`.

Además, solo se puede decidir sobre la versión vigente (A-09). *Pendiente* explícita y *Sin decidir* son situaciones distintas y ninguna es ejecutable (A-02).

**Concurrencia:**
- *C1:* dos publicaciones simultáneas se serializan con el bloqueo de la orden y la segunda obtiene `version + 1`. `UNIQUE (orden_id, version)` es el respaldo.
- *C2:* aceptar y rechazar la misma línea a la vez queda serializado con `FOR UPDATE`; la aplicable es la última confirmada.
- *C3:* con `decision_esperada`, la segunda sesión es rechazada explícitamente.

### 6.2 G02-P02 — Ejecutar reparaciones y pruebas

| Rutina | Reglas que hace cumplir (también en triggers) |
|---|---|
| `fn_iniciar_labor` | La labor no está Anulada ni Completada; **todas** sus dependencias están Completadas; tiene autorización aplicable **Aceptada** o, si es de emergencia, su excepción. Registra en `historial_labor` el `autorizacion_id` o `emergencia_id` habilitante. |
| `fn_registrar_emergencia` | Crea la labor **mínima** de emergencia y su excepción justificada (≥ 20 caracteres, riesgo, alcance). Habilita **solo** esa labor. |
| `fn_registrar_participacion` / `fn_cerrar_participacion` | Técnico existente, con rol Técnico y activo; especialidad del mismo técnico y vigente; labor En proceso; inicio no anterior al inicio de la labor; minutos efectivos ≤ intervalo; sin traslapes del mismo técnico. |
| `fn_registrar_prueba` | Resultado categórico; medición opcional (valor y unidad juntos); descripción obligatoria. |
| `fn_registrar_consumo(orden, labor, repuesto, cantidad, precio, personal, fecha_hora)` | La labor es de esa orden. En la **misma** transacción: consumo + liberación de la reserva de la orden (si existía) + movimiento de Consumo con origen. Si no hay existencias se revierte todo. |
| `fn_completar_labor` | ≥ 1 participación cerrada y ninguna abierta; si la **última** prueba es Desfavorable, exige un retrabajo de esa prueba ya Completado. |
| `fn_registrar_retrabajo` | Labor nueva ligada a la labor revisada y a la prueba Desfavorable; **no** modifica la original. Requiere su propia línea y decisión (A-01). |
| `fn_suspender_labor` | Con motivo; al reanudar se vuelve a exigir el habilitante. |
| Vistas | `v_historia_labor`, `v_participaciones`, `v_pruebas`, `v_retrabajos`, `v_propuesto_vs_ejecutado`, `v_existencias`, `v_insumos_orden`. |

**Concurrencia:** todas las operaciones sobre una labor bloquean su fila (`FOR UPDATE`).
- *C1:* completar mientras otra sesión registra una participación: la segunda espera y es rechazada (labor ya Completada).
- *C2:* el inventario bloquea la fila del repuesto y recalcula las existencias. De dos consumos simultáneos de la última unidad, uno se confirma y el otro falla; el stock final es 0.

### 6.3 G02-P03 — Gestionar estados de la orden y fecha prometida

| Rutina / vista | Función |
|---|---|
| `fn_cambiar_estado_orden(orden, estado_nuevo, personal, motivo, fecha_hora, estado_esperado)` | Bloquea la orden; error explícito si no existe; control optimista opcional; inserta en `historial_orden`. El trigger valida la transición del catálogo, el motivo en retrocesos y cancelaciones, el orden temporal y las reglas de contexto (A-11), asigna `secuencia` y `estado_anterior` y actualiza `estado_actual` **en la misma transacción**. |
| `fn_cambiar_fecha_prometida(orden, fecha_nueva, comunicada_en, medio, motivo, personal, fecha_esperada)` | Igual que la anterior para la promesa: la primera fila es la promesa original; toda reprogramación exige motivo; `fecha_anterior` la asigna el sistema. |
| `v_estado_actual_orden`, `v_cronologia_estados`, `v_cronologia_promesas`, `v_promesas`, `v_pendientes` | Estados y promesas en **vistas separadas**, sin mezclarlos. |

**Corrección D4:**
- `trg_orden_antes_actualizar` rechaza el `UPDATE` directo de `estado_actual` o `fecha_prometida_actual`; solo el trigger del historial los cambia.
- El constraint trigger diferido `trg_orden_coherencia` verifica al COMMIT que el valor actual sea igual a la última fila de cada historial. Es una segunda defensa, probada en G02-P03-A-02.
- **Mismo instante:** el orden lo da `secuencia`, asignada bajo el bloqueo, no `fecha_hora`.
- **Cancelar no borra nada:** las órdenes no se eliminan y los estados terminales no tienen salida.

**Concurrencia:**
- *C1:* bloqueo pesimista. B espera y se aplica después; los dos cambios quedan en la historia.
- *C2:* control optimista. B es rechazada porque el estado cambió.

Se muestran los dos escenarios, con su justificación en `pruebas/concurrencia/P03_instrucciones.md`.

## 7. Evidencias

- **Bitácora:** cada prueba se registra en `pruebas.evidencia`:
  - `pruebas.esperar_rechazo` ejecuta la sentencia en una subtransacción, compara la causa con el patrón esperado y guarda el SQLSTATE y el mensaje reales;
  - `pruebas.verificar` guarda la lectura posterior de datos que demuestra el resultado o la ausencia de efectos.

  La tabla completa, con el mensaje de cada rechazo, está en [`resultados/evidencias_observadas.md`](resultados/evidencias_observadas.md).
- **Persistencia:** al menos una prueba por proceso confirma con `COMMIT` y lee en una transacción posterior (V-01 y V-04 de P01, V-01 de P02, V-01 y V-02 de P03).
- **Datos con contextos válidos distintos:**
  - dos órdenes con clientes facultados distintos (9001 María titular, 9002 Ana designada);
  - técnicos con especialidades distintas, una vencida y una técnica inactiva;
  - personal que existe pero no es técnico;
  - dos vehículos para los reclamos.

  Así se demuestra pertenencia y no solo inexistencia.
- **Criterios AC:** se redactaron a partir de cada proceso (ver [`docs/trazabilidad.md`](docs/trazabilidad.md) §4 y la ambigüedad A-15).

### Tabla de evidencias: ID → criterio → archivo → resultado observado

Generada desde la bitácora tras la ejecución desde una base nueva.

| ID | Criterio(s) | Archivo (`pruebas/`) | Comprobaciones | Resultado |
|---|---|---|---:|---|
| G02-P01-A-01 | AC-G02-P01-01 | `13_p01_atomicidad.sql` | 3 | ✔ 3/3 OK |
| G02-P01-A-02 | AC-G02-P01-01 | `13_p01_atomicidad.sql` | 1 | ✔ 1/1 OK |
| G02-P01-A-03 | AC-G02-P01-01 | `13_p01_atomicidad.sql` | 1 | ✔ 1/1 OK |
| G02-P01-I-01 | AC-G02-P01-03 | `11_p01_invalidas.sql` | 6 | ✔ 6/6 OK |
| G02-P01-I-02 | AC-G02-P01-03 | `11_p01_invalidas.sql` | 4 | ✔ 4/4 OK |
| G02-P01-I-03 | AC-G02-P01-03 | `11_p01_invalidas.sql` | 1 | ✔ 1/1 OK |
| G02-P01-I-04 | AC-G02-P01-01, AC-G02-P01-02 | `11_p01_invalidas.sql` | 8 | ✔ 8/8 OK |
| G02-P01-I-05 | AC-G02-P01-04 | `11_p01_invalidas.sql` | 1 | ✔ 1/1 OK |
| G02-P01-I-06 | AC-G02-P01-02 | `11_p01_invalidas.sql` | 4 | ✔ 4/4 OK |
| G02-P01-I-07 | AC-G02-P01-03 | `11_p01_invalidas.sql` | 3 | ✔ 3/3 OK |
| G02-P01-I-08 | AC-G02-P01-01, AC-G02-P01-03 | `11_p01_invalidas.sql` | 7 | ✔ 7/7 OK |
| G02-P01-L-01 | AC-G02-P01-04 | `12_p01_limite.sql` | 2 | ✔ 2/2 OK |
| G02-P01-L-02 | AC-G02-P01-01 | `12_p01_limite.sql` | 1 | ✔ 1/1 OK |
| G02-P01-L-03 | AC-G02-P01-04 | `12_p01_limite.sql` | 3 | ✔ 3/3 OK |
| G02-P01-L-04 | AC-G02-P01-04 | `12_p01_limite.sql` | 1 | ✔ 1/1 OK |
| G02-P01-L-05 | AC-G02-P01-04 | `12_p01_limite.sql` | 4 | ✔ 4/4 OK |
| G02-P01-V-01 | AC-G02-P01-01 | `10_p01_validas.sql` | 1 | ✔ 1/1 OK |
| G02-P01-V-02 | AC-G02-P01-02, AC-G02-P01-04 | `10_p01_validas.sql` | 2 | ✔ 2/2 OK |
| G02-P01-V-03 | AC-G02-P01-01 | `10_p01_validas.sql` | 1 | ✔ 1/1 OK |
| G02-P01-V-04 | AC-G02-P01-01, AC-G02-P01-02, AC-G02-P01-04 | `10_p01_validas.sql` | 3 | ✔ 3/3 OK |
| G02-P02-A-01 | AC-G02-P02-04 | `23_p02_atomicidad.sql` | 2 | ✔ 2/2 OK |
| G02-P02-A-02 | AC-G02-P02-03 | `23_p02_atomicidad.sql` | 2 | ✔ 2/2 OK |
| G02-P02-A-03 | AC-G02-P02-04 | `23_p02_atomicidad.sql` | 5 | ✔ 5/5 OK |
| G02-P02-I-01 | AC-G02-P02-01 | `21_p02_invalidas.sql` | 6 | ✔ 6/6 OK |
| G02-P02-I-02 | AC-G02-P02-01 | `21_p02_invalidas.sql` | 2 | ✔ 2/2 OK |
| G02-P02-I-03 | AC-G02-P02-02 | `21_p02_invalidas.sql` | 1 | ✔ 1/1 OK |
| G02-P02-I-04 | AC-G02-P02-02 | `21_p02_invalidas.sql` | 6 | ✔ 6/6 OK |
| G02-P02-I-05 | AC-G02-P02-04 | `21_p02_invalidas.sql` | 2 | ✔ 2/2 OK |
| G02-P02-I-06 | AC-G02-P02-04 | `21_p02_invalidas.sql` | 2 | ✔ 2/2 OK |
| G02-P02-I-07 | AC-G02-P02-03 | `21_p02_invalidas.sql` | 2 | ✔ 2/2 OK |
| G02-P02-I-08 | AC-G02-P02-01 | `21_p02_invalidas.sql` | 3 | ✔ 3/3 OK |
| G02-P02-I-09 | AC-G02-P02-02 | `21_p02_invalidas.sql` | 2 | ✔ 2/2 OK |
| G02-P02-I-10 | AC-G02-P02-02, AC-G02-P02-03, AC-G02-P02-04 | `21_p02_invalidas.sql` | 6 | ✔ 6/6 OK |
| G02-P02-I-11 | AC-G02-P02-03 | `21_p02_invalidas.sql` | 5 | ✔ 5/5 OK |
| G02-P02-L-01 | AC-G02-P02-03 | `22_p02_limite.sql` | 1 | ✔ 1/1 OK |
| G02-P02-L-02 | AC-G02-P02-01 | `22_p02_limite.sql` | 7 | ✔ 7/7 OK |
| G02-P02-L-03 | AC-G02-P02-02 | `22_p02_limite.sql` | 1 | ✔ 1/1 OK |
| G02-P02-L-04 | AC-G02-P02-01, AC-G02-P02-03 | `22_p02_limite.sql` | 2 | ✔ 2/2 OK |
| G02-P02-L-05 | AC-G02-P02-01 | `22_p02_limite.sql` | 2 | ✔ 2/2 OK |
| G02-P02-V-01 | AC-G02-P02-01, AC-G02-P02-02, AC-G02-P02-03, AC-G02-P02-04 | `20_p02_validas.sql` | 5 | ✔ 5/5 OK |
| G02-P02-V-02 | AC-G02-P02-04 | `20_p02_validas.sql` | 1 | ✔ 1/1 OK |
| G02-P03-A-01 | AC-G02-P03-03 | `33_p03_atomicidad.sql` | 2 | ✔ 2/2 OK |
| G02-P03-A-02 | AC-G02-P03-03 | `33_p03_atomicidad.sql` | 2 | ✔ 2/2 OK |
| G02-P03-I-01 | AC-G02-P03-03 | `31_p03_invalidas.sql` | 2 | ✔ 2/2 OK |
| G02-P03-I-02 | AC-G02-P03-02 | `31_p03_invalidas.sql` | 3 | ✔ 3/3 OK |
| G02-P03-I-03 | AC-G02-P03-01 | `31_p03_invalidas.sql` | 2 | ✔ 2/2 OK |
| G02-P03-I-04 | AC-G02-P03-03 | `31_p03_invalidas.sql` | 3 | ✔ 3/3 OK |
| G02-P03-I-05 | AC-G02-P03-03 | `31_p03_invalidas.sql` | 2 | ✔ 2/2 OK |
| G02-P03-I-06 | AC-G02-P03-01 | `31_p03_invalidas.sql` | 3 | ✔ 3/3 OK |
| G02-P03-I-07 | AC-G02-P03-01, AC-G02-P03-02, AC-G02-P03-03 | `31_p03_invalidas.sql` | 7 | ✔ 7/7 OK |
| G02-P03-L-01 | AC-G02-P03-04 | `32_p03_limite.sql` | 2 | ✔ 2/2 OK |
| G02-P03-L-02 | AC-G02-P03-04 | `32_p03_limite.sql` | 4 | ✔ 4/4 OK |
| G02-P03-L-03 | AC-G02-P03-02 | `32_p03_limite.sql` | 1 | ✔ 1/1 OK |
| G02-P03-L-04 | AC-G02-P03-01 | `32_p03_limite.sql` | 1 | ✔ 1/1 OK |
| G02-P03-V-01 | AC-G02-P03-01, AC-G02-P03-03 | `30_p03_validas.sql` | 3 | ✔ 3/3 OK |
| G02-P03-V-02 | AC-G02-P03-02 | `30_p03_validas.sql` | 2 | ✔ 2/2 OK |
| G02-INT-01 | RN-04 | `90_integridad_modelo.sql` | 3 | ✔ 3/3 OK |
| G02-INT-02 | RN-03 | `90_integridad_modelo.sql` | 6 | ✔ 6/6 OK |
| G02-INT-03 | RN-02 | `90_integridad_modelo.sql` | 4 | ✔ 4/4 OK |
| G02-INT-04 | RN-02 | `90_integridad_modelo.sql` | 1 | ✔ 1/1 OK |
| G02-INT-05 | RN-02, RN-04 | `90_integridad_modelo.sql` | 3 | ✔ 3/3 OK |
| G02-INT-06 | RN-01, RN-05, RN-08 | `90_integridad_modelo.sql` | 8 | ✔ 8/8 OK |
| G02-INT-07 | RN-04 | `90_integridad_modelo.sql` | 5 | ✔ 5/5 OK |
| G02-INT-08 | RN-06 | `90_integridad_modelo.sql` | 3 | ✔ 3/3 OK |
| G02-INT-09 | RN-09 | `90_integridad_modelo.sql` | 5 | ✔ 5/5 OK |
| G02-INT-10 | RN-14 | `90_integridad_modelo.sql` | 5 | ✔ 5/5 OK |
| G02-INT-11 | RN-17 | `90_integridad_modelo.sql` | 6 | ✔ 6/6 OK |
| G02-INT-12 | RN-19 | `90_integridad_modelo.sql` | 8 | ✔ 8/8 OK |
| G02-INT-13 | RN-18 | `90_integridad_modelo.sql` | 3 | ✔ 3/3 OK |
| G02-INT-14 | RN-18 | `90_integridad_modelo.sql` | 1 | ✔ 1/1 OK |
| G02-INT-15 | RN-15 | `90_integridad_modelo.sql` | 4 | ✔ 4/4 OK |
| G02-INT-16 | RN-20 | `90_integridad_modelo.sql` | 8 | ✔ 8/8 OK |
| G02-INT-17 | RN-22 | `90_integridad_modelo.sql` | 3 | ✔ 3/3 OK |
| G02-INT-18 | RN-21, RN-22 | `90_integridad_modelo.sql` | 9 | ✔ 9/9 OK |
| G02-INT-19 | D5 | `90_integridad_modelo.sql` | 2 | ✔ 2/2 OK |
| G02-INT-20 | D4, D9 | `90_integridad_modelo.sql` | 2 | ✔ 2/2 OK |

### Concurrencia (dos sesiones reales, [`resultados/concurrencia.md`](resultados/concurrencia.md))

| ID | Escenario | Mecanismo | Resultado observado |
|---|---|---|---|
| G02-P01-C1 | Dos publicaciones simultáneas sobre la orden 9011 | `FOR UPDATE` de la orden | B esperó unos 2 s y obtuvo la v2; v1 (A) y v2 (B) confirmadas ✔ |
| G02-P01-C2 | A acepta y B rechaza la misma línea | `FOR UPDATE` de la línea | Serializadas; se conservan las 2 filas; la aplicable es la Rechazada (última confirmada) ✔ |
| G02-P01-C3 | Lo mismo con control optimista | `p_decision_esperada` | B fue rechazada: "se esperaba «Sin decidir» y la decisión vigente es «Aceptada»" ✔ |
| G02-P02-C1 | Completar la labor mientras otra sesión registra una participación | `FOR UPDATE` de la labor | B esperó y fue rechazada (labor Completada); 1 participación ✔ |
| G02-P02-C2 | Dos consumos simultáneos de la última unidad de FR-003 | `FOR UPDATE` del repuesto | Un consumo confirmado y el otro rechazado por existencias; físico 0 ✔ |
| G02-P03-C1 | Dos reprogramaciones simultáneas de la orden 9013 | `FOR UPDATE` de la orden + `secuencia` | Ambas en la historia (secuencias 2 y 3); la `fecha_anterior` de B es la fecha de A ✔ |
| G02-P03-C2 | Cambio de estado con control optimista | `p_estado_esperado` | B fue rechazada: "se esperaba el estado «Recibida» y la orden está en «En diagnóstico»" ✔ |

## 8. Continuidad con el Lab03 y el Proyecto 1

- **Lab03 leído** desde la rama `lab03-grupo02-entrega` del repositorio del curso (`jimena-perez/bd1-2026-2s`), en modo solo lectura. **No se modificó** la carpeta `lab03/` ni su PR.
- **Reutilizado sin modificación:**
  - el alta `sp_registrar_orden` con su historial inicial;
  - las funciones `fn_total_ordenes_cliente` y `fn_prioridad_orden` y la demostración de la tabla temporal;
  - el texto SQL de Q01–Q04 y las identidades (clientes, vehículos y personal).

  Detalle en [`Control_de_Cambios.md`](Control_de_Cambios.md), parte C. El alta del Lab03 se prueba en G02-INT-06.
- **Corregido:** los rótulos de Q02 ("visitas por vehículo") y Q04 ("conteo de órdenes por estado") y el defecto de la fecha prometida sobrescrita (D4).
- **Adaptado mínimamente:** los datos de órdenes e hallazgos (C-11), porque los resultados de los procesos no se pueden precargar y D1 exige autor.

## 9. Limitaciones y supuestos

- Los supuestos de diseño están en [`docs/ambiguedades.md`](docs/ambiguedades.md) (A-01 … A-16). Ninguno contradice el caso ni excluye una situación.
- `00_Enunciado_General.md` y `Control_de_Cambios_Especificacion.md` **no estaban disponibles**. Se usaron la ruta `proyecto2/grupo-02/` y el formato de las instrucciones §9.2. Si esos documentos fijan otra ruta o formato, prevalecen (A-15).
- **No se implementan como flujos completos** (no lo pide la entrega) las compras y proveedores, la entrega comercial y la garantía. Sus tablas existen y su integridad está probada.
- La variable de transacción `taller.via_historial` puede encenderse a mano. Por eso existe la segunda defensa (constraint trigger diferido de coherencia, G02-P03-A-02). Un superusuario siempre podría desactivar los triggers; eso queda fuera del modelo.
- Las pruebas de concurrencia usan `pg_sleep(3)` en la sesión A para que la espera de B sea observable. En el video puede ejecutarse paso a paso.
- Los resultados se guardaron en `.md` y no en `.txt` (C-16).

## 10. Checklist de aceptación

- [x] Todas las relaciones del inventario (23 del P1) tienen correspondencia; las 9 nuevas están justificadas.
- [x] El esquema carga desde una base nueva con `ON_ERROR_STOP` en PostgreSQL 17.10.
- [x] RN-01…RN-22 y cada "validación posterior" del P1 tienen mecanismo **y** prueba ([`docs/trazabilidad.md`](docs/trazabilidad.md)).
- [x] P01: V, I (incluye contexto ajeno con datos válidos distintos y persona sin facultad), L, atomicidad y concurrencia; regla de decisión aplicable documentada; v1 intacta tras v2.
- [x] P02: V (2 participaciones, prueba desfavorable, retrabajo ligado, insumos), I (rechazada, dependencia, técnico o labor ajena), L (sin repuestos, prueba descriptiva, emergencia acotada, efectivo ≠ intervalo), atomicidad y concurrencia.
- [x] P03: V (avance, retroceso a diagnóstico, 2 cambios de promesa), I (orden inexistente, sin motivo, UPDATE directo bloqueado, fallo parcial), L (mismo instante, cancelada consultable), atomicidad y concurrencia.
- [x] Pruebas de integridad del resto del modelo (entrega, garantía sin reclamo, reclamo, inventario, pieza retirada, proveedor, especialidades, contactos, propiedad).
- [x] Ninguna evidencia usa resultados precargados de los procesos (`07_datos_iniciales.sql` termina con 0 propuestas, labores y autorizaciones).
- [x] Cada evidencia tiene ID, criterio, preparación, acción, esperado, observado y comprobación de datos.
- [x] `resultados/` generado por ejecución real.
- [x] Q02 y Q04 con rótulos corregidos; alta del Lab03 reutilizada.
- [x] README, docs, `Control_de_Cambios.md` (con "Reutilización sin modificación"), `Uso_de_IA.md` y `Defensa.md`. Los enlaces de video y la validación propia de las integrantes quedan pendientes, porque les corresponden a ellas.
- [x] Sin transacciones abiertas; repetible sin residuos.
- [x] Rama `proyecto2/grupo-02` subida con commits pequeños; el PR **no** lo abrió el agente.
