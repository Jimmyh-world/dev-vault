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
