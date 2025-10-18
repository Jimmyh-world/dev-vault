#!/bin/bash
# Vault Health Check Script
# Usage: ./check-vault-health.sh

echo "=== Vault Health Check ==="
echo "Timestamp: $(date)"
echo ""

# Check container running
echo "1. Container Status:"
docker ps --filter name=vault --format "  {{.Names}}: {{.Status}}" || echo "  Unable to check"
echo ""

# Check Vault health endpoint
echo "2. Vault Health:"
HEALTH=$(curl -s http://localhost:8200/v1/sys/health)
echo "  Initialized: $(echo $HEALTH | jq -r .initialized 2>/dev/null || echo 'N/A')"
echo "  Sealed: $(echo $HEALTH | jq -r .sealed 2>/dev/null || echo 'N/A')"
echo "  Standby: $(echo $HEALTH | jq -r .standby 2>/dev/null || echo 'N/A')"
echo ""

# Check audit log size (from container)
echo "3. Audit Log:"
AUDIT_INFO=$(docker exec vault ls -lh /vault/logs/audit.log 2>/dev/null | awk '{print $5, $NF}' || echo "Not found")
if [ "$AUDIT_INFO" != "Not found" ]; then
  echo "  File size: $(echo $AUDIT_INFO | awk '{print $1}')"
  LINES=$(docker exec vault wc -l /vault/logs/audit.log 2>/dev/null | awk '{print $1}' || echo "N/A")
  echo "  Entries: $LINES"
else
  echo "  Not found"
fi
echo ""

# Check resource usage
echo "4. Resource Usage:"
docker stats vault --no-stream --format "  CPU: {{.CPUPerc}} | Memory: {{.MemUsage}}" 2>/dev/null || echo "  Unable to check"
echo ""

echo "=== Health Check Complete ==="
