---
title: Backup Migration Runbook
type: operations
owner: maintainers
audience: operator
version: v1.0.0
last-reviewed: 2026-09-10
status: active
project: developmi-stack
repo: github.com/Developmi/stack
---

# Backup Migration Runbook

Operator procedure to migrate the live backup subsystem onto the unified engine
(`roles/L6_runtime/backup/`, `backup_role_source: engine`) **without orphaning
existing snapshots**. The migration reuses the existing repository URLs and the
existing per-host restic passwords, so nothing is re-initialized and no password
changes (design D4). This is a how-to; the storage/topology reference lives in
[ARCHITECTURE.md](../architecture/ARCHITECTURE.md), and the tier/retention policy
is the SSOT in [BACKUP_STRATEGY.md](BACKUP_STRATEGY.md).

> **Scope**: `brain-1` and `muscle-1`. Gate steps marked **[GATE]** require the
> real hosts and real R2 credentials and are executed by an operator — they are
> not automatable from a workstation.

## 0. Preconditions

- [ ] `main` contains the migration slice (SOPS consolidation, `inventory_hostname`
      host key, app-data seed fix, divergent-host guard).
- [ ] `restic_r2_*` values are present and correct in SOPS:
      `make sops-view | grep -E 'restic_r2_(account_id|access_key_id|secret_access_key|retention)'`.
- [ ] The per-host passwords exist: `restic_password_brain_1`, `restic_password_muscle_1`.
- [ ] Ansible connectivity to both hosts and `become` available.
- [ ] `docs/operations/BACKUP_STRATEGY.md` §7 (restore procedure) is understood.

## 1. Freeze timers (task 6.1)

Stop every backup/restic timer on both hosts so no scheduled run overlaps the
migration. Do **not** `mask` the units: the engine role re-enables and starts
timers (`enabled: true, state: started`), and a masked unit would fail the deploy.
Keep the freeze window short.

```bash
# Run on brain-1 and muscle-1 (per host):
sudo systemctl list-unit-files --type=timer --all --no-legend 'backup-*' 'restic-*' \
  | awk '{print $1}' | xargs -r -n1 systemctl stop
```

Record the pre-migration baseline **before** deploying (Gate 1 needs it):

```bash
# Run on brain-1 and muscle-1 (per host):
sudo bash -c 'set -a; . /etc/restic/env; set +a; restic snapshots --json' \
  | jq -r '.[].short_id' | sort > /tmp/restic-baseline-$(hostname).txt
wc -l /tmp/restic-baseline-$(hostname).txt
```

## 2. Consolidate SOPS to `restic_r2_*` (task 6.1)

