const express = require('express');
const router = express.Router();
const pool = require('../db');

// Every Supabase-style payload from the app is wrapped in an array: [ {...} ]
// Small helper to safely unwrap it and fail loudly (but harmlessly to the
// app, since it ignores response bodies) if the shape is wrong.
function unwrapSingle(body) {
  if (Array.isArray(body) && body.length > 0) return body[0];
  if (body && typeof body === 'object') return body; // tolerate non-array too
  return null;
}

// ---------------------------------------------------------------------
// POST /rest/v1/emails
// ---------------------------------------------------------------------
router.post('/emails', async (req, res) => {
  const record = unwrapSingle(req.body);
  if (!record || !record.email) {
    return res.status(400).json({ error: 'email is required' });
  }

  const email = String(record.email).toLowerCase();
  const name = record.name ?? null;
  const status = record.status ?? 'pending';
  const lastSentAt = record.last_sent_at ? new Date(record.last_sent_at) : new Date();

  try {
    await pool.query(
      `INSERT INTO emails (email, name, status, last_sent_at)
       VALUES ($1, $2, $3, $4)
       ON CONFLICT (email)
       DO UPDATE SET
         name = EXCLUDED.name,
         status = EXCLUDED.status,
         last_sent_at = EXCLUDED.last_sent_at`,
      [email, name, status, lastSentAt]
    );
    return res.status(201).json({ success: true });
  } catch (err) {
    console.error('POST /rest/v1/emails failed:', err);
    return res.status(500).json({ error: 'internal error' });
  }
});

// ---------------------------------------------------------------------
// POST /rest/v1/user_preferences
// Handles BOTH payload shapes the app sends to this same endpoint:
//   - syncUserPreferences: camelCase, full preferences object
//   - syncPersonalization: snake_case, partial (topics + feed_mode only)
// Upsert key: userId / user_id. Partial payloads must NOT null out
// columns they don't include — we COALESCE against the existing row.
// ---------------------------------------------------------------------
router.post('/user_preferences', async (req, res) => {
  const record = unwrapSingle(req.body);

  // Normalize both camelCase and snake_case keys into one shape
  const userId = record?.userId ?? record?.user_id;
  if (!record || !userId) {
    return res.status(400).json({ error: 'userId is required' });
  }

  const notificationsEnabled = record.notificationsEnabled ?? null;
  const appTheme = record.appTheme ?? null;
  const analyticsEnabled = record.analyticsEnabled ?? null;
  const newsletterOptIn = record.newsletterOptIn ?? null;
  const appLanguage = record.appLanguage ?? null;
  const preferredTopics = record.preferredTopics ?? record.preferred_topics ?? null;
  const feedMode = record.feedMode ?? record.feed_mode ?? null;
  const lastUpdated = record.lastUpdated ?? record.last_updated
    ? new Date(record.lastUpdated ?? record.last_updated)
    : new Date();

  try {
    await pool.query(
      `INSERT INTO user_preferences (
         user_id, notifications_enabled, app_theme, analytics_enabled,
         newsletter_opt_in, app_language, preferred_topics, feed_mode, last_updated
       )
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
       ON CONFLICT (user_id)
       DO UPDATE SET
         notifications_enabled = COALESCE(EXCLUDED.notifications_enabled, user_preferences.notifications_enabled),
         app_theme              = COALESCE(EXCLUDED.app_theme, user_preferences.app_theme),
         analytics_enabled      = COALESCE(EXCLUDED.analytics_enabled, user_preferences.analytics_enabled),
         newsletter_opt_in      = COALESCE(EXCLUDED.newsletter_opt_in, user_preferences.newsletter_opt_in),
         app_language           = COALESCE(EXCLUDED.app_language, user_preferences.app_language),
         preferred_topics       = COALESCE(EXCLUDED.preferred_topics, user_preferences.preferred_topics),
         feed_mode              = COALESCE(EXCLUDED.feed_mode, user_preferences.feed_mode),
         last_updated           = EXCLUDED.last_updated`,
      [
        userId,
        notificationsEnabled,
        appTheme,
        analyticsEnabled,
        newsletterOptIn,
        appLanguage,
        preferredTopics, // pg binds JS arrays to TEXT[] directly
        feedMode,
        lastUpdated,
      ]
    );
    return res.status(201).json({ success: true });
  } catch (err) {
    console.error('POST /rest/v1/user_preferences failed:', err);
    return res.status(500).json({ error: 'internal error' });
  }
});

// ---------------------------------------------------------------------
// POST /rest/v1/newsletter_subscribers
// ---------------------------------------------------------------------
router.post('/newsletter_subscribers', async (req, res) => {
  const record = unwrapSingle(req.body);
  if (!record || !record.email) {
    return res.status(400).json({ error: 'email is required' });
  }

  const email = String(record.email).toLowerCase();
  const name = record.name ?? null;
  const subscribed = record.subscribed ?? true;
  const authMethod = record.auth_method ?? null;
  const subscribedAt = record.subscribed_at ? new Date(record.subscribed_at) : new Date();

  try {
    await pool.query(
      `INSERT INTO newsletter_subscribers (email, name, subscribed, auth_method, subscribed_at)
       VALUES ($1, $2, $3, $4, $5)
       ON CONFLICT (email)
       DO UPDATE SET
         name = EXCLUDED.name,
         subscribed = EXCLUDED.subscribed,
         auth_method = EXCLUDED.auth_method,
         subscribed_at = EXCLUDED.subscribed_at`,
      [email, name, subscribed, authMethod, subscribedAt]
    );
    return res.status(201).json({ success: true });
  } catch (err) {
    console.error('POST /rest/v1/newsletter_subscribers failed:', err);
    return res.status(500).json({ error: 'internal error' });
  }
});

module.exports = router;
