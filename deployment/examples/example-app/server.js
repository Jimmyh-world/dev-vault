// Example application demonstrating Vault secret usage
// Reads secrets from environment variables loaded by fetch-secrets.sh
// Created: 2025-10-21

require('dotenv').config();  // Load .env file created by fetch-secrets.sh

const secrets = {
    database: {
        host: process.env.host || 'NOT_SET',
        port: process.env.port || 'NOT_SET',
        username: process.env.username || 'NOT_SET',
        password: process.env.password ? '***REDACTED***' : 'NOT_SET'
    }
};

console.log('\n=== Example App Started ===');
console.log('Loaded secrets from Vault:');
console.log(JSON.stringify(secrets, null, 2));
console.log('\n✅ Success! Secrets loaded from Vault via AppRole authentication');
console.log('App would now connect to database, APIs, etc.\n');

// Keep app running for demo
setInterval(() => {
    console.log(`[${new Date().toISOString()}] App running with Vault secrets...`);
}, 30000);
