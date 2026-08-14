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
- The suite does NOT deploy applications - it provides reference profiles under `apps/` for operator-managed deployment.

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
make setup-toolchain

# Validate local setup and syntax gates
make check-toolchain
```

If `make lint` fails because the toolchain is incomplete, restore the environment with `uv sync` and re-run the command.

### 1.3 Secrets and Vault

Runtime secrets are encrypted with **SOPS + age** and loaded transparently by the `community.sops` vars plugin (`secrets.sops.yml` + `managers/portainer.sops.yml`). The Ansible Vault keeps only the Tailscale auth/ACL keys ("trio") until expiry.

```bash
# SOPS workflow (primary)
# 1. Generate the age keypair and back it up OFFLINE (required before first encryption)
age-keygen -o age/keys.txt
# 2. Replace the age1<PLACEHOLDER> recipient in .sops.yaml with your public key
# 3. Create the SOPS file from the example (fresh checkouts only)
make sops-init
# 4. Encrypt in place
make sops-encrypt
# 5. Edit / view encrypted secrets
make sops-edit
make sops-view
# Extra recipients (new team member): sops updatekeys secrets.sops.yml

# Vault workflow (Tailscale trio only, until key expiry)
# Encrypt a new/plaintext vault file
uv run ansible-vault encrypt inventory/group_vars/all/secrets.yml
# Edit the encrypted vault file (prompts for password; re-encrypts on save)
uv run ansible-vault edit inventory/group_vars/all/secrets.yml
# View the encrypted vault file
uv run ansible-vault view inventory/group_vars/all/secrets.yml
```

Optional variable overrides:

```bash
make sops-edit SOPS_FILE=inventory/group_vars/all/managers/portainer.sops.yml
# vault-* make targets are RETIRED (SOPS migration); the vault file path is fixed:
uv run ansible-vault edit inventory/group_vars/all/secrets.yml
```

**Retired secrets (dead keys removed, decouple-manager-sops D3):** `portainer_url`, `portainer_username`, `portainer_password`, `portainer_server_url` and the vault copy of `observability_network_name` had zero consumers and were dropped - they exist in neither `secrets.sops.yml` nor the vault. `portainer_*` keys are confined to `inventory/group_vars/all/managers/`.

### 1.4 Core Deployments

```bash
# Base hardening (playbooks/site.yml)
make deploy-hardening

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
- Deploy targets do NOT pass `--ask-vault-pass` by default: runtime secrets decrypt transparently via SOPS+age. Only the six Tailscale trio consumers pin the flag until the trio expires (D4): `deploy-hardening`, `deploy-compliance`, `reconnect-tailscale`, `deploy-local`, `nuke`, `provision-host`.

Examples:

```bash
make deploy-hardening
```

### 1.5 Advanced Deployment Controls

```bash
# Dry run any playbook
make run CHECK=1 PLAYBOOK=playbooks/site.yml

# Run a custom playbook
make run PLAYBOOK=playbooks/l6/engine.yml

# Limit execution to one host or group
make deploy-hardening ANSIBLE_LIMIT=brain

# Run specific tags
make run PLAYBOOK=playbooks/site.yml TAGS='nist,sc-7'

# Skip specific tags
make run PLAYBOOK=playbooks/site.yml SKIP_TAGS='tailscale,vpn'

# Compliance-only run
make deploy-compliance
```

Optional override:

```bash
# Pass vault prompting when a non-tailscale target still needs the vault trio
# (e.g. dry-run): the tailscale trio consumers pin --ask-vault-pass until expiry.
make run CHECK=1 PLAYBOOK=playbooks/l6/engine.yml ANSIBLE_OPTS='--ask-vault-pass'
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

Apps deploy as Docker Compose stacks from structured profiles under `apps/` via the L6 runtime (Compose-only path, ADR-07). With the optional manager enabled (`enable_portainer: true`), the same stacks can be managed through Portainer's UI (Edge agent).

**Shared network condition (D9):** any Compose app that must be reachable through Caddy MUST join BOTH networks:
- `expose_network` - the intentional app-exposure bridge (`external: true`, static compose files)
- the shared network - `{{ shared_network_name }}` (`public_net`, single source of truth in `inventory/group_vars/all/main.yml`)

The static compose files under `apps/` currently join only `expose_network`; wiring them onto the shared network is tracked as a follow-up (decouple-manager-sops D9). Ansible-rendered compose (roles/templates) already joins `{{ shared_network_name }}`.

### 1.9 Inventory and Safety Operations

```bash
# Print active inventory file content
make show-inventory

