-- Wiederholbare Prüfung des KI-Datensatzes. Nur temporäre Objekte werden erstellt.
-- Bei einem anderen Datensatznamen den Wert hier anpassen.
BEGIN;
SET LOCAL search_path = public, pg_temp;
SET LOCAL TIME ZONE 'Europe/Berlin';
CREATE TEMP TABLE _ai_check_config ON COMMIT DROP AS
SELECT 'ai-v1'::text AS dataset, TIMESTAMPTZ '2026-11-17 12:00:00+01' AS snapshot;
CREATE TEMP VIEW _ai_customers AS
SELECT c.* FROM customers c, _ai_check_config cfg
WHERE c.email LIKE '%@' || cfg.dataset || '.example.invalid';
CREATE TEMP VIEW _ai_instructors AS
SELECT i.* FROM instructors i, _ai_check_config cfg
WHERE i.email LIKE '%@' || cfg.dataset || '.example.invalid';
CREATE TEMP VIEW _ai_bookings AS
SELECT b.* FROM bookings b JOIN _ai_customers c ON c.id = b.customer_id;
CREATE TEMP VIEW _ai_equipment AS
SELECT e.* FROM equipment e, _ai_check_config cfg
WHERE e.inventory_number LIKE cfg.dataset || '-%';
CREATE TEMP VIEW _ai_allocations AS
SELECT a.* FROM equipment_allocations a JOIN _ai_equipment e ON e.id = a.equipment_id;
CREATE TEMP VIEW _ai_rentals AS
SELECT r.* FROM equipment_rentals r JOIN _ai_allocations a ON a.id = r.allocation_id;
CREATE TEMP VIEW _ai_invoices AS
SELECT i.* FROM invoices i JOIN _ai_customers c ON c.id = i.customer_id;
CREATE TEMP VIEW _ai_sessions AS
SELECT s.* FROM course_sessions s JOIN _ai_instructors i ON i.id = s.instructor_id;
CREATE TEMP VIEW _ai_trips AS
SELECT t.* FROM dive_trips t JOIN _ai_instructors i ON i.id = t.instructor_id;

CREATE TEMP VIEW _ai_counts AS
SELECT 'customers' AS table_name, count(*) AS rows FROM _ai_customers
UNION ALL SELECT 'instructors', count(*) FROM _ai_instructors
UNION ALL SELECT 'certifications', count(*) FROM certifications c, _ai_check_config cfg WHERE c.organization = 'SYNTHETIC-' || cfg.dataset
UNION ALL SELECT 'customer_certifications', count(*) FROM customer_certifications c JOIN _ai_customers a ON a.id = c.customer_id
UNION ALL SELECT 'instructor_certifications', count(*) FROM instructor_certifications c JOIN _ai_instructors i ON i.id = c.instructor_id
UNION ALL SELECT 'courses', count(*) FROM courses c, _ai_check_config cfg WHERE c.name LIKE '% [' || cfg.dataset || ']'
UNION ALL SELECT 'course_sessions', count(*) FROM _ai_sessions
UNION ALL SELECT 'dive_sites', count(*) FROM dive_sites s, _ai_check_config cfg WHERE s.name LIKE '% [' || cfg.dataset || ']'
UNION ALL SELECT 'dive_trips', count(*) FROM _ai_trips
UNION ALL SELECT 'bookings', count(*) FROM _ai_bookings
UNION ALL SELECT 'equipment', count(*) FROM _ai_equipment
UNION ALL SELECT 'equipment_allocations', count(*) FROM _ai_allocations
UNION ALL SELECT 'equipment_rentals', count(*) FROM _ai_rentals
UNION ALL SELECT 'equipment_assignments', count(*) FROM equipment_assignments a JOIN _ai_allocations x ON x.id = a.allocation_id
UNION ALL SELECT 'equipment_maintenance', count(*) FROM equipment_maintenance m JOIN _ai_allocations x ON x.id = m.allocation_id
UNION ALL SELECT 'invoices', count(*) FROM _ai_invoices;

-- Mengenprüfung, zusätzlich zu den aktiven DB-Constraints und Triggern.
DO $$
DECLARE
  n bigint := (SELECT count(*) FROM _ai_customers);
  actual bigint;
  expected record;
BEGIN
  IF n = 0 THEN
    RAISE EXCEPTION 'Kein KI-Datensatz gefunden';
  END IF;
  FOR expected IN SELECT * FROM (VALUES
    ('instructors', 10::bigint), ('certifications', 2), ('instructor_certifications', 20),
    ('courses', 3), ('dive_sites', 3), ('course_sessions', (n+7)/8), ('dive_trips', (n+7)/8),
    ('bookings', 2*n), ('equipment', 120), ('equipment_rentals', n/4),
    ('equipment_assignments', (n+5)/10), ('equipment_maintenance', 100),
    ('equipment_allocations', 100+n/4+(n+5)/10), ('invoices', 2*(n-n/10)+n/4)
  ) AS v(table_name, expected_rows) LOOP
    SELECT rows INTO actual FROM _ai_counts WHERE table_name = expected.table_name;
    IF actual IS DISTINCT FROM expected.expected_rows THEN
      RAISE EXCEPTION '%: erwartet %, vorhanden %', expected.table_name, expected.expected_rows, actual;
    END IF;
  END LOOP;
END $$;

CREATE TEMP VIEW _ai_issues AS
SELECT 'Buchungen: genau ein Kurs und ein Trip pro Kunde' AS rule, count(*) AS violations
FROM (SELECT customer_id FROM _ai_bookings GROUP BY customer_id
      HAVING count(session_id) <> 1 OR count(trip_id) <> 1) bad
