# dev-vault

**Status**: OPERATIONAL - 70% Complete
**Last Updated**: 2025-10-18

## Overview

HashiCorp Vault infrastructure deployment for the dev lab. This repository orchestrates centralized secret management implementation using the three-machine architecture (Chromebook Orchestrator, Guardian Pi 5, Beast) and the Orchestrator + Specialist pattern with Haiku 4.5.

**Current State:** Vault v1.15.6 operational on Beast (192.168.68.100:8200) with KV v2 secrets engine, policy-based access control, and userpass authentication.

## Purpose

- Architecture planning and documentation for Vault deployment
- Execution spec creation (RED phase) using Chromebook Orchestrator
- Structured deployment execution by Beast (Haiku 4.5 Specialist)
- Implementation validation and audit (GREEN phase)
- Deployment checkpoint and approval (CHECKPOINT phase)

## Repository Structure

```
dev-vault/
├── deployment/                      # Deployed artifacts (configs, scripts)
│   ├── vault.hcl                    # Vault server configuration
│   ├── check-vault-health.sh        # Health monitoring script
│   ├── manage-policies.sh           # Policy management tool
│   ├── create-token.sh              # Token creation tool
│   └── policies/                    # Policy HCL files
│       ├── admin-policy.hcl         # Full admin access
│       ├── bot-policy.hcl           # Cardano read-only
│       └── external-readonly.hcl    # API tokens read-only
├── docs/
│   ├── specs/                       # Execution specs for Beast
│   │   ├── BEAST-SPECIALIST-CONTEXT.md      # Haiku 4.5 specialist context
│   │   ├── PHASE-1-VAULT-DEPLOYMENT.md      # Phase 1 infrastructure spec
│   │   └── PHASE-2-SECRETS-AND-POLICIES.md  # Phase 2 configuration spec
│   └── checkpoints/                 # Deployment records & approvals
│       ├── PHASE-1-DEPLOYMENT-RECORD.md
│       ├── PHASE-1-CHECKPOINT-APPROVAL.md
│       ├── PHASE-2-DEPLOYMENT-RECORD.md
│       └── PHASE-2-CHECKPOINT-APPROVAL.md
├── devlab-vault-architecture.md     # Research document
├── vault-auth-guide.md              # Authentication strategy research
├── AGENTS.md                        # AI assistant guidelines
├── CLAUDE.md                        # Quick reference for Claude
├── JIMMYS-WORKFLOW.md               # RED→GREEN→CHECKPOINT workflow system
└── README.md                        # This file
```

## Current Status

**Phase 1: Infrastructure Deployment** ✅ COMPLETE (2025-10-18)
- ✅ Vault v1.15.6 deployed on Beast:8200
- ✅ File-based storage backend
- ✅ Single unseal key configuration
- ✅ Audit logging enabled
- ✅ Health monitoring functional
- ✅ Execution time: 10 minutes
- ✅ CHECKPOINT approved

**Phase 2: Secrets & Policies** ✅ COMPLETE (2025-10-18)
- ✅ KV v2 secrets engine enabled at secret/
- ✅ Three policies created (admin, bot, external-readonly)
- ✅ Userpass authentication enabled (768h TTL)
- ✅ Test secrets stored in hierarchy
- ✅ **Policy enforcement validated (6/6 security tests passed)**
- ✅ Management scripts created
- ✅ Execution time: 25 minutes
- ✅ CHECKPOINT approved

**Phase 3: Production Readiness** ⚪ PENDING
- ⚪ Replace test secrets with real Cardano keys
- ⚪ Backup automation
- ⚪ Monitoring integration
- ⚪ Revoke root token (use admin user token)

## Vault Infrastructure

**Deployed On:** Beast (192.168.68.100)
**Version:** HashiCorp Vault v1.15.6
**Access:** http://192.168.68.100:8200
**Status:** ✅ Operational (initialized, unsealed)

### Capabilities

**Secret Storage:**
- KV v2 secrets engine at `secret/` path
- Versioning enabled (rollback support)
- Test secrets stored (ready for production secrets)

**Access Control:**
- 3 role-based policies (admin, bot, external-readonly)
- Policy enforcement validated (6/6 security tests passed)
- Userpass authentication (768h token TTL)