# Destructive cleanup (guarded by confirmation phrase)
make nuke CONFIRM=DESTROY_ALL_INFRASTRUCTURE
```

Optional variable overrides:

```bash
make deploy-hardening ANSIBLE_INVENTORY=inventory/hosts.ini.test
```

### 1.10 Production Runbook (Recommended Order)

```bash
make sync
make install-collections
make sops-init        # fresh checkout only: create secrets.sops.yml from the example
make sops-edit        # fill in real values (re-encrypts on save; or: make sops-encrypt)
make deploy-hardening
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
- Runtime secrets are managed through SOPS + age - configure `inventory/group_vars/all/secrets.sops.yml` (template: `secrets.yml.example`) and `inventory/group_vars/all/managers/portainer.sops.yml` before deploying; the Ansible Vault keeps only the Tailscale trio until expiry.

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
# ANSIBLE_OPTS='--ask-vault-pass' is only needed for the Tailscale trio consumers (see §7.4)
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
- Ansible-driven application deployment with SOPS-backed secrets
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
- [x] `make sync`
- [x] `make install-collections`
- [x] `make setup-toolchain`
- [x] `make check-toolchain`
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

- [x] `make run CHECK=1 PLAYBOOK=playbooks/site.yml ANSIBLE_OPTS='--ask-vault-pass'`
- [x] `make run CHECK=1 PLAYBOOK=playbooks/l6/engine.yml ANSIBLE_OPTS='--ask-vault-pass'`
- [x] `make run CHECK=1 PLAYBOOK=playbooks/l3/exporters.yml ANSIBLE_OPTS='--ask-vault-pass'`

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

- [x] `make deploy-hardening ANSIBLE_OPTS='--ask-vault-pass'`
- [x] `make deploy-engine ANSIBLE_OPTS='--ask-vault-pass'`
- [x] `make deploy-portainer ANSIBLE_OPTS='--ask-vault-pass'`
- [x] `make deploy-monitoring ANSIBLE_OPTS='--ask-vault-pass'`
- [x] `make run PLAYBOOK=<file>.yml ANSIBLE_OPTS='--ask-vault-pass'`

Validated playbooks:

| Playbook                     | Purpose                                       |
| ---------------------------- | --------------------------------------------- |
| `playbooks/site.yml`         | Base hardening and core infrastructure        |
| `playbooks/l4/edge.yml`      | Edge proxy + WAF deployment                   |
| `playbooks/l6/engine.yml`    | Docker Engine + compose plugin                |
| `playbooks/l6/portainer.yml` | Portainer BE (optional Manager)               |
| `playbooks/l3/exporters.yml` | Node exporter + cadvisor (all hosts)          |
| `playbooks/l3/stack.yml`     | VictoriaMetrics + Grafana + Loki (brain only) |

#### 2.5.5 Tag-Controlled Execution

##### Core Infrastructure Tags

- [x] `make run PLAYBOOK=playbooks/site.yml TAGS='base,system' ANSIBLE_OPTS='--ask-vault-pass'`
- [x] `make run PLAYBOOK=playbooks/site.yml TAGS='security,firewall' ANSIBLE_OPTS='--ask-vault-pass'`
- [x] `make run PLAYBOOK=playbooks/site.yml TAGS='crowdsec,ips' ANSIBLE_OPTS='--ask-vault-pass'`
- [x] `make run PLAYBOOK=playbooks/site.yml TAGS='vpn,tailscale' ANSIBLE_OPTS='--ask-vault-pass'`
- [x] `make run PLAYBOOK=playbooks/site.yml TAGS='docker,containers' ANSIBLE_OPTS='--ask-vault-pass'`

##### NIST Control Tags

- [x] `make run PLAYBOOK=playbooks/site.yml TAGS='nist' ANSIBLE_OPTS='--ask-vault-pass'`
- [x] `make run PLAYBOOK=playbooks/site.yml TAGS='nist,ac-2' ANSIBLE_OPTS='--ask-vault-pass'`
- [x] `make run PLAYBOOK=playbooks/site.yml TAGS='nist,cm-7' ANSIBLE_OPTS='--ask-vault-pass'`
- [x] `make run PLAYBOOK=playbooks/site.yml TAGS='nist,sc-7' ANSIBLE_OPTS='--ask-vault-pass'`
- [x] `make run PLAYBOOK=playbooks/site.yml TAGS='nist,si-4,au-12' ANSIBLE_OPTS='--ask-vault-pass'`
- [x] `make run PLAYBOOK=playbooks/site.yml TAGS='nist,sc-28' ANSIBLE_OPTS='--ask-vault-pass'`

