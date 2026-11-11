-- =============================================================================
-- 99_demo_seed.sql — Datos de DEMOSTRACIÓN (100% ficticios)
--
-- Permite navegar la aplicación sin datos reales. Todos los nombres, números
-- de empleado y asuntos son inventados. Ejecutar después de 01..12.
-- No crea usuarios: el primer usuario GOD se crea manualmente (ver README).
-- =============================================================================

BEGIN;

-- Personal ficticio
INSERT INTO personal (numero_empleado, nombre_completo, nombre_normalizado, tipo_personal_id, categoria, horario)
VALUES
    ('10001', 'Ana Martínez Ruiz',    'ANA MARTINEZ RUIZ',    (SELECT id FROM tipos_personal WHERE clave = 'SINDICALIZADO'), 'AUXILIAR',     '09:00 a 16:00 L-V'),
    ('10002', 'Carlos Pérez Gómez',   'CARLOS PEREZ GOMEZ',   (SELECT id FROM tipos_personal WHERE clave = 'CONFIANZA'),     'COORDINADOR',  '09:00 a 18:00 L-V'),
    ('10003', 'Laura Hernández Soto', 'LAURA HERNANDEZ SOTO', (SELECT id FROM tipos_personal WHERE clave = 'SINDICALIZADO'), 'ASISTENTE',    '08:00 a 15:00 L-V'),
    ('10004', 'Jorge Ramírez Luna',   'JORGE RAMIREZ LUNA',   (SELECT id FROM tipos_personal WHERE clave = 'SINDICALIZADO'), 'AUXILIAR',     '09:00 a 16:00 L-V'),
    ('10005', 'Sofía Torres Díaz',    'SOFIA TORRES DIAZ',    (SELECT id FROM tipos_personal WHERE clave = 'CONFIANZA'),     'ANALISTA',     '09:00 a 18:00 L-V')
ON CONFLICT DO NOTHING;

-- Oficios EXTERNOS ficticios (el folio de tesorería se genera en BD)
INSERT INTO oficios (numero_folio, anio_folio, tipo_oficio_id, dependencia_id, estado_id, asunto, fecha_recepcion, realizo)
VALUES
    (1, 2026, (SELECT id FROM tipos_oficio WHERE clave = 'EXTERNO'),
        (SELECT id FROM dependencias WHERE clave = 'DA'  LIMIT 1),
        (SELECT id FROM estados_oficio WHERE nombre = 'Recibido'),
        'Solicitud de alta de usuario en sistema de recaudación (DEMO)', DATE '2026-01-12', 'Usuario Demo'),
    (2, 2026, (SELECT id FROM tipos_oficio WHERE clave = 'EXTERNO'),
        (SELECT id FROM dependencias WHERE clave = 'DOP' LIMIT 1),
        (SELECT id FROM estados_oficio WHERE nombre = 'En Proceso'),
        'Requerimiento de soporte a equipo de cómputo (DEMO)', DATE '2026-01-20', 'Usuario Demo'),
    (3, 2026, (SELECT id FROM tipos_oficio WHERE clave = 'EXTERNO'),
        (SELECT id FROM dependencias WHERE clave = 'RC'  LIMIT 1),
        (SELECT id FROM estados_oficio WHERE nombre = 'Contestado'),
        'Solicitud de configuración de impresora de red (DEMO)', DATE '2026-02-03', 'Usuario Demo')
ON CONFLICT DO NOTHING;

-- Oficio INTERNO ficticio
INSERT INTO oficios (numero_folio, anio_folio, tipo_oficio_id, area_interna_id, estado_id, asunto, fecha_recepcion, folio_interno_texto)
VALUES
    (10001, 2026, (SELECT id FROM tipos_oficio WHERE clave = 'INTERNO'),
        (SELECT id FROM areas_internas WHERE clave = 'SE' LIMIT 1),
        (SELECT id FROM estados_oficio WHERE nombre = 'Archivado'),
        'Memorándum interno de prueba (DEMO)', DATE '2026-02-10', 'TM/MUN/SE/001/2026')
ON CONFLICT DO NOTHING;

-- Movimiento inicial de cada oficio demo (trazabilidad)
INSERT INTO movimientos_oficio (oficio_id, estado_anterior_id, estado_nuevo_id, observacion)
SELECT o.id, NULL, o.estado_id, 'Registro inicial (DEMO)'
  FROM oficios o
  LEFT JOIN movimientos_oficio m ON m.oficio_id = o.id
 WHERE m.id IS NULL AND o.asunto LIKE '%(DEMO)';

-- Incidencias ficticias
INSERT INTO incidencias (personal_id, tipo_incidencia_id, estatus_id, fecha_incidencia, fecha_inicio, fecha_fin, anio, mes, dias, motivo, fuente)
VALUES
    ((SELECT id FROM personal WHERE numero_empleado = '10001'),
     (SELECT id FROM tipos_incidencia WHERE clave = 'OMISION_ENTRADA'),
     (SELECT id FROM estatus_incidencia WHERE clave = 'JUSTIFICADA'),
     DATE '2026-03-02', DATE '2026-03-02', DATE '2026-03-02', 2026, 3, 1, 'Falla del reloj checador (DEMO)', 'MANUAL'),
    ((SELECT id FROM personal WHERE numero_empleado = '10004'),
     (SELECT id FROM tipos_incidencia WHERE clave = 'RETARDO'),
     (SELECT id FROM estatus_incidencia WHERE clave = 'REGISTRADA'),
     DATE '2026-03-05', DATE '2026-03-05', DATE '2026-03-05', 2026, 3, 0, 'Retardo de 15 minutos (DEMO)', 'MANUAL')
ON CONFLICT DO NOTHING;

-- Vacaciones ficticias
INSERT INTO vacaciones_movimientos (personal_id, periodo_id, fecha_inicio, fecha_fin, fecha_regreso, dias_corresponden, dias_tomados, estatus_id, observaciones)
VALUES
    ((SELECT id FROM personal WHERE numero_empleado = '10003'),
     (SELECT id FROM vacaciones_periodos WHERE clave = '1ER_PERIODO_2025'),
     DATE '2025-07-14', DATE '2025-07-25', DATE '2025-07-28', 10, 10,
     (SELECT id FROM estatus_vacaciones WHERE clave = 'FINALIZADA'), 'DEMO'),
    ((SELECT id FROM personal WHERE numero_empleado = '10002'),
     (SELECT id FROM vacaciones_periodos WHERE clave = '2DO_PERIODO_2025'),
     DATE '2025-12-22', DATE '2025-12-26', DATE '2025-12-29', 10, 5,
     (SELECT id FROM estatus_vacaciones WHERE clave = 'FINALIZADA'), 'DEMO');

COMMIT;
