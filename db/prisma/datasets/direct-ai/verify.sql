-- Read-only checks of the corrected 578-row direct-AI dataset.
BEGIN;
SET LOCAL TIME ZONE 'Europe/Berlin';
CREATE TEMP VIEW direct_ai_issues AS
SELECT 'certificate_overlap' AS rule, count(*) AS violations
FROM customer_certifications a JOIN customer_certifications b
 ON a.id<b.id AND a.customer_id=b.customer_id AND a.certification_id=b.certification_id
WHERE daterange(a.issued_at,coalesce(a.expires_at+1,'infinity'::date),'[)') && daterange(b.issued_at,coalesce(b.expires_at+1,'infinity'::date),'[)')
UNION ALL
SELECT 'booking_qualification',count(*) FROM bookings b
LEFT JOIN course_sessions s ON s.id=b.session_id LEFT JOIN courses c ON c.id=s.course_id
LEFT JOIN dive_trips t ON t.id=b.trip_id LEFT JOIN dive_sites d ON d.id=t.site_id
WHERE b.booking_status<>'cancelled' AND coalesce(c.required_certification_id,d.required_certification_id) IS NOT NULL
AND NOT EXISTS (SELECT 1 FROM customer_certifications cc WHERE cc.customer_id=b.customer_id
 AND cc.certification_id=coalesce(c.required_certification_id,d.required_certification_id)
 AND cc.issued_at<=coalesce(s.start_at,t.start_at)::date
 AND (cc.expires_at IS NULL OR cc.expires_at>=coalesce(s.start_at,t.start_at)::date))
UNION ALL
SELECT 'customer_time_overlap',count(*) FROM bookings a JOIN bookings b ON a.id<b.id AND a.customer_id=b.customer_id
LEFT JOIN course_sessions sa ON sa.id=a.session_id LEFT JOIN dive_trips ta ON ta.id=a.trip_id
LEFT JOIN course_sessions sb ON sb.id=b.session_id LEFT JOIN dive_trips tb ON tb.id=b.trip_id
WHERE a.booking_status<>'cancelled' AND b.booking_status<>'cancelled'
AND tstzrange(coalesce(sa.start_at,ta.start_at),coalesce(sa.end_at,ta.end_at),'[)') && tstzrange(coalesce(sb.start_at,tb.start_at),coalesce(sb.end_at,tb.end_at),'[)')
UNION ALL
SELECT 'equipment_before_purchase_or_after_retirement',count(*) FROM equipment_allocations a JOIN equipment e ON e.id=a.equipment_id
WHERE a.start_at::date<e.purchased_at OR a.end_at::date>=e.retired_at
UNION ALL
SELECT 'assignment_does_not_cover_event',count(*) FROM equipment_assignments x
JOIN equipment_allocations a ON a.id=x.allocation_id JOIN bookings b ON b.id=x.booking_id
LEFT JOIN course_sessions s ON s.id=b.session_id LEFT JOIN dive_trips t ON t.id=b.trip_id
WHERE a.start_at>coalesce(s.start_at,t.start_at) OR a.end_at<coalesce(s.end_at,t.end_at)
 OR (b.booking_status='cancelled' AND a.status<>'cancelled')
UNION ALL
SELECT 'invoice_customer_or_amount',count(*) FROM invoices i
LEFT JOIN bookings b ON b.id=i.booking_id LEFT JOIN course_sessions s ON s.id=b.session_id
LEFT JOIN courses c ON c.id=s.course_id LEFT JOIN dive_trips t ON t.id=b.trip_id
LEFT JOIN equipment_rentals r ON r.id=i.rental_id
WHERE i.customer_id IS DISTINCT FROM coalesce(b.customer_id,r.customer_id)
 OR i.total_amount IS DISTINCT FROM coalesce(c.price,t.price,r.price)
UNION ALL
SELECT 'booked_outside_snapshot',count(*) FROM bookings b JOIN customers c ON c.id=b.customer_id
WHERE b.booked_at::date>'2026-11-22' OR b.booked_at<c.created_at
UNION ALL
SELECT 'invoice_dates',count(*) FROM invoices
WHERE paid_at::date<issued_at OR paid_at::date>'2026-11-22' OR issued_at>'2026-11-22'
UNION ALL
SELECT 'over_capacity',count(*) FROM (
 SELECT s.id FROM course_sessions s JOIN bookings b ON b.session_id=s.id AND b.booking_status<>'cancelled'
 GROUP BY s.id,s.max_participants HAVING count(*)>s.max_participants
 UNION ALL
 SELECT t.id FROM dive_trips t JOIN bookings b ON b.trip_id=t.id AND b.booking_status<>'cancelled'
 GROUP BY t.id,t.max_participants HAVING count(*)>t.max_participants
) q;
TABLE direct_ai_issues;
DO $$
DECLARE r record; actual bigint;
BEGIN
 IF EXISTS(SELECT 1 FROM direct_ai_issues WHERE violations<>0) THEN
   RAISE EXCEPTION 'Corrected direct-AI dataset has inconsistencies; see direct_ai_issues';
 END IF;
 FOR r IN SELECT * FROM (VALUES
   ('certifications',10),('customers',28),('instructors',5),('customer_certifications',46),
   ('instructor_certifications',15),('courses',7),('dive_sites',8),('course_sessions',17),
   ('dive_trips',12),('bookings',105),('equipment',36),('equipment_allocations',89),
   ('equipment_rentals',15),('equipment_assignments',67),('equipment_maintenance',7),('invoices',111)
 ) AS expected(table_name,rows) LOOP
   EXECUTE format('SELECT count(*) FROM public.%I',r.table_name) INTO actual;
   IF actual<>r.rows THEN RAISE EXCEPTION 'Unexpected count in %: expected %, got %',r.table_name,r.rows,actual; END IF;
 END LOOP;
 IF (SELECT count(*) FROM bookings WHERE session_id=15 AND booking_status='confirmed') <> 2 THEN
   RAISE EXCEPTION 'Full-event scenario missing';
 END IF;
 IF EXISTS(SELECT 1 FROM bookings WHERE session_id=16 AND booking_status='confirmed') THEN
   RAISE EXCEPTION 'Empty-event scenario is not empty';
 END IF;
 IF NOT EXISTS(SELECT 1 FROM bookings b JOIN course_sessions s ON s.id=b.session_id
   JOIN customer_certifications cc ON cc.customer_id=b.customer_id
   WHERE b.id=105 AND cc.expires_at=s.start_at::date AND cc.certification_id=1) THEN
   RAISE EXCEPTION 'Inclusive certification-expiry boundary missing';
 END IF;
 IF NOT EXISTS(SELECT 1 FROM equipment_allocations a JOIN equipment_allocations b
   ON a.id=88 AND b.id=89 AND a.equipment_id=b.equipment_id AND a.end_at=b.start_at) THEN
   RAISE EXCEPTION 'Adjacent equipment intervals missing';
 END IF;
END $$;
SELECT 578 AS validated_rows, '2026-11-22'::date AS snapshot;
DROP VIEW direct_ai_issues;
COMMIT;
