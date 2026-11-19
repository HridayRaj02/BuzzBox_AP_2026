-- =====================================================================
-- BuzzBox - Useful application and reporting queries
-- Database: PostgreSQL
--
-- These are read-only queries for the schema in 03_schema.sql.
-- Bind the named values noted in comments in the application layer where
-- a query needs a particular user, event, city, or ticket.
-- =====================================================================

-- 1. Browse all events that have not started, with their organizer,
--    venue, categories, and the lowest ticket price.
SELECT
    e."id" AS "eventId",
    e."name" AS "eventName",
    e."startDate",
    e."endDate",
    e."status",
    o."organizationName",
    v."name" AS "venueName",
    v."city",
    STRING_AGG(DISTINCT c."name", ', ' ORDER BY c."name") AS "categories",
    MIN(tt."price") AS "startingPrice"
FROM "Event" e
JOIN "Organizer" o ON o."id" = e."organizerId"
LEFT JOIN "Venue" v ON v."id" = e."venueId"
LEFT JOIN "EventCategory" ec ON ec."eventId" = e."id"
LEFT JOIN "Category" c ON c."id" = ec."categoryId"
LEFT JOIN "TicketType" tt ON tt."eventId" = e."id"
WHERE e."status" = 'upcoming'
  AND e."startDate" > CURRENT_TIMESTAMP
GROUP BY e."id", e."name", e."startDate", e."endDate", e."status",
         o."organizationName", v."name", v."city"
ORDER BY e."startDate";


-- 2. List ticket types that are currently saleable, including remaining
--    inventory. Optional filter: AND tt."eventId" = :event_id
SELECT
    tt."id" AS "ticketTypeId",
    e."id" AS "eventId",
    e."name" AS "eventName",
    tt."name" AS "ticketType",
    tt."price",
    tt."availableQuantity",
    tt."totalQuantity",
    ROUND(100.0 * tt."availableQuantity" / tt."totalQuantity", 2) AS "availabilityPercent",
    tt."saleStart",
    tt."saleEnd"
FROM "TicketType" tt
JOIN "Event" e ON e."id" = tt."eventId"
WHERE e."status" = 'upcoming'
  AND (tt."saleStart" IS NULL OR tt."saleStart" <= CURRENT_TIMESTAMP)
  AND (tt."saleEnd" IS NULL OR tt."saleEnd" >= CURRENT_TIMESTAMP)
  AND tt."availableQuantity" > 0
ORDER BY e."startDate", tt."price";


-- 3. Show a customer's booking history and payment state.
--    Bind :user_id to the signed-in user's ID.
WITH booking_tickets AS (
    SELECT
        bi."bookingId",
        STRING_AGG(
            bi."quantity"::TEXT || ' × ' || tt."name",
            ', ' ORDER BY tt."name"
        ) AS "tickets"
    FROM "BookingItem" bi
    JOIN "TicketType" tt ON tt."id" = bi."ticketTypeId"
    GROUP BY bi."bookingId"
), booking_payments AS (
    SELECT
        p."bookingId",
        COALESCE(MAX(p."status") FILTER (WHERE p."status" = 'successful'),
                 MAX(p."status")) AS "paymentStatus"
    FROM "Payment" p
    GROUP BY p."bookingId"
)
SELECT
    b."id" AS "bookingId",
    b."bookingCode",
    b."bookingDate",
    b."status" AS "bookingStatus",
    b."totalAmount",
    e."name" AS "eventName",
    e."startDate",
    COALESCE(bt."tickets", 'No tickets') AS "tickets",
    bp."paymentStatus"
FROM "Booking" b
JOIN "Event" e ON e."id" = b."eventId"
LEFT JOIN booking_tickets bt ON bt."bookingId" = b."id"
LEFT JOIN booking_payments bp ON bp."bookingId" = b."id"
WHERE b."userId" = :user_id
ORDER BY b."bookingDate" DESC;


-- 4. Event sales report. It uses successful payments only, so pending,
--    failed, and refunded attempts do not inflate revenue.
WITH successful_payments AS (
    SELECT
        p."bookingId",
        SUM(p."amount") AS "revenue"
    FROM "Payment" p
    WHERE p."status" = 'successful'
    GROUP BY p."bookingId"
), confirmed_ticket_counts AS (
    SELECT
        b."eventId",
        SUM(bi."quantity") AS "ticketsSold"
    FROM "Booking" b
    JOIN "BookingItem" bi ON bi."bookingId" = b."id"
    WHERE b."status" = 'confirmed'
    GROUP BY b."eventId"
), revenue_by_event AS (
    SELECT
        b."eventId",
        COUNT(DISTINCT b."id") AS "paidBookings",
        SUM(sp."revenue") AS "revenue"
    FROM "Booking" b
    JOIN successful_payments sp ON sp."bookingId" = b."id"
    WHERE b."status" = 'confirmed'
    GROUP BY b."eventId"
)
SELECT
    e."id" AS "eventId",
    e."name" AS "eventName",
    COALESCE(ctc."ticketsSold", 0) AS "ticketsSold",
    COALESCE(rbe."paidBookings", 0) AS "paidBookings",
    COALESCE(rbe."revenue", 0.00) AS "revenue"
FROM "Event" e
LEFT JOIN confirmed_ticket_counts ctc ON ctc."eventId" = e."id"
LEFT JOIN revenue_by_event rbe ON rbe."eventId" = e."id"
ORDER BY "revenue" DESC, "ticketsSold" DESC, e."startDate" DESC;


