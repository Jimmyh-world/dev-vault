#!/bin/bash
# Vault Token Creation Script
# Usage: VAULT_TOKEN=<token> ./create-token.sh <policy-name> <ttl> [display-name]

set -e

VAULT_ADDR="${VAULT_ADDR:-http://127.0.0.1:8200}"
POLICY=$1
TTL=$2
DISPLAY_NAME=${3:-"unnamed-token"}

if [ -z "$VAULT_TOKEN" ]; then
  echo "Error: VAULT_TOKEN environment variable not set"
  exit 1
fi

if [ -z "$POLICY" ] || [ -z "$TTL" ]; then
  echo "Usage: $0 <policy-name> <ttl> [display-name]"
  echo ""
  echo "Examples:"
  echo "  Create a bot token valid for 7 days:"
  echo "    VAULT_TOKEN=<admin-token> $0 bot-policy 7d production-bot"
  echo ""
  echo "  Create an external researcher token valid for 30 days:"
  echo "    VAULT_TOKEN=<admin-token> $0 external-readonly 30d researcher-alice"
  echo ""
  echo "  Create a temporary test token valid for 1 hour:"
  echo "    VAULT_TOKEN=<admin-token> $0 admin-policy 1h test-admin"
  exit 1
fi

echo "Creating token with policy: $POLICY, TTL: $TTL, Display Name: $DISPLAY_NAME"
echo ""

docker exec -e VAULT_ADDR="$VAULT_ADDR" -e VAULT_TOKEN="$VAULT_TOKEN" vault \
  vault token create \
    -policy="$POLICY" \
    -ttl="$TTL" \
    -display-name="$DISPLAY_NAME" \
    -format=json | jq .

echo ""
echo "Token created successfully! Store the client_token securely."
