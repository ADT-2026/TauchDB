TRUNCATE invoices, equipment_maintenance, equipment_assignments, equipment_rentals,
         equipment_allocations, equipment, bookings, dive_trips, dive_sites,
         course_sessions, courses, instructor_certifications, customer_certifications,
         certifications, instructors, customers
RESTART IDENTITY CASCADE;

BEGIN;

INSERT INTO certifications (name, organization) VALUES
  ('Open Water Diver',    'PADI'),   -- 1
  ('Advanced Open Water', 'PADI');   -- 2

INSERT INTO customers (first_name, last_name, email, birth_date) VALUES
  ('Anna', 'Beispiel', 'anna@example.com', '1990-05-01'),   -- 1
  ('Ben',  'Test',     'ben@example.com',  '1985-03-12'),   -- 2
  ('Cara', 'Muster',   'cara@example.com', '1995-07-20');   -- 3

INSERT INTO instructors (first_name, last_name, email) VALUES
  ('Ina', 'Instructor', 'ina@example.com'),                 -- 1
  ('Ivo', 'Instructor', 'ivo@example.com');                 -- 2

-- Kunden-Zertifizierungen: nur Anna hat Zert. 1 (unbegrenzt gültig)
INSERT INTO customer_certifications (customer_id, certification_id, certificate_number, issued_at)
VALUES (1, 1, 'OWD-001', '2024-01-01');

-- Instructor-Zertifizierungen
INSERT INTO instructor_certifications (instructor_id, certification_id, certificate_number, issued_at, expires_at)
VALUES
  (1, 1, 'INS-001', '2023-01-01', NULL),           -- Ina: unbegrenzt
  (2, 1, 'INS-002', '2022-01-01', '2024-06-01');   -- Ivo: abgelaufen (Erneuerung wird getestet)

INSERT INTO courses (name, price, duration_days, required_certification_id) VALUES
  ('Open Water Kurs', 299, 3, NULL),                         -- 1
  ('Advanced Kurs',   349, 2, 1);                            -- 2 (braucht Zert. 1)

INSERT INTO course_sessions (course_id, instructor_id, start_at, end_at, max_participants) VALUES
  (1, 1, '2026-12-01 09:00+01', '2026-12-03 17:00+01', 2),   -- 1 (wird voll: 2/2)
  (2, 2, '2026-12-10 09:00+01', '2026-12-11 17:00+01', 2);   -- 2

INSERT INTO dive_sites (name, location, max_depth_meters, required_certification_id) VALUES
  ('Blue Hole',  'Ägypten', 40, 1),                          -- 1
  ('House Reef', 'Ägypten', 18, NULL);                       -- 2

INSERT INTO dive_trips (site_id, instructor_id, start_at, end_at, max_participants, price) VALUES
  (1, 1, '2026-12-20 08:00+01', '2026-12-20 12:00+01', 2, 80);   -- 1

INSERT INTO bookings (customer_id, session_id, trip_id) VALUES
  (1, 1, NULL),   -- 1 Anna -> Kurs 1
  (1, 2, NULL),   -- 2 Anna -> Advanced (Zert. vorhanden)
  (1, NULL, 1),   -- 3 Anna -> Trip (1/2)
  (2, 1, NULL);   -- 4 Ben  -> Kurs 1 (Session 1 voll)

INSERT INTO equipment (inventory_number, equipment_type) VALUES
  ('REG-001', 'regulator'),   -- 1
  ('BCD-001', 'bcd');         -- 2

-- Allocation + Detail immer in derselben Transaktion
INSERT INTO equipment_allocations (equipment_id, start_at, end_at, allocation_type)
VALUES (1, '2026-12-01 08:00+01', '2026-12-01 18:00+01', 'rental');        -- 1
INSERT INTO equipment_rentals (allocation_id, customer_id, price) VALUES (1, 1, 15);   -- rental 1

INSERT INTO equipment_allocations (equipment_id, start_at, end_at, allocation_type)
VALUES (2, '2026-12-01 08:00+01', '2026-12-03 18:00+01', 'assignment');    -- 2
INSERT INTO equipment_assignments (allocation_id, booking_id) VALUES (2, 1);

INSERT INTO equipment_allocations (equipment_id, start_at, end_at, allocation_type)
VALUES (1, '2026-12-05 08:00+01', '2026-12-06 08:00+01', 'maintenance');   -- 3
INSERT INTO equipment_maintenance (allocation_id, description, cost) VALUES (3, 'Service', 45);

INSERT INTO invoices (customer_id, booking_id, invoice_number, total_amount, due_at)
VALUES (1, 1, 'INV-0001', 299, '2026-12-31');
INSERT INTO invoices (customer_id, rental_id, invoice_number, total_amount, due_at)
VALUES (1, 1, 'INV-0002', 15, '2026-12-31');

COMMIT;
