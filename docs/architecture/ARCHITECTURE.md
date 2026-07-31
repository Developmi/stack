---
title: Architecture Overview - Developmi Stack
type: architecture
owner: maintainers
audience: all
version: v6.0.0
last-reviewed: 2026-07-31
status: active
project: developmi-stack
repo: github.com/Developmi/stack
---

# Architecture Overview - Developmi Stack v6.0.0

The Developmi Stack is a multi-layer Linux hardening and application deployment framework built on Ansible.
It transforms vanilla Debian/Ubuntu servers into NIST 800-53 compliant bastion hosts
with a 7-layer architecture that cleanly separates infrastructure provisioning (L0, private), OS hardening (L1-L4),
application profiles (L5), and runtime adapters (L6).

---

## 1. Full Directory Layout - 7-Layer Model

```
stack/
├── AGENTS.md
├── Makefile
├── ansible.cfg
├── pyproject.toml
├── requirements.yml
├── uv.lock
├── .gitignore
├── inventory/
│   ├── hosts.ini
│   ├── hosts.ini.example
│   ├── group_vars/
│   │   ├── all/
│   │   │   ├── main.yml                ← Global safe defaults
│   │   │   ├── images.yml              ← Container image pins
│   │   │   └── secrets.yml             ← Global secrets only (Tailscale, GitHub token, Portainer admin, Telegram bot)
│   │   ├── brain/                      ← Server-grade, backups + observability
│   │   │   └── main.yml
│   │   ├── muscle/                     ← Server-grade, backups + observability
│   │   │   └── main.yml
│   │   ├── local/                      ← Workstation-grade, no backups, no observability
│   │   │   └── main.yml
│   │   ├── app_<name>/                 ← Per-application profile overrides
│   │   │   └── vars.yml
├── roles/
│   ├── L1_os_baseline/                 ← L1
│   │   ├── general/                    ← L1 (package manager, update/hold, OS baseline)
│   │   ├── debian_12/
│   │   └── ubuntu_22.04/
│   ├── L2_compliance/                  ← L2
│   │   ├── general/                    ← L2 (ssh, firewall, fail2ban, kernel, user_hardening, tailscale, security)
│   │   └── nist_800_53/                ← L2 (NIST/CIS evidence, CrowdSec)
│   ├── L3_observability/               ← L3
│   │   ├── general/                    ← L3 (monitoring stack)
│   │   └── app_templates/
│   ├── L4_networking/                  ← L4
│   │   ├── general/
│   │   ├── caddy/                      ← L4 (Caddy, certs, WAF)
│   │   ├── traefik/
│   │   └── nginx/
│   ├── L6_runtime/                     ← L6
│   │   ├── general/
│   │   ├── docker_compose/             ← L6 (engine: Docker Compose)
│   │   ├── portainer/                  ← L6 (manager, optional)
│   │   ├── backup/                     ← L6 - consolidated app + runtime backups
│   │   ├── compose/
│   │   │   ├── deploy.yml.j2
│   │   │   └── defaults.yml
│   │   ├── swarm/
│   │   │   └── README.md               ← Future
│   │   └── k3s/
│   │       └── README.md               ← Future
├── apps/                               ← L5 - Application profiles (operator-managed references)
│   ├── chatwoot/                       ← Standard layout per app:
│   │   ├── docker-compose.yml              docker-compose.yml (x-<app>-env anchor pattern)
│   │   ├── .env.example                    .env.example (namespaced <APP>_ variables)
│   │   └── profile.yml                     profile.yml (reduced 6-field schema)
│   │                                   ← assets/ only when compose bind-mounts files
│   ├── n8n/
│   ├── twenty-crm/
│   ├── openwebui/
│   ├── metabase/
│   ├── nocodb/
│   ├── clickhouse/
│   ├── mariadb/
│   ├── openlit/
│   ├── postgresql/
│   ├── uptime-kuma/
│   └── fastapi/                        ← Community-provided example (legacy layout, excluded)
├── playbooks/
│   ├── site.yml                        ← L1+L2 (OS baseline + compliance)
│   ├── l4/edge.yml                     ← L4 (reverse proxy + WAF)
│   ├── l6/engine.yml                   ← L6 (Docker Engine)
│   ├── l6/portainer.yml                ← L6 (optional Manager)
│   ├── l6/backup-stack.yml             ← L6 (runtime backup)
│   ├── l3/exporters.yml                ← L3 (node_exporter + cadvisor)
│   ├── l3/stack.yml                    ← L3 (VictoriaMetrics + Grafana + Loki)
│   └── l2/compliance.yml               ← L2 (evidence collection)
├── scripts/
│   └── setup.sh
├── tests/
│   └── README.md
├── docs/
│   ├── GLOSSARY.md                     ← Terminology (root of docs/)
│   ├── README.md                       ← Documentation index
│   ├── architecture/
│   │   ├── ARCHITECTURE.md
│   │   ├── LAYER_BOUNDARIES.md
│   │   └── adr/                        ← Architecture Decision Records (ADR-01..ADR-09)
│   ├── compliance/
│   │   ├── INDEX.md
│   │   ├── NIST/
│   │   ├── DORA/
│   │   ├── SOC2/
│   │   ├── ENS/
│   │   └── evidence/
│   ├── finops/
│   │   └── FINOPS-BASELINE.md
│   ├── operations/
│   │   ├── BACKUP_STRATEGY.md
│   │   ├── COMPATIBILITY_MATRIX.md
│   │   ├── DEVELOPER_SETUP.md
│   │   ├── EMERGENCY_ACCESS.md
│   │   ├── HOST_CLASSES.md
│   │   ├── INCIDENT_RESPONSE_DR.md
│   │   ├── OPERATIONS_RUNBOOK.md
│   │   └── VERSION_PINS.md
│   ├── project/
│   │   ├── CONTRIBUTORS_DOC_GUIDE.md
│   │   ├── ONBOARDING.md
│   │   ├── PROJECT_WORKFLOW.md
│   │   ├── RELEASE.md
│   │   ├── REPOSITORY_STRUCTURE.md
│   │   └── ROADMAP.md
│   └── security/
│       └── HARDENING-STATUS.md
```

