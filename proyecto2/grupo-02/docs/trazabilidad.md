# Trazabilidad: regla / criterio → elemento → mecanismo → prueba

**IC-4301 · Proyecto 2 · Grupo 02 · Taller Ruta 27**

## 1. Reglas de negocio del Proyecto 1 (RN-01 … RN-22)

En el Proyecto 1, RN-03, RN-12, RN-22 y varias "validaciones posteriores" quedaron sin mecanismo. **En esta entrega todas tienen mecanismo y prueba.**

| RN | Regla (P1) | Elemento(s) | Mecanismo | Prueba(s) |
|---|---|---|---|---|
| RN-01 | Una orden = una visita de un vehículo | `orden_trabajo` | PK; FK a vehículo; índice único parcial `uq_orden_abierta_por_vehiculo` | G02-INT-06, G02-INT-19 (Q02) |
| RN-02 | VIN estable; la placa cambia | `vehiculo`, `orden_trabajo.placa_ingreso` | CHECK VIN; `trg_vehiculo_vin_estable`; instantánea de la placa | G02-INT-03, G02-INT-04 |
| RN-03 | Varios contactos, ≥ 1 apto para avisos | `contacto_cliente` | Constraint trigger **diferido**; CHECK de formato | G02-INT-02 |
| RN-04 | Distinguir quién entrega, a quién se factura y quién está facultado para aprobar | `orden_trabajo`, `facultad_orden` | FK por rol; roles fijados por visita; facultades con fuente y vigencia | G02-INT-05, G02-INT-07, G02-P01-I-01 |
| RN-05 | Datos de recepción | `orden_trabajo` | NOT NULL, CHECK de km y combustible; inmutables después del alta | G02-INT-06 |
| RN-06 | Objetos y daños confirmados | `objeto_dano` | Solo se confirma; bloquea la salida de 'Recibida' | G02-INT-08, G02-P03-I-05, G02-P03-L-01 |
| RN-07 | Cambios de promesa con fecha comunicada, motivo y responsable, sin sobrescribir | `historial_fecha_prometida` | Solo inserción; motivo obligatorio; `fecha_anterior` asignada por el sistema | G02-P03-V-02, G02-P03-I-02, G02-P03-L-03 |
| RN-08 | Cambios de estado con responsable y momento, no lineal | `historial_orden`, `transicion_estado_orden` | Secuencia bajo bloqueo; catálogo con retrocesos y motivo | G02-P03-V-01, G02-P03-I-03, G02-P03-I-06, G02-P03-L-04 |
| RN-09 | Hallazgos | `hallazgo` | Autor técnico (D1), momento, urgencia | G02-INT-09 |
| RN-10 | Versiones de propuesta sin pérdida | `propuesta`, `linea_propuesta` | Versión consecutiva; Presentada inmutable | G02-P01-V-03, G02-P01-V-04, G02-P01-I-04, G02-P01-A-01 |
| RN-11 | Autorización por labor (aceptada / rechazada / pendiente, fecha, medio, quién) | `autorizacion_labor` | Solo inserción; facultad vigente; decisión aplicable | G02-P01-V-02, G02-P01-L-03, G02-P01-L-04 |
| RN-12 | Rechazada no se ejecuta; emergencia mínima con justificación | `historial_labor`, `excepcion_emergencia` | Habilitante obligatorio (CHECK + trigger); la emergencia habilita solo su labor | G02-P02-I-01, G02-P02-L-02, G02-P01-L-05 |
| RN-13 | Varios técnicos con tiempos | `participacion_tecnica` | Técnico activo; CHECK minutos ≤ intervalo; EXCLUDE sin traslapes | G02-P02-V-01, G02-P02-L-03, G02-P02-I-09 |
| RN-14 | Especialidades con vigencia | `especialidad_tecnico` | EXCLUDE; solo rol Técnico; vigente en la participación | G02-INT-10, G02-P02-I-04 |
| RN-15 | Dependencia y revisión de labores sin borrar | `labor_dependencia`, `labor` (retrabajo) | N:M sin ciclos; labor inmutable; retrabajo ligado | G02-INT-15, G02-P02-I-02, G02-P02-V-01, G02-P02-I-10 |
| RN-16 | Pruebas (qué, quién, cuándo, resultado) | `prueba` | Resultado categórico; medición opcional; solo inserción | G02-P02-V-01, G02-P02-L-01, G02-P02-I-11 |
| RN-17 | Código interno ≠ código del proveedor | `repuesto`, `proveedor`, `proveedor_repuesto` | Formato del código interno; `UQ(proveedor_id, codigo_proveedor)` | G02-INT-11 |
| RN-18 | Estimado ≠ consumido | `repuesto_propuesto`, `consumo_repuesto`, `pieza_retirada` | Relaciones separadas; `v_propuesto_vs_ejecutado`, `v_insumos_orden` | G02-P02-V-02, G02-INT-13, G02-INT-14 |
| RN-19 | Movimientos y disponibilidad | `movimiento_inventario`, `v_existencias` | Trigger con bloqueo del repuesto; existencias nunca negativas | G02-P02-I-06, G02-INT-12, G02-P02-C2 |
| RN-20 | Entrega | `entrega` | Facultad Retirar; km; Lista entrega; máximo una por orden | G02-INT-16 |
| RN-21 | El reclamo abre una orden nueva y referencia la labor anterior | `reclamo_garantia`, `garantia` | Orden nueva ≠ original, mismo VIN; la garantía referencia la labor | G02-INT-18 |
| RN-22 | La garantía vence con lo que ocurra primero | `reclamo_garantia` | Aceptada solo dentro de ambos límites | G02-INT-18 |

