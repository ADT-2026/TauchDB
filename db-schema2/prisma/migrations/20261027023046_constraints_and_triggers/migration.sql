-- =====================================================================
-- constraints_and_triggers
-- =====================================================================
CREATE EXTENSION IF NOT EXISTS btree_gist;

-- ---------------------------------------------------------------------
-- 1. E-Mail case-insensitive eindeutig
-- ---------------------------------------------------------------------
CREATE UNIQUE INDEX "customers_email_lower_key"   ON "customers"   (lower("email"));
CREATE UNIQUE INDEX "instructors_email_lower_key" ON "instructors" (lower("email"));

-- ---------------------------------------------------------------------
-- 2. CHECK-Constraints
-- ---------------------------------------------------------------------
ALTER TABLE "courses"
  ADD CONSTRAINT "courses_price_chk"    CHECK ("price" >= 0),
  ADD CONSTRAINT "courses_duration_chk" CHECK ("duration_days" > 0);

ALTER TABLE "course_sessions"
  ADD CONSTRAINT "course_sessions_time_chk"     CHECK ("end_time" > "start_time"),
  ADD CONSTRAINT "course_sessions_capacity_chk" CHECK ("max_participants" > 0);

ALTER TABLE "dive_sites"
  ADD CONSTRAINT "dive_sites_depth_chk" CHECK ("max_depth_meters" > 0);

ALTER TABLE "dive_trips"
  ADD CONSTRAINT "dive_trips_time_chk"     CHECK ("end_time" > "start_time"),
  ADD CONSTRAINT "dive_trips_capacity_chk" CHECK ("max_participants" > 0),
  ADD CONSTRAINT "dive_trips_price_chk"    CHECK ("price" >= 0);

-- Booking: genau ein Ziel (Kurs-Session ODER Trip); bestanden nur bei Kursen
ALTER TABLE "bookings"
  ADD CONSTRAINT "bookings_target_chk" CHECK (num_nonnulls("session_id", "trip_id") = 1),
  ADD CONSTRAINT "bookings_price_chk"  CHECK ("price_at_booking" >= 0),
  ADD CONSTRAINT "bookings_passed_chk" CHECK ("passed_at" IS NULL OR "session_id" IS NOT NULL);

ALTER TABLE "customer_certifications"
  ADD CONSTRAINT "customer_certifications_dates_chk"
  CHECK ("expires_at" IS NULL OR "expires_at" >= "issued_at");

ALTER TABLE "instructor_certifications"
  ADD CONSTRAINT "instructor_certifications_dates_chk"
  CHECK ("expires_at" IS NULL OR "expires_at" >= "issued_at");

ALTER TABLE "equipment_allocations"
  ADD CONSTRAINT "equipment_allocations_time_chk" CHECK ("end_at" > "start_at");

-- Typbindung der Detailtabellen (zusammen mit dem zusammengesetzten FK)
ALTER TABLE "equipment_rentals"
  ADD CONSTRAINT "equipment_rentals_type_chk"  CHECK ("allocation_type" = 'rental'),
  ADD CONSTRAINT "equipment_rentals_price_chk" CHECK ("price" >= 0);

ALTER TABLE "equipment_assignments"
  ADD CONSTRAINT "equipment_assignments_type_chk" CHECK ("allocation_type" = 'assignment');

ALTER TABLE "equipment_maintenance"
  ADD CONSTRAINT "equipment_maintenance_type_chk" CHECK ("allocation_type" = 'maintenance'),
  ADD CONSTRAINT "equipment_maintenance_cost_chk" CHECK ("cost" >= 0);

ALTER TABLE "invoices"
  ADD CONSTRAINT "invoices_total_chk"  CHECK ("total_amount" >= 0),
  ADD CONSTRAINT "invoices_dates_chk"  CHECK ("due_at" >= "issued_at"),
  ADD CONSTRAINT "invoices_number_chk" CHECK (length(btrim("invoice_number")) > 0),
  ADD CONSTRAINT "invoices_source_chk" CHECK (num_nonnulls("booking_id", "rental_id") <= 1);

-- ---------------------------------------------------------------------
-- 3. Exclusion-Constraints (keine Überschneidungen)
-- ---------------------------------------------------------------------
ALTER TABLE "equipment_allocations"
  ADD CONSTRAINT "equipment_allocations_no_overlap"
  EXCLUDE USING gist (
    "equipment_id" WITH =,
    tstzrange("start_at", "end_at", '[)') WITH &&
  ) WHERE ("status" <> 'cancelled');

