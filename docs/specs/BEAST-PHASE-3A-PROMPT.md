# Beast Deployment Prompt: Phase 3A Container Integration

**Copy and paste this entire prompt into Claude Code CLI on Beast**

---

You are Claude Haiku 4.5, the **Beast Specialist** executor agent in Jimmy's three-machine development infrastructure. You are running on **Beast** (192.168.68.100), the high-performance Docker deployment machine.

## 🎯 Mission: Phase 3A - Container Integration with AppRole

**Your Role:** Execute deployment spec with precision and validation
**Pattern:** Pattern 1 (Pre-Start Script - Simplest)
**Estimated Time:** 45-60 minutes
**Start Time:** 2025-10-21

---

## 📋 Context: What's Already Deployed

**Vault Infrastructure (YOU deployed this in Phase 1-2):**
- ✅ Vault v1.15.6 running on Beast:8200
- ✅ KV v2 secrets engine at `secret/` path
- ✅ Userpass authentication enabled
- ✅ 3 policies: admin, bot, external-readonly
- ✅ Health monitoring and audit logging functional

**Your Previous Success:**
- Phase 1: 10 minutes, zero issues
- Phase 2: 25 minutes, zero issues
- Total: 35 minutes execution time, 100% workflow compliance

**This Phase Goal:**
Enable containers/apps on Beast to fetch secrets from Vault using AppRole authentication with a simple pre-start script pattern.

---

## 📖 Execution Spec Location

**PRIMARY SPEC:** `/home/jamesb/dev-vault/docs/specs/PHASE-3A-CONTAINER-INTEGRATION.md`

**READ THIS SPEC FIRST** - It contains:
- All implementation steps (Step 1-10)
- Exact commands to run
- File contents to create
- Validation criteria
- Rollback procedures

---

## 🔧 Your Execution Workflow

### MANDATORY: Use Jimmy's Workflow

**🔴 RED (IMPLEMENT):**
1. Read the execution spec completely
2. Execute each step sequentially
3. Verify each step before proceeding
4. Document any deviations

**🟢 GREEN (VALIDATE):**
1. Run all 6 validation tests (in spec)
2. Verify policy enforcement works
3. Test end-to-end Docker integration
4. Confirm zero security issues

**🔵 CHECKPOINT:**
1. Create deployment record in docs/checkpoints/
2. Document actual execution time
3. List any issues encountered
4. Commit all artifacts to git

---

## 🚦 Pre-Flight Checks (RUN THESE FIRST!)

```bash
# 1. Verify Vault is running
curl -s http://192.168.68.100:8200/v1/sys/health | jq .

# 2. Set Vault environment
export VAULT_ADDR="http://192.168.68.100:8200"

# 3. Login to Vault (use root token or admin token from Phase 1)
vault login
# Enter token when prompted

# 4. Verify current auth methods
vault auth list

# 5. Verify KV v2 engine exists
vault secrets list | grep secret/

# 6. Navigate to project directory
cd ~/dev-vault

# 7. Pull latest spec from GitHub
git pull origin main

# 8. Verify spec exists
ls -lah docs/specs/PHASE-3A-CONTAINER-INTEGRATION.md
```

**ONLY PROCEED IF ALL CHECKS PASS!**

---

## 📝 Step-by-Step Execution Guide

### Step 1: Enable AppRole Authentication

```bash
# Enable AppRole
vault auth enable approle

# Verify
vault auth list | grep approle
```

**Expected:** `approle/` appears in auth methods list

---

### Step 2: Create Example App Policy

```bash
# Create policy file
cat > deployment/policies/app-example.hcl <<'EOF'
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
EOF

# Apply policy
vault policy write app-example deployment/policies/app-example.hcl

# Verify
vault policy read app-example
```

**Expected:** Policy content displayed without errors

---

### Step 3: Create AppRole for Example App

```bash
# Create AppRole role
vault write auth/approle/role/example-app \
    token_ttl=1h \
    token_max_ttl=24h \
    policies="app-example" \
    bind_secret_id=true

# Get Role ID and Secret ID
ROLE_ID=$(vault read -field=role_id auth/approle/role/example-app/role-id)
SECRET_ID=$(vault write -f -field=secret_id auth/approle/role/example-app/secret-id)

# Display for documentation (you'll need these for testing)
echo "ROLE_ID: $ROLE_ID"
echo "SECRET_ID: $SECRET_ID"

# Save to temporary file for testing
cat > /tmp/vault-approle-creds.env <<EOF
export VAULT_ROLE_ID="$ROLE_ID"
export VAULT_SECRET_ID="$SECRET_ID"
EOF

echo "Credentials saved to /tmp/vault-approle-creds.env for testing"
```

**Expected:** Role ID and Secret ID displayed

---

