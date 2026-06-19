-- EtherWorld iOS app — self-hosted Postgres schema
-- Replaces Supabase-managed tables: emails, user_preferences, newsletter_subscribers

CREATE TABLE IF NOT EXISTS emails (
    id            SERIAL PRIMARY KEY,
    email         TEXT NOT NULL UNIQUE,
    name          TEXT,
    status        TEXT NOT NULL DEFAULT 'pending',
    last_sent_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- One row per user_id. Columns are snake_case (Postgres convention);
-- the Node layer normalizes both camelCase (syncUserPreferences) and
-- snake_case (syncPersonalization) payloads down to this shape before insert.
CREATE TABLE IF NOT EXISTS user_preferences (
    user_id               TEXT PRIMARY KEY,
    notifications_enabled BOOLEAN,
    app_theme             TEXT,
    analytics_enabled     BOOLEAN,
    newsletter_opt_in     BOOLEAN,
    app_language          TEXT,
    preferred_topics      TEXT[],
    feed_mode             TEXT,
    last_updated          TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_at             TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS newsletter_subscribers (
    id              SERIAL PRIMARY KEY,
    email           TEXT NOT NULL UNIQUE,
    name            TEXT,
    subscribed      BOOLEAN NOT NULL DEFAULT true,
    auth_method     TEXT,
    subscribed_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_newsletter_subscribers_email ON newsletter_subscribers(email);