## 2. "Validaciones posteriores" que el P1 dejó sin mecanismo

| Validación | Mecanismo actual | Prueba |
|---|---|---|
| El técnico tiene rol Técnico | `fn_exigir_personal(..., ARRAY['Técnico'])` en participación y hallazgo; trigger de especialidad | G02-P02-I-04, G02-INT-09, G02-INT-10 |
| Facultad real del autorizador | `facultad_orden` + `trg_autorizacion_validar` + `fk_autorizacion_facultad` | G02-P01-I-01, G02-P01-I-07 |
| La persona que retira está autorizada | `trg_entrega_validar` (facultad Retirar vigente) | G02-INT-16 |
| Km de salida ≥ km de ingreso | `trg_entrega_validar` | G02-INT-16 |
| Coherencia entre minutos e intervalo | `ck_participacion_minutos` | G02-P02-I-09, G02-P02-L-03 |
| Objetos confirmados | `trg_objeto_dano_validar` + regla al salir de Recibida | G02-INT-08, G02-P03-I-05 |

## 3. Defectos corregidos (D1 … D12)

| D | Corrección | Prueba que la demuestra |
|---|---|---|
| D1 | `hallazgo.diagnosticado_por_id` + `fecha_hora` | G02-INT-09 |
| D2 | `facultad_orden` verificada en cada decisión y en la entrega | G02-P01-I-01, G02-P01-I-07, G02-INT-07, G02-INT-16 |
| D3 | `garantia` + `reclamo_garantia` separadas | G02-INT-17, G02-INT-18 |
| D4 | Fecha prometida y estado solo vía historial | G02-P03-I-04, G02-P03-A-02, G02-INT-20 |
| D5 | Rótulos de Q02 / Q04 | G02-INT-19 |
| D6 | `linea_propuesta` (la labor en cada versión) | G02-P01-V-04, G02-P01-L-01 |
| D7 | `labor_dependencia` N:M sin ciclos | G02-INT-15, G02-P02-I-02 |
| D8 | `excepcion_emergencia` limitada a su labor | G02-P02-L-02 |
| D9 | `historial_labor` con el habilitante | G02-P02-V-01, G02-P02-L-05, G02-INT-20 |
| D10 | `prueba.resultado` categórico + medición opcional | G02-P02-I-11, G02-P02-L-01 |
| D11 | `movimiento_inventario.consumo_id` + existencias no negativas | G02-P02-A-03, G02-P02-I-06 |
| D12 | `propiedad_vehiculo` con vigencias; roles fijados por visita | G02-INT-05 |

## 4. Criterios de aceptación por proceso → pruebas

> Los textos de los criterios AC se redactaron a partir de lo que exige cada proceso en las instrucciones, porque el anexo con su redacción literal no está en el repositorio (ver [A-15](ambiguedades.md#a-15--documentos-comunes-ausentes-y-criterios-ac)).

| Criterio | Enunciado | Pruebas |
|---|---|---|
| AC-G02-P01-01 | Cada versión se conserva íntegra al emitir otra (precios, alcance, repuestos, decisiones) y una versión con un detalle inválido no deja nada | V-01, V-03, V-04, I-04, I-08, L-02, A-01…A-03, C1 |
| AC-G02-P01-02 | Cada decisión registra la decisión, el cliente facultado, el medio y la fecha, y nunca se sobrescribe | V-02, V-04, I-04, I-06, L-04 |
| AC-G02-P01-03 | Se rechaza la decisión de quien no tiene facultad vigente en esa orden, o sobre una labor o versión de otro contexto | I-01, I-02, I-03, I-07, I-08 |
| AC-G02-P01-04 | La decisión aplicable es inequívoca; una labor rechazada, pendiente o sin decidir no es ejecutable | V-02, V-04, I-05, L-01, L-03, L-05, C2, C3 |
| AC-G02-P02-01 | Solo se ejecuta una labor con autorización aplicable Aceptada o con emergencia justificada (que habilita solo esa labor) y con sus dependencias completas | V-01, V-02, I-01, I-02, I-08, L-02, L-04, L-05 |
| AC-G02-P02-02 | Participaciones de varios técnicos válidos, con especialidad vigente y tiempos coherentes | V-01, I-03, I-04, I-09, I-10, L-03, L-04, C1 |
| AC-G02-P02-03 | Pruebas con resultado; la desfavorable genera un retrabajo ligado sin borrar la intervención original; completar exige sus condiciones | V-01, I-07, I-10, I-11, L-01, L-04, A-02 |
| AC-G02-P02-04 | El consumo genera su movimiento en la misma transacción; las existencias nunca son negativas; propuesto vs. ejecutado | V-01, V-02, I-05, I-06, A-01, A-03, C2 |
| AC-G02-P03-01 | Cada cambio de estado tiene responsable, momento y motivo cuando aplica; secuencia no lineal con retrocesos legítimos | V-01, I-03, I-06, I-07, L-04 |
| AC-G02-P03-02 | Las reprogramaciones conservan la promesa original y las anteriores, con motivo, medio y responsable | V-02, I-02, L-03 |
| AC-G02-P03-03 | El valor actual y el historial se confirman juntos; el UPDATE directo se rechaza; un fallo a mitad no deja efectos | V-01, I-01, I-04, I-05, I-07, A-01, A-02 |
| AC-G02-P03-04 | Orden inequívoco en el mismo instante; concurrencia sin pérdidas; una orden cancelada sigue consultable | L-01, L-02, C1, C2 |