### Step 4: Create Test Secrets

```bash
# Create database credentials
vault kv put secret/apps/example/database \
    host="postgres.example.com" \
    port="5432" \
    username="appuser" \
    password="test-password-change-in-production"

# Create API keys
vault kv put secret/apps/example/api-keys \
    stripe_key="sk_test_example_key" \
    sendgrid_key="SG.example_key" \
    supabase_url="https://example.supabase.co" \
    supabase_anon_key="eyJ_example_key"

# Verify
vault kv list secret/apps/example/
vault kv get secret/apps/example/database
```

**Expected:** Secrets created and readable

---

### Step 5: Create fetch-secrets.sh Script

**READ THE SPEC** - Copy the complete script from PHASE-3A-CONTAINER-INTEGRATION.md Step 5

```bash
# Create scripts directory
mkdir -p deployment/scripts

# Create the script (use the complete version from spec!)
cat > deployment/scripts/fetch-secrets.sh <<'SCRIPT_EOF'
[COPY COMPLETE SCRIPT FROM SPEC - It's ~150 lines]
SCRIPT_EOF

# Set executable permission
chmod +x deployment/scripts/fetch-secrets.sh

# Verify
ls -lah deployment/scripts/fetch-secrets.sh
head -20 deployment/scripts/fetch-secrets.sh
```

**Expected:** Script created and executable

---

### Step 6: Create Docker Example Files

```bash
# Create examples directory
mkdir -p deployment/examples/example-app

# Create docker-compose.yml (copy from spec Step 6)
cat > deployment/examples/docker-compose-pattern1.yml <<'COMPOSE_EOF'
[COPY FROM SPEC]
COMPOSE_EOF

# Create example app server.js (copy from spec Step 7)
cat > deployment/examples/example-app/server.js <<'JS_EOF'
[COPY FROM SPEC]
JS_EOF

# Create package.json (copy from spec Step 7)
cat > deployment/examples/example-app/package.json <<'PKG_EOF'
[COPY FROM SPEC]
PKG_EOF

# Install dependencies
cd deployment/examples/example-app
npm install
cd ~/dev-vault
```

**Expected:** All example files created

---

### Step 7: CLI Test (Direct Script Execution)

```bash
# Source the credentials
source /tmp/vault-approle-creds.env

# Set additional required vars
export VAULT_ADDR="http://192.168.68.100:8200"
export VAULT_SECRET_PATH="secret/data/apps/example/database"

# Test all output formats
echo "=== Testing ENV format ==="
./deployment/scripts/fetch-secrets.sh env

echo "=== Testing JSON format ==="
./deployment/scripts/fetch-secrets.sh json

echo "=== Testing EXPORT format ==="
./deployment/scripts/fetch-secrets.sh export
```

**Expected:** Database credentials output in all three formats

---

### Step 8: Docker Container Test

```bash
cd deployment/examples

# Create .env file for docker-compose
cat > .env <<EOF
VAULT_ROLE_ID=$ROLE_ID
VAULT_SECRET_ID=$SECRET_ID
EOF

# Start container
docker-compose -f docker-compose-pattern1.yml up -d

# Check logs
docker logs vault-example-app

# Should see:
# - "Fetching secrets from Vault"
# - "Secrets loaded, starting application"
# - "✅ Success! Secrets loaded from Vault"

# Clean up
docker-compose -f docker-compose-pattern1.yml down
```

**Expected:** Container starts successfully and loads secrets

---

### Step 9: Policy Enforcement Test

```bash
# Try to access unauthorized path (should fail)
export VAULT_SECRET_PATH="secret/data/cardano/testnet/signing-key"
./deployment/scripts/fetch-secrets.sh env

# Expected: Permission denied error
# This confirms policy enforcement is working!
```

**Expected:** Permission denied (this is GOOD!)

---

### Step 10: Create Usage Documentation

```bash
# Create Pattern 1 usage guide (copy complete content from spec Step 9)
cat > deployment/examples/PATTERN1-USAGE.md <<'DOC_EOF'
[COPY COMPLETE MARKDOWN FROM SPEC]
DOC_EOF

# Verify
wc -l deployment/examples/PATTERN1-USAGE.md
```

**Expected:** Documentation file created

---

## ✅ GREEN Phase: Validation Tests

**Run ALL 6 tests from the spec:**

### Test 1: AppRole Enabled
```bash
vault auth list | grep approle
# ✅ Expected: approle/ present
```

### Test 2: Policy Created
```bash
vault policy read app-example
# ✅ Expected: Policy content displayed
```

### Test 3: Authentication Works
```bash
source /tmp/vault-approle-creds.env
curl -s --request POST \
    --data "{\"role_id\":\"${VAULT_ROLE_ID}\",\"secret_id\":\"${VAULT_SECRET_ID}\"}" \
    http://192.168.68.100:8200/v1/auth/approle/login | jq .auth.client_token
# ✅ Expected: Valid token returned
```

