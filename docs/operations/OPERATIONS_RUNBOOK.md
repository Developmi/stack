---
title: Operations Runbook
type: operations
owner: maintainers
audience: operator
version: v6.0.0
last-reviewed: 2026-07-16
status: active
project: developmi-stack
repo: github.com/Developmi/stack
---

# Operations Runbook

Definitive operational reference for the Developmi Stack. Covers commands, audits, deployment, restart, rotation, boot sequence, and troubleshooting.

This project uses Make as the single operational interface for setup, deployment, validation, and maintenance. Prefer these commands over direct `ansible-playbook` calls.

Operational rules:

- All Ansible-related execution runs through `uv run`.
- Node-based tooling policy: use `pnpm` only (no `npm`).
- Prettier execution must run through `pnpm` (for example, `pnpm dlx prettier@3.8.1`).
- `make lint` is strict and validates YAML plus all playbooks automatically (no `PLAYBOOK` argument needed).
- The suite does NOT deploy applications — it provides reference profiles under `apps/` for operator-managed deployment.

---

## §1 Command Reference

### 1.1 Help

```bash
make help
```

### 1.2 Initial Setup

```bash
# Sync local toolchain
make sync

# Install required Ansible collections
make install-collections

# Optional bootstrap workflow
make bootstrap

# Validate local setup and syntax gates
make validate
```

If `make lint` fails because the toolchain is incomplete, restore the environment with `uv sync` and re-run the command.

### 1.3 Secrets and Vault

```bash
# Create vault file from example if missing
make vault-init

# Encrypt vault file
make vault-encrypt

# Edit encrypted secrets
make vault-edit

# View encrypted secrets
make vault-view
```

Optional variable overrides:

```bash
make vault-edit VAULT_FILE=inventory/group_vars/all/secrets.yml
```

### 1.4 Core Deployments

```bash
# Base hardening (playbooks/site.yml)
make deploy

# Docker Engine (playbooks/l6/engine.yml)
make deploy-engine

# Portainer (playbooks/l6/portainer.yml)
make deploy-portainer

# Exporters + monitoring stack (playbooks/l3/exporters.yml + playbooks/l3/stack.yml)
make deploy-monitoring
```

Makefile handles prompting automatically in a scalable way:

- If inventory contains a host with `ansible_user` different from `root`, it automatically adds `--ask-become-pass`.
- If all hosts are `root`, it does not add become password prompt.
- Deployment targets include `--ask-vault-pass` by default so encrypted runtime secrets can be decrypted at execution time.

Examples:

```bash
make deploy
```

### 1.5 Advanced Deployment Controls

```bash
# Dry run any playbook
make dry-run PLAYBOOK=playbooks/site.yml

# Run a custom playbook
make deploy-custom PLAYBOOK=playbooks/l6/engine.yml

# Limit execution to one host or group
make deploy ANSIBLE_LIMIT=brain

# Run specific tags
make deploy-tags PLAYBOOK=playbooks/site.yml ANSIBLE_TAGS='nist,sc-7'

# Skip specific tags
make deploy-skip-tags PLAYBOOK=playbooks/site.yml ANSIBLE_SKIP_TAGS='tailscale,vpn'

# Compliance-only run
make deploy-compliance-nist80053
```

Optional override:

```bash
# Disable vault prompt only when encrypted vars are not required
make deploy VAULT_PROMPT_FLAG=
```

### 1.6 Verification and Monitoring

```bash
# Tailscale status on all hosts
make verify-tailscale

# CrowdSec alerts on all hosts
make verify-crowdsec

# Last audit logs on all hosts
make verify-auditd

# Exporters + scrape target checks
make verify-observability

# Local CrowdSec monitor helper script
make monitor-crowdsec
```

### 1.7 Quality Gates

```bash
# Lint checks when tools are installed (scans all playbooks automatically)
make lint

# Install and run pre-commit hooks
make precommit-install
make precommit-run
```

### 1.8 Application Deployment

### 1.9 Inventory and Safety Operations

```bash
# Print active inventory file content
make show-inventory

# Destructive cleanup (guarded by confirmation phrase)
make nuke CONFIRM=DESTROY_ALL_INFRASTRUCTURE
```

Optional variable overrides:

```bash
make deploy ANSIBLE_INVENTORY=inventory/hosts.ini.test
```

### 1.10 Production Runbook (Recommended Order)

```bash
make sync
make install-collections
make vault-init
make vault-edit
make deploy
make deploy-engine
make deploy-portainer
make deploy-backups
make deploy-monitoring
make verify-tailscale
make verify-crowdsec
make verify-observability
```

#### Behavior Notes

- `make lint` is strict and fails on YAML or playbook issues.
- If lint tooling is missing or broken, restore the project environment with `uv sync` and run the command again.
- All Ansible commands in this document are executed through `uv run` by the Makefile.
- Application secrets are managed through Ansible Vault - configure `inventory/group_vars/all/secrets.yml` and app-specific secrets files before deploying.

---

## §2 Production Command Audit

Operational security checklist for command execution in production environments.

This document is intended for real infrastructure audits where commands are executed sequentially and evidence is collected for validation, compliance, and rollback analysis.

The audit baseline is aligned with the Make-based operational interface and validates that command execution paths are deterministic, tested, and production-safe.

### 2.1 Scope

- Environment: production or production-like
- Interface: Make targets only
- Goal: validate operational command paths before release or post-release hardening
- Audit model: execution + evidence collection
- Exclusions by default:
  - Vault mutation commands
  - Destructive teardown commands