Each layer follows boundary contracts defined in [LAYER_BOUNDARIES.md](LAYER_BOUNDARIES.md). The table below summarizes responsibilities; see the boundary document for the full contract including promises, forbids, and dependencies.

| Layer | Name                   | Responsibility                                                                                |
| ----- | ---------------------- | --------------------------------------------------------------------------------------------- |
| L0    | Commercial Infra (IaC) | Bare-metal/cloud provisioning with OpenTofu. Outside OpenSource scope - reference only.       |
| L1    | OS Baseline            | Package manager, update/hold policies, auto-upgrade, OS detection, AMD64/ARM64 compatibility. |
| L2    | Compliance             | SSH hardening, firewall, fail2ban, CrowdSec, kernel hardening, NIST/CIS evidence.             |
| L3    | Observability          | VictoriaMetrics, Grafana, Loki, scrape targets, alerting.                                     |
| L4    | Networking / Edge      | Caddy reverse proxy, TLS certs, WAF, ingress routing.                                         |
| L5    | Application Profiles   | Declarative YAML profile per app under `apps/`. Tested references - operator-managed.         |
| L6    | Runtime Adapters       | Docker Engine (Compose), Portainer (optional), consolidated backups.                          |

### Trust Boundaries

Layers MUST NOT reach across trust boundaries:

- **L1–L6 are OpenSource** - L0 is private/commercial, never referenced with implementation details.
- **Applications (L5) never know which runtime (L6) they are on.**
- **Runtimes (L6) never know which cloud (L0) provisioned them.**
- **L1 is the bottom of the OpenSource surface** - L0 is documented as an external dependency only.
- Control tags (`nist,ac-2`, `cis,1.1`) and layer tags (`l2-compliance`) are distinct metadata; neither subsumes the other.

---

## 2. OS Support Matrix - AMD64/ARM64 Compatibility

### OS Capability Table

| Capability            | Ubuntu 22.04 (amd64) | Ubuntu 22.04 (arm64) | Ubuntu 24.04 (amd64) | Ubuntu 24.04 (arm64) | Debian 11 (amd64)   | Debian 11 (arm64)   | Debian 12 (amd64)   | Debian 12 (arm64)   |
| --------------------- | -------------------- | -------------------- | -------------------- | -------------------- | ------------------- | ------------------- | ------------------- | ------------------- |
| Package Manager       | ✅ apt               | ✅ apt               | ✅ apt               | ✅ apt               | ✅ apt              | ✅ apt              | ✅ apt              | ✅ apt              |
| Update/Hold Policies  | ✅ Full              | ✅ Full              | ✅ Full              | ✅ Full              | ✅ Full             | ✅ Full             | ✅ Full             | ✅ Full             |
| Auto-upgrade Checker  | ✅ Full              | ✅ Full              | ✅ Full              | ✅ Full              | ✅ Full             | ✅ Full             | ✅ Full             | ✅ Full             |
| Pop OS → Ubuntu Norm. | ✅ Full              | ✅ Full              | - (N/A)              | - (N/A)              | - (N/A)             | - (N/A)             | - (N/A)             | - (N/A)             |
| NIST 800-53 Hardening | ✅ Full              | ✅ Full              | ✅ Full              | ✅ Full              | ✅ Full             | ✅ Full             | ✅ Full             | ✅ Full             |
| CIS Benchmarks        | ✅ Full              | ✅ Full              | ✅ Full              | ✅ Full              | ⚠️ Minor delta      | ⚠️ Minor delta      | ⚠️ Minor delta      | ⚠️ Minor delta      |
| Firewall              | ✅ ufw               | ✅ ufw               | ✅ ufw               | ✅ ufw               | ⚠️ nftables wrapper | ⚠️ nftables wrapper | ⚠️ nftables wrapper | ⚠️ nftables wrapper |
| CrowdSec Enforcement  | ✅ Full              | ✅ Full              | ✅ Full              | ✅ Full              | ✅ Full             | ✅ Full             | ✅ Full             | ✅ Full             |
| fail2ban              | ✅ Full              | ✅ Full              | ✅ Full              | ✅ Full              | ✅ Full             | ✅ Full             | ✅ Full             | ✅ Full             |
| Kernel Hardening      | ✅ Full              | ✅ Full              | ✅ Full              | ✅ Full              | ✅ Full             | ✅ Full             | ✅ Full             | ✅ Full             |

#### Architecture Columns (AMD64 / ARM64 - Ampere)

| Architecture       | L1 OS Baseline | L2 Compliance | L3 Observability | L4 Networking | L5 App Profiles                          | L6 Runtime |
| ------------------ | -------------- | ------------- | ---------------- | ------------- | ---------------------------------------- | ---------- |
| **amd64**          | ✅ Full        | ✅ Full       | ✅ Full          | ✅ Full       | ✅ Full                                  | ✅ Full    |
| **arm64 (Ampere)** | ✅ Full        | ✅ Full       | ✅ Full          | ✅ Full       | ✅ Full (validated per `supported_arch`) | ✅ Full    |

