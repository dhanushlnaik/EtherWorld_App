#!/usr/bin/env node

/**
 * Test SendGrid OTP Backend
 * Run: node test-sendgrid-otp.js
 */

require('dotenv').config({ path: require('path').join(__dirname, '.env') });
const https = require('https');

console.log('\n🔍 TESTING SENDGRID OTP BACKEND\n');

// 1. Check config
console.log('1️⃣  SENDGRID CONFIGURATION:');
const apiKey = process.env.SENDGRID_API_KEY;
const fromEmail = process.env.SENDGRID_FROM_EMAIL;

if (!apiKey || !fromEmail) {
  console.log('   ❌ Missing SENDGRID_API_KEY or SENDGRID_FROM_EMAIL');
  process.exit(1);
}

console.log(`   ✅ API Key: ${apiKey.substring(0, 15)}...`);
console.log(`   ✅ From Email: ${fromEmail}`);

// 2. Test SendGrid API directly
console.log('\n2️⃣  TESTING SENDGRID API:');

const testEmail = 'test@example.com';
const payload = {
  personalizations: [{
    to: [{ email: testEmail }]
  }],
  from: { email: fromEmail },
  subject: 'EtherWorld OTP Test',
  content: [{
    type: 'text/html',
    value: '<p>Test OTP: <strong>123456</strong></p>'
  }]
};

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
    console.log(`   Status: ${res.statusCode}`);
    
    if (res.statusCode >= 200 && res.statusCode < 300) {
      console.log(`   ✅ SendGrid accepted email!`);
      console.log('\n✅ SENDGRID OTP BACKEND IS READY\n');
    } else {
      console.log(`   ❌ SendGrid rejected email`);
      console.log(`   Response: ${body}`);
    }
  });
});

req.on('error', (err) => {
  console.log(`   ❌ Network error: ${err.message}`);
});

req.write(JSON.stringify(payload));
req.end();
