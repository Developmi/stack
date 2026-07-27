---
title: Incident Response & Disaster Recovery Runbook
type: operations
owner: maintainers
audience: operator
version: v6.0.0
last-reviewed: 2026-07-16
status: active
project: developmi-stack
repo: github.com/Developmi/stack
---

# Incident Response & Disaster Recovery Runbook

This document is the Single Source of Truth (SSOT) for the incident response and disaster recovery (DR) procedures of the Developmi Stack. It covers RTO/RPO targets, server and application restoration steps, dependency order, secrets recovery, and drill protocols.

> [!NOTE]
> This is a **RESTORE reference**. For backup configuration details (schedules, retention policies, backup commands, R2 bucket), see [BACKUP_STRATEGY.md](BACKUP_STRATEGY.md).

---

## 1. RTO/RPO Targets

Recovery Time Objective (RTO) and Recovery Point Objective (RPO) per application. RTO is measured from "operator starts procedure" to "smoke test passes." Values marked **Measured** come from verified drill results; **Estimated** values use tier-based targets and must be validated via drill.

### 1.1 Per-Application Table

| Application | DB Type  | DR Tier  | RTO Target | RPO Target | Status    | Notes                          |
| ----------- | -------- | -------- | ---------- | ---------- | --------- | ------------------------------ |
| Chatwoot    | postgres | critical | 5 min      | 4 h        | Measured  | Verified 64s restore |
| n8n         | postgres | critical | 15 min     | 4 h        | Estimated | -                              |
| Twenty CRM  | postgres | critical | 30 min     | 4 h        | Estimated | Larger DB volume               |
| Metabase    | postgres | critical | 15 min     | 4 h        | Estimated | -                              |
| NocoDB      | postgres | critical | 15 min     | 4 h        | Estimated | -                              |
| OpenWebUI   | none     | standard | 30 min     | 24 h       | Estimated | SQLite file restore            |
| FastAPI     | custom   | standard | 30 min     | 24 h       | Estimated | Stateless; community-provided  |

### 1.2 Tier Definitions

| Tier            | RTO Range   | RPO Range   | Priority               | Example Apps                                | Rationale                                                                                                    |
| --------------- | ----------- | ----------- | ---------------------- | ------------------------------------------- | ------------------------------------------------------------------------------------------------------------ |
| **critical**    | ≤ 30 min    | ≤ 4 h       | Restore first          | Chatwoot, n8n, Twenty CRM, Metabase, NocoDB | Revenue-impacting or primary operations. PG dump-based restore is fast; dump creation is the 4 h bottleneck. |
| **standard**    | ≤ 60 min    | ≤ 24 h      | After critical         | OpenWebUI, FastAPI                          | Operational but not revenue-critical. SQLite file restore or stateless redeploy is simple.                   |
| **best-effort** | Best effort | Best effort | Last / if time permits | (none currently)                            | For future low-priority apps.                                                                                |

### 1.3 Status Markers

- **Measured**: Value confirmed by a completed DR drill with recorded RTO/RPO. Must reference the drill date or source.
- **Estimated**: Tier-based target, not yet verified by drill. Must be updated to "Measured" after the first successful drill for that app.

---

## 2. Disaster Recovery Scenarios

### Scenario A: Full Server / Host Loss (Complete Brain Host Recovery)

Use this procedure when a complete brain host is lost and needs to be rebuilt on new infrastructure.

#### Prerequisites

- New brain host provisioned (L0 - operator responsibility, commercial infra)
- Ansible control node with repository cloned and vault password available at `/tmp/.vault_pass`
- Restic repository credentials (R2 endpoint, access key, restic password)

#### Step 1: Provision New Host (L0)

- Deploy Debian 12 or Ubuntu 22.04.
- Configure SSH access for the Ansible control node.
- Optionally install Tailscale (for private networking).

#### Step 2: Re-provision via Ansible (L1 → L6)

Run playbooks to set up OS baselines, compliance configurations, monitoring, ingress, and the container runtime:

