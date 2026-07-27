---
title: Repository Structure Reference
type: project
owner: maintainers
audience: all
version: v6.0.0
last-reviewed: 2026-07-16
status: active
project: developmi-stack
repo: github.com/Developmi/stack
---

# Repository Structure

Definitive directory-by-directory walkthrough of the Developmi Stack repository. Covers every top-level directory, all roles across 6 security layers, 11 playbooks, 8 application profiles, inventory structure, runtime adapters, and the Makefile build system.

---

## Top-Level Directory Overview

```
stack/
├── playbooks/               # Ansible playbooks - deployment orchestration (l1–l6/, ops/)
├── roles/                   # 5 role groups - by security layer (L1–L6)
├── inventory/               # Host inventory and group_vars
├── apps/                    # 8 L5 application profiles (profile, vars)
├── docs/                    # All project documentation
├── scripts/                 # Operational shell scripts
├── tests/                   # Test fixtures and validation
├── .github/workflows/       # CI/CD workflows (lint, security-audit)
├── Makefile                 # Build, deploy, and verification targets
├── ansible.cfg              # Ansible runtime configuration
├── requirements.yml         # Ansible Galaxy collection dependencies
├── pyproject.toml           # Python project metadata (uv toolchain)
├── requirements.txt         # Legacy pip requirements (immutable)
├── .pre-commit-config.yaml  # Pre-commit hook configuration
├── .ansible-lint            # Ansible lint configuration
└── .yamllint                # YAML lint configuration
```

| Directory            | Purpose                                                                            |
| -------------------- | ---------------------------------------------------------------------------------- |
| `playbooks/`         | Ansible playbooks orchestrating role execution across host groups (l1–l6/, ops/)    |
| `roles/`             | 5 role groups - the core logic (grouped by L1–L6 security layer)                   |
| `inventory/`         | Host inventory (`hosts.ini`) and group variables                                   |
| `apps/`              | 8 L5 application profile directories (`profile.yml`, `vars.yml`)                   |
| `docs/`              | All project documentation - architecture, operations, compliance, governance       |
| `scripts/`           | Operational scripts (`setup.sh`, `monitor-crowdsec.sh`, `validate-hierarchy.sh`)   |
| `tests/`             | Test fixtures and validation (`.codegraph/`, `fixtures/`)                          |
| `.github/workflows/` | GitHub Actions CI - lint, security audit                                           |

---

## Roles - Layer Reference (L1–L6)

Roles are the core of the hardening suite, each a self-contained Ansible unit with `tasks/`, `defaults/`, `vars/`, `handlers/`, `templates/`, and optionally `files/`. They are grouped by the security layer they implement.

### L1 - OS Baseline

Foundation layer. Applied first to every host.

| Role             | Purpose                                                                                  | Key Variables                                   |
| ---------------- | ---------------------------------------------------------------------------------------- | ----------------------------------------------- |
| `common`         | Hostname, timezone, NTP, locale, SSH banners, APT repositories                           | `timezone`, `hostname`, `ntp_servers`           |
| `packages`       | Essential system packages, APT cache updates, package pinning                            | `base_packages`, `apt_cache_valid_time`         |
| `security`       | SSH server hardening, auditd, UFW firewall, kernel parameters, PAM/sudo                  | `ssh_port`, `permit_root_login`, `auditd_rules` |
| `user_hardening` | User management, password policies, PAM configuration, account locking (NIST AC-2, AC-6) | `users`, `password_policies`, `pam_config`      |

### L2 - Compliance

Security validation and evidence collection.

| Role         | Purpose                                                                  | Key Variables                              |
| ------------ | ------------------------------------------------------------------------ | ------------------------------------------ |
| `compliance` | Read-only evidence collection, writes to `/srv/evidence/nist/<control>/` | `evidence_controls`, `evidence_output_dir` |
| `crowdsec`   | CrowdSec Intrusion Prevention System (NIST SI-4, IDS/IPS)                | `crowdsec_scenarios`, `crowdsec_api_key`   |

### L3 - Network / Edge

VPN mesh and network security boundary (part of L2_compliance role group).

| Role               | Purpose                                                                  | Key Variables                                            |
| ------------------ | ------------------------------------------------------------------------ | -------------------------------------------------------- |
| `L2_compliance/general` (tailscale tasks) | Tailscale mesh VPN client, OAuth key provisioning, ACL pre-configuration | `tailscale_auth_key`, `tailscale_tags`, `tailscale_args` |

### L4 - Runtime Engine