### 2.2 Security Rules Before Running

- Use a trusted control node with MFA-protected access.
- Confirm the active inventory before deployment operations.
- Run dry-run validation before any real apply.
- Preserve full command output for evidence collection and rollback analysis.
- Stop immediately on critical failures and investigate before continuing.

### 2.3 Execution Variables

Recommended operational variables:

```bash
ANSIBLE_OPTS='--ask-vault-pass'
ANSIBLE_INVENTORY=inventory/hosts.ini
ANSIBLE_LIMIT=<host_or_group>
```

Additional supported runtime controls:

```bash
APT_FORCE=true
```

When enabled, the Makefile injects:

```text
--extra-vars "apt_force_cleanup=true"
```

This force-cleans stale or locked APT states during automation runs.

### 2.4 Operational Interface Notes

The Make interface includes:

- Automatic privilege escalation detection
- Automatic become-password prompting when non-root inventory users are detected
- Unified `uv run` execution wrapper for all Ansible commands
- Ansible-driven application deployment with Vault-backed secrets
- Optional forced APT cleanup logic
- Explicit destructive-operation confirmation gates

### 2.5 Audit Checklist

Status legend:

- `[x]` passed
- `[ ]` not executed
- `[!]` failed and requires investigation
- `[-]` intentionally skipped

#### 2.5.1 Environment & Toolchain

- [x] `make help`
- [x] `make sync`
- [x] `make install`
- [x] `make install-collections`
- [x] `make bootstrap`
- [x] `make validate`
- [x] `make precommit-install`
- [x] `make precommit-run`
- [x] `make show-inventory`

#### 2.5.2 Lint & Validation

- [x] `make lint`

> **Note:** `make lint` automatically scans all playbooks under `playbooks/` - no `PLAYBOOK` argument is accepted or needed.

Validation includes:

- `yamllint`
- `ansible-lint`
- strict execution mode through `uv run`

#### 2.5.3 Dry-Run Validation (No Apply)

- [x] `make dry-run PLAYBOOK=playbooks/site.yml ANSIBLE_OPTS='--ask-vault-pass'`
- [x] `make dry-run PLAYBOOK=playbooks/l6/engine.yml ANSIBLE_OPTS='--ask-vault-pass'`
- [x] `make dry-run PLAYBOOK=playbooks/l3/exporters.yml ANSIBLE_OPTS='--ask-vault-pass'`

Dry-run mode executes:

```text
--check --diff
```

This validates:

- syntax
- task flow
- templating
- idempotency expectations
- inventory targeting

without mutating infrastructure.

#### 2.5.4 Core Deployment Paths

- [x] `make deploy ANSIBLE_OPTS='--ask-vault-pass'`
- [x] `make deploy-engine ANSIBLE_OPTS='--ask-vault-pass'`
- [x] `make deploy-portainer ANSIBLE_OPTS='--ask-vault-pass'`
- [x] `make deploy-monitoring ANSIBLE_OPTS='--ask-vault-pass'`
- [x] `make deploy-custom PLAYBOOK=<file>.yml ANSIBLE_OPTS='--ask-vault-pass'`

Validated playbooks:

| Playbook                   | Purpose                                  |
| -------------------------- | ---------------------------------------- |
| `playbooks/site.yml`           | Base hardening and core infrastructure         |
| `playbooks/l4/edge.yml`       | Edge proxy + WAF deployment                  |
| `playbooks/l6/engine.yml`     | Docker Engine + compose plugin                |
| `playbooks/l6/portainer.yml`  | Portainer BE (optional Manager)               |
| `playbooks/l3/exporters.yml`  | Node exporter + cadvisor (all hosts)          |
| `playbooks/l3/stack.yml`      | VictoriaMetrics + Grafana + Loki (brain only) |

#### 2.5.5 Tag-Controlled Execution

##### Core Infrastructure Tags

- [x] `make deploy-tags PLAYBOOK=playbooks/site.yml ANSIBLE_TAGS='base,system' ANSIBLE_OPTS='--ask-vault-pass'`
- [x] `make deploy-tags PLAYBOOK=playbooks/site.yml ANSIBLE_TAGS='security,firewall' ANSIBLE_OPTS='--ask-vault-pass'`
- [x] `make deploy-tags PLAYBOOK=playbooks/site.yml ANSIBLE_TAGS='crowdsec,ips' ANSIBLE_OPTS='--ask-vault-pass'`
- [x] `make deploy-tags PLAYBOOK=playbooks/site.yml ANSIBLE_TAGS='vpn,tailscale' ANSIBLE_OPTS='--ask-vault-pass'`
- [x] `make deploy-tags PLAYBOOK=playbooks/site.yml ANSIBLE_TAGS='docker,containers' ANSIBLE_OPTS='--ask-vault-pass'`

##### NIST Control Tags

- [x] `make deploy-tags PLAYBOOK=playbooks/site.yml ANSIBLE_TAGS='nist' ANSIBLE_OPTS='--ask-vault-pass'`
- [x] `make deploy-tags PLAYBOOK=playbooks/site.yml ANSIBLE_TAGS='nist,ac-2' ANSIBLE_OPTS='--ask-vault-pass'`
- [x] `make deploy-tags PLAYBOOK=playbooks/site.yml ANSIBLE_TAGS='nist,cm-7' ANSIBLE_OPTS='--ask-vault-pass'`
- [x] `make deploy-tags PLAYBOOK=playbooks/site.yml ANSIBLE_TAGS='nist,sc-7' ANSIBLE_OPTS='--ask-vault-pass'`
- [x] `make deploy-tags PLAYBOOK=playbooks/site.yml ANSIBLE_TAGS='nist,si-4,au-12' ANSIBLE_OPTS='--ask-vault-pass'`
- [x] `make deploy-tags PLAYBOOK=playbooks/site.yml ANSIBLE_TAGS='nist,sc-28' ANSIBLE_OPTS='--ask-vault-pass'`

