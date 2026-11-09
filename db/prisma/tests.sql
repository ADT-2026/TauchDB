-- Erwartet einen Fehler
CREATE OR REPLACE FUNCTION pg_temp.expect_fail(label text, stmt text)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  BEGIN
    EXECUTE stmt;
    SET CONSTRAINTS ALL IMMEDIATE;
    RAISE EXCEPTION '__no_error__';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM = '__no_error__' THEN
      RAISE WARNING 'FEHLT   %: kein Fehler ausgelöst!', label;
    ELSE
      RAISE NOTICE 'OK      %: % [%]', label, SQLERRM, SQLSTATE;
    END IF;
  END;
END $$;

-- Erwartet Erfolg
CREATE OR REPLACE FUNCTION pg_temp.expect_ok(label text, stmt text)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  BEGIN
    EXECUTE stmt;
    SET CONSTRAINTS ALL IMMEDIATE;
    RAISE EXCEPTION '__ok__';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM = '__ok__' THEN
      RAISE NOTICE 'OK      %: erlaubt', label;
    ELSE
      RAISE WARNING 'FEHLER  %: unerwartet abgelehnt: % [%]', label, SQLERRM, SQLSTATE;
    END IF;
  END;
END $$;

-- ===== Kunden / Basis =====
SELECT pg_temp.expect_fail('E-Mail case-insensitive unique',
  $$INSERT INTO customers (first_name,last_name,email) VALUES ('X','Y','ANNA@example.com')$$);

SELECT pg_temp.expect_fail('Kurspreis negativ',
  $$INSERT INTO courses (name,price,duration_days) VALUES ('Neg',-1,1)$$);

-- ===== Kunden-Zertifizierungen =====
SELECT pg_temp.expect_fail('Kundenzert.: Zeitraum überlappt',
  $$INSERT INTO customer_certifications (customer_id,certification_id,certificate_number,issued_at)
    VALUES (1,1,'OWD-002','2025-01-01')$$);

SELECT pg_temp.expect_fail('Kundenzert.: gleiche Nummer, anderer Kunde',
  $$INSERT INTO customer_certifications (customer_id,certification_id,certificate_number,issued_at)
    VALUES (2,1,'OWD-001','2024-01-01')$$);

SELECT pg_temp.expect_ok('Kundenzert.: gleiche Nummer, anderes Zertifikat',
  $$INSERT INTO customer_certifications (customer_id,certification_id,certificate_number,issued_at)
    VALUES (2,2,'OWD-001','2024-01-01')$$);

SELECT pg_temp.expect_fail('Kundenzert.: expires < issued',
  $$INSERT INTO customer_certifications (customer_id,certification_id,certificate_number,issued_at,expires_at)
    VALUES (3,1,'OWD-900','2025-01-02','2025-01-01')$$);

-- ===== Instructor-Zertifizierungen =====
SELECT pg_temp.expect_ok('Instructorzert.: Erneuerung nach Ablauf',
  $$INSERT INTO instructor_certifications (instructor_id,certification_id,certificate_number,issued_at)
    VALUES (2,1,'INS-003','2024-06-02')$$);

SELECT pg_temp.expect_fail('Instructorzert.: Überlappung mit laufender',
  $$INSERT INTO instructor_certifications (instructor_id,certification_id,certificate_number,issued_at)
    VALUES (1,1,'INS-004','2024-01-01')$$);

SELECT pg_temp.expect_fail('Instructorzert.: doppelte Nummer je Zertifikat',
  $$INSERT INTO instructor_certifications (instructor_id,certification_id,certificate_number,issued_at)
    VALUES (2,1,'INS-001','2030-01-01')$$);

SELECT pg_temp.expect_ok('Instructorzert.: gleiche Nummer, anderes Zertifikat',
  $$INSERT INTO instructor_certifications (instructor_id,certification_id,certificate_number,issued_at)
    VALUES (2,2,'INS-001','2024-01-01')$$);

SELECT pg_temp.expect_fail('Instructorzert.: expires < issued',
  $$INSERT INTO instructor_certifications (instructor_id,certification_id,certificate_number,issued_at,expires_at)
    VALUES (2,2,'INS-777','2025-01-02','2025-01-01')$$);

-- ===== Sessions / Trips =====
SELECT pg_temp.expect_fail('Session end <= start',
  $$INSERT INTO course_sessions (course_id,instructor_id,start_at,end_at,max_participants)
    VALUES (1,2,'2027-01-02 10:00+01','2027-01-01 10:00+01',5)$$);

SELECT pg_temp.expect_fail('Instructor-Überlapp Kurs/Kurs',
  $$INSERT INTO course_sessions (course_id,instructor_id,start_at,end_at,max_participants)
    VALUES (1,1,'2026-12-02 09:00+01','2026-12-02 17:00+01',5)$$);

SELECT pg_temp.expect_fail('Instructor-Überlapp Trip/Kurs',
  $$INSERT INTO dive_trips (site_id,instructor_id,start_at,end_at,max_participants,price)
    VALUES (2,1,'2026-12-02 08:00+01','2026-12-02 12:00+01',5,50)$$);

SELECT pg_temp.expect_ok('Instructor: direkt anschließend (Ende = Start)',
  $$INSERT INTO dive_trips (site_id,instructor_id,start_at,end_at,max_participants,price)
    VALUES (2,1,'2026-12-03 17:00+01','2026-12-03 19:00+01',5,50)$$);

SELECT pg_temp.expect_ok('Instructor: stornierte Session blockiert nicht',
  $$INSERT INTO course_sessions (course_id,instructor_id,start_at,end_at,max_participants,status)
    VALUES (1,1,'2026-12-02 09:00+01','2026-12-02 17:00+01',5,'cancelled')$$);

