# Matriz regla → mecanismo → prueba (modelo completo)

**IC-4301 · Proyecto 2 · Grupo 02 · Taller Ruta 27**

Una fila por regla verificable. Las 32 relaciones tienen al menos una prueba. En la columna *Observado*, ✔ significa que la prueba se ejecutó **de verdad desde una base nueva** y dio el resultado esperado. El SQLSTATE y el mensaje exactos de cada fila están en [`../resultados/evidencias_observadas.md`](../resultados/evidencias_observadas.md), buscando por el ID de la prueba.

Mecanismos: `PK`, `FK`, `FK ctx` (FK compuesta de contexto), `UQ`, `CHECK`, `DOMAIN`, `EXCLUDE`, `TRG` (trigger BEFORE/AFTER), `CTRG` (constraint trigger **diferido**, se evalúa al COMMIT), `FN` (rutina), `IDX` (índice único parcial).

## Identidad y roles

| Relación | Regla | Mecanismo | Prueba (ID) | Esperado | Observado |
|---|---|---|---|---|---|
| cliente | Identificación única | `UQ uq_cliente_identificacion` | G02-INT-01 | Rechazo | ✔ |
| cliente | Tipo Persona/Organización; nombre no vacío | `CHECK ck_cliente_tipo`, `ck_cliente_nombre` | G02-INT-01 | Rechazo | ✔ |
| contacto_cliente | ≥ 1 contacto apto para avisos por cliente (RN-03) | `CTRG trg_cliente_contacto_avisos`, `trg_contacto_avisos` | G02-INT-02 (3 casos, incluido quitar el único apto) | Rechazo al COMMIT | ✔ |
| contacto_cliente | Formato según el tipo (correo / teléfono) | `CHECK ck_contacto_formato` | G02-INT-02 | Rechazo | ✔ |
| contacto_cliente | Cliente y contacto en la misma transacción | `CTRG` diferido | G02-INT-02 (cliente 109) | Válido | ✔ |
| vehiculo | VIN ISO 3779 (17 caracteres, sin I/O/Q) | `CHECK ck_vehiculo_vin` | G02-INT-03 | Rechazo | ✔ |
| vehiculo | Año ≤ año actual + 1 | `TRG trg_vehiculo_anio` | G02-INT-03 | Rechazo | ✔ |
| vehiculo | El VIN no se reescribe (RN-02) | `TRG trg_vehiculo_vin_estable` | G02-INT-03 | Rechazo | ✔ |
| vehiculo / orden_trabajo | La placa cambia sin afectar visitas previas | `orden_trabajo.placa_ingreso` + `TRG trg_orden_antes_insertar` | G02-INT-04 | Válido; placa_ingreso intacta | ✔ |
| propiedad_vehiculo | Un propietario por periodo | `EXCLUDE ex_propiedad_sin_traslape` | G02-INT-05 | Rechazo | ✔ |
| propiedad_vehiculo / orden_trabajo | El cambio de propietario no reescribe visitas (D12) | `TRG trg_orden_antes_actualizar` (roles fijados) | G02-INT-05 | Rechazo; factura intacta | ✔ |
| personal | Rol del dominio; activo | `CHECK ck_personal_rol`; `FN fn_exigir_personal` | G02-P03-I-07, G02-P02-I-04 | Rechazo de personal inactivo | ✔ |
| personal | No deja de ser Técnico con especialidades vigentes | `TRG trg_personal_rol_estable` | G02-INT-10 | Rechazo | ✔ |
| especialidad_tecnico | Sin traslapes de la misma especialidad | `EXCLUDE ex_especialidad_sin_traslape` | G02-INT-10 | Rechazo; renovación sin traslape válida | ✔ |
| especialidad_tecnico | Solo para rol Técnico; fin ≥ inicio | `TRG trg_especialidad_tecnico`; `CHECK ck_especialidad_vigencia` | G02-INT-10 | Rechazo | ✔ |
| orden_trabajo | Una visita abierta por vehículo (RN-01) | `IDX uq_orden_abierta_por_vehiculo` | G02-INT-06 | Rechazo | ✔ |
| orden_trabajo | Km ≥ 0, combustible del dominio, motivo obligatorio (RN-05) | `CHECK ck_orden_km_ingreso`, `ck_orden_combustible`, `ck_orden_motivo` | G02-INT-06 | Rechazo | ✔ |
| orden_trabajo | Nace en Recibida con su estado inicial en el historial | `TRG trg_orden_antes_insertar`; `CTRG trg_orden_coherencia` | G02-INT-06 | Rechazo (al COMMIT) | ✔ |
| orden_trabajo | Datos de recepción y roles fijados por visita (RN-04/05) | `TRG trg_orden_antes_actualizar` | G02-INT-06, G02-INT-05 | Rechazo | ✔ |
| orden_trabajo | No se borra (cancelar no borra) | `TRG trg_orden_sin_borrado` | G02-P03-L-02 | Rechazo | ✔ |
| orden_trabajo | Alta del Lab03 reutilizada sin modificar | `sp_registrar_orden` + `TRG` de compatibilidad | G02-INT-06 (orden 9901) | Válido: placa, historial secuencia 1, 2 facultades | ✔ |
| facultad_orden | Solo el titular designa o se hace representar (D2) | `TRG trg_facultad_validar` | G02-INT-07 | Rechazo | ✔ |
| facultad_orden | Sin facultades duplicadas vigentes | `EXCLUDE ex_facultad_sin_traslape` | G02-INT-07 | Rechazo | ✔ |
| facultad_orden | Titular sin otorgante; designación con otorgante | `CHECK ck_facultad_otorgante` | G02-INT-07 | Rechazo | ✔ |
| facultad_orden | Vigencia no anterior a la recepción; solo revocación, una vez; no se borra | `TRG trg_facultad_validar` | G02-INT-07, G02-P01-I-07 | Rechazo | ✔ |
| objeto_dano | Solo se confirma; no se borra (RN-06) | `TRG trg_objeto_dano_validar` | G02-INT-08 | Rechazo | ✔ |
| objeto_dano / historial_orden | No sale de Recibida con objetos sin confirmar | `TRG trg_historial_orden_antes` | G02-P03-I-05 | Rechazo | ✔ |

