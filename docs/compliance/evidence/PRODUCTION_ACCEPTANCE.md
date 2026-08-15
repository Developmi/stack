---
title: Production Acceptance - Developmi Stack
type: compliance
owner: maintainers
audience: all
version: v6.0.0
last-reviewed: 2026-06-30
status: active
project: developmi-stack
repo: github.com/Developmi/stack
---

# Production Acceptance | Developmi Stack

Acceptance gates that must pass before the platform is considered production-ready. Each gate has explicit pass/fail criteria, a verification method, and a responsible role.

---

## Gate 1: L1 OS Baseline

**Description**: All target hosts have Debian 12 or Ubuntu 22.04 with standard package policies applied.

| Criteria                       | Pass                                    | Fail                                        |
| ------------------------------ | --------------------------------------- | ------------------------------------------- |
| **OS distribution**            | Debian 12 or Ubuntu 22.04               | Any other OS                                |
| **Package policies**           | `update_policy: security-only` applied  | No update policy configured                 |
| **Automatic security updates** | `unattended_upgrades: security` enabled | Automatic updates disabled or misconfigured |
| **OCI killswitch**             | Applied on Ubuntu 22.04 hosts           | Missing on Ubuntu hosts                     |

**Verification method**: `ansible-playbook playbooks/site.yml --check --diff --limit <host>`

**Responsible**: Platform operator

---

## Gate 2: L2 Compliance Hardening

**Description**: SSH hardening, firewall (ufw/nftables), fail2ban, kernel hardening, and OCI killswitch applied to all hosts.

| Criteria             | Pass                                                                      | Fail                                     |
| -------------------- | ------------------------------------------------------------------------- | ---------------------------------------- |
| **SSH hardening**    | `PermitRootLogin no`, `PasswordAuthentication no`, key-only auth enforced | Root login or password auth allowed      |
| **Firewall**         | ufw active (Ubuntu) OR nftables ruleset active (Debian 12)                | No firewall running                      |
| **Fail2ban**         | Active with SSH jail enabled                                              | Fail2ban not running or SSH jail missing |
| **Kernel hardening** | `kernel.kptr_restrict=2`, `kernel.dmesg_restrict=1`, ASLR enabled         | Any kernel param at insecure default     |
| **OCI killswitch**   | Applied on Ubuntu 22.04                                                   | Missing                                  |

**Verification method**: Manual SSH checks + `sysctl` verification + `ufw status`/`nft list ruleset`

**Responsible**: Security operator

---

## Gate 3: L3 Observability

**Description**: Monitoring stack deployed, health check endpoints respond, alerting configured.

| Criteria             | Pass                                                      | Fail                                |
| -------------------- | --------------------------------------------------------- | ----------------------------------- |
| **Monitoring stack** | Prometheus + Grafana deployed and accessible              | No monitoring services running      |
| **Health endpoints** | All app health endpoints return HTTP 200                  | Any app health endpoint non-200     |
| **Alerting**         | Alert rules configured and firing for critical conditions | No alert rules or alerts not firing |

**Verification method**: `curl -f http://<host>:9090/-/healthy` (Prometheus), `curl -f http://<host>:3000/api/health` (Grafana)

**Responsible**: Platform operator

---

## Gate 4: L4 Networking/Edge

**Description**: Caddy reverse proxy deployed, TLS certificates valid, WAF rules active.

| Criteria             | Pass                                                     | Fail                            |
| -------------------- | -------------------------------------------------------- | ------------------------------- |
| **Caddy deployed**   | Caddy reverse proxy running, serving configured domains  | No Caddy service running        |
| **TLS certificates** | All configured domains have valid TLS (no expired certs) | Any expired or missing TLS cert |
| **WAF rules**        | Coraza WAF active with OWASP Core Rule Set               | WAF disabled or misconfigured   |

**Verification method**: `curl -vI https://<domain> 2>&1 | grep "SSL certificate verify ok"`, check `roles/L4_networking/caddy/` config

**Responsible**: Security operator

---

## Gate 5: L5 Application Profiles

**Description**: `apps/` directory exists with tested application profiles.

| Criteria               | Pass                                                  | Fail                       |
| ---------------------- | ----------------------------------------------------- | -------------------------- |
| **Directory exists**   | `apps/` directory present with profile directories    | Directory missing          |
| **Profile count**      | At least one profile with `profile.yml`               | No profiles found          |
| **Schema compliance**  | Each profile has all 6 MUST fields + `supported_arch` | Any MUST field missing     |
| **Variables declared** | `vars.yml` exists for declared profiles               | Vars file missing or empty |

**Verification method**: `ls apps/`, `find apps/ -name profile.yml`

**Responsible**: Platform operator

---

## Gate 6: L6 Runtime

**Description**: Docker Engine deployed, Portainer optional, backup rotation verified.

| Criteria                 | Pass                                                                      | Fail                                  |
| ------------------------ | ------------------------------------------------------------------------- | ------------------------------------- |
| **Docker Engine**        | Docker 27.x running on all hosts requiring runtime                        | Docker not installed or wrong version |
| **Portainer (optional)** | Portainer BE accessible if deployed; no errors if not deployed            | Portainer deployed but unreachable    |
| **Backup rotation**      | `systemctl list-timers` shows active backup timers with correct schedules | Backup timers missing or failing      |
| **Stack backup**         | L6 `stack_backup` produces runtime state snapshots                        | No stack_backup evidence              |

**Verification method**: `docker --version`, `systemctl list-timers | grep backup`, check `/srv/backups/stack/`

**Responsible**: Platform operator

## Gate Summary

| Gate                     | Layer | Status (pre-acceptance) |
| ------------------------ | ----- | ----------------------- |
| 1 - OS Baseline          | L1    | Pending verification    |
| 2 - Compliance Hardening | L2    | Pending verification    |
| 3 - Observability        | L3    | Pending verification    |
| 4 - Networking/Edge      | L4    | Pending verification    |
| 5 - Application Profiles | L5    | Pending verification    |
| 6 - Runtime              | L6    | Pending verification    |

---

## Related Documents

- [EVIDENCE_MODEL.md](EVIDENCE_MODEL.md) - Evidence collection triggers, format, storage, verification, retention
- [../../architecture/ARCHITECTURE.md](../../architecture/ARCHITECTURE.md) - 7-layer platform architecture
- [../NIST/NIST_800_53.md](../NIST/NIST_800_53.md) - NIST 800-53 control mapping