#### Per-Capability Deltas and Resolution Plan

| Delta                             | Affected OS        | Resolution                                                                                                                                                                                                                                             |
| --------------------------------- | ------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Firewall backend: ufw vs nftables | Debian 11/12       | Variable dispatcher: `os_firewall_backend: "{{ 'nftables' if ansible_os_family == 'Debian' and ansible_distribution_major_version == '12' else 'ufw' }}"` - role dispatches via `ansible.builtin.include_tasks: "{{ os_firewall_backend }}_rules.yml"` |
| CIS minor deltas                  | Debian 11/12       | Documented in `docs/compliance/NIST/INDEX.md` - Debian CIS benchmarks have minor structural differences from Ubuntu. Tagged `cis,debian-delta`.                                                                                                        |
| ARM64 image availability          | All                | Every app profile MUST declare `supported_arch`. Playbook validates host arch ∈ profile's `supported_arch` before deploy. All base OS + infra components (Docker, Caddy, CrowdSec, Tailscale, Portainer) are multi-arch verified.                      |
| OCI killswitch                    | Ubuntu 22.04 (OCI) | Required for Oracle Cloud nodes only. Detected at `gather_facts` time, dispatched conditionally. Not applicable to Debian or non-OCI targets.                                                                                                          |

---

## 3. Role Composition and Variable Hierarchy

### Variable Precedence (4 Layers - Ascending Priority)

```
Layer 1: roles/<role>/defaults/main.yml          ← Lowest priority - role fallbacks
Layer 2: group_vars/all/main.yml                  ← Global safe defaults
Layer 3: group_vars/{brain,muscle,local}/main.yml ← Host-class config
Layer 4: group_vars/app_<name>/vars.yml           ← Application-level overrides

```

**Rule**: No hardcoded values in roles. Every tunable must be a variable with a default in `defaults/main.yml`.

### Tag Conventions

| Category          | Format                | Examples                                                         |
| ----------------- | --------------------- | ---------------------------------------------------------------- |
| Functional        | lowercase, hyphenated | `ssh`, `firewall`, `docker`, `backup`, `fail2ban`, `kernel`      |
| Compliance (NIST) | `nist,<control-id>`   | `nist,ac-2`, `nist,sc-7`, `nist,si-4`, `nist,au-12`, `nist,cm-7` |
| Compliance (CIS)  | `cis,<id>`            | `cis,1.1`, `cis,2.3`                                             |
| Compliance (SOC2) | `soc2,<id>`           | `soc2,cc6.1`                                                     |
| Layer L0          | `l0-iac`              | -                                                                |
| Layer L1          | `l1-os-baseline`      | -                                                                |
| Layer L2          | `l2-compliance`       | -                                                                |
| Layer L3          | `l3-observability`    | -                                                                |
| Layer L4          | `l4-networking`       | -                                                                |
| Layer L5          | `l5-app-profile`      | -                                                                |
| Layer L6          | `l6-runtime`          | -                                                                |

**Tag separation rule**: Layer tags and control tags are distinct metadata. `l2-compliance` never implies `nist,ac-2`; both coexist on the same task when applicable.

### Dispatcher Pattern

```
hardening_profile: server | workstation
```

- **`server`**: Full hardening - server-grade firewall (`ufw deny`/`nftables deny`), fail2ban 1h bantime, CrowdSec enforcement, observability stack, backups enabled.
- **`workstation`**: Tailored hardening - UFW deny (Zero Trust base), fail2ban 10m bantime, CrowdSec skipped (false positives from network changes), no observability, no backups.

The dispatcher is a single variable in `group_vars/{brain,muscle,local}/main.yml`. The `local` host class sets `hardening_profile: workstation`; `brain` and `muscle` set `server`.

---

## 4. Architectural Principles

