# Control de cambios — Proyecto 2 (Grupo 02, Taller Ruta 27)

**IC-4301 Bases de Datos I · Tecnológico de Costa Rica**

> **Formato:** `Control_de_Cambios_Especificacion.md` no está en el repositorio del grupo ni en el del curso (ver [ambigüedad A-15](docs/ambiguedades.md#a-15--documentos-comunes-ausentes-y-criterios-ac)). Por eso se usa el formato de las instrucciones de la entrega (§9.2): **ID · Fuente · Situación anterior · Modificación · Justificación · Reglas afectadas · Impacto · Archivos · Prueba actual**.
>
> Fuentes: *Revisión P1* (observaciones del profesor al Proyecto 1) · *Lab03* (entrega y defensa del Laboratorio 3) · *Diseño P1* (defecto detectado al implementar el modelo del P1) · *Anexo G02 / Instrucciones §x* (requisito de esta entrega).
>
> **No se cambió por cambiar:** cada entrada responde a un defecto, a una regla sin mecanismo o a una necesidad de implementación.

---

## Parte A — Defectos señalados (D1 … D12)

### D1 · El hallazgo no tenía autor
- **Fuente:** Revisión P1.
- **Situación anterior:** `HALLAZGO(hallazgo_id, orden_id, sintoma_comprobado, posible_causa, urgencia, recomendacion)`, sin quién diagnosticó ni cuándo.
- **Modificación:** se agregan `diagnosticado_por_id` (NOT NULL, FK a `personal`) y `fecha_hora`. Un trigger exige que el autor sea Técnico y esté activo, y que el hallazgo no sea anterior a la recepción; autor y momento son inmutables. Se agrega `UQ(hallazgo_id, orden_id)` para las FK de contexto.
- **Justificación:** un hallazgo sin autor no puede auditarse ni defenderse ante el cliente.
- **Reglas afectadas:** RN-09.
- **Impacto:** tabla `hallazgo`; trigger `trg_hallazgo_validar`. Los datos del Lab03 se adaptaron agregando autor y momento (ver C-11).
- **Archivos:** `sql/01_esquema.sql`, `sql/02_triggers_integridad.sql`, `sql/07_datos_iniciales.sql`.
- **Prueba actual:** G02-INT-09.

### D2 · Facultades insuficientes
- **Fuente:** Revisión P1 ("identificar a quien responde no demuestra su facultad").
- **Situación anterior:** solo `ORDEN_TRABAJO.autorizador_cliente_id`; nada acreditaba la facultad real para aprobar ni para retirar.
- **Modificación:** nueva relación `facultad_orden` con:
  - el tipo (*Aprobar* / *Retirar*);
  - la fuente (*Titular* / *Designación* / *Representación legal*), el otorgante y el medio de verificación;
  - una vigencia sin traslapes (EXCLUDE) y quién la registró.

  Toda decisión referencia la facultad usada con la FK de contexto `(facultad_id, orden_id)`, y el trigger verifica tipo, cliente y vigencia en `fecha_hora`. La entrega exige una facultad *Retirar* vigente. Para mantener compatibilidad con el alta del Lab03, `trg_orden_despues_insertar` crea automáticamente las facultades del titular y la designación del autorizador.
- **Justificación:** separa *quién es* el cliente de *qué puede hacer* en esa visita, que es lo que pide la revisión.
- **Reglas afectadas:** RN-04, RN-11, RN-20.
- **Impacto:** nueva tabla; columnas `autorizacion_labor.facultad_id` y `entrega.facultad_id`; triggers `trg_facultad_validar`, `trg_autorizacion_validar` y `trg_entrega_validar`.
- **Archivos:** `sql/01_esquema.sql`, `sql/02_triggers_integridad.sql`, `sql/03_rutinas_p01.sql`.
- **Prueba actual:** G02-P01-I-01, G02-P01-I-07, G02-INT-07, G02-INT-16.

### D3 · Garantía y reclamo mezclados
- **Fuente:** Revisión P1.
- **Situación anterior:** `GARANTIA_RECLAMO(reclamo_id, orden_nueva_id, labor_anterior_id, periodo_garantia_dias, kilometraje_garantia, …)`: la garantía solo existía si había reclamo.
- **Modificación:**
  - `garantia`: otorgada al entregar, por labor *Completada* de esa orden; exige al menos uno de los límites (días o km).
  - `reclamo_garantia`: posterior a la entrega; abre una orden nueva distinta y del mismo VIN. Solo puede quedar *Aceptada* (o *Pendiente*) dentro de **ambos** límites, porque vence lo que ocurra primero. Fuera de límite solo puede registrarse *Rechazada*, con justificación.
- **Justificación:** la garantía es un hecho de la entrega; el reclamo es un hecho posterior y opcional.
- **Reglas afectadas:** RN-21, RN-22.
- **Impacto:** dos tablas; triggers `trg_garantia_validar` y `trg_reclamo_validar`.
- **Archivos:** `sql/01_esquema.sql`, `sql/02_triggers_integridad.sql`.
- **Prueba actual:** G02-INT-17, G02-INT-18.

### D4 · Fecha prometida sobrescrita sin historia
- **Fuente:** Lab03 (demostrado: `UPDATE orden_trabajo SET fecha_prometida_actual = …` se aceptaba sin dejar rastro).
- **Situación anterior:** `fecha_prometida_actual` (y el estado) podían cambiarse con un UPDATE directo, sin historial.
- **Modificación:** el valor actual y su historial se confirman juntos. La única vía de cambio es insertar en `historial_fecha_prometida` o en `historial_orden`, por las rutinas `fn_cambiar_fecha_prometida` / `fn_cambiar_estado_orden` o "a mano"; el trigger AFTER INSERT actualiza el valor actual en la misma transacción. `trg_orden_antes_actualizar` rechaza el UPDATE directo, y el constraint trigger diferido `trg_orden_coherencia` verifica al COMMIT que el valor actual sea igual a la última fila del historial. Se agrega `orden_trabajo.estado_actual`.
- **Justificación:** elimina la pérdida de historia que el Lab03 permitía.
- **Reglas afectadas:** RN-07, RN-08.
- **Impacto:** tablas `orden_trabajo`, `historial_orden` y `historial_fecha_prometida`; cuatro triggers.
- **Archivos:** `sql/01_esquema.sql`, `sql/02_triggers_integridad.sql`, `sql/05_rutinas_p03.sql`.
- **Prueba actual:** G02-P03-I-04 (el UPDATE directo ahora falla), G02-P03-A-02, G02-INT-20.

### D5 · Rótulos incorrectos de Q02 y Q04
- **Fuente:** Lab03.
- **Situación anterior:** el README del Lab03 rotulaba Q02 como "Visitas facturables por cliente" y Q04 como "Vehículos con visitas repetidas", pero la lógica de Q02 cuenta **visitas por vehículo** y la de Q04 **órdenes por estado**.
- **Modificación:** **solo** se corrigen el rótulo, el nombre de la vista y el comentario: `v_q02_visitas_por_vehiculo` ("VISITAS POR VEHÍCULO") y `v_q04_conteo_ordenes_por_estado` ("CONTEO DE ÓRDENES POR ESTADO"). El texto SQL de las consultas es idéntico al del Lab03.
- **Justificación:** la lógica era válida; el error estaba en la descripción.
- **Reglas afectadas:** —
- **Impacto:** vistas Q01–Q04.
- **Archivos:** `sql/06_vistas_consultas.sql`.
- **Prueba actual:** G02-INT-19.

### D6 · La labor estaba atada a una propuesta
- **Fuente:** Diseño P1.
- **Situación anterior:** `LABOR.propuesta_id` impedía comparar una misma labor entre versiones con distinto precio.
- **Modificación:** `labor` pasa a ser el trabajo estable de la orden y su precio y alcance en cada versión pasan a `linea_propuesta` (componente de versión). `repuesto_propuesto` cuelga de la línea. Con eso se define la **regla de decisión aplicable** (README §6.1).
- **Justificación:** permite versiones sin pérdida y decisiones por versión que no se arrastran.
- **Reglas afectadas:** RN-10, RN-11.
- **Impacto:** tablas `labor`, `linea_propuesta` y `repuesto_propuesto`; vistas `v_version_vigente_labor`, `v_situacion_labor` y `v_comparacion_versiones`.
- **Archivos:** `sql/01_esquema.sql`, `sql/03_rutinas_p01.sql`, `sql/06_vistas_consultas.sql`.
- **Prueba actual:** G02-P01-V-04, G02-P01-L-01, G02-P01-L-05.

### D7 · Dependencia única entre labores
- **Fuente:** Diseño P1.
- **Situación anterior:** `labor_previa_id`: una labor solo podía depender de otra.
- **Modificación:** relación N:M recursiva `labor_dependencia` con FK de contexto a la misma orden, CHECK contra la autodependencia y trigger anti-ciclos (CTE recursiva). Iniciar una labor exige que todas sus dependencias estén completadas.
- **Justificación:** el caso admite varias dependencias.
- **Reglas afectadas:** RN-15.
- **Impacto:** nueva tabla; `trg_dependencia_sin_ciclos`; `trg_historial_labor_antes`.
- **Archivos:** `sql/01_esquema.sql`, `sql/02_triggers_integridad.sql`, `sql/03_rutinas_p01.sql` (dependencias en el JSON de la versión).
- **Prueba actual:** G02-INT-15, G02-P02-I-02, G02-P02-L-04.

### D8 · La emergencia era un texto dentro de LABOR
- **Fuente:** Diseño P1.
- **Situación anterior:** `LABOR.emergencia_justificacion` no identificaba quién ni cuándo, ni limitaba el alcance.
- **Modificación:** nueva relación `excepcion_emergencia` (una por labor) con riesgo, justificación de al menos 20 caracteres, alcance mínimo, quién la autorizó y cuándo. Solo se admite sobre una labor marcada `es_emergencia` y **habilita solo esa labor**, nunca la propuesta.
- **Justificación:** evita que una urgencia se convierta en autorización general.
- **Reglas afectadas:** RN-12.
- **Impacto:** nueva tabla; `fn_registrar_emergencia`; FK `(emergencia_id, labor_id)` desde `historial_labor`.
- **Archivos:** `sql/01_esquema.sql`, `sql/02_triggers_integridad.sql`, `sql/04_rutinas_p02.sql`.
- **Prueba actual:** G02-P02-L-02.

### D9 · Sin historial de estados de la labor
- **Fuente:** Diseño P1.
- **Situación anterior:** solo `LABOR.estado_labor`, sin historia ni vínculo con lo que habilitó la ejecución.
- **Modificación:** nueva relación `historial_labor` con secuencia, responsable, motivo y **exactamente un habilitante** (`autorizacion_id` o `emergencia_id`) al pasar a *En proceso* (CHECK). El trigger verifica que la autorización sea **la aplicable y Aceptada**. `labor.estado_labor` se sincroniza igual que en D4.
- **Justificación:** permite saber, para cada ejecución, qué decisión la autorizó.
- **Reglas afectadas:** RN-11, RN-12, RN-15.
- **Impacto:** nueva tabla; dos triggers.
- **Archivos:** `sql/01_esquema.sql`, `sql/02_triggers_integridad.sql`, `sql/04_rutinas_p02.sql`.
- **Prueba actual:** G02-P02-V-01, G02-P02-I-01, G02-P02-L-05, G02-INT-20.

### D10 · La prueba no tenía resultado categórico
- **Fuente:** Diseño P1.
- **Situación anterior:** `PRUEBA.medicion` y `PRUEBA.resultado` como texto libre.
- **Modificación:**
  - `resultado` ∈ {Favorable, Desfavorable, No concluyente};
  - `medicion_valor` numérico y `unidad` opcionales, pero siempre juntos (CHECK);
  - `descripcion_resultado` obligatoria;
  - la tabla es de solo inserción.
- **Justificación:** el resultado categórico es el que decide si hace falta un retrabajo y si la labor puede completarse.
- **Reglas afectadas:** RN-16.
- **Impacto:** tabla `prueba`; regla de completado.
- **Archivos:** `sql/01_esquema.sql`, `sql/02_triggers_integridad.sql`.
- **Prueba actual:** G02-P02-I-11, G02-P02-L-01.

### D11 · Movimientos sin origen
- **Fuente:** Diseño P1.
- **Situación anterior:** `MOVIMIENTO_INVENTARIO` sin vínculo con el consumo y sin control de existencias.
- **Modificación:**
  - `consumo_id` UNIQUE, con FK de contexto `(consumo_id, repuesto_id, orden_id)` y CHECK de que todo *Consumo* tenga origen;
  - constraint trigger diferido: todo consumo tiene su movimiento por la misma cantidad;
  - trigger que bloquea el repuesto y rechaza existencias físicas o disponibles negativas;
  - existencias derivadas en `v_existencias`.
- **Justificación:** no queda un consumo sin movimiento ni un movimiento sin origen, y el stock no puede quedar negativo, ni siquiera con concurrencia.
- **Reglas afectadas:** RN-18, RN-19.
- **Impacto:** tablas `movimiento_inventario` y `consumo_repuesto`; `fn_registrar_consumo`.
- **Archivos:** `sql/01_esquema.sql`, `sql/02_triggers_integridad.sql`, `sql/04_rutinas_p02.sql`, `sql/06_vistas_consultas.sql`.
- **Prueba actual:** G02-P02-I-06, G02-P02-A-03, G02-INT-12, G02-P02-C2.

### D12 · Sin propietario histórico del vehículo
- **Fuente:** Caso ("cambios de propietario no reescriben visitas").
- **Situación anterior:** el vehículo no tenía propietario ni vigencias.
- **Modificación:** nueva relación `propiedad_vehiculo` con vigencias sin traslapes (EXCLUDE). Los roles de cada visita (factura, entrega, autoriza, recibe) quedan **fijados** en la orden: `trg_orden_antes_actualizar` rechaza reescribirlos.
- **Justificación:** el propietario actual no debe alterar el registro de visitas pasadas.
- **Reglas afectadas:** RN-02, RN-04.
- **Impacto:** nueva tabla; trigger de orden.
- **Archivos:** `sql/01_esquema.sql`, `sql/02_triggers_integridad.sql`.
- **Prueba actual:** G02-INT-05.

---

## Parte B — Otros cambios de implementación

| ID | Fuente | Situación anterior | Modificación | Justificación | Reglas | Impacto / archivos | Prueba |
|---|---|---|---|---|---|---|---|
| C-01 | Instrucciones §4.1 | Tablas en `public` (Lab03) | Esquema `taller`; `SET search_path` en cada script | Aislar el proyecto y poder reiniciarlo sin tocar otros objetos | — | Todos los `sql/*.sql` | run_all |
| C-02 | Instrucciones §4.1 / Lab03 | PK `INTEGER` con IDs explícitos (Lab03) | `IDENTITY BY DEFAULT`; se mantiene **`integer`** en las relaciones heredadas del Lab03 (cliente, personal, orden, hallazgo) y sus FK, y se usa `bigint` en las nuevas | Las rutinas del Lab03 reciben `INTEGER` y se reutilizan sin modificar; BY DEFAULT permite IDs fijos legibles (las instrucciones sugerían ALWAYS) | — | `01_esquema.sql`, `07_datos_iniciales.sql` | G02-INT-06 (alta del Lab03) |
| C-03 | Instrucciones §4.1 | `TIMESTAMP` (Lab03) | `timestamptz` en todos los momentos; zona `America/Costa_Rica` en los scripts | Momentos inequívocos | RN-07, RN-08 | Todos | — |
| C-04 | Diseño P1 | `vin` solo con `CHAR_LENGTH = 17`; `anio` ≤ 2027 fijo | Regex ISO 3779; `anio` ≤ año actual + 1 por trigger | El tope fijo del Lab03 caducaba en 2028 | RN-02 | `01`, `02` | G02-INT-03 |
| C-05 | RN-02 | La orden no guardaba la placa | `orden_trabajo.placa_ingreso`, completada por trigger si no se indica | La placa cambia y la visita conserva la de ese día | RN-02 | `01`, `02` | G02-INT-04 |
| C-06 | RN-01 | Un vehículo podía tener varias visitas abiertas | Índice único parcial `uq_orden_abierta_por_vehiculo` | Una visita a la vez | RN-01 | `01` | G02-INT-06 |
| C-07 | RN-03 (P1 sin mecanismo) | Sin validación de contactos | CHECK de formato + constraint trigger diferido | RN-03 | RN-03 | `01`, `02` | G02-INT-02 |
| C-08 | Diseño P1 | `PERSONAL` sin estado | `personal.activo`; el personal inactivo no actúa | Validaciones de rol y de actividad | RN-13, RN-14 | `01`, `02` | G02-P02-I-04 |
| C-09 | Ambigüedad P1 | Proveedor como texto | Relación `proveedor`; `proveedor_repuesto.proveedor_id` | Identidad del proveedor; `UQ(proveedor, código)` | RN-17 | `01` | G02-INT-11 |
| C-10 | Instrucciones §4.2-15 | Transiciones implícitas | Catálogo `transicion_estado_orden` (18 pares, 6 retrocesos con motivo; estados terminales sin salida) | Secuencia no lineal explícita | RN-08 | `01`, `02` | G02-P03-I-06, G02-P03-L-04 |
| C-11 | Lab03 + Instrucciones §1 (prohibido precargar resultados) | `02_datos.sql` del Lab03 cargaba órdenes con estados avanzados (En reparación, Autorizada, Cancelada) y hallazgos sin autor | **Adaptación mínima de los datos:** se conservan los mismos clientes, vehículos y personal (IDs 101–105, 201–203 y los 4 VIN); las órdenes quedan solo en 'Recibida' y los hallazgos llevan autor. Se agregan contextos válidos distintos | Los cambios de estado son resultado de P03 y no pueden precargarse; D1 exige autor | RN-08, RN-09 | `07_datos_iniciales.sql` | Todas |
| C-12 | Instrucciones §4.2-28 | `Ajuste` con signo ambiguo | `Ajuste positivo` / `Ajuste negativo` con motivo obligatorio; la cantidad siempre es > 0 | El signo lo da el tipo | RN-19 | `01`, `02` | G02-INT-12 |
| C-13 | Diseño (A-11) | Los estados de la orden no dependían de los hechos | Pendiente autorización, Autorizada, Lista entrega y Entregada exigen el hecho que las justifica; salir de Recibida exige objetos confirmados | Coherencia entre estado y datos | RN-06, RN-08 | `02` | G02-P03-V-01, G02-P03-I-05, G02-INT-16 |
| C-14 | Diseño (A-09) | — | La decisión solo puede registrarse sobre la versión vigente de la labor | Una decisión sobre una versión obsoleta sería inaplicable | RN-11 | `02` | G02-P01-I-05 |
| C-15 | Diseño (A-13) | — | `km_reclamo` = km de ingreso de la orden nueva | Un solo dato del kilometraje del vehículo al reclamar | RN-22 | `02` | G02-INT-18 |
| C-16 | CI del curso | Instrucciones §8.1 pedían `resultados/*.txt` | Salidas en `resultados/*.md` (texto dentro de bloques de código) | La validación del curso solo admite `.md`, `.sql`, `.pdf` e imágenes | — | `resultados/` | — |
| C-17 | Diseño | Sin coherencia temporal en la ejecución | La participación no puede iniciar antes de que la labor pasara a En proceso; las decisiones no pueden ser anteriores a la presentación ni a la última decisión de su línea | Momentos coherentes | RN-11, RN-13 | `02` | G02-P02-I-04, G02-P01-I-06 |

---

## Parte C — Reutilización sin modificación

| Archivo de origen (rama `lab03-grupo02-entrega` de `jimena-perez/bd1-2026-2s`) | Archivo destino | Qué se reutiliza | Por qué es válido tal cual |
|---|---|---|---|
| `lab03/grupo-02/sql/04_rutinas.sql` | `sql/08_rutinas_lab03.sql` | `fn_total_ordenes_cliente`, `fn_prioridad_orden`, **`sp_registrar_orden`** (alta con historial inicial) y la demostración de la tabla temporal. **El cuerpo es idéntico**; solo se agregó un encabezado con `SET search_path = taller, public` y la zona horaria. | Las tablas conservan los nombres y tipos (`integer`) que usan las rutinas. `historial_orden` conserva la columna `estado`. Los triggers completan lo nuevo sin cambiar la firma: `placa_ingreso`, la secuencia 1 del estado inicial y las facultades de la visita (D2). Probado en G02-INT-06 (orden 9901 y rechazo de km negativo). |
| `lab03/grupo-02/sql/03_consultas.sql` (Q01–Q04) | `sql/06_vistas_consultas.sql` (`v_q01…v_q04`) | El texto SQL de las 4 consultas, idéntico, ahora envuelto en vistas. | Las columnas usadas (`historial_orden.estado`, `fecha_hora`, `historial_id`) se mantienen. Solo cambian los rótulos de Q02 y Q04 (D5). Probado en G02-INT-19. |
| `lab03/grupo-02/sql/02_datos.sql` (identidades) | `sql/07_datos_iniciales.sql` | Clientes 101–105, vehículos de los 4 VIN, personal 201–203. | Son datos maestros válidos. Las órdenes y hallazgos se adaptaron (C-11). |
| `lab03/grupo-02/sql/01_esquema.sql` | `sql/01_esquema.sql` | Las 6 tablas del Lab03 (cliente, vehículo, personal, orden, historial, hallazgo) con sus nombres y columnas. | Ampliadas, no reescritas (ver D1, D4, C-02…C-05); el índice `idx_historial_orden_ultimo` se conserva. |

> La carpeta `lab03/` y el PR del Lab03 **no se modificaron**: este proyecto vive en otro repositorio (`jimena-perez/Bases-IIFase`) y el Lab03 se leyó en modo solo lectura.
>
> Nota de la demostración heredada: con los datos nuevos, `fn_prioridad_orden(9005)` ya no devuelve "Sin hallazgos" como en el Lab03, porque la orden 9005 ahora tiene un hallazgo. La función es la misma; lo que cambió son los datos.
