const express = require('express');
const cors = require('cors');
const nodemailer = require('nodemailer');
const crypto = require('crypto');
const { createClient } = require('redis');
const path = require('path');

// Always load .env from the backend folder so the server
// works whether started in ./backend or from the repo root.
require('dotenv').config({ path: path.join(__dirname, '.env') });

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json());

// Storage: prefer Redis if configured, otherwise fall back to in-memory Map (hashed values)
let redisClient = null;
const useRedis = !!process.env.REDIS_URL || !!process.env.REDIS_HOST;
if (useRedis) {
  const redisOpts = process.env.REDIS_URL ? { url: process.env.REDIS_URL } : {
    socket: { host: process.env.REDIS_HOST, port: process.env.REDIS_PORT || 6379 },
    password: process.env.REDIS_PASSWORD || undefined
  };
  redisClient = createClient(redisOpts);
  redisClient.on('error', (err) => console.error('Redis error', err));
  redisClient.connect().then(() => console.log('✅ Connected to Redis')).catch(err => console.error('Redis connect failed', err));
}

const otpStore = new Map(); // fallback when Redis unavailable

// HMAC secret for hashing OTPs
const OTP_HMAC_SECRET = process.env.OTP_HMAC_SECRET || process.env.SESSION_SECRET || 'dev-otp-secret-please-change';

// Email transporter configuration
let transporter;

function resolveFromAddress() {
  // For SMTP providers like SendGrid, the SMTP username is often not an email (e.g. "apikey").
  // Always prefer an explicit, verified sender address.
  if (process.env.EMAIL_FROM) return process.env.EMAIL_FROM;

  // Gmail: EMAIL_USER is typically an actual email address.
  if (process.env.EMAIL_SERVICE === 'gmail' && process.env.EMAIL_USER) return process.env.EMAIL_USER;

  return null;
}

function initEmailTransporter() {
  try {
    if (process.env.EMAIL_SERVICE === 'gmail') {
      transporter = nodemailer.createTransport({
        service: 'gmail',
        auth: {
          user: process.env.EMAIL_USER,
          pass: process.env.EMAIL_PASSWORD // App password
        }
      });
    } else if (process.env.SMTP_HOST) {
      const smtpUser = process.env.SMTP_USER || process.env.EMAIL_USER;
      const smtpPass = process.env.SMTP_PASS || process.env.EMAIL_PASSWORD;
      transporter = nodemailer.createTransport({
        host: process.env.SMTP_HOST,
        port: process.env.SMTP_PORT || 587,
        secure: false,
        auth: smtpUser && smtpPass ? { user: smtpUser, pass: smtpPass } : undefined
      });
    } else {
      console.log('⚠️  No email configuration found, running in TEST MODE');
      transporter = {
        sendMail: async (mailOptions) => {
          console.log('📧 TEST MODE - Would send email:');
          console.log('To:', mailOptions.to);
          console.log('Subject:', mailOptions.subject);
          console.log('OTP Code:', mailOptions.html.match(/\d{6}/)?.[0]);
          return { messageId: 'test-mode' };
        }
      };
    }
  } catch (err) {
    console.error('Error initializing email transporter:', err);
    transporter = {
      sendMail: async (mailOptions) => {
        console.log('📧 TEST MODE - transporter init failed, logging email:');
        console.log('To:', mailOptions.to);
        console.log('Subject:', mailOptions.subject);
        console.log('OTP Code:', mailOptions.html.match(/\d{6}/)?.[0]);
        return { messageId: 'test-mode' };
      }
    };
  }
}

initEmailTransporter();

// Generate secure 6-digit OTP
function generateOTP() {
  const n = crypto.randomInt(0, 1000000);
  return n.toString().padStart(6, '0');
}

function hashOTP(code) {
  return crypto.createHmac('sha256', OTP_HMAC_SECRET).update(code).digest('hex');
}

const DEFAULT_TTL_SECONDS = parseInt(process.env.OTP_TTL_SECONDS || '600', 10); // 10 minutes

// Clean up in-memory expired OTPs every minute
setInterval(() => {
  const now = Date.now();
  for (const [email, data] of otpStore.entries()) {
    if (now > data.expiresAt) {
      otpStore.delete(email);
    }
  }
}, 60000);