##### Stack Deployment Tags

- [x] `make deploy-tags PLAYBOOK=playbooks/l4/edge.yml ANSIBLE_TAGS='l4-networking,caddy' ANSIBLE_OPTS='--ask-vault-pass'`
- [x] `make deploy-tags PLAYBOOK=playbooks/l6/portainer.yml ANSIBLE_TAGS='l6-runtime,portainer' ANSIBLE_OPTS='--ask-vault-pass'`

##### Monitoring & Observability Tags

- [x] `make deploy-tags PLAYBOOK=playbooks/l3/exporters.yml ANSIBLE_TAGS='l3-observability,exporters' ANSIBLE_OPTS='--ask-vault-pass'`
- [x] `make deploy-tags PLAYBOOK=playbooks/l3/exporters.yml ANSIBLE_TAGS='exporters' ANSIBLE_OPTS='--ask-vault-pass'`
- [x] `make deploy-tags PLAYBOOK=playbooks/l3/stack.yml ANSIBLE_TAGS='l3-observability,stack' ANSIBLE_OPTS='--ask-vault-pass'`
- [x] `make deploy-tags PLAYBOOK=playbooks/l3/exporters.yml ANSIBLE_TAGS='node_exporter' ANSIBLE_OPTS='--ask-vault-pass'`
- [x] `make deploy-tags PLAYBOOK=playbooks/l3/exporters.yml ANSIBLE_TAGS='cadvisor' ANSIBLE_OPTS='--ask-vault-pass'`
- [x] `make deploy-tags PLAYBOOK=playbooks/l3/stack.yml ANSIBLE_TAGS='victoriametrics' ANSIBLE_OPTS='--ask-vault-pass'`
- [x] `make deploy-tags PLAYBOOK=playbooks/l3/stack.yml ANSIBLE_TAGS='loki' ANSIBLE_OPTS='--ask-vault-pass'`
- [x] `make deploy-tags PLAYBOOK=playbooks/l3/stack.yml ANSIBLE_TAGS='grafana' ANSIBLE_OPTS='--ask-vault-pass'`

#### 2.5.6 Skip-Tag Validation

- [x] `make deploy-skip-tags PLAYBOOK=playbooks/site.yml ANSIBLE_SKIP_TAGS='tailscale,vpn' ANSIBLE_OPTS='--ask-vault-pass'`
- [x] `make deploy-skip-tags PLAYBOOK=playbooks/site.yml ANSIBLE_SKIP_TAGS='security,firewall,fail2ban' ANSIBLE_OPTS='--ask-vault-pass'`

Skip-tag execution confirms selective rollout behavior and safe exclusion paths.

#### 2.5.7 Compliance & Verification

##### Compliance Execution

- [x] `make deploy-compliance-nist80053 ANSIBLE_OPTS='--ask-vault-pass'`

Validated compliance mode:

```text
--tags compliance
```

##### Operational Verification Commands

- [x] `make verify-tailscale`
- [x] `make verify-crowdsec`
- [x] `make verify-auditd`
- [x] `make verify-observability`
- [x] `make monitor-crowdsec`

Verification coverage:

| Command                | Validation Scope                      |
| ---------------------- | ------------------------------------- |
| `verify-tailscale`     | Mesh VPN connectivity                 |
| `verify-crowdsec`      | IPS alert pipeline                    |
| `verify-auditd`        | Audit logging pipeline                |
| `verify-observability` | Exporters and VictoriaMetrics targets |
| `monitor-crowdsec`     | Local CrowdSec operational monitoring |

#### 2.5.8 Application Deployment

> **Note:** The suite does NOT deploy applications. Application deployment is the operator's responsibility using the reference profiles under `apps/`.

- [x] N/A — Application deployment is out of scope for this hardening suite. Reference profiles are provided under `apps/<name>/` for operator-managed stacks.

#### 2.5.9 Vault Operations (Validated but Excluded from Baseline)

The following commands are operationally validated but excluded from routine production audit baselines because they mutate secret material.

- [x] `make vault-init`
- [x] `make vault-encrypt`
- [x] `make vault-edit`
- [x] `make vault-view`

#### 2.5.10 Destructive Operations

The destructive cleanup workflow includes explicit confirmation gates.

Validated command:

- [x] `make nuke CONFIRM=DESTROY_ALL_INFRASTRUCTURE ANSIBLE_OPTS='--ask-vault-pass'`

Safety controls include:

- mandatory confirmation phrase
- explicit operator intent validation
- isolated `playbooks/ops/nuke.yml` execution path

Required confirmation value:

```text
DESTROY_ALL_INFRASTRUCTURE
```

### 2.6 Operational Safety Guarantees

The current Make interface provides:

- deterministic Ansible execution paths
- enforced inventory selection
- automatic privilege escalation handling
- safer Docker app orchestration
- explicit destructive-operation gating
- optional forced APT recovery controls
- centralized runtime wrapping through `uv run`