##### Stack Deployment Tags

- [x] `make run PLAYBOOK=playbooks/l4/edge.yml TAGS='l4-networking,caddy' ANSIBLE_OPTS='--ask-vault-pass'`
- [x] `make run PLAYBOOK=playbooks/l6/portainer.yml TAGS='l6-runtime,portainer' ANSIBLE_OPTS='--ask-vault-pass'`

##### Monitoring & Observability Tags

- [x] `make run PLAYBOOK=playbooks/l3/exporters.yml TAGS='l3-observability,exporters' ANSIBLE_OPTS='--ask-vault-pass'`
- [x] `make run PLAYBOOK=playbooks/l3/exporters.yml TAGS='exporters' ANSIBLE_OPTS='--ask-vault-pass'`
- [x] `make run PLAYBOOK=playbooks/l3/stack.yml TAGS='l3-observability,stack' ANSIBLE_OPTS='--ask-vault-pass'`
- [x] `make run PLAYBOOK=playbooks/l3/exporters.yml TAGS='node_exporter' ANSIBLE_OPTS='--ask-vault-pass'`
- [x] `make run PLAYBOOK=playbooks/l3/exporters.yml TAGS='cadvisor' ANSIBLE_OPTS='--ask-vault-pass'`
- [x] `make run PLAYBOOK=playbooks/l3/stack.yml TAGS='victoriametrics' ANSIBLE_OPTS='--ask-vault-pass'`
- [x] `make run PLAYBOOK=playbooks/l3/stack.yml TAGS='loki' ANSIBLE_OPTS='--ask-vault-pass'`
- [x] `make run PLAYBOOK=playbooks/l3/stack.yml TAGS='grafana' ANSIBLE_OPTS='--ask-vault-pass'`

#### 2.5.6 Skip-Tag Validation

- [x] `make run PLAYBOOK=playbooks/site.yml SKIP_TAGS='tailscale,vpn' ANSIBLE_OPTS='--ask-vault-pass'`
- [x] `make run PLAYBOOK=playbooks/site.yml SKIP_TAGS='security,firewall,fail2ban' ANSIBLE_OPTS='--ask-vault-pass'`

Skip-tag execution confirms selective rollout behavior and safe exclusion paths.

#### 2.5.7 Compliance & Verification

##### Compliance Execution

- [x] `make deploy-compliance ANSIBLE_OPTS='--ask-vault-pass'`

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

- [x] N/A - Application deployment is out of scope for this hardening suite. Reference profiles are provided under `apps/<name>/` for operator-managed stacks.

#### 2.5.9 Vault Operations (Validated but Excluded from Baseline)

The following commands are operationally validated but excluded from routine production audit baselines because they mutate secret material.

- [x] `uv run ansible-vault encrypt inventory/group_vars/all/secrets.yml`
- [x] `uv run ansible-vault edit inventory/group_vars/all/secrets.yml`
- [x] `uv run ansible-vault view inventory/group_vars/all/secrets.yml`

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

| Layer | Name                  | Playbook                                                                                                       | Dependency | Hosts                |
| ----- | --------------------- | -------------------------------------------------------------------------------------------------------------- | ---------- | -------------------- |
| L0    | Control Node Setup    | N/A (manual)                                                                                                   | None       | Control node         |
| L1    | OS Baseline           | `playbooks/site.yml` (roles: L1_os_baseline)                                                                   | L0         | all                  |
| L2    | Networking Foundation | `playbooks/site.yml` (role: L2_compliance) + `playbooks/l3/exporters.yml` (node_exporter)                      | L1         | all                  |
| L3    | Compliance Hardening  | `playbooks/site.yml` (roles: L2_compliance)                                                                    | L2         | all                  |
| L4    | Networking & Edge     | `playbooks/l4/edge.yml` (role: L4_networking)                                                                  | L3         | muscle               |
| L5    | App Profiles          | `playbooks/l6/backup-appdata.yml` + `playbooks/l6/backup-timers.yml` (var: `backup_role_source: app`)          | L4         | brain                |
| L6    | Runtime               | `playbooks/l6/engine.yml` + `playbooks/l6/portainer.yml` + `playbooks/l6/backup-stack.yml` (roles: L6_runtime) | L4         | all + brain + muscle |