Container platform and reverse-proxy layer.

| Role            | Purpose                                                                    | Key Variables                                                  |
| --------------- | -------------------------------------------------------------------------- | -------------------------------------------------------------- |
| `L6_runtime/docker_compose` | Docker Engine, Compose plugin, user group membership, daemon configuration | `docker_users`, `docker_daemon_opts`, `docker_compose_version` |
| `L4_networking/caddy` | Caddy reverse proxy + Coraza WAF, TLS termination, service routing         | `caddy_config`, `waf_rules`, `ingress_domains`                 |

### L5 - Application Layer

App-specific data backup and scheduling.

| Role            | Purpose                                                                            | Key Variables                                  |
| --------------- | ---------------------------------------------------------------------------------- | ---------------------------------------------- |
| `L6_runtime/backup` | Database dump automation (PostgreSQL, MySQL, SQLite, Valkey) + Restic → R2 storage | `backup_databases`, `restic_repo`, `r2_bucket` |
| `L6_runtime/backup-db` | systemd `.timer` + `.service` units for scheduled backup execution                 | `backup_schedule`, `backup_retention`          |

### L6 - Orchestration & Observability

Container management, runtime backup, and monitoring stack.

| Role              | Purpose                                                               | Key Variables                                       |
| ----------------- | --------------------------------------------------------------------- | --------------------------------------------------- |
| `L6_runtime/portainer` | Portainer CE container management UI, agent deployment                | `enable_portainer`, `portainer_edition`             |
| `L6_runtime/backup`    | Restic-based backup of Docker volumes and stack configs to R2         | `stack_restic_repo`, `r2_stack_bucket`              |
| `L3_observability/general` | Prometheus exporters (node_exporter, cadvisor), VictoriaMetrics stack | `enable_observability`, `vm_url`, `scrape_interval` |

---

## Playbooks - Reference

Playbooks are organized by security layer (l1–l6), with additional operational playbooks under `ops/`. The top-level `site.yml` acts as a meta `import_playbook` orchestrator.

```
playbooks/
├── site.yml                                # Meta import_playbook - orchestrates l1–l6
├── l1/
│   └── baseline.yml                        # OS baseline (hostname, timezone, apt, kernel modules)
├── l2/
│   ├── hardening.yml                       # SSH, firewall, fail2ban, kernel hardening
│   ├── compliance.yml                      # NIST/CIS evidence collection
│   ├── lockdown.yml                        # Post-bootstrap SSH lockdown via Tailscale
│   ├── validate.yml                        # L2 hardening integrity audit (read-only)
│   └── tailscale-recover.yml               # Tailscale mesh VPN recovery (cloud console required)
├── l3/
│   ├── exporters.yml                       # node_exporter, cadvisor deployment
│   └── stack.yml                           # VictoriaMetrics, Grafana, Loki stack
├── l4/
│   └── edge.yml                            # Caddy reverse proxy + Coraza WAF
├── l5/                                     # (no standalone playbooks - apps deployed via L6 runtime)
├── l6/
│   ├── engine.yml                          # Docker Engine + Compose plugin
│   ├── portainer.yml                       # Portainer CE (optional manager)
│   ├── backup-stack.yml                    # Runtime state backup (Restic → R2)
│   ├── backup-appdata.yml                  # L5 application data backup (DB dumps + Restic)
│   ├── backup-timers.yml                   # systemd timer/service units for backup scheduling
│   └── backup-databases.yml                # DB auto-discovery backups (PostgreSQL + MariaDB)
└── ops/
    ├── bootstrap.yml                       # Initial node setup and toolchain install
    ├── nuke.yml                            # Deterministic teardown (confirmation-gated)
    ├── validate.yml                        # Syntax and pre-flight validation
    └── local-devices.yml                   # Workstation/laptop hardening over Tailscale
```

### Playbook Tags

All playbooks support Ansible tag filtering:

| Tag               | Scope                                    |
| ----------------- | ---------------------------------------- |
| `l1-os-baseline`  | Base OS configuration (common, packages) |
| `l2-compliance`   | NIST compliance hardening and evidence   |
| `l3-observability`| Observability stack (exporters + monitoring) |
| `l4-networking`   | Reverse proxy, WAF, ingress              |
| `l5-app-profiles` | Application deployment                   |
| `l6-runtime`      | Docker, Portainer, backup, observability |
| `compliance`      | Evidence collection only                 |
| `backup`          | Backup operations                        |

---

## Application Profiles (L5)

Eight application profiles live under `apps/`. Each profile contains two files:

