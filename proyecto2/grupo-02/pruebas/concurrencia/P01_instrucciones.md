# G02-P01 · Concurrencia (dos sesiones)

**Precondición:** base construida con `sql/run_all.sql` y preparación cargada con `00_preparacion_concurrencia.sql`. La preparación usa la orden **9011**, que la batería de pruebas no toca.

Abrir **dos terminales `psql`** conectadas a la misma base (`taller_ruta27`), ambas desde `proyecto2/grupo-02`.

| Escenario | Qué demuestra | Mecanismo |
|---|---|---|
| **C1** | Dos sesiones publican versión sobre la misma orden a la vez: B espera el bloqueo y obtiene `version + 1`; no se pierde ninguna publicación. | Bloqueo pesimista `SELECT … FOR UPDATE` de la orden en `fn_publicar_propuesta`, más `UNIQUE (orden_id, version)` como respaldo. |
| **C2** | A acepta y B rechaza la misma línea: quedan serializadas, las dos filas se conservan y la decisión aplicable es la última confirmada (B). | `FOR UPDATE` de la fila de `linea_propuesta`. |
| **C3** | Variante optimista: B indica que esperaba "Sin decidir"; al ver que A ya aceptó, B es **rechazada explícitamente** en lugar de sobrescribir. | `p_decision_esperada` en `fn_registrar_decision`. |

## Pasos para el video (C1; C2 y C3 son iguales con sus archivos)

1. **Terminal A:** `\i pruebas/concurrencia/P01_C1_sesion_A.sql`. Ejecuta `BEGIN`, publica la versión y retiene el bloqueo 3 s con `pg_sleep(3)`. Si se quiere más tiempo para la explicación, se puede subir ese valor en el script.
2. **Terminal B**, mientras A espera: `\i pruebas/concurrencia/P01_C1_sesion_B.sql`. B **queda bloqueada** en la publicación.
3. **Terminal A:** el script hace `COMMIT` al terminar la espera.
4. **Terminal B:** se desbloquea y obtiene la **versión 2**. Su consulta final muestra v1 (de A) y v2 (de B).

Las marcas `HH24:MI:SS.MS` (`b_solicita` → `b_obtiene_bloqueo_y_termina`) muestran la espera real de B.

## Ejecución automática (la que generó `resultados/concurrencia.md`)

Desde `proyecto2/grupo-02`, sesión A en segundo plano y B un segundo después:

```bash
psql -d taller_ruta27 -f pruebas/concurrencia/P01_C1_sesion_A.sql > a.txt 2>&1 & sleep 1; psql -d taller_ruta27 -f pruebas/concurrencia/P01_C1_sesion_B.sql > b.txt 2>&1; wait
```