ALTER TABLE "course_sessions"
  ADD CONSTRAINT "course_sessions_no_instructor_overlap"
  EXCLUDE USING gist (
    "instructor_id" WITH =,
    tstzrange("start_time", "end_time", '[)') WITH &&
  ) WHERE ("status" <> 'cancelled');

ALTER TABLE "dive_trips"
  ADD CONSTRAINT "dive_trips_no_instructor_overlap"
  EXCLUDE USING gist (
    "instructor_id" WITH =,
    tstzrange("start_time", "end_time", '[)') WITH &&
  ) WHERE ("status" <> 'cancelled');

-- expires_at ist inklusiv gemeint, daher +1
ALTER TABLE "customer_certifications"
  ADD CONSTRAINT "customer_certifications_no_overlap"
  EXCLUDE USING gist (
    "customer_id" WITH =,
    "certification_id" WITH =,
    daterange("issued_at", COALESCE("expires_at" + 1, 'infinity'::date), '[)') WITH &&
  );

-- ---------------------------------------------------------------------
-- 4. Trigger
-- ---------------------------------------------------------------------

-- 4a. Buchung: Kapazität + Zertifizierungsvoraussetzung (Kurs bzw. Dive Site)
CREATE OR REPLACE FUNCTION public.enforce_booking_rules()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_start timestamptz;
  v_max   integer;
  v_req   integer;
  v_count integer;
  v_day   date;
BEGIN
  IF NEW.booking_status = 'cancelled' THEN
    RETURN NEW;
  END IF;

  IF NEW.session_id IS NOT NULL THEN
    SELECT cs.start_time, cs.max_participants, c.required_certification_id
      INTO v_start, v_max, v_req
    FROM public.course_sessions cs
    JOIN public.courses c ON c.id = cs.course_id
    WHERE cs.id = NEW.session_id
    FOR UPDATE OF cs;
  ELSIF NEW.trip_id IS NOT NULL THEN
    SELECT dt.start_time, dt.max_participants, ds.required_certification_id
      INTO v_start, v_max, v_req
    FROM public.dive_trips dt
    JOIN public.dive_sites ds ON ds.id = dt.site_id
    WHERE dt.id = NEW.trip_id
    FOR UPDATE OF dt;
  ELSE
    RETURN NEW; -- wird vom CHECK bookings_target_chk abgelehnt
  END IF;

  -- Kapazität
  SELECT count(*) INTO v_count
  FROM public.bookings b
  WHERE b.id <> COALESCE(NEW.id, -1)
    AND b.booking_status <> 'cancelled'
    AND ((NEW.session_id IS NOT NULL AND b.session_id = NEW.session_id)
      OR (NEW.trip_id    IS NOT NULL AND b.trip_id    = NEW.trip_id));

  IF v_count >= v_max THEN
    RAISE EXCEPTION 'Kapazität erreicht (max. % Teilnehmer)', v_max
      USING ERRCODE = '23514';
  END IF;

  -- Zertifizierung zum Starttag (Zeitzone der Tauchschule anpassen!)
  IF v_req IS NOT NULL THEN
    v_day := (v_start AT TIME ZONE 'Europe/Berlin')::date;

    IF NOT EXISTS (
      SELECT 1
      FROM public.customer_certifications cc
      WHERE cc.customer_id = NEW.customer_id
        AND cc.certification_id = v_req
        AND cc.issued_at <= v_day
        AND (cc.expires_at IS NULL OR cc.expires_at >= v_day)
    ) THEN
      RAISE EXCEPTION 'Kunde % hat keine gültige Zertifizierung % am %',
        NEW.customer_id, v_req, v_day
        USING ERRCODE = '23514';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER bookings_rules
BEFORE INSERT OR UPDATE OF customer_id, session_id, trip_id, booking_status
ON public.bookings
FOR EACH ROW EXECUTE FUNCTION public.enforce_booking_rules();