// Rate limiting (simple in-memory implementation)
const rateLimitStore = new Map();
const RATE_LIMIT_WINDOW = 60000; // 1 minute
const MAX_ATTEMPTS = 5;

function checkRateLimit(email) {
  const now = Date.now();
  const attempts = rateLimitStore.get(email) || [];
  const recentAttempts = attempts.filter(time => now - time < RATE_LIMIT_WINDOW);
  if (recentAttempts.length >= MAX_ATTEMPTS) return false;
  recentAttempts.push(now);
  rateLimitStore.set(email, recentAttempts);
  return true;
}

async function storeOTP(email, hashed, ttlSeconds = DEFAULT_TTL_SECONDS) {
  const key = `otp:${email}`;
  if (redisClient) {
    await redisClient.set(key, hashed, { EX: ttlSeconds });
    await redisClient.set(`otp_attempts:${email}`, '0', { EX: ttlSeconds });
  } else {
    otpStore.set(email, { hash: hashed, expiresAt: Date.now() + ttlSeconds * 1000, attempts: 0 });
  }
}

async function getOTPData(email) {
  const key = `otp:${email}`;
  if (redisClient) {
    const hash = await redisClient.get(key);
    if (!hash) return null;
    const attempts = parseInt(await redisClient.get(`otp_attempts:${email}`) || '0', 10);
    // TTL retrieval isn't necessary for logic here
    return { hash, attempts };
  }
  const data = otpStore.get(email);
  if (!data) return null;
  return { hash: data.hash, attempts: data.attempts, expiresAt: data.expiresAt };
}

async function incrementAttempts(email) {
  if (redisClient) {
    const key = `otp_attempts:${email}`;
    const attempts = await redisClient.incr(key);
    return attempts;
  }
  const data = otpStore.get(email);
  if (!data) return 1;
  data.attempts = (data.attempts || 0) + 1;
  otpStore.set(email, data);
  return data.attempts;
}

async function deleteOTP(email) {
  if (redisClient) {
    await redisClient.del(`otp:${email}`);
    await redisClient.del(`otp_attempts:${email}`);
  } else {
    otpStore.delete(email);
  }
}

// POST /auth/send-otp
app.post('/auth/send-otp', async (req, res) => {
  try {
    const { email } = req.body;
    if (!email || !email.includes('@')) return res.status(400).json({ error: 'Invalid email address' });
    if (!checkRateLimit(email)) return res.status(429).json({ error: 'Too many attempts. Please try again later.' });

    const fromAddress = resolveFromAddress();
    if (!fromAddress && (process.env.SMTP_HOST || process.env.EMAIL_SERVICE === 'gmail')) {
      console.error('Email misconfigured: missing EMAIL_FROM (or EMAIL_USER for gmail).');
      return res.status(500).json({ error: 'Email is not configured correctly on the server' });
    }

    const otp = generateOTP();
    const hashed = hashOTP(otp);
    await storeOTP(email.toLowerCase(), hashed);

    // Send email (non-blocking send handled, but we wait for success to inform client)
    const mailOptions = {
      from: fromAddress || 'noreply@localhost',
      to: email,
      subject: 'Your EtherWorld Verification Code',
      html: `<!DOCTYPE html><html><head><style>body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Arial,sans-serif;line-height:1.6;color:#333}.container{max-width:600px;margin:0 auto;padding:20px}.code-box{background:#f5f5f5;border:2px solid #007AFF;border-radius:8px;padding:20px;text-align:center;margin:30px 0}.code{font-size:36px;font-weight:700;letter-spacing:8px;color:#007AFF}.footer{font-size:12px;color:#666;margin-top:30px}</style></head><body><div class="container"><h2>Welcome to EtherWorld</h2><p>Your verification code is:</p><div class="code-box"><div class="code">${otp}</div></div><p>This code will expire in <strong>${Math.round(DEFAULT_TTL_SECONDS/60)} minutes</strong>.</p><p>If you didn't request this code, please ignore this email.</p><div class="footer"><p>© 2026 EtherWorld. All rights reserved.</p></div></div></body></html>`
    };

    const info = await transporter.sendMail(mailOptions);
    if (process.env.DEBUG_OTP === '1') {
      console.log('📧 Sent OTP (DEBUG_OTP=1):', { to: email, otp, messageId: info && info.messageId });
    }
    console.log(`✅ OTP sent to ${email} (expires in ${DEFAULT_TTL_SECONDS} sec)`);
    res.json({ success: true, message: 'OTP sent successfully' });
  } catch (error) {
    console.error('Error sending OTP:', error);
    res.status(500).json({ error: 'Failed to send OTP' });
  }
});

