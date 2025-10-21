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
