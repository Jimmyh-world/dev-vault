# SPEC: Phase 1 Minimal Vault Deployment

**Created:** 2025-10-18
**Status:** RED Phase (Ready for Beast execution)
**Estimated Effort:** 2-4 hours
**Complexity:** Medium
**Target Machine:** Beast (192.168.68.100)
**Foundation:** Jimmy's Workflow (MANDATORY)

---

## Executive Summary

Deploy a minimal, production-ready HashiCorp Vault instance on Beast following the "KISS + YAGNI" approach from devlab-vault-architecture.md Phase 1 (lines 1109-1188).

**What gets deployed:**
- Single Vault container (hashicorp/vault:1.15)
- File-based storage backend (simplest option)
- Single unseal key (one admin - you, Jimmy)
- Basic file audit logging
- Persistent Docker volumes
- Port 8200 (Vault API)

**What does NOT get deployed (future phases):**
- ❌ Multi-key Shamir unsealing (overkill for solo admin)
- ❌ High availability cluster (not needed yet)
- ❌ AppRole authentication (future)
- ❌ Dynamic secrets engines (future)
- ❌ Monitoring dashboards (future)

---

## Prerequisites

**Before Beast can execute this spec:**

### System Requirements
- [ ] Beast accessible via SSH: `ssh jimmyb@192.168.68.100`
- [ ] Docker installed and running: `docker --version`
- [ ] Docker Compose available: `docker compose version`
- [ ] Disk space > 20GB available: `df -h /`
- [ ] Port 8200 not in use: `netstat -tulpn | grep 8200`

### Network Requirements
- [ ] Beast on local network (192.168.68.100)
- [ ] Can reach from Chromebook for validation

### Knowledge Requirements
- [ ] Beast has read `docs/specs/BEAST-SPECIALIST-CONTEXT.md`
- [ ] Jimmy's Workflow understood and will be followed

---

## Deployment Architecture

```
Beast (192.168.68.100)
├── Docker Container: vault
│   ├── Image: hashicorp/vault:1.15
│   ├── Port: 8200:8200
│   └── Capabilities: IPC_LOCK (prevents memory swapping)
│
├── Docker Volumes
│   ├── vault-data → /vault/data (encrypted storage)
│   ├── vault-logs → /vault/logs (audit logs)
│   └── vault-config → /vault/config (server config)
│
└── Configuration
    └── /home/jimmyb/vault/config/vault.hcl
```

---

## Implementation Steps

**Beast:** Execute each step using Jimmy's Workflow (RED → GREEN → CHECKPOINT).

**For each step:**
1. Read the step objective
2. Apply 5-question thinking
3. Execute (RED phase)
4. Validate (GREEN phase)
5. Report (CHECKPOINT phase)

---

### Step 1: Create Vault Directory Structure

**Objective:** Prepare file system for Vault deployment

**5-Question Guidance:**
- Q1. INTENT: Create directories for config, data, and logs
- Q2. DATA: Need `/home/jimmyb/vault/{config,data,logs}`
- Q3. SAFETY: Just mkdir, very safe
- Q4. OPTIMIZATION: Create all at once with -p flag
- Q5. TOOL: Standard shell commands

**Execute:**

```bash
# Create vault directories
mkdir -p /home/jimmyb/vault/config
mkdir -p /home/jimmyb/vault/data
mkdir -p /home/jimmyb/vault/logs

# Set permissions (vault user in container is UID 100)
chmod 755 /home/jimmyb/vault/config
chmod 700 /home/jimmyb/vault/data
chmod 755 /home/jimmyb/vault/logs
```

**GREEN Validation Checklist:**
- [ ] `/home/jimmyb/vault/config` exists
- [ ] `/home/jimmyb/vault/data` exists (permissions 700)
- [ ] `/home/jimmyb/vault/logs` exists
- [ ] All owned by jimmyb:jimmyb

**Verification Commands:**
```bash
ls -la /home/jimmyb/vault/
tree /home/jimmyb/vault/ || ls -R /home/jimmyb/vault/
```

**Rollback:**
```bash
rm -rf /home/jimmyb/vault
```

---

### Step 2: Create Vault Server Configuration

**Objective:** Write vault.hcl configuration file

**5-Question Guidance:**
- Q1. INTENT: Configure file storage backend, TCP listener, audit log
- Q2. DATA: HCL syntax config at `/home/jimmyb/vault/config/vault.hcl`
- Q3. SAFETY: Just file creation, validate HCL syntax after
- Q4. OPTIMIZATION: Use heredoc for clean formatting
- Q5. TOOL: bash heredoc with cat

**Execute:**

