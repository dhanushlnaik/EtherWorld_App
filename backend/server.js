const express = require('express');
const cors = require('cors');
const nodemailer = require('nodemailer');
const crypto = require('crypto');
const { createClient } = require('redis');
const path = require('path');
const https = require('https');

// Always load .env from the backend folder so the server
// works whether started in ./backend or from the repo root.
require('dotenv').config({ path: path.join(__dirname, '.env') });

console.log('🚀 Booting EtherWorld OTP Backend...');

const app = express();
const PORT = process.env.PORT || 3000;

// IMPORTANT: Validate critical environment variables at startup
const validateEnvironment = () => {
  const emailService = process.env.EMAIL_SERVICE || process.env.SMTP_HOST || process.env.SENDGRID_API_KEY;
  const sendGridMode = !!process.env.SENDGRID_API_KEY;
  const smtpMode = process.env.SMTP_HOST && !sendGridMode;
  const gmailMode = process.env.EMAIL_SERVICE === 'gmail' && !sendGridMode;

  console.log('🔎 Email env:', {
    sendgridKey: !!process.env.SENDGRID_API_KEY,
    sendgridFrom: !!process.env.SENDGRID_FROM_EMAIL,
    emailFrom: !!process.env.EMAIL_FROM,
    emailService: process.env.EMAIL_SERVICE || null,
    smtpHost: !!process.env.SMTP_HOST
  });

  let errors = [];
  let warnings = [];

  if (sendGridMode) {
    if (!process.env.SENDGRID_API_KEY) errors.push('SENDGRID_API_KEY is required');
    if (!process.env.SENDGRID_FROM_EMAIL && !process.env.EMAIL_FROM) errors.push('SENDGRID_FROM_EMAIL or EMAIL_FROM is required');
  } else if (gmailMode) {
    if (!process.env.EMAIL_USER) errors.push('EMAIL_USER is required for Gmail');
    if (!process.env.EMAIL_PASSWORD) errors.push('EMAIL_PASSWORD is required for Gmail');
  } else if (smtpMode) {
    if (!process.env.SMTP_USER && !process.env.EMAIL_USER) warnings.push('SMTP_USER or EMAIL_USER not set, SMTP auth will be disabled');
    if (!process.env.SMTP_PASS && !process.env.EMAIL_PASSWORD) warnings.push('SMTP_PASS or EMAIL_PASSWORD not set, SMTP auth will be disabled');
  } else {
    warnings.push('No email service configured - running in TEST MODE');
  }

  if (errors.length > 0) {
    console.error('❌ CRITICAL ENVIRONMENT ERRORS:');
    errors.forEach(err => console.error(`   - ${err}`));
    process.exit(1);
  }

  if (warnings.length > 0) {
    console.warn('⚠️  ENVIRONMENT WARNINGS:');
    warnings.forEach(warn => console.warn(`   - ${warn}`));
  }
};

validateEnvironment();

// Middleware
app.use(cors());
app.use(express.json());

// Redis storage (optional)
let redisClient = null;
const useRedis = !!process.env.REDIS_URL || !!process.env.REDIS_HOST;
console.log('🧰 Config:', { port: PORT, host: process.env.HOST || '0.0.0.0', useRedis });
if (useRedis) {
  const redisOpts = process.env.REDIS_URL ? { url: process.env.REDIS_URL } : {
    socket: { host: process.env.REDIS_HOST, port: process.env.REDIS_PORT || 6379 },
    password: process.env.REDIS_PASSWORD || undefined
  };
  console.log('🧠 Initializing Redis client...');
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
  // Priority order: SENDGRID_FROM_EMAIL > EMAIL_FROM > fallback
  let addr = process.env.SENDGRID_FROM_EMAIL || process.env.EMAIL_FROM;
  
  // Parse email from formats like "Name <email@example.com>" → "email@example.com"
  if (addr && addr.includes('<') && addr.includes('>')) {
    const match = addr.match(/<([^>]+)>/);
    if (match) addr = match[1];
  }

  // Gmail: EMAIL_USER is typically an actual email address.
  if (!addr && process.env.EMAIL_SERVICE === 'gmail' && process.env.EMAIL_USER) {
    addr = process.env.EMAIL_USER;
  }

  return addr || null;
}