### 4.2 L0 - Control Node Setup (Reference Only)

L0 covers the operator's workstation. This is outside the repository scope but required before any playbook execution.

**Prerequisites:**

- Python 3.14+ with `uv` installed
- SSH access to all target hosts
- Ansible inventory file (`inventory/hosts.ini`) configured
- SOPS age key available at `~/.config/sops/age/keys.txt` (Tailscale trio vaulted in `secrets.yml` until gate D4)

**Start commands:**

```bash
# Install Python toolchain
uv sync

# Install Ansible collections
make install-collections

# Validate environment
make check-toolchain
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
make run PLAYBOOK=playbooks/site.yml TAGS='l1-os-baseline'
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
make run PLAYBOOK=playbooks/site.yml TAGS='l2-networking'
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
make run PLAYBOOK=playbooks/site.yml TAGS='l3-compliance'
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
make run PLAYBOOK=playbooks/l4/edge.yml TAGS='l4-networking,caddy,ingress'
```

**Verification:**

```bash
# Check Caddy container running
uv run ansible muscle -i inventory/hosts.ini -m shell -a "docker ps --filter name=caddy --format '{{.Status}}'"

# Verify TLS endpoint
curl -fsS https://<public-domain>/health 2>&1 | head -5
```

### 4.7 L5 - App Profiles

Backup and application reference layer. Runs database dumps and Restic backups for app data. The suite does NOT deploy applications - it provides reference profiles under `apps/` for operator-managed deployment.

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

### 4.8a Deploy Path: Compose-only (first-class)

A minimal deploy requires zero management-UI overhead (ADR-07). `enable_portainer: false` is the default in `inventory/group_vars/all/main.yml`, so the manager code path never executes and no `portainer_*` variable is defined or required (spec F2).

**Start command:**

```bash
# Docker Engine + Compose plugin on all hosts - no vault prompt, no manager vars
make deploy-engine

# Edge proxy (optional, per host)
make deploy-edge BACKEND=caddy TARGET=brain-1
```

**Verification:**

```bash
uv run ansible all -i inventory/hosts.ini -m shell -a "docker version --format '{{.Server.Version}}'"
uv run ansible brain -i inventory/hosts.ini -m shell -a "docker compose ls"
```

**Troubleshooting:**
- The Compose-only path never touches `playbooks/l6/portainer.yml`; `deploy-portainer` (with `-e enable_portainer=true`) is the explicit opt-in.
- If a run fails on an undefined `portainer_*` variable, a manager variable leaked into a host/group vars file: `portainer_*` is confined to `inventory/group_vars/all/managers/` (N4) and `enable_portainer` must stay `false`.
- Secrets decrypt transparently via SOPS+age - no `--ask-vault-pass` needed (Tailscale trio consumers excepted, see §1.4).

### 4.9 Boot Sequence Architecture Rationale

- **L2 (Networking Foundation) before L3 (Compliance):** The Tailscale mesh must be established before CrowdSec can register with the central API, before audit logs ship over the mesh, and before user_hardening can verify SSH key distribution across nodes. Packages must be installed before compliance scans can validate versions.
- **L3 (Compliance) before L4 (Ingress):** The firewall, fail2ban, and CrowdSec bouncers must be active before Caddy and the WAF are exposed, ensuring a defense-in-depth perimeter.
- **L4 (Ingress) before L5 (Apps):** Caddy must provide TLS termination before application traffic can flow.
- **L4 (Ingress) before L6 (Runtime):** Docker Engine (deployed as part of L6) must be available for L4 containers. In practice, `make deploy-engine` followed by `make deploy-portainer` handles L6, while `make deploy-platform` deploys all of L2+L3+L6 together.

---

## §4a Bootstrap Flow (Tailscale + SSH Lockdown)

### 4a.1 Variable: `bootstrap_mode`

First-deploy switch (a "bootstrap gate"), **not** a NIST control. It only
controls whether the firewall/SSH config render the bootstrap exception
(ACCEPT SSH from `controller_ip` on all interfaces) so the first deploy can
complete before Tailscale is established. Defined in
`inventory/group_vars/all/main.yml` with a default of `false` (steady-state).