## Autoría, diagnóstico y propuesta

| Relación | Regla | Mecanismo | Prueba (ID) | Esperado | Observado |
|---|---|---|---|---|---|
| hallazgo | Autor obligatorio (D1) | `NOT NULL diagnosticado_por_id` | G02-INT-09 | Rechazo | ✔ |
| hallazgo | El autor es un técnico activo; no anterior a la recepción; autor y momento inmutables | `TRG trg_hallazgo_validar` | G02-INT-09 | Rechazo | ✔ |
| hallazgo | Urgencia del dominio | `CHECK ck_hallazgo_urgencia` | G02-INT-09 | Rechazo | ✔ |
| propuesta | Versión consecutiva bajo bloqueo, sin huecos | `TRG trg_propuesta_validar` + `UQ uq_propuesta_version` | G02-P01-I-08, G02-P01-A-01, G02-P01-C1 | Rechazo; v5 sin huecos | ✔ |
| propuesta | Se crea en Borrador; Presentada es inmutable (RN-10) | `TRG trg_propuesta_validar` | G02-P01-I-04, G02-P01-I-08 | Rechazo | ✔ |
| propuesta | La versión base es de la misma orden | `FK ctx fk_propuesta_base` | G02-P01-I-08 | Rechazo | ✔ |
| labor | Hallazgo de la misma orden | `FK ctx fk_labor_hallazgo` + `FN` | G02-P01-I-08, G02-P01-A-02 | Rechazo | ✔ |
| labor | No se reescribe ni se borra (RN-15); estado solo vía historial (D9) | `TRG trg_labor_validar` | G02-P02-I-10 | Rechazo | ✔ |
| labor | El retrabajo nace de una prueba Desfavorable de la labor revisada | `FK ctx fk_labor_prueba_origen` + `TRG` | G02-P02-I-11 | Rechazo | ✔ |
| linea_propuesta | Propuesta y labor de la misma orden (D6) | `FK ctx fk_linea_propuesta`, `fk_linea_labor` | G02-P01-I-02 | Rechazo | ✔ |
| linea_propuesta | Precio ≥ 0; sin labor repetida en una versión | `CHECK ck_linea_precio`; `PK`; `FN` | G02-P01-A-01, G02-P01-I-08 | Rechazo sin efectos | ✔ |
| linea_propuesta / repuesto_propuesto | Inmutables si la versión está presentada | `TRG trg_linea_validar`, `trg_repuesto_propuesto_validar` | G02-P01-I-04 | Rechazo | ✔ |
| repuesto_propuesto | Repuesto existente; cantidad > 0 | `FK fk_rep_prop_repuesto`; `CHECK` | G02-P01-A-03 | Rechazo sin efectos | ✔ |
| autorizacion_labor | Facultad Aprobar vigente del mismo cliente en esa orden (D2) | `TRG trg_autorizacion_validar` + `FK ctx fk_autorizacion_facultad` | G02-P01-I-01, G02-P01-I-07 | Rechazo (también sin el trigger) | ✔ |
| autorizacion_labor | Línea de esa versión y orden | `FK ctx fk_autorizacion_linea` | G02-P01-I-02, G02-P01-I-03 | Rechazo (también sin el trigger) | ✔ |
| autorizacion_labor | Solo sobre la versión vigente; no antes de la presentación ni de la última decisión | `TRG trg_autorizacion_validar` | G02-P01-I-05, G02-P01-I-06 | Rechazo | ✔ |
| autorizacion_labor | Solo inserción (RN-11) | `TRG trg_autorizacion_inmutable` | G02-P01-I-04 | Rechazo | ✔ |
| autorizacion_labor | Decisión y medio del dominio | `CHECK ck_autorizacion_decision`; `DOMAIN d_medio_comunicacion` | G02-P01-I-06 | Rechazo | ✔ |