| #   | Principle                                                 | Definition                                                                                                                                              | Concrete Example from the Platform                                                                                                                                                                                                                        |
| --- | --------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | **Principle 1: Simplicity beats sophistication**          | The simplest solution that meets requirements wins. Over-engineering is the enemy of maintainability.                                                   | Docker Compose as the default Engine. No Kubernetes for single-node deploys. Portainer is optional. Compose NEVER depends on Portainer.                                                                                                                   |
| 2   | **Principle 2: Recovery beats availability**              | Design for graceful failure and fast recovery, not impossible uptime guarantees.                                                                        | A single consolidated backup role (`roles/L6_runtime/backup/`) with `backup_role_source` dispatch provides independent L5/L6 recovery paths. App data and runtime state can be restored independently.                                                    |
| 3   | **Principle 3: Automation beats documentation**           | Document by executing. Manual runbooks are code smells - automate first, document second.                                                               | Pre-flight assertions validate secrets and `supported_arch` before deploy. Zero manual validation steps. Compliance evidence is auto-collected to `/srv/evidence/nist/<control>/`.                                                                        |
| 4   | **Principle 4: Sovereignty beats convenience**            | Keep control of your data and infrastructure. Avoid vendor lock-in that erodes autonomy.                                                                | Variable-driven OS dispatch (`os_firewall_backend`) instead of vendor-specific conditionals. Mandatory AMD64/ARM64 compatibility table prevents architecture lock-in. Tailscale OAuth-only ACL automation - no long-lived API tokens.                     |
| 5   | **Principle 5: Evidence beats assertion**                 | Every compliance claim must be backed by machine-collected evidence, not human statements.                                                              | NIST 800-53 controls trace to Ansible task tags → evidence files at `/srv/evidence/nist/<control>/`. `compliance.yml` playbook auto-collects evidence. `compliance/evidence/EVIDENCE_MODEL.md` documents the chain.                                       |
| 6   | **Principle 6: Boring technology beats novel technology** | Prefer proven, widely-adopted tools. Novelty adds risk, not value.                                                                                      | Ansible (agentless, YAML, 10+ years). Docker Compose (every operator knows it). PostgreSQL (battle-tested). Caddy (simpler than nginx for reverse proxy). No custom DSLs, no framework lock-in.                                                           |
| 7   | **Principle 7: One operator, one runbook, 03:00**         | A single tired operator at 3 AM must understand and fix any issue with ONE document.                                                                    | Six-layer variable hierarchy makes overrides discoverable by path alone. Tag conventions separate functional, compliance, and layer concerns. Layer boundaries are explicit - an app profile never reaches into host config.                              |
| 8   | **Principle 8: Layers don't reach across boundaries**     | Each layer promises a contract. It never bypasses the layer below or above it.                                                                          | L5 (app profiles) defines `what` to run; L6 (runtime) defines `how`. Profile schema contains zero Compose-specific directives. Engine (Compose) and Manager (Portainer) are independent axes - removing Portainer doesn't break Compose stacks.           |
| 9   | **Principle 9: Open core, not open-washing**              | L1–L6 are genuinely OpenSource. L0 (provisioning, cloud) is private infrastructure - clearly documented as out of scope, never teased as "coming soon." | L0 documented as "Commercial Infra (IaC) - outside OpenSource scope, reference only." `apps/fastapi/` marked "community-provided" with explicit user config requirements. No hidden enterprise tiers.                                                     |
| 10  | **Principle 10: Reversibility over optimization**         | Every decision must be reversible without a rewrite. Prefer loose coupling over tight integration.                                                      | Profile schema abstracts runtime: same profile works for Compose today, Swarm/K3s tomorrow. Variable dispatchers (`os_firewall_backend`) let roles switch backends without refactoring. ADR-07 guarantees Manager can be removed without breaking Engine. |

---

## 5. 7-Layer Architecture Model - Full Specification

Each layer follows boundary contracts defined in [LAYER_BOUNDARIES.md](LAYER_BOUNDARIES.md), which includes full promises, forbids, and dependencies for every layer. The layer responsibilities summary in §1 above provides a quick reference; refer to LAYER_BOUNDARIES.md for the authoritative contracts.

### Trust Levels per Layer

| Layer | Trust Level           | Rationale                                                                                                        |
| ----- | --------------------- | ---------------------------------------------------------------------------------------------------------------- |
| L0    | **Private**           | Cloud credentials, Terraform state. Not in OpenSource repo.                                                      |
| L1    | **System**            | Package manager runs as root. Trusted to configure base OS.                                                      |
| L2    | **Security-critical** | Firewall, SSH, CrowdSec - compromise here compromises everything above. Highest OpenSource trust level.          |
| L3    | **Monitoring**        | Read-only access to metrics/logs. Write access limited to monitoring stack config.                               |
| L4    | **Edge**              | Exposed to public internet via Caddy. WAF is the first line of defense. Cert management is sensitive.            |
| L5    | **Application**       | Runs application code. Database credentials. Operator-managed - suite does not deploy applications.              |
| L6    | **Runtime**           | Docker socket access (privileged). Controls all containers. Manager (Portainer) further extends control surface. |

### Data Flow

```
Operator (CLI) → Make targets → Ansible Control Node
  │
  ├── playbooks/site.yml → L1 (common → packages) → L2 (security → crowdsec → compliance)
  │   └── Dispatcher: hardening_profile: server | workstation
  │
  ├── playbooks/l4/edge.yml → L4 (Caddy reverse proxy + WAF)
  │
  ├── playbooks/l6/engine.yml → L6 Engine (docker) → L6 Manager (playbooks/l6/portainer.yml, optional)
  │
  └── playbooks/l3/exporters.yml + playbooks/l3/stack.yml → L3 (observability roles + scrape targets)
       │
       ↓ (SSH/Tailscale)
Target Host: /srv/evidence/nist/<control>/
```

### Separation Rules

1. **L0 is OUT OF SCOPE** - referenced only as an external dependency. Implementation details (OpenTofu configs, cloud credentials) never appear in the OpenSource repo.
2. **L1 is the bottom of the OpenSource surface** - layers L2–L6 depend on L1 being applied first.
3. **`roles/L6_runtime/backup/` - consolidated backup role** - previously separate `roles/backup` (L5) and `roles/stack_backup` (L6) roles were consolidated into a single role with `backup_role_source` dispatch per ADR-09.
4. **Engine (Compose) and Manager (Portainer) are independent axes** - removing Portainer does not affect Compose stacks.
5. **Profile schema (L5) contains zero Compose-specific directives** - the same profile works across runtimes (Compose, Swarm, K3s).
6. **Operator-managed applications** - L5 profiles under `apps/` are tested references. The suite does not deploy applications; it prepares the infrastructure for the operator's workloads.

---

## 6. AMD64 / ARM64 Compatibility Table

### Per-Component Architecture Support

