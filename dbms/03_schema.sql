-- =====================================================================
-- BuzzBox — Netflix-inspired streaming service schema
-- Target engine: PostgreSQL 15 (runs on 14+)
--
-- Models accounts, household profiles, subscriptions, a movie and series
-- catalog, genres, watchlists, ratings, and viewing progress.
-- Run with: psql -d buzzbox -f dbms/03_schema.sql
-- =====================================================================

BEGIN;

CREATE TABLE "User" (
    "id"          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    "fullName"    TEXT NOT NULL,
    "email"       TEXT NOT NULL UNIQUE,
    "passwordHash" TEXT NOT NULL,
    "createdAt"   TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE "SubscriptionPlan" (
    "id"              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    "name"            TEXT NOT NULL UNIQUE,
    "monthlyPrice"    NUMERIC(8,2) NOT NULL CHECK ("monthlyPrice" >= 0),
    "maxProfiles"     SMALLINT NOT NULL CHECK ("maxProfiles" > 0),
    "maxVideoQuality" TEXT NOT NULL CHECK ("maxVideoQuality" IN ('SD', 'HD', '4K'))
);

CREATE TABLE "Subscription" (
    "id"        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    "userId"    BIGINT NOT NULL REFERENCES "User" ("id") ON DELETE CASCADE ON UPDATE CASCADE,
    "planId"    BIGINT NOT NULL REFERENCES "SubscriptionPlan" ("id") ON DELETE RESTRICT ON UPDATE CASCADE,
    "status"    TEXT NOT NULL DEFAULT 'active'
                    CHECK ("status" IN ('active', 'paused', 'cancelled', 'expired')),
    "startDate" DATE NOT NULL DEFAULT CURRENT_DATE,
    "endDate"   DATE,
    CHECK ("endDate" IS NULL OR "endDate" >= "startDate")
);

CREATE TABLE "Profile" (
    "id"        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    "userId"    BIGINT NOT NULL REFERENCES "User" ("id") ON DELETE CASCADE ON UPDATE CASCADE,
    "name"      TEXT NOT NULL,
    "isKids"    BOOLEAN NOT NULL DEFAULT FALSE,
    "createdAt" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE ("userId", "name")
);

-- Catalog entries represent either a movie or a series.
CREATE TABLE "Title" (
    "id"              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    "name"            TEXT NOT NULL,
    "description"     TEXT,
    "titleType"       TEXT NOT NULL CHECK ("titleType" IN ('movie', 'series')),
    "releaseYear"     SMALLINT CHECK ("releaseYear" IS NULL OR "releaseYear" BETWEEN 1888 AND 2100),
    "maturityRating"  TEXT,
    "durationMinutes" INTEGER,
    "createdAt"       TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CHECK ("durationMinutes" IS NULL OR "durationMinutes" > 0),
    CHECK ("titleType" <> 'movie' OR "durationMinutes" IS NOT NULL)
);

CREATE TABLE "Episode" (
    "id"              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    "seriesId"        BIGINT NOT NULL REFERENCES "Title" ("id") ON DELETE CASCADE ON UPDATE CASCADE,
    "seasonNumber"    SMALLINT NOT NULL CHECK ("seasonNumber" > 0),
    "episodeNumber"   SMALLINT NOT NULL CHECK ("episodeNumber" > 0),
    "name"            TEXT NOT NULL,
    "durationMinutes" INTEGER NOT NULL CHECK ("durationMinutes" > 0),
    UNIQUE ("seriesId", "seasonNumber", "episodeNumber")
);

CREATE TABLE "Genre" (
    "id"   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    "name" TEXT NOT NULL UNIQUE
);

CREATE TABLE "TitleGenre" (
    "titleId" BIGINT NOT NULL REFERENCES "Title" ("id") ON DELETE CASCADE ON UPDATE CASCADE,
    "genreId" BIGINT NOT NULL REFERENCES "Genre" ("id") ON DELETE CASCADE ON UPDATE CASCADE,
    PRIMARY KEY ("titleId", "genreId")
);

CREATE TABLE "Watchlist" (
    "profileId" BIGINT NOT NULL REFERENCES "Profile" ("id") ON DELETE CASCADE ON UPDATE CASCADE,
    "titleId"   BIGINT NOT NULL REFERENCES "Title" ("id") ON DELETE CASCADE ON UPDATE CASCADE,
    "addedAt"   TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY ("profileId", "titleId")
);

CREATE TABLE "Rating" (
    "profileId" BIGINT NOT NULL REFERENCES "Profile" ("id") ON DELETE CASCADE ON UPDATE CASCADE,
    "titleId"   BIGINT NOT NULL REFERENCES "Title" ("id") ON DELETE CASCADE ON UPDATE CASCADE,
    "score"     SMALLINT NOT NULL CHECK ("score" BETWEEN 1 AND 5),
    "ratedAt"   TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY ("profileId", "titleId")
);

-- Exactly one of titleId (movie) or episodeId (series episode) is populated.
CREATE TABLE "ViewingHistory" (
    "id"              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    "profileId"       BIGINT NOT NULL REFERENCES "Profile" ("id") ON DELETE CASCADE ON UPDATE CASCADE,
    "titleId"         BIGINT REFERENCES "Title" ("id") ON DELETE CASCADE ON UPDATE CASCADE,
    "episodeId"       BIGINT REFERENCES "Episode" ("id") ON DELETE CASCADE ON UPDATE CASCADE,
    "watchedAt"       TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "progressSeconds" INTEGER NOT NULL DEFAULT 0 CHECK ("progressSeconds" >= 0),
    "completed"       BOOLEAN NOT NULL DEFAULT FALSE,
    CHECK (("titleId" IS NOT NULL AND "episodeId" IS NULL)
        OR ("titleId" IS NULL AND "episodeId" IS NOT NULL))
);

CREATE INDEX "Subscription_userId_status_idx" ON "Subscription" ("userId", "status");
CREATE INDEX "Profile_userId_idx" ON "Profile" ("userId");
CREATE INDEX "Title_titleType_idx" ON "Title" ("titleType");
CREATE INDEX "Episode_seriesId_idx" ON "Episode" ("seriesId");
CREATE INDEX "TitleGenre_genreId_idx" ON "TitleGenre" ("genreId");
CREATE INDEX "Watchlist_titleId_idx" ON "Watchlist" ("titleId");
CREATE INDEX "Rating_titleId_idx" ON "Rating" ("titleId");
CREATE INDEX "ViewingHistory_profile_watchedAt_idx"
    ON "ViewingHistory" ("profileId", "watchedAt" DESC);

COMMIT;
