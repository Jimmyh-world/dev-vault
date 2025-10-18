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