```bash
cat > /home/jimmyb/vault/config/vault.hcl << 'EOF'
# Vault Server Configuration - Phase 1 Minimal Deployment
# Created: 2025-10-18
# Storage backend: File (simplest, no HA)

storage "file" {
  path = "/vault/data"
}

# API listener on all interfaces
listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_disable = 1  # TLS handled by external proxy (Cloudflare) in production
}

# API address for cluster communication
api_addr = "http://192.168.68.100:8200"

# Enable Vault UI for administration
ui = true

# Logging
log_level = "info"

# Disable mlock for container environments
# (IPC_LOCK capability provides memory protection instead)
disable_mlock = false
EOF
```

**GREEN Validation Checklist:**
- [ ] File exists at `/home/jimmyb/vault/config/vault.hcl`
- [ ] File is readable
- [ ] Contains storage, listener, api_addr sections
- [ ] No syntax errors (will be validated when Vault starts)

**Verification Commands:**
```bash
cat /home/jimmyb/vault/config/vault.hcl
ls -la /home/jimmyb/vault/config/vault.hcl
wc -l /home/jimmyb/vault/config/vault.hcl  # Should be ~25 lines
```

**Rollback:**
```bash
rm /home/jimmyb/vault/config/vault.hcl
```

---

### Step 3: Pull Vault Docker Image

**Objective:** Download official HashiCorp Vault image

**5-Question Guidance:**
- Q1. INTENT: Get vault:1.15 image from Docker Hub
- Q2. DATA: Image name `hashicorp/vault:1.15`
- Q3. SAFETY: Official image, just downloading, safe
- Q4. OPTIMIZATION: Pull before running to check for errors
- Q5. TOOL: docker pull

**Execute:**

```bash
docker pull hashicorp/vault:1.15
```

**GREEN Validation Checklist:**
- [ ] Image downloaded successfully
- [ ] Image appears in `docker images`
- [ ] Size is reasonable (~200-300MB)

**Verification Commands:**
```bash
docker images | grep vault
docker inspect hashicorp/vault:1.15 | grep -A3 "Created"
```

**Rollback:**
```bash
docker rmi hashicorp/vault:1.15
```

---

### Step 4: Deploy Vault Container

**Objective:** Start Vault container with proper configuration

**5-Question Guidance:**
- Q1. INTENT: Run Vault as persistent Docker container
- Q2. DATA: Config from step 2, port 8200, volumes mounted
- Q3. SAFETY: Check port 8200 free, use restart policy
- Q4. OPTIMIZATION: Mount config/data/logs, add IPC_LOCK capability
- Q5. TOOL: docker run with detailed flags

**IMPORTANT - Check port availability first:**

```bash
# Pre-flight check
netstat -tulpn | grep 8200
# Should return nothing (port free)
# If port in use, STOP and report conflict
```

**Execute:**

```bash
docker run -d \
  --name vault \
  --hostname vault \
  -p 8200:8200 \
  -v /home/jimmyb/vault/config:/vault/config:ro \
  -v /home/jimmyb/vault/data:/vault/data \
  -v /home/jimmyb/vault/logs:/vault/logs \
  --cap-add=IPC_LOCK \
  --restart unless-stopped \
  hashicorp/vault:1.15 \
  server
```

**GREEN Validation Checklist:**
- [ ] Container started successfully
- [ ] Container shows "Up" status
- [ ] Port 8200 is listening
- [ ] Vault responds to health check
- [ ] Logs show successful startup (no errors)
- [ ] Vault is in sealed state (expected)

**Verification Commands:**
```bash
# Check container running
docker ps | grep vault

# Check port listening
netstat -tulpn | grep 8200

# Check Vault health endpoint
curl http://localhost:8200/v1/sys/health
# Expected: JSON with "sealed": true, "initialized": false

# Check logs
docker logs vault | tail -20
# Should show "Vault server started" or similar

# Check resource usage
docker stats vault --no-stream
```

**Expected Health Response:**
```json
{
  "initialized": false,
  "sealed": true,
  "standby": false,
  "performance_standby": false,
  "replication_performance_mode": "disabled",
  "replication_dr_mode": "disabled",
  "server_time_utc": 1697461234,
  "version": "1.15.x",
  "cluster_name": "vault-cluster-xxxxx",
  "cluster_id": "xxxxx"
}
```

**Rollback:**
```bash
docker stop vault
docker rm vault
# Data and logs remain in /home/jimmyb/vault/ for investigation
```

---

### Step 5: Initialize Vault

**Objective:** Initialize Vault with single unseal key