### Test 4: Script Fetches Secrets
```bash
export VAULT_SECRET_PATH="secret/data/apps/example/database"
./deployment/scripts/fetch-secrets.sh env | grep "host="
# ✅ Expected: Database credentials displayed
```

### Test 5: Docker Integration Works
```bash
cd deployment/examples
docker-compose -f docker-compose-pattern1.yml up -d
docker logs vault-example-app | grep "Success"
docker-compose down
# ✅ Expected: Success message found
```

### Test 6: Policy Enforcement
```bash
export VAULT_SECRET_PATH="secret/data/admin/root-key"
./deployment/scripts/fetch-secrets.sh env 2>&1 | grep -i "permission\|denied"
# ✅ Expected: Permission denied error
```

**ALL TESTS MUST PASS!**

---

## 🔵 CHECKPOINT Phase: Documentation

### Create Checkpoint Document

```bash
cat > docs/checkpoints/PHASE-3A-CHECKPOINT-APPROVAL.md <<'CHECKPOINT_EOF'
# Phase 3A Checkpoint: Container Integration - AppRole & Pattern 1

**Deployment Date:** 2025-10-21
**Executor:** Beast Specialist (Claude Haiku 4.5)
**Orchestrator Review:** Pending
**Status:** ✅ DEPLOYED / ⚠️ ISSUES / ❌ FAILED

---

## 🎯 Deployment Summary

**What Was Deployed:**
- AppRole authentication method enabled
- Example app policy (app-example) created
- Example AppRole (example-app) configured
- Test secrets created under secret/apps/example/
- fetch-secrets.sh script (Pattern 1)
- Docker Compose example with working integration
- Complete usage documentation

**Pattern Implemented:** Pattern 1 (Pre-Start Script)

**Execution Metrics:**
- Start Time: [INSERT TIME]
- End Time: [INSERT TIME]
- Total Duration: [INSERT MINUTES] minutes
- Target Duration: 45-60 minutes
- Issues Encountered: [NONE or LIST]

---

## ✅ Validation Results

### All 6 Tests Executed:
- [✅/❌] Test 1: AppRole authentication enabled
- [✅/❌] Test 2: app-example policy created
- [✅/❌] Test 3: AppRole can authenticate
- [✅/❌] Test 4: Script fetches secrets successfully
- [✅/❌] Test 5: Docker container integration works
- [✅/❌] Test 6: Policy enforcement prevents unauthorized access

### Security Validation:
- [✅/❌] Unauthorized access blocked by policy
- [✅/❌] Secret IDs have proper TTL (24h max)
- [✅/❌] Token TTL set correctly (1h)
- [✅/❌] Test secrets clearly marked as non-production

### Documentation:
- [✅/❌] PATTERN1-USAGE.md complete
- [✅/❌] Example docker-compose.yml functional
- [✅/❌] fetch-secrets.sh script documented
- [✅/❌] All files committed to git

---

## 📊 Deployment Artifacts

**Policies Created:**
- deployment/policies/app-example.hcl

**Scripts Created:**
- deployment/scripts/fetch-secrets.sh

**Examples Created:**
- deployment/examples/docker-compose-pattern1.yml
- deployment/examples/example-app/server.js
- deployment/examples/example-app/package.json
- deployment/examples/PATTERN1-USAGE.md

**Vault Configuration:**
- Auth method: approle enabled
- AppRole: example-app (token_ttl=1h, max_ttl=24h)
- Secrets path: secret/apps/example/*

**Credentials Generated:**
- Role ID: [DOCUMENTED IN PASSWORD MANAGER]
- Secret ID: [DOCUMENTED IN PASSWORD MANAGER]

---

## 🔄 Rollback Procedure

If issues are found during GREEN validation:

\`\`\`bash
# Stop test containers
cd ~/dev-vault/deployment/examples
docker-compose -f docker-compose-pattern1.yml down

# Delete test secrets
vault kv metadata delete secret/apps/example/database
vault kv metadata delete secret/apps/example/api-keys

# Delete AppRole
vault delete auth/approle/role/example-app

# Delete policy
vault policy delete app-example

# Disable AppRole (only if no other apps use it!)
# vault auth disable approle

# Remove files
git checkout HEAD -- deployment/
\`\`\`

**Rollback Testing:** [✅ TESTED / ⚪ NOT TESTED]

---

## 🐛 Issues Encountered

[NONE or list any issues, how they were resolved, time impact]

---

## 📝 Next Steps

**Immediate:**
- Orchestrator GREEN validation
- Update NEXT-SESSION-START-HERE.md
- Update README.md with Phase 3A completion

**Future Phases:**
- Phase 3B: Multi-User Access (external access, per-project policies)
- Phase 3C: Patterns 2 & 3 (Init Container, Vault Agent Sidecar)
- Phase 4: Production Hardening (real secrets, backup, monitoring)

---

## 📚 References

- Execution Spec: docs/specs/PHASE-3A-CONTAINER-INTEGRATION.md
- Vault AppRole Docs: https://www.vaultproject.io/docs/auth/approle
- Phase 1 Checkpoint: docs/checkpoints/PHASE-1-CHECKPOINT-APPROVAL.md
- Phase 2 Checkpoint: docs/checkpoints/PHASE-2-CHECKPOINT-APPROVAL.md

---

**Deployed By:** Beast Specialist (Haiku 4.5)
**Reviewed By:** [Orchestrator to fill]
**Approved By:** [Orchestrator to fill]
**Approval Date:** [Orchestrator to fill]

---

**Workflow Phase:** 🔵 CHECKPOINT (Awaiting GREEN validation from Orchestrator)
CHECKPOINT_EOF
```

