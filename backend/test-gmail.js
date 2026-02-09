#!/usr/bin/env node

/**
 * Extended diagnostic for Gmail/Email configuration
 */

const nodemailer = require('nodemailer');
require('dotenv').config({ path: require('path').join(__dirname, '.env') });

console.log('\n🔍 GMAIL/EMAIL CONFIGURATION DIAGNOSTIC\n');

// 1. Check raw credentials
console.log('1️⃣  RAW CREDENTIALS FROM .env:');
const emailService = process.env.EMAIL_SERVICE;
const emailUser = process.env.EMAIL_USER;
const emailPassword = process.env.EMAIL_PASSWORD;
const emailFrom = process.env.EMAIL_FROM;

console.log(`   EMAIL_SERVICE: ${emailService}`);
console.log(`   EMAIL_USER: ${emailUser}`);
console.log(`   EMAIL_PASSWORD: [${emailPassword ? emailPassword.length + ' chars' : 'NOT SET'}]`);
console.log(`   EMAIL_PASSWORD (raw): "${emailPassword}"`);
console.log(`   EMAIL_FROM: ${emailFrom}`);

// 2. Check for common issues
console.log('\n2️⃣  CHECKING FOR COMMON ISSUES:');

if (emailPassword && emailPassword.includes(' ')) {
  console.log('   ⚠️  WARNING: Email password contains spaces');
  console.log(`      This is NORMAL for Gmail app passwords (16 chars with 3 spaces)`);
  console.log(`      Current length: ${emailPassword.length} chars`);
}

if (!emailUser) {
  console.log('   ❌ EMAIL_USER not set');
}
if (!emailPassword) {
  console.log('   ❌ EMAIL_PASSWORD not set');
}

// 3. Try to create transporter
console.log('\n3️⃣  ATTEMPTING TO CREATE GMAIL TRANSPORTER:');
try {
  const transporter = nodemailer.createTransport({
    service: 'gmail',
    auth: {
      user: emailUser,
      pass: emailPassword
    }
  });
  console.log('   ✅ Transporter created successfully');
  
  // 4. Verify connection
  console.log('\n4️⃣  VERIFYING GMAIL CONNECTION:');
  transporter.verify((error, success) => {
    if (error) {
      console.log(`   ❌ VERIFICATION FAILED: ${error.message}`);
      console.log(`   Error code: ${error.code}`);
      if (error.message.includes('Invalid login')) {
        console.log('\n   💡 SOLUTIONS:');
        console.log('      1. Check EMAIL_USER is correct');
        console.log('      2. Check EMAIL_PASSWORD is correct (use App Password, not regular password)');
        console.log('      3. Ensure 2FA is enabled and App Password is generated');
        console.log('      4. Check if account is locked due to login attempts');
      }
      if (error.code === 'EAUTH') {
        console.log('\n   💡 This is an authentication error. Most likely causes:');
        console.log('      - Wrong app password');
        console.log('      - Wrong email address');
        console.log('      - App password has been revoked');
      }
    } else {
      console.log('   ✅ CONNECTION VERIFIED - Gmail transporter is working!');
      
      // 5. Test sending
      console.log('\n5️⃣  SENDING TEST EMAIL:');
      const testMail = {
        from: emailFrom || emailUser,
        to: 'test@example.com',
        subject: 'EtherWorld OTP Test',
        html: `<p>Test OTP: <strong>123456</strong></p>`
      };
      
      transporter.sendMail(testMail, (error, info) => {
        if (error) {
          console.log(`   ❌ SEND FAILED: ${error.message}`);
        } else {
          console.log(`   ✅ TEST EMAIL SENT`);
          console.log(`   Message ID: ${info.messageId}`);
        }
      });
    }
  });
  
} catch (err) {
  console.log(`   ❌ FAILED TO CREATE TRANSPORTER: ${err.message}`);
}

console.log('\n💾 RECOMMENDATION:');
console.log('   If you see connection failures, try these steps:');
console.log('   1. Go to myaccount.google.com/apppasswords');
console.log('   2. Select Mail and Windows Computer');
console.log('   3. Copy the generated 16-char password (with spaces)');
console.log('   4. Paste it exactly into EMAIL_PASSWORD in .env');
console.log('   5. Restart the backend\n');
