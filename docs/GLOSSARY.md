---
title: Developmi Stack Glossary
type: architecture
owner: maintainers
audience: all
version: v6.0.0
last-reviewed: 2026-07-26
status: active
project: developmi-stack
repo: github.com/Developmi/stack
---

# Developmi Stack Glossary

A single source of truth for terminology used across the **Developmi Stack** (formerly stack). This consolidated glossary covers platform architecture, shared infrastructure, compliance frameworks, project governance, and our Spec-Driven Development (SDD) workflow.

---

## 1. Platform Architecture & Operations

Terms defining how nodes are classified, hardened, and operated within the infrastructure.

### Core Terminology

| Term | Definition |
| --- | --- |
| **make target** | A named Makefile command (e.g., `make deploy`, `make nuke`). The primary operator interface. |
| **overlay transport** | The policy requiring Tailscale VPN for non-bootstrap playbook operations (e.g., `engine.yml`, `exporters.yml`, `nuke.yml`). |
| **phase** | A deployment stage in the Makefile orchestration (Phase 0 through Phase 7). |
| **ponytail mode** | Lazy/YAGNI-first development mode. Enforces: stdlib before dependency, deletion over addition, shortest working diff. |
| **Zero Trust** | Security model where no actor is trusted by default. Enforced via Tailscale ACLs, overlay-only transport, and pull-based management. Aligned to NIST SP 800-207. |

### Host Classes & Profiles

