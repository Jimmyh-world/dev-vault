# Vault Usage Guide - Application Secrets & Container Integration

**Last Updated:** 2025-10-20
**Vault Version:** 1.15.6
**Deployment:** Beast (192.168.68.100:8200)
**Status:** Operational

---

## 📋 Table of Contents

1. [Overview](#overview)
2. [Quick Start: Store Your First Secret](#quick-start-store-your-first-secret)
3. [Container Integration Patterns](#container-integration-patterns)
4. [AppRole Setup (Required for Containers)](#approle-setup-required-for-containers)
5. [Real-World Examples](#real-world-examples)
6. [User Onboarding](#user-onboarding)
7. [Troubleshooting](#troubleshooting)

---

## Overview

### What Vault Does for Your Apps

Vault provides **centralized secret management** for applications running on Beast. Instead of:

❌ Hardcoding secrets in `docker-compose.yml` (committed to git!)
❌ Using `.env` files (easy to leak)
❌ Manually distributing credentials to team members

You get:

✅ **Centralized storage** - All secrets in one secure place
✅ **Access control** - Role-based policies (who can read what)
✅ **Audit trail** - Every access logged
✅ **Versioning** - Rollback to previous secret values
✅ **Dynamic secrets** - Auto-rotation, short-lived tokens

---

### What This Guide Covers

**For Developers:**
- How to store API keys, database credentials, etc.
- How to fetch secrets in your containers
- Integration patterns for web apps

**For Team Leads:**
- How to onboard new users
- How to organize secrets by project
- Access control best practices

**For DevOps:**
- AppRole authentication setup
- Container integration patterns
- Security validation

---

## Quick Start: Store Your First Secret

### Via Web UI (Easiest)

**Step 1: Access Vault UI**

```bash
# From local network
open http://192.168.68.100:8200/ui

# Or via SSH tunnel
ssh -L 8200:localhost:8200 jamesb@192.168.68.100
open http://localhost:8200/ui
```

**Step 2: Login**

- Method: **Token** or **Username**
- Token: `<your-token-from-password-manager>`
- Or Username: `testuser` / Password: `<from-phase-2>`

**Step 3: Navigate to Secrets**

1. Click **Secrets** in sidebar
2. Click **secret/** (KV v2 engine)
3. Click **Create secret**

**Step 4: Create Secret**

```
Path: myapp/production
Secret data:
  database_url = postgres://user:pass@db.example.com:5432/mydb
  stripe_api_key = sk_live_abc123xyz
  supabase_key = eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

**Step 5: Save**

✅ Secret stored at `secret/myapp/production`

---

### Via CLI (on Beast)

```bash
# SSH to Beast
ssh jamesb@192.168.68.100

# Set your token
export VAULT_TOKEN="<your-token>"

# Store secret
docker exec -e VAULT_TOKEN="$VAULT_TOKEN" vault \
  vault kv put secret/myapp/production \
    database_url="postgres://user:pass@db:5432/mydb" \
    stripe_api_key="sk_live_abc123" \
    supabase_key="eyJhbGc..."

# Read it back (verify)
docker exec -e VAULT_TOKEN="$VAULT_TOKEN" vault \
  vault kv get secret/myapp/production
```

---

## Container Integration Patterns

### The Problem

Your app needs secrets. How does it get them securely?

```yaml
# ❌ DON'T DO THIS
services:
  myapp:
    image: myapp:latest
    environment:
      DATABASE_URL: "postgres://..."  # Hardcoded! In git!
      STRIPE_KEY: "sk_live_..."        # Secret exposed!
```

### The Solution: 4 Patterns

| Pattern | Complexity | Security | Auto-Refresh | Best For |
|---------|-----------|----------|--------------|----------|
| **1. Pre-Start Script** | Low | Medium | No | Development, testing |
| **2. Init Container** | Medium | High | No | Stateless production apps |
| **3. Vault Agent Sidecar** | High | Highest | Yes | Long-running services |
| **4. App Native SDK** | Medium | High | Yes | Apps you control |

---

### Pattern 1: Pre-Start Script (Simplest)

**How it works:**
1. Admin runs script to fetch secrets
2. Writes to `.env` file (gitignored)
3. Docker Compose loads from `.env`

**Use when:** Quick setup, development, 1-2 developers

#### Setup

**Step 1: Create fetch script**

```bash
#!/bin/bash
# fetch-myapp-secrets.sh

export VAULT_ADDR="http://192.168.68.100:8200"
export VAULT_TOKEN="<your-admin-token>"

echo "Fetching secrets from Vault..."

# Fetch all secrets for myapp/production
docker exec -e VAULT_ADDR="$VAULT_ADDR" \
            -e VAULT_TOKEN="$VAULT_TOKEN" \
  vault vault kv get -format=json secret/myapp/production \
  | jq -r '.data.data | to_entries | .[] | "\(.key | ascii_upcase)=\(.value)"' \
  > .env

echo "✅ Secrets written to .env"
echo "Run: docker-compose up -d"
```

**Step 2: Update .gitignore**

```
.env
fetch-myapp-secrets.sh  # Contains your token
```

**Step 3: Update docker-compose.yml**

```yaml
services:
  myapp:
    image: myapp:latest
    env_file: .env  # Load from .env
```

**Step 4: Usage**

```bash
./fetch-myapp-secrets.sh  # Fetch latest
docker-compose up -d      # Start with secrets
```

**Pros:**
- ✅ Simplest to implement (15 min)
- ✅ No code changes
- ✅ Good for development

**Cons:**
- ❌ Manual step (must remember to run)
- ❌ Secrets on disk (.env file)
- ❌ No auto-refresh

---

### Pattern 2: Init Container (Production-Ready)

**How it works:**
1. Container starts with AppRole credentials
2. Entrypoint script authenticates to Vault
3. Fetches secrets, exports as env vars
4. Starts main app

**Use when:** Production apps, stateless services, team of 3-5

#### Setup

**Prerequisites:** AppRole configured (see [AppRole Setup](#approle-setup-required-for-containers))

**Step 1: Create entrypoint wrapper**

```bash
#!/bin/bash
# entrypoint-with-vault.sh

set -e

echo "🔐 Authenticating with Vault..."

# Authenticate with AppRole
VAULT_TOKEN=$(curl -s -X POST http://vault:8200/v1/auth/approle/login \
  -d "{\"role_id\":\"$VAULT_ROLE_ID\",\"secret_id\":\"$VAULT_SECRET_ID\"}" \
  | jq -r '.auth.client_token')

if [ -z "$VAULT_TOKEN" ]; then
  echo "❌ Failed to authenticate with Vault"
  exit 1
fi

echo "✅ Authenticated successfully"
echo "📦 Fetching secrets..."

# Fetch secrets and export as env vars
eval $(curl -s -H "X-Vault-Token: $VAULT_TOKEN" \
  http://vault:8200/v1/secret/data/myapp/production \
  | jq -r '.data.data | to_entries | .[] | "export \(.key | ascii_upcase)=\(.value)"')

echo "✅ Secrets loaded"
echo "🚀 Starting application..."

# Start your app (replace with your command)
exec node server.js
```

**Step 2: Update docker-compose.yml**

```yaml
services:
  myapp:
    image: myapp:latest
    entrypoint: /scripts/entrypoint-with-vault.sh
    environment:
      VAULT_ROLE_ID: ${VAULT_ROLE_ID}      # Not secret, can commit
      VAULT_SECRET_ID: ${VAULT_SECRET_ID}  # Secret, in .env
    volumes:
      - ./entrypoint-with-vault.sh:/scripts/entrypoint-with-vault.sh:ro
    networks:
      - vault_network

networks:
  vault_network:
    external: true  # Connect to Vault's network
```

**Step 3: Create .env (gitignored)**

```bash
# .env (DO NOT COMMIT)
VAULT_ROLE_ID=1234abcd-5678-efgh-...       # From AppRole setup
VAULT_SECRET_ID=9876zyxw-4321-ponm-...     # From AppRole setup (SECRET!)
```

**Step 4: Usage**

```bash
docker-compose up -d  # Secrets fetched automatically on start
```

**Pros:**
- ✅ Automatic on container start
- ✅ No manual steps
- ✅ Secrets not on disk
- ✅ Production-ready

**Cons:**
- ❌ No auto-refresh (must restart for new secrets)
- ❌ Secrets in env vars (visible in `docker inspect`)

---

### Pattern 3: Vault Agent Sidecar (Most Secure)

**How it works:**
1. Vault Agent sidecar container runs alongside app
2. Agent authenticates with AppRole
3. Fetches secrets, writes to shared volume
4. App reads from `/vault/secrets/`
5. Agent auto-renews and refreshes

**Use when:** Long-running services, high security, auto-refresh needed

#### Setup

**Step 1: Create Vault Agent config**

```hcl
# vault-agent.hcl
pid_file = "/tmp/pidfile"

vault {
  address = "http://vault:8200"
}

auto_auth {
  method {
    type = "approle"
    config = {
      role_id_file_path = "/vault/config/role-id"
      secret_id_file_path = "/vault/config/secret-id"
      remove_secret_id_file_after_reading = false
    }
  }

  sink {
    type = "file"
    config = {
      path = "/vault/token"
    }
  }
}

template {
  source      = "/vault/config/secrets.tmpl"
  destination = "/vault/secrets/secrets.env"
}
```

**Step 2: Create secret template**

```
# secrets.tmpl
{{ with secret "secret/data/myapp/production" }}
DATABASE_URL={{ .Data.data.database_url }}
STRIPE_API_KEY={{ .Data.data.stripe_api_key }}
SUPABASE_KEY={{ .Data.data.supabase_key }}
{{ end }}
```

**Step 3: Update docker-compose.yml**

```yaml
services:
  vault-agent:
    image: hashicorp/vault:1.15.6
    command: agent -config=/vault/config/agent.hcl
    volumes:
      - ./vault-agent.hcl:/vault/config/agent.hcl:ro
      - ./secrets.tmpl:/vault/config/secrets.tmpl:ro
      - ./role-id:/vault/config/role-id:ro
      - ./secret-id:/vault/config/secret-id:ro
      - secrets:/vault/secrets
    networks:
      - vault_network

  myapp:
    image: myapp:latest
    volumes:
      - secrets:/app/secrets:ro  # Read-only access
    environment:
      SECRETS_FILE: /app/secrets/secrets.env
    command: sh -c "source /app/secrets/secrets.env && node server.js"
    networks:
      - vault_network
    depends_on:
      - vault-agent

volumes:
  secrets:

networks:
  vault_network:
    external: true
```

**Pros:**
- ✅ Most secure (no env vars)
- ✅ Auto-renewal of tokens
- ✅ Secrets refreshed without restart
- ✅ Industry standard

**Cons:**
- ❌ More complex setup (extra container)
- ❌ Requires AppRole

---

### Pattern 4: Application Native SDK

**How it works:**
App code directly uses Vault SDK to fetch secrets.

**Example (Node.js):**

```javascript
// app.js
const vault = require('node-vault')({
  apiVersion: 'v1',
  endpoint: 'http://vault:8200',
});

async function getSecrets() {
  // Authenticate with AppRole
  const auth = await vault.approleLogin({
    role_id: process.env.VAULT_ROLE_ID,
    secret_id: process.env.VAULT_SECRET_ID,
  });

  vault.token = auth.auth.client_token;

  // Fetch secrets
  const result = await vault.read('secret/data/myapp/production');
  const secrets = result.data.data;

  return secrets;
}

// Use in app
(async () => {
  const secrets = await getSecrets();
  const dbUrl = secrets.database_url;
  // ... connect to database
})();
```

**Example (Python):**

```python
# app.py
import hvac
import os

client = hvac.Client(url='http://vault:8200')

# Authenticate
client.auth.approle.login(
    role_id=os.environ['VAULT_ROLE_ID'],
    secret_id=os.environ['VAULT_SECRET_ID']
)

# Fetch secrets
secret = client.secrets.kv.v2.read_secret_version(
    path='myapp/production'
)

database_url = secret['data']['data']['database_url']
stripe_key = secret['data']['data']['stripe_api_key']
```

**Pros:**
- ✅ Most flexible
- ✅ Can refresh on schedule
- ✅ App controls caching

**Cons:**
- ❌ Requires code changes
- ❌ More complex error handling

---

## AppRole Setup (Required for Containers)

Before containers can fetch secrets, you need **AppRole authentication**.

### What is AppRole?

AppRole is Vault's **machine-to-machine** authentication method.

- **Role ID**: Public identifier (safe to commit)
- **Secret ID**: Secret credential (like a password)

Think of it like username + password for apps.

---

### Setup Steps (Run on Beast)

**Step 1: Enable AppRole**

```bash
# SSH to Beast
ssh jamesb@192.168.68.100

# Set admin token
export VAULT_TOKEN="<your-admin-token>"

# Enable AppRole auth method
docker exec -e VAULT_TOKEN="$VAULT_TOKEN" vault \
  vault auth enable approle
```

**Step 2: Create Policy for Your App**

```bash
# Create policy file
cat > myapp-policy.hcl <<EOF
# Read access to myapp secrets
path "secret/data/myapp/*" {
  capabilities = ["read"]
}

# List access
path "secret/metadata/myapp/*" {
  capabilities = ["list"]
}

# Token self-introspection
path "auth/token/lookup-self" {
  capabilities = ["read"]
}

# Token renewal
path "auth/token/renew-self" {
  capabilities = ["update"]
}
EOF

# Upload policy to Vault
docker exec -i -e VAULT_TOKEN="$VAULT_TOKEN" vault \
  vault policy write myapp-policy - < myapp-policy.hcl
```

**Step 3: Create AppRole**

```bash
# Create role attached to policy
docker exec -e VAULT_TOKEN="$VAULT_TOKEN" vault \
  vault write auth/approle/role/myapp \
    token_policies="myapp-policy" \
    token_ttl=24h \
    token_max_ttl=768h
```

**Step 4: Get Role ID (Public)**

```bash
# Get Role ID
ROLE_ID=$(docker exec -e VAULT_TOKEN="$VAULT_TOKEN" vault \
  vault read -field=role_id auth/approle/role/myapp/role-id)

echo "Role ID: $ROLE_ID"
# Save this in docker-compose.yml or .env
```

**Step 5: Generate Secret ID (SECRET!)**

```bash
# Generate Secret ID
SECRET_ID=$(docker exec -e VAULT_TOKEN="$VAULT_TOKEN" vault \
  vault write -f -field=secret_id auth/approle/role/myapp/secret-id)

echo "Secret ID: $SECRET_ID"
# ⚠️ SAVE THIS IN PASSWORD MANAGER!
# Add to .env (gitignored)
```

**Step 6: Test Authentication**

```bash
# Test login with AppRole
docker exec vault vault write auth/approle/login \
  role_id="$ROLE_ID" \
  secret_id="$SECRET_ID"

# Should return a token ✅
```

---

### AppRole Security Best Practices

1. **Secret ID Rotation**: Generate new Secret IDs periodically
2. **TTL Limits**: Set reasonable token TTLs (24h default)
3. **Policy Least Privilege**: Only grant read access to specific paths
4. **Audit Logging**: Monitor AppRole logins

---

## Real-World Examples

### Example 1: Cardano Trading Bot

**Secrets Needed:**
- Cardano signing key
- Maestro API key (testnet + mainnet)
- Database credentials

**Vault Structure:**

```
secret/cardano-bot/production/
  ├── signing_key_testnet
  ├── signing_key_mainnet
  ├── maestro_api_key_testnet
  ├── maestro_api_key_mainnet
  └── database_url
```

**AppRole Setup:**

```bash
# Create policy
cat > cardano-bot-policy.hcl <<EOF
path "secret/data/cardano-bot/*" {
  capabilities = ["read"]
}
EOF

docker exec -i -e VAULT_TOKEN="$VAULT_TOKEN" vault \
  vault policy write cardano-bot-policy - < cardano-bot-policy.hcl

# Create role
docker exec -e VAULT_TOKEN="$VAULT_TOKEN" vault \
  vault write auth/approle/role/cardano-bot \
    token_policies="cardano-bot-policy" \
    token_ttl=24h
```

**docker-compose.yml:**

```yaml
services:
  cardano-bot:
    image: cardano-bot:latest
    entrypoint: /scripts/entrypoint-with-vault.sh
    environment:
      VAULT_ROLE_ID: ${CARDANO_BOT_ROLE_ID}
      VAULT_SECRET_ID: ${CARDANO_BOT_SECRET_ID}
      NETWORK: production
```

---

### Example 2: Multi-Tenant SaaS

**Secrets Needed:**
- Supabase credentials (per environment)
- Stripe API keys
- SendGrid API key
- OAuth tokens

**Vault Structure:**

```
secret/myapp/
  ├── development/
  │   ├── supabase_url
  │   ├── supabase_anon_key
  │   └── stripe_api_key_test
  ├── staging/
  │   └── ...
  └── production/
      ├── supabase_url
      ├── supabase_anon_key
      ├── stripe_api_key_live
      ├── sendgrid_api_key
      └── github_oauth_token
```

**Policy (Separate by Environment):**

```hcl
# myapp-dev-policy.hcl
path "secret/data/myapp/development/*" {
  capabilities = ["read"]
}

# myapp-prod-policy.hcl
path "secret/data/myapp/production/*" {
  capabilities = ["read"]
}
```

---

## User Onboarding

### For Team Members (3-5 Users)

**Step 1: Admin Creates User**

```bash
# Enable userpass (if not already)
docker exec -e VAULT_TOKEN="$VAULT_TOKEN" vault \
  vault auth enable userpass

# Create user
docker exec -e VAULT_TOKEN="$VAULT_TOKEN" vault \
  vault write auth/userpass/users/alice \
    password="<generate-secure-password>" \
    policies="project-alpha-policy"
```

**Step 2: Share Credentials**

Send to user (via secure channel):
```
Vault URL: http://192.168.68.100:8200/ui
Username: alice
Password: <secure-password>
Policy: project-alpha-policy (read/write to secret/projects/alpha/*)
```

**Step 3: User First Login**

1. Navigate to Vault UI
2. Method: **Username**
3. Login with credentials
4. Navigate to `secret/projects/alpha/`
5. Create/read secrets

---

### Secret Organization (Multi-Project)

**Recommended Structure:**

```
secret/
├── projects/
│   ├── alpha/
│   │   ├── dev/
│   │   ├── staging/
│   │   └── production/
│   ├── beta/
│   │   └── dev/
│   └── gamma/
├── shared/
│   ├── api-keys/
│   └── databases/
└── personal/
    ├── alice/
    └── bob/
```

**Per-Project Policies:**

```hcl
# project-alpha-policy.hcl
# Full access to alpha project
path "secret/data/projects/alpha/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

# Read-only access to shared
path "secret/data/shared/*" {
  capabilities = ["read", "list"]
}

# Personal namespace
path "secret/data/personal/alice/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
```

---

## Troubleshooting

### Issue: Container Can't Connect to Vault

**Symptoms:**
```
curl: (7) Failed to connect to vault:8200
```

**Solution:**
Ensure container is on same network as Vault:

```yaml
services:
  myapp:
    networks:
      - vault_network

networks:
  vault_network:
    external: true
```

Or use Beast's IP directly:
```bash
VAULT_ADDR=http://192.168.68.100:8200
```

---

### Issue: AppRole Authentication Fails

**Symptoms:**
```
Error: permission denied
```

**Debug Steps:**

```bash
# 1. Verify Role ID is correct
docker exec -e VAULT_TOKEN="$VAULT_TOKEN" vault \
  vault read auth/approle/role/myapp/role-id

# 2. Generate fresh Secret ID
docker exec -e VAULT_TOKEN="$VAULT_TOKEN" vault \
  vault write -f auth/approle/role/myapp/secret-id

# 3. Test login manually
docker exec vault vault write auth/approle/login \
  role_id="$ROLE_ID" \
  secret_id="$SECRET_ID"
```

---

### Issue: Policy Denies Access

**Symptoms:**
```
Error: permission denied on secret/data/myapp/production
```

**Debug Steps:**

```bash
# 1. Check which policies are attached
docker exec -e VAULT_TOKEN="$VAULT_TOKEN" vault \
  vault read auth/approle/role/myapp

# 2. Read policy contents
docker exec -e VAULT_TOKEN="$VAULT_TOKEN" vault \
  vault policy read myapp-policy

# 3. Verify path matches
# Policy: secret/data/myapp/*
# Request: secret/data/myapp/production ✅
```

**Common mistake:** KV v2 paths have `/data/` in them:
- ❌ `secret/myapp/production` (wrong)
- ✅ `secret/data/myapp/production` (correct)

---

### Issue: Secrets Not Refreshing

**Symptoms:**
Old secret values even after updating in Vault.

**Solution:**
- **Pattern 1-2:** Restart container to fetch latest
- **Pattern 3:** Check Agent template refresh interval
- **Pattern 4:** Implement periodic refetch in app code

---

## Next Steps

### Ready to Integrate?

1. **Choose Pattern**: Start with Pattern 1 (simple) or Pattern 2 (production)
2. **Set Up AppRole**: Follow [AppRole Setup](#approle-setup-required-for-containers)
3. **Store Secrets**: Use Web UI or CLI
4. **Test Integration**: Verify container can fetch secrets
5. **Deploy**: Roll out to production

### Need Help?

- **Vault Docs**: https://www.vaultproject.io/docs
- **AGENTS.md**: Project-specific guidelines
- **NEXT-SESSION-START-HERE.md**: Current status and next tasks
- **Phase 2 Checkpoint**: docs/checkpoints/PHASE-2-CHECKPOINT-APPROVAL.md

---

**Last Updated:** 2025-10-20
**Template Compliance:** ✅ Following Jimmy's standards
**Workflow:** RED→GREEN→CHECKPOINT