## Ejecución, repuestos y movimientos

| Relación | Regla | Mecanismo | Prueba (ID) | Esperado | Observado |
|---|---|---|---|---|---|
| historial_labor | Inicio solo con la autorización aplicable Aceptada o con emergencia (RN-11/12) | `TRG trg_historial_labor_antes` + `CHECK ck_historial_labor_habilitante` | G02-P02-I-01, G02-P01-L-05 | Rechazo | ✔ |
| historial_labor | La autorización o emergencia citada es de esa labor | `FK ctx fk_historial_labor_autorizacion`, `fk_historial_labor_emergencia` | G02-P02-I-01, G02-P02-L-02 | Rechazo (también sin el trigger) | ✔ |
| historial_labor | Dependencias completadas antes de iniciar (RN-15) | `TRG` | G02-P02-I-02, G02-P02-L-04 | Rechazo; luego válido | ✔ |
| historial_labor | Transiciones de labor; motivo para suspender o anular | `TRG` | G02-P02-L-05 | Rechazo sin motivo | ✔ |
| historial_labor | Completar: participación cerrada, ninguna abierta, prueba Desfavorable solo con retrabajo completado | `TRG` | G02-P02-I-07, G02-P02-L-04, G02-P02-A-02 | Rechazo | ✔ |
| excepcion_emergencia | Solo sobre una labor de emergencia; justificación ≥ 20 caracteres; habilita solo su labor (D8) | `TRG trg_emergencia_validar`; `CHECK ck_emergencia_justificacion`; `UQ uq_emergencia_labor` | G02-P02-L-02 | Rechazo; la otra labor no se habilita | ✔ |
| labor_dependencia | Sin ciclos; de la misma orden; no consigo misma (D7) | `TRG trg_dependencia_sin_ciclos`; `FK ctx`; `CHECK` | G02-INT-15 | Rechazo; N:M válido | ✔ |
| participacion_tecnica | Técnico existente, con rol Técnico y activo; labor En proceso; no antes del inicio de la labor | `TRG trg_participacion_validar` | G02-P02-I-03, G02-P02-I-04, G02-P02-I-08 | Rechazo | ✔ |
| participacion_tecnica | Especialidad del mismo técnico y vigente | `FK ctx fk_participacion_especialidad` + `TRG` | G02-P02-I-04 | Rechazo | ✔ |
| participacion_tecnica | Minutos efectivos ≤ intervalo (validación posterior del P1) | `CHECK ck_participacion_minutos` | G02-P02-I-09, G02-P02-L-03 | Rechazo; 75/120 y 120/120 válidos | ✔ |
| participacion_tecnica | Un técnico no está en dos intervenciones a la vez | `EXCLUDE ex_participacion_tecnico` | G02-P02-I-09 | Rechazo | ✔ |
| participacion_tecnica | Solo se cierra, una vez | `TRG` | G02-P02-I-10, G02-P02-L-04 | Rechazo; cierre válido | ✔ |
| prueba | Resultado categórico; medición valor + unidad juntos (D10) | `CHECK ck_prueba_resultado`, `ck_prueba_medicion` | G02-P02-I-11 | Rechazo | ✔ |
| prueba | Solo sobre labor En proceso; solo inserción | `TRG trg_prueba_validar`, `trg_prueba_inmutable` | G02-P02-I-08, G02-P02-I-10 | Rechazo | ✔ |
| consumo_repuesto | Labor de la misma orden | `FK ctx fk_consumo_labor` + `FN` | G02-P02-I-05 | Rechazo | ✔ |
| consumo_repuesto | Siempre con su movimiento de Consumo | `CTRG trg_consumo_con_movimiento` | G02-P02-A-03 | Rechazo al COMMIT | ✔ |
| movimiento_inventario | Existencias físicas y disponibles nunca negativas (RN-19) | `TRG trg_movimiento_validar` (bloquea el repuesto) | G02-P02-I-06, G02-INT-12, G02-P02-C2 | Rechazo; stock final ≥ 0 | ✔ |
| movimiento_inventario | Consumo con origen (D11) y la misma cantidad | `CHECK ck_movimiento_consumo_origen`; `FK ctx fk_movimiento_consumo`; `TRG` | G02-P02-A-03 | Rechazo (también sin el trigger) | ✔ |
| movimiento_inventario | Reserva, liberación y consumo con orden; ajuste con motivo; cantidad > 0; no liberar más de lo reservado | `CHECK`; `TRG` | G02-INT-12 | Rechazo | ✔ |
| movimiento_inventario | Solo inserción | `TRG trg_movimiento_inmutable` | G02-INT-12 | Rechazo | ✔ |
| repuesto | Código interno con formato; unidad del dominio (RN-17) | `CHECK ck_repuesto_codigo`, `ck_repuesto_unidad` | G02-INT-11 | Rechazo | ✔ |
| proveedor | Nombre único | `UQ uq_proveedor_nombre` | G02-INT-11 | Rechazo | ✔ |
| proveedor_repuesto | (proveedor, código) único; precio ≥ 0 (RN-17) | `UQ uq_prov_rep_codigo`; `CHECK` | G02-INT-11 | Rechazo; mismo código en otro proveedor válido | ✔ |
| pieza_retirada | Labor de la misma orden; labor ejecutada; destino del dominio | `FK ctx fk_pieza_labor`; `TRG trg_pieza_validar`; `CHECK ck_pieza_destino` | G02-INT-13 | Rechazo | ✔ |
| (consulta) | Distinguir presupuesto / reserva / consumo / pieza retirada (RN-18) | `v_insumos_orden` | G02-INT-14 | Válido | ✔ |

