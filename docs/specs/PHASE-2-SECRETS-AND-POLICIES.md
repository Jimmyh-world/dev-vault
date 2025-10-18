# SPEC: Phase 2 Secrets Engine & Access Policies

**Created:** 2025-10-18
**Status:** RED Phase (Ready for Beast execution)
**Estimated Effort:** 2-3 hours
**Complexity:** Medium
**Target Machine:** Beast (192.168.68.100)
**Foundation:** Jimmy's Workflow (MANDATORY)
**Prerequisite:** Phase 1 Vault deployment complete ✅

---

## Executive Summary

Configure Vault for actual secret storage and access control following Phase 1 architecture (devlab-vault-architecture.md lines 1129-1150).

**What gets configured:**
- KV v2 secrets engine at `secret/` path
- Three policies: admin-policy, bot-policy, external-readonly
- Userpass authentication method
- Test user creation
- Secret storage hierarchy
- Policy enforcement validation

**What this enables:**
- Secure storage of Cardano signing keys
- Policy-based access control
- Token generation for different roles
- Foundation for trading bot integration

---

## Prerequisites

**System State Required:**

### Phase 1 Complete
- ✅ Vault container running on Beast:8200
- ✅ Vault initialized and unsealed
- ✅ Root token available (from password manager)
- ✅ Audit logging enabled

### Verification
```bash
# Verify Vault is unsealed and operational
curl http://localhost:8200/v1/sys/health | jq .
# Expected: "sealed": false, "initialized": true

# Verify you have root token from backup
echo "Root token from password manager: hvs.xxxxxx"
```

---

## Configuration Architecture

### Secrets Hierarchy (Phase 1 - Simple)

```
secret/
├── cardano/
│   ├── testnet/
│   │   ├── signing-key          # Test wallet signing key
│   │   └── maestro-api-key      # Testnet Maestro API key
│   └── mainnet/
│       └── (empty for now - production comes later)
├── api-tokens/
│   └── test-user-token          # Test token for validation
└── config/
    └── test-config               # Test configuration secret
```

### Policy Structure

**Three policies (KISS - keep it simple):**

