#!/bin/bash
# Vault Policy Management Script
# Usage: VAULT_TOKEN=<token> ./manage-policies.sh [list|read|write|delete] [policy-name]

set -e

VAULT_ADDR="${VAULT_ADDR:-http://127.0.0.1:8200}"
COMMAND=$1
POLICY_NAME=$2

if [ -z "$VAULT_TOKEN" ]; then
  echo "Error: VAULT_TOKEN environment variable not set"
  exit 1
fi

case $COMMAND in
  list)
    docker exec -e VAULT_ADDR="$VAULT_ADDR" -e VAULT_TOKEN="$VAULT_TOKEN" vault vault policy list
    ;;
  read)
    if [ -z "$POLICY_NAME" ]; then
      echo "Usage: $0 read <policy-name>"
      exit 1
    fi
    docker exec -e VAULT_ADDR="$VAULT_ADDR" -e VAULT_TOKEN="$VAULT_TOKEN" vault vault policy read "$POLICY_NAME"
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
    docker exec -e VAULT_ADDR="$VAULT_ADDR" -e VAULT_TOKEN="$VAULT_TOKEN" vault \
      vault policy write "$POLICY_NAME" "/vault/policies/$POLICY_NAME.hcl"
    ;;
  delete)
    if [ -z "$POLICY_NAME" ]; then
      echo "Usage: $0 delete <policy-name>"
      exit 1
    fi
    docker exec -e VAULT_ADDR="$VAULT_ADDR" -e VAULT_TOKEN="$VAULT_TOKEN" vault vault policy delete "$POLICY_NAME"
    ;;
  *)
    echo "Usage: $0 [list|read|write|delete] [policy-name]"
    echo ""
    echo "Examples:"
    echo "  List all policies:"
    echo "    VAULT_TOKEN=<token> $0 list"
    echo ""
    echo "  Read a policy:"
    echo "    VAULT_TOKEN=<token> $0 read bot-policy"
    echo ""
    echo "  Write a policy:"
    echo "    VAULT_TOKEN=<token> $0 write admin-policy"
    echo ""
    echo "  Delete a policy:"
    echo "    VAULT_TOKEN=<token> $0 delete external-readonly"
    exit 1
    ;;
esac
