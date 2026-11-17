-- KI-erstellter SQL-Generator, ohne Faker oder externen KI-Aufruf zur Laufzeit.
-- Voraussetzung: beide Prisma-Migrationen sind angewendet.
-- Konfiguration unten in DECLARE. Keine bestehenden Daten werden gelöscht.
BEGIN;
SET LOCAL search_path = public, pg_temp;
SET LOCAL TIME ZONE 'Europe/Berlin';

DO $$
DECLARE
  customer_count constant integer := 1000;
  dataset constant text := 'ai-v1';
  snapshot constant timestamptz := '2026-11-17 12:00:00+01';
  first_day constant date := '2026-01-05';
  first_names constant text[] := ARRAY[
    'Anna','Ben','Clara','David','Emilia','Felix','Greta','Hassan',
    'Ida','Jonas','Klara','Leon','Mia','Noah','Olivia','Paul',
    'Rana','Samuel','Tara','Viktor','Yara','Zoe','Amir','Elena',
    'Finn','Hannah','Jamal','Lina','Matteo','Nora','Oskar','Sofia'];
  last_names constant text[] := ARRAY[
    'Müller','Schmidt','Schneider','Fischer','Weber','Meyer','Wagner','Becker',
    'Hoffmann','Schäfer','Koch','Bauer','Richter','Klein','Wolf','Schröder',
    'Neumann','Schwarz','Zimmermann','Braun','Krüger','Hartmann','Lange','Schmitt',
    'Werner','Schmitz','Krause','Meier','Lehmann','Schmid','Schulz','Roth'];
  instructors integer[] := ARRAY[]::integer[];
  equipment_ids integer[] := ARRAY[]::integer[];
  certs integer[] := ARRAY[]::integer[];
  courses integer[] := ARRAY[]::integer[];
  sites integer[] := ARRAY[]::integer[];
  i integer;
  n integer;
  cohort integer;
  level integer;
  row_id integer;
  customer integer;
  session integer;
  trip integer;
  booking integer;
  allocation integer;
  rental integer;
  starts timestamptz;
  ends timestamptz;
  trip_starts timestamptz;
  booked timestamptz;
  cancelled boolean;
  passed boolean;
  course_price numeric;
  trip_price numeric;
  rental_price numeric;