- `bootstrap_mode: true` → render ACCEPT SSH from `controller_ip` on all interfaces (first deploy only)
- `bootstrap_mode: false` → no exception rendered; SSH only via Tailscale CGNAT

**Never set to `true` in a vars file.** Always pass via `--extra-vars`:

```bash
make deploy-first
```

### 4a.2 First Deploy

```bash
# 1. Initial deployment in bootstrap mode (renders SSH ACCEPT from controller_ip):
make deploy-first

# 2. After deploy, get the Tailscale IP from the lockdown output:
uv run ansible all -i inventory/hosts.ini -m shell -a "tailscale ip -4"

# 3. Update ansible_host in inventory/hosts.ini to the Tailscale IP:
#    ansible_host: 100.x.y.z
```

The `lockdown.yml` playbook runs automatically at the end of `site.yml` and
ALWAYS closes public SSH at the end of the same run (pre-flights verify
Tailscale is online; the verification steps fail closed if the DROP did not
take effect):

- Disables root SSH (`PermitRootLogin no`)
- Pins `AllowUsers` to the Tailscale CGNAT range
- Applies public SSH DROP on all non-Tailscale interfaces
- Removes the bootstrap ACCEPT exception (UFW rule / nftables line)
- Creates `/etc/tailscale-recover.lock` marker file
- Prints Tailscale IPs for inventory update

> **IMPORTANT:** because the first deploy closes public SSH at the end of the
> SAME run, `ansible_host` in `inventory/hosts.ini` MUST be switched to the
> Tailscale IPs immediately after the first deploy, before any subsequent run.

### 4a.3 Steady-State Deploys

```bash
# Subsequent deploys (via Tailscale IP):
make deploy-hardening
```

Lockdown pre-flight checks that Tailscale is connected and the marker exists on every deploy.

### 4a.4 Lockdown Without Full `site.yml`

When deploying individual playbooks (which does not run `site.yml`), run lockdown manually:

```bash
uv run ansible-playbook -i inventory/hosts.ini playbooks/l2/lockdown.yml
```

### 4a.5 Recovery - Tailscale Down

If Tailscale is unreachable and SSH is locked down:

**Option A - Re-bootstrap via cloud console:**

```bash
# Connect via cloud provider serial/SPICE console, then:
make deploy-first
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
uv run ansible-playbook -i inventory/hosts.ini playbooks/l2/lockdown.yml
```

---

## §5 Deploy Procedures

### 5.1 Initial Provisioning

Complete greenfield deployment sequence. Run from L0 through L6.

```bash
# 1. Control node setup
uv sync
make install-collections
make check-toolchain

# 2. Secrets setup (SOPS + age; vault only for the tailscale trio)
age-keygen -o age/keys.txt                    # back the key up OFFLINE first
#    replace the age1<PLACEHOLDER> recipient in .sops.yaml
make sops-init
make sops-edit                                # populate secrets
make sops-encrypt
uv run ansible-vault encrypt inventory/group_vars/all/secrets.yml
uv run ansible-vault edit inventory/group_vars/all/secrets.yml    # tailscale trio (until expiry)

# 3. L1 - OS Baseline
make run PLAYBOOK=playbooks/site.yml TAGS='l1-os-baseline'

# 4. L2 - Networking Foundation (Tailscale)
make run PLAYBOOK=playbooks/site.yml TAGS='l2-networking'

# 5. Verify Tailscale mesh
make verify-tailscale

# 6. L3 - Compliance Hardening
make run PLAYBOOK=playbooks/site.yml TAGS='l3-compliance'

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

| Playbook                | Command                                             | Use Case                                       |
| ----------------------- | --------------------------------------------------- | ---------------------------------------------- |
| `site.yml`              | `make deploy-hardening`                                       | OS hardening + compliance                      |
| `l6/engine.yml`         | `make deploy-engine`                                | Docker Engine + compose plugin                 |
| `l4/edge.yml`           | `make run PLAYBOOK=playbooks/l4/edge.yml` | Caddy + WAF deployment                         |
| `l6/portainer.yml`      | `make deploy-portainer`                             | Portainer BE (optional Manager)                |
| `l6/backup-stack.yml`   | `make deploy-backup-stack`                          | Runtime backup (Restic → R2)                   |
| `l3/exporters.yml`      | `make deploy-monitoring`                            | Node exporter + cadvisor (all hosts)           |
| `l3/stack.yml`          | `make deploy-monitoring`                            | VictoriaMetrics + Grafana + Loki (brain only)  |
| `l6/backup-appdata.yml` | `make deploy-backups`                               | App data backup (database dumps → Restic → R2) |
| `l6/backup-timers.yml`  | `make deploy-backup-timers`                         | Systemd backup timer scheduling                |
| `local-devices.yml`     | `make deploy-local`                                 | Workstation hardening                          |
| `l2/compliance.yml`     | `make deploy-compliance`                  | Compliance audit tags only                     |

### 5.3 Selective Deploy (Tags / Limits)

Narrow deployment scope for surgical changes or testing.

**By tag:**

```bash
# Run only NIST AC-2 controls
make run PLAYBOOK=playbooks/site.yml TAGS='nist,ac-2'

