---
title: Evidence Model - Developmi Stack
type: compliance
owner: maintainers
audience: all
version: v6.0.0
last-reviewed: 2026-06-30
status: active
project: developmi-stack
repo: github.com/Developmi/stack
---

# Evidence Model | Developmi Stack

How compliance evidence is collected, formatted, stored, verified, and retained.

---

## Collection Triggers

Evidence is collected automatically and on-demand:

| Trigger           | Mechanism                                                                         | Schedule                                   |
| ----------------- | --------------------------------------------------------------------------------- | ------------------------------------------ |
| **Playbook run**  | `compliance.yml` with NIST control tags (`--tags nist,ac-2,sc-7,si-4,au-12,cm-7`) | After each `playbooks/site.yml` deployment |
| **Cron schedule** | Systemd timer invoking `compliance.yml` nightly                                   | Daily at 02:00 UTC                         |
| **Manual**        | Operator invokes `make compliance` for pre-audit evidence refresh                 | On-demand                                  |
| **Post-incident** | Operator runs compliance after any security incident or configuration change      | On-demand                                  |

---

## Format

All evidence files follow a consistent YAML structure:

```yaml
# /srv/evidence/nist/<control>/<timestamp>_<control>_<check_type>.yml
control: ac-2
host: <hostname>
timestamp: 2026-06-28T02:00:00Z
playbook: l2/compliance.yml
ansible_version: 2.20.4
checks:
  - name: <check_description>
    expected: <expected_value>
    actual: <actual_value>
    status: pass | fail
```

### Evidence Types

| Type                | Description                                 | Example                       |
| ------------------- | ------------------------------------------- | ----------------------------- |
| **Config snapshot** | Current state of a configuration file       | `/etc/ssh/sshd_config` checks |
| **Command output**  | Output of a compliance verification command | `ufw status verbose`          |
| **Log excerpt**     | Relevant log entries for a specific control | auditd log for AU-12          |
| **Meta-report**     | Summary of all checks for a control         | Aggregated pass/fail counts   |

---

## Storage

Evidence is stored in a filesystem hierarchy under `/srv/evidence/`:

```
/srv/evidence/
├── nist/
│   ├── ac-2/          ← Account Management evidence
│   │   ├── 2026-06-28T020000Z_ac-2_ssh_config.yml
│   │   ├── 2026-06-28T020000Z_ac-2_sudoers_audit.yml
│   │   └── 2026-06-28T020000Z_ac-2_user_list.yml
│   ├── cm-7/          ← Least Functionality evidence
│   ├── sc-7/          ← Boundary Protection evidence
│   ├── si-4/          ← System Monitoring evidence
│   └── au-12/         ← Audit Generation evidence
├── cis/               ← CIS benchmark evidence
│   ├── ssh/
│   ├── ufw/
│   └── sysctl/
└── app-specific/      ← Per-application evidence
    ├── chatwoot/
    ├── n8n/
    └── ...
```

### File Naming Convention

`<ISO8601-timestamp>_<control-id>_<check-type>.yml`

Example: `2026-06-28T020000Z_ac-2_ssh_config.yml`

---

## Verification

### Procedure

An auditor confirms evidence is current and complete by:

1. **Check recency**: Evidence files should be ≤ 24 hours old for daily collections

   ```bash
   find /srv/evidence/nist/ -name "*.yml" -mtime -1 | wc -l
   ```

2. **Run dry-run compliance playbook**: Confirms no configuration drift

   ```bash
   ansible-playbook playbooks/l2/compliance.yml --check --diff
   ```

3. **Cross-reference against control list**: Verify all NIST controls in [NIST_800_53.md](../NIST/NIST_800_53.md) have corresponding evidence files

   ```bash
   for ctrl in ac-2 cm-7 sc-7 si-4 au-12; do
     echo -n "$ctrl: "
     ls /srv/evidence/nist/$ctrl/*.yml 2>/dev/null | wc -l
   done
   ```

4. **Validate YAML syntax**: All evidence reports must be valid YAML
   ```bash
   yamllint /srv/evidence/ | grep -c error
   # Expected: 0 errors
   ```

---

## Retention

| Data Type                 | Retention Period | Rotation Policy                           |
| ------------------------- | ---------------- | ----------------------------------------- |
| **Daily evidence**        | 30 days          | Delete files older than 30 days via cron  |
| **Weekly snapshots**      | 90 days          | Keep one snapshot per week for 13 weeks   |
| **Monthly snapshots**     | 1 year           | Keep one snapshot per month for 12 months |
| **Audit-ready snapshots** | Indefinite       | Manual archiving before formal audits     |

### Rotation Cron Example

```bash
# Clean up daily evidence older than 30 days
0 3 * * * find /srv/evidence/nist/ -name "*.yml" -mtime +30 -delete
```

---

## Related Documents

- [../NIST/NIST_800_53.md](../NIST/NIST_800_53.md) - NIST 800-53 control → role → evidence traceability
- [PRODUCTION_ACCEPTANCE.md](PRODUCTION_ACCEPTANCE.md) - Production acceptance gates
- [../INDEX.md](../INDEX.md) - Compliance framework matrix
- [../../architecture/ARCHITECTURE.md](../../architecture/ARCHITECTURE.md) - 7-layer model with compliance integration