```bash
# 1. L1 (OS baseline) and L2 (Compliance: SSH, firewall, fail2ban, CrowdSec, kernel hardening)
ansible-playbook playbooks/site.yml \
  --limit <new-brain-host> \
  --vault-password-file /tmp/.vault_pass

# 2. L3 (Observability / Exporters)
ansible-playbook playbooks/l3/exporters.yml \
  --limit <new-brain-host> \
  --vault-password-file /tmp/.vault_pass

# 3. L4 (Ingress / Caddy)
ansible-playbook playbooks/l4/edge.yml \
  --limit <new-brain-host> \
  --vault-password-file /tmp/.vault_pass

# 4. L6 (Runtime / Docker / Portainer Engine)
ansible-playbook playbooks/l6/engine.yml \
  --limit <new-brain-host> \
  --vault-password-file /tmp/.vault_pass
```

Alternative unified setup commands (if utilizing stack configuration files directly):
- Ingress: `ansible-playbook playbooks/l4/edge.yml`
- Runtime: `ansible-playbook playbooks/l6/engine.yml` then `ansible-playbook playbooks/l6/portainer.yml`

#### Step 3: Restore Restic Repository Access

Set up environment variables on the control node or host to access backup snapshots:

```bash
export RESTIC_REPOSITORY="s3:https://<r2-endpoint>/nist-backups-prod"
export RESTIC_PASSWORD_FILE="/path/to/restic-password"
export AWS_ACCESS_KEY_ID="<r2-access-key>"
export AWS_SECRET_ACCESS_KEY="<r2-secret-key>"
restic snapshots --latest 1
```

#### Step 4: Restore Data and Deploy Applications

Deploy L5/L6 data restore playbooks:

```bash
ansible-playbook playbooks/l6/backup-appdata.yml \
  --limit <new-brain-host> \
  --vault-password-file /tmp/.vault_pass
```
- App data restored from `/srv/backups/app/<name>/` or restic path.
- Runtime state restored from `/srv/backups/stack/`.

Verify ingress routes, check Caddy, and check that system timers are active.

---

## 3. Restore Dependency Order

Restore must follow this dependency chain. Apps without known cross-dependencies can be restored in parallel within their phase.

### Phase 1: Infrastructure (L1 → L6)

Provision the host layers before any app data restore.

| Layer | Purpose                                                | Provisioning                                          |
| ----- | ------------------------------------------------------ | ----------------------------------------------------- |
| L1    | OS baseline                                            | `ansible-playbook site.yml`                           |
| L2    | Compliance (SSH, firewall, fail2ban, CrowdSec, kernel) | `ansible-playbook site.yml`                           |
| L3    | Observability                                          | `ansible-playbook playbooks/l3/stack.yml`, `playbooks/l3/exporters.yml`                     |
| L4    | Ingress (Caddy)                                        | `ansible-playbook playbooks/l4/edge.yml`          |
| L6    | Runtime (Docker, Portainer)                            | `ansible-playbook playbooks/l6/engine.yml`, `playbooks/l6/portainer.yml` |

### Phase 2: Data Layer

Restore shared data services before any app that depends on them.

| Service    | Depended on by                              | Restore Method |
| ---------- | ------------------------------------------- | -------------- |
| PostgreSQL | Chatwoot, n8n, Twenty CRM, Metabase, NocoDB | `pg_restore` from Restic dump |
| Valkey     | Chatwoot                                    | `dump.rdb` from Restic snapshot |
| Valkey (n8n) | n8n (Bull queue, execution state)        | `dump.rdb` from Restic snapshot |

> [!NOTE]
> If PostgreSQL runs as a separate container (not embedded per-app), restore it once in Phase 2. Per-app sections assume embedded postgres containers - adjust `pg_container` name if using a shared instance.

### Phase 3: Applications

All apps can be restored in parallel within this phase. No verified cross-app startup dependencies exist.

| App        | Data Layer Dependency              | Restore Method |
| ---------- | ---------------------------------- | -------------- |
| Chatwoot   | PostgreSQL + Valkey                | `pg_restore` + `dump.rdb` from Restic |
| n8n        | PostgreSQL + Valkey                         | `pg_restore` + `dump.rdb` from Restic |
| Twenty CRM | PostgreSQL                         | `pg_restore` from Restic |
| Metabase   | PostgreSQL                         | `pg_restore` from Restic |
| NocoDB     | PostgreSQL                         | `pg_restore` from Restic |
| OpenWebUI  | (none)                             | SQLite file restore from Restic |
| FastAPI    | (custom - operator responsibility) | Container redeploy |

