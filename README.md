<div align="center">

<img src="docs/assets/developmi-stack.webp" width="180" alt="Developmi Stack logo" />

# Developmi Stack

_A layered infrastructure stack built with Ansible, Docker and Zero Trust principles._

![Python 3.14](https://img.shields.io/badge/Python-3.14-3776AB?style=for-the-badge&logo=python&logoColor=white)
![Ansible Core 2.21.1](https://img.shields.io/badge/Ansible_Core-2.21.1-EE0000?style=for-the-badge&logo=ansible&logoColor=white)
![Docker Ready](https://img.shields.io/badge/Docker-Ready-2496ED?style=for-the-badge&logo=docker&logoColor=white)
![Standard NIST 800-53](https://img.shields.io/badge/Standard-NIST_800--53-0B5CAD?style=for-the-badge)
![Status In Development](https://img.shields.io/badge/Status-In_Development-orange?style=for-the-badge)
![License MIT](https://img.shields.io/badge/License-MIT_©-blue?style=for-the-badge)
![CI GitHub Actions](https://img.shields.io/badge/CI-GitHub_Actions-blue?style=for-the-badge&logo=githubactions&logoColor=white)
![Maintainer Miguel Lozano](https://img.shields.io/badge/Maintainer-Miguel_Lozano-black?style=for-the-badge)
![Role Cloud & Infrastructure Engineer](https://img.shields.io/badge/Role-Cloud_%26_Infrastructure_Engineer-black?style=for-the-badge)

</div>

> **The script is free. Peace of mind is not.**
>
> This repository delivers a reproducible hardening baseline, zero-trust access patterns, and optional containerized application bundles for managed infrastructure.

---

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Value Snapshot for CTO/CFO](#value-snapshot-for-ctocfo)
- [FinOps Case Study (Nuntu)](#finops-case-study-nuntu)
- [Field Validation Evidence](#field-validation-evidence)
- [Compliance & Standards](#compliance--standards)
- [Quick Start](#quick-start)
- [Operations with Make](#operations-with-make)
- [Architecture](#architecture)
- [Docker & Deployment](#docker--deployment)
- [Configuration & Secrets](#configuration--secrets)
- [Validation & Quality Gates](#validation--quality-gates)
- [Tests](#-tests)
- [Security](#-security)
- [Changelog](#-changelog)
- [Contributing](#-contributing)
- [License](#-license)
- [Documentation Guide](#documentation-guide)
- [Contact & Support](#contact--support)

---

## Overview

Developmi Stack is an Ansible-based infrastructure automation project focused on establishing a secure, auditable, and repeatable baseline across mixed-host environments.

It is designed to standardize the security posture of:

- **Brain nodes** for central services, ingress, and observability.
- **Muscle nodes** for workload execution and optional edge services.
- **Application stacks** under `apps/` deployed via Portainer (Edge agent).

The project aligns to **NIST 800-53** controls and emphasizes secrets handling, least privilege, hardened networking, and operational repeatability.

---

## Features

- 🛡️ **Security-first hardening** with SSH restrictions, firewall controls, audit logging, CrowdSec integration, and Vault-backed secrets.
- 🔐 **Zero-trust networking** through Tailscale ACL-driven access and minimized public exposure.
- 🧱 **Modular architecture** using Ansible roles for security, Docker orchestration, observability, compliance, ingress, and Portainer edge operations.
- 📦 **Optional application bundles** for Chatwoot, Metabase, n8n, OpenWebUI, Twenty CRM, and Uptime Kuma.
- 📈 **Operational visibility** with exporter and observability stack support when capacity allows.
- 🧪 **Validation gates** executed through Make targets (uv-backed) for linting, syntax checks, and secret scanning.
- 🧭 **Documented operating model** with commands centralized in `docs/operations/OPERATIONS_RUNBOOK.md`.

---

## Value Snapshot for CTO/CFO

In less than 30 seconds:

- **Cost Control:** Designed for self-hosted operation on VPS/Bare Metal to avoid linear SaaS cost growth.
- **Security Baseline:** NIST-aligned hardening with zero-trust networking and auditable controls.
- **Data Sovereignty:** Sensitive workloads stay in infrastructure you control.
- **Cloud-Exit Ready:** Portable Ansible playbooks and provider-agnostic architecture reduce lock-in.
- **Operational Predictability:** Pull-based management model and Make-driven runbooks reduce change risk.

---

## FinOps Case Study (Nuntu)

This project pattern has been applied to a real-world migration scenario (codenamed **Nuntu**) focused on sovereignty, security, and OpEx reduction.

### Business problem

- SaaS sprawl with linear OpEx growth by headcount.
- Data processed in third-party multi-tenant platforms.
- Vendor/API dependence creating operational fragility.

### Implemented approach

- Sovereign self-hosted stack on high-performance VPS fleet.
- Pull-based operations model (Portainer Edge pattern).
- Caddy + WAF perimeter with hardened default-deny posture.
- Security automation and compliance-oriented runbooks.

### Measured outcomes (reported case)

| Metric                 | Before (SaaS Sprawl) | After (Sovereign Self-Hosted)        | Impact                     |
| ---------------------- | -------------------- | ------------------------------------ | -------------------------- |
| Annual Software OpEx   | $X (baseline)        | $0.3X                                | **-70%**                   |
| Platform Uptime (Prod) | ~99.5%               | 99.8%                                | Higher reliability         |
| Data Sovereignty       | 0%                   | 100%                                 | Full control               |
| WAF Efficacy           | N/A                  | >99% block rate, <1% false positives | Enterprise-grade perimeter |
| Incident Response Time | Hours/Days           | Minutes                              | Stronger resilience        |
| Vendor Risk            | Critical             | Negligible                           | Supply-chain risk reduced  |

> **Scope note:** This case study is a field implementation narrative and not a vendor benchmark report. Results depend on workload, architecture, and governance discipline.

---

## Field Validation Evidence

Current documented execution evidence in this repository corresponds to a lab/staging scope with:

- **1 Brain node**
- **2 Muscle nodes**

This is intentionally presented as operational proof-of-execution while broader fleet rollouts are scheduled.

### Deployment proof screenshots

![Base hardening deployment evidence](docs/assets/make-deploy.png)



![Monitoring deployment evidence](docs/assets/make-deploy-monitoring.png)

---

## Compliance & Standards

This repository is not just "NIST-themed". It includes implementation-grounded compliance references with auditable mappings and evidence workflows.

### Primary control coverage

- **NIST SP 800-53:** AC-2, CM-7, SC-7, SI-4, AU-12, and SC-28 (partial for full disk encryption).
- **NIST SP 800-207 (Zero Trust):** overlay-network control path, identity/tag-based access, and pull-based management pattern.
- **CIS Level 1 (generic Ubuntu/Debian alignment):** SSH baseline, firewall posture, brute-force mitigation, and audit telemetry.
- **DORA/ENS contextual mapping:** documented as technical-functional alignment for resilience and governance discussions.

### Where to audit compliance details

- Compliance framework status and mapping: [docs/compliance/COMPLIANCE-MAPPING-STATUS.md](docs/compliance/COMPLIANCE-MAPPING-STATUS.md)
- Reproducible evidence workflow: [docs/compliance/evidence/EVIDENCE_MODEL.md](docs/compliance/evidence/EVIDENCE_MODEL.md)

> **Important:** This project provides implementation evidence and technical mappings. Formal certification readiness still requires organization-specific legal, scope, and auditor validation.

---

## Quick Start

### Prerequisites

- `uv` for Python dependency and environment management.
- Python 3.14 or newer.
- SSH access to the target hosts.
- Ansible Galaxy network access for collection installation.
- Docker Compose only if you plan to run optional app bundles.

### Setup

```bash
git clone https://github.com/Developmi/stack.git
cd stack
make sync
make install-collections
```

### Inventory

Create or customize your inventory before deployment:

```ini
[brain]
brain-1 ansible_host=YOUR_PUBLIC_IP ansible_user=root public_ip=YOUR_PUBLIC_IP

[muscle]
muscle-1 ansible_host=YOUR_PUBLIC_IP ansible_user=ubuntu public_ip=YOUR_PUBLIC_IP
```

### Secrets

Populate the Vault-backed secrets file and encrypt it before deployment:

```bash
make vault-init
make vault-encrypt
```

### Deploy

```bash
make validate
make deploy
make deploy-engine
make deploy-edge EDGE=caddy HOST=<brain>
make deploy-portainer
make deploy-observability-stack
```

> **Note:** The canonical command surface lives in [docs/operations/OPERATIONS_RUNBOOK.md](docs/operations/OPERATIONS_RUNBOOK.md). Use `make` targets instead of raw playbook calls when possible.

---

## Operations with Make

Make is the official command interface for this project. Day-to-day operations should run through Make targets.

### High-frequency operator commands

```bash
make help
make sync
make install-collections
make validate
make deploy
make deploy-engine
make deploy-edge EDGE=caddy HOST=<brain>
make deploy-portainer
make deploy-observability-stack
make verify-tailscale
make verify-crowdsec
make verify-observability
```

### Advanced and safety workflows

```bash
make deploy-tags PLAYBOOK=playbooks/site.yml ANSIBLE_TAGS='nist,sc-7'
make deploy-skip-tags PLAYBOOK=playbooks/site.yml ANSIBLE_SKIP_TAGS='tailscale,vpn'
make compliance
make nuke CONFIRM=DESTROY_ALL_INFRASTRUCTURE
make audit-full
```

Operational reference index:

- Primary runbook: [docs/operations/OPERATIONS_RUNBOOK.md](docs/operations/OPERATIONS_RUNBOOK.md)
- Production command-path controls: [docs/operations/OPERATIONS_RUNBOOK.md](docs/operations/OPERATIONS_RUNBOOK.md)
- Application deployment (via Portainer): [docs/operations/OPERATIONS_RUNBOOK.md](docs/operations/OPERATIONS_RUNBOOK.md)

---

## Architecture

### Simplified Tree

```text
.
├── playbooks/site.yml                 # Base hardening entry point
├── playbooks/l1/                      # L1 - OS baseline
├── playbooks/l2/                      # L2 - Compliance, hardening
├── playbooks/l3/                      # L3 - Observability, exporters
├── playbooks/l4/                      # L4 - Networking/Edge proxy
├── playbooks/l6/                      # L6 - Runtime (Engine, Portainer, backups)
├── playbooks/ops/                     # Operational playbooks (nuke, bootstrap, validate)
├── inventory/               # Target host inventory definitions
├── group_vars/              # Shared and group-specific variables
├── roles/                   # Ansible roles for platform capabilities
├── apps/                    # L5 application profiles (profile, vars)
├── docs/                    # Operational, compliance, and project documentation
└── scripts/                 # Bootstrap and monitoring helpers
```

### Execution Flow

```mermaid
flowchart LR
  Operator[Operator] --> Make[Make Targets]
  Make --> Ansible[Ansible Playbooks]
  Ansible --> Vault[Encrypted Secrets]
  Ansible --> Hosts[Brain and Muscle Hosts]
  Hosts --> Docker[Optional Docker Compose Bundles]
  Hosts --> Security[Hardening, Compliance, and Monitoring]
```

The role structure is intentionally separated so security controls, Docker orchestration, observability, and ingress can evolve independently without coupling the baseline hardening path.

---

## Docker & Deployment

Docker is used for application stacks and observability services, not as the primary automation runtime.

### Deploy Applications

All 8 application profiles (Chatwoot, Metabase, n8n, NocoDB, OpenWebUI, Twenty CRM, Uptime Kuma, FastAPI) are deployed through Portainer Edge agent with structured profiles under `apps/`. The `playbooks/apps.yml` was removed in the L1-L6 restructure - apps now deploy via Portainer's stack management. See [ARCHITECTURE.md §Application Profiles](docs/architecture/ARCHITECTURE.md#application-profiles) for the full schema.

### Security Notes

- Prefer publishing services through the hardened ingress layer instead of exposing broad host ports.
- Use the provided Vault workflow for sensitive runtime values.
- Application stacks are intended to run behind the project's reverse proxy and network segmentation model.
- App configuration lives in `apps/<name>/vars.yml` (Vault-encrypted secrets).

---

## Configuration & Secrets

This project does not require a root `.env.example`. Sensitive inputs are handled through Ansible Vault in `group_vars/all/secrets.yml`. Application-specific configuration lives in `apps/<name>/vars.yml` (Vault-encrypted secrets). See [ARCHITECTURE.md §App Profiles](docs/architecture/ARCHITECTURE.md#application-profiles) for the profile schema.

### Core Vault Template

```yaml
# group_vars/all/secrets.yml.example
vault_github_token: "GITHUB_TOKEN_GOES_HERE"
tailscale_auth_key: "tskey-client-XXXXXXXXXXXXXXXX"
portainer_edge_keys_by_node:
  brain-1: "PORTAINER_EDGE_KEY_FOR_BRAIN_1"
  muscle-1: "PORTAINER_EDGE_KEY_FOR_MUSCLE_1"
tailscale_acl_key: "tskey-client-YYYYYYYYYYYYYYYY"
tailscale_acl_client_id: "YOUR_TAILSCALE_OAUTH_CLIENT_ID"
caddy_acme_email: "ops@example.com"
```

### Optional Observability Values

These are required only when the observability stack is enabled:

- `observability_network_name`
- `observability_stack_host_ip`
- `observability_grafana_admin_user`
- `observability_grafana_admin_password`
- `observability_grafana_root_url`

### App Configuration

Application variables are managed through the Ansible variable hierarchy (5-tier precedence). Each app has:
- `apps/<name>/vars.yml` - Vault-encrypted secret key declarations
- `apps/<name>/profile.yml` - metadata (version, DB type, backup schedule, monitoring)

Apps deploy via Portainer (Edge agent). See [OPERATIONS_RUNBOOK.md §3](docs/operations/OPERATIONS_RUNBOOK.md) for the full deployment guide.

---

## Validation & Quality Gates

The repository is validated through uv-managed tooling and Ansible-native checks.

```bash
make sync
make install-collections
make validate
make lint PLAYBOOK=playbooks/site.yml
make precommit-run
```

Current quality gates include:

- YAML formatting validation.
- Ansible playbook syntax checks.
- Role and playbook linting.
- Secret detection with a tracked baseline.

> **Operational note:** `make lint` is intentionally strict and should be used before changes are promoted to shared environments.

---

## 🧪 Tests

This project is validated through Make-driven quality gates. For production-grade role testing, use `molecule` or `ansible-test` with a local inventory:

```bash
make validate
make lint PLAYBOOK=playbooks/site.yml
make precommit-run
```

**CI pipeline:** All playbooks pass syntax check and linting on every PR via [GitHub Actions](.github/workflows/ci.yml). A dedicated `security-audit.yml` workflow runs on version tags for release gating.

> **Note:** Automated role-level integration testing (e.g., Molecule) is on the roadmap. Current validation focuses on syntax, linting, idempotency dry-runs, and secret scanning - all exercised through `make` targets and CI.

---

## 🔒 Security

This project follows a coordinated disclosure policy.
If you discover a vulnerability, **do not open a public issue**.
See [SECURITY.md](./SECURITY.md) for reporting instructions, supported versions, and response timelines.

---

## 📋 Changelog

See [CHANGELOG.md](CHANGELOG.md) for the full version history.
The project follows [Keep a Changelog](https://keepachangelog.com/) and [Semantic Versioning](https://semver.org/).

---

## 🤝 Contributing

Contributions are welcome. Please read [CONTRIBUTING.md](./CONTRIBUTING.md) before opening a pull request.
This project follows [Conventional Commits](https://www.conventionalcommits.org/) and the Developmi engineering standard.

---

## 📄 License

Copyright © 2026 Miguel Lozano | Developmi. All rights reserved.
Licensed under the [MIT License](./LICENSE).

---

## Documentation Guide

For the full documentation index including architecture, compliance, operations, and project docs, see [docs/README.md](docs/README.md).

---

## Contact & Support

- **Maintained by:** Miguel Lozano | Developmi
- **Role:** Cloud & Infrastructure Engineer | FinOps & Bare Metal Specialist | AI Sovereignty Strategist under NIST/DORA Standards
- **Philosophy:** _Security is not a feature; it is the baseline._
- **Website:** [Developmi](https://developmi.com)
- **GitHub:** [Miguel-DevOps](https://github.com/Miguel-DevOps)
- **LinkedIn:** [Miguel Lozano](https://www.linkedin.com/in/miguel-dev-ops)

---

© 2026 Miguel Lozano | Developmi. All rights reserved.

## Related Documents

- [docs/README.md](docs/README.md) - Documentation index
- [docs/architecture/ARCHITECTURE.md](docs/architecture/ARCHITECTURE.md) - System design and security layers
- [docs/operations/OPERATIONS_RUNBOOK.md](docs/operations/OPERATIONS_RUNBOOK.md) - Operational command reference
- [docs/compliance/COMPLIANCE-MAPPING-STATUS.md](docs/compliance/COMPLIANCE-MAPPING-STATUS.md) - Compliance framework status and mapping
- [CONTRIBUTING.md](CONTRIBUTING.md) - Contribution guide (redirect)