UNION ALL
SELECT 'Rechnungen: Kunde, Betrag und nicht stornierte Leistung', count(*)
FROM _ai_invoices i
LEFT JOIN bookings b ON b.id = i.booking_id
LEFT JOIN course_sessions s ON s.id = b.session_id
LEFT JOIN courses c ON c.id = s.course_id
LEFT JOIN dive_trips t ON t.id = b.trip_id
LEFT JOIN equipment_rentals r ON r.id = i.rental_id
WHERE i.customer_id IS DISTINCT FROM coalesce(b.customer_id, r.customer_id)
   OR i.total_amount IS DISTINCT FROM coalesce(c.price, t.price, r.price)
   OR b.booking_status = 'cancelled'
UNION ALL
SELECT 'Buchungen: Zertifikat zum Veranstaltungsbeginn gültig', count(*)
FROM _ai_bookings b
LEFT JOIN course_sessions s ON s.id = b.session_id
LEFT JOIN courses c ON c.id = s.course_id
LEFT JOIN dive_trips t ON t.id = b.trip_id
LEFT JOIN dive_sites ds ON ds.id = t.site_id
WHERE b.booking_status = 'confirmed'
  AND coalesce(c.required_certification_id, ds.required_certification_id) IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM customer_certifications cc
                  WHERE cc.customer_id = b.customer_id
                    AND cc.certification_id = coalesce(c.required_certification_id, ds.required_certification_id)
                    AND cc.issued_at <= coalesce(s.start_at, t.start_at)::date
                    AND (cc.expires_at IS NULL OR cc.expires_at >= coalesce(s.start_at, t.start_at)::date))
UNION ALL
SELECT 'Zeitfolge: Registrierung, Buchung, Veranstaltung und Abschluss', count(*)
FROM _ai_bookings b
JOIN _ai_customers c ON c.id = b.customer_id
LEFT JOIN course_sessions s ON s.id = b.session_id
LEFT JOIN dive_trips t ON t.id = b.trip_id
CROSS JOIN _ai_check_config cfg
WHERE b.booked_at < c.created_at OR b.booked_at > cfg.snapshot
   OR b.booked_at > coalesce(s.start_at, t.start_at)
   OR (b.passed_at IS NOT NULL AND (b.passed_at < s.end_at OR b.passed_at > cfg.snapshot OR b.booking_status = 'cancelled'))
UNION ALL
SELECT 'Rechnungsdaten: Ausstellung und Zahlung nicht in der Zukunft', count(*)
FROM _ai_invoices i, _ai_check_config cfg
WHERE i.issued_at > cfg.snapshot::date OR i.paid_at > cfg.snapshot OR i.paid_at::date < i.issued_at
UNION ALL
SELECT 'Zuweisungen: bestätigte Buchung und passender Zeitraum', count(*)
FROM equipment_assignments x JOIN _ai_allocations a ON a.id = x.allocation_id
JOIN bookings b ON b.id = x.booking_id
LEFT JOIN course_sessions s ON s.id = b.session_id
LEFT JOIN dive_trips t ON t.id = b.trip_id
WHERE b.booking_status = 'cancelled' OR a.start_at <> coalesce(s.start_at,t.start_at)
   OR a.end_at <> coalesce(s.end_at,t.end_at)
UNION ALL
SELECT 'Ausrüstung: keine Belegung nach Ausmusterung', count(*)
FROM _ai_allocations a JOIN _ai_equipment e ON e.id = a.equipment_id
WHERE e.retired_at IS NOT NULL AND a.end_at::date >= e.retired_at
UNION ALL
SELECT 'Belegungen: genau ein passender Detaileintrag', count(*)
FROM _ai_allocations a
LEFT JOIN equipment_rentals r ON r.allocation_id = a.id
LEFT JOIN equipment_assignments x ON x.allocation_id = a.id
LEFT JOIN equipment_maintenance m ON m.allocation_id = a.id
WHERE num_nonnulls(r.id,x.id,m.id) <> 1
   OR NOT public.allocation_has_detail(a.id,a.allocation_type)
UNION ALL
SELECT 'Belegungsstatus passend zum Stichtag', count(*)
FROM _ai_allocations a, _ai_check_config cfg
WHERE (a.end_at <= cfg.snapshot AND a.status <> 'completed')
   OR (a.end_at > cfg.snapshot AND a.status <> 'active');

TABLE _ai_issues;
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM _ai_issues WHERE violations <> 0) THEN
    RAISE EXCEPTION 'KI-Datensatz hat fachliche Inkonsistenzen; siehe Prüfergebnis';
  END IF;
END $$;
SELECT table_name, rows FROM _ai_counts ORDER BY table_name;
SELECT sum(rows) AS total_rows FROM _ai_counts;
SELECT booking_status, count(*) FROM _ai_bookings GROUP BY booking_status ORDER BY booking_status;
SELECT count(*) FILTER (WHERE paid_at IS NOT NULL) AS paid_invoices,
       count(*) FILTER (WHERE paid_at IS NULL) AS unpaid_invoices FROM _ai_invoices;

-- Temporäre Views vor der Konfiguration entfernen, damit erneut ausführbar.
DROP VIEW _ai_issues, _ai_counts, _ai_invoices, _ai_rentals, _ai_allocations,
          _ai_equipment, _ai_bookings, _ai_sessions, _ai_trips, _ai_instructors, _ai_customers;
COMMIT;