### 2.7 Release Gate Statement

If all required commands pass successfully and no critical findings remain unresolved, the operational interface is considered validated for production deployment and ongoing infrastructure maintenance.

---



## §4 Boot Sequence

Full system boot order from control node to runtime services. Follow layers sequentially. Each layer builds on the previous.

### 4.1 Boot Order Table

| Layer | Name                 | Playbook                                                                                       | Dependency | Hosts                |
| ----- | -------------------- | ---------------------------------------------------------------------------------------------- | ---------- | -------------------- |
| L0    | Control Node Setup   | N/A (manual)                                                                                   | None       | Control node         |
| L1    | OS Baseline          | `playbooks/site.yml` (roles: L1_os_baseline)                                                   | L0         | all                  |
| L2    | Networking Foundation | `playbooks/site.yml` (role: L2_compliance) + `playbooks/l3/exporters.yml` (node_exporter) | L1         | all                  |
| L3    | Compliance Hardening  | `playbooks/site.yml` (roles: L2_compliance)                                                    | L2         | all                  |
| L4    | Networking & Edge     | `playbooks/l4/edge.yml` (role: L4_networking)                                                | L3         | muscle               |
| L5    | App Profiles         | `playbooks/l6/backup-appdata.yml` + `playbooks/l6/backup-timers.yml` (var: `backup_role_source: app`) | L4         | brain                |
| L6    | Runtime              | `playbooks/l6/engine.yml` + `playbooks/l6/portainer.yml` + `playbooks/l6/backup-stack.yml` (roles: L6_runtime) | L4         | all + brain + muscle |

### 4.2 L0 - Control Node Setup (Reference Only)

L0 covers the operator's workstation. This is outside the repository scope but required before any playbook execution.

**Prerequisites:**

- Python 3.14+ with `uv` installed
- SSH access to all target hosts
- Ansible inventory file (`inventory/hosts.ini`) configured
- Vault password available at `/tmp/.vault_pass`

**Start commands:**

```bash
# Install Python toolchain
uv sync

# Install Ansible collections
make install-collections

# Validate environment
make validate
```

**Verification:**

```bash
# Confirm toolchain
uv run ansible --version

# Confirm inventory reachable
make show-inventory

# Test SSH connectivity
uv run ansible all -i inventory/hosts.ini -m ping
```

### 4.3 L1 - OS Baseline

Establishes the operating system foundation: common configuration, package management, and system tuning.

**Prerequisites:** L0 complete, control node operational.

**Start command:**

```bash
make deploy-tags PLAYBOOK=playbooks/site.yml ANSIBLE_TAGS='l1-os-baseline'
```

**Verification:**

```bash
# Verify common role applied
uv run ansible all -i inventory/hosts.ini -m shell -a "hostnamectl status"

# Verify packages installed
uv run ansible all -i inventory/hosts.ini -m shell -a "dpkg -l | grep -E 'curl|gnupg|ca-certificates'"
```

### 4.4 L2 - Networking Foundation

Establishes the Tailscale mesh VPN and core monitoring exporter (node_exporter). Provides the network fabric that all subsequent layers use for secure communication.

**Prerequisites:** L1 complete, control node operational.

**Start command:**

```bash
make deploy-tags PLAYBOOK=playbooks/site.yml ANSIBLE_TAGS='l2-networking'
```

**Verification:**

```bash
# Verify Tailscale mesh
make verify-tailscale
```

### 4.5 L3 - Compliance Hardening

Applies NIST SP 800-53 security controls: firewall, CrowdSec IPS, user hardening, and compliance evidence collection. Runs AFTER networking is established so that CrowdSec can register with the central API and audit logs can flow over the mesh.

**Prerequisites:** L2 complete, Tailscale mesh active.

**Start command:**

```bash
make deploy-tags PLAYBOOK=playbooks/site.yml ANSIBLE_TAGS='l3-compliance'
```

**Verification:**

```bash
# Verify CrowdSec operational
make verify-crowdsec

# Verify audit logging
make verify-auditd
```

> **Note:** The full observability stack (VictoriaMetrics, Grafana, Loki) is deployed as an optional add-on via `make deploy-monitoring` after the boot sequence. See §5.1 Initial Provisioning for the optional step.

### 4.6 L4 - Networking & Edge

Deploys Caddy reverse proxy with Coraza WAF on muscle nodes. Provides TLS termination and ingress routing for all services.

**Prerequisites:** L3 complete, Docker Engine installed.

**Start command:**

```bash
make deploy-tags PLAYBOOK=playbooks/l4/edge.yml ANSIBLE_TAGS='l4-networking,caddy,ingress'
```

**Verification:**

```bash
# Check Caddy container running
uv run ansible muscle -i inventory/hosts.ini -m shell -a "docker ps --filter name=caddy --format '{{.Status}}'"

# Verify TLS endpoint
curl -fsS https://<public-domain>/health 2>&1 | head -5
```

### 4.7 L5 - App Profiles

Backup and application reference layer. Runs database dumps and Restic backups for app data. The suite does NOT deploy applications — it provides reference profiles under `apps/` for operator-managed deployment.

**Prerequisites:** L4 complete, `enable_backups: true` (default).

**Start commands:**

```bash
# Deploy backup automation (brain host)
make deploy-backups
make deploy-backup-timers
```

**Verification:**

```bash
# Verify backup timers
make verify-timers

# Verify recent backup
uv run ansible brain -i inventory/hosts.ini -m shell -a "restic -r r2:<bucket> snapshots --latest 1"
```