-- 5. Compare venue capacity with confirmed tickets and completed check-ins.
WITH confirmed_tickets AS (
    SELECT b."eventId", SUM(bi."quantity") AS "ticketsSold"
    FROM "Booking" b
    JOIN "BookingItem" bi ON bi."bookingId" = b."id"
    WHERE b."status" = 'confirmed'
    GROUP BY b."eventId"
), event_check_ins AS (
    SELECT b."eventId", COUNT(ci."id") AS "checkedIn"
    FROM "Booking" b
    JOIN "BookingItem" bi ON bi."bookingId" = b."id"
    JOIN "Ticket" t ON t."bookingItemId" = bi."id"
    JOIN "CheckIn" ci ON ci."ticketId" = t."id"
    GROUP BY b."eventId"
)
SELECT
    e."id" AS "eventId",
    e."name" AS "eventName",
    v."name" AS "venueName",
    v."capacity",
    COALESCE(ct."ticketsSold", 0) AS "ticketsSold",
    COALESCE(eci."checkedIn", 0) AS "checkedIn",
    v."capacity" - COALESCE(ct."ticketsSold", 0) AS "remainingCapacity"
FROM "Event" e
JOIN "Venue" v ON v."id" = e."venueId"
LEFT JOIN confirmed_tickets ct ON ct."eventId" = e."id"
LEFT JOIN event_check_ins eci ON eci."eventId" = e."id"
ORDER BY e."startDate" DESC;


-- 6. Identify ticket types close to selling out (20% or fewer left).
SELECT
    e."id" AS "eventId",
    e."name" AS "eventName",
    tt."id" AS "ticketTypeId",
    tt."name" AS "ticketType",
    tt."availableQuantity",
    tt."totalQuantity",
    ROUND(100.0 * tt."availableQuantity" / tt."totalQuantity", 2) AS "availabilityPercent"
FROM "TicketType" tt
JOIN "Event" e ON e."id" = tt."eventId"
WHERE e."status" IN ('upcoming', 'ongoing')
  AND tt."availableQuantity" <= tt."totalQuantity" * 0.20
ORDER BY "availabilityPercent", e."startDate";


-- 7. Find the most valuable customers by successful spend.
SELECT
    u."id" AS "userId",
    u."fullName",
    u."email",
    COUNT(DISTINCT b."id") AS "confirmedBookings",
    SUM(p."amount") AS "totalSpent"
FROM "User" u
JOIN "Booking" b ON b."userId" = u."id"
JOIN "Payment" p ON p."bookingId" = b."id"
WHERE b."status" = 'confirmed'
  AND p."status" = 'successful'
GROUP BY u."id", u."fullName", u."email"
ORDER BY "totalSpent" DESC, "confirmedBookings" DESC
LIMIT 10;


-- 8. Validate a ticket by its QR code before checking the guest in.
--    Bind :qr_code to the UUID encoded in the scanned QR code.
SELECT
    t."id" AS "ticketId",
    t."ticketCode",
    t."status" AS "ticketStatus",
    e."id" AS "eventId",
    e."name" AS "eventName",
    e."startDate",
    u."fullName" AS "guestName",
    ci."checkedInAt",
    CASE
        WHEN b."status" <> 'confirmed' THEN 'invalid booking'
        WHEN t."status" <> 'valid' THEN 'ticket is not valid'
        WHEN ci."id" IS NOT NULL THEN 'already checked in'
        WHEN e."status" = 'cancelled' THEN 'event cancelled'
        ELSE 'eligible for check-in'
    END AS "checkInResult"
FROM "Ticket" t
JOIN "BookingItem" bi ON bi."id" = t."bookingItemId"
JOIN "Booking" b ON b."id" = bi."bookingId"
JOIN "Event" e ON e."id" = b."eventId"
JOIN "User" u ON u."id" = b."userId"
LEFT JOIN "CheckIn" ci ON ci."ticketId" = t."id"
WHERE t."qrCode" = :qr_code::UUID;


-- 9. Show organizer performance across all of their events.
WITH sales AS (
    SELECT
        b."eventId",
        SUM(p."amount") AS "revenue"
    FROM "Booking" b
    JOIN "Payment" p ON p."bookingId" = b."id"
    WHERE b."status" = 'confirmed'
      AND p."status" = 'successful'
    GROUP BY b."eventId"
)
SELECT
    o."id" AS "organizerId",
    o."organizationName",
    COUNT(e."id") AS "eventCount",
    COUNT(e."id") FILTER (WHERE e."status" = 'upcoming') AS "upcomingEvents",
    COALESCE(SUM(s."revenue"), 0.00) AS "totalRevenue"
FROM "Organizer" o
LEFT JOIN "Event" e ON e."organizerId" = o."id"
LEFT JOIN sales s ON s."eventId" = e."id"
GROUP BY o."id", o."organizationName"
ORDER BY "totalRevenue" DESC, "eventCount" DESC;


-- 10. Find events that have not received a confirmed booking yet.
SELECT
    e."id" AS "eventId",
    e."name" AS "eventName",
    e."startDate",
    o."organizationName"
FROM "Event" e
JOIN "Organizer" o ON o."id" = e."organizerId"
WHERE e."status" = 'upcoming'
  AND NOT EXISTS (
      SELECT 1
      FROM "Booking" b
      WHERE b."eventId" = e."id"
        AND b."status" = 'confirmed'
  )
ORDER BY e."startDate";