| Class / Term | Definition / Attributes |
| --- | --- |
| **brain** | Hetzner management node - central services, ingress, and observability host. (Allowed: All L1-L6 roles |
| **muscle** | OCI compute nodes - workload execution and optional edge services. (Allowed: L1-L4, L5 app-specific |
| **local** | Local workstation nodes. (Allowed: L1-L2, L6 engine only |
| **hardening profile** | Security configuration applied per node type (e.g., `server` for brain/muscle vs. `workstation` for local). |
| **workstation hardening** | A tailored hardening profile for local devices (desktops, laptops) with relaxed UFW policy and skipped CrowdSec. |

---

## 2. Infrastructure Layers & Topologies

The Developmi Stack is segregated into a strict 7-layer architecture.

**Layer 0 (Commercial Infra)**: Bare-metal/cloud provisioning with OpenTofu. See [ARCHITECTURE.md §1](../architecture/ARCHITECTURE.md).
**Layer 1 (OS Baseline)**: Package manager, update/hold policies, auto-upgrade, OS detection, AMD64/ARM64 compatibility.
**Layer 2 (Compliance)**: SSH hardening, firewall, fail2ban, CrowdSec, kernel hardening, NIST/CIS evidence.
**Layer 3 (Observability)**: VictoriaMetrics, Grafana, Loki, scrape targets, alerting.
**Layer 4 (Networking/Edge)**: Caddy reverse proxy, TLS certs, WAF, ingress routing.
**Layer 5 (Application Profiles)**: Declarative YAML profile schema per app under `apps/`. Profiles are tested references — deployment is operator-managed.
**Layer 6 (Runtime Adapters)**: Docker Engine (Compose), Portainer (optional), consolidated backups.

---

## 3. Technical Implementation

Mappings for variables, paths, and configurations across the codebase.

### Variable Hierarchy (4 Layers)

The stack follows a strict precedence model for variables:

1. `app_<name>/vars.yml` *(Per-application profile overrides)*
2. `brain|muscle|local/main.yml` *(Per-group host class config)*
3. `all/main.yml` *(Global safe defaults)*
4. `roles/<role>/defaults/main.yml` *(Role-level fallbacks)*

### Ansible Vault & Secrets Management

AES256-encrypted secret management mechanism with the password stored locally at `/tmp/.vault_pass`. **Ansible Vault is the strict Single Source of Truth (SSOT) for secrets.**

- **Global secrets** (`group_vars/all/secrets.yml`): Tailscale, GitHub token, Portainer admin, Telegram bot.
- **App-declared secrets** (`apps/<name>/secrets.yml`): Keys specifically required for an application.

> **Note:** Any alerts raised by `detect-secrets` inside `apps/<name>/vars.yml` or `profile.yml` are known false positives related to operational parameters (e.g., backup paths).

### Key Directories

| Path | Layer | Purpose |
| --- | --- | --- |
| `apps/<name>/` | L5  | Application profiles (profile.yml, vars.yml, secrets.yml, compose.yml.j2). Deployed via Portainer/SSH. |
| `runtime/compose/` | L6  | Docker Compose adapter (deploy.yml.j2, defaults.yml) |
| `inventory/group_vars/all/` | L1-L6 | Global safe defaults + secrets |
| `inventory/group_vars/brain/` | Host Class | Server-grade, backups + observability definitions |

### Playbooks & Roles

| File / Prefix | Purpose |
| --- | --- |
| `playbooks/site.yml` | Full OS baseline + compliance (L1 + L2). |
| `playbooks/l6/*.yml` | Runtime, Portainer, and backup deployment (L6). |
| `playbooks/l3/*.yml` | Observability stack and exporters deployment (L3). |
| `playbooks/l2/compliance.yml` | Auto-collects NIST 800-53 evidence (L2). |
| `stack_*` (Role) | Legacy naming — roles are now under `L6_runtime/` (backup, portainer, general). |
| `*-timers` (Role) | Scheduled task roles (L5) e.g., `backup-timers`. |

### Tag Conventions

- **Functional:** lowercase (e.g., `ssh`, `firewall`, `docker`, `backup`).
- **Compliance:** `nist,<control-id>` (e.g., `nist,ac-2`, `nist,sc-7`).
- **Layer:** `l<number>-<name>` (e.g., `l1-os-baseline`).

---

## 4. Toolchain, Technologies & Compliance

| Term | Category | Definition |
| --- | --- | --- |
| **Caddy** | Toolchain | Reverse proxy and ingress layer. Handles TLS termination, routing, and security headers. |
| **CIS Benchmarks** | Compliance | Consensus-developed secure configuration guidelines for Ubuntu/Debian. |
| **Coraza WAF** | Toolchain | Web Application Firewall integrated into Caddy. |
| **CrowdSec** | Toolchain | Collaborative IPS. Behavior-based detection with global threat intelligence. |
| **DORA** | Compliance | Digital Operational Resilience Act (EU). Monitored and repeatable via Ansible automation. |
| **ENS** | Compliance | Esquema Nacional de Seguridad (Spain). Technical equivalence mapped internally. |
| **evidence model** | Compliance | Evidence collection workflow - defined in `EVIDENCE_MODEL.md`. |
| **finops** | Operations | Cost tracking and optimization discipline. |
| **MITRE ATT&CK** | Compliance | Defensive mapping framework for adversary tactics and techniques. |
| **NIST 800-53** | Compliance | Primary compliance framework. Controls AC-2, CM-7, SC-7, SI-4, AU-12, SC-28 implemented. |
| **NIST control** | Compliance | A specific security control from NIST SP 800-53 (e.g., AC-2, SC-7). |
| **OpenTofu** | Toolchain | Open-source infrastructure-as-code tool (Terraform fork) used for Layer 0 provisioning. |
| **Portainer** | Toolchain | Docker management UI using a pull-based Edge Agent architecture (zero open ports). |
| **Tailscale** | Toolchain | WireGuard-based zero-trust VPN mesh. Provides ACL-driven access with NAT traversal. |
| **uv** | Toolchain | Python package manager. Used for all toolchain operations (sync, lint, playbook execution). |

### Evidence Paths

Compliance artifacts are systematically exported to:

```text
/srv/evidence/
├── nist/
│   ├── ac-2/  (ssh_config, sudoers_audit, user_list)
│   ├── cm-7/  (kernel modules)
│   ├── sc-7/  (ufw/nftables status, fail2ban)
│   ├── si-4/  (crowdsec alerts, auditd rules)
│   └── au-12/ (audit logs)
├── cis/
└── app-specific/ (e.g., chatwoot, n8n)
```

---

## 5. SDD & Project Workflow

Terminology specific to our internal operations, AI-assisted persistence, and document management.

### Persistence & Context

| Term | Definition |
| --- | --- |
| **engram** | Persistent memory system utilized by our AI tools (`mem_save`, `mem_search`, `mem_context`) + `.atl` flat files for session persistence. |
| **SDD persistence** | Hybrid backend - Engram for cross-session AI memory, `.atl` flat files for specification versioning. |

### Spec-Driven Development (SDD)

| Term | Definition |
| --- | --- |
| **SDD** | Spec-Driven Development - the structured workflow for proposing, specifying, designing, implementing, and verifying changes. |
| **Change** | A unit of work: proposal → spec → design → tasks → apply → verify → archive. |
| **Proposal** | The intent document: what, why, scope, risks, success criteria. |
| **Spec** | Requirements with GIVEN/WHEN/THEN scenarios and acceptance criteria. |
| **Design** | Technical approach with architecture decisions, data flow, file changes, interfaces. |
| **Tasks** | Implementation checklist broken into phases. |
| **Apply** | Implementation phase - writing code/docs according to specs and design. |
| **Verify** | Validation phase - checking implementation against specs, design, and tasks. |
| **Archive** | Closing a completed change and syncing delta specs to main specs. |
| **Artifact** | Any output document of an SDD phase (e.g., `proposal.md`, `spec.md`). |
| **Delta spec** | A spec written for a specific change containing only modified/introduced requirements. |
| **Mainline spec** | The canonical spec for the project, built by merging delta specs post-archive. |

### Project Governance & Documentation

| Term | Definition |
| --- | --- |
| **Audience** | The primary reader persona for a document (maintainer, contributor, operator, auditor). |
| **Cross-reference** | A link from one doc to another with a brief "why" explanation to avoid SSOT duplication. |
| **Frontmatter** | YAML block at the top of every document with title, type, owner, version, status. |
| **Owner** | The person or team responsible for a document's accuracy and review cadence. |
| **Review cadence** | How often a document must be reviewed (quarterly, per release, per audit cycle). |
| **Status** | Document lifecycle state: `active` (current), `reference` (informational), `deprecated`. |
| **Trace** | The `trace` field in frontmatter - links a document to its parent SDD artifact. |
| **DOC_ARCHITECTURE** | Meta-document defining documentation conventions, structures, and styles. |
| **CROSS_REFERENCE_MAP** | Matrix showing every document and its related boundaries. |
| **OWNERSHIP_REGISTRY** | The registry mapping every document to its owner and schedule. |
| **CONTRIBUTORS_DOC_GUIDE** | Guide for contributors on how to add, update, or deprecate documentation. |