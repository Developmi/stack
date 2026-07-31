---
title: Backup Strategy
type: operations
owner: maintainers
audience: operator
version: v6.0.0
last-reviewed: 2026-07-31
status: active
project: developmi-stack
repo: github.com/Developmi/stack
---

# Backup Strategy

Two-layer backup architecture for the Developmi Stack platform, covering application data (L5) and runtime state (L6). This document describes the mechanisms, schedules, retention policies, verification methods, and restore procedures.

**Source of truth caveat**: Tier-level backup policy - schedules, retention, and verification per DR tier - is the SSOT in §4 of this document (updated 2026-07-31 with the DR-tier model). Per-app values are declared in `apps/*/profile.yml` and MUST stay in sync with this document (SCE-BAK-006).

---

## 1. Backup Architecture Overview

The platform separates backup into two independent layers per [ADR-09](../architecture/adr/ADR-09.md) (now superseded - both layers served by a single consolidated `roles/L6_runtime/backup/` role with `backup_role_source` dispatch):

| Layer  | Role                       | What It Protects                                                | Restic Repo Prefix | Mechanism                  |
| ------ | -------------------------- | --------------------------------------------------------------- | ------------------ | -------------------------- |
| **L5** | `roles/L6_runtime/backup/` | Application data: database dumps, uploads, config files         | `restic/`          | Ephemeral Docker container |
| **L6** | `roles/L6_runtime/backup/` | Runtime state: Docker volumes, Portainer configs, Compose state | `stack-restic/`    | Installed Restic binary    |

### Why Two Layers?

L5 and L6 are intentionally separate - they protect different things with different recovery paths and different schedules:

- **App data** (L5) changes every few minutes (user-generated content, workflow state, analytics). tier1 app backups run every 4 hours; tier2 daily; tier3 weekly (see §4).
- **Runtime state** (L6) changes infrequently (Docker configs, volume data). Backups run once daily.

### Boundary Contract

```
L5 - backup:       NEVER touches Portainer configs, Compose state, Docker daemon
L6 - backup:        NEVER touches DB dumps, app uploads, app config files
```

This contract ensures independent recovery: you can restore a database without touching runtime state, and vice versa. If a restore goes wrong, only one layer is affected.

### Restic Repo Prefix Isolation

| Layer | Prefix          | Example Repository Path                                        |
| ----- | --------------- | -------------------------------------------------------------- |
| L5    | `restic/`       | `s3://<r2-endpoint>/nist-backups-prod/restic/<hostname>`       |
| L6    | `stack-restic/` | `s3://<r2-endpoint>/nist-backups-prod/stack-restic/<hostname>` |

The separate prefixes prevent cross-contamination - an L5 retention policy never prunes L6 snapshots, and vice versa.

---

## 2. L5 - Application Data Backup

### 2.1 Two L5 Mechanisms

L5 application data backup uses two separate mechanisms that serve different purposes:

| Aspect           | Playbook Restic Backup                             | Systemd Timer S3 Pipe          |
| ---------------- | -------------------------------------------------- | ------------------------------ |
| Entry point      | `ansible-playbook playbooks/l6/backup-appdata.yml` | systemd `backup-db-*.timer`    |
| Orchestrator     | Ansible (playbook)                                 | systemd (independent per-host) |
| Database dump    | `pre_dump.yml` (auto-detect containers)            | `docker exec` inline in unit   |
| Upload mechanism | Restic `restic/restic:0.19.0` → R2                 | `aws s3 cp` pipe → R2          |
| Restic retention | `forget --prune` (daily/weekly/monthly)            | NONE (raw dumps accumulate)    |
| Notification     | Telegram on failure only                           | NONE                           |
| Scope            | Inventory group `brain` only                       | All hosts with profiles        |
| Invocation       | Manual / CI/CD                                     | Automatic on schedule          |

**Key difference**: The playbook provides full lifecycle backup (dump → Restic → retention → notify). The systemd timers provide **schedule-only** raw dump uploads - no Restic, no retention, no notification. Use the playbook for comprehensive protection; use timers for automated scheduled dumps between playbook runs.

**Note on R2 endpoint**: The `aws s3 cp` commands in systemd timer units use `backup_r2_endpoint` from `roles/L6_runtime/backup/defaults/main.yml`, which **defaults to empty**. If not overridden, all `aws s3 cp` calls will fail. Set `backup_r2_endpoint` to the R2 endpoint URL (format: `https://<account-id>.r2.cloudflarestorage.com`) in `inventory/group_vars/all/vars.yml` before deploying timers.

### Playbook-Based Restic Backup (Recommended)