Code consumes **only** the `restic_r2_*` namespace; the `backup_r2_*` /
`vault_backup_r2_*` aliases and the `backup_r2_endpoint` shim were removed from
code (STORAGE-004/005). The encrypted SOPS file still carries the legacy keys
**during the transition** because it cannot be re-encrypted mid-flight — see
[§7 Transition](#7-transition-legacy-sops-keys). No SOPS edit is required for the
migration to work; the legacy keys are simply unused.

```bash
# Confirm the single namespace is resolvable (non-secret view):
make sops-view | grep -E '^(restic_r2_|backup_r2_|vault_backup_r2_)'
```

## 3. Deploy the engine at the existing repo URLs (task 6.2)

```bash
make deploy-backup-engine
```

Expected:

- The role renders `backup-engine-<app>.service` + `.timer` and `backup-tier1.*`
  on every `enable_backups: true` host.
- `/etc/restic/env` and `/etc/restic/password.key` are (re)written from the
  **same** `restic_password_<inventory_hostname>` value — no password rotation.
- The app-data repo is `restic/<inventory_hostname>` (unchanged); the stack-config
  repo is `stack-restic/<ansible_hostname>` (unchanged).
- **No re-init**: `restic init` is guarded by `/etc/restic/.repo-initialized`, so
  the deploy never creates a new repository. Confirm the guard held:

```bash
# Per host — the marker must exist and predate the deploy:
ls -l /etc/restic/.repo-initialized
```

## 4. [GATE] Gate 1 — old + new snapshots visible (task 6.3)

Run a manual backup on each host, then prove the pre-migration snapshots are
still present **and** a new snapshot was written.

```bash
# Per host — trigger one manual run, then list snapshots:
sudo systemctl start backup-tier1.service
sudo systemctl start backup-engine-chatwoot.service   # or any deployed app unit
sudo bash -c 'set -a; . /etc/restic/env; set +a; restic snapshots'
```

Expected observable evidence:

- `restic snapshots` lists the snapshot IDs captured in
  `/tmp/restic-baseline-$(hostname).txt` (old snapshots intact), plus at least
  one **new** snapshot with a timestamp after the deploy.
- No error output; `restic stats` succeeds.
- `restic snapshots --json | jq length` is **greater than** the baseline count.

Record for the change evidence:

```bash
sudo bash -c 'set -a; . /etc/restic/env; set +a; restic snapshots --json' \
  | jq -r '.[].short_id' | sort > /tmp/restic-post-$(hostname).txt
comm -23 /tmp/restic-baseline-$(hostname).txt /tmp/restic-post-$(hostname).txt
# Expected: empty output (no old snapshot disappeared)
```

## 5. [GATE] Gate 2 — host-key resolution (task 6.4)

The engine keys the app-data repo and the restic password by
`inventory_hostname`. After the L1 baseline role,
`roles/L1_os_baseline/general/tasks/hostname.yml` sets the kernel hostname from
`inventory_hostname`, so `ansible_hostname == inventory_hostname` is expected.

```bash
uv run ansible brain-1,muscle-1 -i inventory/hosts.ini -m setup \
  -a 'filter=ansible_hostname' | grep -E 'ansible_hostname|inventory_hostname'
```

- **Not divergent (expected)**: the two names match. The local seed (Gate 3)
  copies from the app-data repo `restic/<inventory_hostname>`.
- **Divergent (defensive path)**: `roles/L6_runtime/backup/tasks/repo-init-local.yml`
  detects the mismatch and seeds from the pre-migration stack-config repo
  `stack-restic/<ansible_hostname>` instead, because the app-data repo path is
  keyed by `inventory_hostname` and would be empty on a divergent host. The role
  logs a warning; confirm the resolved source before relying on the local copy:

```bash
# Per host — the deploy log shows the resolved copy source:
journalctl -u backup-tier1.service --since "30 min ago" | grep -i 'repo-init' || true
```

> This guard is defensive. Do not report a divergent host unless the check above
> actually shows a mismatch.

## 6. Init the local second medium + `restic copy` (task 6.5)

The local FS repository `/var/backups/restic/<inventory_hostname>` is the second
medium for the **app-data** repo `restic/<host>` (design D1). It is initialized
with the source chunker parameters and seeded once via `restic copy`; both steps
are marker-guarded and idempotent.

`make deploy-backup-engine` now creates and seeds this local second medium on
**every** backup host (the engine path runs `repo-init-local.yml` after the
app-data repo init), so no manual `restic init` / `restic copy` step is required
— including on `muscle`. The engine probes the source repository read-only
first: when the app-data repo is absent/unreachable (e.g. a host that runs no
apps), the seed is skipped without failing the play and without writing the
marker, so a later deploy retries.

```bash
make deploy-backup-engine
```

Expected: the local repository is created under `/var/backups/restic/`, seeded
from the app-data repo, and `/etc/restic/.local-seed-complete` is written. A
second invocation performs no work (markers honoured).

```bash
# Per host — prove the local repo holds the copied snapshots:
sudo restic -r /var/backups/restic/$(hostname) \
  --password-file /etc/restic/password.key snapshots

# Per host — the marker is the evidence the seed completed:
ls -l /etc/restic/.local-seed-complete
```

## 7. Re-enable timers + evidence gate (task 6.6)

The engine deploy already enabled and started the timers; confirm and re-enable
the prune timer only after the first **verified** backup.

```bash
# Per host — every backup/restic timer must be active:
sudo systemctl list-timers 'backup-*' 'restic-*' --all
```

Restore-verification evidence gate — a backup is unverified until a restore
succeeds (NIST SP 800-209). Trigger a verification and confirm the evidence JSON:

```bash
# Per host — run one restore verification for a Tier1 app:
sudo systemctl start backup-restore-verify-chatwoot.service
cat /var/lib/backup-restore-verify/evidence/chatwoot.json
```

Expected: the file exists and contains `"result":"success"`. A failed
verification writes `"result":"failure"`, exits non-zero, and notifies Telegram.

After the first successful verified backup cycle:

```bash
sudo systemctl enable --now restic-prune.timer
```

## 8. Transition: legacy SOPS keys

`backup_r2_account_id`, `vault_backup_r2_access_key_id`, and
`vault_backup_r2_secret_access_key` remain in the **encrypted** SOPS file only
during the transition; no code reads them. Once Gates 1–3 pass and the system is
stable:

```bash
make sops-edit   # remove the three legacy keys
```

Do this only after the migration is verified — the real SOPS file must never be
edited or re-encrypted mid-migration.

## 9. Rollback (task 6.7)

Rollback reverts the chained PRs; it **never** touches repositories or passwords.
Snapshots written by the engine remain valid and reachable.

1. Freeze timers again (§1).
2. Revert the migration commits, newest first:

   ```bash
   git revert --no-edit <merge-or-commit-for-PR11>   # migration + gates (this slice)
   git revert --no-edit <merge-or-commit-for-PR10>   # restore verification
   # ... continue back to PR1 (foundation)
   ```

   The exact SHAs are the merge commits on `main`
   (`git log --oneline --merges main`).

3. Redeploy the reverted state:

   ```bash
   make deploy-backups
   ```

4. **Do not** run `restic init`, change any `restic_password_*`, or delete any
   repository. Repos and passwords are untouched by the revert, so old and new
   snapshots stay reachable.
5. Re-enable the timers (§7).

Rollback boundary: the revert only removes the engine role paths, units,
templates, and the SOPS consolidation in code. It does not remove snapshots,
credentials, or the local repository.

## 10. Related Documents

| Document                                           | Relationship                                                   |
| -------------------------------------------------- | -------------------------------------------------------------- |
| [BACKUP_STRATEGY.md](BACKUP_STRATEGY.md)           | Backup tier/retention/verification SSOT and restore procedures |
| [INCIDENT_RESPONSE_DR.md](INCIDENT_RESPONSE_DR.md) | Disaster recovery and secrets recovery                         |
| [VERSION_PINS.md](VERSION_PINS.md)                 | Restic 0.19.1 pin                                              |
| [ARCHITECTURE.md](../architecture/ARCHITECTURE.md) | Layer reference model                                          |