# Run only CrowdSec IPS
make run PLAYBOOK=playbooks/site.yml TAGS='crowdsec,ips'

# Run only Docker Engine
make run PLAYBOOK=playbooks/l6/engine.yml TAGS='docker'
```

**By host limit:**

```bash
# Deploy to single host
make deploy-hardening ANSIBLE_LIMIT=brain

# Deploy to a group
make deploy-hardening ANSIBLE_LIMIT=muscle
```

**Excluding tags:**

```bash
# Skip VPN and Tailscale
make run PLAYBOOK=playbooks/site.yml SKIP_TAGS='tailscale,vpn'
```

### 5.4 Dry-Run (Check Mode)

Validate without mutating. Always dry-run before production deploy.

```bash
# Dry-run site.yml
make run CHECK=1 PLAYBOOK=playbooks/site.yml

# Dry-run with vault pass
make run CHECK=1 PLAYBOOK=playbooks/site.yml ANSIBLE_OPTS='--ask-vault-pass'

# Dry-run a single host
make run CHECK=1 PLAYBOOK=playbooks/site.yml ANSIBLE_LIMIT=brain
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
make deploy-compliance
```

This executes `playbooks/l2/compliance.yml` with NIST 800-53 compliance tags, collecting evidence without mutating system state.

### 5.6 Decision Guidance

| Scenario             | Recommended Approach                                                   |
| -------------------- | ---------------------------------------------------------------------- |
| First deployment     | Full L0→L6 sequence (§5.1)                                             |
| OS update applied    | Dry-run → `make deploy-hardening`                                                |
| Security patch only  | `make run PLAYBOOK=playbooks/site.yml TAGS='security'` |
| Configuration change | Dry-run affected playbook → deploy                                     |
| Pre-audit validation | `make deploy-compliance`                                     |
| Destructive teardown | `make nuke CONFIRM=DESTROY_ALL_INFRASTRUCTURE`                         |

### 5.7 Variable Overrides

| Variable            | Default                                | Purpose                           |
| ------------------- | -------------------------------------- | --------------------------------- |
| `ANSIBLE_INVENTORY` | `inventory/hosts.ini`                  | Inventory file path               |
| `ANSIBLE_LIMIT`     | (all hosts)                            | Limit to host or group            |
| `PLAYBOOK`          | `playbooks/site.yml`                   | Target playbook for `run`         |
| `TAGS`              | (all tags)                             | Filter by tags (`run`)            |
| `SKIP_TAGS`         | (none)                                 | Exclude tags (`run`)              |
| `CHECK`             | (empty)                                | `1` → `--check --diff` (`run`)    |
| `ANSIBLE_TAGS`      | (all tags)                             | Tags for the `deploy-tags` alias  |
| `ANSIBLE_SKIP_TAGS` | (none)                                 | Legacy; use `SKIP_TAGS` with `run`     |
| `ANSIBLE_OPTS`      | (empty)                                | Pass extra ansible-playbook flags |
| `VAULT_PROMPT_FLAG` | (empty)                              | Retired: deploy targets no longer prompt (SOPS+age). Tailscale trio consumers pin `--ask-vault-pass` until trio expiry; use `ANSIBLE_OPTS='--ask-vault-pass'` when a non-tailscale target still needs the vault. |
| `APT_FORCE`         | `false`                                | Force-clean locked APT states     |
| `SOPS_FILE`        | `inventory/group_vars/all/secrets.sops.yml` | SOPS secrets file (make sops-*)         |

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
| Application Stacks  | Operator-managed via reference profiles under `apps/`                                                   | Deploy/redeploy L5 containers as needed  |

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
make deploy-hardening ANSIBLE_LIMIT=<host>

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
uv run ansible-vault view inventory/group_vars/all/secrets.yml

# 4. Test deployment (dry-run)
make run CHECK=1 PLAYBOOK=playbooks/site.yml
```