async function sendViaNetlify(mailOptions) {
  // Direct SendGrid API call for maximum reliability and error visibility
  const apiKey = process.env.SENDGRID_API_KEY;
  if (!apiKey) throw new Error('SENDGRID_API_KEY not configured');

  const payload = {
    personalizations: [{
      to: [{ email: mailOptions.to }]
    }],
    from: { email: mailOptions.from },
    subject: mailOptions.subject,
    content: [{
      type: 'text/html',
      value: mailOptions.html
    }]
  };

  console.log(`📨 Attempting SendGrid send to ${mailOptions.to}...`);
  
  return new Promise((resolve, reject) => {
    const req = https.request({
      hostname: 'api.sendgrid.com',
      path: '/v3/mail/send',
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${apiKey}`,
        'Content-Type': 'application/json'
      }
    }, (res) => {
      let body = '';
      res.on('data', chunk => body += chunk);
      res.on('end', () => {
        console.log(`📧 SendGrid response status: ${res.statusCode}`);
        
        if (res.statusCode >= 200 && res.statusCode < 300) {
          console.log(`✅ SendGrid accepted email for ${mailOptions.to}`);
          resolve({ messageId: `sendgrid-${Date.now()}` });
        } else {
          const errorMsg = body ? `SendGrid error: ${body}` : `SendGrid HTTP ${res.statusCode}`;
          console.error(`❌ SendGrid failed: ${errorMsg}`);
          reject(new Error(errorMsg));
        }
      });
    });

    req.on('error', (err) => {
      console.error(`❌ SendGrid network error: ${err.message}`);
      reject(err);
    });

    req.write(JSON.stringify(payload));
    req.end();
  });
}

function initEmailTransporter() {
  // Use SendGrid API if configured
  if (process.env.SENDGRID_API_KEY) {
    console.log('📨 Using SendGrid API');
    transporter = {
      sendMail: async (mailOptions) => {
        try {
          return await sendViaNetlify(mailOptions);
        } catch (err) {
          console.error('SendGrid API error:', err.message);
          throw err;
        }
      }
    };
    return;
  }

  // Fall back to nodemailer for SMTP or Gmail
  try {
    if (process.env.EMAIL_SERVICE === 'gmail') {
      console.log('📨 Using Gmail SMTP');
      transporter = nodemailer.createTransport({
        service: 'gmail',
        auth: {
          user: process.env.EMAIL_USER,
          pass: process.env.EMAIL_PASSWORD // App password
        }
      });
    } else if (process.env.SMTP_HOST) {
      console.log(`📨 Using SMTP (${process.env.SMTP_HOST}:${process.env.SMTP_PORT || 587})`);
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
          console.log('  To:', mailOptions.to);
          console.log('  Subject:', mailOptions.subject);
          const otpMatch = mailOptions.html.match(/(\d{6})/);
          const otp = otpMatch ? otpMatch[1] : 'N/A';
          console.log('  OTP Code:', otp);
          return { messageId: 'test-mode' };
        }
      };
    }
  } catch (err) {
    console.error('Error initializing email transporter:', err);
    transporter = {
      sendMail: async (mailOptions) => {
        console.log('📧 TEST MODE - transporter init failed, logging email:');
        console.log('  To:', mailOptions.to);
        console.log('  Subject:', mailOptions.subject);
        const otpMatch = mailOptions.html.match(/(\d{6})/);
        const otp = otpMatch ? otpMatch[1] : 'N/A';
        console.log('  OTP Code:', otp);
        return { messageId: 'test-mode' };
      }
    };
  }
}

initEmailTransporter();
console.log('📨 Email transporter initialized');

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
  const startTime = Date.now();
  try {
    const { email } = req.body;
    
    // Validate input
    if (!email || !email.includes('@')) {
      console.warn(`❌ Invalid email format: ${email || 'empty'}`);
      return res.status(400).json({ error: 'Invalid email address' });
    }
    
    const emailLower = email.toLowerCase();
    console.log(`📬 OTP request for: ${emailLower}`);
    
    // Check rate limit
    if (!checkRateLimit(emailLower)) {
      console.warn(`⏱️  Rate limit exceeded for: ${emailLower}`);
      return res.status(429).json({ error: 'Too many attempts. Please try again later.' });
    }

    const fromAddress = resolveFromAddress();
    if (!fromAddress && (process.env.SMTP_HOST || process.env.EMAIL_SERVICE === 'gmail' || process.env.SENDGRID_API_KEY)) {
      const configErr = 'Email misconfigured: missing sender address (SENDGRID_FROM_EMAIL or EMAIL_FROM)';
      console.error(`❌ ${configErr}`);
      return res.status(500).json({ error: configErr });
    }

    // Generate and store OTP
    const otp = generateOTP();
    const hashed = hashOTP(otp);
    await storeOTP(emailLower, hashed);
    console.log(`✅ OTP generated for ${emailLower}: ${otp} (hashed)`);

    // Send email with detailed error handling
    const mailOptions = {
      from: fromAddress || 'noreply@localhost',
      to: emailLower,
      subject: 'Your EtherWorld Verification Code',
      html: `<!DOCTYPE html><html><head><style>body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Arial,sans-serif;line-height:1.6;color:#333}.container{max-width:600px;margin:0 auto;padding:20px}.code-box{background:#f5f5f5;border:2px solid #007AFF;border-radius:8px;padding:20px;text-align:center;margin:30px 0}.code{font-size:36px;font-weight:700;letter-spacing:8px;color:#007AFF}.footer{font-size:12px;color:#666;margin-top:30px}</style></head><body><div class="container"><h2>Welcome to EtherWorld</h2><p>Your verification code is:</p><div class="code-box"><div class="code">${otp}</div></div><p>This code will expire in <strong>${Math.round(DEFAULT_TTL_SECONDS/60)} minutes</strong>.</p><p>If you didn't request this code, please ignore this email.</p><div class="footer"><p>© 2026 EtherWorld. All rights reserved.</p></div></div></body></html>`
    };

    try {
      console.log(`📧 Sending email via transporter...`);
      console.log(`   From: ${mailOptions.from}`);
      console.log(`   To: ${mailOptions.to}`);
      const info = await transporter.sendMail(mailOptions);
      const elapsed = Date.now() - startTime;
      console.log(`✅ OTP email sent to ${emailLower} (${elapsed}ms), messageId: ${info.messageId}`);
      
      if (process.env.DEBUG_OTP === '1') {
        console.log(`🔍 DEBUG_OTP=1: OTP code was ${otp}`);
      }
      
      res.json({ success: true, message: 'OTP sent successfully' });
    } catch (emailError) {
      const elapsed = Date.now() - startTime;
      console.error(`❌ Email send failed (${elapsed}ms): ${emailError.message}`);
      console.error(`   Error code: ${emailError.code}`);
      console.error(`   Command: ${emailError.command}`);
      console.error(`   Response code: ${emailError.responseCode}`);
      console.error(`   Error details:`, emailError);
      
      // Clean up stored OTP since we couldn't send it
      await deleteOTP(emailLower);
      
      // Return more specific error to client
      const errorMsg = emailError.message.includes('SendGrid') 
        ? emailError.message 
        : 'Failed to send verification email. Please try again.';
      res.status(500).json({ error: errorMsg });
    }
  } catch (error) {
    const elapsed = Date.now() - startTime;
    console.error(`❌ Unexpected error in /auth/send-otp (${elapsed}ms):`, error.message);
    console.error(error);
    res.status(500).json({ error: 'An unexpected error occurred' });
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
  const emailMode = 
    process.env.SENDGRID_API_KEY ? 'SendGrid API' :
    process.env.SMTP_HOST ? `SMTP (${process.env.SMTP_HOST})` :
    process.env.EMAIL_SERVICE === 'gmail' ? 'Gmail' :
    'TEST MODE';
  
  const sendGridConfigured = !!process.env.SENDGRID_API_KEY && !!fromAddress;
  const smtpUser = process.env.SMTP_USER || process.env.EMAIL_USER;
  const smtpPass = process.env.SMTP_PASS || process.env.EMAIL_PASSWORD;
  const smtpConfigured = !!process.env.SMTP_HOST && !!smtpUser && !!smtpPass;
  const gmailConfigured = process.env.EMAIL_SERVICE === 'gmail' && !!process.env.EMAIL_USER && !!process.env.EMAIL_PASSWORD;

  res.json({
    status: 'ok',
    timestamp: new Date().toISOString(),
    emailMode,
    emailConfigured: sendGridConfigured || smtpConfigured || gmailConfigured,
    sendGridConfigured,
    smtpConfigured,
    gmailConfigured,
    fromAddress: fromAddress || 'not-configured',
    redis: redisClient ? 'connected' : 'using in-memory storage',
    redisConnected: !!redisClient
  });
});

// Start server
const HOST = process.env.HOST || '0.0.0.0';
const server = app.listen(PORT, HOST, () => {
  const fromAddress = resolveFromAddress();
  const emailMode = 
    process.env.SENDGRID_API_KEY ? 'SendGrid API' :
    process.env.SMTP_HOST ? `SMTP (${process.env.SMTP_HOST})` :
    process.env.EMAIL_SERVICE === 'gmail' ? 'Gmail SMTP' :
    'TEST MODE';
  
  console.log('');
  console.log('═══════════════════════════════════════════════════════');
  console.log(`🚀 Server running on ${HOST}:${PORT}`);
  console.log(`📧 Email mode: ${emailMode}`);
  console.log(`📨 From address: ${fromAddress || 'not-configured'}`);
  console.log(`💾 Storage: ${redisClient ? 'Redis' : 'In-Memory'}`);
  const healthHost = HOST === '0.0.0.0' ? 'localhost' : HOST;
  console.log(`🔗 Health: http://${healthHost}:${PORT}/health`);
  console.log('═══════════════════════════════════════════════════════');
  console.log('');
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
