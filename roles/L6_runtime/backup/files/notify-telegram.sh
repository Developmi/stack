#!/usr/bin/env bash
# notify-telegram.sh - Send backup summary via Telegram Bot API
# Called by restic-backup-all.sh wrapper with per-script status.
# Failure MUST NOT exit non-zero (spec R.6).
#
# Usage: notify-telegram.sh <hostname> <vol-status> <vol-count>
set -uo pipefail

# shellcheck source=/dev/null
source /etc/restic/env

HOSTNAME="${1:-unknown}"
VOL_STATUS="${2:-?}"
VOL_COUNT="${3:-0}"

# Build summary message
SUMMARY="📦 ${HOSTNAME} Backup Summary
"

# Volumes status line
if [ "$VOL_STATUS" = "OK" ]; then
    SUMMARY="${SUMMARY}✅ volumes: OK (${VOL_COUNT} snapshots)
"
elif [ "$VOL_STATUS" = "SKIPPED" ]; then
    SUMMARY="${SUMMARY}⏭️ volumes: SKIPPED (no config)
"
else
    SUMMARY="${SUMMARY}❌ volumes: FAILED
"
fi

# Send via Telegram Bot API - failure MUST NOT exit non-zero (spec R.6)
curl -s --max-time 10 -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
    -d "chat_id=${TELEGRAM_CHAT_ID}" \
    -d "text=${SUMMARY}" \
    -d "parse_mode=HTML" \
    > /dev/null 2>&1 || true
