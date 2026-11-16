-- =====================================================================
-- G02-P01 · Versionar propuestas y autorizar labores · LÍMITE
-- Se muestra con v_situacion_labor qué decisión aplica en cada caso.
-- =====================================================================
SET search_path = taller, public;
SET TIME ZONE 'America/Costa_Rica';

-- ===========================================================
-- ID: G02-P01-L-01     Criterio: AC-G02-P01-04
-- Preparación: en 9002 el filtro fue Aceptado en v1 (por Ana).
-- Acción: v2 que SOLO cambia su precio (12000 -> 10000).
-- Esperado: el filtro queda "Sin decidir" en v2 (no se arrastra la
--   aceptación de v1) y deja de ser ejecutable hasta una nueva decisión;
--   el titular (Transportes) acepta sobre v2 y vuelve a ser ejecutable con
--   el autorizacion_id de v2.
-- ===========================================================
SELECT fn_publicar_propuesta(9002, pruebas.propuesta_id(9002, 1),
  ('[{"labor_id":' || pruebas.labor_id(9002, 'Cambio de filtro') || ',"precio_estimado":10000,"alcance":"Precio de flota"}]')::jsonb,
  205, 'Tarifa de flota', '2026-11-03 14:00');
SELECT labor_id, version_vigente, precio_vigente, situacion, autorizacion_id
FROM v_situacion_labor WHERE orden_id = 9002;
SELECT pruebas.verificar('G02-P01-L-01', 'AC-G02-P01-04', 'v2 solo-precio: la aceptación de v1 no se arrastra',
     (SELECT situacion = 'Sin decidir' AND version_vigente = 2 FROM v_situacion_labor WHERE labor_id = pruebas.labor_id(9002, 'Cambio de filtro'))
     AND NOT EXISTS (SELECT 1 FROM v_autorizacion_ejecutable WHERE orden_id = 9002),
     'v2 Sin decidir y sin autorización ejecutable',
     (SELECT 'v' || version_vigente || ' ' || situacion FROM v_situacion_labor WHERE labor_id = pruebas.labor_id(9002, 'Cambio de filtro'))
     || '; ejecutables: ' || (SELECT count(*) FROM v_autorizacion_ejecutable WHERE orden_id = 9002));
SELECT fn_registrar_decision(pruebas.propuesta_id(9002, 2), pruebas.labor_id(9002, 'Cambio de filtro'),
                             103, 'Aceptada', 'Correo', 201, '2026-11-03 14:30', 'Aprobado por la jefatura de flota');
SELECT pruebas.verificar('G02-P01-L-01', 'AC-G02-P01-04', 'tras decidir sobre v2, la ejecutable es la de v2',
     (SELECT e.autorizacion_id = a.autorizacion_id AND e.version = 2
      FROM v_autorizacion_ejecutable e JOIN autorizacion_labor a ON a.propuesta_id = pruebas.propuesta_id(9002, 2)
      WHERE e.labor_id = pruebas.labor_id(9002, 'Cambio de filtro')),
     'autorización ejecutable = decisión de v2',
     (SELECT 'v' || version || ', autorizacion_id ' || autorizacion_id FROM v_autorizacion_ejecutable WHERE orden_id = 9002));

-- ===========================================================
-- ID: G02-P01-L-02     Criterio: AC-G02-P01-01, AC-G02-P01-04
-- v2 que SOLO añade una labor: ver G02-P01-V-03. Aquí se verifica de nuevo
-- que A, B y C de 9001 conservan su versión vigente y decisión de v1, y que
-- v2 contiene una sola línea.
-- ===========================================================
SELECT pruebas.verificar('G02-P01-L-02', 'AC-G02-P01-01', 'v2 de 9001 contiene solo la labor añadida',
     (SELECT count(*) = 1 FROM linea_propuesta WHERE propuesta_id = pruebas.propuesta_id(9001, 2))
     AND (SELECT situacion = 'Aceptada' AND version_vigente = 1 FROM v_situacion_labor WHERE labor_id = pruebas.labor_id(9001, 'Cambio de pastillas')),
     'v2 con 1 línea; A sigue vigente en v1 y Aceptada',
     (SELECT count(*) FROM linea_propuesta WHERE propuesta_id = pruebas.propuesta_id(9001, 2)) || ' línea(s); A v'
     || (SELECT version_vigente || ' ' || situacion FROM v_situacion_labor WHERE labor_id = pruebas.labor_id(9001, 'Cambio de pastillas')));