| Component                      | AMD64        | ARM64 (Ampere) | Notes                                                                                           |
| ------------------------------ | ------------ | -------------- | ----------------------------------------------------------------------------------------------- |
| **OS - Debian 12**             | ✅ Supported | ✅ Supported   | ARM64 tested on Oracle Ampere A1 instances                                                      |
| **OS - Ubuntu 22.04**          | ✅ Supported | ✅ Supported   | ARM64 tested on Oracle Ampere A1 instances                                                      |
| **OS - Ubuntu 24.04**          | ✅ Supported | ✅ Supported   | ARM64 tested on Oracle Ampere A1 instances                                                      |
| **OS - Debian 11**             | ✅ Supported | ✅ Supported   | ARM64 tested on Oracle Ampere A1 instances                                                      |
| **Docker Engine**              | ✅ Supported | ✅ Supported   | Same version on both architectures; `docker.com` apt repo is multi-arch                         |
| **Portainer BE**               | ✅ Supported | ✅ Supported   | Official multi-arch Docker image                                                                |
| **Caddy**                      | ✅ Supported | ✅ Supported   | Official binary is multi-arch (Go-compiled)                                                     |
| **CrowdSec**                   | ✅ Supported | ✅ Supported   | apt repo provides multi-arch packages                                                           |
| **Tailscale**                  | ✅ Supported | ✅ Supported   | Official binary is multi-arch                                                                   |
| **Ansible roles (L1–L6)**      | ✅ Supported | ✅ Supported   | No architecture-specific logic; OS detection via `gather_facts`                                 |
| **Ansible Galaxy collections** | ✅ Supported | ✅ Supported   | `community.general`, `community.docker` are architecture-agnostic                               |
| **Chatwoot image**             | ✅ Supported | ✅ Supported   | Multi-arch Docker image                                                                         |
| **n8n image**                  | ✅ Supported | ✅ Supported   | Multi-arch Docker image                                                                         |
| **Twenty CRM image**           | ✅ Supported | ✅ Supported   | Multi-arch Docker image; arm64 manifest-verified in v2.26.0 (2026-07-31)                        |
| **OpenWebUI image**            | ✅ Supported | ✅ Supported   | Multi-arch Docker image                                                                         |
| **Metabase image**             | ✅ Supported | ✅ Supported   | Multi-arch Docker image                                                                         |
| **NocoDB image**               | ✅ Supported | ✅ Supported   | Multi-arch Docker image                                                                         |
| **ClickHouse image**           | ✅ Supported | ✅ Supported   | `26.3.17.56` registry-verified amd64+arm64 (2026-07-31); 26.3 is the LTS branch                 |
| **MariaDB image**              | ✅ Supported | ✅ Supported   | Multi-arch Docker image (11.4 LTS series)                                                       |
| **PostgreSQL image**           | ✅ Supported | ✅ Supported   | Multi-arch Docker image (`17.10-alpine`; shared 17 line)                                        |
| **OpenLit image**              | ✅ Supported | ✅ Supported   | GHCR multi-arch image (1.24.1)                                                                  |
| **Uptime Kuma image**          | ✅ Supported | ✅ Supported   | Multi-arch Docker image (2.4.0)                                                                 |
| **FastAPI (community)**        | ⚠️ Untested  | ⚠️ Untested    | Community-provided example - user must provide multi-arch Dockerfile or pin to `supported_arch` |
| **VictoriaMetrics**            | ✅ Supported | ✅ Supported   | Multi-arch Docker image                                                                         |
| **Grafana**                    | ✅ Supported | ✅ Supported   | Multi-arch Docker image                                                                         |
| **Loki**                       | ✅ Supported | ✅ Supported   | Multi-arch Docker image                                                                         |

**Validation rule**: Every app profile `profile.yml` MUST declare `supported_arch`. The `apps.yml` playbook validates that the target host architecture is in the list before deployment. Deployment fails with a clear architecture mismatch error if the host arch is not in `supported_arch`.

---

## 7. Host Classes - brain / muscle / local

### Capability Matrix

| Capability            | `brain`                                                                                                           | `muscle`                                                                               | `local`                                                        |
| --------------------- | ----------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------- | -------------------------------------------------------------- |
| **Backups**           | ✅ Enabled - app data (L5) + runtime state (L6)                                                                   | ✅ Enabled - app data (L5) + runtime state (L6)                                        | ❌ Disabled                                                    |
| **Observability**     | ✅ Full stack (VictoriaMetrics, Grafana, Loki)                                                                    | ✅ Full stack (VictoriaMetrics, Grafana, Loki)                                         | ❌ Disabled                                                    |
| **Hardening Profile** | Server-grade (`hardening_profile: server`)                                                                        | Server-grade (`hardening_profile: server`)                                             | Workstation-grade (`hardening_profile: workstation`)           |
| **Resource Profile**  | Management node - moderate CPU, persistent storage for backups + evidence                                         | Compute worker - higher CPU/RAM for application workloads, persistent storage for data | Personal workstation - variable, no guaranteed resources       |
| **Failure Domain**    | Single point of failure for management (Portainer, Grafana, monitoring). Redundancy via multiple brains possible. | Stateless apps - any muscle node can be replaced.                                      | Independent - failure does not affect other nodes              |
| **CrowdSec**          | ✅ Installed (collaborative IPS)                                                                                  | ✅ Installed (collaborative IPS)                                                       | ❌ Skipped (false positives from network changes)              |
| **Tailscale Auth**    | Automated (`--authkey`)                                                                                           | Automated (`--authkey`)                                                                | Manual (`tailscale up` by user)                                |
| **UFW Policy**        | Default deny (`policy: deny`)                                                                                     | Default deny (`policy: deny`)                                                          | Deny (Zero Trust base layer; inbound denied, outbound allowed) |
| **Fail2ban Bantime**  | 1 hour                                                                                                            | 1 hour                                                                                 | 10 minutes (avoids lockout without IPMI/console)               |

