# Evidencias de concurrencia (dos sesiones reales)

> Generado el 2026-11-16 04:07 UTC. Cada escenario lanza la **sesión A** (`psql` en segundo plano, retiene el bloqueo 3 s con `pg_sleep`) y, 1 s después, la **sesión B** en otro proceso `psql`. Las marcas `HH24:MI:SS.MS` muestran la espera real de B. Ver `pruebas/concurrencia/*_instrucciones.md`.

## Preparación (`00_preparacion_concurrencia.sql`)

```text
SET
SET
BEGIN
 fn_cambiar_estado_orden 
-------------------------
                      59
(1 row)

 fn_cambiar_estado_orden 
-------------------------
                      60
(1 row)

 fn_publicar_propuesta 
-----------------------
                   323
(1 row)

 fn_cambiar_estado_orden 
-------------------------
                      61
(1 row)

 fn_registrar_decision 
-----------------------
                   633
                   634
                   635
(3 rows)

 fn_cambiar_estado_orden 
-------------------------
                      62
(1 row)

 fn_cambiar_estado_orden 
-------------------------
                      63
(1 row)

 fn_iniciar_labor 
------------------
               63
               64
               65
(3 rows)

 fn_registrar_participacion 
----------------------------
                         25
(1 row)

COMMIT
 orden_id | estado_actual  | fecha_prometida_actual 
----------+----------------+------------------------
     9011 | En diagnóstico | 
     9012 | En reparación  | 
     9013 | Recibida       | 2026-11-12 17:00:00-06
(3 rows)

 labor_id |             descripcion             | estado_labor 
----------+-------------------------------------+--------------
      530 | Cambio de disco delantero izquierdo | En proceso
      531 | Cambio de disco delantero derecho   | En proceso
      532 | Revisión de calipers                | En proceso
(3 rows)

 repuesto_id | fisico | reservado | disponible 
-------------+--------+-----------+------------
 FR-003      |   1.00 |         0 |       1.00
(1 row)

```

## G02-P01-C1

### Sesión A

```text
SET
SET
SESIÓN A – paso 1: BEGIN y publicar versión (toma el bloqueo de la orden 9011)
BEGIN
   a_inicio   
--------------
 22:07:48.515
(1 row)

 propuesta_a 
-------------
         324
(1 row)

 version_obtenida_por_a 
------------------------
                      1
(1 row)

SESIÓN A – paso 2: retiene el bloqueo 3 s (en el video: esperar a que B quede bloqueada)
 pg_sleep 
----------
 
(1 row)

SESIÓN A – paso 3: COMMIT
COMMIT
   a_commit   
--------------
 22:07:51.530
(1 row)

```

### Sesión B

```text
SET
SET
SESIÓN B – paso 1: BEGIN y publicar versión (queda esperando el bloqueo de A)
BEGIN
  b_solicita  
--------------
 22:07:49.516
(1 row)

 propuesta_b 
-------------
         325
(1 row)

 b_obtiene_bloqueo_y_termina 
-----------------------------
 22:07:51.538
(1 row)

SESIÓN B – paso 2: COMMIT
COMMIT
Consulta final (datos confirmados)
 version |   estado   |        observacion        
---------+------------+---------------------------
       1 | Presentada | Publicada por la sesión A
       2 | Presentada | Publicada por la sesión B
(2 rows)

```

## G02-P01-C2

### Sesión A

```text
SET
SET
SESIÓN A – paso 1: BEGIN y aceptar "Cambio de pastillas delanteras" (v1 de 9011)
BEGIN
   a_inicio   
--------------
 22:07:51.576
(1 row)

 fn_registrar_decision 
-----------------------
                   636
(1 row)

SESIÓN A – paso 2: retiene el bloqueo de la línea 3 s
 pg_sleep 
----------
 
(1 row)

SESIÓN A – paso 3: COMMIT
COMMIT
```

### Sesión B

```text
SET
SET
SESIÓN B – paso 1: BEGIN y rechazar la misma línea (queda esperando)
BEGIN
  b_solicita  
--------------
 22:07:52.574
(1 row)

 fn_registrar_decision 
-----------------------
                   637
(1 row)

  b_termina   
--------------
 22:07:54.592
(1 row)

SESIÓN B – paso 2: COMMIT
COMMIT
Consulta final: historia de decisiones de la línea y decisión aplicable
 autorizacion_id | decision  |  medio   |    observacion    | confirmada_en 
-----------------+-----------+----------+-------------------+---------------
             636 | Aceptada  | Teléfono | Sesión A: acepta  | 22:07:51.579
             637 | Rechazada | Correo   | Sesión B: rechaza | 22:07:54.588
(2 rows)

 labor_id |          descripcion           | version_vigente |  situacion  | autorizacion_id 
----------+--------------------------------+-----------------+-------------+-----------------
      533 | Cambio de pastillas delanteras |               1 | Rechazada   |             637
      534 | Revisión de líquido de frenos  |               2 | Sin decidir |                
(2 rows)

```