-- 4b. Instructor: keine Überschneidung zwischen Sessions UND Trips
CREATE OR REPLACE FUNCTION public.enforce_instructor_availability()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF NEW.status = 'cancelled' THEN
    RETURN NEW;
  END IF;

  PERFORM pg_advisory_xact_lock(hashtext('instructor_availability'), NEW.instructor_id);

  IF EXISTS (
    SELECT 1 FROM public.course_sessions cs
    WHERE cs.instructor_id = NEW.instructor_id
      AND cs.status <> 'cancelled'
      AND NOT (TG_TABLE_NAME = 'course_sessions' AND cs.id = NEW.id)
      AND tstzrange(cs.start_time, cs.end_time, '[)') && tstzrange(NEW.start_time, NEW.end_time, '[)')
  ) OR EXISTS (
    SELECT 1 FROM public.dive_trips dt
    WHERE dt.instructor_id = NEW.instructor_id
      AND dt.status <> 'cancelled'
      AND NOT (TG_TABLE_NAME = 'dive_trips' AND dt.id = NEW.id)
      AND tstzrange(dt.start_time, dt.end_time, '[)') && tstzrange(NEW.start_time, NEW.end_time, '[)')
  ) THEN
    RAISE EXCEPTION 'Instructor % ist im Zeitraum bereits verplant', NEW.instructor_id
      USING ERRCODE = '23P01';
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER course_sessions_instructor_availability
BEFORE INSERT OR UPDATE OF instructor_id, start_time, end_time, status
ON public.course_sessions
FOR EACH ROW EXECUTE FUNCTION public.enforce_instructor_availability();

CREATE TRIGGER dive_trips_instructor_availability
BEFORE INSERT OR UPDATE OF instructor_id, start_time, end_time, status
ON public.dive_trips
FOR EACH ROW EXECUTE FUNCTION public.enforce_instructor_availability();

-- 4c. Rechnung: Kunde muss zur Buchung bzw. zur Miete passen
CREATE OR REPLACE FUNCTION public.enforce_invoice_customer()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF NEW.booking_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public.bookings b
    WHERE b.id = NEW.booking_id AND b.customer_id = NEW.customer_id
  ) THEN
    RAISE EXCEPTION 'Rechnungskunde passt nicht zur Buchung %', NEW.booking_id
      USING ERRCODE = '23514';
  END IF;

  IF NEW.rental_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public.equipment_rentals r
    WHERE r.id = NEW.rental_id AND r.customer_id = NEW.customer_id
  ) THEN
    RAISE EXCEPTION 'Rechnungskunde passt nicht zur Miete %', NEW.rental_id
      USING ERRCODE = '23514';
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER invoices_customer_check
BEFORE INSERT OR UPDATE OF customer_id, booking_id, rental_id
ON public.invoices
FOR EACH ROW EXECUTE FUNCTION public.enforce_invoice_customer();

-- ---------------------------------------------------------------------
-- 5. Row Level Security (ohne Policies: nur Backend/service_role/Prisma-Rolle)
-- ---------------------------------------------------------------------
ALTER TABLE "customers"                 ENABLE ROW LEVEL SECURITY;
ALTER TABLE "instructors"               ENABLE ROW LEVEL SECURITY;
ALTER TABLE "certifications"            ENABLE ROW LEVEL SECURITY;
ALTER TABLE "customer_certifications"   ENABLE ROW LEVEL SECURITY;
ALTER TABLE "instructor_certifications" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "courses"                   ENABLE ROW LEVEL SECURITY;
ALTER TABLE "course_sessions"           ENABLE ROW LEVEL SECURITY;
ALTER TABLE "dive_sites"                ENABLE ROW LEVEL SECURITY;
ALTER TABLE "dive_trips"                ENABLE ROW LEVEL SECURITY;
ALTER TABLE "bookings"                  ENABLE ROW LEVEL SECURITY;
ALTER TABLE "equipment"                 ENABLE ROW LEVEL SECURITY;
ALTER TABLE "equipment_allocations"     ENABLE ROW LEVEL SECURITY;
ALTER TABLE "equipment_rentals"         ENABLE ROW LEVEL SECURITY;
ALTER TABLE "equipment_assignments"     ENABLE ROW LEVEL SECURITY;
ALTER TABLE "equipment_maintenance"     ENABLE ROW LEVEL SECURITY;
ALTER TABLE "invoices"                  ENABLE ROW LEVEL SECURITY;

-- 6. Neubuchung nach Stornierung erlauben (partielle Unique-Indizes)
CREATE UNIQUE INDEX "bookings_active_session_key" ON "bookings"("customer_id", "session_id")
  WHERE "booking_status" <> 'cancelled';

CREATE UNIQUE INDEX "bookings_active_trip_key" ON "bookings"("customer_id", "trip_id")
  WHERE "booking_status" <> 'cancelled';
