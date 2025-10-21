#!/bin/sh
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
