# Phase 3A: Container Integration - AppRole & Pre-Start Script Pattern

**Execution Date:** 2025-10-21
**Spec Version:** 1.0.0
**Target Machine:** Beast (192.168.68.100)
**Estimated Time:** 45-60 minutes
**Pattern:** Pattern 1 (Pre-Start Script - Simplest)

---

## 🎯 Objective

Enable containers and applications on Beast to fetch secrets from Vault using AppRole authentication with a simple pre-start script pattern.

**Success Criteria:**
- AppRole authentication method enabled and configured
- Example app policy created and validated
- Working fetch-secrets.sh script template
- End-to-end test with demo container successful
- Documentation complete with usage examples

---

## 📋 Prerequisites

**Required Access:**
- SSH access to Beast (192.168.68.100)
- Vault root token or admin token
- Docker installed and running on Beast

**Existing Infrastructure:**
- ✅ Vault v1.15.6 running on Beast:8200
- ✅ KV v2 secrets engine at `secret/` path
- ✅ Userpass auth enabled
- ✅ Admin, bot, and external-readonly policies configured

**Validation Before Starting:**
```bash
# Verify Vault is accessible
curl -s http://192.168.68.100:8200/v1/sys/health | jq .

# Verify you can authenticate
export VAULT_ADDR="http://192.168.68.100:8200"
vault login <your-token>

# Verify KV v2 engine exists
vault secrets list
```

---

## 🔧 Implementation Steps

### Step 1: Enable AppRole Authentication Method

**What:** Enable AppRole auth method for machine-to-machine authentication

**Commands:**
```bash
cd ~/dev-vault

# Enable AppRole auth
vault auth enable approle

# Verify enabled
vault auth list | grep approle
```

**Expected Output:**
```
approle/    approle    n/a      n/a       n/a
```

---

### Step 2: Create Example App Policy

**What:** Create a policy that grants read access to app-specific secrets

**File to Create:** `deployment/policies/app-example.hcl`

**Content:**
```hcl
# Policy for example application
# Grants read access to app-specific secrets under secret/apps/example/
# Created: 2025-10-21
# Pattern: Container Integration (Pattern 1)

# Allow reading secrets for this app
path "secret/data/apps/example/*" {
  capabilities = ["read", "list"]
}

# Allow listing available secrets (optional, for debugging)
path "secret/metadata/apps/example/*" {
  capabilities = ["list"]
}

# Deny all other paths
path "secret/*" {
  capabilities = ["deny"]
}
```

**Apply Policy:**
```bash
# Write policy to Vault
vault policy write app-example deployment/policies/app-example.hcl

# Verify policy created
vault policy list | grep app-example
vault policy read app-example
```

---

### Step 3: Create AppRole for Example App

**What:** Create an AppRole role bound to the app-example policy

**Commands:**
```bash
# Create AppRole role
vault write auth/approle/role/example-app \
    token_ttl=1h \
    token_max_ttl=24h \
    policies="app-example" \
    bind_secret_id=true

# Get Role ID (this is public, can be in config)
vault read auth/approle/role/example-app/role-id

# Generate Secret ID (this is secret, inject at runtime)
vault write -f auth/approle/role/example-app/secret-id

# Save these for testing
export ROLE_ID=$(vault read -field=role_id auth/approle/role/example-app/role-id)
export SECRET_ID=$(vault write -f -field=secret_id auth/approle/role/example-app/secret-id)
```

**Expected Output:**
```
Key                   Value
---                   -----
role_id              <uuid>
secret_id            <uuid>
secret_id_accessor   <uuid>
```

---

### Step 4: Create Test Secrets for Example App

**What:** Create sample secrets that the example app will fetch

**Commands:**
```bash
# Create example app secrets
vault kv put secret/apps/example/database \
    host="postgres.example.com" \
    port="5432" \
    username="appuser" \
    password="test-password-change-in-production"

vault kv put secret/apps/example/api-keys \
    stripe_key="sk_test_example_key" \
    sendgrid_key="SG.example_key" \
    supabase_url="https://example.supabase.co" \
    supabase_anon_key="eyJ_example_key"

# Verify secrets created
vault kv list secret/apps/example/
vault kv get secret/apps/example/database
```

---

### Step 5: Create fetch-secrets.sh Script

**What:** Reusable bash script for fetching secrets from Vault using AppRole