## Entrega y garantía

| Relación | Regla | Mecanismo | Prueba (ID) | Esperado | Observado |
|---|---|---|---|---|---|
| entrega | Orden en Lista entrega | `TRG trg_entrega_validar` | G02-INT-16 | Rechazo | ✔ |
| entrega | Quien retira tiene facultad Retirar vigente (no Aprobar) | `TRG` + `FK ctx fk_entrega_facultad` | G02-INT-16 | Rechazo | ✔ |
| entrega | Km salida ≥ km ingreso; no antes de la recepción | `TRG` | G02-INT-16 | Rechazo | ✔ |
| entrega | Máximo una por orden | `UQ uq_entrega_orden` | G02-INT-16 | Rechazo | ✔ |
| entrega | Inconforme exige observaciones | `CHECK ck_entrega_inconformidad` | G02-INT-16 | Rechazo | ✔ |
| garantia | Existe sin reclamo; por labor completada de esa orden (D3) | `TRG trg_garantia_validar`; `FK ctx fk_garantia_labor`, `fk_garantia_entrega` | G02-INT-17, G02-INT-18 | Rechazo; G2 sin reclamo válida | ✔ |
| garantia | Al menos un límite (días o km) | `CHECK ck_garantia_limite` | G02-INT-17 | Rechazo | ✔ |
| reclamo_garantia | Orden nueva, distinta y del mismo VIN (RN-21) | `TRG trg_reclamo_validar`; `UQ uq_reclamo_orden_nueva` | G02-INT-18 | Rechazo | ✔ |
| reclamo_garantia | Aceptado solo dentro de ambos límites: vence lo primero (RN-22) | `TRG` | G02-INT-18 (fuera de km, fuera de días y dentro de ambos) | Rechazo / válido | ✔ |
| reclamo_garantia | Rechazada exige justificación; km = km de ingreso de la orden nueva; solo se reevalúa si está Pendiente | `CHECK ck_reclamo_justificacion`; `TRG` | G02-INT-18 | Rechazo | ✔ |