**5-Question Guidance:**
- Q1. INTENT: Create root token and unseal key
- Q2. DATA: Use `vault operator init` with key-shares=1, key-threshold=1
- Q3. SAFETY: THIS GENERATES SECRETS - must be securely stored
- Q4. OPTIMIZATION: Redirect output to secure file immediately
- Q5. TOOL: docker exec with vault CLI

**CRITICAL:** This step generates secrets that MUST be saved securely!

**Execute:**

```bash
# Initialize Vault and save output securely
docker exec vault vault operator init \
  -key-shares=1 \
  -key-threshold=1 \
  > /home/jimmyb/vault/vault-init-keys.txt

# Set restrictive permissions immediately
chmod 600 /home/jimmyb/vault/vault-init-keys.txt
```

**GREEN Validation Checklist:**
- [ ] Initialization completed successfully
- [ ] File `/home/jimmyb/vault/vault-init-keys.txt` exists
- [ ] File permissions are 600 (readable only by owner)
- [ ] File contains "Unseal Key 1:" and "Initial Root Token:"
- [ ] Vault status shows initialized: true, sealed: true

**Verification Commands:**
```bash
# Check initialization file exists with correct permissions
ls -la /home/jimmyb/vault/vault-init-keys.txt

# Verify file contains keys (don't print full content - secrets!)
grep -c "Unseal Key" /home/jimmyb/vault/vault-init-keys.txt  # Should be 1
grep -c "Initial Root Token" /home/jimmyb/vault/vault-init-keys.txt  # Should be 1

# Check Vault status
docker exec vault vault status
# Expected: Initialized = true, Sealed = true
```

**Expected Status Output:**
```
Key                Value
---                -----
Seal Type          shamir
Initialized        true
Sealed             true
Total Shares       1
Threshold          1
Unseal Progress    0/1
Unseal Nonce       n/a
Version            1.15.x
Storage Type       file
HA Enabled         false
```

**Rollback:**
```bash
# If initialization fails, must destroy and recreate container
docker stop vault
docker rm vault
rm -rf /home/jimmyb/vault/data/*
# Then restart from Step 4
```

**SECURITY WARNING:**
```
⚠️  The file /home/jimmyb/vault/vault-init-keys.txt contains:
   - Unseal key (required to unseal Vault after restart)
   - Root token (god-mode access to Vault)

   This file MUST be backed up securely and then removed from the server
   after copying to a secure location (password manager, encrypted drive, etc.)

   Chromebook will handle secure backup in GREEN phase validation.
```

---

### Step 6: Unseal Vault

**Objective:** Unseal Vault using the key from Step 5

**5-Question Guidance:**
- Q1. INTENT: Unseal Vault so it can process requests
- Q2. DATA: Need unseal key from vault-init-keys.txt
- Q3. SAFETY: Read-only operation on secrets file, safe to unseal
- Q4. OPTIMIZATION: Extract key automatically from file
- Q5. TOOL: grep to extract key, vault operator unseal

**Execute:**

```bash
# Extract unseal key from init file
UNSEAL_KEY=$(grep "Unseal Key 1:" /home/jimmyb/vault/vault-init-keys.txt | awk '{print $NF}')

# Unseal Vault
docker exec vault vault operator unseal "$UNSEAL_KEY"
```

**GREEN Validation Checklist:**
- [ ] Unseal command succeeded
- [ ] Vault status shows Sealed: false
- [ ] Vault status shows Initialized: true
- [ ] Health check returns 200 OK
- [ ] Vault is ready for operations

**Verification Commands:**
```bash
# Check Vault status
docker exec vault vault status

# Check health endpoint
curl http://localhost:8200/v1/sys/health
# Expected: HTTP 200, "sealed": false, "initialized": true

# Verify Vault is operational
curl -X GET http://localhost:8200/v1/sys/health | jq .
```

**Expected Status Output:**
```
Key             Value
---             -----
Seal Type       shamir
Initialized     true
Sealed          false  ← IMPORTANT
Total Shares    1
Threshold       1
Version         1.15.x
Storage Type    file
Cluster Name    vault-cluster-xxxxx
Cluster ID      xxxxx
HA Enabled      false
```

**Rollback:**
```bash
# Re-seal Vault
docker exec vault vault operator seal
# Vault returns to sealed state, requires unseal key to use again
```

---

### Step 7: Enable Audit Logging

**Objective:** Enable file-based audit logging for all Vault operations

**5-Question Guidance:**
- Q1. INTENT: Log all Vault operations to file for security audit
- Q2. DATA: Need root token from init file, log path /vault/logs
- Q3. SAFETY: Requires auth (use root token), creates log file
- Q4. OPTIMIZATION: Use docker exec with vault audit enable
- Q5. TOOL: vault audit enable file