### 4.8 L6 - Runtime

Deploys Docker Engine, Portainer management UI, and runtime backup (stack_backup via Restic).

**Prerequisites:** L4 complete.

**Start command:**

```bash
# Deploy Docker Engine (playbooks/l6/engine.yml)
make deploy-engine

# Deploy Portainer (playbooks/l6/portainer.yml)
make deploy-portainer
```

**Verification:**

```bash
# Verify Docker Engine
uv run ansible all -i inventory/hosts.ini -m shell -a "docker version --format '{{.Server.Version}}'"

# Verify Portainer (if enabled)
uv run ansible muscle -i inventory/hosts.ini -m shell -a "docker ps --filter name=portainer --format '{{.Status}}'"

# Verify runtime backup
uv run ansible brain -i inventory/hosts.ini -m shell -a "restic -r r2:<bucket> snapshots --path /stack-restic --latest 1"
```

### 4.9 Boot Sequence Architecture Rationale

- **L2 (Networking Foundation) before L3 (Compliance):** The Tailscale mesh must be established before CrowdSec can register with the central API, before audit logs ship over the mesh, and before user_hardening can verify SSH key distribution across nodes. Packages must be installed before compliance scans can validate versions.
- **L3 (Compliance) before L4 (Ingress):** The firewall, fail2ban, and CrowdSec bouncers must be active before Caddy and the WAF are exposed, ensuring a defense-in-depth perimeter.
- **L4 (Ingress) before L5 (Apps):** Caddy must provide TLS termination before application traffic can flow.
- **L4 (Ingress) before L6 (Runtime):** Docker Engine (deployed as part of L6) must be available for L4 containers. In practice, `make deploy-engine` followed by `make deploy-portainer` handles L6, while `make deploy-platform` deploys all of L2+L3+L6 together.

---

## §4a Bootstrap Flow (Tailscale + SSH Lockdown)

### 4a.1 Variable: `nist_bootstrap`

Controls whether public SSH is temporarily allowed during first deployment. Defined in `inventory/group_vars/all/main.yml` with a default of `false` (locked down).

- `nist_bootstrap: true` → firewall allows SSH from the Ansible controller IP on all interfaces (bootstrap mode)
- `nist_bootstrap: false` → SSH is DROPped on all non-`tailscale0` interfaces (steady-state)

**Never set to `true` in a vars file.** Always pass via `--extra-vars`:

```bash
make deploy -e nist_bootstrap=true
```

### 4a.2 First Deploy

```bash
# 1. Initial deployment with bootstrap mode (allows SSH from controller IP):
make deploy -e nist_bootstrap=true

# 2. After deploy, get the Tailscale IP from the lockdown output:
uv run ansible all -i inventory/hosts.ini -m shell -a "tailscale ip -4"

# 3. Update ansible_host in inventory/hosts.ini to the Tailscale IP:
#    ansible_host: 100.x.y.z
```

The `lockdown.yml` playbook runs automatically at the end of `site.yml`:
- Verifies Tailscale is connected on every node
- Transitions `nist_bootstrap` from `true` to `false`
- Applies public SSH DROP on all non-Tailscale interfaces
- Creates `/etc/tailscale-recover.lock` marker file
- Prints Tailscale IPs for inventory update

### 4a.3 Steady-State Deploys

```bash
# Subsequent deploys (via Tailscale IP):
make deploy
```

Lockdown pre-flight checks that Tailscale is connected and the marker exists on every deploy.

### 4a.4 Lockdown Without Full `site.yml`

When deploying individual playbooks (which does not run `site.yml`), run lockdown manually:

```bash
uv run ansible-playbook -i inventory/hosts.ini playbooks/l2/lockdown.yml --ask-vault-pass
```

### 4a.5 Recovery - Tailscale Down

If Tailscale is unreachable and SSH is locked down:

**Option A - Re-bootstrap via cloud console:**
```bash
# Connect via cloud provider serial/SPICE console, then:
make deploy -e nist_bootstrap=true
```

**Option B - Recovery playbook via cloud console:**
```bash
# After connecting via cloud console:
uv run ansible-playbook -i inventory/hosts.ini playbooks/l2/tailscale-recover.yml \
  -e "public_ip=<node_public_ip>" --ask-vault-pass
```
`tailscale-recover.yml` connects via public IP. Requires cloud console as backup - do not run without console access.

After Tailscale is back online, re-apply lockdown:
```bash
uv run ansible-playbook -i inventory/hosts.ini playbooks/l2/lockdown.yml --ask-vault-pass
```

---

## §5 Deploy Procedures

### 5.1 Initial Provisioning

Complete greenfield deployment sequence. Run from L0 through L6.

```bash
# 1. Control node setup
uv sync
make install-collections
make validate

# 2. Vault setup
make vault-init
make vault-edit   # populate secrets

# 3. L1 - OS Baseline
make deploy-tags PLAYBOOK=playbooks/site.yml ANSIBLE_TAGS='l1-os-baseline'

# 4. L2 - Networking Foundation (Tailscale)
make deploy-tags PLAYBOOK=playbooks/site.yml ANSIBLE_TAGS='l2-networking'

# 5. Verify Tailscale mesh
make verify-tailscale

# 6. L3 - Compliance Hardening
make deploy-tags PLAYBOOK=playbooks/site.yml ANSIBLE_TAGS='l3-compliance'

# 7. L4 + L6 - Runtime + Edge (Docker Engine, Portainer, Caddy+WAF)
make deploy-engine
make deploy-portainer

# 8. L5 - App Profiles (backup)
make deploy-backups
make deploy-backup-timers
# Application deployment is operator-managed via reference profiles at apps/
# or deploy all of L2+L3+L6 together:
# make deploy-platform
# make deploy-platform

> **Note:** `make deploy-engine` deploys `playbooks/l6/engine.yml`, `make deploy-portainer` deploys `playbooks/l6/portainer.yml`. To deploy all of L2+L3+L6 at once, use `make deploy-platform`. The full observability stack (VictoriaMetrics, Grafana, Loki) is optional and can be deployed at any point after L2 via `make deploy-monitoring`.
```

