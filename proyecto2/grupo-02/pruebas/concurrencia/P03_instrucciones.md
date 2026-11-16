# G02-P03 · Concurrencia (dos sesiones)

**Precondición:** base construida con `sql/run_all.sql` y preparación cargada con `00_preparacion_concurrencia.sql`. Se usa la orden **9013**, en estado Recibida y con promesa original 2026-11-12 17:00.

Se muestran los **dos escenarios** que piden las instrucciones:

| Escenario | Qué demuestra | Mecanismo |
|---|---|---|
| **C1** | A y B reprograman la promesa de la misma orden: B espera y se aplica **después** de A. Los dos cambios quedan en la historia en el orden confirmado y la `fecha_anterior` de B es la fecha de A, así que no hay pérdida silenciosa. | Bloqueo pesimista de la orden (`FOR UPDATE`) en el trigger del historial; `secuencia` asignada bajo ese bloqueo. |
| **C2** | A cambia el estado; B intenta cancelar indicando que esperaba "Recibida": al obtener el bloqueo ve "En diagnóstico" y es **rechazada explícitamente**. | Control optimista `p_estado_esperado` (análogo a `p_fecha_esperada` para la promesa). |

## Pasos para el video

1. **Terminal A:** `\i pruebas/concurrencia/P03_C1_sesion_A.sql`.
2. **Terminal B**, mientras A retiene el bloqueo: `\i pruebas/concurrencia/P03_C1_sesion_B.sql`. B queda bloqueada.
3. A confirma y B se aplica después. La consulta final muestra las secuencias 1 (original), 2 (A) y 3 (B), con la cadena de `fecha_anterior` intacta.
4. Repetir con `P03_C2_sesion_A.sql` y `P03_C2_sesion_B.sql`: B recibe `G02-P03: conflicto de concurrencia: se esperaba el estado "Recibida" y la orden 9013 está en "En diagnóstico"`.

**Justificación del mecanismo:** el bloqueo pesimista evita la pérdida de actualizaciones sin pedirle nada al cliente que llama. El valor esperado (optimista) sirve cuando la decisión de quien llama depende del valor que vio, como una pantalla desactualizada: en ese caso es preferible rechazar a aplicar un cambio basado en un dato viejo. Las dos rutinas aceptan ambos modos.

## Ejecución automática

```bash
psql -d taller_ruta27 -f pruebas/concurrencia/P03_C1_sesion_A.sql > a.txt 2>&1 & sleep 1; psql -d taller_ruta27 -f pruebas/concurrencia/P03_C1_sesion_B.sql > b.txt 2>&1; wait
```