**Execute:**

```bash
# Extract root token
ROOT_TOKEN=$(grep "Initial Root Token:" /home/jimmyb/vault/vault-init-keys.txt | awk '{print $NF}')

# Enable file audit device
docker exec -e VAULT_TOKEN="$ROOT_TOKEN" vault \
  vault audit enable file file_path=/vault/logs/audit.log
```

**GREEN Validation Checklist:**
- [ ] Audit device enabled successfully
- [ ] Audit log file created at `/home/jimmyb/vault/logs/audit.log`
- [ ] Audit log is JSON formatted
- [ ] Audit log contains entries
- [ ] `vault audit list` shows file device

**Verification Commands:**
```bash
# List audit devices
docker exec -e VAULT_TOKEN="$ROOT_TOKEN" vault vault audit list

# Check audit log file exists and has content
ls -la /home/jimmyb/vault/logs/audit.log
head -5 /home/jimmyb/vault/logs/audit.log

# Verify JSON format
head -1 /home/jimmyb/vault/logs/audit.log | jq .
```

**Expected Output:**
```
Path     Type    Description
----     ----    -----------
file/    file    n/a
```

**Rollback:**
```bash
# Disable audit device
docker exec -e VAULT_TOKEN="$ROOT_TOKEN" vault \
  vault audit disable file
```

---

### Step 8: Create Health Check Script

**Objective:** Automated health check script for monitoring

**5-Question Guidance:**
- Q1. INTENT: Script to verify Vault health (for cron/monitoring)
- Q2. DATA: Shell script checking Vault status
- Q3. SAFETY: Read-only checks, very safe
- Q4. OPTIMIZATION: Single script, executable, clear output
- Q5. TOOL: bash script with curl and docker commands

**Execute:**

```bash
cat > /home/jimmyb/vault/check-vault-health.sh << 'EOF'
#!/bin/bash
# Vault Health Check Script
# Usage: ./check-vault-health.sh

set -e

echo "=== Vault Health Check ==="
echo "Timestamp: $(date)"
echo ""

# Check container running
echo "1. Container Status:"
docker ps --filter name=vault --format "  {{.Names}}: {{.Status}}"
echo ""

# Check Vault health endpoint
echo "2. Vault Health:"
HEALTH=$(curl -s http://localhost:8200/v1/sys/health)
echo "  Initialized: $(echo $HEALTH | jq -r .initialized)"
echo "  Sealed: $(echo $HEALTH | jq -r .sealed)"
echo "  Standby: $(echo $HEALTH | jq -r .standby)"
echo ""

# Check audit log size
echo "3. Audit Log:"
if [ -f /home/jimmyb/vault/logs/audit.log ]; then
  LOG_SIZE=$(du -h /home/jimmyb/vault/logs/audit.log | cut -f1)
  LOG_LINES=$(wc -l < /home/jimmyb/vault/logs/audit.log)
  echo "  Size: $LOG_SIZE"
  echo "  Lines: $LOG_LINES"
else
  echo "  Not found"
fi
echo ""

# Check resource usage
echo "4. Resource Usage:"
docker stats vault --no-stream --format "  CPU: {{.CPUPerc}} | Memory: {{.MemUsage}}"
echo ""

echo "=== Health Check Complete ==="
EOF

chmod +x /home/jimmyb/vault/check-vault-health.sh
```

**GREEN Validation Checklist:**
- [ ] Script created successfully
- [ ] Script is executable (chmod +x)
- [ ] Script runs without errors
- [ ] Script output is readable

**Verification Commands:**
```bash
# Check script exists and is executable
ls -la /home/jimmyb/vault/check-vault-health.sh

# Run health check
/home/jimmyb/vault/check-vault-health.sh
```

**Rollback:**
```bash
rm /home/jimmyb/vault/check-vault-health.sh
```

---

## Final Validation (Beast GREEN Phase)

**After all steps complete, run comprehensive validation:**

```bash
echo "=== PHASE 1 VAULT DEPLOYMENT - FINAL VALIDATION ==="

# 1. Container health
echo "1. Container Status:"
docker ps | grep vault

# 2. Vault operational
echo "2. Vault Health:"
curl -s http://localhost:8200/v1/sys/health | jq .

# 3. All files present
echo "3. File System:"
tree /home/jimmyb/vault/ || ls -R /home/jimmyb/vault/

# 4. Audit logging working
echo "4. Audit Log (last 3 entries):"
tail -3 /home/jimmyb/vault/logs/audit.log | jq .

# 5. Resource usage
echo "5. Resources:"
docker stats vault --no-stream

# 6. Run health check script
echo "6. Health Check Script:"
/home/jimmyb/vault/check-vault-health.sh

echo ""
echo "=== VALIDATION COMPLETE ==="
```

