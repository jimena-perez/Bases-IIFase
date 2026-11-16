# Correspondencia: relaciones del Proyecto 1 → relaciones actuales

**IC-4301 · Proyecto 2 · Grupo 02 · Taller Ruta 27**

Las **23 relaciones** del modelo lógico del Proyecto 1 (§7.1) tienen correspondencia en el modelo actual. Ninguna se eliminó: se mantienen, se modifican, se dividen o se renombran, y se agregan relaciones nuevas cuando una regla del caso no tenía dónde vivir. Cada cambio está en [`../Control_de_Cambios.md`](../Control_de_Cambios.md).

Leyenda: **Igual** (mismo contenido, solo diseño físico) · **Modificada** (se agregan o cambian atributos o restricciones) · **Dividida** (una relación P1 se reparte en varias) · **Renombrada** · **Reemplazada**.

## 1. Las 23 relaciones del P1

| # | Relación P1 | Relación(es) actual(es) | Tipo | Justificación |
|---:|---|---|---|---|
| 1 | CLIENTE | `cliente` | Igual | Mismos atributos; dominio de `tipo_cliente` como CHECK. SD-02 del P1 se mantiene: quien entrega, aprueba o retira se registra aquí. |
| 2 | CONTACTO_CLIENTE | `contacto_cliente` | Modificada | CHECK de formato según el tipo (teléfono o correo), UQ por cliente y valor, y constraint trigger **diferido** que exige ≥1 contacto con `recibe_avisos` al COMMIT (RN-03, que en el P1 no tenía mecanismo). |
| 3 | VEHICULO | `vehiculo` + `propiedad_vehiculo` (nueva) | Modificada | VIN validado con regex ISO 3779 y no reescribible; `anio` ≤ año actual + 1 por trigger. La propiedad histórica pasa a `propiedad_vehiculo` (D12). |
| 4 | PERSONAL | `personal` | Modificada | Se agrega `activo`: el personal inactivo no participa, no registra cambios ni diagnostica. |
| 5 | ORDEN_TRABAJO | `orden_trabajo` + `facultad_orden` (nueva) | Modificada | Se agregan `placa_ingreso` (instantánea de la placa al ingresar, RN-02) y `estado_actual` (valor vigente sincronizado con el historial). Datos de recepción y roles fijados por visita. `autorizador_cliente_id` se conserva por compatibilidad con el alta del Lab03, pero la facultad real se registra en `facultad_orden` (D2). Índice único parcial: una sola visita abierta por vehículo. |
| 6 | OBJETO_DANO | `objeto_dano` | Modificada | Solo admite confirmarse (de `false` a `true`) y no se borra. Regla RN-06: la orden no sale de 'Recibida' con objetos sin confirmar. |
| 7 | HISTORIAL_ORDEN | `historial_orden` + `transicion_estado_orden` (nueva) | Modificada | Se agregan `secuencia`, `estado_anterior` y `motivo`; solo inserción; la columna `estado` (estado nuevo) conserva el nombre del Lab03. Las transiciones permitidas, no lineales, pasan a un catálogo. |
| 8 | HISTORIAL_FECHA_PROMETIDA | `historial_fecha_prometida` | Modificada | Se agregan `secuencia`, `fecha_anterior`, `medio_comunicacion` y `registrado_en`; la primera fila es la promesa original y toda reprogramación exige motivo. Solo inserción (corrige D4). |
| 9 | HALLAZGO | `hallazgo` | Modificada | Se agregan `diagnosticado_por_id` (técnico) y `fecha_hora` (D1); `UQ(hallazgo_id, orden_id)` para las FK de contexto. |
| 10 | PROPUESTA | `propuesta` | Modificada | Se agregan `estado` (Borrador/Presentada), `propuesta_base_id` (versión que amplía), `presentada_por_id` y `fecha_hora_presentacion`. Se mantiene `UQ(orden_id, version)`. Una versión presentada es inmutable. |
| 11 | LABOR | `labor` + `linea_propuesta` (nueva) + `labor_dependencia` (nueva) + `excepcion_emergencia` (nueva) + `historial_labor` (nueva) | Dividida | `labor` es el trabajo estable de la orden. Su precio en cada versión pasa a `linea_propuesta` (D6), `labor_previa_id` pasa a la relación N:M `labor_dependencia` (D7), `emergencia_justificacion` pasa a `excepcion_emergencia` (D8) y los estados quedan en `historial_labor` (D9). `labor_revisada_id` se mantiene y se agrega `prueba_origen_id`. |
| 12 | AUTORIZACION_LABOR | `autorizacion_labor` | Modificada | La decisión es por **línea de versión**: `(propuesta_id, labor_id)`. Referencia la facultad usada (`facultad_id`) y quién la registró. Solo inserción. |
| 13 | PARTICIPACION_TECNICA | `participacion_tecnica` | Modificada | `minutos_dedicados` se renombra a `minutos_efectivos` (puede ser menor que el intervalo, nunca mayor: CHECK). Se agregan `especialidad_id` (de ese mismo técnico) y `orden_id` (FK de contexto). El técnico debe tener rol Técnico y estar activo, y no puede traslapar participaciones. |
| 14 | ESPECIALIDAD_TECNICO | `especialidad_tecnico` | Modificada | EXCLUDE sin traslapes para la misma especialidad; `fecha_fin ≥ fecha_inicio`; solo personal con rol Técnico. |
| 15 | PRUEBA | `prueba` | Modificada | `resultado` categórico (Favorable / Desfavorable / No concluyente) y medición opcional con valor y unidad, siempre juntos; `descripcion_resultado` obligatoria (D10). Solo inserción. |
| 16 | REPUESTO | `repuesto` | Igual | Código interno de texto con formato; dominio de `unidad_manejo`. |
| 17 | PROVEEDOR_REPUESTO | `proveedor` (nueva) + `proveedor_repuesto` | Dividida | El nombre del proveedor pasa a la relación `proveedor`; `proveedor_repuesto` referencia `proveedor_id` con `UQ(proveedor_id, codigo_proveedor)` (RN-17). No hay flujo de compras. |
| 18 | REPUESTO_PROPUESTO | `repuesto_propuesto` | Modificada | Ahora es por línea de versión: `(propuesta_id, labor_id, repuesto_id)`, para que lo estimado cambie con la versión (RN-18). |
| 19 | CONSUMO_REPUESTO | `consumo_repuesto` | Modificada | Se agregan `orden_id` (FK de contexto), `fecha_hora` y `registrado_por_id`. Al COMMIT debe tener exactamente su movimiento de Consumo. |
| 20 | MOVIMIENTO_INVENTARIO | `movimiento_inventario` | Modificada | Se agregan `consumo_id` (origen, D11), `registrado_por_id` y `motivo`. `Ajuste` se divide en `Ajuste positivo` y `Ajuste negativo`. Las existencias físicas y disponibles nunca son negativas (trigger con bloqueo del repuesto). |
| 21 | PIEZA_RETIRADA | `pieza_retirada` | Modificada | Se agregan `orden_id` (FK de contexto) y `registrado_por_id`; solo de labores en ejecución o completadas. |
| 22 | ENTREGA | `entrega` | Modificada | Se agregan `facultad_id` (facultad *Retirar* vigente, D2) y `entregado_por_id`. Reglas: km de salida ≥ km de ingreso, orden en 'Lista entrega', máximo una por orden. |
| 23 | GARANTIA_RECLAMO | `garantia` (nueva) + `reclamo_garantia` | Dividida / Reemplazada | La garantía se otorga al entregar, por labor, y existe aunque nunca haya reclamo; el reclamo es posterior, abre una orden nueva del mismo VIN y respeta "vence lo primero" (D3, RN-21, RN-22). |

