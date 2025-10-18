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
