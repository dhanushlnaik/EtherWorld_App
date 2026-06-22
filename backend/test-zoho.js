const nodemailer = require('nodemailer');

const credentials = {
  user: 'contact@etherworld.co',
  pass: 'FD54gh#46snnn'
};

async function testConnection(port, secure) {
  console.log(`\nTesting connection to smtp.zoho.com on port ${port} (secure: ${secure})...`);
  try {
    const transporter = nodemailer.createTransport({
      host: 'smtp.zoho.com',
      port: port,
      secure: secure,
      auth: credentials,
      connectionTimeout: 5000,
      greetingTimeout: 5000
    });

    await new Promise((resolve, reject) => {
      transporter.verify((error, success) => {
        if (error) {
          reject(error);
        } else {
          resolve(success);
        }
      });
    });

    console.log(`✅ SUCCESS: Connection verified on port ${port}!`);
    return true;
  } catch (error) {
    console.error(`❌ FAILED on port ${port}:`, error.message);
    return false;
  }
}

async function run() {
  console.log('🏁 Starting Zoho SMTP tests...');
  // Test port 465 (SSL)
  await testConnection(465, true);
  // Test port 587 (STARTTLS)
  await testConnection(587, false);
}

run();
