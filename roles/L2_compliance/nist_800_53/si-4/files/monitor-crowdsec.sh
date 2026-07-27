#!/usr/bin/env bash
# ==============================================================================
# CrowdSec Health Monitor - L1/L2 Compliance Check (NIST SI-4, AU-12)
# Quick health snapshot: metrics, service status, recent decisions, disk usage.
# ==============================================================================
set -euo pipefail

echo "=== CrowdSec Metrics ==="
cscli metrics 2>/dev/null || echo "ERROR: cscli metrics failed"

echo ""
echo "=== Service Status ==="
systemctl status crowdsec --no-pager -l 2>/dev/null || echo "ERROR: crowdsec service not running"

echo ""
echo "=== Last 5 Decisions ==="
cscli decisions list -o json 2>/dev/null | python3 -c "
import json,sys
data=json.load(sys.stdin)
for d in data[:5]:
    print(f\"  {d.get('value','?')} | {d.get('reason','?')} | {d.get('action','?')} | {d.get('expires_at','?')}\")
" 2>/dev/null || cscli decisions list 2>/dev/null | head -6 || echo "ERROR: cscli decisions failed"

echo ""
echo "=== Disk Usage ==="
df -h /var/lib/crowdsec 2>/dev/null || echo "No /var/lib/crowdsec partition"
echo ""
df -h / /var/log 2>/dev/null | grep -v ^Filesystem