**File to Create:** `deployment/scripts/fetch-secrets.sh`

**Content:**
```bash
#!/bin/bash
# fetch-secrets.sh - Fetch secrets from Vault using AppRole authentication
# Usage: ./fetch-secrets.sh [output-format]
#   output-format: env (default) | json | export
#
# Required Environment Variables:
#   VAULT_ADDR      - Vault server address (e.g., http://192.168.68.100:8200)
#   VAULT_ROLE_ID   - AppRole Role ID
#   VAULT_SECRET_ID - AppRole Secret ID
#   VAULT_SECRET_PATH - Path to secrets (e.g., secret/apps/example/database)
#
# Created: 2025-10-21
# Pattern: Container Integration (Pattern 1)

set -e  # Exit on any error

# Configuration
OUTPUT_FORMAT="${1:-env}"
VAULT_ADDR="${VAULT_ADDR:-http://192.168.68.100:8200}"
VAULT_ROLE_ID="${VAULT_ROLE_ID:?VAULT_ROLE_ID environment variable required}"
VAULT_SECRET_ID="${VAULT_SECRET_ID:?VAULT_SECRET_ID environment variable required}"
VAULT_SECRET_PATH="${VAULT_SECRET_PATH:?VAULT_SECRET_PATH environment variable required}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" >&2
}

# Step 1: Authenticate with AppRole
log_info "Authenticating with Vault using AppRole..."
AUTH_RESPONSE=$(curl -s --request POST \
    --data "{\"role_id\":\"${VAULT_ROLE_ID}\",\"secret_id\":\"${VAULT_SECRET_ID}\"}" \
    "${VAULT_ADDR}/v1/auth/approle/login")

# Check if authentication succeeded
if echo "$AUTH_RESPONSE" | jq -e '.auth.client_token' > /dev/null 2>&1; then
    VAULT_TOKEN=$(echo "$AUTH_RESPONSE" | jq -r '.auth.client_token')
    log_info "Authentication successful"
else
    log_error "Authentication failed"
    echo "$AUTH_RESPONSE" | jq . >&2
    exit 1
fi

# Step 2: Fetch secrets from Vault
log_info "Fetching secrets from ${VAULT_SECRET_PATH}..."
SECRETS_RESPONSE=$(curl -s --header "X-Vault-Token: ${VAULT_TOKEN}" \
    "${VAULT_ADDR}/v1/${VAULT_SECRET_PATH}")

# Check if fetch succeeded
if echo "$SECRETS_RESPONSE" | jq -e '.data.data' > /dev/null 2>&1; then
    log_info "Secrets fetched successfully"
else
    log_error "Failed to fetch secrets"
    echo "$SECRETS_RESPONSE" | jq . >&2
    exit 1
fi

# Step 3: Format and output secrets
case "$OUTPUT_FORMAT" in
    env)
        # Output as KEY=value for .env file
        echo "$SECRETS_RESPONSE" | jq -r '.data.data | to_entries[] | "\(.key)=\(.value)"'
        ;;
    json)
        # Output as JSON
        echo "$SECRETS_RESPONSE" | jq -r '.data.data'
        ;;
    export)
        # Output as export KEY=value for sourcing
        echo "$SECRETS_RESPONSE" | jq -r '.data.data | to_entries[] | "export \(.key)=\(.value)"'
        ;;
    *)
        log_error "Unknown output format: $OUTPUT_FORMAT"
        log_error "Supported formats: env, json, export"
        exit 1
        ;;
esac

log_info "Secrets output complete"
```

**Set Permissions:**
```bash
chmod +x deployment/scripts/fetch-secrets.sh
```

---

### Step 6: Create Example Docker Integration

**What:** Example docker-compose.yml showing how to use fetch-secrets.sh in a container

**File to Create:** `deployment/examples/docker-compose-pattern1.yml`