The L5 playbook backup flow is orchestrated by `playbooks/l6/backup-appdata.yml` and follows this sequence:

1. **Gate check**: `enable_backups` must be `true`. If disabled, the playbook ends immediately.
2. **Phase 02 deactivation**: Temporarily pauses Phase 02 timers on all hosts in the `brain` inventory group to prevent conflicts.
3. **Pre-dump** (`roles/L6_runtime/backup/tasks/pre_dump.yml`): Auto-discovers database containers by Docker labels and creates dumps:
   - **PostgreSQL**: Containers with label `com.nist.type=postgresql` → `pg_dump -Fc` (custom format)
   - **MySQL**: Containers with label `com.nist.type=mysql` → `mysqldump`
   - **SQLite**: Resolved via `docker inspect` of known containers → `sqlite3 .backup`
   - **Valkey**: Containers with label `com.nist.type=valkey` → `SAVE` + copy `dump.rdb`
4. **Restic backup** (`roles/L6_runtime/backup/tasks/restic_backup.yml`): Ephemeral `restic/restic:0.19.0` container runs `restic backup /data` with the dump directory bind-mounted read-only, pushing to R2 at the `restic/` prefix.
5. **Retention** (`roles/L6_runtime/backup/tasks/retention.yml`): `restic forget --prune` via ephemeral container. Non-critical failure - backup is still reported as successful per ADR-07.
6. **Notification** (`roles/L6_runtime/backup/tasks/notify.yml`): Telegram notification on failure only (silent on success).

### Systemd Timer S3 Pipe (Schedule-Only)

The systemd timers deployed by `roles/L6_runtime/backup/` run independently on each host, executing per-app `docker exec` + `aws s3 cp` pipes without Restic, retention, or notification:

- Each app profile with a supported `db_type` (`postgres`, `mariadb`, `mysql`, `mongodb`, `sqlite`) generates a `backup-db-<app>.timer` unit. The app name is **derived from the profile directory path** (`apps/<name>/profile.yml` → `<name>`), validated against `^[a-z0-9_-]+$` before render; a legacy `name` field (pre-2026-07-31) is ignored.
- The timer's `ExecStart` runs: `docker exec <container> pg_dump ... | aws s3 cp - s3://<bucket>/db/<app>/<timestamp>.dump`
- Raw dump files accumulate in the R2 bucket under the `db/<app>/` prefix - **no retention**.
- **No Telegram notification** on failure. Failures are silent unless the operator monitors `systemctl` or `journalctl`.
- Apps with `db_type: none` or `db_type: custom` produce `ExecStart=/bin/false` - the timer fires but does nothing (openlit, `db_type: none`, renders no unit at all).

> **Declared, not executed (2026-07-31)**: `clickhouse-backup` and `file-volume` backup methods are **declared** in profiles but **not yet executed** by the role (it executes pg/mysql/mariadb/mongodb/sqlite today). clickhouse renders an `ExecStart=/bin/false` unit; uptime-kuma keeps an executable sqlite volume-tar with `volume_name: uptime-kuma_data` (its compose MUST name the volume exactly that). Execution support is future work (change `apps-stack-standardization`, Out of Scope).

The systemd timers are intended as scheduled dump automation **between** playbook-based Restic runs, not as a replacement for full-lifecycle backup.

### Target

L5 backup targets the **brain** host exclusively. All database containers live on the brain host, so L5 does not run on `muscle` or `local` nodes.

### Application Data Backup Scope

The suite provides backup for:

- **Database backup (L6_runtime/backup-db)** - SUPPORTED. Automated PostgreSQL dumps via playbook-based Restic (recommended) or systemd timer S3 pipes (schedule-only). See §2.1 for mechanisms.
- **Stack config backup (L6_runtime/backup)** - SUPPORTED. Caddy, Portainer, and monitoring stack state backed up via Restic binary (stack-restic prefix).
- **App data backup (L6_runtime/backup, app-data mode)** - EXPERIMENTAL. Database dumps and app file data via ephemeral Restic container. Not 100% tested in all scenarios.

> **Application data backup is the operator's responsibility.** The stack provides database backup and stack config backup as supported features. Per-app backup scope (uploads, file volumes, custom data directories) must be configured by the operator. The [INCIDENT_RESPONSE_DR.md](INCIDENT_RESPONSE_DR.md) document provides restore procedures for reference.

**Note**: All PostgreSQL dumps use custom format (`-Fc`), which supports selective restore of individual tables. Dump files are stored at `/srv/backup/dumps/` on the brain host before Restic upload.

---

## 3. L6 - Runtime Backup

### Mechanism