-- ===========================================================
-- ID: G02-P01-L-03     Criterio: AC-G02-P01-04
-- Preparación: orden 9014 (Jorge Quesada, titular).
-- Acción: v1 con 3 labores: E Aceptada, F con decisión explícita
--   "Pendiente" y G SIN ninguna decisión.
-- Esperado: situaciones Aceptada / Pendiente / Sin decidir. Ni la Pendiente
--   ni la Sin decidir son ejecutables (documentado en README §6.1: ambas
--   cuentan como "no autorizada"; la Pendiente además deja constancia de
--   que el cliente fue consultado).
-- ===========================================================
SELECT fn_cambiar_estado_orden(9014, 'En diagnóstico', 204, NULL, '2026-11-08 10:30');
SELECT fn_publicar_propuesta(9014, NULL,
  '[{"descripcion":"Cambio de aceite y filtro","hallazgo_id":4115,"precio_estimado":15000,
     "repuestos":[{"repuesto_id":"MG-002","cantidad":4,"precio_unitario":7200}]},
    {"descripcion":"Cambio de filtro de aire","hallazgo_id":4116,"precio_estimado":6000,
     "repuestos":[{"repuesto_id":"MG-001","cantidad":1,"precio_unitario":9000}]},
    {"descripcion":"Cambio de escobillas","hallazgo_id":4117,"precio_estimado":4000,
     "repuestos":[{"repuesto_id":"LP-001","cantidad":1,"precio_unitario":8500}]}]'::jsonb,
  205, NULL, '2026-11-08 12:00');
SELECT fn_registrar_decision(pruebas.propuesta_id(9014, 1), pruebas.labor_id(9014, 'Cambio de aceite'),
                             106, 'Aceptada', 'Presencial', 206, '2026-11-08 12:30');
SELECT fn_registrar_decision(pruebas.propuesta_id(9014, 1), pruebas.labor_id(9014, 'Cambio de filtro'),
                             106, 'Pendiente', 'Presencial', 206, '2026-11-08 12:31', 'Lo decide mañana');
SELECT labor_id, descripcion, situacion, autorizacion_id FROM v_situacion_labor WHERE orden_id = 9014 ORDER BY labor_id;
SELECT pruebas.verificar('G02-P01-L-03', 'AC-G02-P01-04', 'decisiones incompletas',
     (SELECT string_agg(situacion, ',' ORDER BY labor_id) = 'Aceptada,Pendiente,Sin decidir' FROM v_situacion_labor WHERE orden_id = 9014)
     AND (SELECT count(*) = 1 FROM v_autorizacion_ejecutable WHERE orden_id = 9014),
     'Aceptada,Pendiente,Sin decidir; 1 ejecutable',
     (SELECT string_agg(situacion, ',' ORDER BY labor_id) FROM v_situacion_labor WHERE orden_id = 9014)
     || '; ' || (SELECT count(*) FROM v_autorizacion_ejecutable WHERE orden_id = 9014) || ' ejecutable(s)');
SELECT pruebas.esperar_rechazo('G02-P01-L-03', 'AC-G02-P01-04', 'iniciar la labor Pendiente',
     $q$ SELECT fn_iniciar_labor(pruebas.labor_id(9014, 'Cambio de filtro'), 204, '2026-11-08 13:00') $q$,
     'situación: Pendiente');
SELECT pruebas.esperar_rechazo('G02-P01-L-03', 'AC-G02-P01-04', 'iniciar la labor Sin decidir',
     $q$ SELECT fn_iniciar_labor(pruebas.labor_id(9014, 'Cambio de escobillas'), 204, '2026-11-08 13:00') $q$,
     'situación: Sin decidir');

-- ===========================================================
-- ID: G02-P01-L-04     Criterio: AC-G02-P01-02, AC-G02-P01-04
-- Acción: Jorge cambia de opinión sobre F en la MISMA línea:
--   Pendiente (12:31) -> Aceptada (2026-11-09 08:00).
-- Esperado: se agrega una fila (la Pendiente se conserva) y la aplicable
--   es la última: Aceptada.
-- ===========================================================
SELECT fn_registrar_decision(pruebas.propuesta_id(9014, 1), pruebas.labor_id(9014, 'Cambio de filtro'),
                             106, 'Aceptada', 'Teléfono', 206, '2026-11-09 08:00', 'Confirma el cambio de filtro', 'Pendiente');
SELECT pruebas.verificar('G02-P01-L-04', 'AC-G02-P01-04', 'cambio de decisión en la misma línea',
     (SELECT count(*) = 2 FROM autorizacion_labor WHERE labor_id = pruebas.labor_id(9014, 'Cambio de filtro'))
     AND (SELECT situacion = 'Aceptada' FROM v_situacion_labor WHERE labor_id = pruebas.labor_id(9014, 'Cambio de filtro')),
     '2 filas (Pendiente, Aceptada); aplica Aceptada',
     (SELECT string_agg(decision, ', ' ORDER BY fecha_hora) FROM autorizacion_labor WHERE labor_id = pruebas.labor_id(9014, 'Cambio de filtro'))
     || '; aplica ' || (SELECT situacion FROM v_situacion_labor WHERE labor_id = pruebas.labor_id(9014, 'Cambio de filtro')));