**Content:**
```yaml
# Example: Container Integration Pattern 1 (Pre-Start Script)
# This demonstrates how to fetch secrets before starting your application
# Created: 2025-10-21

version: '3.8'

services:
  example-app:
    image: node:18-alpine
    container_name: vault-example-app

    # Environment variables for Vault authentication
    environment:
      - VAULT_ADDR=http://192.168.68.100:8200
      - VAULT_ROLE_ID=${VAULT_ROLE_ID}          # Inject via .env or CI/CD
      - VAULT_SECRET_ID=${VAULT_SECRET_ID}      # Inject via .env or CI/CD (KEEP SECRET!)
      - VAULT_SECRET_PATH=secret/data/apps/example/database

    # Mount the fetch script
    volumes:
      - ../scripts/fetch-secrets.sh:/usr/local/bin/fetch-secrets.sh:ro
      - ./example-app:/app

    working_dir: /app

    # Entrypoint: Fetch secrets, then start app
    entrypoint: ["/bin/sh", "-c"]
    command:
      - |
        echo "=== Fetching secrets from Vault ==="
        fetch-secrets.sh env > /app/.env

        echo "=== Secrets loaded, starting application ==="
        cat /app/.env  # Optional: Show loaded vars (remove in production!)

        # Start your actual application
        # exec node server.js
        echo "App would start here. Sleeping for demo..."
        tail -f /dev/null

    networks:
      - vault-demo

networks:
  vault-demo:
    driver: bridge
```

---

### Step 7: Create Simple Test App

**What:** Minimal Node.js app to demonstrate secret loading

**File to Create:** `deployment/examples/example-app/server.js`

**Content:**
```javascript
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
```

**File to Create:** `deployment/examples/example-app/package.json`

**Content:**
```json
{
  "name": "vault-example-app",
  "version": "1.0.0",
  "description": "Example app demonstrating Vault integration",
  "main": "server.js",
  "scripts": {
    "start": "node server.js"
  },
  "dependencies": {
    "dotenv": "^16.0.0"
  }
}
```

---

### Step 8: End-to-End Test

**What:** Test the complete flow from authentication to secret fetching

**Test 1: CLI Test (Direct Script Execution)**
```bash
# Export test credentials
export VAULT_ADDR="http://192.168.68.100:8200"
export VAULT_ROLE_ID="<role-id-from-step-3>"
export VAULT_SECRET_ID="<secret-id-from-step-3>"
export VAULT_SECRET_PATH="secret/data/apps/example/database"

# Test fetch script
./deployment/scripts/fetch-secrets.sh env
./deployment/scripts/fetch-secrets.sh json
./deployment/scripts/fetch-secrets.sh export

# Expected output: Database credentials in requested format
```

**Test 2: Docker Container Test**
```bash
cd deployment/examples

# Create .env file with AppRole credentials
cat > .env <<EOF
VAULT_ROLE_ID=<role-id-from-step-3>
VAULT_SECRET_ID=<secret-id-from-step-3>
EOF

# Install app dependencies
cd example-app
npm install
cd ..

# Start container
docker-compose -f docker-compose-pattern1.yml up

# Expected output:
# - "Fetching secrets from Vault"
# - "Secrets loaded, starting application"
# - App shows loaded database credentials
```

**Test 3: Policy Enforcement Test**
```bash
# Try to access unauthorized path (should fail)
export VAULT_SECRET_PATH="secret/data/cardano/testnet/signing-key"
./deployment/scripts/fetch-secrets.sh env

# Expected: Permission denied error
```

---

### Step 9: Create Usage Documentation

**File to Create:** `deployment/examples/PATTERN1-USAGE.md`

**Content:**
```markdown
# Pattern 1: Pre-Start Script Integration Guide

**Pattern:** Pre-Start Script (Simplest)
**Setup Time:** 15 minutes
**Best For:** Quick prototypes, non-critical apps, learning Vault

---

## Quick Start

### 1. Get Your AppRole Credentials

Contact your Vault administrator to create an AppRole for your app:

```bash
# Admin creates AppRole for your app
vault write auth/approle/role/my-app \
    token_ttl=1h \
    token_max_ttl=24h \
    policies="my-app-policy"

# Get Role ID (safe to commit to repo)
vault read auth/approle/role/my-app/role-id

# Generate Secret ID (KEEP SECRET! Inject at runtime)
vault write -f auth/approle/role/my-app/secret-id
```

### 2. Add fetch-secrets.sh to Your Project

```bash
# Copy script to your project
cp /path/to/fetch-secrets.sh ./scripts/

chmod +x ./scripts/fetch-secrets.sh
```

### 3. Update Your Docker Entrypoint

**Before (without Vault):**
```dockerfile
CMD ["node", "server.js"]
```

**After (with Vault):**
```dockerfile
ENV VAULT_ADDR=http://192.168.68.100:8200
ENV VAULT_ROLE_ID=${VAULT_ROLE_ID}
ENV VAULT_SECRET_ID=${VAULT_SECRET_ID}
ENV VAULT_SECRET_PATH=secret/data/apps/myapp/config

