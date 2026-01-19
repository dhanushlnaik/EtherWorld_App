const express = require('express');
const cors = require('cors');
const nodemailer = require('nodemailer');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json());

// In-memory OTP storage (use Redis in production)
const otpStore = new Map();

// Email transporter configuration
let transporter;

// Initialize email transporter
function initEmailTransporter() {
  if (process.env.EMAIL_SERVICE === 'gmail') {
    transporter = nodemailer.createTransport({
      service: 'gmail',
      auth: {
        user: process.env.EMAIL_USER,
        pass: process.env.EMAIL_PASSWORD // App password, not regular password
      }
    });
  } else if (process.env.SMTP_HOST) {
    transporter = nodemailer.createTransport({
      host: process.env.SMTP_HOST,
      port: process.env.SMTP_PORT || 587,
      secure: false,
      auth: {
        user: process.env.EMAIL_USER,
        pass: process.env.EMAIL_PASSWORD
      }
    });
  } else {
    console.log('⚠️  No email configuration found, running in TEST MODE');
    // Test mode - just log OTPs
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
}

initEmailTransporter();

// Generate 6-digit OTP
function generateOTP() {
  return Math.floor(100000 + Math.random() * 900000).toString();
}

// Clean up expired OTPs every minute
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
  
  if (recentAttempts.length >= MAX_ATTEMPTS) {
    return false;
  }
  
  recentAttempts.push(now);
  rateLimitStore.set(email, recentAttempts);
  return true;
}

// POST /auth/send-otp
app.post('/auth/send-otp', async (req, res) => {
  try {
    const { email } = req.body;
    
    if (!email || !email.includes('@')) {
      return res.status(400).json({ error: 'Invalid email address' });
    }
    
    // Rate limiting
    if (!checkRateLimit(email)) {
      return res.status(429).json({ error: 'Too many attempts. Please try again later.' });
    }
    
    // Generate OTP
    const otp = generateOTP();
    const expiresAt = Date.now() + 10 * 60 * 1000; // 10 minutes
    
    // Store OTP
    otpStore.set(email.toLowerCase(), {
      code: otp,
      expiresAt,
      attempts: 0
    });
    
    // Send email
    const mailOptions = {
      from: process.env.EMAIL_FROM || process.env.EMAIL_USER || 'noreply@etherworld.co',
      to: email,
      subject: 'Your EtherWorld Verification Code',
      html: `
        <!DOCTYPE html>
        <html>
        <head>
          <style>
            body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Arial, sans-serif; line-height: 1.6; color: #333; }
            .container { max-width: 600px; margin: 0 auto; padding: 20px; }
            .code-box { background: #f5f5f5; border: 2px solid #007AFF; border-radius: 8px; padding: 20px; text-align: center; margin: 30px 0; }
            .code { font-size: 36px; font-weight: bold; letter-spacing: 8px; color: #007AFF; }
            .footer { font-size: 12px; color: #666; margin-top: 30px; }
          </style>
        </head>
        <body>
          <div class="container">
            <h2>Welcome to EtherWorld</h2>
            <p>Your verification code is:</p>
            <div class="code-box">
              <div class="code">${otp}</div>
            </div>
            <p>This code will expire in <strong>10 minutes</strong>.</p>
            <p>If you didn't request this code, please ignore this email.</p>
            <div class="footer">
              <p>© 2026 EtherWorld. All rights reserved.</p>
            </div>
          </div>
        </body>
        </html>
      `
    };
    
    await transporter.sendMail(mailOptions);
    
    console.log(`✅ OTP sent to ${email}: ${otp} (expires in 10 min)`);
    
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
    
    if (!email || !code) {
      return res.status(400).json({ error: 'Email and code are required' });
    }
    
    const emailLower = email.toLowerCase();
    const storedData = otpStore.get(emailLower);
    
    if (!storedData) {
      return res.status(400).json({ error: 'No OTP found. Please request a new code.' });
    }
    
    // Check expiration
    if (Date.now() > storedData.expiresAt) {
      otpStore.delete(emailLower);
      return res.status(400).json({ error: 'OTP expired. Please request a new code.' });
    }
    
    // Check attempts
    if (storedData.attempts >= 3) {
      otpStore.delete(emailLower);
      return res.status(400).json({ error: 'Too many failed attempts. Please request a new code.' });
    }
    
    // Verify code
    if (storedData.code !== code) {
      storedData.attempts++;
      return res.status(400).json({ error: 'Invalid verification code' });
    }
    
    // Success - remove OTP and create session
    otpStore.delete(emailLower);
    
    // Generate JWT token (simplified - use proper JWT library in production)
    const token = Buffer.from(JSON.stringify({
      email: emailLower,
      iat: Date.now(),
      exp: Date.now() + 30 * 24 * 60 * 60 * 1000 // 30 days
    })).toString('base64');
    
    // Return user data
    const response = {
      token,
      user: {
        id: Buffer.from(emailLower).toString('base64').substring(0, 16),
        email: emailLower,
        name: email.split('@')[0],
        authProvider: 'email',
        createdAt: new Date().toISOString()
      },
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
  res.json({ 
    status: 'ok', 
    timestamp: new Date().toISOString(),
    emailConfigured: !!process.env.EMAIL_USER
  });
});

// Start server
app.listen(PORT, () => {
  console.log(`🚀 EtherWorld OTP Backend running on port ${PORT}`);
  console.log(`📧 Email mode: ${process.env.EMAIL_SERVICE || process.env.SMTP_HOST || 'TEST MODE'}`);
  console.log(`🔗 Health check: http://localhost:${PORT}/health`);
});