## G02-P01-C3

### Sesión A

```text
SET
SET
SESIÓN A – paso 1: BEGIN y aceptar "Revisión de líquido de frenos" (v2) esperando "Sin decidir"
BEGIN
 fn_registrar_decision 
-----------------------
                   638
(1 row)

SESIÓN A – paso 2: retiene el bloqueo 3 s
 pg_sleep 
----------
 
(1 row)

SESIÓN A – paso 3: COMMIT
COMMIT
```

### Sesión B

```text
SET
SET
SESIÓN B – paso 1: BEGIN y rechazar esperando "Sin decidir" (queda esperando)
BEGIN
psql:/home/user/bases-iifase/proyecto2/grupo-02/pruebas/concurrencia/P01_C3_sesion_B.sql:11: ERROR:  G02-P01: conflicto de concurrencia: se esperaba "Sin decidir" y la decisión vigente de la línea es "Aceptada"
CONTEXT:  PL/pgSQL function fn_error(text) line 3 at RAISE
SQL statement "SELECT fn_error(format('G02-P01: conflicto de concurrencia: se esperaba "%s" y la decisión vigente de la línea es "%s"',
                                    p_decision_esperada, v_actual))"
PL/pgSQL function fn_registrar_decision(bigint,bigint,bigint,text,text,bigint,timestamp with time zone,text,text) line 35 at PERFORM
SESIÓN B – paso 2: COMMIT (tras el error, PostgreSQL revierte: ROLLBACK)
ROLLBACK
Consulta final: solo quedó la decisión de A
 autorizacion_id | decision | observacion 
-----------------+----------+-------------
             638 | Aceptada | Sesión A
(1 row)

```

## G02-P02-C1

### Sesión A

```text
SET
SET
SESIÓN A – paso 1: BEGIN y completar la labor (toma el bloqueo de la labor)
BEGIN
   a_inicio   
--------------
 22:07:57.676
(1 row)

 fn_completar_labor 
--------------------
                 68
(1 row)

SESIÓN A – paso 2: retiene el bloqueo 3 s
 pg_sleep 
----------
 
(1 row)

SESIÓN A – paso 3: COMMIT
COMMIT
```

### Sesión B

```text
SET
SET
SESIÓN B – paso 1: BEGIN y registrar participación (queda esperando)
BEGIN
  b_solicita  
--------------
 22:07:58.676
(1 row)

psql:/home/user/bases-iifase/proyecto2/grupo-02/pruebas/concurrencia/P02_C1_sesion_B.sql:13: ERROR:  G02-P02: la labor 532 no está En proceso (estado: Completada)
CONTEXT:  PL/pgSQL function fn_error(text) line 3 at RAISE
SQL statement "SELECT fn_error(format('G02-P02: la labor %s no está En proceso (estado: %s)', NEW.labor_id, v_labor.estado_labor))"
PL/pgSQL function fn_participacion_validar() line 25 at PERFORM
SQL statement "INSERT INTO participacion_tecnica (labor_id, orden_id, tecnico_id, especialidad_id, inicio, fin,
                                       minutos_efectivos, descripcion_participacion)
    VALUES (p_labor_id, v_labor.orden_id, p_tecnico_id, p_especialidad_id, p_inicio, p_fin,
            p_minutos_efectivos, p_descripcion)
    RETURNING participacion_id"
PL/pgSQL function fn_registrar_participacion(bigint,bigint,timestamp with time zone,timestamp with time zone,integer,text,bigint) line 7 at SQL statement
SESIÓN B – paso 2: COMMIT (tras el error: ROLLBACK)
ROLLBACK
Consulta final
 labor_id |     descripcion      | estado_labor | participaciones 
----------+----------------------+--------------+-----------------
      532 | Revisión de calipers | Completada   |               1
(1 row)

```

## G02-P02-C2

### Sesión A

```text
SET
SET
SESIÓN A – paso 1: BEGIN y consumir 1 FR-003 en "Cambio de disco delantero izquierdo"
BEGIN
   a_inicio   
--------------
 22:08:00.723
(1 row)

 consumo_a 
-----------
        13
(1 row)

SESIÓN A – paso 2: retiene el bloqueo del repuesto 3 s
 pg_sleep 
----------
 
(1 row)

SESIÓN A – paso 3: COMMIT
COMMIT
```

### Sesión B