**Suspected dependencies** (unverified; validate during Tier 2 or Tier 3 drill):
- If FastAPI or n8n workflows call Chatwoot API → runtime dependency, does NOT block restore order. Each app restores independently; validate cross-app functionality post-restore.
- If Twenty CRM connects to n8n webhooks → same as above.

---

## 4. Secrets Recovery & Vault Management

Procedures for recovering the Ansible Vault password, rotating secrets, and verifying Vault integrity.

### Scenario A: Vault Password Lost

#### Recovery Options

| Option | Prerequisite | Procedure |
|--------|-------------|-----------|
| **Backup location** | Password stored in a secondary secure location (password manager, hardware token, sealed envelope) | Retrieve from backup location |
| **Paper recovery** | Password printed and stored in a physical safe | Retrieve from physical safe |
| **Team member** | Another team member has access (shared password manager) | Request from team member |
| **Regeneration** | All secrets can be re-generated (API keys, tokens can be re-issued) | Re-generate all secrets and re-encrypt |

#### Regeneration Procedure (Last Resort)

1. **Create a new vault password**
   ```bash
   echo "new-vault-password-here" > /tmp/.vault_pass_new
   ```
2. **Extract all secrets from existing encrypted files** (if password is recoverable from another source):
   ```bash
   # If old password is available from backup
   ansible-vault decrypt inventory/group_vars/all/secrets.yml \
     --vault-password-file /tmp/.vault_pass_old \
     --output /tmp/secrets_decrypted.yml
   ```
3. **Re-encrypt with new password**
   ```bash
   ansible-vault encrypt /tmp/secrets_decrypted.yml \
     --vault-password-file /tmp/.vault_pass_new \
     --output inventory/group_vars/all/secrets.yml
   ```
### Secret Rotation

#### When to Rotate
- After any team member with Vault access leaves.
- After a security incident or suspected breach.
- On a regular schedule (quarterly recommended).
- After any secret recovery operation.

#### Rotation Procedure

1. **Rotate platform-level secrets**
   - Tailscale auth key: regenerate in Tailscale admin console.
   - GitHub token: regenerate at github.com/settings/tokens.
   - Portainer admin password: change via Portainer UI or API.
   - Telegram bot token: regenerate via @BotFather.
2. **Update Vault-encrypted files**
   ```bash
   # Edit secrets file
   ansible-vault edit inventory/group_vars/all/secrets.yml \
     --vault-password-file /tmp/.vault_pass
   ```
3. **Re-deploy affected components**
   ```bash
   # For Tailscale rotation
   ansible-playbook playbooks/site.yml --tags tailscale

   # For app API key rotation
   ansible-playbook playbooks/l6/backup-appdata.yml --limit <client-host>
   ```

### Vault Integrity Verification

#### Verify vault files are encrypted

```bash
# Check file is valid Ansible Vault
ansible-vault view inventory/group_vars/all/secrets.yml \
  --vault-password-file /tmp/.vault_pass > /dev/null && echo "OK" || echo "CORRUPTED"

# Check all vault files
for f in $(find inventory/ -name "secrets.yml"); do
  echo -n "$f: "
  ansible-vault view "$f" --vault-password-file /tmp/.vault_pass > /dev/null && echo "OK" || echo "FAILED"
done
```

#### Verify secret values are non-empty

```bash
# Dry-run to verify all secrets resolve
ansible-playbook playbooks/site.yml \
  --check --diff \
  --vault-password-file /tmp/.vault_pass \
  --limit localhost
```

### Prevention

| Measure | Description |
|---------|-------------|
| **Password manager** | Store vault password in a team password manager (1Password, Bitwarden) |
| **Physical backup** | Print vault password and store in a sealed envelope in a secure location |
| **Access control** | Limit Vault password access to operators who need it (principle of least privilege) |
| **Rotation schedule** | Rotate vault password quarterly (or after team changes) |
| **Documentation** | This document is the single source of truth for recovery procedures |

---

## 5. DR Drill Protocol

Regular drills validate the DR plan and transition RTO/RPO values from "Estimated" to "Measured."

### 5.1 Drill Tiers

