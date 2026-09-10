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

> ## ⚠️ Tier3 is out of scope (TIER-004)
>
> The backup engine covers **Tier1** (guaranteed, image-discovered databases) and
> **Tier2** (opt-in volumes declared in `backup.volumes[]`). **Tier3** is
> explicitly **out of scope**: custom application configuration, arbitrary bind
> mounts, and source/CI artifacts are **not** protected by the engine and it MUST
> NOT claim to protect them. If an app's data is not a Tier1 database and not a
> declared Tier2 volume, protecting it is the operator's responsibility.

The backup subsystem has exactly **one** mechanism: the unified engine in
`roles/L6_runtime/backup/`. It scans `apps/*/profile.yml` on the controller,
resolves the real container/volume at runtime via `docker inspect`, and streams
dumps and volume tarballs into restic. The retired `backup-db` role and the
`aws s3 cp` transport no longer exist (ENGINE-001). See
[ARCHITECTURE.md](../architecture/ARCHITECTURE.md) for the layer reference model;
this document is the operator how-to and does not duplicate that reference.

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

### 2.1 Unified Engine

L5 application data is protected by the single unified engine. Each app's
`apps/<app>/profile.yml` declares the databases and volumes to protect; the
engine renders one `backup-engine-<app>.service` + `.timer` pair per dump-able
app, plus one host-level `backup-tier1.service` + `.timer` pair for
image-discovered Tier1 databases.

| Aspect           | Unified Engine                                                                       |
| ---------------- | ------------------------------------------------------------------------------------ |
| Entry point      | `ansible-playbook playbooks/l6/backup-engine.yml` (`make deploy-backup-engine`)      |
| Orchestrator     | systemd, one unit pair per app + one Tier1 unit pair                                 |
| Database dump    | `pg_dump` / `mysqldump` / `clickhouse-backup` executed inside the container          |
| Upload mechanism | restic `restic/restic:0.19.1` streaming (`restic backup --stdin`) → R2               |
| Restic retention | `forget --prune` per app profile (daily/weekly/monthly)                              |
| Notification     | Telegram on failure only                                                             |
| Scope            | All hosts with `enable_backups: true` (unit self-skips when the container is absent) |
| Invocation       | Automatic on schedule                                                                |

The retired `backup-db` role, the `aws s3 cp` transport, and the
`backup-appdata`/`backup-timers`/`backup-databases` playbooks no longer exist
(ENGINE-001).

### Per-App Flow

1. **Deploy**: `make deploy-backup-engine` renders the engine units from
   `apps/*/profile.yml` and the host-level Tier1 runner.
2. **Run**: the timer fires `backup-engine-<app>.sh`. The runner resolves the
   real container and volume at runtime via `docker inspect`; an absent
   container exits 0 (host affinity).
3. **Dump → upload**: the logical dump (or volume tarball) is streamed into
   restic (`restic backup --stdin`) at the `restic/<host>` app-data prefix.
4. **Credentials**: DB passwords are consumed from a root-owned `0600`
   EnvironmentFile (`/etc/restic/db-<app>.env`); they are never passed on a
   command line and never read from `docker inspect`.
5. **Retention**: `restic forget --prune` runs with the delete-capable token
   from a separate `0600` EnvironmentFile.
6. **Notification** (`notify.yml`): Telegram on failure only (silent on success).

Apps with `db_type: none` or `db_type: custom` deploy no unit and raise no error.
The app name is **derived from the profile directory path**
(`apps/<name>/profile.yml` → `<name>`), validated against `^[a-z0-9_-]+$` before
render; a legacy `name` field is ignored.

### Tier1 Image Discovery

PostgreSQL, ClickHouse, and Redis/Valkey are protected with **no app
declaration**: the host-level `backup-tier1.sh` runner discovers matching
containers by image at backup time and streams logical dumps into restic. A host
without a matching container exits 0.

### Target

L5 backup targets **every host with `enable_backups: true`**. The engine is
deployed with `hosts: all`; each unit self-checks for its container and exits 0
when it is absent, so the schedule is safe to deploy everywhere.

### Application Data Backup Scope

The suite provides backup for:

- **Application data backup (L6_runtime/backup, engine mode)** - SUPPORTED. Per-app database dumps and declared volume tarballs via the unified engine. See §2.1 for the flow.
- **Stack config backup (L6_runtime/backup, stack mode)** - SUPPORTED. Caddy, Portainer, and monitoring stack state backed up via the installed Restic binary (stack-restic prefix).

> **Application data backup is the operator's responsibility.** The stack provides database backup and stack config backup as supported features. Per-app backup scope (uploads, file volumes, custom data directories) must be configured by the operator. The [INCIDENT_RESPONSE_DR.md](INCIDENT_RESPONSE_DR.md) document provides restore procedures for reference.

**Note**: All PostgreSQL dumps use custom format (`-Fc`), which supports selective restore of individual tables. Dump files are stored at `/srv/backup/dumps/` on the brain host before Restic upload.

---

## 3. L6 - Runtime Backup

### Mechanism

The L6 runtime backup is orchestrated by `roles/L6_runtime/backup/` and runs as a set of independent systemd timers:

1. **Binary installation**: Downloads and verifies the `restic v0.19.1` binary (SHA256 verified per architecture).
2. **Credential configuration**: Deploys R2 API keys and Restic repository password via SOPS (`no_log: true`).
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

L5 backup timers are deployed by `roles/L6_runtime/backup/` from `apps/*/profile.yml`. Each dump-able profile generates a `backup-engine-<app>.timer` + `backup-engine-<app>.service` pair; Tier1 databases additionally get a host-level `backup-tier1.timer`:

```bash
# List all L5 backup timers
systemctl list-timers "backup-engine-*" "backup-tier1.timer"
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

| Role                       | Timer Format                    | Deploys                                  | Source of Schedule                     |
| -------------------------- | ------------------------------- | ---------------------------------------- | -------------------------------------- |
| `roles/L6_runtime/backup/` | `backup-engine-<appname>.timer` | Systemd timers from profile schedules    | `apps/*/profile.yml → backup.schedule` |
| `roles/L6_runtime/backup/` | `backup-tier1.timer`            | One Tier1 image-discovery timer per host | `backup_tier1_schedule` default        |
| `roles/L6_runtime/backup/` | `restic-backup-all.timer`       | Single global systemd timer per host     | `stack_backup_schedule` default        |

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

### Verification Contract (NIST SP 800-209)

This subsystem's verification contract follows **NIST SP 800-209** (Security
Guidelines for Storage Systems):

- **Periodic test restores**: every protected asset is periodically restored
  into a scratch target and the result is recorded as evidence. A backup is
  treated as unverified until a restore succeeds.
- **Per-asset RPO**: every protected asset declares an RPO (via its DR tier),
  and verification frequency is consistent with that tier - Tier1 assets are
  verified **monthly**, Tier2 assets **quarterly**.
- **Integrity checking**: `restic check` is enabled (not deployed disabled) and
  its results are recorded.
- **Failures are not swallowed**: a failed backup or verification propagates a
  non-zero result and notifies an operator rather than exiting successfully.

### Confirm Backups Are Running

**L5 - Application Data Backup:**

```bash
# List L5 backup timers (unified engine + Tier1)
systemctl list-timers "backup-engine-*" "backup-tier1.timer"

# Check status of a specific app timer
systemctl status backup-engine-nocodb.timer

# View L5 backup logs
journalctl -u backup-engine-nocodb.service --since "1 hour ago"
```

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
     -e RESTIC_PASSWORD="<restic-password>" \
  -e AWS_ACCESS_KEY_ID="<r2-key>" \
  -e AWS_SECRET_ACCESS_KEY="<r2-secret>" \
  -e AWS_DEFAULT_REGION="auto" \
  restic/restic:0.19.1 \
  snapshots
```

**L6 snapshots** (via installed binary):

```bash
sudo RESTIC_REPOSITORY="s3://<r2-endpoint>/nist-backups-prod/stack-restic/<hostname>" \
     RESTIC_PASSWORD="<restic-password>" \
  AWS_ACCESS_KEY_ID="<r2-key>" \
  AWS_SECRET_ACCESS_KEY="<r2-secret>" \
  restic snapshots
```

### Manual Backup Invocation

```bash
# L5: Run the full L5 backup playbook
make deploy-backups

# Or directly:
ansible-playbook -i inventory/hosts.ini playbooks/l6/backup-engine.yml
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
   -e RESTIC_PASSWORD="<restic-password>" \
     -e AWS_ACCESS_KEY_ID="<r2-key>" \
     -e AWS_SECRET_ACCESS_KEY="<r2-secret>" \
     restic/restic:0.19.1 \
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
   RESTIC_PASSWORD="<restic-password>" \
     AWS_ACCESS_KEY_ID="<r2-key>" \
     AWS_SECRET_ACCESS_KEY="<r2-secret>" \
     restic restore <snapshot-id> --target /srv/backups/stack-restic/
   ```
3. **Re-deploy stacks**: Use Portainer or `ansible-playbook playbooks/l4/edge.yml` to re-deploy affected containers.

### Secrets Recovery

If the SOPS age key is lost, follow the procedures in [`docs/operations/INCIDENT_RESPONSE_DR.md`](../operations/INCIDENT_RESPONSE_DR.md). Without the age key you cannot decrypt backup credentials or Ansible-managed secrets.

---

## 8. Related Documents

| Document                                                                        | Relationship                                                                                       |
| ------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------- |
| [ADR-09 - Consolidated Backup Role (superseded)](../architecture/adr/ADR-09.md) | Rationale for the two-layer backup architecture (now consolidated into `roles/L6_runtime/backup/`) |
| [INCIDENT_RESPONSE_DR.md](../operations/INCIDENT_RESPONSE_DR.md)                | Incident response, disaster recovery, and secrets recovery                                         |
| [VERSION_PINS.md](../operations/VERSION_PINS.md)                                | Restic 0.19.1 version pin and rationale                                                            |
| [ARCHITECTURE.md](../architecture/ARCHITECTURE.md)                              | 7-layer model - L5/L6 layer boundaries                                                             |
| [apps/\*/profile.yml](../../apps/)                                              | Canonical source of truth for per-app backup configuration                                         |
| [playbooks/l6/backup-engine.yml](../../playbooks/l6/backup-engine.yml)          | L5 unified backup engine entry point                                                               |