The L6 runtime backup is orchestrated by `roles/L6_runtime/backup/` and runs as a set of independent systemd timers:

1. **Binary installation**: Downloads and verifies `restic v0.19.0` binary (SHA256 verified per architecture).
2. **Credential configuration**: Deploys R2 API keys and Restic repository password via Ansible Vault (`no_log: true`).
3. **Repository initialization**: Initializes the Restic repository at `stack-restic/` prefix if not already initialized.
4. **Backup script**: Deploys `/usr/local/bin/restic-backup-all.sh` that backs up Docker volumes to R2.
5. **Systemd timers**: Deploys three systemd timer units:
   - `restic-backup-all.timer` - enabled immediately
   - `restic-check.timer` - deployed disabled (enable after first successful backup)
   - `restic-prune.timer` - deployed disabled (enable after first successful backup)
6. **Logrotate**: Configures log rotation for Restic backup logs.

### Target

L6 backup targets **all hosts** in the inventory. Each host backs up its own Docker volumes independently.

### Staggered Schedule

To avoid simultaneous backups across hosts, timers are staggered by inventory group:

| Group    | Backup Time | Check Time | Prune Time |
| -------- | ----------- | ---------- | ---------- |
| `brain`  | 02:00       | Sun 02:00  | Sat 02:00  |
| `muscle` | 03:00       | Sun 03:00  | Sat 03:00  |
| `local`  | 04:00       | Sun 04:00  | Sat 04:00  |

### Check and Prune Timers

By design (ADR-09, design D.9), check and prune timers are deployed in **disabled** state:

- `restic-check.timer` - disabled on initial deployment
- `restic-prune.timer` - disabled on initial deployment

The operator must enable them after the first successful backup cycle:

```bash
sudo systemctl enable --now restic-check.timer
sudo systemctl enable --now restic-prune.timer
```

This prevents running `restic check` or `restic forget --prune` against an empty or unverified repository.

---

## 4. Scheduling Reference

### L5 - Per-App Schedule (DR-Tier SSOT)

L5 backup timers are deployed by `roles/L6_runtime/backup/` from `apps/*/profile.yml`. Each dump-able profile generates a `backup-db-<app>.timer` + `backup-db-<app>.service` pair:

```bash
# List all L5 backup timers
systemctl list-timers "backup-db-*"
```

| Tier      | Apps                                                    | Schedule (systemd OnCalendar)           | Retention (daily/weekly/monthly) | Verification           |
| --------- | ------------------------------------------------------- | --------------------------------------- | -------------------------------- | ---------------------- |
| **tier1** | chatwoot, n8n, twenty-crm, metabase, nocodb             | every 4h (`*-*-* 00/4:00:00`)           | 7 / 4 / 12                       | monthly restore test   |
| **tier2** | openwebui, postgresql, clickhouse, mariadb, uptime-kuma | daily 02:30 (`*-*-* 02:30:00`)          | 14 / 8 / 12                      | quarterly restore test |
| **tier3** | openlit                                                 | weekly Sun 03:00 (`Sun *-*-* 03:00:00`) | 4 / 6                            | none                   |

Backup method per app type: **pg_dump** (chatwoot, n8n, twenty-crm, metabase, nocodb, openwebui, postgresql), **mysqldump** (mariadb), **clickhouse-backup** (clickhouse), **file-volume** (uptime-kuma, openlit).

> **Schedule syntax**: `backup.schedule` values are **systemd OnCalendar expressions** - the role renders the value directly into `OnCalendar=`. Cron syntax (`*/4 * * * *`) is NOT valid there.
>
> **Retention note**: retention values above are the declared tier policy in `apps/*/profile.yml` (themes). The current role execution applies the global restic retention (7/4/12, §5) - per-profile retention wiring is future work.

### L6 - Global Schedule

L6 backup uses a global schedule per host, managed independently from app profiles:

| Setting              | Value                                                                  | Source                                      |
| -------------------- | ---------------------------------------------------------------------- | ------------------------------------------- |
| Schedule variable    | `restic_backup_time_by_group` (brain=02:00, muscle=03:00, local=04:00) | `roles/L6_runtime/backup/defaults/main.yml` |
| Per-group staggering | brain=02:00, muscle=03:00, local=04:00                                 | `restic_backup_time_by_group`               |
| Check timer          | Weekly (Sunday) per group                                              | `restic_check_time_by_group`                |
| Prune timer          | Weekly (Saturday) per group                                            | `restic_prune_time_by_group`                |

### Timer Deployment Summary