| File          | Purpose                                                                                  |
| ------------- | ---------------------------------------------------------------------------------------- |
| `profile.yml` | Metadata: name, version, DB type, backup schedule, monitoring endpoints, compliance tags |
| `vars.yml`    | Variable defaults (non-secret: image tags, ports, resource limits)                       |

> **Note**: Some profiles include a per-app `README.md` with deployment guidance (e.g., `apps/fastapi/README.md`).

### Profile Table

| App          | Version | DB Type    | Backup Schedule | DR Tier  | Health Endpoint       |
| ------------ | ------- | ---------- | --------------- | -------- | --------------------- |
| `chatwoot`   | 4.12.1  | PostgreSQL | `*/4 * * * *`   | critical | `:3000/`              |
| `fastapi`    | 1.0.0   | custom     | `0 2 * * *`     | standard | `:8000/health`        |
| `metabase`   | 0.53.7  | PostgreSQL | `*/4 * * * *`   | critical | `:3000/api/health`    |
| `n8n`        | 2.20.6  | PostgreSQL | `*/4 * * * *`   | critical | `:5678/healthz`       |
| `nocodb`     | 0.262.7 | PostgreSQL | `*/4 * * * *`   | critical | `:8080/api/v1/health` |
| `openwebui`  | 0.9.5   | none       | `0 2 * * *`     | standard | `:8080/health`        |
| `twenty-crm` | 0.40.7  | PostgreSQL | `*/4 * * * *`   | critical | `:3000/health`        |
| `uptime-kuma`| 2.0.2   | SQLite     | `0 2 * * *`     | standard | `:3001/`              |

### Profile Schema (13 Fields)

Each `profile.yml` follows a fixed schema:

| Field             | Description                                        |
| ----------------- | -------------------------------------------------- |
| `name`            | Application identifier                             |
| `version`         | Pinned application version                         |
| `compose_file`    | Always `compose.yml.j2`                            |
| `vars_file`       | Always `vars.yml`                                  |
| `secrets_file`    | Always `secrets.yml`                               |
| `supported_arch`  | CPU architectures: `[amd64]` or `[amd64, arm64]`   |
| `depends_on`      | Inter-app dependencies (currently `[]` for all)    |
| `backup.schedule` | Cron expression for database dumps                 |
| `backup.db_type`  | `postgres`, `mysql`, `sqlite`, `custom`, or `none` |
| `monitoring`      | `health_endpoint`, `health_port`, `scrape_port`    |
| `compliance_tags` | NIST control reference array                       |
| `dr_tier`         | Disaster recovery tier (`critical`, `standard`)    |
| `provider`        | Cloud provider label (e.g. `oracle`, `aws`)        |

---

## Inventory Structure

```
apps/
│       ├── chatwoot/
│       ├── fastapi/
│       ├── metabase/
│       ├── n8n/
│       ├── nocodb/
│       ├── openwebui/
│       ├── twenty-crm/
│       └── uptime-kuma/
inventory/
├── hosts.ini                  # Main inventory - host definitions and groups
├── hosts.ini.example          # Template for new deployments
├── hosts.ini.test             # Stub inventory for CI validation
├── group_vars/
│   ├── all/                   # Global variables (images, main config, secrets)
│   │   ├── main.yml
│   │   ├── images.yml
│   │   ├── secrets.yml        # Ansible Vault encrypted
│   │   └── secrets.yml.example
│   ├── brain/                 # Control-plane node variables
│   │   ├── main.yml
│   │   ├── packages.yml
│   │   ├── firewall.yml
│   │   └── caddy.yml
│   ├── muscle/                # Workload node variables
│   │   ├── main.yml
│   │   ├── packages.yml
│   │   ├── firewall.yml
│   │   └── caddy.yml
│   ├── local/                 # Local device
```

### Variable Precedence (3-Tier)

Defined by ADR-03 and ADR-08:

| Position    | Source                              | Mechanism                  |
| ----------- | ----------------------------------- | -------------------------- |
| 1           | `group_vars/{brain,muscle,local}/`  | Auto-loaded by Ansible     |
| 2           | `group_vars/all/`                   | Auto-loaded by Ansible     |
| 3 (lowest)  | `roles/<role>/defaults/main.yml`    | Auto-loaded by Ansible     |

---



## Top-Level Files

### Build System (`Makefile`)

The Makefile is the primary operational interface. All targets run through the `uv` toolchain for deterministic Python dependency resolution.

#### Setup

