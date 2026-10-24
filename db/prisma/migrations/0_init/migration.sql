-- CreateSchema
CREATE SCHEMA IF NOT EXISTS "public";

-- CreateTable
CREATE TABLE "customers" (
    "id" SERIAL NOT NULL,
    "first_name" TEXT NOT NULL,
    "last_name" TEXT NOT NULL,
    "email" TEXT NOT NULL,
    "phone" TEXT,
    "birth_date" DATE,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "customers_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "instructors" (
    "id" SERIAL NOT NULL,
    "first_name" TEXT NOT NULL,
    "last_name" TEXT NOT NULL,
    "email" TEXT NOT NULL,
    "qualification" TEXT NOT NULL,
    "active" BOOLEAN NOT NULL DEFAULT true,

    CONSTRAINT "instructors_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "courses" (
    "id" SERIAL NOT NULL,
    "name" TEXT NOT NULL,
    "description" TEXT,
    "price" DECIMAL(10,2) NOT NULL,
    "duration_days" INTEGER NOT NULL,
    "required_certification_id" INTEGER,

    CONSTRAINT "courses_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "course_sessions" (
    "id" SERIAL NOT NULL,
    "course_id" INTEGER NOT NULL,
    "instructor_id" INTEGER NOT NULL,
    "start_time" TIMESTAMP(3) NOT NULL,
    "end_time" TIMESTAMP(3) NOT NULL,
    "max_participants" INTEGER NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'planned',

    CONSTRAINT "course_sessions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "course_bookings" (
    "id" SERIAL NOT NULL,
    "customer_id" INTEGER NOT NULL,
    "session_id" INTEGER NOT NULL,
    "booked_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "booking_status" TEXT NOT NULL DEFAULT 'confirmed',
    "completion_status" TEXT NOT NULL DEFAULT 'pending',

    CONSTRAINT "course_bookings_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "certifications" (
    "id" SERIAL NOT NULL,
    "name" TEXT NOT NULL,
    "organization" TEXT NOT NULL,
    "description" TEXT,

    CONSTRAINT "certifications_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "customer_certifications" (
    "id" SERIAL NOT NULL,
    "customer_id" INTEGER NOT NULL,
    "certification_id" INTEGER NOT NULL,
    "certificate_number" TEXT NOT NULL,
    "issued_at" DATE NOT NULL,
    "expires_at" DATE,

    CONSTRAINT "customer_certifications_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "dive_sites" (
    "id" SERIAL NOT NULL,
    "name" TEXT NOT NULL,
    "location" TEXT NOT NULL,
    "max_depth_meters" INTEGER NOT NULL,
    "description" TEXT,

    CONSTRAINT "dive_sites_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "dive_trips" (
    "id" SERIAL NOT NULL,
    "site_id" INTEGER NOT NULL,
    "instructor_id" INTEGER NOT NULL,
    "start_time" TIMESTAMP(3) NOT NULL,
    "end_time" TIMESTAMP(3) NOT NULL,
    "max_participants" INTEGER NOT NULL,
    "price" DECIMAL(10,2) NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'planned',

    CONSTRAINT "dive_trips_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "trip_participants" (
    "id" SERIAL NOT NULL,
    "trip_id" INTEGER NOT NULL,
    "customer_id" INTEGER NOT NULL,
    "registered_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "status" TEXT NOT NULL DEFAULT 'registered',

    CONSTRAINT "trip_participants_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "equipment" (
    "id" SERIAL NOT NULL,
    "inventory_number" TEXT NOT NULL,
    "equipment_type" TEXT NOT NULL,
    "manufacturer" TEXT,
    "model" TEXT,
    "size" TEXT,
    "condition" TEXT NOT NULL DEFAULT 'good',
    "status" TEXT NOT NULL DEFAULT 'available',
    "purchased_at" DATE,

    CONSTRAINT "equipment_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "equipment_assignments" (
    "id" SERIAL NOT NULL,
    "booking_id" INTEGER NOT NULL,
    "equipment_id" INTEGER NOT NULL,
    "assigned_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "returned_at" TIMESTAMP(3),
    "status" TEXT NOT NULL DEFAULT 'assigned',

    CONSTRAINT "equipment_assignments_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "equipment_maintenance" (
    "id" SERIAL NOT NULL,
    "equipment_id" INTEGER NOT NULL,
    "maintenance_date" DATE NOT NULL,
    "next_maintenance" DATE,
    "description" TEXT NOT NULL,
    "cost" DECIMAL(10,2) NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'completed',

    CONSTRAINT "equipment_maintenance_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "equipment_rentals" (
    "id" SERIAL NOT NULL,
    "equipment_id" INTEGER NOT NULL,
    "customer_id" INTEGER NOT NULL,
    "rental_start" TIMESTAMP(3) NOT NULL,
    "rental_end" TIMESTAMP(3) NOT NULL,
    "returned_at" TIMESTAMP(3),
    "price" DECIMAL(10,2) NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'active',

    CONSTRAINT "equipment_rentals_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "invoices" (
    "id" SERIAL NOT NULL,
    "customer_id" INTEGER NOT NULL,
    "booking_id" INTEGER,
    "participant_id" INTEGER,
    "rental_id" INTEGER,
    "invoice_number" TEXT NOT NULL,
    "total_amount" DECIMAL(10,2) NOT NULL,
    "issued_at" DATE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "due_at" DATE NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'open',

    CONSTRAINT "invoices_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "customers_email_key" ON "customers"("email");

-- CreateIndex
CREATE UNIQUE INDEX "instructors_email_key" ON "instructors"("email");

-- CreateIndex
CREATE INDEX "course_sessions_course_id_idx" ON "course_sessions"("course_id");

-- CreateIndex
CREATE INDEX "course_sessions_instructor_id_start_time_idx" ON "course_sessions"("instructor_id", "start_time");

-- CreateIndex
CREATE INDEX "course_bookings_session_id_idx" ON "course_bookings"("session_id");

-- CreateIndex
CREATE UNIQUE INDEX "course_bookings_customer_id_session_id_key" ON "course_bookings"("customer_id", "session_id");

-- CreateIndex
CREATE UNIQUE INDEX "certifications_name_organization_key" ON "certifications"("name", "organization");

-- CreateIndex
CREATE UNIQUE INDEX "customer_certifications_certificate_number_key" ON "customer_certifications"("certificate_number");

-- CreateIndex
CREATE INDEX "customer_certifications_customer_id_certification_id_idx" ON "customer_certifications"("customer_id", "certification_id");

-- CreateIndex
CREATE INDEX "dive_trips_site_id_idx" ON "dive_trips"("site_id");

-- CreateIndex
CREATE INDEX "dive_trips_instructor_id_start_time_idx" ON "dive_trips"("instructor_id", "start_time");

-- CreateIndex
CREATE INDEX "trip_participants_customer_id_idx" ON "trip_participants"("customer_id");

-- CreateIndex
CREATE UNIQUE INDEX "trip_participants_trip_id_customer_id_key" ON "trip_participants"("trip_id", "customer_id");

-- CreateIndex
CREATE UNIQUE INDEX "equipment_inventory_number_key" ON "equipment"("inventory_number");

-- CreateIndex
CREATE INDEX "equipment_equipment_type_status_idx" ON "equipment"("equipment_type", "status");

-- CreateIndex
CREATE INDEX "equipment_assignments_equipment_id_status_idx" ON "equipment_assignments"("equipment_id", "status");

-- CreateIndex
CREATE UNIQUE INDEX "equipment_assignments_booking_id_equipment_id_key" ON "equipment_assignments"("booking_id", "equipment_id");

-- CreateIndex
CREATE INDEX "equipment_maintenance_equipment_id_maintenance_date_idx" ON "equipment_maintenance"("equipment_id", "maintenance_date");

-- CreateIndex
CREATE INDEX "equipment_rentals_equipment_id_rental_start_rental_end_idx" ON "equipment_rentals"("equipment_id", "rental_start", "rental_end");

-- CreateIndex
CREATE INDEX "equipment_rentals_customer_id_idx" ON "equipment_rentals"("customer_id");

-- CreateIndex
CREATE UNIQUE INDEX "invoices_invoice_number_key" ON "invoices"("invoice_number");

-- CreateIndex
CREATE INDEX "invoices_customer_id_idx" ON "invoices"("customer_id");

-- CreateIndex
CREATE INDEX "invoices_status_due_at_idx" ON "invoices"("status", "due_at");

-- AddForeignKey
ALTER TABLE "courses" ADD CONSTRAINT "courses_required_certification_id_fkey" FOREIGN KEY ("required_certification_id") REFERENCES "certifications"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "course_sessions" ADD CONSTRAINT "course_sessions_course_id_fkey" FOREIGN KEY ("course_id") REFERENCES "courses"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "course_sessions" ADD CONSTRAINT "course_sessions_instructor_id_fkey" FOREIGN KEY ("instructor_id") REFERENCES "instructors"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "course_bookings" ADD CONSTRAINT "course_bookings_customer_id_fkey" FOREIGN KEY ("customer_id") REFERENCES "customers"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "course_bookings" ADD CONSTRAINT "course_bookings_session_id_fkey" FOREIGN KEY ("session_id") REFERENCES "course_sessions"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "customer_certifications" ADD CONSTRAINT "customer_certifications_customer_id_fkey" FOREIGN KEY ("customer_id") REFERENCES "customers"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "customer_certifications" ADD CONSTRAINT "customer_certifications_certification_id_fkey" FOREIGN KEY ("certification_id") REFERENCES "certifications"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "dive_trips" ADD CONSTRAINT "dive_trips_site_id_fkey" FOREIGN KEY ("site_id") REFERENCES "dive_sites"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "dive_trips" ADD CONSTRAINT "dive_trips_instructor_id_fkey" FOREIGN KEY ("instructor_id") REFERENCES "instructors"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "trip_participants" ADD CONSTRAINT "trip_participants_trip_id_fkey" FOREIGN KEY ("trip_id") REFERENCES "dive_trips"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "trip_participants" ADD CONSTRAINT "trip_participants_customer_id_fkey" FOREIGN KEY ("customer_id") REFERENCES "customers"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "equipment_assignments" ADD CONSTRAINT "equipment_assignments_booking_id_fkey" FOREIGN KEY ("booking_id") REFERENCES "course_bookings"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "equipment_assignments" ADD CONSTRAINT "equipment_assignments_equipment_id_fkey" FOREIGN KEY ("equipment_id") REFERENCES "equipment"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "equipment_maintenance" ADD CONSTRAINT "equipment_maintenance_equipment_id_fkey" FOREIGN KEY ("equipment_id") REFERENCES "equipment"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "equipment_rentals" ADD CONSTRAINT "equipment_rentals_equipment_id_fkey" FOREIGN KEY ("equipment_id") REFERENCES "equipment"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "equipment_rentals" ADD CONSTRAINT "equipment_rentals_customer_id_fkey" FOREIGN KEY ("customer_id") REFERENCES "customers"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "invoices" ADD CONSTRAINT "invoices_customer_id_fkey" FOREIGN KEY ("customer_id") REFERENCES "customers"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "invoices" ADD CONSTRAINT "invoices_booking_id_fkey" FOREIGN KEY ("booking_id") REFERENCES "course_bookings"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "invoices" ADD CONSTRAINT "invoices_participant_id_fkey" FOREIGN KEY ("participant_id") REFERENCES "trip_participants"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "invoices" ADD CONSTRAINT "invoices_rental_id_fkey" FOREIGN KEY ("rental_id") REFERENCES "equipment_rentals"("id") ON DELETE SET NULL ON UPDATE CASCADE;