-- ===== Buchungen =====
SELECT pg_temp.expect_fail('Buchung ohne Ziel',
  $$INSERT INTO bookings (customer_id) VALUES (3)$$);

SELECT pg_temp.expect_fail('Buchung mit Session UND Trip',
  $$INSERT INTO bookings (customer_id,session_id,trip_id) VALUES (3,1,1)$$);

SELECT pg_temp.expect_fail('Zertifizierung fehlt (Ben -> Advanced)',
  $$INSERT INTO bookings (customer_id,session_id) VALUES (2,2)$$);

SELECT pg_temp.expect_fail('Kapazität erreicht (Cara -> Kurs 1)',
  $$INSERT INTO bookings (customer_id,session_id) VALUES (3,1)$$);

SELECT pg_temp.expect_fail('Doppelte aktive Buchung (Anna -> Trip 1)',
  $$INSERT INTO bookings (customer_id,trip_id) VALUES (1,1)$$);

SELECT pg_temp.expect_ok('Neubuchung nach Storno',
  $$UPDATE bookings SET booking_status = 'cancelled' WHERE id = 3;
    INSERT INTO bookings (customer_id,trip_id) VALUES (1,1)$$);

SELECT pg_temp.expect_ok('Storno gibt Platz frei (Cara -> Kurs 1)',
  $$UPDATE bookings SET booking_status = 'cancelled' WHERE id = 4;
    INSERT INTO bookings (customer_id,session_id) VALUES (3,1)$$);

SELECT pg_temp.expect_fail('passed_at bei Trip-Buchung',
  $$UPDATE bookings SET passed_at = now() WHERE id = 3$$);

SELECT pg_temp.expect_ok('passed_at bei Kurs-Buchung',
  $$UPDATE bookings SET passed_at = now() WHERE id = 1$$);

-- Zertifikat läuft am Starttag ab (Session 2 startet am 10.12. um 09:00 Berlin)
SELECT pg_temp.expect_ok('Zert. gültig bis einschließlich Starttag',
  $$INSERT INTO customer_certifications (customer_id,certification_id,certificate_number,issued_at,expires_at)
      VALUES (2,1,'OWD-B1','2026-01-01','2026-12-10');
    INSERT INTO bookings (customer_id,session_id) VALUES (2,2)$$);

SELECT pg_temp.expect_fail('Zert. am Vortag abgelaufen',
  $$INSERT INTO customer_certifications (customer_id,certification_id,certificate_number,issued_at,expires_at)
      VALUES (2,1,'OWD-B2','2026-01-01','2026-12-09');
    INSERT INTO bookings (customer_id,session_id) VALUES (2,2)$$);

-- ===== Equipment =====
SELECT pg_temp.expect_fail('Equipment-Überlapp',
  $$WITH a AS (
      INSERT INTO equipment_allocations (equipment_id,start_at,end_at,allocation_type)
      VALUES (1,'2026-12-01 12:00+01','2026-12-01 14:00+01','rental') RETURNING id)
    INSERT INTO equipment_rentals (allocation_id,customer_id,price)
    SELECT id,3,10 FROM a$$);

SELECT pg_temp.expect_ok('Allocation + Detail in einer Transaktion',
  $$WITH a AS (
      INSERT INTO equipment_allocations (equipment_id,start_at,end_at,allocation_type)
      VALUES (1,'2026-12-10 08:00+01','2026-12-10 12:00+01','rental') RETURNING id)
    INSERT INTO equipment_rentals (allocation_id,customer_id,price)
    SELECT id,3,10 FROM a$$);

SELECT pg_temp.expect_fail('Allocation ohne Detail (deferred)',
  $$INSERT INTO equipment_allocations (equipment_id,start_at,end_at,allocation_type)
    VALUES (2,'2027-02-01 08:00+01','2027-02-01 10:00+01','rental')$$);

SELECT pg_temp.expect_fail('Detail löschen (deferred)',
  $$DELETE FROM equipment_maintenance WHERE allocation_id = 3$$);

SELECT pg_temp.expect_ok('Allocation + Detail gemeinsam löschen',
  $$DELETE FROM equipment_maintenance WHERE allocation_id = 3;
    DELETE FROM equipment_allocations WHERE id = 3$$);

SELECT pg_temp.expect_fail('Rental an Maintenance-Allocation',
  $$INSERT INTO equipment_rentals (allocation_id,customer_id,price) VALUES (3,1,10)$$);

-- ===== Rechnungen =====
SELECT pg_temp.expect_fail('Rechnung ohne Quelle',
  $$INSERT INTO invoices (customer_id,invoice_number,total_amount,due_at)
    VALUES (1,'INV-X',10,'2026-12-31')$$);

SELECT pg_temp.expect_fail('Rechnung mit Buchung UND Miete',
  $$INSERT INTO invoices (customer_id,booking_id,rental_id,invoice_number,total_amount,due_at)
    VALUES (1,2,1,'INV-Z',10,'2026-12-31')$$);

SELECT pg_temp.expect_fail('Rechnungskunde passt nicht zur Buchung',
  $$INSERT INTO invoices (customer_id,booking_id,invoice_number,total_amount,due_at)
    VALUES (2,3,'INV-Y',10,'2026-12-31')$$);

SELECT pg_temp.expect_fail('Zweite Rechnung zur selben Buchung',
  $$INSERT INTO invoices (customer_id,booking_id,invoice_number,total_amount,due_at)
    VALUES (1,1,'INV-DUP',10,'2026-12-31')$$);