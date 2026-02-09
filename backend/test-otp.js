#!/usr/bin/env node

/**
 * Test script to diagnose OTP backend issues
 * Run: node test-otp.js
 */

require('dotenv').config({ path: require('path').join(__dirname, '.env') });

console.log('\n🔍 DIAGNOSTIC TEST FOR OTP BACKEND\n');

// 1. Check environment variables
console.log('1️⃣  CHECKING ENVIRONMENT VARIABLES:');
const sendGridKey = process.env.SENDGRID_API_KEY;
const sendGridFrom = process.env.SENDGRID_FROM_EMAIL;
const emailService = process.env.EMAIL_SERVICE;
const smtpHost = process.env.SMTP_HOST;

console.log(`   SENDGRID_API_KEY: ${sendGridKey ? '✅ Set (' + sendGridKey.substring(0, 10) + '...)' : '❌ NOT SET'}`);
console.log(`   SENDGRID_FROM_EMAIL: ${sendGridFrom ? '✅ ' + sendGridFrom : '❌ NOT SET'}`);
console.log(`   EMAIL_SERVICE: ${emailService || '⚠️  Not set'}`);
console.log(`   SMTP_HOST: ${smtpHost || '⚠️  Not set'}`);

// 2. Check which email mode will be used
console.log('\n2️⃣  EMAIL MODE DETECTION:');
let emailMode = 'UNKNOWN';
if (sendGridKey) {
  emailMode = 'SendGrid API';
} else if (emailService === 'gmail') {
  emailMode = 'Gmail SMTP';
} else if (smtpHost) {
  emailMode = 'Custom SMTP';
} else {
  emailMode = 'TEST MODE';
}
console.log(`   Detected mode: ${emailMode}`);

// 3. Test SendGrid API key format
if (sendGridKey) {
  console.log('\n3️⃣  SENDGRID API KEY VALIDATION:');
  if (sendGridKey.startsWith('SG.')) {
    console.log('   ✅ API key has correct format (starts with SG.)');
  } else {
    console.log('   ❌ API key format looks wrong (should start with SG.)');
  }
  if (sendGridKey.length > 50) {
    console.log('   ✅ API key length looks reasonable');
  } else {
    console.log('   ❌ API key seems too short');
  }
}

// 4. Test backend health endpoint locally
console.log('\n4️⃣  TESTING BACKEND HEALTH ENDPOINT:');
const http = require('http');

const options = {
  hostname: 'localhost',
  port: process.env.PORT || 3000,
  path: '/health',
  method: 'GET',
  timeout: 5000
};

const req = http.request(options, (res) => {
  let data = '';
  res.on('data', chunk => data += chunk);
  res.on('end', () => {
    try {
      const health = JSON.parse(data);
      console.log(`   Status: ${health.status}`);
      console.log(`   Email mode: ${health.emailMode}`);
      console.log(`   Email configured: ${health.emailConfigured}`);
      console.log(`   SendGrid configured: ${health.sendGridConfigured}`);
      console.log(`   From address: ${health.fromAddress}`);
      
      // 5. Test actual OTP sending
      console.log('\n5️⃣  TESTING OTP SEND ENDPOINT:');
      testOtpSend();
    } catch (err) {
      console.log(`   ❌ Failed to parse health response: ${err.message}`);
    }
  });
});

req.on('error', (err) => {
  if (err.code === 'ECONNREFUSED') {
    console.log(`   ❌ Backend not running on port ${process.env.PORT || 3000}`);
    console.log('   💡 Start the backend with: npm run dev');
  } else {
    console.log(`   ❌ Error: ${err.message}`);
  }
});

req.end();

function testOtpSend() {
  const testEmail = 'test@example.com';
  const postData = JSON.stringify({ email: testEmail });

  const options = {
    hostname: 'localhost',
    port: process.env.PORT || 3000,
    path: '/auth/send-otp',
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Content-Length': Buffer.byteLength(postData)
    },
    timeout: 10000
  };

  const req = http.request(options, (res) => {
    let data = '';
    res.on('data', chunk => data += chunk);
    res.on('end', () => {
      try {
        const response = JSON.parse(data);
        if (res.statusCode === 200) {
          console.log(`   ✅ OTP send request succeeded`);
          console.log(`   Response: ${JSON.stringify(response, null, 2)}`);
        } else {
          console.log(`   ❌ OTP send request failed with status ${res.statusCode}`);
          console.log(`   Response: ${JSON.stringify(response, null, 2)}`);
        }
      } catch (err) {
        console.log(`   ❌ Failed to parse response: ${err.message}`);
        console.log(`   Raw response: ${data}`);
      }
      console.log('\n✅ DIAGNOSTIC TEST COMPLETE\n');
    });
  });

  req.on('error', (err) => {
    console.log(`   ❌ Request error: ${err.message}`);
    console.log('\n✅ DIAGNOSTIC TEST COMPLETE\n');
  });

  req.write(postData);
  req.end();
}