**All checks must pass:**
- ✅ Container running and healthy
- ✅ Vault initialized: true
- ✅ Vault sealed: false
- ✅ Port 8200 responding
- ✅ Audit log present and writing
- ✅ Health check script functional
- ✅ Secrets file secured (600 permissions)

---

## Chromebook GREEN Phase Validation

**Chromebook (Orchestrator) will validate from remote:**

```bash
# SSH to Beast and verify
ssh jimmyb@192.168.68.100 "docker ps | grep vault"

# Check Vault health via network
curl http://192.168.68.100:8200/v1/sys/health | jq .

# Run health check script
ssh jimmyb@192.168.68.100 "/home/jimmyb/vault/check-vault-health.sh"

# Verify secrets file permissions
ssh jimmyb@192.168.68.100 "ls -la /home/jimmyb/vault/vault-init-keys.txt"
```

**Chromebook will also:**
1. Copy `/home/jimmyb/vault/vault-init-keys.txt` to secure local storage
2. Instruct Beast to delete the file from server
3. Document unseal key and root token in password manager
4. Create CHECKPOINT document with deployment record

---

## Complete Rollback Procedure

**If deployment fails and needs full rollback:**

```bash
# Stop and remove container
docker stop vault
docker rm vault

# Remove volumes (WARNING: destroys all data)
docker volume rm vault-data 2>/dev/null || true

# Remove directories
rm -rf /home/jimmyb/vault

# Remove image (optional)
docker rmi hashicorp/vault:1.15

# Verify clean state
docker ps -a | grep vault  # Should return nothing
ls /home/jimmyb/vault      # Should not exist
```

---

## Post-Deployment Operations

**After successful deployment, Beast can also provide:**

### Restart Vault Container
```bash
docker restart vault

# After restart, Vault will be SEALED
# Unseal with: docker exec vault vault operator unseal <key>
```

### View Vault Logs
```bash
# Real-time logs
docker logs -f vault

# Last 50 lines
docker logs vault --tail 50
```

### Backup Vault Data
```bash
# Stop Vault first
docker stop vault

# Backup data directory
tar czf vault-data-backup-$(date +%Y%m%d).tar.gz /home/jimmyb/vault/data

# Restart Vault
docker start vault
docker exec vault vault operator unseal <key>
```

---

## Success Criteria

**Deployment is successful when:**

- ✅ Vault container running on Beast (192.168.68.100:8200)
- ✅ Vault initialized with 1 unseal key
- ✅ Vault unsealed and operational
- ✅ File audit logging enabled and working
- ✅ Configuration persisted in /home/jimmyb/vault/config
- ✅ Data persisted in /home/jimmyb/vault/data
- ✅ Audit logs in /home/jimmyb/vault/logs
- ✅ Health check script functional
- ✅ Secrets secured (600 permissions)
- ✅ All GREEN validation checks pass
- ✅ Chromebook can access Vault from network
- ✅ No port conflicts with existing services

**If all criteria met:** CHECKPOINT approved, proceed to Phase 2

**If any criteria fail:** Document failure, execute rollback, iterate spec

---

## References

**Research Documents:**
- devlab-vault-architecture.md: Lines 1109-1188 (Phase 1 KISS implementation)
- vault-auth-guide.md: N/A (infrastructure only, no auth yet)

**Beast Documentation:**
- /home/jimmyb/network-infrastructure/beast/docs/BEAST-INFRASTRUCTURE-STATUS.md
- Port allocations, resource availability, current services

**Specialist Context:**
- docs/specs/BEAST-SPECIALIST-CONTEXT.md (Jimmy's Workflow foundation)

---

## Notes for Beast

**This is your first major deployment following the new Haiku 4.5 pattern.**

**Remember:**
- Apply 5-question thinking to EVERY step
- Execute RED → GREEN → CHECKPOINT for EVERY step
- Validate thoroughly before reporting success
- Be honest about any failures or blockers
- Provide complete rollback procedures

**Chromebook is counting on:**
- Your precision in execution
- Your thoroughness in validation
- Your honesty in reporting
- Your documentation of the process

**You've got this. Follow the workflow. Deploy with confidence.**

---

**Execution Spec Version:** 1.0
**Created:** 2025-10-18
**Status:** Ready for Beast execution
**Expected Duration:** 2-4 hours
**Foundation:** Jimmy's Workflow (Mandatory)