### 5.2 Per-Playbook Deploy

Run individual playbooks for targeted operations.

| Playbook            | Command                                          | Use Case                                       |
| ------------------- | ------------------------------------------------ | ---------------------------------------------- |
| `site.yml`          | `make deploy`                                    | OS hardening + compliance                      |
| `l6/engine.yml`     | `make deploy-engine`                             | Docker Engine + compose plugin                 |
| `l4/edge.yml`       | `make deploy-custom PLAYBOOK=playbooks/l4/edge.yml` | Caddy + WAF deployment                      |
| `l6/portainer.yml`  | `make deploy-portainer`                          | Portainer BE (optional Manager)                |
| `l6/backup-stack.yml` | `make deploy-backup-stack`                     | Runtime backup (Restic → R2)                   |
| `l3/exporters.yml`  | `make deploy-monitoring`                         | Node exporter + cadvisor (all hosts)           |
| `l3/stack.yml`      | `make deploy-monitoring`                         | VictoriaMetrics + Grafana + Loki (brain only)  |
| `l6/backup-appdata.yml` | `make deploy-backups`                         | App data backup (database dumps → Restic → R2) |
| `l6/backup-timers.yml` | `make deploy-backup-timers`                      | Systemd backup timer scheduling                |
| `local-devices.yml` | `make deploy-local`                              | Workstation hardening                          |
| `l2/compliance.yml` | `make deploy-compliance-nist80053`               | Compliance audit tags only                     |

### 5.3 Selective Deploy (Tags / Limits)

Narrow deployment scope for surgical changes or testing.

**By tag:**

```bash
# Run only NIST AC-2 controls
make deploy-tags PLAYBOOK=playbooks/site.yml ANSIBLE_TAGS='nist,ac-2'

# Run only CrowdSec IPS
make deploy-tags PLAYBOOK=playbooks/site.yml ANSIBLE_TAGS='crowdsec,ips'

# Run only Docker Engine
make deploy-tags PLAYBOOK=playbooks/l6/engine.yml ANSIBLE_TAGS='docker'
```

**By host limit:**

```bash
# Deploy to single host
make deploy ANSIBLE_LIMIT=brain

# Deploy to a group
make deploy ANSIBLE_LIMIT=muscle
```

**Excluding tags:**

```bash
# Skip VPN and Tailscale
make deploy-skip-tags PLAYBOOK=playbooks/site.yml ANSIBLE_SKIP_TAGS='tailscale,vpn'
```

### 5.4 Dry-Run (Check Mode)

Validate without mutating. Always dry-run before production deploy.

```bash
# Dry-run site.yml
make dry-run PLAYBOOK=playbooks/site.yml

# Dry-run with vault pass
make dry-run PLAYBOOK=playbooks/site.yml ANSIBLE_OPTS='--ask-vault-pass'

# Dry-run a single host
make dry-run PLAYBOOK=playbooks/site.yml ANSIBLE_LIMIT=brain
```

**What dry-run validates:**

- YAML and Jinja2 syntax
- Task flow and ordering
- Template rendering
- Inventory targeting
- Idempotency (changed tasks = potential drift)

### 5.5 Compliance-Only Run

Run only compliance audit tags without applying changes.

```bash
make deploy-compliance-nist80053
```

This executes `playbooks/l2/compliance.yml` with NIST 800-53 compliance tags, collecting evidence without mutating system state.

### 5.6 Decision Guidance

| Scenario             | Recommended Approach                                                   |
| -------------------- | ---------------------------------------------------------------------- |
| First deployment     | Full L0→L6 sequence (§5.1)                                             |
| OS update applied    | Dry-run → `make deploy`                                                |
| Security patch only  | `make deploy-tags PLAYBOOK=playbooks/site.yml ANSIBLE_TAGS='security'`                                             |
| Configuration change | Dry-run affected playbook → deploy                                                                                  |
| Pre-audit validation | `make deploy-compliance-nist80053`                                                                                  |
| Destructive teardown | `make nuke CONFIRM=DESTROY_ALL_INFRASTRUCTURE`                         |

### 5.7 Variable Overrides

| Variable            | Default                                | Purpose                           |
| ------------------- | -------------------------------------- | --------------------------------- |
| `ANSIBLE_INVENTORY` | `inventory/hosts.ini`                  | Inventory file path               |
| `ANSIBLE_LIMIT`     | (all hosts)                            | Limit to host or group            |
| `ANSIBLE_TAGS`      | (all tags)                             | Filter by tags                    |
| `ANSIBLE_SKIP_TAGS` | (none)                                 | Exclude tags                      |
| `ANSIBLE_OPTS`      | (empty)                                | Pass extra ansible-playbook flags |
| `VAULT_PROMPT_FLAG` | `--ask-vault-pass`                     | Vault password prompting          |
| `APT_FORCE`         | `false`                                | Force-clean locked APT states     |
| `VAULT_FILE`        | `inventory/group_vars/all/secrets.yml` | Vault file path                   |
| `PLAYBOOK`          | `playbooks/site.yml`                   | Target playbook for dry-run, lint |