BEGIN
  IF customer_count < 1 OR customer_count > 100000 THEN
    RAISE EXCEPTION 'customer_count muss zwischen 1 und 100000 liegen';
  END IF;
  IF dataset !~ '^[a-z0-9][a-z0-9-]{0,30}$' THEN
    RAISE EXCEPTION 'dataset muss ein kurzer Domain-kompatibler Bezeichner sein';
  END IF;
  -- Verhindert parallele Importe desselben Datensatzes.
  PERFORM pg_advisory_xact_lock(hashtext('seed-ai'), hashtext(dataset));
  IF EXISTS (SELECT 1 FROM customers WHERE email LIKE '%@' || dataset || '.example.invalid')
     OR EXISTS (SELECT 1 FROM instructors WHERE email LIKE '%@' || dataset || '.example.invalid')
     OR EXISTS (SELECT 1 FROM equipment WHERE inventory_number LIKE dataset || '-%')
     OR EXISTS (SELECT 1 FROM certifications WHERE organization = 'SYNTHETIC-' || dataset) THEN
    RAISE EXCEPTION 'Datensatz % existiert bereits; kein erneuter Import. Zum Prüfen: npm run db:check:ai', dataset;
  END IF;

  FOR i IN 1..2 LOOP
    INSERT INTO certifications (name, organization, description)
    VALUES ((ARRAY['Open Water Diver','Advanced Open Water'])[i],
            'SYNTHETIC-' || dataset, 'Synthetischer Zertifizierungstyp für den KI-Testdatensatz')
    RETURNING id INTO row_id;
    certs := array_append(certs, row_id);
  END LOOP;

  FOR i IN 1..10 LOOP
    INSERT INTO instructors (first_name, last_name, email)
    VALUES (first_names[i], last_names[33-i], 'instructor.' || i || '@' || dataset || '.example.invalid')
    RETURNING id INTO row_id;
    instructors := array_append(instructors, row_id);
    INSERT INTO instructor_certifications
      (instructor_id, certification_id, certificate_number, issued_at)
    SELECT row_id, c, dataset || '-INS-' || i || '-' || ord, DATE '2023-01-01'
    FROM unnest(certs) WITH ORDINALITY AS t(c, ord);
  END LOOP;

  FOR i IN 1..3 LOOP
    INSERT INTO courses (name, description, price, duration_days, required_certification_id)
    VALUES ((ARRAY['Open Water Kurs','Advanced Kurs','Tieftauch-Workshop'])[i] || ' [' || dataset || ']',
            'Synthetisches Kursangebot', (ARRAY[299,349,149])[i], (ARRAY[3,2,1])[i],
            CASE WHEN i = 1 THEN NULL ELSE certs[i-1] END)
    RETURNING id INTO row_id;
    courses := array_append(courses, row_id);

    INSERT INTO dive_sites (name, location, max_depth_meters, description, required_certification_id)
    VALUES ((ARRAY['Übungsbucht','Hausriff','Tiefe Felswand'])[i] || ' [' || dataset || ']',
            (ARRAY['Testsee Nord','Testsee Süd','Testsee West'])[i], (ARRAY[8,18,35])[i],
            'Fiktiver Tauchplatz', CASE WHEN i = 1 THEN NULL ELSE certs[i-1] END)
    RETURNING id INTO row_id;
    sites := array_append(sites, row_id);
  END LOOP;

  -- 80 Plätze für Kurszuweisungen, 20 für Mieten, 20 ausgemusterte Artikel.
  FOR i IN 1..120 LOOP
    INSERT INTO equipment
      (inventory_number, equipment_type, manufacturer, model, size, condition, purchased_at, retired_at)
    VALUES (dataset || '-EQ-' || lpad(i::text, 4, '0'),
            (ARRAY['regulator','bcd','wetsuit','fins'])[1+(i-1)%4],
            'Demo Dive', 'Testmodell ' || (1+(i-1)%4), (ARRAY['S','M','L','XL'])[1+(i-1)%4],
            (CASE WHEN i > 100 THEN 'defective' WHEN i%10 = 0 THEN 'worn'
                  WHEN i%7 = 0 THEN 'new' ELSE 'good' END)::"EquipmentCondition",
            DATE '2024-01-01' + i, CASE WHEN i > 100 THEN DATE '2025-12-31' END)
    RETURNING id INTO row_id;
    equipment_ids := array_append(equipment_ids, row_id);
    IF i <= 100 THEN
      INSERT INTO equipment_allocations (equipment_id, start_at, end_at, allocation_type, status, created_at)
      VALUES (row_id, (DATE '2025-12-01' + i%20) + TIME '08:00',
              (DATE '2025-12-01' + i%20) + TIME '16:00', 'maintenance', 'completed', '2025-11-20 10:00+01')
      RETURNING id INTO allocation;
      INSERT INTO equipment_maintenance (allocation_id, description, cost, next_maintenance, created_at)
      VALUES (allocation, 'Jahresinspektion: Dichtungen und Funktionsprüfung',
              25 + i%8 * 5, DATE '2026-12-01' + i%20, '2025-11-20 10:00+01');
    END IF;
  END LOOP;

  -- Gruppen mit höchstens acht Kunden; zwei Gruppen pro Woche.
  -- Derselbe Lehrer / dieselbe Ausrüstung kommt erst fünf Wochen später wieder dran.
  FOR cohort IN 0..((customer_count-1)/8) LOOP
    level := cohort%3;
    starts := (first_day + (cohort/2)*7) + TIME '09:00';
    ends := starts + ((ARRAY[3,2,1])[level+1]-1) * INTERVAL '1 day' + INTERVAL '8 hours';
    trip_starts := (first_day + (cohort/2)*7 + 4) + TIME '08:00';
    course_price := (ARRAY[299,349,149])[level+1];
    trip_price := (ARRAY[45,65,95])[level+1];

    INSERT INTO course_sessions (course_id, instructor_id, start_at, end_at, max_participants, status)
    VALUES (courses[level+1], instructors[1+cohort%10], starts, ends, 8,
            (CASE WHEN ends <= snapshot THEN 'completed' ELSE 'planned' END)::"ScheduleStatus")
    RETURNING id INTO session;
    INSERT INTO dive_trips (site_id, instructor_id, start_at, end_at, max_participants, price, status)
    VALUES (sites[level+1], instructors[1+cohort%10], trip_starts, trip_starts + INTERVAL '4 hours', 8, trip_price,
            (CASE WHEN trip_starts + INTERVAL '4 hours' <= snapshot THEN 'completed' ELSE 'planned' END)::"ScheduleStatus")
    RETURNING id INTO trip;

    FOR n IN (cohort*8+1)..least(cohort*8+8, customer_count) LOOP
      INSERT INTO customers (first_name, last_name, email, birth_date, created_at)
      VALUES (first_names[1+(n-1)%32], last_names[1+((n-1)/32)%32],
              'customer.' || n || '@' || dataset || '.example.invalid',
              DATE '1960-01-01' + (n*37)%15000,
              (DATE '2025-01-01' + n%300) + TIME '12:00')
      RETURNING id INTO customer;
      -- Anfänger ohne Zertifikat; Fortgeschrittene mit passenden Voraussetzungen.
      FOR i IN 1..level LOOP
        INSERT INTO customer_certifications
          (customer_id, certification_id, certificate_number, issued_at)
        VALUES (customer, certs[i], dataset || '-PRE-' || n || '-' || i, DATE '2024-01-01' + (i-1)*366);
      END LOOP;

      booked := least(starts - INTERVAL '21 days', snapshot - (1+n%30)*INTERVAL '1 day');
      cancelled := n%10 = 0;
      passed := NOT cancelled AND ends <= snapshot AND n%7 <> 0;
      INSERT INTO bookings (customer_id, session_id, booked_at, booking_status, passed_at)
      VALUES (customer, session, booked,
              (CASE WHEN cancelled THEN 'cancelled' ELSE 'confirmed' END)::"BookingStatus",
              CASE WHEN passed THEN ends END)
      RETURNING id INTO booking;
      IF passed AND level < 2 THEN
        INSERT INTO customer_certifications (customer_id, certification_id, certificate_number, issued_at)
        VALUES (customer, certs[level+1], dataset || '-PASS-' || n, ends::date);
      END IF;

      IF NOT cancelled THEN
        INSERT INTO invoices (customer_id, booking_id, invoice_number, total_amount, issued_at, due_at, paid_at)
        VALUES (customer, booking, dataset || '-COURSE-' || n, course_price, booked::date, booked::date+14,
                CASE WHEN n%4 <> 0 AND booked + INTERVAL '3 days' <= snapshot THEN booked + INTERVAL '3 days' END);
        IF n%5 = 0 THEN
          INSERT INTO equipment_allocations (equipment_id, start_at, end_at, allocation_type, status, created_at)
          VALUES (equipment_ids[1+(n-1)%80], starts, ends, 'assignment',
                  (CASE WHEN ends <= snapshot THEN 'completed' ELSE 'active' END)::"AllocationStatus", booked)
          RETURNING id INTO allocation;
          INSERT INTO equipment_assignments (allocation_id, booking_id, returned_at, created_at)
          VALUES (allocation, booking, CASE WHEN ends <= snapshot THEN ends END, booked);
        END IF;
      END IF;

      INSERT INTO bookings (customer_id, trip_id, booked_at, booking_status)
      VALUES (customer, trip, booked,
              (CASE WHEN cancelled THEN 'cancelled' ELSE 'confirmed' END)::"BookingStatus")
      RETURNING id INTO booking;
      IF NOT cancelled THEN
        INSERT INTO invoices (customer_id, booking_id, invoice_number, total_amount, issued_at, due_at, paid_at)
        VALUES (customer, booking, dataset || '-TRIP-' || n, trip_price, booked::date, booked::date+14,
                CASE WHEN n%4 <> 0 AND booked + INTERVAL '5 days' <= snapshot THEN booked + INTERVAL '5 days' END);
      END IF;

      IF n%4 = 0 THEN
        rental_price := 12 + n%5 * 3;
        INSERT INTO equipment_allocations (equipment_id, start_at, end_at, allocation_type, status, created_at)
        VALUES (equipment_ids[81+(n-1)%20], trip_starts + INTERVAL '6 hours', trip_starts + INTERVAL '10 hours',
                'rental', (CASE WHEN trip_starts + INTERVAL '10 hours' <= snapshot THEN 'completed' ELSE 'active' END)::"AllocationStatus", booked)
        RETURNING id INTO allocation;
        INSERT INTO equipment_rentals (allocation_id, customer_id, price, returned_at, created_at)
        VALUES (allocation, customer, rental_price,
                CASE WHEN trip_starts + INTERVAL '10 hours' <= snapshot THEN trip_starts + INTERVAL '10 hours' END, booked)
        RETURNING id INTO rental;
        INSERT INTO invoices (customer_id, rental_id, invoice_number, total_amount, issued_at, due_at, paid_at)
        VALUES (customer, rental, dataset || '-RENTAL-' || n, rental_price, booked::date, booked::date+14,
                CASE WHEN n%3 <> 0 AND booked + INTERVAL '2 days' <= snapshot THEN booked + INTERVAL '2 days' END);
      END IF;
    END LOOP;
  END LOOP;
  RAISE NOTICE 'Datensatz %: % Kunden, % Kurs- und % Tripbuchungen erzeugt.', dataset, customer_count, customer_count, customer_count;
END $$;

-- Auch die verzögerten Allocation-Detailprüfungen müssen vor dem Commit bestehen.
SET CONSTRAINTS ALL IMMEDIATE;
COMMIT;