```text
SET
SET
SESIÓN B – paso 1: BEGIN y consumir 1 FR-003 en "Cambio de disco delantero derecho" (queda esperando)
BEGIN
  b_solicita  
--------------
 22:08:01.722
(1 row)

psql:/home/user/bases-iifase/proyecto2/grupo-02/pruebas/concurrencia/P02_C2_sesion_B.sql:12: ERROR:  G02-INT: existencias insuficientes de FR-003: el movimiento dejaría -1.00 físicas
CONTEXT:  PL/pgSQL function fn_error(text) line 3 at RAISE
SQL statement "SELECT fn_error(format('G02-INT: existencias insuficientes de %s: el movimiento dejaría %s físicas',
                                NEW.repuesto_id, v_fisico))"
PL/pgSQL function fn_movimiento_validar() line 59 at PERFORM
SQL statement "INSERT INTO movimiento_inventario (repuesto_id, orden_id, tipo_movimiento, cantidad, fecha_hora,
                                       consumo_id, registrado_por_id, motivo)
    VALUES (p_repuesto_id, p_orden_id, 'Consumo', p_cantidad, p_fecha_hora, v_consumo_id, p_personal_id,
            format('Consumo en la labor %s', p_labor_id))"
PL/pgSQL function fn_registrar_consumo(bigint,bigint,text,numeric,numeric,bigint,timestamp with time zone) line 35 at SQL statement
SESIÓN B – paso 2: COMMIT (tras el error: ROLLBACK)
ROLLBACK
Consulta final
 repuesto_id | fisico | reservado | disponible 
-------------+--------+-----------+------------
 FR-003      |   0.00 |         0 |       0.00
(1 row)

 consumo_id |             descripcion             | cantidad_utilizada | movimiento_id | tipo_movimiento 
------------+-------------------------------------+--------------------+---------------+-----------------
         13 | Cambio de disco delantero izquierdo |               1.00 |           820 | Consumo
(1 row)

```

## G02-P03-C1

### Sesión A

```text
SET
SET
SESIÓN A – paso 1: BEGIN y reprogramar a dentro de 3 días
BEGIN
   a_inicio   
--------------
 22:08:03.775
(1 row)

 fn_cambiar_fecha_prometida 
----------------------------
                         20
(1 row)

SESIÓN A – paso 2: retiene el bloqueo 3 s
 pg_sleep 
----------
 
(1 row)

SESIÓN A – paso 3: COMMIT
COMMIT
```

### Sesión B

```text
SET
SET
SESIÓN B – paso 1: BEGIN y reprogramar a dentro de 4 días (queda esperando)
BEGIN
  b_solicita  
--------------
 22:08:04.786
(1 row)

 fn_cambiar_fecha_prometida 
----------------------------
                         21
(1 row)

  b_termina   
--------------
 22:08:06.789
(1 row)

SESIÓN B – paso 2: COMMIT
COMMIT
Consulta final
 secuencia |     fecha_anterior     |      fecha_nueva       | medio_comunicacion |                   motivo                    
-----------+------------------------+------------------------+--------------------+---------------------------------------------
         1 |                        | 2026-11-12 17:00:00-06 | Presencial         | Promesa original comunicada en la recepción
         2 | 2026-11-12 17:00:00-06 | 2026-11-18 22:00:00-06 | Teléfono           | Sesión A: espera de repuesto
         3 | 2026-11-18 22:00:00-06 | 2026-11-19 22:00:00-06 | Correo             | Sesión B: ajuste de agenda del taller
(3 rows)

 orden_id | fecha_prometida_actual 
----------+------------------------
     9013 | 2026-11-19 22:00:00-06
(1 row)

```

## G02-P03-C2

### Sesión A

```text
SET
SET
SESIÓN A – paso 1: BEGIN y Recibida -> En diagnóstico (esperando Recibida)
BEGIN
 fn_cambiar_estado_orden 
-------------------------
                      64
(1 row)

SESIÓN A – paso 2: retiene el bloqueo 3 s
 pg_sleep 
----------
 
(1 row)

SESIÓN A – paso 3: COMMIT
COMMIT
```

### Sesión B

```text
SET
SET
SESIÓN B – paso 1: BEGIN y cancelar esperando Recibida (queda esperando)
BEGIN
psql:/home/user/bases-iifase/proyecto2/grupo-02/pruebas/concurrencia/P03_C2_sesion_B.sql:9: ERROR:  G02-P03: conflicto de concurrencia: se esperaba el estado "Recibida" y la orden 9013 está en "En diagnóstico"
CONTEXT:  PL/pgSQL function fn_error(text) line 3 at RAISE
SQL statement "SELECT fn_error(format('G02-P03: conflicto de concurrencia: se esperaba el estado "%s" y la orden %s está en "%s"',
                                p_estado_esperado, p_orden_id, v_orden.estado_actual))"
PL/pgSQL function fn_cambiar_estado_orden(bigint,text,bigint,text,timestamp with time zone,text) line 9 at PERFORM
SESIÓN B – paso 2: COMMIT (tras el error: ROLLBACK)
ROLLBACK
Consulta final
 secuencia | estado_anterior |     estado     | motivo 
-----------+-----------------+----------------+--------
         1 |                 | Recibida       | 
         2 | Recibida        | En diagnóstico | 
(2 rows)

```