---

## §6 Restart Procedures

### 6.1 Per-Component Restart

| Component           | Restart Command                                                                                         | Notes                                    |
| ------------------- | ------------------------------------------------------------------------------------------------------- | ---------------------------------------- |
| Docker Engine       | `uv run ansible all -i inventory/hosts.ini -m shell -a "systemctl restart docker" --become`             | Check containers restart cleanly         |
| Caddy (WAF)         | `uv run ansible muscle -i inventory/hosts.ini -m shell -a "docker restart caddy"`                       | Verify TLS endpoint after restart        |
| Portainer           | `uv run ansible muscle -i inventory/hosts.ini -m shell -a "docker restart portainer"`                   | UI available within 10s                  |
| CrowdSec            | `uv run ansible all -i inventory/hosts.ini -m shell -a "systemctl restart crowdsec" --become`           | Verify with `make verify-crowdsec`       |
| Tailscale           | `uv run ansible all -i inventory/hosts.ini -m shell -a "systemctl restart tailscaled" --become`         | Verify mesh with `make verify-tailscale` |
| Node Exporter       | `uv run ansible all -i inventory/hosts.ini -m shell -a "docker restart node-exporter"`                  | Confirm metrics flowing in Grafana       |
| Observability Stack | `uv run ansible brain -i inventory/hosts.ini -m shell -a "docker restart victoriametrics grafana loki"` | Sequential restart; Grafana last         |
| Application Stacks  | Operator-managed via reference profiles under `apps/`                     | Deploy/redeploy L5 containers as needed |

### 6.2 Full Host Restart Sequence

When a host requires a full reboot:

```bash
# 1. Pre-restart: verify state
make verify-tailscale
make verify-crowdsec

# 2. Reboot host
uv run ansible <host> -i inventory/hosts.ini -m reboot --become

# 3. Wait for host back online
uv run ansible <host> -i inventory/hosts.ini -m ping

# 4. Post-restart: re-apply core hardening (idempotent)
make deploy ANSIBLE_LIMIT=<host>

# 5. Verify services
make verify-tailscale
make verify-crowdsec
make verify-observability
```

### 6.3 Post-Restart Verification

After any component or host restart:

1. **Tailscale mesh**: `make verify-tailscale` - all hosts show `active`
2. **CrowdSec IPS**: `make verify-crowdsec` - alert pipeline operational
3. **Observability**: `make verify-observability` - exporters and targets healthy
4. **Docker Engine**: `docker info` on all hosts
5. **Caddy**: `curl -fsS https://<domain>/health`
6. **Application stacks**: Verify containers are running and healthy

---

## §7 Rotation Procedures

### 7.1 Vault Password Rotation

```bash
# 1. Rekey the vault file with a new password
uv run ansible-vault rekey inventory/group_vars/all/secrets.yml

# 2. Update the vault password file
echo "<new-password>" > /tmp/.vault_pass

# 3. Verify access
make vault-view

# 4. Test deployment (dry-run)
make dry-run PLAYBOOK=playbooks/site.yml
```

### 7.2 Secret Rotation

After updating secrets in the vault:

```bash
# 1. Edit vault
make vault-edit

# 2. Re-encrypt
make vault-encrypt

# 3. Deploy to propagate new secrets
make deploy
make deploy-engine
make deploy-portainer

# 4. Re-deploy applications to propagate new secrets
# Application config is operator-managed via apps/<name>/ profiles
```

### 7.3 Cloudflare Certificate Rotation

Certificates managed via Cloudflare API. Rotation is handled by the Caddy module when certificates approach expiry. For manual rotation:

```bash
# Force Caddy to renew all certificates
uv run ansible muscle -i inventory/hosts.ini -m shell -a \
  "docker exec caddy caddy reload"

# Verify certificate expiry dates
echo | openssl s_client -servername <domain> -connect <domain>:443 2>/dev/null \
  | openssl x509 -noout -dates
```

### 7.4 Tailscale Key Rotation

Tailscale auth keys are stored in Ansible vault. To rotate:

```bash
# 1. Generate new auth key in Tailscale admin console
#    https://login.tailscale.com/admin/settings/keys

# 2. Update the key in vault
make vault-edit
#    Update tailscale_auth_key value

# 3. Re-encrypt
make vault-encrypt

# 4. Re-deploy Tailscale to all hosts
make deploy-tags PLAYBOOK=playbooks/site.yml ANSIBLE_TAGS='tailscale'

# 5. Verify mesh health
make verify-tailscale
```

> **Note:** Tailscale key rotation does not disrupt existing mesh connections. Nodes already authenticated remain connected. New keys apply only on re-auth.

### 7.5 Docker Credential Rotation

Docker registry credentials (Docker Hub, private registries) are stored in vault.

```bash
# 1. Update credentials in vault
make vault-edit

# 2. Re-encrypt
make vault-encrypt

# 3. Re-deploy Docker configuration
make deploy-tags PLAYBOOK=playbooks/l6/engine.yml ANSIBLE_TAGS='docker'

# 4. Verify Docker can pull images
uv run ansible all -i inventory/hosts.ini -m shell -a "docker pull alpine:latest"
```

