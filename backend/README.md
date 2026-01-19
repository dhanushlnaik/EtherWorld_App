# EtherWorld OTP Backend

Production-ready OTP authentication backend for the EtherWorld iOS app.

## Quick Start

### 1. Install Dependencies
```bash
cd backend
npm install
```

### 2. Configure Email

Copy the example environment file:
```bash
cp .env.example .env
```

Then edit `.env` with your email settings:

**For Gmail (easiest for testing):**
1. Use a Gmail account
2. Enable 2-factor authentication
3. Generate an App Password: https://myaccount.google.com/apppasswords
4. Update `.env`:
```env
EMAIL_SERVICE=gmail
EMAIL_USER=your-email@gmail.com
EMAIL_PASSWORD=your-app-password
```

**For SendGrid (recommended for production):**
```env
SMTP_HOST=smtp.sendgrid.net
SMTP_PORT=587
EMAIL_USER=apikey
EMAIL_PASSWORD=your-sendgrid-api-key
EMAIL_FROM=noreply@etherworld.co
```

**For TEST MODE (no email):**
Leave `.env` empty - OTPs will be logged to console.

### 3. Run Locally
```bash
npm start
```

Server runs on http://localhost:3000

### 4. Test
```bash
# Send OTP
curl -X POST http://localhost:3000/auth/send-otp \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com"}'

# Verify OTP (check console for code in TEST MODE)
curl -X POST http://localhost:3000/auth/verify-otp \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","code":"123456"}'
```

## Deploy to Railway (Free)

1. Install Railway CLI:
```bash
npm install -g @railway/cli
```

2. Login and deploy:
```bash
railway login
railway init
railway up
```

3. Add environment variables in Railway dashboard:
   - `EMAIL_SERVICE=gmail`
   - `EMAIL_USER=your-email@gmail.com`
   - `EMAIL_PASSWORD=your-app-password`

4. Get your backend URL from Railway dashboard (e.g., `https://your-app.railway.app`)

## Deploy to Render (Free)

1. Push code to GitHub
2. Go to https://render.com
3. Create new "Web Service"
4. Connect your repository
5. Configure:
   - Build Command: `npm install`
   - Start Command: `npm start`
6. Add environment variables in Render dashboard
7. Deploy!

## Update iOS App

Once deployed, update the backend URL in your iOS app:

1. Open `IOS_App/NetworkManager.swift`
2. Change line 9:
```swift
private let baseURL = "https://your-app.railway.app" // Your deployed URL
```

3. Rebuild and run the app
4. Real OTPs will now be sent via email!

## API Endpoints

### POST /auth/send-otp
Send OTP code to email.

**Request:**
```json
{
  "email": "user@example.com"
}
```

**Response:**
```json
{
  "success": true,
  "message": "OTP sent successfully"
}
```

### POST /auth/verify-otp
Verify OTP code.

**Request:**
```json
{
  "email": "user@example.com",
  "code": "123456"
}
```

**Response:**
```json
{
  "token": "jwt-token",
  "user": {
    "id": "user-id",
    "email": "user@example.com",
    "name": "user",
    "authProvider": "email",
    "createdAt": "2026-01-19T..."
  },
  "expiresAt": "2026-02-18T..."
}
```

### GET /health
Health check endpoint.

## Features

- ✅ 6-digit OTP generation
- ✅ 10-minute expiration
- ✅ Rate limiting (5 attempts per minute)
- ✅ 3 verification attempts per OTP
- ✅ Beautiful email templates
- ✅ In-memory storage (upgrade to Redis for production)
- ✅ Multiple email service support
- ✅ Test mode for development

## Production Improvements

For production use, consider:

1. **Add Redis** for OTP storage (prevents data loss on restart)
2. **Use proper JWT library** (jsonwebtoken package)
3. **Add database** for user management
4. **Implement IP-based rate limiting**
5. **Add logging** (Winston, Pino)
6. **Add monitoring** (Sentry, LogRocket)
7. **Use environment-specific configs**

## Troubleshooting

**OTPs not sending:**
- Check console for error messages
- Verify email credentials in `.env`
- For Gmail: ensure App Password is used (not regular password)
- Check spam folder

**Rate limiting issues:**
- Wait 1 minute between attempts
- Restart server to clear rate limits

**Verification failing:**
- OTPs expire after 10 minutes
- Only 3 attempts allowed per OTP
- Request new code if needed

## Support

Check console logs for detailed error messages and OTP codes (in TEST MODE).