| Tier           | Scope                          | Frequency                 | Environment                  | Success Criteria                                                   |
| -------------- | ------------------------------ | ------------------------- | ---------------------------- | ------------------------------------------------------------------ |
| 1 - Single app | One app database restore       | Quarterly (rotate apps)   | Staging or spare muscle host | RTO ≤ target, RPO ≤ target, smoke test passes                      |
| 2 - Multi-app  | 2+ apps simultaneously         | Biannual (every 6 months) | Staging or spare muscle host | All apps pass individually + cross-app functional check passes     |
| 3 - Full brain | Complete brain loss simulation | Annual                    | Provision new brain (L0)     | L1–L6 restore + all 7 apps operational within aggregate RTO budget |

### 5.2 Tier 1 Drill Procedure (Single App)

1. Select an app and note its target RTO/RPO from §1.
2. On a staging brain host or spare muscle host, execute the per-app restore procedure (database dump restore from Restic).
3. Measure RTO: start timer when procedure begins, stop when smoke test passes.
4. Measure RPO: check the timestamp of the most recent data in the restored database.
5. Document results using the template below (§5.5).

### 5.3 Tier 2 Drill Procedure (Multi-App)

1. Select 2+ apps and execute their restore procedures in parallel where allowed (§3 Phase 3).
2. After individual smoke tests pass, perform cross-app functional checks:
   - Suspected deps: verify if any app's functionality breaks when another is down (validate §3 markers).
3. Log any dependency order corrections needed.

### 5.4 Tier 3 Drill Procedure (Full Brain)

1. Provision a new brain host from scratch (L0).
2. Execute the full server restore procedure (§Scenario A).
3. Verify all 7 apps are operational with per-app smoke tests.
4. Run production smoke tests on all apps.
5. Validate backup timers are scheduled post-restore.

### 5.5 Drill Report Template

```markdown
## Drill Report: YYYY-MM-DD

**Tier**: 1 / 2 / 3
**Scope**: <app names or "full brain">
**Environment**: <staging | muscle-spare | new-brain>

### Results

| Metric      | Target   | Measured   | Pass/Fail |
| ----------- | -------- | ---------- | --------- |
| RTO         | X min    | Y min      | ✅ / ❌   |
| RPO         | X h      | Y h        | ✅ / ❌   |
| Smoke tests | All pass | N/M passed | ✅ / ❌   |

### Issues Encountered

1. <issue>
2. <resolution or workaround>

### Procedure Corrections Required

- [ ] <what to update in INCIDENT_RESPONSE_DR.md>
- [ ] <automation gaps>

### Next Drill

- <app name or tier> by <date>
```

### 5.6 Post-Drill Update Procedure

1. If measured RTO/RPO differs from §1 targets → update the RTO/RPO table, change status from "Estimated" to "Measured".
2. If procedure steps are incorrect → update the per-app restore procedure.
3. If dependency order is wrong → update §3 dependency order.
4. File drill report in `docs/operations/drill-reports/drill-YYYY-MM-DD-<tier>.md`.

---

## 6. Verification Checklist

Use this checklist to confirm host readiness and configuration integrity post-recovery:

| Check | Command | Expected |
|-------|---------|----------|
| SSH is hardened | `ssh -o PasswordAuthentication=no root@<host>` | Key-only auth (connection refused for password auth) |
| Firewall is active | `ssh <host> "sudo ufw status"` or `sudo nft list ruleset` | Active with rules |
| CrowdSec is running | `ssh <host> "sudo systemctl status crowdsec"` | active (running) |
| Docker is running | `ssh <host> "sudo systemctl status docker"` | active (running) |
| All apps healthy | Per-app smoke tests or `curl -f http://localhost:<port>/health` | HTTP 200 each |
| Ingress routes | `curl -sf https://<host>` | HTTP 200 |
| Backups are scheduled | `ssh <host> "systemctl list-timers \| grep backup"` | Active timers |
| Evidence is current | `ssh <host> "ls -lt /srv/evidence/nist/ac-2/ \| head -3"` | Files ≤ 24h old |

---

## 7. Related Documents

- [BACKUP_STRATEGY.md](BACKUP_STRATEGY.md) - Backup configuration (schedules, retention, restic commands)
- [../architecture/ARCHITECTURE.md](../architecture/ARCHITECTURE.md) - L1–L6 layer model, host classes
- [../architecture/adr/ADR-09.md](../architecture/adr/ADR-09.md) - Backup vs Stack_Backup separation
- [VERSION_PINS.md](VERSION_PINS.md) - Pinned component versions
- [../../GLOSSARY.md](../GLOSSARY.md) - Vault definition and evidence paths
