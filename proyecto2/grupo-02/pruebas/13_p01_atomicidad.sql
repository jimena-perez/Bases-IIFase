-- =====================================================================
-- G02-P01 · ATOMICIDAD de la publicación de versiones
-- Una versión con UN detalle inválido no deja NADA: ni propuesta, ni
-- labores nuevas, ni líneas, ni repuestos estimados, ni dependencias, y la
-- numeración de versiones no salta.
-- =====================================================================
SET search_path = taller, public;
SET TIME ZONE 'America/Costa_Rica';

-- Conteos de referencia de la orden 9001 antes de los intentos.
SELECT (SELECT count(*) FROM propuesta WHERE orden_id = 9001)        AS propuestas,
       (SELECT count(*) FROM labor WHERE orden_id = 9001)            AS labores,
       (SELECT count(*) FROM linea_propuesta WHERE orden_id = 9001)  AS lineas,
       (SELECT count(*) FROM repuesto_propuesto rp JOIN propuesta p USING (propuesta_id) WHERE p.orden_id = 9001) AS repuestos_estimados,
       (SELECT count(*) FROM labor_dependencia WHERE orden_id = 9001) AS dependencias;

-- ===========================================================
-- ID: G02-P01-A-01     Criterio: AC-G02-P01-01
-- Acción: versión con 2 labores nuevas válidas (una con repuesto) y una
--   tercera línea con PRECIO NEGATIVO.
-- Esperado: rechazo "no puede ser negativo"; conteos idénticos.
-- ===========================================================
SELECT pruebas.esperar_rechazo('G02-P01-A-01', 'AC-G02-P01-01', 'versión con una línea de precio negativo',
     $q$ SELECT fn_publicar_propuesta(9001, pruebas.propuesta_id(9001, 4),
            '[{"descripcion":"Rotación de llantas","precio_estimado":8000},
              {"descripcion":"Cambio de bombillo de freno","precio_estimado":3000,
               "repuestos":[{"repuesto_id":"LP-001","cantidad":1,"precio_unitario":1000}]},
              {"descripcion":"Lavado de motor","precio_estimado":-500}]'::jsonb,
            205, NULL, '2026-11-03 11:00') $q$,
     'no puede ser negativo');

-- ===========================================================
-- ID: G02-P01-A-02     Criterio: AC-G02-P01-01, AC-G02-P01-03
-- Acción: versión cuya primera línea crea una labor y una dependencia
--   válidas y cuya segunda línea cita un HALLAZGO DE OTRA ORDEN (4103, de 9002).
-- Esperado: rechazo "no pertenece a la orden 9001"; la labor de la primera
--   línea tampoco queda.
-- ===========================================================
SELECT pruebas.esperar_rechazo('G02-P01-A-02', 'AC-G02-P01-01', 'versión con hallazgo de otra orden en la segunda línea',
     $q$ SELECT fn_publicar_propuesta(9001, NULL,
            '[{"clave":"X","descripcion":"Ajuste de frenos traseros","hallazgo_id":4101,"precio_estimado":9000},
              {"descripcion":"Filtro ajeno","hallazgo_id":4103,"precio_estimado":5000,"requiere":["X"]}]'::jsonb,
            205, NULL, '2026-11-03 11:00') $q$,
     'el hallazgo 4103 no pertenece a la orden 9001');

-- ===========================================================
-- ID: G02-P01-A-03     Criterio: AC-G02-P01-01
-- Acción: versión con un repuesto estimado INEXISTENTE en la última línea.
-- Esperado: rechazo por la FK fk_rep_prop_repuesto; nada queda.
-- ===========================================================
SELECT pruebas.esperar_rechazo('G02-P01-A-03', 'AC-G02-P01-01', 'versión con repuesto inexistente',
     $q$ SELECT fn_publicar_propuesta(9001, NULL,
            '[{"descripcion":"Cambio de amortiguadores","precio_estimado":40000,
               "repuestos":[{"repuesto_id":"ZZ-999","cantidad":2,"precio_unitario":30000}]}]'::jsonb,
            205, NULL, '2026-11-03 11:00') $q$,
     'fk_rep_prop_repuesto');

SELECT pruebas.verificar('G02-P01-A-01', 'AC-G02-P01-01', 'conteos iguales tras los tres intentos fallidos',
     (SELECT count(*) = 4 FROM propuesta WHERE orden_id = 9001)
     AND (SELECT count(*) = 4 FROM labor WHERE orden_id = 9001)
     AND (SELECT count(*) = 6 FROM linea_propuesta WHERE orden_id = 9001)
     AND (SELECT count(*) = 0 FROM labor_dependencia WHERE orden_id = 9001),
     '4 propuestas, 4 labores, 6 líneas, 0 dependencias',
     (SELECT count(*) FROM propuesta WHERE orden_id = 9001) || ' propuestas, '
     || (SELECT count(*) FROM labor WHERE orden_id = 9001) || ' labores, '
     || (SELECT count(*) FROM linea_propuesta WHERE orden_id = 9001) || ' líneas, '
     || (SELECT count(*) FROM labor_dependencia WHERE orden_id = 9001) || ' dependencias');

-- La numeración no salta: la siguiente publicación válida obtiene la v5.
SELECT fn_publicar_propuesta(9001, pruebas.propuesta_id(9001, 4),
  '[{"descripcion":"Rotación de llantas","precio_estimado":8000,"alcance":"Rotación en cruz"}]'::jsonb,
  205, 'Ampliación válida tras los intentos fallidos', '2026-11-03 11:10');
SELECT pruebas.verificar('G02-P01-A-01', 'AC-G02-P01-01', 'la siguiente versión válida es la 5 (sin huecos)',
     (SELECT array_agg(version ORDER BY version) = ARRAY[1, 2, 3, 4, 5] FROM propuesta WHERE orden_id = 9001),
     '{1,2,3,4,5}', (SELECT array_agg(version ORDER BY version)::text FROM propuesta WHERE orden_id = 9001));