| Target                | Description                                                |
| --------------------- | ---------------------------------------------------------- |
| `sync` / `install`    | Sync Python toolchain via `uv sync`                        |
| `install-collections` | Install Ansible Galaxy collections from `requirements.yml` |
| `bootstrap`           | Run `scripts/setup.sh --install`                           |
| `validate`            | Run `scripts/setup.sh --validate` (syntax checks)          |
| `lint`                | Run `yamllint` + `ansible-lint`                            |
| `precommit-install`   | Install pre-commit hooks                                   |
| `precommit-run`       | Run all pre-commit hooks                                   |

#### Vault

| Target          | Description                                                         |
| --------------- | ------------------------------------------------------------------- |
| `vault-init`    | Copy `secrets.yml.example` → `secrets.yml` if vault file is missing |
| `vault-encrypt` | Encrypt vault file                                                  |
| `vault-edit`    | Edit encrypted vault file                                           |
| `vault-view`    | View encrypted vault file                                           |

#### Deploy

| Target | Description | Playbook |
| ---------------------- | ----------------------------------------------- | -------------------------------------------------- |
| `deploy` | Full L1+L2 hardening | `playbooks/site.yml` |
| `deploy-l1` | L1 OS baseline only | `playbooks/l1/baseline.yml` |
| `deploy-bootstrap` | First-deploy bootstrap mode (auto-detects controller_ip) | `playbooks/site.yml -e nist_bootstrap=true` |
| `deploy-lockdown` | Post-bootstrap SSH lockdown | `playbooks/l2/lockdown.yml` |
| `deploy-compliance-nist80053` | Collect NIST 800-53 compliance evidence | `playbooks/l2/compliance.yml` |
| `deploy-tailscale-reconnect` | Tailscale mesh recovery | `playbooks/l2/tailscale-recover.yml` |
| `deploy-exporters` | Deploy node_exporter + cadvisor | `playbooks/l3/exporters.yml` |
| `deploy-monitoring-stack` | Deploy VictoriaMetrics + Loki + Grafana (brain) | `playbooks/l3/stack.yml` |
| `deploy-monitoring` | Full L3: exporters + monitoring stack | `deploy-exporters` + `deploy-monitoring-stack` |
| `deploy-edge` | Deploy edge proxy (requires EDGE=, HOST=) | `playbooks/l4/edge.yml` |
| `deploy-engine` | Deploy Docker Engine | `playbooks/l6/engine.yml` |
| `deploy-portainer` | Deploy Portainer | `playbooks/l6/portainer.yml` |
| `deploy-backup-stack` | Deploy Restic stack backup (brain only) | `playbooks/l6/backup-stack.yml` |
| `deploy-backup-appdata` | Deploy app data backup (DB dumps → R2) | `playbooks/l6/backup-appdata.yml` |
| `deploy-backup-timers` | Deploy systemd backup timers | `playbooks/l6/backup-timers.yml` |
| `deploy-backup-databases` | Deploy DB auto-discovery backups | `playbooks/l6/backup-databases.yml` |
| `deploy-backups` | All backup layers (stack→appdata→timers→databases) | umbrella target |
| `deploy-local` | Workstation hardening | `playbooks/ops/local-devices.yml` |
| `deploy-custom` | Custom playbook (`PLAYBOOK=<file>.yml`) | variable |
| `deploy-tags` | Tag-filtered deploy (`ANSIBLE_TAGS=`) | `PLAYBOOK` |
| `deploy-skip-tags` | Deploy with skipped tags (`ANSIBLE_SKIP_TAGS=`) | `PLAYBOOK` |
| `dry-run` | Check + diff mode | `PLAYBOOK` |
| `nuke` | Destructive teardown (requires CONFIRM=) | `playbooks/ops/nuke.yml` |
| `deploy-platform` | Complete platform (L2→L3→L6, sequential) | meta-target |
| `bootstrap-host` | Bootstrap fresh host as root | `playbooks/ops/bootstrap.yml` |
| `audit-full` | Full validation audit (all layers, read-only) | `playbooks/ops/validate.yml` |
| `validate-l1` | Audit L1 OS baseline (read-only) | `playbooks/ops/validate.yml --tags l1-os-baseline` |
| `validate-l2` | Audit L2 hardening and integrity (read-only) | `playbooks/l2/validate.yml` |
| `backup-now` | Trigger immediate backup on brain | `playbooks/l6/backup-stack.yml --tags backup --limit brain` |

> **Note**: `deploy-validate` and `deploy-all` were removed and are no longer available.