### Allowed Roles per Class

| Host Class | Allowed Roles                                                                                                                                                                                                                                                                                                                 | Typical Count                 |
| ---------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------- |
| **brain**  | `L1_os_baseline/general`, `L2_compliance/general/tasks/security`, `L2_compliance/general` (user_hardening, tailscale), `L2_compliance/nist_800_53` (CrowdSec, compliance), `L3_observability/general`, `L4_networking/caddy`, `L6_runtime/docker_compose`, `L6_runtime/portainer` (optional), `L6_runtime/backup`             | 1 per platform (or ≥2 for HA) |
| **muscle** | `L1_os_baseline/general`, `L2_compliance/general/tasks/security`, `L2_compliance/general` (user_hardening, tailscale), `L2_compliance/nist_800_53` (CrowdSec, compliance), `L3_observability/general`, `L4_networking/caddy`, `L6_runtime/docker_compose`, `L6_runtime/portainer` (optional, Edge Agent), `L6_runtime/backup` | N (scale horizontally)        |
| **local**  | `L1_os_baseline/general`, `L2_compliance/general/tasks/security` (workstation profile), `L2_compliance/general` (tailscale, manual auth, `tag:local`), `L6_runtime/docker_compose`                                                                                                                                            | Per operator                  |

### Host Class Selection

Determined by `group_vars/{brain,muscle,local}/main.yml`. A host's inventory group membership determines which group_vars are applied. The `hardening_profile` variable is set per class:

- `brain/main.yml` → `hardening_profile: server`
- `muscle/main.yml` → `hardening_profile: server`
- `local/main.yml` → `hardening_profile: workstation`

---

## 8. Application Profile Schema (Reduced 6-Field Specification)

### Profile Schema Fields

The standard `apps/<app>/profile.yml` declares exactly six fields:

| #   | Field             | Obligation | Type             | Description                                                                                                                                                                                                                                                         |
| --- | ----------------- | ---------- | ---------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | `supported_arch`  | **MUST**   | array of strings | Architectures the pinned image is published for, verified per image manifest (e.g., `[amd64, arm64]`). The playbook refuses deployment if the host arch is not in this list.                                                                                        |
| 2   | `depends_on`      | SHOULD     | array of objects | Dependencies on other roles or apps. Each entry has `role` (string). Currently `[]` for all standardized apps.                                                                                                                                                      |
| 3   | `monitoring`      | **MUST**   | object           | Declarative monitoring metadata (L3 wiring is not automated). Fields: `enabled` (bool, `true` on all 11), `health_endpoint` (path, starts with `/`), `health_port` (int), `scrape_port` (int).                                                                      |
| 4   | `compliance_tags` | **MUST**   | array of strings | Uniform compliance vocabulary: web/worker apps `[cis-docker:4.1, cis-docker:5.1, cis-os:5.1.2, soc2:cc6.1, iso27001:a.8.2.3]`; DB/cache services additionally `[cis-docker:4.5, soc2:cc6.6, iso27001:a.12.4.1]`.                                                    |
| 5   | `dr_tier`         | **MUST**   | enum             | Disaster recovery priority: `tier1` (RPO ≤ 4h, RTO ≤ 24h), `tier2` (RPO 24h, RTO 48h), `tier3` (best-effort). Replaces the legacy `critical`/`standard`/`best-effort` enum.                                                                                         |
| 6   | `backup`          | **MUST**   | object           | Backup themes: `method` (`pg_dump`, `mysqldump`, `clickhouse-backup`, `file-volume`), `schedule` (systemd OnCalendar syntax), `retention_daily`/`retention_weekly`/`retention_monthly`, `verification`, plus `db_type`/`db_name` retained for backup-role dispatch. |

### Dropped Fields (2026-07-31)

The previously documented 11-field schema (`name`, `version`, `compose_file`, `vars_file`, `secrets_file`, `target_group`, …) was never enforced and referenced files that do not exist (`compose.yml.j2`, `vars.yml`, `secrets.yml`). It is replaced by the 6-field schema above:

- **`name`** - removed. The app name is **derived from the directory path** (`apps/<name>/profile.yml` → `<name>`); the backup role derives it from the profile path and asserts `^[a-z0-9_-]+$` before rendering any unit.
- **`version`** - removed. The version is the **compose image pin** (`${APP_IMAGE:-org/image:tag}`); the pin table in `docs/operations/VERSION_PINS.md` is the single source of truth.
- **`target_group`** - removed.
- **`compose_file` / `vars_file` / `secrets_file`** - removed. The standard layout is `docker-compose.yml` + `.env.example` + `profile.yml` (+ `assets/` only when compose bind-mounts files); no Jinja2 templates, no per-app vars/secrets manifests.

### Validation Rules

1. **MUST fields**: `supported_arch`, `monitoring`, `compliance_tags`, `dr_tier`, `backup` - all present and non-empty; `depends_on` SHOULD be present.
2. **Rejected fields**: `name`, `version`, `target_group` MUST NOT appear in a standardized profile (validated 2026-07-31; only `apps/fastapi/` retains the legacy layout, excluded from standardization).
3. **`dr_tier`**: only `tier1`, `tier2`, `tier3` are accepted.
4. **`backup.method`**: one of `pg_dump`, `mysqldump`, `clickhouse-backup`, `file-volume`. `db_type`/`db_name` retained for backup-role dispatch; `none`/`custom` skip semantics preserved.
5. **`monitoring`**: `enabled: true` by default on all 11 profiles; `health_endpoint` must start with `/`.

