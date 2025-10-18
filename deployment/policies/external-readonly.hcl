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