| Role                       | Timer Format                | Deploys                               | Source of Schedule                     |
| -------------------------- | --------------------------- | ------------------------------------- | -------------------------------------- |
| `roles/L6_runtime/backup/` | `backup-db-<appname>.timer` | Systemd timers from profile schedules | `apps/*/profile.yml → backup.schedule` |
| `roles/L6_runtime/backup/` | `restic-backup-all.timer`   | Single global systemd timer per host  | `stack_backup_schedule` default        |

> **Note**: Both rows reference the same consolidated `roles/L6_runtime/backup/` role. L5 vs L6 behavior is selected via the `backup_role_source` variable at the playbook level.

---

## 5. Retention Policies

### L5 Retention

Enforced by `roles/L6_runtime/backup/` → `retention.yml` via ephemeral Restic container:

| Parameter        | Value                                              |
| ---------------- | -------------------------------------------------- |
| `--keep-daily`   | 7                                                  |
| `--keep-weekly`  | 4                                                  |
| `--keep-monthly` | 12                                                 |
| Mechanism        | `restic forget --prune` via ephemeral container    |
| Failure mode     | Non-critical (backup marked successful regardless) |

Source: `roles/L6_runtime/backup/defaults/main.yml` → `backup_keep_daily`, `backup_keep_weekly`, `backup_keep_monthly`.

> **Per-profile retention values**: The `retention_daily`, `retention_weekly`, and `retention_monthly` fields in `apps/*/profile.yml` are **reserved for future use** and are NOT consumed by the current backup implementation. To change L5 retention, override `backup_keep_daily`, `backup_keep_weekly`, or `backup_keep_monthly` in `inventory/group_vars/all/main.yml`. The Ansible defaults in `roles/L6_runtime/backup/defaults/main.yml` are the sole source of truth.

### L6 Retention

L6 retention uses a **two-phase** process, implemented by the `restic-backup-all.sh` script and a separate systemd prune timer:

#### Phase 1 - Inline Forget (No --prune)

- Runs immediately after each backup in `restic-backup-volumes.sh` (line 65).
- Command: `restic forget --tag volumes --keep-daily 7 --keep-weekly 4 --keep-monthly 3`
- **NO `--prune` flag** - marks snapshots for deletion but does NOT reclaim space.
- Non-critical failure (`|| true`) - a failed forget does not block the backup.
- Runs every backup cycle (daily for most hosts).

| Parameter        | Value                                           |
| ---------------- | ----------------------------------------------- |
| `--keep-daily`   | 7                                               |
| `--keep-weekly`  | 4                                               |
| `--keep-monthly` | 3                                               |
| Mechanism        | `restic forget` (no `--prune`) in backup script |
| Failure mode     | Non-critical - does not block backup            |

#### Phase 2 - Separate Prune Timer

- Runs via `restic-prune` systemd timer (deployed **disabled**).
- Full `restic forget --keep-daily 7 --keep-weekly 4 --keep-monthly 3 --prune`.
- Reclaims space from snapshots marked by Phase 1.
- Runs weekly (Saturday for brain, configurable per group).
- Must be **manually enabled** by the operator after first successful backup cycle:

```bash
sudo systemctl enable --now restic-prune.timer
```

**Net effect**: Backups cannot be blocked by a slow prune. Marking snapshots for deletion happens immediately (Phase 1), while space reclamation runs independently (Phase 2). Until the prune timer is enabled, snapshots marked by Phase 1 accumulate and no space is reclaimed.

---

## 6. Verification

### Confirm Backups Are Running

**L5 - Application Data Backup:**

```bash
# List L5 backup timers (systemd S3 pipe)
systemctl list-timers "backup-db-*"

# Check status of a specific app timer
systemctl status backup-db-nocodb.timer

# View L5 backup logs (systemd S3 pipe)
journalctl -u backup-db-nocodb.service --since "1 hour ago"
```

> **Note**: The systemd S3-pipe timers listed above have **no retention** and **no Telegram notification**. A successful timer execution means the raw dump was uploaded to R2, but it does NOT mean the data is protected by Restic retention. For full-lifecycle verification (Restic snapshots, retention), run the playbook-based L5 backup and inspect the Restic repository directly.

**L6 - Runtime Backup:**

```bash
# Check the backup-all timer status
systemctl status restic-backup-all.timer

# List all L6 timers
systemctl list-timers "restic-*"

# View L6 backup logs
journalctl -u restic-backup-all.service --since "1 day ago"
```

### Inspect Restic Snapshots

**L5 snapshots** (via ephemeral container):

