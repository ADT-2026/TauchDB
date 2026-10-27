-- CreateEnum
CREATE TYPE "BookingStatus" AS ENUM ('confirmed', 'cancelled');

-- CreateEnum
CREATE TYPE "ScheduleStatus" AS ENUM ('planned', 'completed', 'cancelled');

-- CreateEnum
CREATE TYPE "EquipmentCondition" AS ENUM ('new', 'good', 'worn', 'defective');

-- CreateEnum
CREATE TYPE "AllocationType" AS ENUM ('rental', 'assignment', 'maintenance');

-- CreateEnum
CREATE TYPE "AllocationStatus" AS ENUM ('active', 'cancelled', 'completed');

-- CreateTable
CREATE TABLE "customers" (
    "id" SERIAL NOT NULL,
    "first_name" TEXT NOT NULL,
    "last_name" TEXT NOT NULL,
    "email" TEXT NOT NULL,
    "phone" TEXT,
    "birth_date" DATE,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "customers_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "instructors" (
    "id" SERIAL NOT NULL,
    "first_name" TEXT NOT NULL,
    "last_name" TEXT NOT NULL,
    "email" TEXT NOT NULL,
    "active" BOOLEAN NOT NULL DEFAULT true,

    CONSTRAINT "instructors_pkey" PRIMARY KEY ("id")
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
CREATE TABLE "instructor_certifications" (
    "id" SERIAL NOT NULL,
    "instructor_id" INTEGER NOT NULL,
    "certification_id" INTEGER NOT NULL,
    "issued_at" DATE NOT NULL,
    "expires_at" DATE,

    CONSTRAINT "instructor_certifications_pkey" PRIMARY KEY ("id")
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
    "start_time" TIMESTAMPTZ(3) NOT NULL,
    "end_time" TIMESTAMPTZ(3) NOT NULL,
    "max_participants" INTEGER NOT NULL,
    "status" "ScheduleStatus" NOT NULL DEFAULT 'planned',

    CONSTRAINT "course_sessions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "dive_sites" (
    "id" SERIAL NOT NULL,
    "name" TEXT NOT NULL,
    "location" TEXT NOT NULL,
    "max_depth_meters" INTEGER NOT NULL,
    "description" TEXT,
    "required_certification_id" INTEGER,

    CONSTRAINT "dive_sites_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "dive_trips" (
    "id" SERIAL NOT NULL,
    "site_id" INTEGER NOT NULL,
    "instructor_id" INTEGER NOT NULL,
    "start_time" TIMESTAMPTZ(3) NOT NULL,
    "end_time" TIMESTAMPTZ(3) NOT NULL,
    "max_participants" INTEGER NOT NULL,
    "price" DECIMAL(10,2) NOT NULL,
    "status" "ScheduleStatus" NOT NULL DEFAULT 'planned',

    CONSTRAINT "dive_trips_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "bookings" (
    "id" SERIAL NOT NULL,
    "customer_id" INTEGER NOT NULL,
    "session_id" INTEGER,
    "trip_id" INTEGER,
    "booked_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "booking_status" "BookingStatus" NOT NULL DEFAULT 'confirmed',
    "passed_at" TIMESTAMPTZ(3),

    CONSTRAINT "bookings_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "equipment" (
    "id" SERIAL NOT NULL,
    "inventory_number" TEXT NOT NULL,
    "equipment_type" TEXT NOT NULL,
    "manufacturer" TEXT,
    "model" TEXT,
    "size" TEXT,
    "condition" "EquipmentCondition" NOT NULL DEFAULT 'good',
    "purchased_at" DATE,
    "retired_at" DATE,

    CONSTRAINT "equipment_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "equipment_allocations" (
    "id" SERIAL NOT NULL,
    "equipment_id" INTEGER NOT NULL,
    "start_at" TIMESTAMPTZ(3) NOT NULL,
    "end_at" TIMESTAMPTZ(3) NOT NULL,
    "allocation_type" "AllocationType" NOT NULL,
    "status" "AllocationStatus" NOT NULL DEFAULT 'active',
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "equipment_allocations_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "equipment_rentals" (
    "id" SERIAL NOT NULL,
    "allocation_id" INTEGER NOT NULL,
    "allocation_type" "AllocationType" NOT NULL DEFAULT 'rental',
    "customer_id" INTEGER NOT NULL,
    "price" DECIMAL(10,2) NOT NULL,
    "returned_at" TIMESTAMPTZ(3),
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "equipment_rentals_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "equipment_assignments" (
    "id" SERIAL NOT NULL,
    "allocation_id" INTEGER NOT NULL,
    "allocation_type" "AllocationType" NOT NULL DEFAULT 'assignment',
    "booking_id" INTEGER NOT NULL,
    "returned_at" TIMESTAMPTZ(3),
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "equipment_assignments_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "equipment_maintenance" (
    "id" SERIAL NOT NULL,
    "allocation_id" INTEGER NOT NULL,
    "allocation_type" "AllocationType" NOT NULL DEFAULT 'maintenance',
    "description" TEXT NOT NULL,
    "cost" DECIMAL(10,2) NOT NULL,
    "next_maintenance" DATE,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "equipment_maintenance_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "invoices" (
    "id" SERIAL NOT NULL,
    "customer_id" INTEGER NOT NULL,
    "booking_id" INTEGER,
    "rental_id" INTEGER,
    "invoice_number" TEXT NOT NULL,
    "total_amount" DECIMAL(10,2) NOT NULL,
    "issued_at" DATE NOT NULL DEFAULT CURRENT_DATE,
    "due_at" DATE NOT NULL,
    "paid_at" TIMESTAMPTZ(3),

    CONSTRAINT "invoices_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "customers_email_key" ON "customers"("email");

-- CreateIndex
CREATE UNIQUE INDEX "instructors_email_key" ON "instructors"("email");

-- CreateIndex
CREATE UNIQUE INDEX "certifications_name_organization_key" ON "certifications"("name", "organization");

-- CreateIndex
CREATE INDEX "customer_certifications_customer_id_certification_id_idx" ON "customer_certifications"("customer_id", "certification_id");

-- CreateIndex
CREATE UNIQUE INDEX "customer_certifications_certification_id_certificate_number_key" ON "customer_certifications"("certification_id", "certificate_number");

-- CreateIndex
CREATE UNIQUE INDEX "instructor_certifications_instructor_id_certification_id_key" ON "instructor_certifications"("instructor_id", "certification_id");

-- CreateIndex
CREATE INDEX "courses_required_certification_id_idx" ON "courses"("required_certification_id");

-- CreateIndex
CREATE INDEX "course_sessions_course_id_idx" ON "course_sessions"("course_id");

-- CreateIndex
CREATE INDEX "course_sessions_instructor_id_start_time_idx" ON "course_sessions"("instructor_id", "start_time");

-- CreateIndex
CREATE INDEX "dive_sites_required_certification_id_idx" ON "dive_sites"("required_certification_id");

-- CreateIndex
CREATE INDEX "dive_trips_site_id_idx" ON "dive_trips"("site_id");

-- CreateIndex
CREATE INDEX "dive_trips_instructor_id_start_time_idx" ON "dive_trips"("instructor_id", "start_time");

-- CreateIndex
CREATE INDEX "bookings_session_id_idx" ON "bookings"("session_id");

-- CreateIndex
CREATE INDEX "bookings_trip_id_idx" ON "bookings"("trip_id");

-- CreateIndex
CREATE UNIQUE INDEX "equipment_inventory_number_key" ON "equipment"("inventory_number");

-- CreateIndex
CREATE INDEX "equipment_equipment_type_retired_at_idx" ON "equipment"("equipment_type", "retired_at");

-- CreateIndex
CREATE INDEX "equipment_allocations_equipment_id_idx" ON "equipment_allocations"("equipment_id");

-- CreateIndex
CREATE INDEX "equipment_allocations_start_at_end_at_idx" ON "equipment_allocations"("start_at", "end_at");

-- CreateIndex
CREATE UNIQUE INDEX "equipment_allocations_id_allocation_type_key" ON "equipment_allocations"("id", "allocation_type");

-- CreateIndex
CREATE UNIQUE INDEX "equipment_rentals_allocation_id_key" ON "equipment_rentals"("allocation_id");

-- CreateIndex
CREATE INDEX "equipment_rentals_customer_id_idx" ON "equipment_rentals"("customer_id");

-- CreateIndex
CREATE UNIQUE INDEX "equipment_rentals_allocation_id_allocation_type_key" ON "equipment_rentals"("allocation_id", "allocation_type");

-- CreateIndex
CREATE UNIQUE INDEX "equipment_assignments_allocation_id_key" ON "equipment_assignments"("allocation_id");

-- CreateIndex
CREATE INDEX "equipment_assignments_booking_id_idx" ON "equipment_assignments"("booking_id");

-- CreateIndex
CREATE UNIQUE INDEX "equipment_assignments_allocation_id_allocation_type_key" ON "equipment_assignments"("allocation_id", "allocation_type");

-- CreateIndex
CREATE UNIQUE INDEX "equipment_maintenance_allocation_id_key" ON "equipment_maintenance"("allocation_id");

-- CreateIndex
CREATE UNIQUE INDEX "equipment_maintenance_allocation_id_allocation_type_key" ON "equipment_maintenance"("allocation_id", "allocation_type");

-- CreateIndex
CREATE UNIQUE INDEX "invoices_booking_id_key" ON "invoices"("booking_id");

-- CreateIndex
CREATE UNIQUE INDEX "invoices_rental_id_key" ON "invoices"("rental_id");

-- CreateIndex
CREATE UNIQUE INDEX "invoices_invoice_number_key" ON "invoices"("invoice_number");

-- CreateIndex
CREATE INDEX "invoices_customer_id_idx" ON "invoices"("customer_id");

-- CreateIndex
CREATE INDEX "invoices_booking_id_idx" ON "invoices"("booking_id");

-- CreateIndex
CREATE INDEX "invoices_rental_id_idx" ON "invoices"("rental_id");

-- CreateIndex
CREATE INDEX "invoices_paid_at_due_at_idx" ON "invoices"("paid_at", "due_at");

-- AddForeignKey
ALTER TABLE "customer_certifications" ADD CONSTRAINT "customer_certifications_customer_id_fkey" FOREIGN KEY ("customer_id") REFERENCES "customers"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "customer_certifications" ADD CONSTRAINT "customer_certifications_certification_id_fkey" FOREIGN KEY ("certification_id") REFERENCES "certifications"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "instructor_certifications" ADD CONSTRAINT "instructor_certifications_instructor_id_fkey" FOREIGN KEY ("instructor_id") REFERENCES "instructors"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "instructor_certifications" ADD CONSTRAINT "instructor_certifications_certification_id_fkey" FOREIGN KEY ("certification_id") REFERENCES "certifications"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "courses" ADD CONSTRAINT "courses_required_certification_id_fkey" FOREIGN KEY ("required_certification_id") REFERENCES "certifications"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "course_sessions" ADD CONSTRAINT "course_sessions_course_id_fkey" FOREIGN KEY ("course_id") REFERENCES "courses"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "course_sessions" ADD CONSTRAINT "course_sessions_instructor_id_fkey" FOREIGN KEY ("instructor_id") REFERENCES "instructors"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "dive_sites" ADD CONSTRAINT "dive_sites_required_certification_id_fkey" FOREIGN KEY ("required_certification_id") REFERENCES "certifications"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "dive_trips" ADD CONSTRAINT "dive_trips_site_id_fkey" FOREIGN KEY ("site_id") REFERENCES "dive_sites"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "dive_trips" ADD CONSTRAINT "dive_trips_instructor_id_fkey" FOREIGN KEY ("instructor_id") REFERENCES "instructors"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "bookings" ADD CONSTRAINT "bookings_customer_id_fkey" FOREIGN KEY ("customer_id") REFERENCES "customers"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "bookings" ADD CONSTRAINT "bookings_session_id_fkey" FOREIGN KEY ("session_id") REFERENCES "course_sessions"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "bookings" ADD CONSTRAINT "bookings_trip_id_fkey" FOREIGN KEY ("trip_id") REFERENCES "dive_trips"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "equipment_allocations" ADD CONSTRAINT "equipment_allocations_equipment_id_fkey" FOREIGN KEY ("equipment_id") REFERENCES "equipment"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "equipment_rentals" ADD CONSTRAINT "equipment_rentals_allocation_id_allocation_type_fkey" FOREIGN KEY ("allocation_id", "allocation_type") REFERENCES "equipment_allocations"("id", "allocation_type") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "equipment_rentals" ADD CONSTRAINT "equipment_rentals_customer_id_fkey" FOREIGN KEY ("customer_id") REFERENCES "customers"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "equipment_assignments" ADD CONSTRAINT "equipment_assignments_allocation_id_allocation_type_fkey" FOREIGN KEY ("allocation_id", "allocation_type") REFERENCES "equipment_allocations"("id", "allocation_type") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "equipment_assignments" ADD CONSTRAINT "equipment_assignments_booking_id_fkey" FOREIGN KEY ("booking_id") REFERENCES "bookings"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "equipment_maintenance" ADD CONSTRAINT "equipment_maintenance_allocation_id_allocation_type_fkey" FOREIGN KEY ("allocation_id", "allocation_type") REFERENCES "equipment_allocations"("id", "allocation_type") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "invoices" ADD CONSTRAINT "invoices_customer_id_fkey" FOREIGN KEY ("customer_id") REFERENCES "customers"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "invoices" ADD CONSTRAINT "invoices_booking_id_fkey" FOREIGN KEY ("booking_id") REFERENCES "bookings"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "invoices" ADD CONSTRAINT "invoices_rental_id_fkey" FOREIGN KEY ("rental_id") REFERENCES "equipment_rentals"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