## 2. Relaciones nuevas (no existían en el P1)

| Relación nueva | Origen | Qué situación del caso cubre |
|---|---|---|
| `propiedad_vehiculo` | D12 | "Los cambios de propietario no reescriben visitas": propietarios con vigencias sin traslapes. |
| `proveedor` | Ambigüedad del P1 | Identidad del proveedor (antes era solo texto). |
| `facultad_orden` | D2 (revisión P1) | Facultad real de aprobar o retirar, por visita, con fuente, verificación y vigencia. |
| `transicion_estado_orden` | §4.2-15 (catálogo) | Secuencia de estados no lineal, con retrocesos que exigen motivo. |
| `linea_propuesta` | D6 | La labor dentro de cada versión, con su precio y alcance. |
| `excepcion_emergencia` | D8 | Emergencia justificada que habilita solo su labor (RN-12). |
| `labor_dependencia` | D7 | Una labor puede depender de varias (N:M), sin ciclos (RN-15). |
| `historial_labor` | D9 | Estados de la labor con la autorización o emergencia que habilitó su ejecución. |
| `garantia` | D3 | Garantía otorgada al entregar, por labor. |

**Total:** 23 relaciones P1 (2 iguales, 18 modificadas, 3 divididas o reemplazadas) + 9 relaciones nuevas = **32 relaciones actuales**.