## Historia de la orden (P03)

| Relación | Regla | Mecanismo | Prueba (ID) | Esperado | Observado |
|---|---|---|---|---|---|
| historial_orden | Transiciones del catálogo; retroceso con motivo; secuencia y estado anterior asignados por el sistema | `TRG trg_historial_orden_antes`; `transicion_estado_orden` | G02-P03-I-03, I-06, I-07 | Rechazo | ✔ |
| historial_fecha_prometida | Reprogramar exige motivo; promesa posterior a su comunicación | `CHECK ck_hfp_motivo`, `ck_hfp_promesa_futura`; `TRG` | G02-P03-I-02, G02-P03-A-01 | Rechazo | ✔ |
| historial_* | Solo inserción | `TRG trg_historial_orden_inmutable`, `trg_hfp_inmutable` | G02-P03-I-07 | Rechazo | ✔ |
| orden_trabajo | Valor actual = última fila del historial (D4) | `TRG trg_orden_antes_actualizar` + `CTRG trg_orden_coherencia` | G02-P03-I-04, G02-P03-A-02, G02-INT-20 | Rechazo; coherencia global | ✔ |
| transicion_estado_orden | Estados terminales sin salida; catálogo inmutable | `CHECK ck_transicion_terminal`; `TRG trg_transicion_inmutable` | G02-P03-L-02, G02-P03-L-04 | Rechazo / válido | ✔ |

## Reglas "no aplicables" y justificación

No quedó ninguna regla del inventario sin mecanismo. Hay dos decisiones de alcance que son deliberadas, no omisiones:

1. No se valida que el kilometraje de ingreso de una visita sea mayor que el de la anterior: un odómetro puede sustituirse, y el caso no dice nada al respecto.
2. No se exige que toda labor tenga una prueba para completarse (ver [ambigüedad A-06](ambiguedades.md#a-06--completar-una-labor-con-prueba-desfavorable)).