CMD ["/bin/sh", "-c", "fetch-secrets.sh env > .env && node server.js"]
```

### 4. Inject Credentials at Runtime

**Docker Compose:**
```yaml
environment:
  - VAULT_ROLE_ID=${VAULT_ROLE_ID}      # From .env file
  - VAULT_SECRET_ID=${VAULT_SECRET_ID}  # From .env file (DO NOT COMMIT!)
```

**Docker Run:**
```bash
docker run \
  -e VAULT_ROLE_ID="your-role-id" \
  -e VAULT_SECRET_ID="your-secret-id" \
  myapp:latest
```

---

## Usage Examples

### Example 1: Fetch Database Credentials

```bash
export VAULT_SECRET_PATH="secret/data/apps/myapp/database"
./fetch-secrets.sh env > .env

# .env now contains:
# host=postgres.example.com
# port=5432
# username=myapp_user
# password=secret123
```

### Example 2: Fetch API Keys as JSON

```bash
export VAULT_SECRET_PATH="secret/data/apps/myapp/api-keys"
./fetch-secrets.sh json

# Output:
# {
#   "stripe_key": "sk_live_...",
#   "sendgrid_key": "SG...."
# }
```

### Example 3: Source Secrets into Shell

```bash
export VAULT_SECRET_PATH="secret/data/apps/myapp/env"
eval "$(./fetch-secrets.sh export)"

echo $DATABASE_URL  # Now available as environment variable
```

---

## Security Best Practices

1. **Never Commit Secret IDs**
   - Role IDs are safe to commit
   - Secret IDs must be injected at runtime (CI/CD, orchestrator)

2. **Use Short TTLs**
   - Token TTL: 1 hour (default)
   - Max TTL: 24 hours
   - Secrets refresh on container restart

3. **Limit Secret Scope**
   - Each app gets its own policy
   - Policy grants read-only access to app-specific path only

4. **Clean Up Secrets**
   - Don't log secrets to stdout (remove debug statements)
   - Don't mount .env files as volumes
   - Use in-memory volumes if possible

---

## Troubleshooting

### Error: "VAULT_ROLE_ID environment variable required"

**Solution:** Set required environment variables:
```bash
export VAULT_ADDR="http://192.168.68.100:8200"
export VAULT_ROLE_ID="your-role-id"
export VAULT_SECRET_ID="your-secret-id"
export VAULT_SECRET_PATH="secret/data/apps/myapp/config"
```

### Error: "Authentication failed"

**Causes:**
- Wrong Role ID or Secret ID
- Secret ID expired or used too many times
- AppRole not properly configured

**Solution:** Generate new Secret ID:
```bash
vault write -f auth/approle/role/myapp/secret-id
```

### Error: "Permission denied"

**Causes:**
- Policy doesn't grant access to requested path
- Wrong secret path format

**Solution:** Verify your policy and path:
```bash
vault policy read my-app-policy
vault kv list secret/apps/myapp/
```

---

## Upgrading to Pattern 2 or 3

When you're ready for production, consider:

- **Pattern 2 (Init Container):** More secure, uses in-memory volumes
- **Pattern 3 (Vault Agent Sidecar):** Auto-rotation, no restart needed

Both patterns are drop-in replacements - no app code changes required!

---

**Created:** 2025-10-21
**Maintainer:** Jimmy's DevOps Team
**Questions?** Check main Vault docs or create an issue
```

---

### Step 10: Update Management Scripts

**What:** Add AppRole management commands to existing scripts

**Update:** `deployment/manage-policies.sh` (add new functions)

**Commands to Add:**
```bash
# Add these functions to manage-policies.sh

# Create AppRole for an app
create_approle() {
    local app_name=$1
    local policy_name=$2

    echo "Creating AppRole for $app_name with policy $policy_name..."

    vault write auth/approle/role/${app_name} \
        token_ttl=1h \
        token_max_ttl=24h \
        policies="${policy_name}" \
        bind_secret_id=true

    echo "Role created. Get credentials with:"
    echo "  vault read auth/approle/role/${app_name}/role-id"
    echo "  vault write -f auth/approle/role/${app_name}/secret-id"
}

# Generate new Secret ID for an app
generate_secret_id() {
    local app_name=$1

    echo "Generating new Secret ID for $app_name..."
    vault write -f auth/approle/role/${app_name}/secret-id
}

# List all AppRoles
list_approles() {
    echo "Current AppRoles:"
    vault list auth/approle/role
}
```

