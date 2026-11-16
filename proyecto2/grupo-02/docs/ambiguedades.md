# Ambigüedades, preguntas y supuestos

**IC-4301 · Proyecto 2 · Grupo 02 · Taller Ruta 27**

Formato: **fragmento** (del caso, de las reglas RN del Proyecto 1 o de las instrucciones de esta entrega) · **pregunta** · **supuesto adoptado** · **impacto** en el modelo y las pruebas.

Ningún supuesto contradice el caso ni excluye una situación: cuando hubo dos lecturas posibles se eligió la que **conserva más información** y **no convierte una urgencia en autorización automática**.

> Nota de fuentes: el anexo del grupo remite a `00_Enunciado_General.md` y a `Control_de_Cambios_Especificacion.md`, que **no están** en este repositorio ni en el del curso (`jimena-perez/bd1-2026-2s`, rama `main` y ramas del Lab03). Los fragmentos citados provienen de las reglas RN-01…RN-22 del Proyecto 1 y de las instrucciones de la 2.ª entrega. Si esos documentos fijan otra cosa, prevalecen (ver A-15).

---

### A-01 · Retrabajo y autorización
- **Fragmento:** RN-15 "dependencia y revisión de labores sin borrar"; RN-12 "rechazada no se ejecuta; emergencia mínima con justificación".
- **Pregunta:** tras una prueba desfavorable, ¿la nueva intervención queda cubierta por la autorización original de la labor?
- **Supuesto:** **no automáticamente**. El retrabajo es una labor nueva (`labor_revisada_id` + `prueba_origen_id`) que necesita **su propia línea** en una versión nueva (puede ser a precio 0, "sin costo para el cliente") y una decisión *Aceptada*, o una excepción de emergencia si hay riesgo.
- **Impacto:** `fn_registrar_retrabajo` crea la labor en estado *Pendiente*; `fn_iniciar_labor` exige su propia autorización. Prueba **G02-P02-V-01** (retrabajo con v2 a precio 0 y aceptación).

### A-02 · Decisión "Pendiente" explícita vs. ausencia de decisión
- **Fragmento:** RN-11 "autorización por labor (aceptada / rechazada / pendiente, fecha, medio, quién)".
- **Pregunta:** ¿"Pendiente" es una decisión que se registra o simplemente la falta de decisión?
- **Supuesto:** son **dos situaciones distintas** y las dos se representan:
  - *Pendiente* es una fila explícita: el cliente fue consultado y difirió su respuesta, con quién, medio y fecha.
  - *Sin decidir* es que no hay ninguna fila sobre la línea de la versión vigente.

  Ninguna de las dos es ejecutable.
- **Impacto:** `v_situacion_labor.situacion` toma los valores Sin propuesta, Sin decidir, Pendiente, Aceptada o Rechazada. Pruebas **G02-P01-V-02**, **G02-P01-L-03** y **G02-P01-L-04**.

### A-03 · Versión que "retira" una labor
- **Fragmento:** RN-10 "versiones de propuesta sin pérdida".
- **Pregunta:** si una versión nueva no incluye una labor que estaba en la anterior, ¿esa labor queda retirada?
- **Supuesto:** **no**. Una versión nueva puede ser una ampliación parcial, y omitir una labor no la retira: su versión vigente sigue siendo la anterior y conserva su decisión (regla 4 de la decisión aplicable). Para retirar una labor se usa **`fn_anular_labor`**, que la pasa a *Anulada* con motivo en su historial, sin borrar nada. Una labor anulada no puede ofrecerse ni ejecutarse.
- **Impacto:** evita retiros implícitos y silenciosos. Pruebas **G02-P01-V-03** y **G02-P01-L-02**.

### A-04 · Reapertura de órdenes terminales
- **Fragmento:** estados "Entregada" y "Cancelada"; RN-21 "reclamo abre nueva orden".
- **Pregunta:** ¿una orden Entregada o Cancelada puede reabrirse?
- **Supuesto:** **no**. Los dos estados son terminales: el catálogo no tiene transiciones que salgan de ellos (`ck_transicion_terminal`). Un trabajo posterior abre una **orden nueva**, y si es un reclamo de garantía se vincula con `reclamo_garantia`.
- **Impacto:** las órdenes terminales no admiten propuestas, labores ni cambios de promesa; la orden y toda su historia siguen consultables. Prueba **G02-P03-L-02**.