-- ===========================================================
-- ID: G02-P01-L-05     Criterio: AC-G02-P01-04
-- Preparación: B (escobillas) de 9001 fue RECHAZADA en v1.
-- Acción: re-ofrecer B en v4 a un precio menor; consultar e intentar
--   iniciarla; luego María la acepta sobre v4.
-- Esperado: en v4, B está "Sin decidir" y NO es ejecutable (iniciar se
--   rechaza); tras la aceptación sobre v4 la ejecutable es la de v4. La
--   decisión Rechazada de v1 se conserva.
-- ===========================================================
SELECT fn_cambiar_estado_orden(9001, 'Pendiente autorización', 201, 'Se vuelve a ofrecer el cambio de escobillas', '2026-11-03 09:55');
SELECT fn_publicar_propuesta(9001, pruebas.propuesta_id(9001, 3),
  ('[{"labor_id":' || pruebas.labor_id(9001, 'Cambio de escobillas') || ',"precio_estimado":3000,
      "alcance":"Sustituir ambas escobillas (precio promocional)",
      "repuestos":[{"repuesto_id":"LP-001","cantidad":1,"precio_unitario":8500}]}]')::jsonb,
  205, 'Re-oferta de escobillas', '2026-11-03 10:00');
SELECT labor_id, descripcion, version_vigente, situacion FROM v_situacion_labor WHERE labor_id = pruebas.labor_id(9001, 'Cambio de escobillas');
SELECT pruebas.verificar('G02-P01-L-05', 'AC-G02-P01-04', 'labor rechazada re-ofrecida queda Sin decidir',
     (SELECT situacion = 'Sin decidir' AND version_vigente = 4 FROM v_situacion_labor WHERE labor_id = pruebas.labor_id(9001, 'Cambio de escobillas')),
     'v4 Sin decidir', (SELECT 'v' || version_vigente || ' ' || situacion FROM v_situacion_labor WHERE labor_id = pruebas.labor_id(9001, 'Cambio de escobillas')));
SELECT pruebas.esperar_rechazo('G02-P01-L-05', 'AC-G02-P01-04', 'iniciar la labor re-ofrecida sin decisión nueva',
     $q$ SELECT fn_iniciar_labor(pruebas.labor_id(9001, 'Cambio de escobillas'), 202, '2026-11-03 10:05') $q$,
     'no tiene autorización aplicable Aceptada');
SELECT pruebas.esperar_rechazo('G02-P01-L-05', 'AC-G02-P01-04', 'INSERT directo citando la autorización vieja (Rechazada de v1)',
     $q$ INSERT INTO historial_labor (labor_id, estado_nuevo, fecha_hora, personal_id, autorizacion_id)
         SELECT labor_id, 'En proceso', '2026-11-03 10:05', 202, autorizacion_id
         FROM autorizacion_labor WHERE labor_id = pruebas.labor_id(9001, 'Cambio de escobillas') AND decision = 'Rechazada' $q$,
     'no es la decisión aplicable Aceptada');
SELECT fn_registrar_decision(pruebas.propuesta_id(9001, 4), pruebas.labor_id(9001, 'Cambio de escobillas'),
                             101, 'Aceptada', 'Teléfono', 201, '2026-11-03 10:30', 'Acepta con el precio promocional');
SELECT fn_cambiar_estado_orden(9001, 'Autorizada', 201, NULL, '2026-11-03 10:35');
SELECT pruebas.verificar('G02-P01-L-05', 'AC-G02-P01-04', 'la ejecutable de B es la aceptación de v4 y la Rechazada de v1 se conserva',
     (SELECT version = 4 FROM v_autorizacion_ejecutable WHERE labor_id = pruebas.labor_id(9001, 'Cambio de escobillas'))
     AND EXISTS (SELECT 1 FROM v_comparacion_versiones WHERE labor_id = pruebas.labor_id(9001, 'Cambio de escobillas')
                 AND version = 1 AND decision_en_esta_version = 'Rechazada'),
     'ejecutable v4; v1 Rechazada intacta',
     (SELECT string_agg('v' || version || ':' || decision_en_esta_version, ', ' ORDER BY version)
      FROM v_comparacion_versiones WHERE labor_id = pruebas.labor_id(9001, 'Cambio de escobillas')));

-- Situación final de 9001 (todas las labores, con la versión y decisión aplicable).
SELECT labor_id, descripcion, version_vigente, precio_vigente, situacion, decidido_por, medio_decision, autorizacion_id
FROM v_situacion_labor WHERE orden_id = 9001 ORDER BY labor_id;