---

## ✅ Validation Criteria (GREEN Phase)

**Execute these tests to verify successful implementation:**

### Test 1: AppRole Authentication Enabled
```bash
vault auth list | grep approle
# Expected: approle/ present in output
```

### Test 2: Example Policy Created
```bash
vault policy read app-example
# Expected: Policy content displayed without errors
```

### Test 3: AppRole Can Authenticate
```bash
# Use Role ID and Secret ID from Step 3
curl -s --request POST \
    --data "{\"role_id\":\"${ROLE_ID}\",\"secret_id\":\"${SECRET_ID}\"}" \
    http://192.168.68.100:8200/v1/auth/approle/login | jq .auth.client_token

# Expected: Valid client_token returned
```

### Test 4: Script Can Fetch Secrets
```bash
./deployment/scripts/fetch-secrets.sh env | grep "host="
# Expected: Database credentials displayed
```

### Test 5: Docker Container Runs Successfully
```bash
docker-compose -f deployment/examples/docker-compose-pattern1.yml up -d
docker logs vault-example-app | grep "Success"
# Expected: "✅ Success! Secrets loaded from Vault"
```

### Test 6: Policy Enforcement Works
```bash
# Try accessing unauthorized path
export VAULT_SECRET_PATH="secret/data/admin/root-key"
./deployment/scripts/fetch-secrets.sh env
# Expected: Permission denied error
```

---

## 📊 Success Metrics

**Deployment Validation:**
- [ ] AppRole auth method enabled
- [ ] app-example policy created and validated
- [ ] Example AppRole created with correct TTL
- [ ] Test secrets created under secret/apps/example/
- [ ] fetch-secrets.sh script works for all output formats
- [ ] Docker example starts and fetches secrets successfully
- [ ] Policy enforcement prevents unauthorized access
- [ ] Documentation complete and accurate

**Time Tracking:**
- Target: 45-60 minutes
- Actual: ___ minutes (fill in after completion)

**Issues Encountered:**
- None expected (list any issues here)

---

## 🔄 Rollback Procedure

If issues occur, rollback in reverse order:

```bash
# 1. Stop and remove test container
docker-compose -f deployment/examples/docker-compose-pattern1.yml down

# 2. Delete test secrets
vault kv metadata delete secret/apps/example/database
vault kv metadata delete secret/apps/example/api-keys

# 3. Delete AppRole
vault delete auth/approle/role/example-app

# 4. Delete policy
vault policy delete app-example

# 5. Disable AppRole auth (if no other apps use it)
vault auth disable approle

# 6. Remove files
rm -rf deployment/scripts/fetch-secrets.sh
rm -rf deployment/policies/app-example.hcl
rm -rf deployment/examples/
```

---

## 📝 Post-Implementation Tasks

After successful deployment:

1. **Document Credentials:**
   - Save example-app Role ID in password manager
   - Save example-app Secret ID in password manager (or regenerate as needed)

2. **Update Project Documentation:**
   - Add Phase 3A completion to NEXT-SESSION-START-HERE.md
   - Update README.md with container integration instructions
   - Create checkpoint document in docs/checkpoints/

3. **Prepare for Next Phase:**
   - If successful, consider Phase 3B (Multi-User Access)
   - Or Phase 3C (Patterns 2 & 3 for production apps)

---

## 📚 References

- [Vault AppRole Auth Method](https://www.vaultproject.io/docs/auth/approle)
- [Vault KV v2 Secrets Engine](https://www.vaultproject.io/docs/secrets/kv/kv-v2)
- [Docker Entrypoint Best Practices](https://docs.docker.com/develop/dev-best-practices/)
- Phase 1 Checkpoint: docs/checkpoints/PHASE-1-CHECKPOINT-APPROVAL.md
- Phase 2 Checkpoint: docs/checkpoints/PHASE-2-CHECKPOINT-APPROVAL.md

---

**Spec Created:** 2025-10-21
**Created By:** Chromebook Orchestrator (Claude Sonnet 4.5)
**Target Executor:** Beast Specialist (Claude Haiku 4.5)
**Workflow Phase:** 🔴 RED (Implementation Spec)