### A-05 · Relación reserva–consumo
- **Fragmento:** RN-18 "estimado ≠ consumido"; RN-19 "movimientos y disponibilidad".
- **Pregunta:** si la orden tenía un repuesto reservado, ¿el consumo descuenta de la reserva o del disponible general?
- **Supuesto:** el consumo **usa primero la reserva de esa orden**. En la misma transacción se registra una *Liberación* por lo consumido (hasta lo reservado) y luego el *Consumo*. Así el stock físico baja una vez y el reservado no queda "colgado".
- **Impacto:** `fn_registrar_consumo`; `v_existencias` y `v_insumos_orden`. Prueba **G02-P02-V-01** (FR-001: físico 9, reservado 0).

### A-06 · Completar una labor con prueba desfavorable
- **Fragmento:** RN-16 "pruebas (qué, quién, cuándo, resultado)".
- **Pregunta:** ¿se puede completar una labor cuya última prueba fue *Desfavorable*? ¿Es obligatoria una prueba para completar?
- **Supuesto:** para completar se exige:
  1. al menos una participación cerrada;
  2. ninguna participación abierta;
  3. si la **última** prueba es *Desfavorable*, un **retrabajo ligado a esa prueba y ya Completado**.

  No se exige que toda labor tenga una prueba (hay labores, como un cambio de escobillas, donde el caso no la pide).
- **Impacto:** trigger `fn_historial_labor_antes`. Pruebas **G02-P02-V-01**, **G02-P02-A-02** y **G02-P02-L-04**.

### A-07 · Persona facultada que no es el cliente titular
- **Fragmento:** RN-04 "distinguir quien entrega, a quién se factura y quién está facultado para aprobar"; revisión del P1: "identificar a quien responde no demuestra su facultad".
- **Pregunta:** ¿quién puede aprobar o retirar, y cómo se acredita?
- **Supuesto:**
  - El **titular** de la visita es el cliente al que se factura. Recibe por defecto las facultades *Aprobar* y *Retirar*, con fuente *Titular*.
  - Otra persona solo puede tenerlas por **Designación** o **Representación legal**, otorgada por el titular, con un medio de verificación y una vigencia.
  - El `autorizador_cliente_id` de la orden (heredado del Lab03), si es distinto del titular, se registra como *Designación*.
  - Una facultad puede revocarse fijando `vigente_hasta`, una sola vez.
- **Impacto:** `facultad_orden`; triggers de autorización y entrega. Pruebas **G02-P01-I-01**, **G02-P01-I-07**, **G02-INT-07** y **G02-INT-16**.

### A-08 · ¿El titular conserva la facultad si designa a otra persona?
- **Fragmento:** RN-04.
- **Pregunta:** si el titular designa a otra persona para aprobar, ¿puede seguir aprobando él mismo?
- **Supuesto:** **sí**. La designación agrega una facultad, no quita la del titular.
- **Impacto:** en la orden 9002, tanto Ana (designada) como Transportes del Valle (titular) pueden aprobar. Pruebas **G02-P01-I-07** y **G02-P01-L-01**.

### A-09 · Decisión sobre una versión obsoleta
- **Fragmento:** regla de "decisión aplicable" (instrucciones §5.1.1).
- **Pregunta:** ¿se puede registrar una decisión sobre la línea de una versión que ya no es la vigente para esa labor?
- **Supuesto:** **no**. Solo se decide sobre la versión vigente de la labor, porque una decisión sobre una versión superada no puede aplicarse y solo induciría a error.
- **Impacto:** trigger `fn_autorizacion_validar`. Prueba **G02-P01-I-05**.

### A-10 · Órdenes simultáneas del mismo vehículo
- **Fragmento:** RN-01 "una orden = una visita de un vehículo".
- **Pregunta:** ¿puede un vehículo tener dos visitas abiertas a la vez?
- **Supuesto:** **no**. Se usa un índice único parcial sobre `vin` para las órdenes no terminales. Un reclamo de garantía abre la orden nueva cuando la anterior ya está *Entregada*.
- **Impacto:** `uq_orden_abierta_por_vehiculo`. Pruebas **G02-INT-06** y **G02-INT-18** (la orden 9010 se cancela antes de abrir la 9008).

