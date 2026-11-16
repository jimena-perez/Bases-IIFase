# Evidencias observadas (bitácora `pruebas.evidencia`)

> Generado ejecutando la batería completa en una base nueva el 2026-11-16 04:07 UTC. Cada fila es una comprobación registrada por `pruebas.esperar_rechazo` (rechazo esperado, con SQLSTATE y mensaje reales) o por `pruebas.verificar` (lectura posterior de datos).

## Resumen

| Bloque | Comprobaciones | OK | FALLO |
|---|---:|---:|---:|
| INT-01 | 3 | 3 | 0 |
| INT-02 | 6 | 6 | 0 |
| INT-03 | 4 | 4 | 0 |
| INT-04 | 1 | 1 | 0 |
| INT-05 | 3 | 3 | 0 |
| INT-06 | 8 | 8 | 0 |
| INT-07 | 5 | 5 | 0 |
| INT-08 | 3 | 3 | 0 |
| INT-09 | 5 | 5 | 0 |
| INT-10 | 5 | 5 | 0 |
| INT-11 | 6 | 6 | 0 |
| INT-12 | 8 | 8 | 0 |
| INT-13 | 3 | 3 | 0 |
| INT-14 | 1 | 1 | 0 |
| INT-15 | 4 | 4 | 0 |
| INT-16 | 8 | 8 | 0 |
| INT-17 | 3 | 3 | 0 |
| INT-18 | 9 | 9 | 0 |
| INT-19 | 2 | 2 | 0 |
| INT-20 | 2 | 2 | 0 |
| P01-A | 5 | 5 | 0 |
| P01-I | 34 | 34 | 0 |
| P01-L | 11 | 11 | 0 |
| P01-V | 7 | 7 | 0 |
| P02-A | 9 | 9 | 0 |
| P02-I | 37 | 37 | 0 |
| P02-L | 13 | 13 | 0 |
| P02-V | 6 | 6 | 0 |
| P03-A | 4 | 4 | 0 |
| P03-I | 22 | 22 | 0 |
| P03-L | 8 | 8 | 0 |
| P03-V | 5 | 5 | 0 |
| **Total** | **250** | **250** | **0** |

## Detalle