---

## 📦 Git Commit

```bash
cd ~/dev-vault

# Stage all new files
git add deployment/policies/app-example.hcl
git add deployment/scripts/fetch-secrets.sh
git add deployment/examples/
git add docs/checkpoints/PHASE-3A-CHECKPOINT-APPROVAL.md

# Commit with descriptive message
git commit -m "deploy: Phase 3A container integration (AppRole + Pattern 1)

- Enable AppRole authentication method
- Create app-example policy and example-app role
- Add fetch-secrets.sh script for Pattern 1 integration
- Create Docker Compose example with working integration
- Add comprehensive usage documentation (PATTERN1-USAGE.md)
- Create test secrets under secret/apps/example/
- All 6 validation tests passed
- Execution time: [INSERT TIME] minutes
- Zero issues encountered

Pattern: Pre-Start Script (simplest, 15min setup for apps)
Security: Token TTL 1h, Max TTL 24h, policy-enforced access
Next: Orchestrator GREEN validation

🤖 Generated with Claude Code
Co-Authored-By: Claude <noreply@anthropic.com>"

# Push to GitHub
git push origin main

echo "✅ Phase 3A deployment complete and pushed to GitHub!"
echo "📋 Checkpoint document created at docs/checkpoints/PHASE-3A-CHECKPOINT-APPROVAL.md"
echo "⏰ Total execution time: [FILL IN] minutes"
```

---

## 🎯 Final Checklist

Before ending session, confirm:

- [ ] All 10 implementation steps completed
- [ ] All 6 GREEN validation tests passed
- [ ] Checkpoint document created and filled out
- [ ] All artifacts committed to git
- [ ] Changes pushed to GitHub
- [ ] Execution time documented
- [ ] Any issues documented with resolutions
- [ ] Rollback procedure tested (optional but recommended)

---

## 💬 Reporting Back

**When complete, create this summary for Orchestrator:**

```
Phase 3A Deployment Complete! ✅

Execution Time: [X] minutes (target: 45-60min)
Status: All tests passed

Deployed:
✅ AppRole authentication enabled
✅ app-example policy created
✅ example-app AppRole configured (1h TTL)
✅ fetch-secrets.sh script (3 output formats)
✅ Docker Compose example working
✅ Test secrets created
✅ Usage documentation complete

Validation: 6/6 tests passed
- AppRole auth functional
- Policy enforcement working
- Docker integration tested
- Security controls verified

Issues: [NONE or list]

Next: Awaiting Orchestrator GREEN review

Git: All changes committed and pushed to main
Checkpoint: docs/checkpoints/PHASE-3A-CHECKPOINT-APPROVAL.md
```

---

## 🚨 Important Reminders

1. **Read the complete spec first** before starting implementation
2. **Verify each step** before proceeding to the next
3. **Document any deviations** from the spec
4. **Run ALL validation tests** - don't skip any!
5. **Fill out checkpoint document** completely
6. **Commit and push** all artifacts to GitHub
7. **Time tracking** - record start/end times accurately
8. **Report any issues** - even small ones

---

## 🆘 If You Get Stuck

1. **Check the detailed spec** - PHASE-3A-CONTAINER-INTEGRATION.md has full instructions
2. **Verify Vault is running** - curl http://192.168.68.100:8200/v1/sys/health
3. **Check authentication** - vault status, vault token lookup
4. **Review logs** - docker logs vault (Vault container logs)
5. **Rollback if needed** - use rollback procedure from spec

---

**Ready to execute? Start with Pre-Flight Checks! 🚀**

**Estimated completion: 45-60 minutes**
**Your track record: 100% success rate on Phase 1-2**
**Let's make it 3 for 3! 💪**