### A-11 · Estados de la orden ligados a hechos del proceso
- **Fragmento:** estados Pendiente autorización, Autorizada, Lista entrega y Entregada.
- **Pregunta:** ¿el estado de la orden es libre o debe corresponder a hechos registrados?
- **Supuesto:** cuatro transiciones exigen el hecho que las justifica:
  - *Pendiente autorización* exige una propuesta presentada;
  - *Autorizada* exige al menos una labor con decisión aplicable *Aceptada*;
  - *Lista entrega* exige ninguna labor en proceso o suspendida y al menos una completada;
  - *Entregada* exige una entrega registrada.

  Además, salir de *Recibida* exige los objetos y daños confirmados (RN-06).

  No se impone una prohibición universal de retroceso: el catálogo admite 6 retrocesos, todos con motivo.
- **Impacto:** trigger `fn_historial_orden_antes`. Pruebas **G02-P03-V-01**, **G02-P03-I-05**, **G02-P03-L-04** y **G02-INT-16**.

### A-12 · Primera promesa de una orden recibida sin fecha
- **Fragmento:** RN-07 "cambios de fecha prometida con fecha comunicada, motivo y responsable, sin sobrescribir".
- **Pregunta:** si la orden ingresó sin fecha prometida, ¿la primera promesa exige motivo?
- **Supuesto:** **no**. La primera fila es la *promesa original* (`fecha_anterior` NULL). El motivo es obligatorio en toda **reprogramación**.
- **Impacto:** `ck_hfp_motivo`. Prueba **G02-P03-L-03**.

### A-13 · Kilometraje del reclamo de garantía
- **Fragmento:** RN-22 "garantía vence lo que ocurra primero".
- **Pregunta:** ¿con qué kilometraje se evalúa el límite de km?
- **Supuesto:** con el **kilometraje de ingreso de la orden nueva** que abre el reclamo, comparado con el kilometraje de salida de la entrega. Si el reclamo indica un km distinto, se rechaza. El plazo de días se cuenta desde la fecha y hora de la entrega.
- **Impacto:** trigger `fn_reclamo_validar`. Pruebas **G02-INT-18** (fuera de km, fuera de días y dentro de ambos límites).

### A-14 · Quién autoriza una emergencia
- **Fragmento:** RN-12 "emergencia mínima con justificación".
- **Pregunta:** ¿quién puede autorizar una excepción de emergencia?
- **Supuesto:** personal activo con rol *Técnico* u *Otro* (por ejemplo, jefatura de taller), con una justificación de al menos 20 caracteres, el riesgo y el alcance mínimo. La excepción habilita **solo** su labor, que se crea marcada como `es_emergencia`; no toca la propuesta ni las demás labores.
- **Impacto:** `fn_registrar_emergencia` y `excepcion_emergencia`. Prueba **G02-P02-L-02**.

### A-15 · Documentos comunes ausentes y criterios AC
- **Fragmento:** instrucciones §0.1 (`00_Enunciado_General.md`, `Control_de_Cambios_Especificacion.md`) y "AC-G02-P0x-01…04 (ver anexo)".
- **Pregunta:** ¿qué ruta, formato del control de cambios y texto exacto de los criterios AC aplican?
- **Supuesto:**
  - ruta `proyecto2/grupo-02/`;
  - formato del Control de Cambios según §9.2 de las instrucciones;
  - los criterios AC-G02-P0x-01…04 se **redactaron a partir de lo que pide cada proceso** (tabla en el README §7). Deben contrastarse con el anexo oficial antes de entregar.
- **Impacto:** si el anexo redacta distinto los AC, solo cambia la columna *Criterio* de las pruebas; las pruebas no cambian.

### A-16 · Resultados en formato `.md`
- **Fragmento:** instrucciones §8.1 (`resultados/*.txt`); validación automática del repositorio del curso (solo `.md`, `.sql`, `.pdf` e imágenes).
- **Pregunta:** ¿en qué formato se guardan las salidas de ejecución?
- **Supuesto:** como **`.md`**, con la salida real dentro de bloques de código, para no ser rechazadas si la entrega pasa por la validación automática del curso.
- **Impacto:** `resultados/*.md`.