```bash
docker run --rm \
  -e RESTIC_REPOSITORY="s3://<r2-endpoint>/nist-backups-prod/restic/<hostname>" \
  -e RESTIC_PASSWORD="<vault-password>" \
  -e AWS_ACCESS_KEY_ID="<r2-key>" \
  -e AWS_SECRET_ACCESS_KEY="<r2-secret>" \
  -e AWS_DEFAULT_REGION="auto" \
  restic/restic:0.19.0 \
  snapshots
```

**L6 snapshots** (via installed binary):

```bash
sudo RESTIC_REPOSITORY="s3://<r2-endpoint>/nist-backups-prod/stack-restic/<hostname>" \
  RESTIC_PASSWORD="<vault-password>" \
  AWS_ACCESS_KEY_ID="<r2-key>" \
  AWS_SECRET_ACCESS_KEY="<r2-secret>" \
  restic snapshots
```

### Manual Backup Invocation

```bash
# L5: Run the full L5 backup playbook
make deploy-backups

# Or directly:
ansible-playbook -i inventory/hosts.ini playbooks/l6/backup-appdata.yml \
  --vault-password-file /tmp/.vault_pass
```

### Telegram Notifications

The L5 backup role sends a Telegram notification on **failure only**. If backups are working, expect silence. If a notification arrives, check the backup logs immediately.

---

## 7. Restore Procedure Summary

Full disaster recovery procedures are documented in [`docs/operations/INCIDENT_RESPONSE_DR.md`](../operations/INCIDENT_RESPONSE_DR.md). This section provides a high-level reference.

### L5 - Restore Application Data

1. **Locate the snapshot**: Use the `restic/` repo prefix. List snapshots to find the desired restore point.
2. **Restore the dump files**:
   ```bash
   docker run --rm \
     -v /srv/backup/dumps:/data \
     -e RESTIC_REPOSITORY="s3://<r2-endpoint>/nist-backups-prod/restic/<hostname>" \
     -e RESTIC_PASSWORD="<vault-password>" \
     -e AWS_ACCESS_KEY_ID="<r2-key>" \
     -e AWS_SECRET_ACCESS_KEY="<r2-secret>" \
     restic/restic:0.19.0 \
     restore <snapshot-id> --target /data
   ```
3. **Restore the database**:
   - **PostgreSQL**: `pg_restore -U <user> -d <db_name> <dump_file>`
   - **MySQL**: `mysql -u <user> -p <db_name> < <dump_file>`
   - **SQLite**: Copy `.db` file to container volume
   - **Valkey**: Copy `dump.rdb` to `/data/` and restart the container
4. **Verify app health**: Check the app's health endpoint (e.g., `curl -f http://localhost:<port>/health`).

### L6 - Restore Runtime State

1. **Locate the snapshot**: Use the `stack-restic/` repo prefix.
2. **Restore volumes**:
   ```bash
   sudo RESTIC_REPOSITORY="s3://<r2-endpoint>/nist-backups-prod/stack-restic/<hostname>" \
     RESTIC_PASSWORD="<vault-password>" \
     AWS_ACCESS_KEY_ID="<r2-key>" \
     AWS_SECRET_ACCESS_KEY="<r2-secret>" \
     restic restore <snapshot-id> --target /srv/backups/stack-restic/
   ```
3. **Re-deploy stacks**: Use Portainer or `ansible-playbook playbooks/l4/edge.yml` to re-deploy affected containers.

### Vault Password Recovery

If the Ansible Vault password is lost, follow the procedures in [`docs/operations/INCIDENT_RESPONSE_DR.md`](../operations/INCIDENT_RESPONSE_DR.md). Without the vault password you cannot decrypt backup credentials or Ansible-managed secrets.

---

## 8. Related Documents

| Document                                                                        | Relationship                                                                                       |
| ------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------- |
| [ADR-09 - Consolidated Backup Role (superseded)](../architecture/adr/ADR-09.md) | Rationale for the two-layer backup architecture (now consolidated into `roles/L6_runtime/backup/`) |
| [INCIDENT_RESPONSE_DR.md](../operations/INCIDENT_RESPONSE_DR.md)                | Incident response, disaster recovery, and secrets recovery                                         |
| [VERSION_PINS.md](../operations/VERSION_PINS.md)                                | Restic 0.19.0 version pin and rationale                                                            |
| [ARCHITECTURE.md](../architecture/ARCHITECTURE.md)                              | 7-layer model - L5/L6 layer boundaries                                                             |
| [apps/\*/profile.yml](../../apps/)                                              | Canonical source of truth for per-app backup configuration                                         |
| [playbooks/l6/backup-appdata.yml](../../playbooks/l6/backup-appdata.yml)        | L5 backup playbook entry point                                                                     |