### Example: n8n Profile

```yaml
# apps/n8n/profile.yml
supported_arch: [amd64, arm64] # verified per image manifest
depends_on: [] # kept

monitoring:
  enabled: true
  health_endpoint: "/healthz"
  health_port: 5678
  scrape_port: 5678

compliance_tags:
  - cis-docker:4.1
  - cis-docker:4.5
  - cis-docker:5.1
  - cis-os:5.1.2
  - soc2:cc6.1
  - soc2:cc6.6
  - iso27001:a.8.2.3
  - iso27001:a.12.4.1

dr_tier: tier1

backup:
  method: pg_dump
  schedule: "*-*-* 00/4:00:00" # systemd OnCalendar - every 4 hours (tier1)
  retention_daily: 7
  retention_weekly: 4
  retention_monthly: 12
  verification: monthly-restore-test
  db_type: postgres
  db_name: n8n
```

---

## 9. Application Catalog

Each app directory follows the standard layout - `docker-compose.yml` (with the `x-<app>-env` anchor pattern and `${APP_IMAGE:-org/image:tag}` pins), `.env.example`, `profile.yml`, plus `assets/` only when compose bind-mounts files (currently no app does - all config is env-only as of 2026-07-31). See [LAYER_BOUNDARIES.md](LAYER_BOUNDARIES.md) L5. Image versions are pinned in the compose default - the version table lives in [VERSION_PINS.md](../operations/VERSION_PINS.md) (SSOT). DR-tier schedule/retention/verification policy lives in [BACKUP_STRATEGY.md](../operations/BACKUP_STRATEGY.md) (SSOT).

### Catalog Table

| #   | App Name            | Description                                                 | DB Type                          | DR Tier | Port Map (host:container) | Image                                   |
| --- | ------------------- | ----------------------------------------------------------- | -------------------------------- | ------- | ------------------------- | --------------------------------------- |
| 1   | **Chatwoot**        | Open-source customer support platform                       | PostgreSQL (pgvector)            | tier1   | 3000:3000                 | ❌ Official multi-arch                  |
| 2   | **n8n**             | Fair-code workflow automation                               | PostgreSQL                       | tier1   | 5678:5678                 | ❌ Official multi-arch                  |
| 3   | **Twenty CRM**      | Modern open-source CRM                                      | PostgreSQL                       | tier1   | 3001:3000                 | ❌ Official multi-arch (arm64 verified) |
| 4   | **Metabase**        | Business intelligence and analytics                         | PostgreSQL (application-managed) | tier1   | 3002:3000                 | ❌ Official multi-arch                  |
| 5   | **NocoDB**          | Open-source Airtable alternative (database-spreadsheet)     | PostgreSQL                       | tier1   | 8081:8080                 | ❌ Official multi-arch                  |
| 6   | **OpenWebUI**       | Self-hosted AI chat interface                               | PostgreSQL                       | tier2   | 8080:8080                 | ❌ Official multi-arch                  |
| 7   | **PostgreSQL**      | Shared PostgreSQL engine (17 line)                          | PostgreSQL                       | tier2   | 5432:5432                 | ❌ Official multi-arch                  |
| 8   | **ClickHouse**      | Columnar analytics database                                 | ClickHouse                       | tier2   | 8123:8123                 | ❌ Official multi-arch (26.3 LTS)       |
| 9   | **MariaDB**         | MariaDB relational database                                 | MariaDB                          | tier2   | 3306:3306                 | ❌ Official multi-arch (11.4 LTS)       |
| 10  | **Uptime Kuma**     | Self-hosted uptime monitoring                               | SQLite (named volume)            | tier2   | 3001:3001                 | ❌ Official multi-arch                  |
| 11  | **OpenLit**         | LLM observability (OpenTelemetry)                           | ClickHouse (embedded, pinned)    | tier3   | 3001:3001                 | ❌ GHCR multi-arch                      |
| 12  | **FastAPI Backend** | Custom FastAPI backend (example/template for user projects) | PostgreSQL (configurable)        | -       | 8000:8000                 | ⚠️ **Community-provided**               |

> **FastAPI** is excluded from the standardization scope: it retains the legacy layout (see §10) and is not part of the 11-app schema/compose contract.

---

## 10. Custom Docker Image Requirements - FastAPI

### Community-Provided Status

The **FastAPI** application profile is marked **community-provided**. Unlike the other 6 apps (which use official multi-arch Docker images), the FastAPI entry is a **template** for users who need to deploy their own backend. The project does NOT build, maintain, or publish a FastAPI Docker image.

### Required User Configuration Checklist

| #   | Requirement               | Details                                                                                                                                                                                                                                                 |
| --- | ------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | **Dockerfile source**     | User must provide a `Dockerfile` in the `apps/fastapi/` directory. The project ships a `Dockerfile.example` as a reference. The user is responsible for building and pushing the image to a registry (or using a local build).                          |
| 2   | **Port exposure**         | The FastAPI app MUST expose port `8000` (default). If a different port is needed, update `vars.yml` → `fastapi_port` and the compose template accordingly.                                                                                              |
| 3   | **Health endpoint**       | The app MUST expose a health check endpoint. Default: `/health` returning HTTP 200. The monitoring layer (L3) uses this for scrape targets. If the endpoint differs, update `monitoring.health_endpoint` in `profile.yml`.                              |
| 4   | **Environment variables** | All configuration MUST be passed via environment variables (not hardcoded in the Dockerfile). Required vars: `DATABASE_URL`, `SECRET_KEY`, `ENVIRONMENT`. Define them in `apps/fastapi/secrets.yml` (Vault) and reference them in the compose template. |
| 5   | **Multi-arch support**    | The user is responsible for ensuring the Docker image supports their target architecture(s). `supported_arch` in `profile.yml` must match the actual image availability. If only amd64 is available, set `supported_arch: [amd64]`.                     |
| 6   | **Image registry**        | The compose template references `fastapi_image` from `group_vars/all/images.yml`. The user must set this variable to their image (e.g., `ghcr.io/myorg/myapp:v1.0.0`).                                                                                  |