// POST /auth/verify-otp
app.post('/auth/verify-otp', async (req, res) => {
  try {
    const { email, code } = req.body;
    if (!email || !code) return res.status(400).json({ error: 'Email and code are required' });
    const emailLower = email.toLowerCase();

    const data = await getOTPData(emailLower);
    if (!data) return res.status(400).json({ error: 'No OTP found. Please request a new code.' });

    // If in-memory mode, check expiration
    if (!redisClient && data.expiresAt && Date.now() > data.expiresAt) {
      await deleteOTP(emailLower);
      return res.status(400).json({ error: 'OTP expired. Please request a new code.' });
    }

    if (data.attempts >= 3) {
      await deleteOTP(emailLower);
      return res.status(400).json({ error: 'Too many failed attempts. Please request a new code.' });
    }

    const hashedAttempt = hashOTP(code);
    if (hashedAttempt !== data.hash) {
      const attempts = await incrementAttempts(emailLower);
      if (attempts >= 3) {
        await deleteOTP(emailLower);
        return res.status(400).json({ error: 'Too many failed attempts. Please request a new code.' });
      }
      return res.status(400).json({ error: 'Invalid verification code' });
    }

    // Success - remove OTP and create session token
    await deleteOTP(emailLower);
    const token = Buffer.from(JSON.stringify({ email: emailLower, iat: Date.now(), exp: Date.now() + 30 * 24 * 60 * 60 * 1000 })).toString('base64');
    const response = {
      token,
      user: { id: Buffer.from(emailLower).toString('base64').substring(0,16), email: emailLower, name: email.split('@')[0], authProvider: 'email', createdAt: new Date().toISOString() },
      expiresAt: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString()
    };

    console.log(`✅ User verified: ${email}`);
    res.json(response);
  } catch (error) {
    console.error('Error verifying OTP:', error);
    res.status(500).json({ error: 'Failed to verify OTP' });
  }
});

// Health check
app.get('/health', (req, res) => {
  const fromAddress = resolveFromAddress();
  const smtpUser = process.env.SMTP_USER || process.env.EMAIL_USER;
  const smtpPass = process.env.SMTP_PASS || process.env.EMAIL_PASSWORD;
  const smtpConfigured = !!process.env.SMTP_HOST && !!smtpUser && !!smtpPass;
  const gmailConfigured = process.env.EMAIL_SERVICE === 'gmail' && !!process.env.EMAIL_USER && !!process.env.EMAIL_PASSWORD;

  res.json({
    status: 'ok',
    timestamp: new Date().toISOString(),
    emailConfigured: !!fromAddress && (smtpConfigured || gmailConfigured),
    redis: !!redisClient
  });
});

// Start server
const HOST = process.env.HOST || '0.0.0.0';
const server = app.listen(PORT, HOST, () => {
  console.log(`🚀 EtherWorld OTP Backend running on ${HOST}:${PORT}`);
  console.log(`📧 Email mode: ${process.env.EMAIL_SERVICE || process.env.SMTP_HOST || 'TEST MODE'}`);
  const healthHost = HOST === '0.0.0.0' ? 'localhost' : HOST;
  console.log(`🔗 Health check: http://${healthHost}:${PORT}/health`);
});

server.on('error', (err) => {
  console.error('Server error:', err);
  if (err && err.code === 'EADDRINUSE') {
    console.error(`Port ${PORT} already in use. Make sure no other instance is running and retry.`);
    process.exit(1);
  }
});

process.on('uncaughtException', (err) => {
  console.error('Uncaught exception:', err);
});

process.on('unhandledRejection', (reason) => {
  console.error('Unhandled rejection:', reason);
});