1. **admin-policy** - Full access (you)
2. **bot-policy** - Read cardano/* only (trading bot)
3. **external-readonly** - Read specific paths only (external users)

---

## Implementation Steps

**Beast:** Execute each step using Jimmy's Workflow (RED → GREEN → CHECKPOINT).

---

### Step 1: Enable KV v2 Secrets Engine

**Objective:** Enable key-value storage with versioning

**5-Question Guidance:**
- Q1. INTENT: Enable secrets storage at path "secret/"
- Q2. DATA: Need root token, vault secrets enable command
- Q3. SAFETY: Uses root token, creates new mount, safe operation
- Q4. OPTIMIZATION: Single command, idempotent
- Q5. TOOL: vault CLI via docker exec

**Execute:**

```bash
# Set root token from password manager
ROOT_TOKEN="<paste-root-token-from-password-manager>"

# Enable KV v2 at secret/ path
docker exec -e VAULT_TOKEN="$ROOT_TOKEN" vault \
  vault secrets enable -version=2 -path=secret kv

# Verify enabled
docker exec -e VAULT_TOKEN="$ROOT_TOKEN" vault \
  vault secrets list
```

**GREEN Validation Checklist:**
- [ ] Secrets engine enabled successfully
- [ ] `vault secrets list` shows `secret/` path
- [ ] Type is `kv` (key-value)
- [ ] Version is `2` (KV v2 with versioning)

**Verification Commands:**
```bash
docker exec -e VAULT_TOKEN="$ROOT_TOKEN" vault vault secrets list
docker exec -e VAULT_TOKEN="$ROOT_TOKEN" vault vault secrets list -detailed
```

**Expected Output:**
```
Path          Type         Description
----          ----         -----------
cubbyhole/    cubbyhole    per-token private secret storage
identity/     identity     identity store
secret/       kv           key-value secret storage (v2)
sys/          system       system endpoints used for control
```

**Rollback:**
```bash
docker exec -e VAULT_TOKEN="$ROOT_TOKEN" vault \
  vault secrets disable secret/
```

---

### Step 2: Create Admin Policy

**Objective:** Create policy with full Vault access

**5-Question Guidance:**
- Q1. INTENT: Create admin-policy for full access
- Q2. DATA: HCL policy definition, vault policy write command
- Q3. SAFETY: Just defining policy, doesn't grant access yet, safe
- Q4. OPTIMIZATION: Use heredoc for clean policy definition
- Q5. TOOL: vault policy write via docker exec

**Execute:**

```bash
# Create admin policy definition
cat > /home/jimmyb/vault/policies/admin-policy.hcl << 'EOF'
# Admin Policy - Full Access
# Created: 2025-10-18
# Assigned to: Primary administrator (Jimmy)

# Full access to all secrets
path "secret/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

# Manage policies
path "sys/policies/acl/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

# Manage tokens
path "auth/token/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# Manage authentication methods
path "auth/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# Read audit logs configuration
path "sys/audit" {
  capabilities = ["read", "sudo"]
}

# Token self-introspection
path "auth/token/lookup-self" {
  capabilities = ["read"]
}

path "auth/token/renew-self" {
  capabilities = ["update"]
}
EOF

# Create policies directory in vault container
docker exec vault mkdir -p /vault/policies

# Copy policy to container
docker cp /home/jimmyb/vault/policies/admin-policy.hcl vault:/vault/policies/

# Write policy to Vault
docker exec -e VAULT_TOKEN="$ROOT_TOKEN" vault \
  vault policy write admin-policy /vault/policies/admin-policy.hcl
```

**GREEN Validation Checklist:**
- [ ] Policy file created successfully
- [ ] Policy uploaded to Vault
- [ ] `vault policy list` shows admin-policy
- [ ] `vault policy read admin-policy` returns correct definition

**Verification Commands:**
```bash
docker exec -e VAULT_TOKEN="$ROOT_TOKEN" vault vault policy list
docker exec -e VAULT_TOKEN="$ROOT_TOKEN" vault vault policy read admin-policy
```

**Rollback:**
```bash
docker exec -e VAULT_TOKEN="$ROOT_TOKEN" vault \
  vault policy delete admin-policy
```

---

### Step 3: Create Bot Policy

**Objective:** Create restricted policy for trading bot (read cardano/* only)

**Execute:**

```bash
# Create bot policy definition
cat > /home/jimmyb/vault/policies/bot-policy.hcl << 'EOF'
# Bot Policy - Cardano Secrets Read-Only
# Created: 2025-10-18
# Assigned to: Trading bot service

# Read access to Cardano secrets
path "secret/data/cardano/*" {
  capabilities = ["read"]
}

# List Cardano secret paths
path "secret/metadata/cardano/*" {
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

# Deny all other access
path "*" {
  capabilities = ["deny"]
}
EOF

# Copy to container
docker cp /home/jimmyb/vault/policies/bot-policy.hcl vault:/vault/policies/

# Write policy to Vault
docker exec -e VAULT_TOKEN="$ROOT_TOKEN" vault \
  vault policy write bot-policy /vault/policies/bot-policy.hcl
```

**GREEN Validation:**
- [ ] Policy created
- [ ] Appears in policy list
- [ ] Read command returns definition

**Verification:**
```bash
docker exec -e VAULT_TOKEN="$ROOT_TOKEN" vault vault policy read bot-policy
```

**Rollback:**
```bash
docker exec -e VAULT_TOKEN="$ROOT_TOKEN" vault vault policy delete bot-policy
```

---

### Step 4: Create External Readonly Policy

**Objective:** Create restricted policy for external users

**Execute:**

```bash
# Create external readonly policy
cat > /home/jimmyb/vault/policies/external-readonly.hcl << 'EOF'
# External Readonly Policy - Limited API Access
# Created: 2025-10-18
# Assigned to: External researchers/partners

# Read access to specific API tokens
path "secret/data/api-tokens/*" {
  capabilities = ["read"]
}

# Token self-introspection
path "auth/token/lookup-self" {
  capabilities = ["read"]
}

# Deny all other access
path "*" {
  capabilities = ["deny"]
}
EOF

# Copy to container
docker cp /home/jimmyb/vault/policies/external-readonly.hcl vault:/vault/policies/

# Write policy to Vault
docker exec -e VAULT_TOKEN="$ROOT_TOKEN" vault \
  vault policy write external-readonly /vault/policies/external-readonly.hcl
```

**GREEN Validation:**
- [ ] Policy created
- [ ] Total of 3 custom policies + default policies

**Verification:**
```bash
docker exec -e VAULT_TOKEN="$ROOT_TOKEN" vault vault policy list
# Should show: admin-policy, bot-policy, default, external-readonly, root
```

**Rollback:**
```bash
docker exec -e VAULT_TOKEN="$ROOT_TOKEN" vault vault policy delete external-readonly
```

---

### Step 5: Enable Userpass Authentication

**Objective:** Enable username/password authentication method

**5-Question Guidance:**
- Q1. INTENT: Enable userpass for web app users (future)
- Q2. DATA: vault auth enable userpass command
- Q3. SAFETY: Just enabling auth method, no users created yet, safe
- Q4. OPTIMIZATION: Single command, configure TTLs
- Q5. TOOL: vault auth enable

**Execute:**

```bash
# Enable userpass authentication
docker exec -e VAULT_TOKEN="$ROOT_TOKEN" vault \
  vault auth enable userpass

# Configure default TTLs (32 days)
docker exec -e VAULT_TOKEN="$ROOT_TOKEN" vault \
  vault write auth/userpass/config \
    default_lease_ttl=768h \
    max_lease_ttl=768h
```

**GREEN Validation:**
- [ ] Userpass auth enabled
- [ ] Appears in `auth list`
- [ ] Configuration set correctly

**Verification:**
```bash
docker exec -e VAULT_TOKEN="$ROOT_TOKEN" vault vault auth list
docker exec -e VAULT_TOKEN="$ROOT_TOKEN" vault vault read auth/userpass/config
```

**Expected Output:**
```
Path         Type        Description
----         ----        -----------
token/       token       token based credentials
userpass/    userpass    n/a
```

**Rollback:**
```bash
docker exec -e VAULT_TOKEN="$ROOT_TOKEN" vault vault auth disable userpass
```

---

### Step 6: Create Test User

**Objective:** Create test user to validate authentication and policies

**Execute:**

```bash
# Create test user with admin-policy
docker exec -e VAULT_TOKEN="$ROOT_TOKEN" vault \
  vault write auth/userpass/users/testuser \
    password="test-password-change-later" \
    policies="admin-policy"

# Verify user created
docker exec -e VAULT_TOKEN="$ROOT_TOKEN" vault \
  vault list auth/userpass/users
```

**GREEN Validation:**
- [ ] User created successfully
- [ ] User appears in user list
- [ ] User has admin-policy attached

**Verification:**
```bash
docker exec -e VAULT_TOKEN="$ROOT_TOKEN" vault vault read auth/userpass/users/testuser
```

**Rollback:**
```bash
docker exec -e VAULT_TOKEN="$ROOT_TOKEN" vault \
  vault delete auth/userpass/users/testuser
```

---

### Step 7: Test Authentication

**Objective:** Validate userpass login works and returns token

**Execute:**

```bash
# Test login as testuser
TEST_LOGIN=$(docker exec vault vault login \
  -method=userpass \
  -token-only \
  username=testuser \
  password=test-password-change-later)

echo "Test user token: $TEST_LOGIN"

# Verify token is valid and has correct policies
docker exec -e VAULT_TOKEN="$TEST_LOGIN" vault \
  vault token lookup
```

**GREEN Validation:**
- [ ] Login succeeded
- [ ] Token generated
- [ ] Token has admin-policy attached
- [ ] Token can perform self-lookup

**Verification:**
```bash
# Should show token metadata including policies: ["admin-policy"]
docker exec -e VAULT_TOKEN="$TEST_LOGIN" vault vault token lookup
```

**Rollback:**
```bash
# Revoke test token
docker exec -e VAULT_TOKEN="$TEST_LOGIN" vault vault token revoke -self
```

---

### Step 8: Create Test Secrets

**Objective:** Store test secrets in hierarchy to validate storage

**Execute:**

```bash
# Use root token for initial secret creation
ROOT_TOKEN="<from-password-manager>"

# Create test Cardano testnet signing key
docker exec -e VAULT_TOKEN="$ROOT_TOKEN" vault \
  vault kv put secret/cardano/testnet/signing-key \
    key="ed25519_sk_test_1234567890abcdef_test_key_do_not_use" \
    created_date="2025-10-18" \
    purpose="Phase 2 validation test"

# Create test Maestro API key
docker exec -e VAULT_TOKEN="$ROOT_TOKEN" vault \
  vault kv put secret/cardano/testnet/maestro-api-key \
    api_key="test-maestro-key-12345" \
    network="testnet" \
    created_date="2025-10-18"

# Create test API token
docker exec -e VAULT_TOKEN="$ROOT_TOKEN" vault \
  vault kv put secret/api-tokens/test-user-token \
    token="test-token-abcdef" \
    user="test-researcher" \
    granted_date="2025-10-18" \
    expires="2025-11-18"

# Create test config
docker exec -e VAULT_TOKEN="$ROOT_TOKEN" vault \
  vault kv put secret/config/test-config \
    setting1="value1" \
    setting2="value2"
```

**GREEN Validation:**
- [ ] All 4 secrets created successfully
- [ ] Secrets readable with root token
- [ ] Secrets organized in correct hierarchy
- [ ] Metadata stored correctly

**Verification:**
```bash
# List all secret paths
docker exec -e VAULT_TOKEN="$ROOT_TOKEN" vault vault kv list secret/

# List cardano secrets
docker exec -e VAULT_TOKEN="$ROOT_TOKEN" vault vault kv list secret/cardano/testnet

# Read one secret to verify structure
docker exec -e VAULT_TOKEN="$ROOT_TOKEN" vault vault kv get secret/cardano/testnet/signing-key
```

**Rollback:**
```bash
# Delete all test secrets
docker exec -e VAULT_TOKEN="$ROOT_TOKEN" vault vault kv delete secret/cardano/testnet/signing-key
docker exec -e VAULT_TOKEN="$ROOT_TOKEN" vault vault kv delete secret/cardano/testnet/maestro-api-key
docker exec -e VAULT_TOKEN="$ROOT_TOKEN" vault vault kv delete secret/api-tokens/test-user-token
docker exec -e VAULT_TOKEN="$ROOT_TOKEN" vault vault kv delete secret/config/test-config
```

---

### Step 9: Test Bot Policy Enforcement

**Objective:** Validate bot-policy only allows reading cardano/* secrets

**Execute:**

```bash
# Create token with bot-policy
BOT_TOKEN=$(docker exec -e VAULT_TOKEN="$ROOT_TOKEN" vault \
  vault token create \
    -policy=bot-policy \
    -ttl=24h \
    -format=json | jq -r .auth.client_token)

echo "Bot token: $BOT_TOKEN"

# TEST 1: Bot CAN read cardano secrets (should succeed)
docker exec -e VAULT_TOKEN="$BOT_TOKEN" vault \
  vault kv get secret/cardano/testnet/signing-key

# TEST 2: Bot CANNOT read api-tokens (should fail with permission denied)
docker exec -e VAULT_TOKEN="$BOT_TOKEN" vault \
  vault kv get secret/api-tokens/test-user-token 2>&1 || echo "Expected: Permission denied ✓"

# TEST 3: Bot CANNOT write secrets (should fail)
docker exec -e VAULT_TOKEN="$BOT_TOKEN" vault \
  vault kv put secret/cardano/testnet/hacker-attempt value=bad 2>&1 || echo "Expected: Permission denied ✓"
```

**GREEN Validation:**
- [ ] Bot token created with bot-policy
- [ ] TEST 1 succeeds (can read cardano/*)
- [ ] TEST 2 fails with permission denied (cannot read api-tokens/*)
- [ ] TEST 3 fails with permission denied (cannot write)
- [ ] Policy enforcement working correctly

**Verification:**
```bash
# Verify token has correct policy
docker exec -e VAULT_TOKEN="$BOT_TOKEN" vault vault token lookup
# Should show: policies = ["bot-policy"]
```

**Rollback:**
```bash
# Revoke bot token
docker exec -e VAULT_TOKEN="$BOT_TOKEN" vault vault token revoke -self
```

---

### Step 10: Test External Readonly Policy

**Objective:** Validate external-readonly policy restricts access properly

**Execute:**

```bash
# Create token with external-readonly policy
EXTERNAL_TOKEN=$(docker exec -e VAULT_TOKEN="$ROOT_TOKEN" vault \
  vault token create \
    -policy=external-readonly \
    -ttl=30d \
    -format=json | jq -r .auth.client_token)

echo "External token: $EXTERNAL_TOKEN"

# TEST 1: External CAN read api-tokens (should succeed)
docker exec -e VAULT_TOKEN="$EXTERNAL_TOKEN" vault \
  vault kv get secret/api-tokens/test-user-token

# TEST 2: External CANNOT read cardano secrets (should fail)
docker exec -e VAULT_TOKEN="$EXTERNAL_TOKEN" vault \
  vault kv get secret/cardano/testnet/signing-key 2>&1 || echo "Expected: Permission denied ✓"

# TEST 3: External CANNOT write (should fail)
docker exec -e VAULT_TOKEN="$EXTERNAL_TOKEN" vault \
  vault kv put secret/api-tokens/hacker value=bad 2>&1 || echo "Expected: Permission denied ✓"
```

**GREEN Validation:**
- [ ] External token created
- [ ] TEST 1 succeeds (can read api-tokens/*)
- [ ] TEST 2 fails (cannot read cardano/*)
- [ ] TEST 3 fails (cannot write)
- [ ] Policy isolation working

**Verification:**
```bash
docker exec -e VAULT_TOKEN="$EXTERNAL_TOKEN" vault vault token lookup
```

**Rollback:**
```bash
docker exec -e VAULT_TOKEN="$EXTERNAL_TOKEN" vault vault token revoke -self
```

---

### Step 11: Create Policy Management Script

**Objective:** Helper script for policy operations

**Execute:**

```bash
cat > /home/jimmyb/vault/manage-policies.sh << 'EOF'
#!/bin/bash
# Vault Policy Management Script
# Usage: ./manage-policies.sh [list|read|write|delete] [policy-name]

set -e

COMMAND=$1
POLICY_NAME=$2

if [ -z "$VAULT_TOKEN" ]; then
  echo "Error: VAULT_TOKEN environment variable not set"
  exit 1
fi

case $COMMAND in
  list)
    docker exec -e VAULT_TOKEN="$VAULT_TOKEN" vault vault policy list
    ;;
  read)
    if [ -z "$POLICY_NAME" ]; then
      echo "Usage: $0 read <policy-name>"
      exit 1
    fi
    docker exec -e VAULT_TOKEN="$VAULT_TOKEN" vault vault policy read "$POLICY_NAME"
    ;;
  write)
    if [ -z "$POLICY_NAME" ]; then
      echo "Usage: $0 write <policy-name>"
      exit 1
    fi
    if [ ! -f "/home/jimmyb/vault/policies/$POLICY_NAME.hcl" ]; then
      echo "Error: Policy file not found: /home/jimmyb/vault/policies/$POLICY_NAME.hcl"
      exit 1
    fi
    docker cp "/home/jimmyb/vault/policies/$POLICY_NAME.hcl" vault:/vault/policies/
    docker exec -e VAULT_TOKEN="$VAULT_TOKEN" vault \
      vault policy write "$POLICY_NAME" "/vault/policies/$POLICY_NAME.hcl"
    ;;
  delete)
    if [ -z "$POLICY_NAME" ]; then
      echo "Usage: $0 delete <policy-name>"
      exit 1
    fi
    docker exec -e VAULT_TOKEN="$VAULT_TOKEN" vault vault policy delete "$POLICY_NAME"
    ;;
  *)
    echo "Usage: $0 [list|read|write|delete] [policy-name]"
    exit 1
    ;;
esac
EOF

chmod +x /home/jimmyb/vault/manage-policies.sh
```

**GREEN Validation:**
- [ ] Script created and executable
- [ ] Script lists policies correctly
- [ ] Script reads policies correctly

**Verification:**
```bash
# Test script
VAULT_TOKEN="$ROOT_TOKEN" /home/jimmyb/vault/manage-policies.sh list
VAULT_TOKEN="$ROOT_TOKEN" /home/jimmyb/vault/manage-policies.sh read admin-policy
```

**Rollback:**
```bash
rm /home/jimmyb/vault/manage-policies.sh
```

---

### Step 12: Create Token Management Script

**Objective:** Helper script for token creation and management

**Execute:**

```bash
cat > /home/jimmyb/vault/create-token.sh << 'EOF'
#!/bin/bash
# Vault Token Creation Script
# Usage: ./create-token.sh <policy-name> <ttl> [display-name]

set -e

POLICY=$1
TTL=$2
DISPLAY_NAME=${3:-"unnamed-token"}

if [ -z "$VAULT_TOKEN" ]; then
  echo "Error: VAULT_TOKEN environment variable not set"
  exit 1
fi

if [ -z "$POLICY" ] || [ -z "$TTL" ]; then
  echo "Usage: $0 <policy-name> <ttl> [display-name]"
  echo "Example: $0 bot-policy 24h trading-bot-dev"
  exit 1
fi

echo "Creating token with policy: $POLICY, TTL: $TTL, Name: $DISPLAY_NAME"

docker exec -e VAULT_TOKEN="$VAULT_TOKEN" vault \
  vault token create \
    -policy="$POLICY" \
    -ttl="$TTL" \
    -display-name="$DISPLAY_NAME" \
    -format=json | jq .

echo ""
echo "Token created successfully. Store securely!"
EOF

chmod +x /home/jimmyb/vault/create-token.sh
```

**GREEN Validation:**
- [ ] Script created and executable
- [ ] Script creates tokens with correct policies
- [ ] JSON output is well-formatted

**Verification:**
```bash
# Test token creation
VAULT_TOKEN="$ROOT_TOKEN" /home/jimmyb/vault/create-token.sh bot-policy 1h test-bot
```

**Rollback:**
```bash
rm /home/jimmyb/vault/create-token.sh
```

---

## Final Validation (Beast GREEN Phase)

**After all steps complete, run comprehensive validation:**

```bash
echo "=== PHASE 2 SECRETS & POLICIES - FINAL VALIDATION ==="

# 1. Secrets engine enabled
echo "1. Secrets Engine:"
docker exec -e VAULT_TOKEN="$ROOT_TOKEN" vault vault secrets list

# 2. Policies created
echo "2. Policies:"
docker exec -e VAULT_TOKEN="$ROOT_TOKEN" vault vault policy list

# 3. Authentication enabled
echo "3. Authentication Methods:"
docker exec -e VAULT_TOKEN="$ROOT_TOKEN" vault vault auth list

# 4. Test secrets stored
echo "4. Secret Paths:"
docker exec -e VAULT_TOKEN="$ROOT_TOKEN" vault vault kv list secret/
docker exec -e VAULT_TOKEN="$ROOT_TOKEN" vault vault kv list secret/cardano/testnet

# 5. Policy enforcement (create test tokens and verify access)
echo "5. Policy Enforcement Test:"
BOT_TOKEN=$(docker exec -e VAULT_TOKEN="$ROOT_TOKEN" vault vault token create -policy=bot-policy -ttl=5m -format=json | jq -r .auth.client_token)
echo "  Bot can read cardano:"
docker exec -e VAULT_TOKEN="$BOT_TOKEN" vault vault kv get secret/cardano/testnet/signing-key > /dev/null && echo "  ✅ Success" || echo "  ❌ Failed"
echo "  Bot cannot read api-tokens:"
docker exec -e VAULT_TOKEN="$BOT_TOKEN" vault vault kv get secret/api-tokens/test-user-token 2>&1 | grep -q "permission denied" && echo "  ✅ Correctly denied" || echo "  ❌ Should be denied"

# 6. Management scripts
echo "6. Management Scripts:"
ls -la /home/jimmyb/vault/*.sh

echo ""
echo "=== VALIDATION COMPLETE ==="
```

**All checks must pass:**
- ✅ KV v2 secrets engine enabled at secret/
- ✅ Three policies created (admin, bot, external)
- ✅ Userpass authentication enabled
- ✅ Test user created and can authenticate
- ✅ Test secrets stored in hierarchy
- ✅ Bot policy allows cardano/* read, denies others
- ✅ External policy allows api-tokens/* read, denies others
- ✅ Management scripts functional

---

## Chromebook GREEN Phase Validation

**Chromebook will verify (without SSH - based on Beast's report):**

1. Review policy HCL files (committed to GitHub)
2. Review management scripts (committed to GitHub)
3. Verify validation results from Beast's report
4. Confirm policy enforcement tests passed
5. Approve CHECKPOINT or request iteration

---

## Version Control Artifacts

**After successful deployment, commit to GitHub:**

```bash
# Navigate to dev-vault repo
cd /home/jimmyb/dev-vault

# Copy policy files to repo
mkdir -p deployment/policies
cp /home/jimmyb/vault/policies/*.hcl deployment/policies/

# Copy management scripts to repo
cp /home/jimmyb/vault/manage-policies.sh deployment/
cp /home/jimmyb/vault/create-token.sh deployment/

# Create deployment record
cat > docs/checkpoints/PHASE-2-DEPLOYMENT-RECORD.md << 'RECORD_EOF'
# Phase 2 Secrets & Policies Deployment Record

**Date:** 2025-10-18
**Executor:** Beast (Haiku 4.5)
**Status:** ✅ COMPLETE
**Deployment ID:** phase-2-secrets-policies

## What Was Configured

**Secrets Engine:**
- KV v2 enabled at secret/ path
- Version 2 (includes versioning, soft delete)

**Policies Created:**
1. admin-policy - Full access (3 paths)
2. bot-policy - Cardano read-only (2 paths)
3. external-readonly - API tokens read-only (1 path)

**Authentication:**
- Userpass enabled
- Default TTL: 768h (32 days)
- Test user created: testuser

**Test Secrets:**
- secret/cardano/testnet/signing-key
- secret/cardano/testnet/maestro-api-key
- secret/api-tokens/test-user-token
- secret/config/test-config

**Management Scripts:**
- manage-policies.sh - Policy CRUD operations
- create-token.sh - Token creation helper

## Validation Results

[Include actual validation output from Step 12]

## Policy Enforcement Tests

[Include results from bot-policy and external-readonly tests]

## Next Actions

- ⚪ Replace test secrets with real Cardano keys (when ready)
- ⚪ Create real users for trading bot and external researchers
- ⚪ Revoke root token (use admin user token instead)
- ⚪ Setup backup automation
- ⚪ Phase 3 planning

---

**Record Created:** [timestamp]
**Deployment Status:** READY FOR CHROMEBOOK VALIDATION
RECORD_EOF

# Stage all changes
git add deployment/policies/ deployment/*.sh docs/checkpoints/PHASE-2-DEPLOYMENT-RECORD.md

# Commit
git commit -m "deploy: Phase 2 secrets engine and policies configuration

Configured Vault for secret storage and access control:
- KV v2 secrets engine enabled
- Three policies created (admin, bot, external)
- Userpass authentication configured
- Test secrets stored and validated
- Policy enforcement tested and working
- Management scripts created

Status: Vault ready for production secret storage
Next: Chromebook GREEN validation and CHECKPOINT

Co-Authored-By: Beast <beast@dev-lab>"

# Push to GitHub
git push origin main
```

---

## Success Criteria

**Phase 2 is successful when:**

- ✅ KV v2 secrets engine enabled and operational
- ✅ Three policies created and uploaded
- ✅ Userpass authentication enabled
- ✅ Test user can authenticate
- ✅ Test secrets stored in correct hierarchy
- ✅ Bot policy enforcement validated (read cardano/*, deny others)
- ✅ External policy enforcement validated (read api-tokens/*, deny others)
- ✅ Management scripts functional
- ✅ All artifacts version controlled in GitHub
- ✅ No security issues
- ✅ All GREEN validation checks pass

---

## Security Considerations

### Root Token Usage
**After Phase 2 completes:**
- Root token should be REVOKED
- Use admin user token for future operations
- Only regenerate root token in emergencies

### Test Secrets
- All secrets created in Phase 2 are TEST DATA
- Replace with real secrets in Phase 3 or as needed
- Test secrets clearly marked with "test" prefix

### Token Lifecycle
- Bot token: 24h TTL (short-lived for testing)
- External token: 30d TTL (reasonable for API access)
- Admin token: 32d TTL (from userpass config)

---

## Post-Deployment Operations

### Create New Token (After Phase 2)
```bash
# Export your admin token (from login, not root)
export VAULT_TOKEN="<admin-user-token>"

# Create bot token
/home/jimmyb/vault/create-token.sh bot-policy 7d production-bot

# Create external user token
/home/jimmyb/vault/create-token.sh external-readonly 30d researcher-alice
```

### Store New Secret
```bash
# With admin token
export VAULT_TOKEN="<admin-token>"

docker exec -e VAULT_TOKEN="$VAULT_TOKEN" vault \
  vault kv put secret/cardano/mainnet/signing-key \
    key="<real-signing-key>" \
    created_date="$(date +%Y-%m-%d)"
```

### Read Secret (As Bot)
```bash
# With bot token
export VAULT_TOKEN="<bot-token>"

docker exec -e VAULT_TOKEN="$VAULT_TOKEN" vault \
  vault kv get -field=key secret/cardano/testnet/signing-key
```

---

## Complete Rollback Procedure

**If Phase 2 needs complete rollback:**

```bash
# Revoke all test tokens
docker exec -e VAULT_TOKEN="$ROOT_TOKEN" vault vault token revoke -accessor <accessor-id>

# Delete all policies
docker exec -e VAULT_TOKEN="$ROOT_TOKEN" vault vault policy delete admin-policy
docker exec -e VAULT_TOKEN="$ROOT_TOKEN" vault vault policy delete bot-policy
docker exec -e VAULT_TOKEN="$ROOT_TOKEN" vault vault policy delete external-readonly

# Disable userpass
docker exec -e VAULT_TOKEN="$ROOT_TOKEN" vault vault auth disable userpass

# Delete all test secrets
docker exec -e VAULT_TOKEN="$ROOT_TOKEN" vault vault kv delete secret/cardano/testnet/signing-key
docker exec -e VAULT_TOKEN="$ROOT_TOKEN" vault vault kv delete secret/cardano/testnet/maestro-api-key
docker exec -e VAULT_TOKEN="$ROOT_TOKEN" vault vault kv delete secret/api-tokens/test-user-token
docker exec -e VAULT_TOKEN="$ROOT_TOKEN" vault vault kv delete secret/config/test-config

# Disable secrets engine
docker exec -e VAULT_TOKEN="$ROOT_TOKEN" vault vault secrets disable secret/

# Remove scripts and policies
rm -rf /home/jimmyb/vault/policies
rm /home/jimmyb/vault/manage-policies.sh
rm /home/jimmyb/vault/create-token.sh

# Vault returns to Phase 1 state (container running, unsealed, but unconfigured)
```

---

## References

**Research Documents:**
- devlab-vault-architecture.md: Lines 1129-1150 (Phase 1 configuration)
- devlab-vault-architecture.md: Lines 280-337 (Secret hierarchies)
- devlab-vault-architecture.md: Lines 396-458 (Policy examples)

**Phase 1 Deployment:**
- docs/checkpoints/PHASE-1-DEPLOYMENT-RECORD.md
- docs/checkpoints/PHASE-1-CHECKPOINT-APPROVAL.md

**Specialist Context:**
- docs/specs/BEAST-SPECIALIST-CONTEXT.md (Jimmy's Workflow foundation)

---

## Notes for Beast

**This is your second deployment following the Haiku 4.5 + Jimmy's Workflow pattern.**

**Remember:**
- Apply 5-question thinking to EVERY step (12 steps this time)
- Execute RED → GREEN → CHECKPOINT for EVERY step
- Test policy enforcement thoroughly (Steps 9-10 are critical)
- Validate before reporting success
- Commit artifacts to GitHub when done
- Be honest about any issues

**Focus areas:**
- **Security:** Policy enforcement must work perfectly
- **Testing:** Validate that denials actually deny
- **Documentation:** Clear validation results

**You've proven the pattern in Phase 1. Phase 2 builds on that success.**

---

**Execution Spec Version:** 1.0
**Created:** 2025-10-18
**Status:** Ready for Beast execution
**Expected Duration:** 2-3 hours
**Foundation:** Jimmy's Workflow (Mandatory)
