# G02-P02 · Concurrencia (dos sesiones)

**Precondición:** base construida con `sql/run_all.sql` y preparación cargada con `00_preparacion_concurrencia.sql`. Esta deja la orden **9012** con tres labores aceptadas en proceso, una de ellas ("Revisión de calipers") con una participación cerrada, y **una sola unidad** de FR-003.

| Escenario | Qué demuestra | Mecanismo |
|---|---|---|
| **C1** | A completa una labor mientras B registra una participación sobre ella: B espera y luego es **rechazada** porque la labor ya está Completada. No se pierde ninguna participación ni queda una participación sobre una labor completada. | `FOR UPDATE` de la fila de `labor` en todas las rutinas y triggers de ejecución. |
| **C2** | Dos consumos simultáneos de la última unidad en dos labores distintas: uno se confirma y el otro falla por existencias; el stock final es 0, nunca negativo. | El trigger de inventario bloquea la fila de `repuesto` (`FOR UPDATE`) y recalcula las existencias después de obtener el bloqueo (READ COMMITTED: cada sentencia ve lo ya confirmado). |

## Pasos para el video

1. **Terminal A:** `\i pruebas/concurrencia/P02_C1_sesion_A.sql`. Completa la labor y retiene el bloqueo.
2. **Terminal B**, de inmediato: `\i pruebas/concurrencia/P02_C1_sesion_B.sql`. B queda esperando.
3. Cuando A hace `COMMIT`, B recibe `G02-P02: la labor … no está En proceso (estado: Completada)` y su `COMMIT` termina en `ROLLBACK`.
4. La consulta final muestra la labor Completada con su única participación.

Repetir con `P02_C2_sesion_A.sql` y `P02_C2_sesion_B.sql`: B recibe `existencias insuficientes de FR-003`, y la consulta final muestra físico 0 con un solo consumo y su movimiento.

## Ejecución automática

```bash
psql -d taller_ruta27 -f pruebas/concurrencia/P02_C1_sesion_A.sql > a.txt 2>&1 & sleep 1; psql -d taller_ruta27 -f pruebas/concurrencia/P02_C1_sesion_B.sql > b.txt 2>&1; wait
```
