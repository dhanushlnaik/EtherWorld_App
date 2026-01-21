# Deployment & Runtime Configuration

This document lists the environment variables and quick test commands to run the EtherWorld OTP backend on Railway (or any host).

## Required environment variables

- `EMAIL_SERVICE` (optional) — `sendgrid` or `gmail`. If not provided, server runs in TEST MODE.
- `SMTP_HOST` (optional) — hostname for SMTP (e.g. `smtp.sendgrid.net`).
- `SMTP_PORT` (optional) — port for SMTP (default `587`).
- `EMAIL_USER` — SMTP username (for SendGrid use `apikey`).
- `EMAIL_PASSWORD` — SMTP password or SendGrid API key.
- `EMAIL_FROM` (optional) — From address, e.g. `noreply@yourdomain.com`.
- `OTP_HMAC_SECRET` (recommended) — secret used to HMAC OTPs. Set to a secure random string in production.
- `REDIS_URL` or `REDIS_HOST`/`REDIS_PORT`/`REDIS_PASSWORD` (optional) — if provided, OTPs and attempt counters will be stored in Redis.
- `PORT` (optional) — the server will use the provided port, otherwise 3000.

## Railway setup (recommended)
1. Create a new project and deploy from GitHub.
2. When selecting the repo, set the **Root Directory** to `/backend`.
3. Add the variables above in the **Variables** tab. Example values for SendGrid:

```
EMAIL_SERVICE=sendgrid
SMTP_HOST=smtp.sendgrid.net
SMTP_PORT=587
EMAIL_USER=apikey
EMAIL_PASSWORD=<YOUR_SENDGRID_API_KEY>
EMAIL_FROM=noreply@yourdomain.com
OTP_HMAC_SECRET=<long-random-secret>
REDIS_URL=<optional-redis-url>
```

4. Deploy and check Logs → Deployments → View logs to confirm startup.

## Quick runtime test (curl)

Replace `<URL>` with your deployed base URL (e.g. `https://etherworld-otp.up.railway.app`):

```bash
# send OTP
curl -X POST https://<URL>/auth/send-otp \
  -H "Content-Type: application/json" \
  -d '{"email":"you@example.com"}'

# verify OTP (replace 123456 with the code you received)
curl -X POST https://<URL>/auth/verify-otp \
  -H "Content-Type: application/json" \
  -d '{"email":"you@example.com","code":"123456"}'
```

## Notes
- If you don't configure SMTP, the server will run in TEST MODE and log OTP values to logs.
- Use `OTP_HMAC_SECRET` to rotate hashing secret; changing it invalidates previously issued OTPs.