### 7.2 Secret Rotation

After updating secrets (SOPS + age):

```bash
# 1. Edit the SOPS file (decrypts to $EDITOR, re-encrypts on save)
make sops-edit
#    Manager edge keys:
make sops-edit SOPS_FILE=inventory/group_vars/all/managers/portainer.sops.yml

# 2. Deploy to propagate new secrets
make deploy-hardening
make deploy-engine
make deploy-portainer

# 3. Re-deploy applications to propagate new secrets
# Application config is operator-managed via apps/<name>/ profiles
```

> The Tailscale trio remains vaulted until expiry: `uv run ansible-vault edit inventory/group_vars/all/secrets.yml` (re-encrypts on save; see §7.4).

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

# 2. Update the key in vault (prompts for password)
uv run ansible-vault edit inventory/group_vars/all/secrets.yml
#    Update tailscale_auth_key value

# 3. Re-encrypt (only needed for a new/plaintext file; edit re-encrypts on save)
uv run ansible-vault encrypt inventory/group_vars/all/secrets.yml

# 4. Re-deploy Tailscale to all hosts
make run PLAYBOOK=playbooks/site.yml TAGS='tailscale'

# 5. Verify mesh health
make verify-tailscale
```

> **Note:** Tailscale key rotation does not disrupt existing mesh connections. Nodes already authenticated remain connected. New keys apply only on re-auth.

> **Vault retirement gate (D4):** the Tailscale auth/ACL keys (the "trio": `tailscale_auth_key`, `tailscale_acl_key`, `tailscale_acl_client_id`) are the ONLY remaining Ansible Vault contents. At key expiry: (1) delete the trio from the vault, (2) remove `inventory/group_vars/all/secrets.yml`, (3) remove the `--ask-vault-pass` literals from the six tailscale consumers in the Makefile (`deploy-hardening`, `deploy-compliance`, `reconnect-tailscale`, `deploy-local`, `nuke`, `provision-host`), (4) verify `grep -n -- '--ask-vault-pass' Makefile` returns zero matches - the vault then exists only for bootstrap.

### 7.5 Docker Credential Rotation

Docker registry credentials (private registries) are stored in `inventory/group_vars/all/secrets.sops.yml` (`vault_github_token`).

```bash
# 1. Update credentials in the SOPS file
make sops-edit

# 2. Re-encrypt (only needed after plaintext edits; sops-edit re-encrypts on save)
make sops-encrypt

# 3. Re-deploy Docker configuration
make run PLAYBOOK=playbooks/l6/engine.yml TAGS='docker'