---

## §8 Troubleshooting

### 8.1 Common Failure Modes

| Symptom                            | Likely Cause                            | Diagnostic Command                                                                             | Resolution                                                                                      |
| ---------------------------------- | --------------------------------------- | ---------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------- |
| `make deploy` fails with SSH error | SSH key not loaded or host unreachable  | `uv run ansible all -i inventory/hosts.ini -m ping`                                            | Verify SSH agent, check Tailscale connectivity                                                  |
| `make lint` fails                  | YAML syntax or ansible-lint violation   | `make lint PLAYBOOK=playbooks/site.yml` (see error output)                                     | Fix YAML indentation or lint violations; run `uv sync` if toolchain missing                     |
| `apt` lock held during deploy      | Stale dpkg/apt process                  | `uv run ansible all -i inventory/hosts.ini -m shell -a "lsof /var/lib/dpkg/lock-frontend"`     | Retry with `APT_FORCE=true` or manually kill stale process                                      |
| Vault decryption fails             | Wrong vault password or corrupted vault | `make vault-view`                                                                              | Verify `/tmp/.vault_pass` matches; restore from backup if corrupted                             |
| `changed` tasks on second deploy   | Idempotency issue in a role             | `make dry-run PLAYBOOK=playbooks/site.yml` (note changed tasks)                                | Investigate the role's idempotency; check for non-deterministic tasks                           |
| CrowdSec bouncers not blocking     | Bouncer config out of sync              | `make verify-crowdsec`                                                                         | Re-deploy CrowdSec role: `make deploy-tags PLAYBOOK=playbooks/site.yml ANSIBLE_TAGS='crowdsec'` |
| Tailscale node offline             | tailscaled not running or auth expired  | `make verify-tailscale`                                                                        | SSH via alternative path, `systemctl restart tailscaled`, or re-deploy Tailscale role           |
| Docker container exits immediately | Image pull failure or config error      | `docker logs <container>`                                                                      | Check `.env` values, verify image tag exists, check compose syntax                              |
| Observability stack not scraping   | Exporter down or VM config mismatch     | `make verify-observability`                                                                    | Check Docker container status, verify scrape targets in VictoriaMetrics                         |
| Portainer inaccessible             | Portainer disabled or container stopped | `uv run ansible muscle -i inventory/hosts.ini -m shell -a "docker ps --filter name=portainer"` | Ensure `enable_portainer: true` in group_vars; redeploy stacks                                  |
| App deployment failure             | Playbook error or missing vault secret  | Check `make lint` output, verify vault secrets                                                                    | Re-deploy via the operator's own toolchain using reference profiles at `apps/<name>/` |

### 8.2 Diagnostic Commands Per Layer

| Layer | Diagnostic       | Command                                                                                                                            |
| ----- | ---------------- | ---------------------------------------------------------------------------------------------------------------------------------- | ------------------------ |
| L0    | Toolchain health | `uv run ansible --version && make validate`                                                                                        |
| L1    | OS state         | `uv run ansible all -i inventory/hosts.ini -m setup`                                                                               |
| L2    | Firewall rules   | `uv run ansible all -i inventory/hosts.ini -m shell -a "ufw status verbose" --become`                                              |
| L2    | SSH config       | `uv run ansible all -i inventory/hosts.ini -m shell -a "sshd -T \| grep -E 'PermitRoot                                             | PasswordAuth'" --become` |
| L2    | CrowdSec metrics | `make verify-crowdsec`                                                                                                             |
| L3    | Metrics flow     | `make verify-observability`                                                                                                        |
| L4    | Caddy status     | `uv run ansible muscle -i inventory/hosts.ini -m shell -a "docker logs caddy --tail 20"`                                           |
| L5    | Backup status    | `make verify-timers`                                                                                                               |
| L6    | Docker health    | `uv run ansible all -i inventory/hosts.ini -m shell -a "docker info --format '{{.ServerVersion}} running={{.ContainersRunning}}'"` |

### 8.3 Escalation Paths

1. **Deployment failure with no obvious cause** → See [INCIDENT_RESPONSE_DR.md](../operations/INCIDENT_RESPONSE_DR.md) for disaster recovery procedures.
2. **Vault corruption or lost password** → See [INCIDENT_RESPONSE_DR.md](../operations/INCIDENT_RESPONSE_DR.md) for secret recovery workflows.
3. **Host unreachable via SSH** → See [EMERGENCY_ACCESS.md](EMERGENCY_ACCESS.md) for console/rescue access procedures.
4. **Playbook logic error** → Inspect the failing role in `roles/<name>/tasks/main.yml`. Check `ansible-lint` output for the playbook.
5. **Infrastructure-wide outage** → Follow the boot sequence in §4 from L0 upwards.

---

## Related Documents

- [INCIDENT_RESPONSE_DR.md](../operations/INCIDENT_RESPONSE_DR.md) - Incident response and disaster recovery procedures
- [COMPATIBILITY.md](COMPATIBILITY_MATRIX.md) - Tested OS and architecture support matrix
- [VERSION_PINS.md](../operations/VERSION_PINS.md) - Version pinning strategy
- [ONBOARDING.md](../project/ONBOARDING.md) - Operator onboarding guide
- [EMERGENCY_ACCESS.md](EMERGENCY_ACCESS.md) - Console/rescue recovery procedures
- [GLOSSARY.md](../GLOSSARY.md) - Terminology definitions

---

Miguel Lozano, 2026
