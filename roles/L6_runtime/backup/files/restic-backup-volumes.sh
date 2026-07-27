#!/usr/bin/env bash
# restic-backup-volumes.sh - Backup paths from /etc/restic/backup-paths.conf
# Reads paths from config file, tars each and pipes to restic --stdin.
# Skips gracefully if config is missing or empty.
set -uo pipefail

# shellcheck source=/dev/null
set -a; source /etc/restic/env; set +a

# Ensure cache dir exists (belt-and-suspenders: env exports it, but mkdir guarantees)
mkdir -p "${RESTIC_CACHE_DIR:-/var/cache/restic}"

TAG="volumes"
PATHS_CONF="/etc/restic/backup-paths.conf"

if [ ! -f "$PATHS_CONF" ]; then
    echo "[$TAG] No backup paths config found at $PATHS_CONF - skipping."
    exit 0
fi

BACKUP_COUNT=0
FAIL_COUNT=0

while IFS= read -r BACKUP_PATH; do
    # Skip empty lines and comments
    [[ -z "$BACKUP_PATH" || "$BACKUP_PATH" =~ ^[[:space:]]*# ]] && continue

    # Trim whitespace
    BACKUP_PATH=$(echo "$BACKUP_PATH" | xargs)

    if [ ! -e "$BACKUP_PATH" ]; then
        echo "[$TAG] WARNING: Path not found - $BACKUP_PATH - skipping."
        continue
    fi

    # Create a safe filename from the path
    SAFE_NAME=$(echo "$BACKUP_PATH" | sed 's|^/||; s|/|_|g')
    PARENT=$(dirname "$BACKUP_PATH")
    BASENAME=$(basename "$BACKUP_PATH")

    echo "[$TAG] Backing up: $BACKUP_PATH → ${SAFE_NAME}.tar.gz"

    # Tar piped directly to restic - zero disk footprint
    # Uses PIPESTATUS to only fail on restic error (not tar exit code quirks)
    tar czf - \
        --exclude='*.key' --exclude='.env' --exclude='*.pem' \
        --exclude='*credentials*' --exclude='*secret*' \
        --ignore-failed-read --warning=no-file-changed \
        -C "$PARENT" "$BASENAME" 2>/dev/null | \
        restic backup --stdin --stdin-filename "${SAFE_NAME}.tar.gz" \
            --tag "$TAG"
    RESTIC_EXIT=${PIPESTATUS[1]}
    if [ "$RESTIC_EXIT" -eq 0 ]; then
        BACKUP_COUNT=$((BACKUP_COUNT + 1))
        echo "[$TAG] OK: $BACKUP_PATH"
    else
        FAIL_COUNT=$((FAIL_COUNT + 1))
        echo "[$TAG] FAILED: $BACKUP_PATH (restic exit $RESTIC_EXIT)"
    fi
done < "$PATHS_CONF"

echo "[$TAG] Volumes backup complete: ${BACKUP_COUNT} succeeded, ${FAIL_COUNT} failed."

# Post-backup forget (inline, no --prune per design D.5)
restic forget --tag "$TAG" --keep-daily 7 --keep-weekly 4 --keep-monthly 3 || true

if [ "$FAIL_COUNT" -gt 0 ]; then
    exit 1
fi