#### Verification

| Target                 | Description                               |
| ---------------------- | ----------------------------------------- |
| `verify-tailscale`     | `tailscale status` on all hosts           |
| `verify-crowdsec`      | CrowdSec alerts on all hosts              |
| `verify-auditd`        | Tail audit logs on all hosts              |
| `verify-observability` | Check exporters and VM targets            |
| `verify-timers`        | List backup timers on all hosts           |
| `show-inventory`       | Print configured inventory path           |

#### Key Variables

| Variable            | Default                                | Description                                    |
| ------------------- | -------------------------------------- | ---------------------------------------------- |
| `PLAYBOOK`          | `playbooks/site.yml`                   | Playbook file for deploy-custom, dry-run, tags |
| `ANSIBLE_INVENTORY` | `inventory/hosts.ini`                  | Inventory path                                 |
| `ANSIBLE_LIMIT`     | (empty)                                | Ansible `--limit` filter                       |
| `ANSIBLE_TAGS`      | (empty)                                | Ansible `--tags` filter                        |
| `ANSIBLE_SKIP_TAGS` | (empty)                                | Ansible `--skip-tags` filter                   |
| `ANSIBLE_OPTS`      | (empty)                                | Extra ansible-playbook options                 |
| `VAULT_FILE`        | `inventory/group_vars/all/secrets.yml` | Vault file path                                |
| `APT_FORCE`         | `false`                                | Force-kill hung apt processes                  |

### Ansible Configuration (`ansible.cfg`)

| Section                  | Key                   | Value                                                                    |
| ------------------------ | --------------------- | ------------------------------------------------------------------------ |
| `[defaults]`             | `inventory`           | `inventory/hosts.ini`                                                    |
|                          | `host_key_checking`   | `True`                                                                   |
|                          | `retry_files_enabled` | `False`                                                                  |
|                          | `gathering`           | `smart`                                                                  |
|                          | `forks`               | `10`                                                                     |
|                          | `timeout`             | `60`                                                                     |
|                          | `stdout_callback`     | `default`                                                                |
|                          | `roles_path`          | `roles`                                                                  |
|                          | `remote_tmp`          | `~/.ansible/tmp`                                                         |
| `[ssh_connection]`       | `pipelining`          | `True`                                                                   |
|                          | `ssh_args`            | `-o ControlMaster=auto -o ControlPersist=600s -o ServerAliveInterval=60 -o ServerAliveCountMax=3`                           |
|                          | `control_path`        | `/tmp/ansible-ssh-%%h-%%p-%%r`                                           |
| `[privilege_escalation]` | `become`              | `True`                                                                   |
|                          | `become_method`       | `sudo`                                                                   |
|                          | `become_user`         | `root`                                                                   |
|                          | `become_ask_pass`     | `False`                                                                  |
|                          | `timeout`             | `60`                                                                     |

### Dependency Manifest (`requirements.yml`)

| Collection          | Version |
| ------------------- | ------- |
| `community.general` | 13.0.1  |
| `ansible.posix`     | 2.2.0   |
| `community.docker`  | 5.2.1   |

### CI Workflows (`.github/workflows/`)

| Workflow             | Purpose                           |
| -------------------- | --------------------------------- |
| `ansible-lint.yml`   | Ansible role and playbook linting |
| `ci.yml`             | Full CI pipeline                  |
| `security-audit.yml` | Security scanning                 |

---

## Scripts

| Script                  | Purpose                                                                                      |
| ----------------------- | -------------------------------------------------------------------------------------------- |
| `setup.sh`              | Bootstrap, install, and validate toolchain - invoked by `make bootstrap` and `make validate` |
| `monitor-crowdsec.sh`   | Local CrowdSec alert monitoring - invoked by `make monitor-crowdsec`                         |
| `validate-hierarchy.sh` | Variable hierarchy validation                                                                |

---

## Related Documents

- [ARCHITECTURE.md](../architecture/ARCHITECTURE.md) - 7-layer security model and platform design
- [LAYER_BOUNDARIES.md](../architecture/LAYER_BOUNDARIES.md) - Layer boundary contracts
- [OPERATIONS_RUNBOOK.md](../operations/OPERATIONS_RUNBOOK.md) - Definitive operations runbook
- [PROJECT_WORKFLOW.md](PROJECT_WORKFLOW.md) - Project workflow onboarding
- [ARCHITECTURE.md](../architecture/ARCHITECTURE.md) - Documentation conventions and standards
- [README.md](../README.md) - Document relationship matrix