### Reference Files in `apps/fastapi/`

| File                 | Purpose                                                          | User Action                                  |
| -------------------- | ---------------------------------------------------------------- | -------------------------------------------- |
| `profile.yml`        | Declares app metadata, backup policy, monitoring, supported_arch | Review and adjust per deployment             |
| `vars.yml`           | Configurable parameters (port, DB settings, resource limits)     | Adjust for your app                          |
| `compose.yml.j2`     | Jinja2 compose template referencing variables                    | Replace if your app needs different services |
| `secrets.yml`        | Secrets manifest (keys required, values from Vault)              | Add your app's secret keys                   |
| `Dockerfile.example` | Reference Dockerfile - not used by Ansible                       | Replace with your actual Dockerfile          |

> ⚠️ **The FastAPI profile is a starting point, not a turn-key deploy.** Unlike Chatwoot or n8n (which deploy with a single `make deploy`), deploying FastAPI requires the user to build and publish a Docker image first. This is intentional - the platform provides the infrastructure pattern; the user provides the application.

---

## 11. Runtime Adapter Abstraction Points

### Abstraction Table: Profile Fields → Runtime Interpretation

| Profile Field                                                       | Compose (Default)                                                                                                 | Swarm (Future)                                              | K3s (Future)                                               |
| ------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------- | ---------------------------------------------------------- |
| `backup` (method/schedule/retention/verification, db_type, db_name) | Backup role renders `backup-db-<app>.timer`/`.service` from `backup.schedule` (OnCalendar) and `db_type` dispatch | `pg_dump` / `mysqldump` pod with CronJob equivalent         | Kubernetes CronJob with persistent volume claims           |
| `monitoring` (enabled/health_endpoint/health_port/scrape_port)      | HTTP GET check via VictoriaMetrics/Grafana scrape config                                                          | HTTP GET check (same)                                       | Kubernetes liveness/readiness probe from `health_endpoint` |
| `supported_arch`                                                    | Constraint: `docker compose up` only if host arch ∈ list                                                          | Constraint: `docker stack deploy` only if swarm nodes match | Constraint: nodeSelector with `kubernetes.io/arch` label   |
| `depends_on`                                                        | Ansible playbook ordering (role dependencies)                                                                     | Ansible playbook ordering (same)                            | Kubernetes init containers or dependency checks            |

### Invariant: Zero Compose-Specific Directives

The profile schema is **runtime-agnostic**. Key design choices:

- The app **name is derived from the directory path** (`apps/<name>/`), never from a field; versions come from the compose image pin (`${APP_IMAGE:-...}`).
- `backup` declares the **data** to protect (method, schedule, retention, verification, db_type, db_name), not the backup mechanism.
- `monitoring` declares the **target** (endpoint, port), not the scrape mechanism.
- `supported_arch` and `depends_on` are cross-runtime constraints shared by every adapter.

**Migration path**: When Swarm or K3s adapters are implemented, no profile changes are needed. The runtime adapter (L6) reads the same profile and renders the appropriate format.

---

## Appendix: Architecture Decision Records (ADR) Summary

- [ADR-01: Docker Compose - Engine y Manager separados](adr/ADR-01.md)
- [ADR-02: YAML Profiles over DSL](adr/ADR-02.md)
- [ADR-03: Four Layers of Variables](adr/ADR-03.md)
- [ADR-04: Abstraction by Convention](adr/ADR-04.md)
- [ADR-05: Variable-Driven OS Dispatch](adr/ADR-05.md)
- [ADR-06: apps/ over recommended_apps/](adr/ADR-06.md)
- [ADR-07: Engine/Manager Decoupling](adr/ADR-07.md)
- [ADR-08: Backup Roles Consolidation (superseded)](adr/ADR-08.md)
- [ADR-09: AMD64/ARM64 Mandatory Compatibility](adr/ADR-09.md)

---

## References

- Architecture: See the Architecture documentation (sections on 7-layer model, directory layout, and implementation roadmap)
- Ansible Best Practices: https://docs.ansible.com/ansible/latest/user_guide/playbooks_best_practices.html
- NIST 800-53 Rev 5: https://nvlpubs.nist.gov/nistpubs/SpecialPublications/NIST.SP.800-53r5.pdf

## Related Documents

- `docs/architecture/LAYER_BOUNDARIES.md` - Layer boundary contracts (L0-L6)
- `docs/GLOSSARY.md` - Terminology bridge
- `docs/compliance/COMPLIANCE-MAPPING-STATUS.md` - Compliance framework overview and mapping status
- `docs/compliance/NIST/NIST_800_53.md` - Control-to-role-to-evidence traceability
- `docs/compliance/evidence/EVIDENCE_MODEL.md` - Evidence collection audit trail
- `docs/operations/DEVELOPER_SETUP.md` - Operator onboarding guide
- `docs/operations/INCIDENT_RESPONSE_DR.md` - Incident response and disaster recovery runbook

- `docs/project/CONTRIBUTORS_DOC_GUIDE.md` - Contributors documentation guide
