# Dev Lab Vault: Universal Secret Management & API Key Infrastructure

## Executive Summary

This document outlines the architecture for a containerized HashiCorp Vault deployment serving as the central secret management and API authentication system for an internal development laboratory. The Vault instance provides secure storage for sensitive credentials, dynamic API key generation for external users, comprehensive audit logging, and serves as the authentication backbone for all lab services.

**Primary Use Cases:**
- Secure storage of Cardano blockchain signing keys and credentials
- API key issuance and management for external node access
- Centralized secret management across multiple projects
- Audit trail for compliance and security investigations
- Dynamic credential generation with automatic expiration

**Key Benefits:**
- Single source of truth for all secrets across the lab
- Zero secrets stored in application code or configuration files
- Automated credential rotation and expiration
- Granular access control with policy-as-code
- Complete audit trail of all secret access
- Horizontal scalability across future projects

---

## Table of Contents

1. [Introduction & Context](#introduction--context)
2. [Architecture Overview](#architecture-overview)
3. [Core Components](#core-components)
4. [Secret Storage Patterns](#secret-storage-patterns)
5. [API Key Management](#api-key-management)
6. [Security Model](#security-model)
7. [Network Architecture](#network-architecture)
8. [Data Persistence & Backup](#data-persistence--backup)
9. [Access Control & Policies](#access-control--policies)
10. [Integration Patterns](#integration-patterns)
11. [Operational Procedures](#operational-procedures)
12. [Scaling & Future Growth](#scaling--future-growth)

---

## Introduction & Context

### The Problem Space

Modern development laboratories face three critical challenges in secret management:

1. **Credential Sprawl**: Secrets distributed across environment variables, configuration files, encrypted files, and developer machines create security vulnerabilities and operational complexity.

2. **Access Management Overhead**: Manually issuing, tracking, rotating, and revoking API keys for external collaborators requires significant administrative effort and introduces human error.

3. **Audit & Compliance Gaps**: Without centralized logging, determining who accessed which secrets when becomes impossible, creating compliance risks and hindering security investigations.

### The Vault Solution

HashiCorp Vault addresses these challenges through:

- **Centralized Secret Store**: All sensitive data stored in one encrypted backend with programmatic access
- **Dynamic Secret Generation**: API keys, database credentials, and certificates generated on-demand with automatic expiration
- **Policy-Based Access Control**: Fine-grained permissions defined as code and version-controlled
- **Comprehensive Audit Logging**: Every operation logged with timestamp, actor, action, and outcome
- **Encryption as a Service**: Applications can leverage Vault's encryption without managing keys directly

### Project Context: Cardano Trading Bot Laboratory

The initial driver for Vault deployment centers on a Cardano blockchain trading bot project requiring:

**Secure Storage:**
- Cardano payment signing keys (ed25519 private keys)
- Collateral UTxO references
- Maestro/Blockfrost API credentials
- GeniusYield DEX integration secrets

**External Node Access:**
- Mainnet Cardano node exposed via API
- Testnet Cardano node for development
- Preprod environment for integration testing
- API key issuance for external researchers and partners

**Operational Requirements:**
- 24/7 automated trading requiring persistent access to secrets
- Zero-downtime secret rotation capabilities
- Complete audit trail for regulatory compliance
- Disaster recovery with encrypted backups

---

## Architecture Overview

### High-Level System Design

```
┌─────────────────────────────────────────────────────────────┐
│                     Dev Lab Infrastructure                   │
│                    (Behind Cloudflare Protection)            │
│                                                              │
│  ┌────────────────────────────────────────────────────┐    │
│  │              Docker Internal Network                │    │
│  │                 (bridge/overlay)                    │    │
│  │                                                      │    │
│  │  ┌──────────────┐      ┌────────────────────┐     │    │
│  │  │    Vault     │      │   Cardano Node     │     │    │
│  │  │  Container   │      │   (mainnet)        │     │    │
│  │  │  :8200       │      │   :3001            │     │    │
│  │  └──────┬───────┘      └─────────┬──────────┘     │    │
│  │         │                        │                 │    │
│  │         │                        │                 │    │
│  │  ┌──────▼───────┐      ┌────────▼──────────┐     │    │
│  │  │  Trading     │      │   Cardano Node    │     │    │
│  │  │  Bot         │      │   (testnet)       │     │    │
│  │  │  Container   │      │   :3002           │     │    │
│  │  └──────────────┘      └───────────────────┘     │    │
│  │                                                     │    │
│  │  ┌──────────────────────────────────────────┐    │    │
│  │  │        API Gateway / Reverse Proxy        │    │    │
│  │  │    (Traefik/Nginx with Vault Auth)       │    │    │
│  │  │              :80 / :443                   │    │    │
│  │  └──────────────────┬───────────────────────┘    │    │
│  └─────────────────────┼────────────────────────────┘    │
│                        │                                   │
└────────────────────────┼───────────────────────────────────┘
                         │
                         ▼
                ┌────────────────┐
                │   Cloudflare   │
                │   CDN/WAF      │
                └────────┬───────┘
                         │
                         ▼
                  External Users
                  (API Consumers)
```

### Component Interaction Flow

**Internal Service Access (Trading Bot → Vault):**
1. Bot starts, reads Vault token from Docker secret
2. Authenticates to Vault via Docker network (`http://vault:8200`)
3. Requests signing key from path `secret/data/cardano/mainnet/signing-key`
4. Vault validates token, checks policy permissions
5. Returns decrypted secret to bot
6. Bot uses key for transaction signing
7. All operations logged to Vault audit log

**External User Access (Researcher → Cardano Node):**
1. User receives time-limited Vault token (30-day TTL)
2. Makes API request to `https://lab.domain.com/cardano/testnet/query`
3. Cloudflare forwards to API gateway
4. Gateway extracts Bearer token, queries Vault for validation
5. Vault confirms token valid with `testnet-readonly` policy
6. Gateway proxies request to `cardano-testnet:3002`
7. Response returned to user
8. Access logged in Vault audit trail

### Key Architectural Decisions

**Decision 1: Single Vault Instance vs. Clustered**
- **Choice**: Single containerized Vault instance
- **Rationale**: Dev lab workload doesn't justify HA complexity; disaster recovery via volume snapshots sufficient; can migrate to cluster if scaling requirements emerge
- **Trade-offs**: Single point of failure acceptable in dev environment; 15-minute RTO achievable with proper backup strategy

**Decision 2: Storage Backend**
- **Choice**: File-based storage with volume mount
- **Rationale**: Simplest deployment, lowest operational overhead, sufficient performance for lab scale (<100 req/sec)
- **Trade-offs**: No built-in HA; acceptable for dev lab; can migrate to Consul/Raft backend if clustering needed later

**Decision 3: Network Exposure**
- **Choice**: Vault never directly exposed to internet; API gateway handles external traffic
- **Rationale**: Minimizes attack surface; separates authentication (Vault) from routing (gateway); enables rate limiting and WAF at edge
- **Trade-offs**: Slightly more complex architecture; justified by security benefits

**Decision 4: Unsealing Strategy**
- **Choice**: Manual unseal on startup with Shamir secret sharing (3-of-5 keys)
- **Rationale**: Balances security (no auto-unseal keys in config) with operational practicality (can unseal with quorum)
- **Trade-offs**: Requires human intervention on restart; acceptable for dev lab with infrequent restarts

---

## Core Components

### Vault Container Specification

**Base Image**: `hashicorp/vault:1.15` (official Vault image)

**Volume Mounts**:
- `/vault/data` → Persistent encrypted storage backend
- `/vault/logs` → Audit log output directory
- `/vault/config` → Server configuration files

**Environment Variables**:
- `VAULT_ADDR=http://0.0.0.0:8200` (internal listen address)
- `VAULT_API_ADDR=http://vault:8200` (address for cluster communication)

**Exposed Ports**:
- `8200/tcp` → Vault API (internal Docker network only)

**Resource Allocation**:
- Memory: 512MB minimum, 1GB recommended
- CPU: 0.5 cores minimum, 1 core recommended
- Storage: 10GB minimum for small deployments, scales with secret count

**Health Checks**:
- HTTP GET to `/v1/sys/health` every 30s
- Healthy response: `200 OK` when initialized and unsealed
- Unhealthy response: `503 Service Unavailable` when sealed
- Container restart policy: `unless-stopped` (requires manual unseal)

### Vault Configuration File

**Server Configuration** (`/vault/config/vault.hcl`):

```hcl
storage "file" {
  path = "/vault/data"
}

listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_disable = 1  # TLS handled by API gateway
}

api_addr = "http://vault:8200"
ui = true  # Enable web UI for administration

log_level = "info"

# Enable audit logging to file
audit {
  file {
    path = "/vault/logs/audit.log"
  }
}
```

### Secret Engines

Vault organizes secrets using mountable engines, each optimized for specific use cases:

**KV Version 2 (Key-Value Secrets Engine)**
- **Mount Path**: `secret/`
- **Purpose**: Static secrets (API keys, credentials, signing keys)
- **Features**: Versioning, soft delete, configurable max versions
- **Use Case**: Cardano signing keys, API credentials, configuration secrets

**Database Secrets Engine** (Future)
- **Mount Path**: `database/`
- **Purpose**: Dynamic database credentials with automatic rotation
- **Use Case**: PostgreSQL/MySQL credentials for bot database

**PKI Secrets Engine** (Future)
- **Mount Path**: `pki/`
- **Purpose**: Internal certificate authority for TLS certificates
- **Use Case**: mTLS between containers, service authentication

**Transit Secrets Engine** (Future)
- **Mount Path**: `transit/`
- **Purpose**: Encryption as a service without key exposure
- **Use Case**: Encrypt trading strategy configs, PII data

### Authentication Methods

**Token Authentication (Primary)**
- Default method for all access
- Tokens created with policies, TTL, and metadata
- Supports parent-child hierarchies for delegation
- Renewable within configured max TTL

**AppRole Authentication (Future)**
- Machine-to-machine authentication
- Role ID (public) + Secret ID (secret) pattern
- Secret ID can be delivered via trusted orchestrator
- Use Case: Automated bot deployments via CI/CD

**Kubernetes Authentication** (Future)
- If migrating to Kubernetes
- Pods authenticate using service account tokens
- Vault validates against K8s API server

---

## Secret Storage Patterns

### Hierarchical Organization

Vault secrets should be organized hierarchically to reflect access boundaries and project structure:

```
secret/
├── cardano/
│   ├── mainnet/
│   │   ├── signing-key          # Production trading key
│   │   ├── collateral-utxo      # Collateral reference
│   │   └── maestro-api-key      # Mainnet Maestro access
│   ├── testnet/
│   │   ├── signing-key          # Test trading key
│   │   ├── collateral-utxo      # Testnet collateral
│   │   └── maestro-api-key      # Testnet Maestro access
│   └── preprod/
│       └── signing-key          # Pre-production key
├── external-access/
│   └── node-api-tokens/         # Generated for external users
│       ├── researcher-alice-token
│       ├── partner-bob-token
│       └── institution-charlie-token
├── trading-bot/
│   ├── config/
│   │   ├── risk-params          # Trading risk configuration
│   │   └── strategy-params      # Strategy parameters
│   └── integrations/
│       ├── geniusyield-api      # DEX integration key
│       └── monitoring-webhook   # Alerting webhook URL
└── infrastructure/
    ├── cloudflare-api           # DNS/CDN management
    ├── backup-credentials       # S3/rsync backup access
    └── monitoring-tokens        # Prometheus/Grafana tokens
```

### Secret Versioning Strategy

Vault KV v2 maintains version history for all secrets, enabling:

**Version Retention Policy**:
- Keep last 10 versions of each secret
- Soft delete older versions (recoverable for 30 days)
- Hard delete after 30-day grace period
- Critical secrets (signing keys): never auto-delete, manual cleanup only

**Rotation Workflow**:
1. Write new version to Vault with updated secret
2. Test new secret in staging environment
3. Update production to use new version
4. Monitor for 24 hours
5. Mark old version for deletion after validation period

**Emergency Rollback**:
- Query version history: `vault kv get -version=5 secret/path`
- Restore previous version: `vault kv rollback -version=5 secret/path`
- All operations logged for audit trail

### Encryption Standards

**At-Rest Encryption**:
- Vault encrypts all data using AES-256-GCM
- Master key never stored unencrypted (protected by unseal keys)
- Data keys rotated automatically per Vault's keyring rotation schedule

**In-Transit Encryption**:
- Internal Docker network: TLS optional (trusted network assumption)
- External access: Mandatory TLS 1.3 via API gateway/Cloudflare
- Vault API to gateway: Can use mTLS for additional security

**Key Hierarchy**:
```
Unseal Keys (Shamir 3-of-5)
    ↓
Master Key (AES-256)
    ↓
Encryption Key Ring (rotated)
    ↓
Individual Secret Encryption Keys
    ↓
Encrypted Secret Data
```

---

## API Key Management

### Token Lifecycle Management

**Token Creation Workflow**:

1. **Administrator creates policy** defining access scope
2. **Generate token** with policy attachment and TTL
3. **Deliver token** to user via secure channel
4. **User authenticates** by including token in API requests
5. **Gateway validates** token with Vault before proxying
6. **Token expires** automatically after TTL
7. **Renewal** possible within max TTL bounds if configured

**Token Types**:

**Service Tokens** (Default):
- Persistent, renewable tokens
- Backed by audit log entries
- Can be revoked explicitly
- Used for: External API access, service-to-service auth

**Batch Tokens** (High-Volume):
- Lightweight, non-renewable
- Not tracked in storage (lower overhead)
- Automatically expire, cannot be revoked individually
- Used for: High-frequency trading bot API calls

**Periodic Tokens** (Long-Lived):
- Renewable indefinitely within max TTL
- Root token can create periodic tokens
- Used for: Critical infrastructure, CI/CD systems

### Policy Definition for External Node Access

**Testnet Read-Only Policy** (`testnet-readonly.hcl`):

```hcl
# Allow reading Cardano testnet node endpoints
path "secret/data/external-access/node-api-tokens/*" {
  capabilities = ["read"]
}

# Allow token self-inspection
path "auth/token/lookup-self" {
  capabilities = ["read"]
}

# Deny all other access
path "*" {
  capabilities = ["deny"]
}
```

**Mainnet Limited Policy** (`mainnet-limited.hcl`):

```hcl
# Allow reading specific mainnet endpoints
path "secret/data/cardano/mainnet/query-api" {
  capabilities = ["read"]
}

# Block transaction submission access
path "secret/data/cardano/mainnet/signing-key" {
  capabilities = ["deny"]
}

# Rate limiting enforced at API gateway layer
```

**Administrative Policy** (`admin-policy.hcl`):

```hcl
# Full access to all secrets
path "secret/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

# Policy management
path "sys/policies/acl/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

# Token management
path "auth/token/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# Audit log access
path "sys/audit" {
  capabilities = ["read", "sudo"]
}
```

### API Key Issuance Process

**External User Onboarding**:

1. **User requests access** via email/ticket with justification
2. **Administrator reviews** use case and determines appropriate policy
3. **Token generated** with metadata:
   - Display name (e.g., "researcher-alice-testnet")
   - TTL (e.g., 720h = 30 days)
   - Policy attachment (e.g., `testnet-readonly`)
   - Usage limit (optional, e.g., 10,000 requests)
4. **Token delivered** via secure channel (1Password, encrypted email)
5. **User documentation** provided with API examples
6. **Monitoring dashboard** updated to track token usage

**Renewal Process**:
- Users request renewal 7 days before expiration
- Administrator extends TTL or issues new token
- Old token revoked after grace period

**Revocation Process**:
- Administrator revokes token immediately
- All child tokens also revoked
- User notified of revocation reason
- Logged in audit trail for compliance

### Usage Tracking & Rate Limiting

**Vault Audit Logs** capture:
- Token accessor (anonymized token ID)
- Timestamp of each request
- Endpoint accessed
- Response status code
- Client IP address
- Request metadata

**Rate Limiting Implementation**:
- API gateway tracks requests per token
- Configurable limits:
  - Free tier: 1000 requests/day
  - Research tier: 10,000 requests/day
  - Partner tier: 100,000 requests/day
- Exceeded limit returns HTTP 429 with Retry-After header

**Usage Analytics**:
- Daily aggregation of requests per token
- Alert on suspicious patterns (sudden spike, geographic anomaly)
- Monthly reports to administrators
- Billing integration (if commercializing node access)

---

## Security Model

### Defense in Depth Strategy

**Layer 1: Network Isolation**
- Vault container on internal Docker network only
- No direct internet exposure
- All external traffic via API gateway with Cloudflare WAF

**Layer 2: Authentication & Authorization**
- Every request requires valid token
- Policies enforce principle of least privilege
- Token TTLs limit blast radius of compromised credentials

**Layer 3: Encryption**
- All secrets encrypted at rest with AES-256-GCM
- TLS 1.3 for all external communications
- Vault master key protected by Shamir secret sharing

**Layer 4: Audit & Monitoring**
- Every operation logged with actor and timestamp
- Real-time alerting on suspicious activity
- Immutable audit logs for forensic analysis

**Layer 5: Operational Security**
- Unseal keys distributed across multiple administrators
- No root token persistence (generated on-demand, revoked after use)
- Regular secret rotation enforced by policy
- Backup encryption with separate key management

### Threat Model & Mitigations

**Threat: Compromised Application Token**
- **Mitigation**: Short TTL (24-48h for bots), policy limits blast radius, immediate revocation capability
- **Detection**: Audit log analysis for unusual access patterns
- **Response**: Revoke token, rotate affected secrets, investigate breach

**Threat: Container Escape / Host Compromise**
- **Mitigation**: Vault sealed by default on restart, requires quorum to unseal, secrets encrypted at rest
- **Detection**: Host intrusion detection system (AIDE, Tripwire)
- **Response**: Seal Vault, investigate compromise, rotate unseal keys if necessary

**Threat: Insider Threat / Malicious Administrator**
- **Mitigation**: Multi-person integrity for critical operations, comprehensive audit logging, unseal key quorum
- **Detection**: Behavioral analytics on admin actions
- **Response**: Revoke admin access, audit all changes, potential law enforcement engagement

**Threat: API Gateway Bypass**
- **Mitigation**: Network policies prevent direct Vault access, authentication at gateway layer
- **Detection**: Unexpected traffic patterns to Vault container
- **Response**: Investigate source, strengthen network policies, rotate compromised credentials

**Threat: Backup Compromise**
- **Mitigation**: Backups encrypted with separate key, stored off-site with access logging
- **Detection**: Unauthorized backup access attempts
- **Response**: Rotate Vault unseal keys, assess exposure scope

### Compliance Considerations

**Audit Requirements**:
- All secret access logged with timestamp and actor
- Logs retained for minimum 90 days (configurable to years)
- Immutable log storage (append-only, cannot be altered)
- Regular log review for anomalies

**Access Control Documentation**:
- Policies stored in version control (Git)
- Changes peer-reviewed before deployment
- Documentation of who has access to what and why

**Encryption Standards**:
- NIST-compliant encryption algorithms (AES-256-GCM)
- Key rotation schedule documented and enforced
- Encryption key lifecycle management

**Disaster Recovery**:
- Recovery Time Objective (RTO): 15 minutes
- Recovery Point Objective (RPO): 24 hours (daily backups)
- Documented and tested recovery procedures

---

## Network Architecture

### Docker Networking Configuration

**Internal Network** (`vault-internal`):
- Type: Bridge network
- Subnet: `172.20.0.0/16`
- Gateway: `172.20.0.1`
- DNS: Docker embedded DNS resolver

**Service Endpoints**:
```
vault:8200           → Vault API
cardano-mainnet:3001 → Mainnet node RPC
cardano-testnet:3002 → Testnet node RPC
api-gateway:80/443   → External traffic entry point
```

**Network Policies**:
- Vault container: Accepts connections from any container on `vault-internal`
- Cardano nodes: Accept connections only from `api-gateway` and `trading-bot`
- Trading bot: Outbound to `vault` and `cardano-*` only
- API gateway: Outbound to `vault` (auth) and `cardano-*` (proxying)

### External Access Flow

**User Request Path**:
```
User
  ↓ HTTPS (TLS 1.3)
Cloudflare CDN/WAF
  ↓ Filtered traffic
API Gateway (Traefik/Nginx)
  ↓ Token validation with Vault
Vault (authentication decision)
  ↓ If valid, proxy to backend
Cardano Node Container
  ↓ Response
... reverse path back to user
```

**Security Controls at Each Layer**:

1. **Cloudflare**:
   - DDoS protection
   - Bot mitigation
   - Geographic blocking (if desired)
   - TLS termination

2. **API Gateway**:
   - Token extraction from Authorization header
   - Vault token validation
   - Rate limiting per token
   - Request logging
   - Backend routing based on path

3. **Vault**:
   - Token signature verification
   - Policy evaluation
   - Audit logging
   - Response: allowed/denied

4. **Backend Service**:
   - Process validated request
   - No authentication checks (trusts gateway)

### Cloudflare Integration

**DNS Configuration**:
- `api.lab.yourdomain.com` → Your lab's public IP
- Cloudflare proxies traffic (orange cloud)
- SSL/TLS mode: Full (strict) with valid certificate

**WAF Rules**:
- Block common attack patterns (SQL injection, XSS)
- Challenge suspicious IPs
- Rate limit per IP: 100 requests/minute
- Geographic restrictions (optional)

**Access Control**:
- Cloudflare Access (optional) for admin endpoints
- Zero Trust policies for sensitive paths
- mTLS for high-security scenarios

---

## Data Persistence & Backup

### Volume Management

**Vault Data Volume**:
- Mount point: `/vault/data`
- Contains: Encrypted secret storage backend
- Encryption: Vault's built-in encryption (AES-256-GCM)
- Size: Start 10GB, monitor growth

**Audit Log Volume**:
- Mount point: `/vault/logs`
- Contains: Audit log files (JSON format)
- Rotation: Daily rotation, compressed, 90-day retention
- Size: Plan 1GB per month (varies by request volume)

**Configuration Volume** (Optional):
- Mount point: `/vault/config`
- Contains: `vault.hcl` server configuration
- Alternative: Bake config into custom Docker image

### Backup Strategy

**Automated Daily Backups**:
- Schedule: 2:00 AM UTC daily (low-traffic window)
- Method: Snapshot Vault data volume
- Encryption: Separate encryption key (GPG or age)
- Destination: Off-site storage (S3, NAS, external drive)
- Retention: 30 daily, 12 monthly, 3 yearly

**Backup Script Workflow**:
1. Seal Vault (optional, for consistency)
2. Snapshot `/vault/data` directory
3. Encrypt snapshot with backup key
4. Upload to off-site storage
5. Verify upload integrity (checksum)
6. Unseal Vault (if sealed)
7. Log backup completion
8. Alert on failure

**Backup Encryption**:
- Backup encryption key != Vault unseal keys
- Stored securely separate from Vault infrastructure
- Escrowed with trusted third party or secure vault

**Audit Log Backup**:
- Separate from data backups (different retention)
- Shipped to SIEM or log aggregator in real-time (optional)
- Long-term archival for compliance (7+ years if required)

### Disaster Recovery Procedures

**Scenario 1: Vault Container Failure**
1. Stop failed container
2. Deploy new Vault container with same volume mounts
3. Start container (Vault will be sealed)
4. Unseal using quorum of unseal keys (3 of 5)
5. Verify services reconnecting successfully
6. Review audit logs for any issues during outage

**Scenario 2: Volume Corruption**
1. Stop Vault container
2. Identify most recent good backup
3. Restore backup to new volume
4. Mount restored volume to Vault container
5. Start Vault and unseal
6. Validate secret integrity
7. Notify users of RPO (data loss window)

**Scenario 3: Complete Lab Failure**
1. Provision new infrastructure (cloud or physical)
2. Restore Vault backup to new environment
3. Update DNS to point to new IP
4. Unseal Vault
5. Reconnect services (update Vault endpoints)
6. Validate all secrets accessible
7. Resume operations

**Recovery Time Objectives**:
- Container failure: < 5 minutes
- Volume corruption: < 15 minutes
- Complete lab failure: < 4 hours

---

## Access Control & Policies

### Policy Design Principles

**Principle of Least Privilege**:
- Grant minimum permissions necessary for function
- Deny by default, allow explicitly
- Separate read from write access where possible

**Separation of Duties**:
- No single administrator has full control
- Critical operations require multiple approvals
- Audit-only roles cannot modify secrets

**Time-Based Access**:
- Short TTLs for high-risk secrets (signing keys: 24h)
- Longer TTLs for low-risk secrets (API keys: 30 days)
- Force renewal to ensure active use

**Contextual Access**:
- IP allowlisting for highly sensitive operations (optional)
- Time-of-day restrictions for admin operations (optional)
- Geographic restrictions via Cloudflare

### Example Policy Matrix

| Role | Testnet Read | Testnet Write | Mainnet Read | Mainnet Write | Admin Functions |
|------|--------------|---------------|--------------|---------------|-----------------|
| **External Researcher** | ✅ | ❌ | ❌ | ❌ | ❌ |
| **Partner Developer** | ✅ | ❌ | ✅ | ❌ | ❌ |
| **Trading Bot (testnet)** | ✅ | ✅ | ❌ | ❌ | ❌ |
| **Trading Bot (mainnet)** | ❌ | ❌ | ✅ | ✅ | ❌ |
| **DevOps Engineer** | ✅ | ✅ | ✅ | ✅ | Limited |
| **Security Admin** | Audit Only | Audit Only | Audit Only | Audit Only | Full |

### Emergency Access Procedures

**Break-Glass Account**:
- Root token generated only when needed
- Requires physical access to lab (or multi-party approval)
- Time-limited (expires after 1 hour)
- Logged extensively for post-incident review
- Revoked immediately after use

**Emergency Revocation**:
- Suspected compromise triggers immediate token revocation
- Batch revocation via token accessor
- Child tokens automatically revoked
- Notification to affected parties
- Incident response process initiated

**Policy Update Process**:
1. Propose policy change in version control (Git)
2. Peer review by second administrator
3. Test policy in staging environment
4. Deploy to production Vault
5. Verify services retain expected access
6. Document change in changelog

---

## Integration Patterns

### Trading Bot Integration

**Bot Startup Flow**:
1. Read Vault token from Docker secret (`/run/secrets/vault-token`)
2. Authenticate to Vault at `http://vault:8200`
3. Retrieve signing key from `secret/data/cardano/mainnet/signing-key`
4. Cache decrypted key in memory only (never to disk)
5. Use key for transaction signing
6. Periodically renew token to extend TTL

**Error Handling**:
- Vault unreachable: Retry with exponential backoff, alert after 5 minutes
- Token expired: Attempt renewal, fail if renewal impossible, alert immediately
- Secret not found: Fatal error, stop bot to prevent operation without credentials
- Permission denied: Log detailed error, alert administrator

**Secret Rotation Without Downtime**:
1. Write new version of signing key to Vault
2. Bot automatically retrieves latest version on next fetch
3. Vault's versioning retains old key temporarily
4. Monitor transactions for 24 hours
5. Delete old version after validation

### API Gateway Integration

**Middleware Authentication Flow**:

1. **Extract Token** from `Authorization: Bearer <token>` header
2. **Validate Token** via Vault lookup:
   ```
   GET /v1/auth/token/lookup
   Headers: X-Vault-Token: <token>
   ```
3. **Check Response**:
   - 200 OK + policies → Proceed to step 4
   - 403 Forbidden → Return 401 to user
   - 500 Error → Fail open or closed (configurable)
4. **Evaluate Policies**: Does token policy allow requested endpoint?
5. **Proxy Request** to backend if authorized
6. **Return Response** to user
7. **Log Access** with token accessor and outcome

**Caching Strategy**:
- Cache token validation results for 60 seconds
- Invalidate cache on explicit revocation
- Reduce Vault load for high-frequency access

**Fallback Behavior**:
- If Vault down: Fail closed (deny all requests)
- Or: Fail open with rate limiting (temporary degradation)
- Configuration depends on availability vs. security priority

### Monitoring & Alerting Integration

**Prometheus Metrics Exporter**:
- Vault provides `/v1/sys/metrics` endpoint
- Export token usage, request latency, error rates
- Grafana dashboards for visualization

**Alert Rules**:
- **Critical**: Vault sealed (unsealed = false)
- **Critical**: Authentication failure rate > 10/min
- **Warning**: Token expiring in < 24h for critical services
- **Warning**: Audit log volume > 1GB (rotation needed)
- **Info**: New token created (for auditing)

**Log Shipping**:
- Ship audit logs to centralized logging (ELK, Splunk, Loki)
- Real-time analysis for security events
- Long-term retention for compliance

---

## Operational Procedures

### Initial Deployment

**Step 1: Deploy Container**
- Pull official Vault image
- Create persistent volumes for data and logs
- Mount configuration file
- Start container with health checks

**Step 2: Initialize Vault**
- Initialize with Shamir secret sharing (5 keys, threshold 3)
- Receive 5 unseal keys and 1 root token
- Distribute unseal keys to separate administrators
- Store root token securely (hardware token, encrypted file)

**Step 3: Unseal Vault**
- Provide 3 of 5 unseal keys
- Verify Vault status: unsealed = true, standby = false

**Step 4: Enable Audit Logging**
- Configure file-based audit log
- Set log rotation and retention policy
- Verify logs written successfully

**Step 5: Configure Secret Engines**
- Enable KV v2 at `secret/` path
- Configure max versions, deletion policies

**Step 6: Create Initial Policies**
- Upload policy files (admin, bot, external-user)
- Test policy enforcement

**Step 7: Create Service Tokens**
- Generate token for trading bot with appropriate policy
- Store token in Docker secret
- Test bot authentication

**Step 8: Revoke Root Token**
- After setup complete, revoke root token
- Generate new root token only when necessary (break-glass)

### Daily Operations

**Morning Checklist**:
- Verify Vault unsealed and healthy
- Check audit logs for anomalies overnight
- Review token expirations (upcoming 7 days)
- Validate backup completed successfully

**Token Management**:
- Review new token requests
- Issue tokens with appropriate policies
- Renew long-running tokens before expiration
- Revoke tokens for departing users/completed projects

**Secret Rotation**:
- Quarterly rotation for high-risk secrets (signing keys)
- Monthly rotation for medium-risk secrets (API keys)
- Annual rotation for low-risk secrets (webhooks)

### Incident Response

**Suspected Token Compromise**:
1. Immediately revoke compromised token
2. Review audit logs for unauthorized access
3. Rotate all secrets accessible by token
4. Investigate compromise vector
5. Strengthen controls to prevent recurrence
6. Document incident for post-mortem

**Vault Outage**:
1. Check container status and logs
2. Verify unsealed state (seal if suspicious activity)
3. Restart container if configuration issue
4. Restore from backup if data corruption
5. Notify users of temporary service interruption
6. Post-incident review of availability

**Unauthorized Access Attempt**:
1. Vault automatically logs failed authentication
2. Alert triggers on repeated failures
3. Investigate source IP and attempted access
4. Block at Cloudflare if external attack
5. Review all policies for over-permissiveness
6. Update policies and test

### Maintenance Windows

**Vault Upgrade Process**:
1. Announce maintenance window (planned downtime)
2. Snapshot current state (backup)
3. Seal Vault gracefully
4. Upgrade Docker image to new version
5. Start new container with same volumes
6. Unseal Vault
7. Verify health checks pass
8. Test critical workflows (bot auth, API gateway)
9. Monitor for 24 hours post-upgrade

**Volume Expansion**:
1. Monitor disk usage trends
2. Plan expansion before 80% utilization
3. Schedule maintenance window
4. Stop Vault container
5. Expand volume in underlying storage
6. Start Vault container
7. Verify expanded capacity

---

## Scaling & Future Growth

### Horizontal Scaling Triggers

**When to Consider HA Cluster**:
- Vault becomes critical path for > 10 production services
- SLA requirements exceed single-instance capabilities
- Geographic distribution requires local Vault instances
- Request volume exceeds 100 req/sec sustained

**Migration Path to HA**:
1. Add Consul or Raft storage backend
2. Deploy 3-5 Vault nodes in cluster
3. Configure load balancer in front of cluster
4. Migrate secrets from file backend to new backend
5. Test failover scenarios
6. Update client applications to use cluster endpoint

### Additional Use Cases

**Database Credential Management**:
- Enable database secrets engine
- Generate dynamic PostgreSQL/MySQL credentials
- Automatic credential rotation (TTL-based)
- Bot never stores long-lived DB passwords

**PKI for Internal Services**:
- Enable PKI secrets engine
- Issue short-lived certificates for service-to-service mTLS
- Automatic certificate renewal
- No manual certificate management

**Encryption as a Service**:
- Enable transit secrets engine
- Applications send plaintext to Vault for encryption
- Vault returns ciphertext (key never exposed)
- Use case: Encrypt trading strategy configs at rest

**CI/CD Integration**:
- GitHub Actions / GitLab CI authenticates to Vault
- Retrieves deployment credentials dynamically
- No secrets stored in CI configuration
- Time-limited tokens for each pipeline run

### Cost Projections

**Current State (Single Instance)**:
- Infrastructure: $0 (self-hosted on existing lab hardware)
- Operational overhead: 2-4 hours/month
- Backup storage: $5/month (cloud object storage)

**HA Cluster (Future)**:
- Infrastructure: 3x compute resources (~$300/month if cloud-hosted)
- Operational overhead: 4-8 hours/month (increased complexity)
- Backup storage: $15/month (3x volume)
- Load balancer: $20/month

**Break-Even Analysis**:
- Current solution sufficient until lab grows 5-10x
- HA justified when downtime cost > $10k/hour
- For dev lab: Single instance optimal for 2-3 years

### Long-Term Roadmap

**Q1 2025**: Foundation
- ✅ Deploy single Vault instance
- ✅ Migrate Cardano bot secrets
- ✅ API key issuance for testnet access

**Q2 2025**: Expansion
- Enable dynamic secrets for databases
- Integrate additional projects (2-3 services)
- Implement automated secret rotation

**Q3 2025**: Hardening
- Add monitoring and alerting
- Disaster recovery testing (quarterly)
- Policy refinement based on usage patterns

**Q4 2025**: Advanced Features
- Transit engine for encryption as a service
- AppRole authentication for automated deployments
- Consider HA if usage justifies

**2026+**: Maturity
- Evaluate Vault Enterprise (if compliance needs grow)
- Kubernetes integration (if migrating to K8s)
- Multi-region deployment (if geographic distribution required)

---

## Implementation Phases: KISS + YAGNI Approach

This section breaks down the full architecture into three pragmatic implementation phases based on actual needs, not theoretical requirements.

---

## Phase 1: IMMEDIATE - Single Admin Vault (Current Need)

### Timeline: Week 1 - Deploy and Use

**Reality Check**: You're one person. You need secrets stored securely NOW. Everything else is future planning.

### What You Actually Deploy

**Container Setup**:
- Single Vault container with persistent volume
- File-based storage backend (simplest option)
- Runs on your existing Docker infrastructure
- Health check configured but no auto-restart (requires manual unseal)

**Initialization Strategy**:
- Initialize with **1 unseal key only** (not 3-of-5 Shamir)
- You're the only admin, no quorum needed
- Store unseal key securely (password manager, hardware token)
- Generate root token, use it to set up, then revoke it

**Authentication**:
- Token-based only (no AppRole, no Kubernetes auth yet)
- You create tokens manually as needed via CLI
- Tokens have reasonable TTLs (7-30 days)

**Secrets Organization**:
```
secret/
├── cardano/
│   ├── mainnet/signing-key
│   ├── mainnet/collateral-utxo
│   ├── mainnet/maestro-api-key
│   └── testnet/signing-key
└── api-tokens/
    └── (external user tokens stored here)
```

**Policies**:
Three policies only:
1. **admin-policy**: You. Full access to everything.
2. **bot-policy**: Trading bot can read cardano/* secrets only.
3. **external-readonly**: External users can access their specific token for node API.

**Backup Strategy**:
- Daily cron job snapshots `/vault/data` volume
- Encrypted with GPG and your existing backup key
- Copied to NAS or external drive (wherever you backup other lab stuff)
- Test restore once after initial setup, then quarterly

**Audit Logging**:
- Basic file-based audit log enabled
- Rotated daily, kept for 30 days
- You grep through it if something suspicious happens
- No SIEM integration, no real-time alerts (yet)

**API Gateway Integration**:
- Simple middleware in your reverse proxy (Nginx/Traefik)
- Extracts Bearer token from header
- Validates against Vault
- Proxies to Cardano node if valid
- Returns 401 if invalid
- That's it. No rate limiting, no fancy analytics (yet).

**What You DON'T Build**:
- ❌ Multi-admin unseal (you're the only admin)
- ❌ High availability cluster (single instance is fine)
- ❌ Complex policy hierarchies (three policies total)
- ❌ Dynamic secrets (static secrets work fine)
- ❌ Detailed monitoring dashboards (health check is enough)
- ❌ Incident response procedures (it's just you)

**Deployment Time**: 30-60 minutes including testing

**Success Criteria**:
- ✅ Vault container running and unsealed
- ✅ Trading bot retrieves signing key successfully
- ✅ External user can access testnet node with issued token
- ✅ Backup completes successfully
- ✅ You can restore from backup

---

## Phase 2: GROWTH - Multi-Service Vault (3-6 Months Out)

### Timeline: When You Add 2-3 More Projects or 5+ External Users

**Trigger Events**:
- You deploy second or third service needing secrets
- External user count exceeds 5 people
- You're manually managing too many tokens
- Audit log becomes important for compliance/tracking
- Downtime starts costing you time/money

### What Changes from Phase 1

**Secret Organization Expands**:
```
secret/
├── cardano/
│   └── (existing structure)
├── project-2/
│   └── (new project secrets)
├── project-3/
│   └── (another project)
└── infrastructure/
    ├── cloudflare-api
    ├── backup-credentials
    └── monitoring-tokens
```

**Policy Refinement**:
- Add policies per project (5-10 total policies)
- Each service gets minimum required access
- External users grouped by access tier (free/research/partner)
- Start using policy templating for similar patterns

**Authentication Upgrade**:
- Add AppRole for automated service authentication
- Services get Role ID + Secret ID instead of long-lived tokens
- Secret IDs delivered via CI/CD or orchestration
- Tokens still used for external API access

**Monitoring Addition**:
- Enable Prometheus metrics endpoint
- Basic Grafana dashboard showing request rate, token count
- Alert on Vault sealed status (email/Slack/Discord)
- Alert on backup failures
- Weekly review of audit logs for anomalies

**Backup Improvement**:
- Automated verification of backup integrity
- Off-site backup copy (cloud storage or second location)
- Document tested restore procedure
- Monthly restore test (not just quarterly)

**API Gateway Enhancement**:
- Add rate limiting per token (requests/hour)
- Basic usage tracking (requests per token per day)
- Simple admin dashboard showing token usage
- Automatic suspension of tokens exceeding limits

**Operational Changes**:
- Document token issuance procedure (checklist)
- Create runbook for common operations
- Set calendar reminders for secret rotation
- Regular policy review (monthly)

**Still NOT Doing**:
- ❌ HA cluster (single instance still fine for < 10 services)
- ❌ Multi-admin unseal (still just you)
- ❌ Geographic distribution
- ❌ Enterprise compliance features
- ❌ Complex incident response procedures

**Deployment Effort**: 1-2 days to migrate existing setup + add new features

**Success Criteria**:
- ✅ 3+ services using Vault successfully
- ✅ 5-10 external users with API tokens
- ✅ Basic monitoring shows system health
- ✅ Backups verified and restorable
- ✅ You spend < 1 hour/week on Vault operations

---

## Phase 3: ENTERPRISE - Full-Featured Vault (12+ Months / Heavy Growth)

### Timeline: When Lab Becomes Production Infrastructure

**Trigger Events**:
- Supporting 10+ production services
- External user count exceeds 50 people
- Downtime costs > $1000/hour
- Compliance requirements (audit, SLA, certifications)
- Multiple administrators needed
- Geographic distribution required
- You're getting paid for services (commercialization)

### Major Architectural Changes

**High Availability Cluster**:
- 3-5 Vault nodes in cluster configuration
- Raft or Consul storage backend (replicated)
- Load balancer in front of cluster
- Automatic failover between nodes
- Geographic distribution if multi-region

**Multi-Admin Operations**:
- NOW you implement 3-of-5 Shamir unseal
- Unseal keys distributed to multiple administrators
- Break-glass procedures for emergency access
- Separation of duties (security admin vs operations admin)

**Advanced Secret Engines**:
- Database secrets engine (dynamic DB credentials)
- PKI secrets engine (internal certificate authority)
- Transit engine (encryption as a service)
- SSH secrets engine (one-time SSH passwords)

**Enterprise Features**:
- Namespaces for tenant isolation (if multi-tenant)
- Sentinel policies for policy-as-code enforcement
- Disaster recovery replication to secondary cluster
- Performance replication for read scalability
- HSM integration for unseal keys (optional)

**Comprehensive Monitoring**:
- Full observability stack (Prometheus + Grafana + Loki)
- Real-time alerting (PagerDuty/OpsGenie integration)
- SLO/SLI tracking (uptime, latency, error rate)
- Capacity planning dashboards
- Cost analysis and optimization

**Advanced API Gateway**:
- Full API management platform (Kong, Tyk, or Apigee)
- Advanced rate limiting (burst, quota, throttling)
- Usage-based billing integration (if commercializing)
- Analytics and reporting dashboards
- Developer portal for self-service token management

**Security Hardening**:
- Security audit by third party
- Penetration testing
- Compliance certifications (SOC 2, ISO 27001 if needed)
- Automated policy testing
- Secret rotation enforcement

**Operational Maturity**:
- 24/7 on-call rotation (if multi-admin team)
- Detailed incident response playbooks
- Regular disaster recovery drills
- Change management process
- SLA commitments to users

**Backup & DR**:
- Automated backup to multiple geographic locations
- < 15 minute RTO (recovery time objective)
- < 1 hour RPO (recovery point objective)
- Annual DR test with full failover
- Documented and tested recovery procedures

**Deployment Effort**: 2-4 weeks for migration + testing

**Success Criteria**:
- ✅ 99.9%+ uptime over 90 days
- ✅ < 100ms p95 latency for token validation
- ✅ Supporting 10+ production services
- ✅ 50+ external users with self-service token management
- ✅ Passed security audit and compliance review
- ✅ Documented and tested DR procedures
- ✅ < 4 hours/month operational overhead (automated)

---

## Decision Tree: When to Advance Phases

**Stay in Phase 1 If**:
- Single developer (just you)
- < 3 services using Vault
- < 10 external users
- Downtime acceptable (not production-critical)
- Manual operations tolerable

**Move to Phase 2 When**:
- 2+ services needing secrets
- 5+ external users
- Manual token management becomes tedious
- Audit log review needed monthly
- Backup automation saves significant time

**Move to Phase 3 When**:
- 10+ production services
- 50+ external users
- Downtime costs exceed $1k/hour
- Compliance requirements mandate HA
- Multiple administrators needed
- You're commercializing services

---

## Architecture Future-Proofing

**Design Decisions That Support All Phases**:

1. **Storage Backend**: File storage in Phase 1 can migrate to Raft/Consul in Phase 3 without application changes.

2. **Secret Paths**: Hierarchical structure from Phase 1 scales naturally as you add projects.

3. **Policy Model**: Simple policies in Phase 1 use same syntax as complex policies in Phase 3.

4. **Token Authentication**: Phase 1 tokens work identically in Phase 2 and 3 (AppRole is additive).

5. **Audit Logging**: File-based logs in Phase 1 can ship to SIEM in Phase 3 without format changes.

6. **API Gateway Pattern**: Simple validation in Phase 1 extends to sophisticated features in Phase 3 without redesign.

**What You Build Once and Never Change**:
- Secret path hierarchy (get it right in Phase 1)
- Policy naming conventions
- Token metadata structure
- Audit log format
- Backup encryption approach

**What You Can Defer Safely**:
- High availability (add only when needed)
- Advanced monitoring (basic health checks sufficient initially)
- Complex policies (start simple, refine as you learn)
- Automated rotation (manual is fine for few secrets)
- Multi-admin procedures (overkill for solo operation)

---

## Recommended Starting Point

**For Your Current Situation** (solo developer, Cardano trading bot + external node access):

→ **Start with Phase 1 IMMEDIATELY**

**Deployment Plan**:
- **Day 1**: Deploy Vault container, initialize with 1 unseal key, create 3 basic policies
- **Day 2**: Migrate Cardano bot secrets, test bot authentication
- **Day 3**: Set up API gateway token validation, issue first external token
- **Day 4**: Configure daily backup, test restore
- **Day 5**: Document everything, call it done

**Re-evaluate in 3 months** and check if Phase 2 triggers apply.

**Keep Phase 3 architecture doc** as reference for "someday" - but don't build it until you actually need it.

---

## Conclusion

The full architecture document describes the **destination**, but this phased approach describes the **journey**. You don't need to build enterprise infrastructure to store a few secrets securely.

**Phase 1 gives you**:
- ✅ Secure secret storage (better than files or environment variables)
- ✅ API token issuance (solves your external user problem)
- ✅ Basic audit trail (grep-able logs)
- ✅ Simple backup/restore (disaster recovery basics)
- ✅ **< 1 hour deployment time**
- ✅ **< 30 minutes/month operational overhead**

**The full architecture remains valuable** as a roadmap showing where you CAN go as needs grow, but it's not prescriptive about where you MUST start.

Build what you need now. Expand when the pain justifies the complexity. That's KISS + YAGNI in practice.

---

**Document Version**: 2.0  
**Last Updated**: 2025-01-19  
**Author**: Development Lab Architecture Team  
**Review Cycle**: Re-evaluate phase every 3 months or when trigger events occur