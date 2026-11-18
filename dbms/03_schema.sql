
-- =====================================================================
-- BuzzBox - Event Ticket Booking System
-- Database: PostgreSQL
--
-- This database manages users, organizers, events, venues,
-- ticket categories, bookings, payments and event entry.
-- =====================================================================

BEGIN;

-- Users

CREATE TABLE "User" (
    "id" BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    "fullName" TEXT NOT NULL,
    "email" TEXT NOT NULL UNIQUE,
    "passwordHash" TEXT NOT NULL,
    "phone" VARCHAR(15),
    "role" TEXT DEFAULT 'user'
        CHECK ("role" IN ('user', 'organizer', 'admin')),
    "createdAt" TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Organizers

CREATE TABLE "Organizer" (
    "id" BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    "userId" BIGINT NOT NULL REFERENCES "User" ("id")
        ON DELETE CASCADE,
    "organizationName" TEXT NOT NULL,
    "description" TEXT,
    "contactEmail" TEXT NOT NULL
);

-- Event categories

CREATE TABLE "Category" (
    "id" BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    "name" TEXT NOT NULL UNIQUE,
    "description" TEXT
);

-- Event venues

CREATE TABLE "Venue" (
    "id" BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    "name" TEXT NOT NULL,
    "address" TEXT NOT NULL,
    "city" TEXT NOT NULL,
    "state" TEXT,
    "capacity" INTEGER CHECK ("capacity" > 0)
);

-- Events

CREATE TABLE "Event" (
    "id" BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    "organizerId" BIGINT NOT NULL REFERENCES "Organizer" ("id"),
    "venueId" BIGINT REFERENCES "Venue" ("id"),
    "name" TEXT NOT NULL,
    "description" TEXT,
    "startDate" TIMESTAMPTZ NOT NULL,
    "endDate" TIMESTAMPTZ NOT NULL,
    "status" TEXT DEFAULT 'upcoming'
        CHECK ("status" IN ('upcoming', 'ongoing', 'completed', 'cancelled')),
    "bannerUrl" TEXT,
    "createdAt" TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    CHECK ("endDate" > "startDate")
);

CREATE TABLE "EventCategory" (
    "eventId" BIGINT REFERENCES "Event" ("id") ON DELETE CASCADE,
    "categoryId" BIGINT REFERENCES "Category" ("id") ON DELETE CASCADE,
    PRIMARY KEY ("eventId", "categoryId")
);

-- Ticket details

CREATE TABLE "TicketType" (
    "id" BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    "eventId" BIGINT NOT NULL REFERENCES "Event" ("id") ON DELETE CASCADE,
    "name" TEXT NOT NULL,
    "price" NUMERIC(10,2) NOT NULL CHECK ("price" >= 0),
    "totalQuantity" INTEGER NOT NULL CHECK ("totalQuantity" > 0),
    "availableQuantity" INTEGER NOT NULL CHECK ("availableQuantity" >= 0),
    "saleStart" TIMESTAMPTZ,
    "saleEnd" TIMESTAMPTZ
);

-- Bookings

CREATE TABLE "Booking" (
    "id" BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    "userId" BIGINT NOT NULL REFERENCES "User" ("id"),
    "eventId" BIGINT NOT NULL REFERENCES "Event" ("id"),
    "bookingCode" TEXT NOT NULL UNIQUE,
    "totalAmount" NUMERIC(10,2) NOT NULL CHECK ("totalAmount" >= 0),
    "status" TEXT DEFAULT 'pending'
        CHECK ("status" IN ('pending', 'confirmed', 'cancelled')),
    "bookingDate" TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE "BookingItem" (
    "id" BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    "bookingId" BIGINT NOT NULL REFERENCES "Booking" ("id") ON DELETE CASCADE,
    "ticketTypeId" BIGINT NOT NULL REFERENCES "TicketType" ("id"),
    "quantity" INTEGER NOT NULL CHECK ("quantity" > 0),
    "price" NUMERIC(10,2) NOT NULL CHECK ("price" >= 0)
);

-- Payments

CREATE TABLE "Payment" (
    "id" BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    "bookingId" BIGINT NOT NULL REFERENCES "Booking" ("id"),
    "transactionId" TEXT UNIQUE,
    "paymentMethod" TEXT NOT NULL,
    "amount" NUMERIC(10,2) NOT NULL CHECK ("amount" >= 0),
    "status" TEXT DEFAULT 'pending'
        CHECK ("status" IN ('pending', 'successful', 'failed', 'refunded')),
    "paymentDate" TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Individual tickets

CREATE TABLE "Ticket" (
    "id" BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    "bookingItemId" BIGINT NOT NULL REFERENCES "BookingItem" ("id"),
    "ticketCode" TEXT NOT NULL UNIQUE,
    "qrCode" UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
    "status" TEXT DEFAULT 'valid'
        CHECK ("status" IN ('valid', 'used', 'cancelled'))
);

-- Event entry

CREATE TABLE "CheckIn" (
    "id" BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    "ticketId" BIGINT NOT NULL UNIQUE REFERENCES "Ticket" ("id"),
    "checkedInAt" TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    "checkedInBy" BIGINT REFERENCES "User" ("id")
);

-- Indexes

CREATE INDEX "Event_organizerId_idx"
    ON "Event" ("organizerId");

CREATE INDEX "Event_startDate_idx"
    ON "Event" ("startDate");

CREATE INDEX "Booking_userId_idx"
    ON "Booking" ("userId");

CREATE INDEX "Booking_eventId_idx"
    ON "Booking" ("eventId");

CREATE INDEX "TicketType_eventId_idx"
    ON "TicketType" ("eventId");

CREATE INDEX "Payment_bookingId_idx"
    ON "Payment" ("bookingId");

CREATE INDEX "Ticket_bookingItemId_idx"
    ON "Ticket" ("bookingItemId");

COMMIT;