**Operational Tools:**
- Health monitoring: `deployment/check-vault-health.sh`
- Policy management: `deployment/manage-policies.sh`
- Token creation: `deployment/create-token.sh`

**Audit & Monitoring:**
- File-based audit logging (all operations logged)
- Health checks functional
- Resource usage: <1% CPU, 395MB RAM

---

## Using Vault

### Create Tokens (Beast)

```bash
# Export your admin token
export VAULT_TOKEN="<admin-token-from-password-manager>"

# Create bot token (7-day)
./deployment/create-token.sh bot-policy 7d production-bot

# Create external user token (30-day)
./deployment/create-token.sh external-readonly 30d researcher-alice
```

### Store Secrets (Beast)

```bash
# Store Cardano signing key
docker exec -e VAULT_TOKEN="$VAULT_TOKEN" vault \
  vault kv put secret/cardano/mainnet/signing-key \
    key="<real-signing-key>" \
    created_date="$(date +%Y-%m-%d)"

# Store Maestro API key
docker exec -e VAULT_TOKEN="$VAULT_TOKEN" vault \
  vault kv put secret/cardano/testnet/maestro-api-key \
    api_key="<real-api-key>" \
    network="testnet"
```

### Retrieve Secrets (Beast - with bot token)

```bash
# Export bot token
export VAULT_TOKEN="<bot-token>"

# Read signing key
docker exec -e VAULT_TOKEN="$VAULT_TOKEN" vault \
  vault kv get -field=key secret/cardano/testnet/signing-key
```

---

## Getting Started

### For AI Assistants

Start by reading **AGENTS.md** for complete project context and guidelines.

### Orchestrator Workflow (Chromebook)

1. **RED Phase**: Create detailed execution specs in `docs/specs/`
2. **Commit & Push**: Push specs to GitHub
3. **Delegate**: Create GitHub issue for Beast to execute
4. **GREEN Phase**: Pull Beast's implementation, validate, audit
5. **CHECKPOINT**: Approve or request iteration

### Specialist Execution (Beast)

1. **Pull**: Git pull latest specs from GitHub
2. **Read**: Specialist context + execution spec
3. **Execute**: Follow Jimmy's Workflow (RED→GREEN→CHECKPOINT) for each step
4. **Commit**: Push deployment artifacts to GitHub
5. **Report**: Report completion in GitHub issue

---

## Three-Machine Architecture

- **Chromebook Orchestrator** (Sonnet 4.5): Strategic planning, specs, validation, approval
- **Beast** (Haiku 4.5 Specialist): Structured deployment execution, Docker infrastructure
- **Guardian Pi 5** (192.168.68.10): Future services hosting

**Coordination:** GitHub (single source of truth)
**Pattern:** Orchestrator + Specialist (60% cost savings, 2x speed)

---

## Deployment History

| Phase | Date | Duration | Executor | Result |
|-------|------|----------|----------|--------|
| Phase 1 | 2025-10-18 | 10 min | Beast (Haiku 4.5) | ✅ Vault deployed |
| Phase 2 | 2025-10-18 | 25 min | Beast (Haiku 4.5) | ✅ Policies configured |
| **Total** | **2025-10-18** | **35 min** | **20 steps** | **✅ Operational** |

---

## Resources

**Project Documentation:**
- AGENTS.md: AI assistant guidelines
- JIMMYS-WORKFLOW.md: RED→GREEN→CHECKPOINT system
- docs/checkpoints/: Deployment records and approvals

**Research Documents:**
- devlab-vault-architecture.md: Comprehensive deployment architecture
- vault-auth-guide.md: Authentication strategy comparison

**Deployment Artifacts:**
- deployment/: Vault configs, policies, management scripts
- docs/specs/: Execution specifications for Beast

**Context:**
- ~/CLAUDE-CHROMEBOOK.md: Orchestrator role documentation
- ~/templates/haiku-4.5-research/: Orchestrator + Specialist pattern research

---

## License

Internal development laboratory project.

---

**Coordination Hub**: GitHub (single source of truth)
**Workflow**: Jimmy's Workflow (RED→GREEN→CHECKPOINT)
**Pattern**: Orchestrator + Specialist (Validated)