# 4. Verify Docker can pull images
uv run ansible all -i inventory/hosts.ini -m shell -a "docker pull alpine:latest"
```

---

## §8 Troubleshooting

### 8.1 Common Failure Modes

| Symptom                                                                         | Likely Cause                                                                                | Diagnostic Command                                                                                                                                                  | Resolution                                                                                      |
| ------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------- |
| `make deploy-hardening` fails with SSH error                                              | SSH key not loaded or host unreachable                                                      | `uv run ansible all -i inventory/hosts.ini -m ping`                                                                                                                 | Verify SSH agent, check Tailscale connectivity                                                  |
| `make lint` fails                                                               | YAML syntax or ansible-lint violation                                                       | `make lint PLAYBOOK=playbooks/site.yml` (see error output)                                                                                                          | Fix YAML indentation or lint violations; run `uv sync` if toolchain missing                     |
| `apt` lock held during deploy                                                   | Stale dpkg/apt process                                                                      | `uv run ansible all -i inventory/hosts.ini -m shell -a "lsof /var/lib/dpkg/lock-frontend"`                                                                          | Retry with `APT_FORCE=true` or manually kill stale process                                      |
| Vault decryption fails                                                          | Wrong vault password or corrupted vault                                                     | `uv run ansible-vault view inventory/group_vars/all/secrets.yml`                                                                                                    | Verify `/tmp/.vault_pass` matches; restore from backup if corrupted                             |
| `changed` tasks on second deploy                                                | Idempotency issue in a role                                                                 | `make run CHECK=1 PLAYBOOK=playbooks/site.yml` (note changed tasks)                                                                                                     | Investigate the role's idempotency; check for non-deterministic tasks                           |
| CrowdSec bouncers not blocking                                                  | Bouncer config out of sync                                                                  | `make verify-crowdsec`                                                                                                                                              | Re-deploy CrowdSec role: `make run PLAYBOOK=playbooks/site.yml TAGS='crowdsec'` |
| Tailscale node offline                                                          | tailscaled not running or auth expired                                                      | `make verify-tailscale`                                                                                                                                             | SSH via alternative path, `systemctl restart tailscaled`, or re-deploy Tailscale role           |
| Docker container exits immediately                                              | Image pull failure or config error                                                          | `docker logs <container>`                                                                                                                                           | Check `.env` values, verify image tag exists, check compose syntax                              |
| Observability stack not scraping                                                | Exporter down or VM config mismatch                                                         | `make verify-observability`                                                                                                                                         | Check Docker container status, verify scrape targets in VictoriaMetrics                         |
| Portainer inaccessible                                                          | Portainer disabled or container stopped                                                     | `uv run ansible muscle -i inventory/hosts.ini -m shell -a "docker ps --filter name=portainer"`                                                                      | Ensure `make deploy-portainer` was run (the target passes `-e enable_portainer=true`; do not edit group_vars)                                  |
| App deployment failure                                                          | Playbook error or missing SOPS secret                                                      | Check `make lint` output, verify SOPS secrets                                                                                                                      | Re-deploy via the operator's own toolchain using reference profiles at `apps/<name>/`           |
| Grafana crash-loops with `Datasource provisioning error: data source not found` | Stale auto-generated datasource UID in Grafana DB (pre-`uid: victoriametrics` provisioning) | `sudo python3 -c "import sqlite3; c=sqlite3.connect('/srv/app/observability/grafana-data/grafana.db'); print(c.execute('SELECT uid FROM data_source').fetchall())"` | One-time datasource UID migration (see note below)                                              |

#### Grafana Datasource UID Migration (one-time)

When an existing observability deployment was provisioned before `uid: victoriametrics`
was added to the datasource provisioning file, Grafana's DB keeps the auto-generated
datasource UID (provisioning preserves UIDs on name-match), so alert rules referencing
`datasourceUid: victoriametrics` fail with `Datasource provisioning error: data source
not found` and Grafana crash-loops on start.

One-time fix per brain host:

1. `sudo docker compose -f /srv/app/observability/docker-compose.yml stop grafana`
2. `sudo cp /srv/app/observability/grafana-data/grafana.db /srv/app/observability/grafana-data/grafana.db.bak-$(date +%Y%m%d)`
3. `sudo python3 -c "import sqlite3; c=sqlite3.connect('/srv/app/observability/grafana-data/grafana.db'); c.execute('DELETE FROM data_source'); c.commit(); c.close()"`
4. `sudo docker compose -f /srv/app/observability/docker-compose.yml up -d grafana`

Grafana re-provisions both datasources on start, now with `uid: victoriametrics`.
Do NOT use `deleteDatasources` in the provisioning file — it is destructive to
custom datasource state.

#### Known Gap: Brain-Only Backup Timers vs Muscle-Hosted App Databases

The `backup-db-<app>` timers (deployed via `deploy-backup-timers`) run on the
brain hosts and execute `docker exec` against BRAIN-local containers. When app
databases are hosted on muscle hosts (Fase 4 app deployment), those timers
cannot reach the databases. Documented gap pending an architecture decision:
per-host timers on muscle, remote dump over the tailnet, or DB placement.

### 8.2 Diagnostic Commands Per Layer

| Layer | Diagnostic       | Command                                                                                                                            |
| ----- | ---------------- | ---------------------------------------------------------------------------------------------------------------------------------- | ------------------------ |
| L0    | Toolchain health | `uv run ansible --version && make check-toolchain`                                                                                        |
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
2. **SOPS age key corrupted or lost** → See [INCIDENT_RESPONSE_DR.md](../operations/INCIDENT_RESPONSE_DR.md) for secret recovery workflows.
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
