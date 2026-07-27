---
title: Hardening Status Matrix
type: Status
owner: maintainers
audience: all
version: v6.0.0
last-reviewed: 2026-07-05
status: active
project: developmi-stack
repo: github.com/Developmi/stack
---

# Hardening Status Matrix

Per-role × per-layer hardening coverage matrix. Tracks what is automated via Ansible,
what requires manual intervention, and what is not applicable per host class.

---

## Hardening Profile Dispatcher

The `hardening_profile` variable (from [ARCHITECTURE.md §3](../architecture/ARCHITECTURE.md#3-role-composition-and-variable-hierarchy))
dispatches between two hardening levels:

| Profile        | Value          | Host Classes | Behavior |
|----------------|----------------|--------------|----------|
| **Server**     | `server`       | brain, muscle | Full hardening: server-grade firewall (`ufw deny`/`nftables deny`), fail2ban 1h bantime, CrowdSec enforcement, observability stack, backups enabled |
| **Workstation**| `workstation`  | local         | Tailored hardening: UFW deny (Zero Trust base), fail2ban 10m bantime, CrowdSec skipped (false positives from network changes), no observability, no backups |

The dispatcher is set per host class in `inventory/group_vars/{brain,muscle,local}/main.yml`.

### Tag Conventions Used in Matrix

**Tag Conventions**: Controls are tagged using `nist,ac-2` / `cis,1.1` format per the `hardening_profile` dispatcher. For the complete tagging model, see [ARCHITECTURE.md §3](../architecture/ARCHITECTURE.md#layer-4-compliance-networking).

---

## Layer Definitions

Layers follow the architecture model per [ARCHITECTURE.md §5](../architecture/ARCHITECTURE.md#5-7-layer-architecture-model--full-specification).
The boot sequence in [OPERATIONS_RUNBOOK.md §4](../operations/OPERATIONS_RUNBOOK.md#4-boot-sequence)

> **Layer numbering note**: `OPERATIONS_RUNBOOK.md §4` boot sequence uses a slightly different grouping.
> | Runbook §4 | ARCHITECTURE.md / this doc |
> |-----------|---------------------------|
> | L2 (Networking) | L2 (Compliance+Networking) |
> | L3 (Compliance) | L2+L3 combined |
>
> When in doubt, ARCHITECTURE.md §5 is the canonical layer model.
maps to these layers with a slightly different grouping.

| Layer | Name              | Roles                                                                                    | Playbook                     |
| ----- | ----------------- | ---------------------------------------------------------------------------------------- | ---------------------------- |
| L1    | OS Baseline       | `L1_os_baseline`                                                                         | `playbooks/l1/baseline.yml`  |
| L2    | Compliance        | `L2_compliance`                                                                          | `playbooks/l2/hardening.yml`, `playbooks/l2/compliance.yml`, `playbooks/l2/lockdown.yml` |
| L3    | Observability     | `L3_observability`                                                                       | `playbooks/l3/stack.yml`, `playbooks/l3/exporters.yml` |
| L4    | Networking / Edge | `L4_networking/caddy`                                                                    | `playbooks/l4/edge.yml`      |
| L5    | App Profiles      | N/A (reference profiles at `apps/`)                                                      | N/A (user-managed)           |
| L6    | Runtime           | `L6_runtime/general`, `L6_runtime/portainer`, `L6_runtime/backup`, `L6_runtime/backup-db` | `playbooks/l6/engine.yml`, `playbooks/l6/portainer.yml`, `playbooks/l6/backup-stack.yml`, `playbooks/l6/backup-appdata.yml`, `playbooks/l6/backup-timers.yml`, `playbooks/l6/backup-databases.yml` |

---

## Coverage Matrix

Status values:
- **Automated**: Deployed via Ansible playbook (no manual steps)
- **Manual**: Requires operator intervention (documented in runbook)
- **N/A**: Not applicable for this host class

### Brain

| Layer | Hardening               | Status    | Playbook                      | Tags / Notes                              |
|-------|-------------------------|-----------|-------------------------------|-------------------------------------------|
| L1    | OS baseline             | Automated | `playbooks/l1/baseline.yml`   | `l1-os-baseline`, CIS Level 1, kernel tuning |
| L2    | Compliance hardening    | Automated | `playbooks/l2/hardening.yml`, `playbooks/l2/compliance.yml`, `playbooks/l2/lockdown.yml` | `l2-compliance`, `nist,ac-2`, `nist,sc-7`, `nist,cm-7`, SSH, firewall, fail2ban, CrowdSec, kernel, user hardening |
| L3    | Observability           | Automated | `playbooks/l3/stack.yml`, `playbooks/l3/exporters.yml` | `l3-observability`, VictoriaMetrics, Grafana, Loki, node_exporter, cadvisor |
| L4    | Networking / Edge       | N/A       | -                             | `L4_networking/caddy` not deployed to brain per boot sequence (§4) |
| L5    | App Profiles            | N/A       | -                             | Reference profiles at `apps/` (user-managed) |
| L6    | Runtime                 | Automated | `playbooks/l6/engine.yml`, `playbooks/l6/portainer.yml`, `playbooks/l6/backup-stack.yml` | `l6-runtime`, Docker Engine, Portainer (optional), stack backup, Docker bench |

### Muscle

| Layer | Hardening               | Status    | Playbook                      | Tags / Notes                              |
|-------|-------------------------|-----------|-------------------------------|-------------------------------------------|
| L1    | OS baseline             | Automated | `playbooks/l1/baseline.yml`   | `l1-os-baseline`, CIS Level 1, kernel tuning |
| L2    | Compliance hardening    | Automated | `playbooks/l2/hardening.yml`, `playbooks/l2/compliance.yml`, `playbooks/l2/lockdown.yml` | `l2-compliance`, `nist,ac-2`, `nist,sc-7`, `nist,cm-7`, SSH, firewall, fail2ban, CrowdSec, kernel, user hardening |
| L3    | Observability           | Automated | `playbooks/l3/exporters.yml`  | `l3-observability`, exporters (node_exporter, cadvisor), no full stack (brain owns VictoriaMetrics/Grafana/Loki) |
| L4    | Networking / Edge       | Automated | `playbooks/l4/edge.yml`       | `l4-networking`, Caddy reverse proxy, Coraza WAF, TLS termination, Cloudflare certs |
| L5    | App Profiles            | N/A       | -                             | Reference profiles at `apps/` (user-managed) |
| L6    | Runtime                 | Automated | `playbooks/l6/engine.yml`, `playbooks/l6/portainer.yml`, `playbooks/l6/backup-stack.yml`, `playbooks/l6/backup-appdata.yml`, `playbooks/l6/backup-timers.yml` | `l6-runtime`, Docker Engine, Portainer (optional, Edge Agent), stack backup, app data backup, Docker bench |

### Local

| Layer | Hardening               | Status    | Playbook                      | Tags / Notes                              |
|-------|-------------------------|-----------|-------------------------------|-------------------------------------------|
| L1    | OS baseline             | Automated | `playbooks/l1/baseline.yml`   | `l1-os-baseline`, CIS Level 1, kernel tuning |
| L2    | Compliance hardening    | Automated | `playbooks/l2/hardening.yml`, `playbooks/l2/compliance.yml` | `l2-compliance`, `hardening_profile: workstation`, `nist,sc-7`, SSH, firewall, fail2ban (10m), kernel. CrowdSec **skipped** |
| L3    | Observability           | N/A       | -                             | No observability on workstation class     |
| L4    | Networking / Edge       | N/A       | -                             | No ingress role on local                  |
| L5    | App Profiles            | N/A       | -                             | No app profiles on workstation class      |
| L6    | Runtime                 | Automated | `playbooks/l6/engine.yml`     | `l6-runtime`, Docker Engine only (no Portainer, no backup) |

---

## Automation Level Summary

| Role   | L1         | L2         | L3         | L4         | L5    | L6         |
|--------|------------|------------|------------|------------|-------|------------|
| Brain  | Automated  | Automated  | Automated  | N/A        | N/A   | Automated  |
| Muscle | Automated  | Automated  | Automated  | Automated  | N/A   | Automated  |
| Local  | Automated  | Automated  | N/A        | N/A        | N/A   | Automated  |

---

## Control Traceability

NIST 800-53 controls are tagged at the Ansible task level. Evidence is auto-collected
to `/srv/evidence/nist/<control>/`. See [NIST_800_53.md](../compliance/NIST/NIST_800_53.md)
for full control-to-task mapping.

| Control   | Tag            | Layer | Applies To         | Enforcement                     |
|-----------|----------------|-------|--------------------|---------------------------------|
| AC-2      | `nist,ac-2`    | L2    | brain, muscle      | Automated (account management)  |
| SC-7      | `nist,sc-7`    | L2    | brain, muscle, local | Automated (boundary protection) |
| SI-4      | `nist,si-4`    | L2    | brain, muscle      | Automated (monitoring)          |
| AU-12     | `nist,au-12`   | L2    | brain, muscle      | Automated (audit generation)    |
| CM-7      | `nist,cm-7`    | L2    | brain, muscle      | Automated (least functionality) |
| SC-28     | `nist,sc-28`   | L2    | brain, muscle      | Audit-only (disk encryption verification) |

---

## Updating This Matrix

When a new layer, role, or host class is added:

1. Add a row to the layer definitions table above
2. Add a column (if new layer) and rows (if new role/class) to the Coverage Matrix
3. Update the Automation Level Summary table
4. If new NIST controls, add entries to Control Traceability and update [NIST_800_53.md](../compliance/NIST/NIST_800_53.md)
5. Notify maintainers for review

When hardening coverage changes (e.g., a previously manual step is automated):

1. Change the Status cell from `Manual` to `Automated`
2. Add/update the Playbook column
3. Bump `last-reviewed` in frontmatter

---

## Cross-References

- [OPERATIONS_RUNBOOK.md](../operations/OPERATIONS_RUNBOOK.md) - §4 Boot sequence per layer with commands

- [ARCHITECTURE.md](../architecture/ARCHITECTURE.md) - §3 Hardening profile dispatcher, §5 Layer responsibilities, §7 Host classes
- [NIST_800_53.md](../compliance/NIST/NIST_800_53.md) - Full control traceability
- [EVIDENCE_MODEL.md](../compliance/evidence/EVIDENCE_MODEL.md) - Evidence collection chain
- [LAYER_BOUNDARIES.md](../architecture/LAYER_BOUNDARIES.md) - Trust boundaries and contracts
