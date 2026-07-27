#!/usr/bin/env bash
# restic-backup-all.sh - L6 Runtime Backup Wrapper
# Runs volumes-only backup (app data dumps handled by L5 backup role per ADR-09).
# Collects exit code, fires Telegram notification, always exits 0.
# Per design D.10: systemd sees success, Telegram IS the alert channel.
set -uo pipefail

# shellcheck source=/dev/null
set -a; source /etc/restic/env; set +a

LOG_FILE="/var/log/restic/backup.log"

# Ensure log directory exists
mkdir -p "$(dirname "$LOG_FILE")"

{
    echo "=== Backup started $(date -Iseconds) ==="

    declare -A RESULTS
    declare -A SNAPSHOT_COUNTS

    # --- Docker Volumes (runtime state only) ---
    echo "--- Docker Volumes ---"
    if timeout 15m /usr/local/bin/restic-backup-volumes.sh; then
        RESULTS[volumes]="OK"
        SNAPSHOT_COUNTS[volumes]=$(restic snapshots --tag volumes --compact 2>/dev/null | grep -c '^[a-f0-9]\{8\}' || echo "0")
    else
        RESULTS[volumes]="FAILED"
        SNAPSHOT_COUNTS[volumes]="0"
    fi

    # --- Notification (always fires - failure does not alter exit code) ---
    /usr/local/bin/notify-telegram.sh "$(hostname)" \
        "${RESULTS[volumes]:-SKIPPED}" "${SNAPSHOT_COUNTS[volumes]:-0}" \
        || true

    echo "=== Backup finished $(date -Iseconds) ==="
} >> "$LOG_FILE" 2>&1

# Always exit 0 - systemd sees success, Telegram IS the alert channel (design D.10)
exit 0