| # | ID | Criterio | Tipo | Acción | Esperado | Observado | Resultado |
|---:|---|---|---|---|---|---|---|
| 1 | G02-P01-V-01 | AC-G02-P01-01 | Verificación | v1 presentada con 3 líneas | v1 Presentada, 3 líneas | v1 Presentada, 3 líneas | OK |
| 2 | G02-P01-V-02 | AC-G02-P01-02 | Verificación | decisiones con actor, facultad, medio y fecha | 3 decisiones de María por teléfono con facultad | 3 decisiones: Aceptada, Rechazada, Pendiente | OK |
| 3 | G02-P01-V-02 | AC-G02-P01-04 | Verificación | solo A es ejecutable | ejecutables: {A} | ejecutables: {501} | OK |
| 4 | G02-P01-V-03 | AC-G02-P01-01 | Verificación | la ampliación no toca A, B y C | A=v1:Aceptada, B=v1:Rechazada, C=v1:Pendiente, D=v2:Aceptada | Cambio de pastillas delanteras=v1:Aceptada, Cambio de escobillas=v1:Rechazada, Alineación y balanceo=v1:Pendiente, Purga y cambio de líquido de frenos=v2:Aceptada | OK |
| 5 | G02-P01-V-04 | AC-G02-P01-01 | Verificación | v1 intacta tras v2 y v3 | v1: A 45000 Aceptada \| B 5000 Rechazada \| C 30000 Pendiente | Cambio de pastillas delanteras:45000.00:Aceptada \| Cambio de escobillas:5000.00:Rechazada \| Alineación y balanceo:30000.00:Pendiente | OK |
| 6 | G02-P01-V-04 | AC-G02-P01-04 | Verificación | C vigente en v3 a 25000 y Aceptada | C: v3, 25000, Aceptada | C: v3, 25000.00, Aceptada | OK |
| 7 | G02-P01-V-04 | AC-G02-P01-02 | Verificación | ninguna decisión anterior fue sobrescrita | 5 decisiones conservadas (incluida la Pendiente de C en v1) | 5 decisiones: Aceptada, Rechazada, Pendiente, Aceptada, Aceptada | OK |
| 8 | G02-P01-I-01 | AC-G02-P01-03 | Rechazo | Ana (facultada en 9002) decide en 9001 | Rechazo: el cliente 104 no tiene facultad vigente para aprobar en la orden 9001 | P0001: G02-P01: el cliente 104 no tiene facultad vigente para aprobar en la orden 9001 | OK |
| 9 | G02-P01-I-01 | AC-G02-P01-03 | Rechazo | Pedro (sin facultad) decide en 9001 | Rechazo: el cliente 108 no tiene facultad vigente | P0001: G02-P01: el cliente 108 no tiene facultad vigente para aprobar en la orden 9001 | OK |
| 10 | G02-P01-I-01 | AC-G02-P01-03 | Rechazo | INSERT directo con la facultad de Ana en 9002 | Rechazo: no tiene facultad vigente para aprobar en la orden 9001 | P0001: G02-P01: el cliente 104 no tiene facultad vigente para aprobar en la orden 9001 | OK |
| 11 | G02-P01-I-01 | AC-G02-P01-03 | Rechazo | misma inserción solo contra la FK compuesta | Rechazo: fk_autorizacion_facultad | 23503: insert or update on table "autorizacion_labor" violates foreign key constraint "fk_autorizacion_facultad" | OK |
| 12 | G02-P01-I-01 | AC-G02-P01-03 | Rechazo | INSERT directo: facultad de María pero cliente Ana | Rechazo: no tiene facultad vigente para aprobar | P0001: G02-P01: el cliente 104 no tiene facultad vigente para aprobar en la orden 9001 | OK |
| 13 | G02-P01-I-01 | AC-G02-P01-03 | Verificación | sin decisiones nuevas en 9001 y D sigue Aceptada | 5 decisiones; D Aceptada | 5 decisiones; D Aceptada | OK |
| 14 | G02-P01-I-02 | AC-G02-P01-03 | Rechazo | decisión sobre labor de otra orden (rutina) | Rechazo: no forma parte de la propuesta | P0001: G02-P01: la labor 505 no forma parte de la propuesta 301 | OK |
| 15 | G02-P01-I-02 | AC-G02-P01-03 | Rechazo | decisión sobre labor de otra orden (INSERT directo) | Rechazo: no forma parte de la propuesta | P0001: G02-P01: la labor 505 no forma parte de la propuesta 301 | OK |
| 16 | G02-P01-I-02 | AC-G02-P01-03 | Rechazo | misma inserción solo contra la FK compuesta | Rechazo: fk_autorizacion_linea | 23503: insert or update on table "autorizacion_labor" violates foreign key constraint "fk_autorizacion_linea" | OK |
| 17 | G02-P01-I-02 | AC-G02-P01-03 | Rechazo | publicar en 9001 una línea con labor de 9002 | Rechazo: no pertenece a la orden 9001 | P0001: G02-P01: línea 1: la labor 505 no pertenece a la orden 9001 | OK |
| 18 | G02-P01-I-03 | AC-G02-P01-03 | Rechazo | decisión sobre (v1, labor que solo está en v2) | Rechazo: no forma parte de la propuesta | P0001: G02-P01: la labor 504 no forma parte de la propuesta 301 | OK |
| 19 | G02-P01-I-04 | AC-G02-P01-01 | Rechazo | UPDATE del precio de una línea presentada | Rechazo: inmutables | P0001: G02-P01: la propuesta 301 ya fue presentada; sus líneas y repuestos son inmutables (UPDATE sobre linea_propuesta) | OK |
| 20 | G02-P01-I-04 | AC-G02-P01-01 | Rechazo | DELETE de una línea presentada | Rechazo: inmutables | P0001: G02-P01: la propuesta 301 ya fue presentada; sus líneas y repuestos son inmutables (DELETE sobre linea_propuesta) | OK |
| 21 | G02-P01-I-04 | AC-G02-P01-01 | Rechazo | UPDATE de un repuesto estimado presentado | Rechazo: inmutables | P0001: G02-P01: la propuesta 301 ya fue presentada; sus líneas y repuestos son inmutables (UPDATE sobre repuesto_propuesto) | OK |
| 22 | G02-P01-I-04 | AC-G02-P01-01 | Rechazo | INSERT de una línea en v1 ya presentada | Rechazo: inmutables | P0001: G02-P01: la propuesta 301 ya fue presentada; sus líneas y repuestos son inmutables (INSERT sobre linea_propuesta) | OK |
| 23 | G02-P01-I-04 | AC-G02-P01-01 | Rechazo | UPDATE de la observación de una propuesta presentada | Rechazo: ya fue presentada y es inmutable | P0001: G02-P01: la propuesta 301 (v1) ya fue presentada y es inmutable | OK |
| 24 | G02-P01-I-04 | AC-G02-P01-02 | Rechazo | UPDATE de una autorización (cambiar Rechazada por Aceptada) | Rechazo: solo inserción | P0001: G02-INM: autorizacion_labor es de solo inserción; no se permite UPDATE (registre una fila nueva) | OK |
| 25 | G02-P01-I-04 | AC-G02-P01-02 | Rechazo | DELETE de una autorización | Rechazo: solo inserción | P0001: G02-INM: autorizacion_labor es de solo inserción; no se permite DELETE (registre una fila nueva) | OK |
| 26 | G02-P01-I-04 | AC-G02-P01-01 | Verificación | v1 sigue idéntica | 45000 Aceptada, 5000 Rechazada, 30000 Pendiente | 45000.00:Aceptada,5000.00:Rechazada,30000.00:Pendiente | OK |
| 27 | G02-P01-I-05 | AC-G02-P01-04 | Rechazo | decidir sobre una versión obsoleta de la labor | Rechazo: la versión 1 no es la vigente | P0001: G02-P01: la versión 1 no es la vigente para la labor 503; la vigente es la versión 3 | OK |
| 28 | G02-P01-I-06 | AC-G02-P01-02 | Rechazo | decisión fuera de dominio | Rechazo: ck_autorizacion_decision | 23514: new row for relation "autorizacion_labor" violates check constraint "ck_autorizacion_decision" | OK |
| 29 | G02-P01-I-06 | AC-G02-P01-02 | Rechazo | medio fuera de dominio | Rechazo: d_medio_comunicacion | 23514: value for domain d_medio_comunicacion violates check constraint "ck_d_medio_comunicacion" | OK |
| 30 | G02-P01-I-06 | AC-G02-P01-02 | Rechazo | decisión anterior a la presentación | Rechazo: no puede ser anterior a la presentación | P0001: G02-P01: la decisión (2026-11-03 10:00:00-06) no puede ser anterior a la presentación de la versión (2026-11-03 10:30:00-06) | OK |
| 31 | G02-P01-I-06 | AC-G02-P01-02 | Rechazo | decisión anterior a la última de la línea | Rechazo: anterior a la última decisión registrada | P0001: G02-P01: la decisión (2026-11-03 10:45:00-06) es anterior a la última decisión registrada sobre la línea (2026-11-03 11:00:00-06) | OK |
| 32 | G02-P01-I-07 | AC-G02-P01-03 | Rechazo | decisión con facultad revocada | Rechazo: no tiene facultad vigente | P0001: G02-P01: el cliente 104 no tiene facultad vigente para aprobar en la orden 9002 | OK |
| 33 | G02-P01-I-07 | AC-G02-P01-03 | Rechazo | revocar dos veces / reescribir la facultad | Rechazo: solo admite revocación | P0001: G02-INM: la facultad 5 solo admite revocación (fijar vigente_hasta una única vez) | OK |
| 34 | G02-P01-I-07 | AC-G02-P01-03 | Verificación | la decisión de Ana anterior a la revocación se conserva | Aceptada por Ana Solís | Aceptada por Ana Solís | OK |
| 35 | G02-P01-I-08 | AC-G02-P01-01 | Rechazo | versión sin líneas | Rechazo: al menos una línea | P0001: G02-P01: una versión debe tener al menos una línea | OK |
| 36 | G02-P01-I-08 | AC-G02-P01-01 | Rechazo | labor repetida en la misma versión | Rechazo: aparece dos veces | P0001: G02-P01: línea 2: la labor 503 aparece dos veces en la misma versión | OK |
| 37 | G02-P01-I-08 | AC-G02-P01-03 | Rechazo | labor nueva con hallazgo de otra orden | Rechazo: el hallazgo 4103 no pertenece a la orden 9001 | P0001: G02-P01: línea 1: el hallazgo 4103 no pertenece a la orden 9001 | OK |
| 38 | G02-P01-I-08 | AC-G02-P01-03 | Rechazo | versión base de otra orden | Rechazo: fk_propuesta_base | 23503: insert or update on table "propuesta" violates foreign key constraint "fk_propuesta_base" | OK |
| 39 | G02-P01-I-08 | AC-G02-P01-01 | Rechazo | INSERT directo de una propuesta ya Presentada | Rechazo: se crea en Borrador | P0001: G02-P01: una propuesta se crea en Borrador y se presenta junto con sus líneas | OK |
| 40 | G02-P01-I-08 | AC-G02-P01-01 | Rechazo | INSERT directo con hueco de versión | Rechazo: debe ser 4 | P0001: G02-P01: la siguiente versión de la orden 9001 debe ser 4 (se indicó 7) | OK |
| 41 | G02-P01-I-08 | AC-G02-P01-01 | Verificación | siguen existiendo solo v1..v3 en 9001 | {1,2,3} | {1,2,3} | OK |
| 42 | G02-P01-L-01 | AC-G02-P01-04 | Verificación | v2 solo-precio: la aceptación de v1 no se arrastra | v2 Sin decidir y sin autorización ejecutable | v2 Sin decidir; ejecutables: 0 | OK |
| 43 | G02-P01-L-01 | AC-G02-P01-04 | Verificación | tras decidir sobre v2, la ejecutable es la de v2 | autorización ejecutable = decisión de v2 | v2, autorizacion_id 617 | OK |
| 44 | G02-P01-L-02 | AC-G02-P01-01 | Verificación | v2 de 9001 contiene solo la labor añadida | v2 con 1 línea; A sigue vigente en v1 y Aceptada | 1 línea(s); A v1 Aceptada | OK |
| 45 | G02-P01-L-03 | AC-G02-P01-04 | Verificación | decisiones incompletas | Aceptada,Pendiente,Sin decidir; 1 ejecutable | Aceptada,Pendiente,Sin decidir; 1 ejecutable(s) | OK |
| 46 | G02-P01-L-03 | AC-G02-P01-04 | Rechazo | iniciar la labor Pendiente | Rechazo: situación: Pendiente | P0001: G02-P02: la labor 507 no tiene autorización aplicable Aceptada ni excepción de emergencia (situación: Pendiente) | OK |
| 47 | G02-P01-L-03 | AC-G02-P01-04 | Rechazo | iniciar la labor Sin decidir | Rechazo: situación: Sin decidir | P0001: G02-P02: la labor 508 no tiene autorización aplicable Aceptada ni excepción de emergencia (situación: Sin decidir) | OK |
| 48 | G02-P01-L-04 | AC-G02-P01-04 | Verificación | cambio de decisión en la misma línea | 2 filas (Pendiente, Aceptada); aplica Aceptada | Pendiente, Aceptada; aplica Aceptada | OK |
| 49 | G02-P01-L-05 | AC-G02-P01-04 | Verificación | labor rechazada re-ofrecida queda Sin decidir | v4 Sin decidir | v4 Sin decidir | OK |
| 50 | G02-P01-L-05 | AC-G02-P01-04 | Rechazo | iniciar la labor re-ofrecida sin decisión nueva | Rechazo: no tiene autorización aplicable Aceptada | P0001: G02-P02: la labor 502 no tiene autorización aplicable Aceptada ni excepción de emergencia (situación: Sin decidir) | OK |
| 51 | G02-P01-L-05 | AC-G02-P01-04 | Rechazo | INSERT directo citando la autorización vieja (Rechazada de v1) | Rechazo: no es la decisión aplicable Aceptada | P0001: G02-P02: la autorización 602 no es la decisión aplicable Aceptada de la labor 502 (situación: Sin decidir) | OK |
| 52 | G02-P01-L-05 | AC-G02-P01-04 | Verificación | la ejecutable de B es la aceptación de v4 y la Rechazada de v1 se conserva | ejecutable v4; v1 Rechazada intacta | v1:Rechazada, v4:Aceptada | OK |
| 53 | G02-P01-A-01 | AC-G02-P01-01 | Rechazo | versión con una línea de precio negativo | Rechazo: no puede ser negativo | P0001: G02-P01: línea 3: el precio estimado no puede ser negativo (-500) | OK |
| 54 | G02-P01-A-02 | AC-G02-P01-01 | Rechazo | versión con hallazgo de otra orden en la segunda línea | Rechazo: el hallazgo 4103 no pertenece a la orden 9001 | P0001: G02-P01: línea 2: el hallazgo 4103 no pertenece a la orden 9001 | OK |
| 55 | G02-P01-A-03 | AC-G02-P01-01 | Rechazo | versión con repuesto inexistente | Rechazo: fk_rep_prop_repuesto | 23503: insert or update on table "repuesto_propuesto" violates foreign key constraint "fk_rep_prop_repuesto" | OK |
| 56 | G02-P01-A-01 | AC-G02-P01-01 | Verificación | conteos iguales tras los tres intentos fallidos | 4 propuestas, 4 labores, 6 líneas, 0 dependencias | 4 propuestas, 4 labores, 6 líneas, 0 dependencias | OK |
| 57 | G02-P01-A-01 | AC-G02-P01-01 | Verificación | la siguiente versión válida es la 5 (sin huecos) | {1,2,3,4,5} | {1,2,3,4,5} | OK |
| 58 | G02-P02-V-01 | AC-G02-P02-01 | Verificación | P inició con SU autorización aplicable Aceptada | autorizacion_id del inicio = decisión aplicable | inicio con autorizacion_id 622 | OK |
| 59 | G02-P02-V-01 | AC-G02-P02-02 | Verificación | 2 técnicos; efectivo (85) menor que el intervalo (90) | 2 técnicos, uno con 85 de 90 minutos | Diego Mora 85/90; Andrés Castro 45/45 | OK |
| 60 | G02-P02-V-01 | AC-G02-P02-03 | Verificación | retrabajo ligado a P y a la prueba Desfavorable; ambos Completados | retrabajo Completada, P Completada, origen Desfavorable | retrabajo Completada, P Completada, origen Desfavorable | OK |
| 61 | G02-P02-V-01 | AC-G02-P02-03 | Verificación | la intervención original y su prueba Desfavorable se conservan | 2 pruebas (Desfavorable + Favorable) y 2 participaciones de P intactas | Desfavorable + Favorable | OK |
| 62 | G02-P02-V-01 | AC-G02-P02-04 | Verificación | consumo con movimiento y liberación de la reserva | FR-001: físico 9, reservado 0, disponible 9 | FR-001: físico 9.00, reservado 0.00, disponible 9.00 | OK |
| 63 | G02-P02-V-02 | AC-G02-P02-04 | Verificación | propuesto vs ejecutado de P y Q | P 25000/25000/130 min; Q 6500/6500/40 min | 25000.0000/25000.0000/130,6500.0000/6500.0000/40 | OK |
| 64 | G02-P02-I-01 | AC-G02-P02-01 | Rechazo | iniciar labor rechazada | Rechazo: situación: Rechazada | P0001: G02-P02: la labor 519 no tiene autorización aplicable Aceptada ni excepción de emergencia (situación: Rechazada) | OK |
| 65 | G02-P02-I-01 | AC-G02-P02-01 | Rechazo | INSERT directo citando la autorización Rechazada | Rechazo: no es la decisión aplicable Aceptada | P0001: G02-P02: la autorización 626 no es la decisión aplicable Aceptada de la labor 519 (situación: Rechazada) | OK |
| 66 | G02-P02-I-01 | AC-G02-P02-01 | Rechazo | INSERT directo citando la autorización de OTRA labor | Rechazo: no es la decisión aplicable Aceptada | P0001: G02-P02: la autorización 623 no es la decisión aplicable Aceptada de la labor 519 (situación: Rechazada) | OK |
| 67 | G02-P02-I-01 | AC-G02-P02-01 | Rechazo | misma inserción solo contra la FK compuesta | Rechazo: fk_historial_labor_autorizacion | 23503: insert or update on table "historial_labor" violates foreign key constraint "fk_historial_labor_autorizacion" | OK |
| 68 | G02-P02-I-01 | AC-G02-P02-01 | Rechazo | reiniciar una labor Completada | Rechazo: está Completada y no puede iniciarse | P0001: G02-P02: la labor 515 está Completada y no puede iniciarse | OK |
| 69 | G02-P02-I-01 | AC-G02-P02-01 | Verificación | K no avanzó | K Pendiente con 1 fila de historial | Pendiente con 1 fila(s) | OK |
| 70 | G02-P02-I-02 | AC-G02-P02-01 | Rechazo | iniciar labor con dependencia sin completar | Rechazo: que no está Completada | P0001: G02-P02: la labor 518 depende de la labor 516, que no está Completada | OK |
| 71 | G02-P02-I-02 | AC-G02-P02-01 | Verificación | U sigue Pendiente | Pendiente | Pendiente | OK |
| 72 | G02-P02-I-03 | AC-G02-P02-02 | Rechazo | participación con técnico inexistente | Rechazo: el personal 999 no existe | P0001: G02-P02: participación: el personal 999 no existe | OK |
| 73 | G02-P02-I-04 | AC-G02-P02-02 | Rechazo | participación de personal que no es técnico | Rechazo: tiene rol Recepción y se requiere Técnico | P0001: G02-P02: participación: el personal 201 tiene rol Recepción y se requiere Técnico | OK |
| 74 | G02-P02-I-04 | AC-G02-P02-02 | Rechazo | participación de técnica inactiva | Rechazo: no está activo | P0001: G02-P02: participación: el personal 207 no está activo | OK |
| 75 | G02-P02-I-04 | AC-G02-P02-02 | Rechazo | especialidad de otro técnico | Rechazo: la especialidad 3 no está vigente para el técnico 202 | P0001: G02-P02: la especialidad 3 no está vigente para el técnico 202 en 2026-11-05 | OK |
| 76 | G02-P02-I-04 | AC-G02-P02-02 | Rechazo | especialidad vencida | Rechazo: la especialidad 5 no está vigente | P0001: G02-P02: la especialidad 5 no está vigente para el técnico 204 en 2026-11-05 | OK |
| 77 | G02-P02-I-04 | AC-G02-P02-02 | Rechazo | participación antes de iniciar la labor | Rechazo: no puede iniciar antes de que la labor | P0001: G02-P02: la participación (2026-11-05 10:00:00-06) no puede iniciar antes de que la labor 516 pasara a En proceso (2026-11-05 11:00:00-06) | OK |
| 78 | G02-P02-I-04 | AC-G02-P02-02 | Verificación | S sin participaciones | 0 participaciones | 0 participaciones | OK |
| 79 | G02-P02-I-05 | AC-G02-P02-04 | Rechazo | consumo sobre labor de otra orden (rutina) | Rechazo: no pertenece a la orden 9001 | P0001: G02-P02: la labor 516 no pertenece a la orden 9001 (es de la orden 9003) | OK |
| 80 | G02-P02-I-05 | AC-G02-P02-04 | Rechazo | consumo sobre labor de otra orden (INSERT directo) | Rechazo: fk_consumo_labor | 23503: insert or update on table "consumo_repuesto" violates foreign key constraint "fk_consumo_labor" | OK |
| 81 | G02-P02-I-06 | AC-G02-P02-04 | Rechazo | consumo sin existencias | Rechazo: existencias insuficientes de EL-002 | P0001: G02-INT: existencias insuficientes de EL-002: el movimiento dejaría -1.00 físicas | OK |
| 82 | G02-P02-I-06 | AC-G02-P02-04 | Verificación | sin consumo ni movimiento de EL-002 | 0 consumos en S, 0 movimientos de EL-002 | 0 consumos, 0 movimientos | OK |
| 83 | G02-P02-I-07 | AC-G02-P02-03 | Rechazo | completar sin participación | Rechazo: sin participación técnica cerrada | P0001: G02-P02: no se puede completar la labor 516 sin participación técnica cerrada | OK |
| 84 | G02-P02-I-07 | AC-G02-P02-03 | Verificación | S sigue En proceso | En proceso | En proceso | OK |
| 85 | G02-P02-I-08 | AC-G02-P02-01 | Rechazo | participación en labor no iniciada | Rechazo: no está En proceso | P0001: G02-P02: la labor 519 no está En proceso (estado: Pendiente) | OK |
| 86 | G02-P02-I-08 | AC-G02-P02-01 | Rechazo | prueba en labor no iniciada | Rechazo: no está En proceso | P0001: G02-P02: la labor 519 no está En proceso (estado: Pendiente) | OK |
| 87 | G02-P02-I-08 | AC-G02-P02-01 | Rechazo | consumo en labor no iniciada | Rechazo: no está En proceso | P0001: G02-P02: la labor 519 no está En proceso (estado: Pendiente) | OK |
| 88 | G02-P02-I-09 | AC-G02-P02-02 | Rechazo | efectivos > intervalo | Rechazo: ck_participacion_minutos | 23514: new row for relation "participacion_tecnica" violates check constraint "ck_participacion_minutos" | OK |
| 89 | G02-P02-I-09 | AC-G02-P02-02 | Rechazo | técnico en dos intervenciones a la vez | Rechazo: ex_participacion_tecnico | 23P01: conflicting key value violates exclusion constraint "ex_participacion_tecnico" | OK |
| 90 | G02-P02-I-10 | AC-G02-P02-03 | Rechazo | UPDATE directo del estado de una labor | Rechazo: solo cambia mediante historial_labor | P0001: G02-P02: el estado de la labor 516 solo cambia mediante historial_labor | OK |
| 91 | G02-P02-I-10 | AC-G02-P02-03 | Rechazo | UPDATE de la descripción de una labor | Rechazo: no se reescribe | P0001: G02-INM: la labor 515 no se reescribe; registre un retrabajo o una labor nueva (RN-15) | OK |
| 92 | G02-P02-I-10 | AC-G02-P02-03 | Rechazo | DELETE de una labor | Rechazo: no se elimina | P0001: G02-INM: la labor 519 no se elimina; anúlela con motivo | OK |
| 93 | G02-P02-I-10 | AC-G02-P02-03 | Rechazo | UPDATE del resultado de una prueba | Rechazo: solo inserción | P0001: G02-INM: prueba es de solo inserción; no se permite UPDATE (registre una fila nueva) | OK |
| 94 | G02-P02-I-10 | AC-G02-P02-04 | Rechazo | DELETE de un consumo | Rechazo: solo inserción | P0001: G02-INM: consumo_repuesto es de solo inserción; no se permite DELETE (registre una fila nueva) | OK |
| 95 | G02-P02-I-10 | AC-G02-P02-02 | Rechazo | UPDATE de una participación cerrada | Rechazo: solo admite su cierre | P0001: G02-INM: la participación 1 solo admite su cierre (fin y minutos), una vez | OK |
| 96 | G02-P02-I-11 | AC-G02-P02-03 | Rechazo | retrabajo desde prueba Favorable | Rechazo: solo se origina en una prueba Desfavorable | P0001: G02-P02: un retrabajo solo se origina en una prueba Desfavorable (la prueba 2 es Favorable) | OK |
| 97 | G02-P02-I-11 | AC-G02-P02-03 | Rechazo | retrabajo con prueba de otra labor | Rechazo: no es de la labor | P0001: G02-P02: la prueba 1 no es de la labor 517 | OK |
| 98 | G02-P02-I-11 | AC-G02-P02-03 | Rechazo | medición sin unidad | Rechazo: ck_prueba_medicion | 23514: new row for relation "prueba" violates check constraint "ck_prueba_medicion" | OK |
| 99 | G02-P02-I-11 | AC-G02-P02-03 | Rechazo | resultado fuera de dominio | Rechazo: ck_prueba_resultado | 23514: new row for relation "prueba" violates check constraint "ck_prueba_resultado" | OK |
| 100 | G02-P02-I-11 | AC-G02-P02-03 | Verificación | S sigue En proceso sin pruebas ni participaciones | En proceso, 0 pruebas, 0 participaciones | En proceso, 0 pruebas, 0 participaciones | OK |
| 101 | G02-P02-L-01 | AC-G02-P02-03 | Verificación | labor sin repuestos y prueba descriptiva | Completada, 0 consumos, prueba sin medición | Completada, 0 consumos, medición NULL | OK |
| 102 | G02-P02-L-02 | AC-G02-P02-01 | Verificación | la emergencia habilitó su labor citando la excepción | inicio con emergencia_id, labor Completada | emergencia_id 1, Completada | OK |
| 103 | G02-P02-L-02 | AC-G02-P02-01 | Rechazo | la emergencia NO habilita otra labor de la propuesta | Rechazo: situación: Sin decidir | P0001: G02-P02: la labor 523 no tiene autorización aplicable Aceptada ni excepción de emergencia (situación: Sin decidir) | OK |
| 104 | G02-P02-L-02 | AC-G02-P02-01 | Rechazo | INSERT directo citando la emergencia en otra labor | Rechazo: no es de emergencia | P0001: G02-P02: la labor 523 no es de emergencia | OK |
| 105 | G02-P02-L-02 | AC-G02-P02-01 | Rechazo | misma inserción solo contra la FK compuesta | Rechazo: fk_historial_labor_emergencia | 23503: insert or update on table "historial_labor" violates foreign key constraint "fk_historial_labor_emergencia" | OK |
| 106 | G02-P02-L-02 | AC-G02-P02-01 | Rechazo | excepción de emergencia sobre una labor no marcada como emergencia | Rechazo: no está marcada como emergencia | P0001: G02-P02: la labor 523 no está marcada como emergencia; no admite excepción | OK |
| 107 | G02-P02-L-02 | AC-G02-P02-01 | Rechazo | emergencia con justificación insuficiente | Rechazo: ck_emergencia_justificacion | 23514: new row for relation "excepcion_emergencia" violates check constraint "ck_emergencia_justificacion" | OK |
| 108 | G02-P02-L-02 | AC-G02-P02-01 | Verificación | la propuesta y las demás labores no cambiaron | 1 línea, 2 labores, bujes Pendiente | 1 línea, 2 labores, bujes Pendiente | OK |
| 109 | G02-P02-L-03 | AC-G02-P02-02 | Verificación | intervalo 120 / efectivos 75 y 120 / 120 | 75/120,120/120 | 75/120,120/120 | OK |
| 110 | G02-P02-L-04 | AC-G02-P02-03 | Rechazo | completar con una participación abierta | Rechazo: tiene participaciones abiertas | P0001: G02-P02: la labor 516 tiene participaciones abiertas | OK |
| 111 | G02-P02-L-04 | AC-G02-P02-01 | Verificación | S Completada y U iniciada tras cumplir su dependencia | S Completada; U En proceso | S Completada; U En proceso | OK |
| 112 | G02-P02-L-05 | AC-G02-P02-01 | Rechazo | suspender sin motivo | Rechazo: requiere motivo | P0001: G02-P02: pasar la labor 518 a Suspendida requiere motivo | OK |
| 113 | G02-P02-L-05 | AC-G02-P02-01 | Verificación | suspensión y reanudación con habilitante | Pendiente -> En proceso -> Suspendida -> En proceso (2 inicios con autorización) | Pendiente -> En proceso -> Suspendida -> En proceso | OK |
| 114 | G02-P02-A-01 | AC-G02-P02-04 | Rechazo | bloque con consumo sin existencias a mitad | Rechazo: existencias insuficientes de EL-002 | P0001: G02-INT: existencias insuficientes de EL-002: el movimiento dejaría -1.00 físicas | OK |
| 115 | G02-P02-A-01 | AC-G02-P02-04 | Verificación | ni labor completada ni consumo huérfano | U En proceso, 0 consumos, 0 participaciones, MG-002 físico 20 | En proceso, 0 consumos, 0 participaciones, MG-002 20.00 | OK |
| 116 | G02-P02-A-02 | AC-G02-P02-03 | Rechazo | completar con última prueba Desfavorable | Rechazo: es Desfavorable y no tiene retrabajo completado | P0001: G02-P02: la última prueba (10) de la labor 518 es Desfavorable y no tiene retrabajo completado | OK |
| 117 | G02-P02-A-02 | AC-G02-P02-03 | Verificación | nada quedó del bloque | 0 pruebas, 0 participaciones en U | 0 pruebas, 0 participaciones | OK |
| 118 | G02-P02-A-03 | AC-G02-P02-04 | Rechazo | consumo sin movimiento (al COMMIT) | Rechazo: no tiene su movimiento de inventario | P0001: G02-P02: el consumo 10 no tiene su movimiento de inventario de Consumo | OK |
| 119 | G02-P02-A-03 | AC-G02-P02-04 | Rechazo | movimiento Consumo sin origen | Rechazo: requiere el consumo de origen | P0001: G02-INT: un movimiento de Consumo requiere el consumo de origen (consumo_id), D11 | OK |
| 120 | G02-P02-A-03 | AC-G02-P02-04 | Rechazo | movimiento Consumo sin origen (solo contra el CHECK) | Rechazo: ck_movimiento_consumo_origen | 23514: new row for relation "movimiento_inventario" violates check constraint "ck_movimiento_consumo_origen" | OK |
| 121 | G02-P02-A-03 | AC-G02-P02-04 | Rechazo | movimiento con cantidad distinta a la del consumo | Rechazo: no coincide con la cantidad | P0001: G02-INT: el movimiento de Consumo (3.00) no coincide con la cantidad del consumo 11 (1.00) | OK |
| 122 | G02-P02-A-03 | AC-G02-P02-04 | Verificación | todo consumo tiene exactamente su movimiento | 0 consumos sin movimiento y 0 movimientos de consumo sin origen | 4 consumos, 4 movimientos de consumo | OK |
| 123 | G02-P03-V-01 | AC-G02-P03-01 | Verificación | historial de estados de 9005 tras COMMIT | 8 cambios, secuencia 1..8 sin huecos | 8 cambios, secuencia 1..8 | OK |
| 124 | G02-P03-V-01 | AC-G02-P03-01 | Verificación | retroceso En reparación -> En diagnóstico con motivo | retroceso registrado con su motivo | En reparación -> En diagnóstico \| Al reemplazar la batería se detecta falla en el convertidor DC-DC | OK |
| 125 | G02-P03-V-01 | AC-G02-P03-03 | Verificación | valor actual = último estado del historial | estado_actual Autorizada, igual al historial | Autorizada | OK |
| 126 | G02-P03-V-02 | AC-G02-P03-02 | Verificación | promesa original, actual y número de cambios | original 2026-11-10 17:00, actual 2026-11-13 12:00, 2 reprogramaciones | original 2026-11-10 17:00:00-06, actual 2026-11-13 12:00:00-06, 2 reprogramaciones | OK |
| 127 | G02-P03-V-02 | AC-G02-P03-02 | Verificación | cada cambio conserva la fecha anterior (no se sobrescribe) | fecha_anterior(n) = fecha_nueva(n-1) en toda la cadena | 1: NULL -> 2026-11-10 17:00:00-06 \| 2: 2026-11-10 17:00:00-06 -> 2026-11-12 17:00:00-06 \| 3: 2026-11-12 17:00:00-06 -> 2026-11-13 12:00:00-06 | OK |
| 128 | G02-P03-I-01 | AC-G02-P03-03 | Rechazo | cambio de estado de orden inexistente | Rechazo: la orden 99999 no existe | P0001: G02-P03: la orden 99999 no existe | OK |
| 129 | G02-P03-I-01 | AC-G02-P03-03 | Rechazo | cambio de promesa de orden inexistente | Rechazo: la orden 99999 no existe | P0001: G02-P03: la orden 99999 no existe | OK |
| 130 | G02-P03-I-02 | AC-G02-P03-02 | Rechazo | reprogramar 9006 sin motivo | Rechazo: requiere motivo | P0001: G02-P03: el cambio de fecha prometida de la orden 9006 requiere motivo (RN-07) | OK |
| 131 | G02-P03-I-02 | AC-G02-P03-02 | Rechazo | reprogramar 9006 con motivo vacío | Rechazo: requiere motivo | P0001: G02-P03: el cambio de fecha prometida de la orden 9006 requiere motivo (RN-07) | OK |
| 132 | G02-P03-I-02 | AC-G02-P03-02 | Verificación | sin efectos en la promesa de 9006 | promesa 2026-11-09 12:00 y 1 fila de historial | 2026-11-09 12:00:00-06 y 1 fila(s) | OK |
| 133 | G02-P03-I-03 | AC-G02-P03-01 | Rechazo | retroceso Autorizada -> En diagnóstico sin motivo | Rechazo: requiere motivo | P0001: G02-P03: la transición Autorizada -> En diagnóstico requiere motivo | OK |
| 134 | G02-P03-I-03 | AC-G02-P03-01 | Verificación | sin efectos en 9005 | Autorizada con 8 filas de historial | Autorizada con 8 filas | OK |
| 135 | G02-P03-I-04 | AC-G02-P03-03 | Rechazo | UPDATE directo de fecha_prometida_actual | Rechazo: solo cambian mediante su historial | P0001: G02-P03: estado_actual y fecha_prometida_actual de la orden 9006 solo cambian mediante su historial (use fn_cambiar_estado_orden / fn_cambiar_fecha_prometida) | OK |
| 136 | G02-P03-I-04 | AC-G02-P03-03 | Rechazo | UPDATE directo de estado_actual | Rechazo: solo cambian mediante su historial | P0001: G02-P03: estado_actual y fecha_prometida_actual de la orden 9006 solo cambian mediante su historial (use fn_cambiar_estado_orden / fn_cambiar_fecha_prometida) | OK |
| 137 | G02-P03-I-04 | AC-G02-P03-03 | Verificación | valores actuales de 9006 intactos | Recibida / 2026-11-09 12:00 | Recibida / 2026-11-09 12:00:00-06 | OK |
| 138 | G02-P03-I-05 | AC-G02-P03-03 | Rechazo | fallo inducido a mitad del registro | Rechazo: objetos/daños sin confirmar | P0001: G02-P03: la orden 9006 tiene objetos/daños sin confirmar por el cliente (RN-06) | OK |
| 139 | G02-P03-I-05 | AC-G02-P03-03 | Verificación | ni historial ni valor actual cambiaron | Recibida, promesa 2026-11-09 12:00, 1 + 1 filas | Recibida, 2026-11-09 12:00:00-06, 1 + 1 filas | OK |
| 140 | G02-P03-I-06 | AC-G02-P03-01 | Rechazo | Recibida -> Autorizada (salta diagnóstico) | Rechazo: transición no permitida | P0001: G02-P03: transición no permitida de Recibida a Autorizada en la orden 9006 | OK |
| 141 | G02-P03-I-06 | AC-G02-P03-01 | Rechazo | Autorizada -> Autorizada | Rechazo: ya está en Autorizada | P0001: G02-P03: la orden 9005 ya está en Autorizada | OK |
| 142 | G02-P03-I-06 | AC-G02-P03-01 | Rechazo | estado fuera del dominio | Rechazo: d_estado_orden | 23514: value for domain d_estado_orden violates check constraint "ck_d_estado_orden" | OK |
| 143 | G02-P03-I-07 | AC-G02-P03-03 | Rechazo | INSERT con secuencia inventada | Rechazo: la secuencia la asigna el sistema | P0001: G02-P03: la secuencia la asigna el sistema (esperada 9, indicada 50) | OK |
| 144 | G02-P03-I-07 | AC-G02-P03-03 | Rechazo | INSERT con estado_anterior falso | Rechazo: estado_anterior lo asigna el sistema | P0001: G02-P03: estado_anterior lo asigna el sistema (actual Autorizada, indicado Lista entrega) | OK |
| 145 | G02-P03-I-07 | AC-G02-P03-01 | Rechazo | cambio con fecha anterior al último | Rechazo: anterior al último cambio | P0001: G02-P03: la fecha_hora 2026-11-01 10:00:00-06 es anterior al último cambio de estado (2026-11-07 11:30:00-06) | OK |
| 146 | G02-P03-I-07 | AC-G02-P03-03 | Rechazo | UPDATE de una fila del historial | Rechazo: solo inserción | P0001: G02-INM: historial_orden es de solo inserción; no se permite UPDATE (registre una fila nueva) | OK |
| 147 | G02-P03-I-07 | AC-G02-P03-02 | Rechazo | DELETE de una promesa | Rechazo: solo inserción | P0001: G02-INM: historial_fecha_prometida es de solo inserción; no se permite DELETE (registre una fila nueva) | OK |
| 148 | G02-P03-I-07 | AC-G02-P03-01 | Rechazo | cambio registrado por personal inactivo | Rechazo: no está activo | P0001: G02-P03: cambio de estado: el personal 207 no está activo | OK |
| 149 | G02-P03-I-07 | AC-G02-P03-03 | Verificación | historial de 9005 intacto | 8 estados y 3 promesas | 8 estados y 3 promesas | OK |
| 150 | G02-P03-L-01 | AC-G02-P03-04 | Verificación | mismo instante ordenado por secuencia | 1:Recibida,2:En diagnóstico,3:Cancelada (2 y 3 con la misma fecha_hora) | 1:Recibida@11:00,2:En diagnóstico@09:00,3:Cancelada@09:00 | OK |
| 151 | G02-P03-L-01 | AC-G02-P03-04 | Verificación | promesas del mismo instante ordenadas por secuencia | secuencias 1,2,3; la vigente es la de secuencia 3 (15:00) | 1:09 12:00,2:10 12:00,3:10 15:00 | OK |
| 152 | G02-P03-L-02 | AC-G02-P03-04 | Verificación | orden cancelada consultable con toda su historia | Cancelada; 3 estados y 3 promesas visibles | Cancelada; 3 estados y 3 promesas | OK |
| 153 | G02-P03-L-02 | AC-G02-P03-04 | Rechazo | reabrir una orden Cancelada | Rechazo: transición no permitida de Cancelada | P0001: G02-P03: transición no permitida de Cancelada a En diagnóstico en la orden 9006 | OK |
| 154 | G02-P03-L-02 | AC-G02-P03-04 | Rechazo | reprogramar una orden Cancelada | Rechazo: está Cancelada | P0001: G02-P03: la orden 9006 está Cancelada; su fecha prometida ya no se modifica | OK |
| 155 | G02-P03-L-02 | AC-G02-P03-04 | Rechazo | borrar la orden cancelada | Rechazo: no se elimina | P0001: G02-INT: la orden 9006 no se elimina; use el estado Cancelada | OK |
| 156 | G02-P03-L-03 | AC-G02-P03-02 | Verificación | primera promesa sin motivo = promesa original | secuencia 1, fecha_anterior NULL, actual 2026-11-08 17:00 | secuencia 1, anterior NULL, nueva 2026-11-08 17:00:00-06 | OK |
| 157 | G02-P03-L-04 | AC-G02-P03-01 | Verificación | retrocesos admitidos y todos con motivo obligatorio | >= 5 retrocesos, todos con motivo | 6 retrocesos; con motivo: true | OK |
| 158 | G02-P03-A-01 | AC-G02-P03-03 | Rechazo | bloque con fallo al final | Rechazo: ck_hfp_promesa_futura | 23514: new row for relation "historial_fecha_prometida" violates check constraint "ck_hfp_promesa_futura" | OK |
| 159 | G02-P03-A-01 | AC-G02-P03-03 | Verificación | nada quedó del bloque fallido | Autorizada / 2026-11-13 12:00 / 8 estados / 3 promesas | Autorizada / 2026-11-13 12:00:00-06 / 8 estados / 3 promesas | OK |
| 160 | G02-P03-A-02 | AC-G02-P03-03 | Rechazo | saltarse la rutina activando la variable a mano | Rechazo: no coincide con su historial | P0001: G02-P03: estado_actual (En reparación) de la orden 9013 no coincide con su historial (Recibida) | OK |
| 161 | G02-P03-A-02 | AC-G02-P03-03 | Verificación | 9013 sigue coherente | Recibida | Recibida | OK |
| 162 | G02-INT-01 | RN-04 | Rechazo | identificación duplicada | Rechazo: uq_cliente_identificacion | 23505: duplicate key value violates unique constraint "uq_cliente_identificacion" | OK |
| 163 | G02-INT-01 | RN-04 | Rechazo | tipo de cliente fuera de dominio | Rechazo: ck_cliente_tipo | 23514: new row for relation "cliente" violates check constraint "ck_cliente_tipo" | OK |
| 164 | G02-INT-01 | RN-04 | Rechazo | nombre vacío | Rechazo: ck_cliente_nombre | 23514: new row for relation "cliente" violates check constraint "ck_cliente_nombre" | OK |
| 165 | G02-INT-02 | RN-03 | Rechazo | cliente sin contacto apto para avisos (al COMMIT) | Rechazo: debe tener al menos un contacto apto para avisos | P0001: G02-INT: el cliente 904 debe tener al menos un contacto apto para avisos (RN-03) | OK |
| 166 | G02-INT-02 | RN-03 | Rechazo | cliente con contacto que NO recibe avisos (al COMMIT) | Rechazo: debe tener al menos un contacto apto para avisos | P0001: G02-INT: el cliente 905 debe tener al menos un contacto apto para avisos (RN-03) | OK |
| 167 | G02-INT-02 | RN-03 | Rechazo | quitar el único contacto apto de María (al COMMIT) | Rechazo: el cliente 101 debe tener al menos un contacto apto | P0001: G02-INT: el cliente 101 debe tener al menos un contacto apto para avisos (RN-03) | OK |
| 168 | G02-INT-02 | RN-03 | Rechazo | correo con formato inválido | Rechazo: ck_contacto_formato | 23514: new row for relation "contacto_cliente" violates check constraint "ck_contacto_formato" | OK |
| 169 | G02-INT-02 | RN-03 | Rechazo | teléfono con formato inválido | Rechazo: ck_contacto_formato | 23514: new row for relation "contacto_cliente" violates check constraint "ck_contacto_formato" | OK |
| 170 | G02-INT-02 | RN-03 | Verificación | cliente nuevo con contacto apto confirmado | todo cliente tiene >= 1 contacto apto | 9 clientes, todos con contacto apto | OK |
| 171 | G02-INT-03 | RN-02 | Rechazo | VIN con letra O (no permitida) | Rechazo: ck_vehiculo_vin | 23514: new row for relation "vehiculo" violates check constraint "ck_vehiculo_vin" | OK |
| 172 | G02-INT-03 | RN-02 | Rechazo | VIN de 16 caracteres | Rechazo: ck_vehiculo_vin | 23514: new row for relation "vehiculo" violates check constraint "ck_vehiculo_vin" | OK |
| 173 | G02-INT-03 | RN-02 | Rechazo | año mayor que el actual + 1 | Rechazo: supera el año actual + 1 | P0001: G02-INT: el año 2028 del vehículo 1HGCM82633A999999 supera el año actual + 1 | OK |
| 174 | G02-INT-03 | RN-02 | Rechazo | reescribir el VIN | Rechazo: identidad estable | P0001: G02-INT: el VIN 1HGCM82633A123456 es la identidad estable del vehículo y no se modifica (RN-02) | OK |
| 175 | G02-INT-04 | RN-02 | Verificación | la placa cambia sin afectar la visita previa | vehículo PQR999; orden 9006 ingresó con PQR678 | vehículo PQR999; orden 9006 ingresó con PQR678 | OK |
| 176 | G02-INT-05 | RN-02 | Rechazo | dos propietarios en el mismo periodo | Rechazo: ex_propiedad_sin_traslape | 23P01: conflicting key value violates exclusion constraint "ex_propiedad_sin_traslape" | OK |
| 177 | G02-INT-05 | RN-04 | Rechazo | reescribir a quién se facturó una visita anterior | Rechazo: quedan fijados por visita | P0001: G02-INT: los datos de recepción y los roles de la orden 9006 quedan fijados por visita y no se modifican | OK |
| 178 | G02-INT-05 | RN-04 | Verificación | el cambio de propietario no reescribe la visita | propietario actual Laura (107); visita 9006 facturada a Ana (104) | propietario actual 107; visita 9006 facturada a 104 | OK |
| 179 | G02-INT-06 | RN-01 | Rechazo | segunda visita abierta del mismo vehículo | Rechazo: uq_orden_abierta_por_vehiculo | 23505: duplicate key value violates unique constraint "uq_orden_abierta_por_vehiculo" | OK |
| 180 | G02-INT-06 | RN-05 | Rechazo | kilometraje de ingreso negativo | Rechazo: ck_orden_km_ingreso | 23514: new row for relation "orden_trabajo" violates check constraint "ck_orden_km_ingreso" | OK |
| 181 | G02-INT-06 | RN-05 | Rechazo | nivel de combustible fuera de dominio | Rechazo: ck_orden_combustible | 23514: new row for relation "orden_trabajo" violates check constraint "ck_orden_combustible" | OK |
| 182 | G02-INT-06 | RN-08 | Rechazo | orden sin estado inicial en el historial (al COMMIT) | Rechazo: no tiene su estado inicial | P0001: G02-P03: la orden 9904 no tiene su estado inicial en historial_orden | OK |
| 183 | G02-INT-06 | RN-08 | Rechazo | orden que nace en un estado distinto de Recibida | Rechazo: inicia en Recibida | P0001: G02-P03: una orden nueva inicia en Recibida (se indicó Autorizada) | OK |
| 184 | G02-INT-06 | RN-05 | Rechazo | reescribir el kilometraje de ingreso | Rechazo: quedan fijados por visita | P0001: G02-INT: los datos de recepción y los roles de la orden 9001 quedan fijados por visita y no se modifican | OK |
| 185 | G02-INT-06 | RN-01 | Verificación | alta del Lab03 sobre el modelo nuevo | placa KLM789, Recibida, historial secuencia 1, 2 facultades del titular | KLM789, Recibida, 1 estado(s), 2 facultades | OK |
| 186 | G02-INT-06 | RN-05 | Rechazo | alta del Lab03 con kilometraje negativo (validación propia del Lab03) | Rechazo: no puede ser negativo | P0001: El kilometraje de ingreso no puede ser negativo ni nulo | OK |
| 187 | G02-INT-07 | RN-04 | Rechazo | designación otorgada por quien no es el titular | Rechazo: solo el titular de la orden 9002 | P0001: G02-INT: solo el titular de la orden 9002 (cliente 103) puede designar o hacerse representar | OK |
| 188 | G02-INT-07 | RN-04 | Rechazo | misma facultad vigente duplicada | Rechazo: ex_facultad_sin_traslape | 23P01: conflicting key value violates exclusion constraint "ex_facultad_sin_traslape" | OK |
| 189 | G02-INT-07 | RN-04 | Rechazo | titular con otorgante | Rechazo: ck_facultad_otorgante | 23514: new row for relation "facultad_orden" violates check constraint "ck_facultad_otorgante" | OK |
| 190 | G02-INT-07 | RN-04 | Rechazo | facultad vigente antes de la recepción | Rechazo: antes de la recepción | P0001: G02-INT: la facultad no puede regir antes de la recepción de la orden 9001 | OK |
| 191 | G02-INT-07 | RN-04 | Rechazo | borrar una facultad | Rechazo: no se elimina | P0001: G02-INM: la facultad 1 no se elimina; revóquela fijando vigente_hasta | OK |
| 192 | G02-INT-08 | RN-06 | Rechazo | reescribir la descripción de un daño | Rechazo: solo admite confirmación | P0001: G02-INM: el detalle 1 solo admite confirmación del cliente | OK |
| 193 | G02-INT-08 | RN-06 | Rechazo | desconfirmar un objeto | Rechazo: solo admite confirmación | P0001: G02-INM: el detalle 2 solo admite confirmación del cliente | OK |
| 194 | G02-INT-08 | RN-06 | Rechazo | borrar un objeto o daño | Rechazo: no se elimina | P0001: G02-INM: el detalle 3 de objetos/daños no se elimina | OK |
| 195 | G02-INT-09 | RN-09 | Rechazo | hallazgo sin autor | Rechazo: diagnosticado_por_id | 23502: null value in column "diagnosticado_por_id" of relation "hallazgo" violates not-null constraint | OK |
| 196 | G02-INT-09 | RN-09 | Rechazo | autor que no es técnico | Rechazo: tiene rol Recepción y se requiere Técnico | P0001: G02-INT: autor del hallazgo: el personal 201 tiene rol Recepción y se requiere Técnico | OK |
| 197 | G02-INT-09 | RN-09 | Rechazo | hallazgo anterior a la recepción | Rechazo: anterior a la recepción | P0001: G02-INT: el hallazgo no puede ser anterior a la recepción de la orden 9014 | OK |
| 198 | G02-INT-09 | RN-09 | Rechazo | cambiar el autor de un hallazgo | Rechazo: no se modifican | P0001: G02-INT: la orden, el autor y el momento del hallazgo 4101 no se modifican | OK |
| 199 | G02-INT-09 | RN-09 | Rechazo | urgencia fuera de dominio | Rechazo: ck_hallazgo_urgencia | 23514: new row for relation "hallazgo" violates check constraint "ck_hallazgo_urgencia" | OK |
| 200 | G02-INT-10 | RN-14 | Rechazo | especialidad traslapada | Rechazo: ex_especialidad_sin_traslape | 23P01: conflicting key value violates exclusion constraint "ex_especialidad_sin_traslape" | OK |
| 201 | G02-INT-10 | RN-14 | Rechazo | especialidad a personal que no es técnico | Rechazo: solo un Técnico tiene especialidades | P0001: G02-INT: especialidad: el personal 205 tiene rol Otro y solo un Técnico tiene especialidades | OK |
| 202 | G02-INT-10 | RN-14 | Rechazo | fin anterior al inicio | Rechazo: ck_especialidad_vigencia | 23514: new row for relation "especialidad_tecnico" violates check constraint "ck_especialidad_vigencia" | OK |
| 203 | G02-INT-10 | RN-14 | Rechazo | quitar el rol Técnico con especialidades vigentes | Rechazo: tiene especialidades vigentes | P0001: G02-INT: el personal 203 tiene especialidades vigentes; cierre su vigencia antes de cambiar el rol | OK |
| 204 | G02-INT-10 | RN-14 | Verificación | renovación sin traslape aceptada | 2 periodos de Frenos para Andrés | 2023-01-01..2025-12-31, 2026-12-01..∞ | OK |
| 205 | G02-INT-11 | RN-17 | Rechazo | código interno con formato inválido | Rechazo: ck_repuesto_codigo | 23514: new row for relation "repuesto" violates check constraint "ck_repuesto_codigo" | OK |
| 206 | G02-INT-11 | RN-17 | Rechazo | unidad de manejo fuera de dominio | Rechazo: ck_repuesto_unidad | 23514: new row for relation "repuesto" violates check constraint "ck_repuesto_unidad" | OK |
| 207 | G02-INT-11 | RN-17 | Rechazo | mismo código de proveedor dos veces en el mismo proveedor | Rechazo: uq_prov_rep_codigo | 23505: duplicate key value violates unique constraint "uq_prov_rep_codigo" | OK |
| 208 | G02-INT-11 | RN-17 | Rechazo | precio de referencia negativo | Rechazo: ck_prov_rep_precio | 23514: new row for relation "proveedor_repuesto" violates check constraint "ck_prov_rep_precio" | OK |
| 209 | G02-INT-11 | RN-17 | Rechazo | proveedor duplicado | Rechazo: uq_proveedor_nombre | 23505: duplicate key value violates unique constraint "uq_proveedor_nombre" | OK |
| 210 | G02-INT-11 | RN-17 | Verificación | mismo código de proveedor en proveedores distintos | 2 proveedores con el código BOS-0986-494 | 2:FR-001, 1:FR-003 | OK |
| 211 | G02-INT-12 | RN-19 | Rechazo | ajuste negativo mayor que la existencia física | Rechazo: existencias insuficientes de FR-003 | P0001: G02-INT: existencias insuficientes de FR-003: el movimiento dejaría -4.00 físicas | OK |
| 212 | G02-INT-12 | RN-19 | Rechazo | reserva mayor que lo disponible | Rechazo: disponibles | P0001: G02-INT: existencias insuficientes de FR-003: el movimiento dejaría -1.00 disponibles (físico 1.00, reservado 2.00) | OK |
| 213 | G02-INT-12 | RN-19 | Rechazo | liberar más de lo reservado por la orden | Rechazo: no se puede liberar | P0001: G02-INT: no se puede liberar 1.00 de FR-003; la orden 9014 solo tiene 0 reservado | OK |
| 214 | G02-INT-12 | RN-19 | Rechazo | reserva sin orden | Rechazo: ck_movimiento_orden | 23514: new row for relation "movimiento_inventario" violates check constraint "ck_movimiento_orden" | OK |
| 215 | G02-INT-12 | RN-19 | Rechazo | ajuste sin motivo | Rechazo: ck_movimiento_ajuste_motivo | 23514: new row for relation "movimiento_inventario" violates check constraint "ck_movimiento_ajuste_motivo" | OK |
| 216 | G02-INT-12 | RN-19 | Rechazo | cantidad cero | Rechazo: ck_movimiento_cantidad | 23514: new row for relation "movimiento_inventario" violates check constraint "ck_movimiento_cantidad" | OK |
| 217 | G02-INT-12 | RN-19 | Rechazo | modificar un movimiento | Rechazo: solo inserción | P0001: G02-INM: movimiento_inventario es de solo inserción; no se permite UPDATE (registre una fila nueva) | OK |
| 218 | G02-INT-12 | RN-19 | Verificación | ninguna existencia física ni disponible es negativa | todas las existencias >= 0 | EL-001=2.00/2.00, EL-002=0/0, FR-001=9.00/9.00, FR-002=6.00/6.00, FR-003=1.00/1.00, LP-001=5.00/5.00, MG-001=6.00/6.00, MG-002=21.00/21.00 | OK |
| 219 | G02-INT-13 | RN-18 | Rechazo | pieza retirada de una labor de OTRA orden | Rechazo: fk_pieza_labor | 23503: insert or update on table "pieza_retirada" violates foreign key constraint "fk_pieza_labor" | OK |
| 220 | G02-INT-13 | RN-18 | Rechazo | pieza de una labor que no se ejecutó | Rechazo: no tiene piezas retiradas | P0001: G02-INT: la labor 519 está Pendiente; no tiene piezas retiradas | OK |
| 221 | G02-INT-13 | RN-18 | Rechazo | destino fuera de dominio | Rechazo: ck_pieza_destino | 23514: new row for relation "pieza_retirada" violates check constraint "ck_pieza_destino" | OK |
| 222 | G02-INT-14 | RN-18 | Verificación | una consulta distingue los cuatro conceptos | Presupuesto, Reserva, Liberación, Consumo y Pieza en la orden 9003 | Consumo, Liberación de reserva, Pieza retirada, Presupuesto, Reserva | OK |
| 223 | G02-INT-15 | RN-15 | Rechazo | dependencia circular | Rechazo: formaría un ciclo | P0001: G02-P02: la dependencia 515 -> 517 formaría un ciclo | OK |
| 224 | G02-INT-15 | RN-15 | Rechazo | dependencia con una labor de otra orden | Rechazo: fk_dependencia_requerida | 23503: insert or update on table "labor_dependencia" violates foreign key constraint "fk_dependencia_requerida" | OK |
| 225 | G02-INT-15 | RN-15 | Rechazo | labor que depende de sí misma | Rechazo: ck_dependencia_distinta | 23514: new row for relation "labor_dependencia" violates check constraint "ck_dependencia_distinta" | OK |
| 226 | G02-INT-15 | RN-15 | Verificación | una labor con dos dependencias | 2 dependencias | 2 dependencias | OK |
| 227 | G02-INT-16 | RN-20 | Rechazo | entregar una orden que no está Lista entrega | Rechazo: no está Lista entrega | P0001: G02-INT: la orden 9014 no está Lista entrega (estado: En diagnóstico) | OK |
| 228 | G02-INT-16 | RN-20 | Rechazo | retira una persona sin facultad Retirar | Rechazo: el cliente 108 no tiene facultad vigente para retirar | P0001: G02-INT: el cliente 108 no tiene facultad vigente para retirar el vehículo de la orden 9007 | OK |
| 229 | G02-INT-16 | RN-20 | Rechazo | retira con la facultad Aprobar (no Retirar) | Rechazo: no tiene facultad vigente para retirar | P0001: G02-INT: el cliente 107 no tiene facultad vigente para retirar el vehículo de la orden 9007 | OK |
| 230 | G02-INT-16 | RN-20 | Rechazo | kilometraje de salida menor que el de ingreso | Rechazo: menor que el de ingreso | P0001: G02-INT: el kilometraje de salida (29990) es menor que el de ingreso (30000) | OK |
| 231 | G02-INT-16 | RN-20 | Rechazo | entrega anterior a la recepción | Rechazo: no tiene facultad vigente para retirar | P0001: G02-INT: el cliente 107 no tiene facultad vigente para retirar el vehículo de la orden 9007 | OK |
| 232 | G02-INT-16 | RN-20 | Rechazo | inconforme sin observaciones | Rechazo: ck_entrega_inconformidad | 23514: new row for relation "entrega" violates check constraint "ck_entrega_inconformidad" | OK |
| 233 | G02-INT-16 | RN-20 | Rechazo | segunda entrega de la misma orden | Rechazo: uq_entrega_orden | 23505: duplicate key value violates unique constraint "uq_entrega_orden" | OK |
| 234 | G02-INT-16 | RN-20 | Verificación | entrega válida con facultad Retirar y orden Entregada | facultad Retirar; orden Entregada | facultad Retirar; orden Entregada | OK |
| 235 | G02-INT-17 | RN-22 | Rechazo | garantía sobre una labor no completada | Rechazo: solo se otorga garantía sobre labores Completadas | P0001: G02-INT: solo se otorga garantía sobre labores Completadas (la labor 529 está Pendiente) | OK |
| 236 | G02-INT-17 | RN-22 | Rechazo | garantía sobre una labor de otra orden | Rechazo: fk_garantia_labor | 23503: insert or update on table "garantia" violates foreign key constraint "fk_garantia_labor" | OK |
| 237 | G02-INT-17 | RN-22 | Rechazo | garantía sin ningún límite | Rechazo: ck_garantia_limite | 23514: new row for relation "garantia" violates check constraint "ck_garantia_limite" | OK |
| 238 | G02-INT-18 | RN-22 | Rechazo | aceptar un reclamo fuera del límite de km (vence lo primero) | Rechazo: dentro del límite de km: no | P0001: G02-INT: garantía 1 vencida (vence lo primero): dentro del plazo de días: sí; dentro del límite de km: no; el reclamo solo puede registrarse como Rechazada con justificación (RN-22) | OK |
| 239 | G02-INT-18 | RN-22 | Rechazo | rechazar sin justificación | Rechazo: ck_reclamo_justificacion | 23514: new row for relation "reclamo_garantia" violates check constraint "ck_reclamo_justificacion" | OK |
| 240 | G02-INT-18 | RN-21 | Rechazo | kilometraje del reclamo distinto al de ingreso de la orden nueva | Rechazo: debe ser el de ingreso de la orden nueva | P0001: G02-INT: el kilometraje del reclamo (30500) debe ser el de ingreso de la orden nueva 9010 (31600) | OK |
| 241 | G02-INT-18 | RN-22 | Rechazo | aceptar un reclamo fuera del límite de días (vence lo primero) | Rechazo: dentro del plazo de días: no | P0001: G02-INT: garantía 2 vencida (vence lo primero): dentro del plazo de días: no; dentro del límite de km: sí; el reclamo solo puede registrarse como Rechazada con justificación (RN-22) | OK |
| 242 | G02-INT-18 | RN-21 | Rechazo | reclamo con orden de OTRO vehículo | Rechazo: no del vehículo garantizado | P0001: G02-INT: la orden nueva 9009 es del vehículo WVWZZZ1JZXW000001, no del vehículo garantizado 5YJ3E1EA7KF000001 | OK |
| 243 | G02-INT-18 | RN-21 | Rechazo | reclamo sobre la misma orden garantizada | Rechazo: debe abrir una orden nueva | P0001: G02-INT: el reclamo debe abrir una orden nueva, distinta de la orden garantizada (RN-21) | OK |
| 244 | G02-INT-18 | RN-21 | Rechazo | segundo reclamo con la misma orden nueva | Rechazo: uq_reclamo_orden_nueva | 23505: duplicate key value violates unique constraint "uq_reclamo_orden_nueva" | OK |
| 245 | G02-INT-18 | RN-21 | Rechazo | reevaluar un reclamo ya decidido | Rechazo: solo se reevalúa mientras está Pendiente | P0001: G02-INM: el reclamo 8 solo se reevalúa mientras está Pendiente | OK |
| 246 | G02-INT-18 | RN-22 | Verificación | garantía sin reclamo existe; G1 con un reclamo rechazado y uno aceptado | G2 sin reclamos; G1: Rechazada, Aceptada | G2 0 reclamos; G1: Rechazada,Aceptada | OK |
| 247 | G02-INT-19 | D5 | Verificación | Q04 cuenta las órdenes por estado y coincide con estado_actual | Q04 = conteo por estado_actual | Autorizada:2, Cancelada:2, En diagnóstico:3, En reparación:1, Entregada:1, Recibida:6 | OK |
| 248 | G02-INT-19 | D5 | Verificación | Q02 cuenta visitas por vehículo (el Tesla tiene 3: 9007, 9008, 9010) | STU901: 3 visitas | STU901: 3 visitas | OK |
| 249 | G02-INT-20 | D4 | Verificación | todas las órdenes: valor actual = última fila de cada historial | 0 órdenes incoherentes | 15 órdenes revisadas | OK |
| 250 | G02-INT-20 | D9 | Verificación | todas las labores: estado = última fila de su historial | 0 labores incoherentes | 22 labores revisadas | OK |
