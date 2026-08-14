---
title: Developer Onboarding
type: operations
owner: maintainers
audience: maintainer
version: v6.0.0
last-reviewed: 2026-07-16
status: active
project: developmi-stack
repo: github.com/Developmi/stack
---

# Developer Onboarding - Developmi Stack v6.0.0

5-step developer setup sequence to go from zero to running your first Ansible playbook.

---

## Prerequisites

| Component | Version | Installation |
|-----------|---------|-------------|
| **Python** | 3.14+ | `apt install python3.14` or via `pyenv` |
| **uv** | latest stable | `curl -LsSf https://astral.sh/uv/install.sh \| sh` |
| **ansible-core** | 2.21.1 (pinned) | `uv pip install ansible-core==2.21.1` |
| **Git** | 2.40+ | `apt install git` |
| **OS** | Linux (Debian 12 or Ubuntu 22.04 recommended) | - |

---

## Step 1: Clone the Repository

```bash
git clone https://github.com/Developmi/stack.git
cd stack
```

---

## Step 2: Install Toolchain Dependencies

```bash
# Create virtual environment and install dependencies
uv sync

# Verify ansible-core version (must be 2.21.1)
ansible --version | head -1
# Expected: ansible [core 2.21.1]

# Install Ansible collections
make install-collections
```

---

## Step 3: Set Up Secrets (SOPS + age)

```bash
# Copy the SOPS sample and encrypt it with your age key
cp inventory/group_vars/all/secrets.sops.yml.example inventory/group_vars/all/secrets.sops.yml
make sops-encrypt

# Verify secrets are readable
make sops-view
```

> ⚠️ The `.gitignore` excludes `*.sops.yml`. Never commit plaintext secrets. The only vaulted exception is the Tailscale trio (`inventory/group_vars/all/secrets.yml`), retired at gate D4 (OPERATIONS_RUNBOOK §7.4).

---

## Step 4: Run Your First Playbook

```bash
# Full deploy (OS baseline + compliance hardening)
make deploy
# OR
ansible-playbook playbooks/site.yml
```

For a minimal test on a single host:

```bash
ansible-playbook playbooks/site.yml \
  --limit <target-host> \
  --check --diff
```

---

## Step 5: Verification

After deployment, verify the hardening was applied:

```bash
# SSH hardening
ssh -o PasswordAuthentication=no root@<target-host> 2>&1 | grep -q "Permission denied" && echo "PASS" || echo "FAIL"

# Firewall status (Debian 12)
ssh <target-host> "sudo nft list ruleset | head -5"
# Expected: ruleset with standard chains

# Firewall status (Ubuntu 22.04)
ssh <target-host> "sudo ufw status verbose | grep 'Status: active'"

# Compliance evidence
ssh <target-host> "ls /srv/evidence/nist/ac-2/"
# Expected: timestamped evidence files

# System hardening
ssh <target-host> "sysctl kernel.kptr_restrict"
# Expected: 2 (restricted)
```

---

## Common Issues

| Issue | Resolution |
|-------|-----------|
| `ansible-core` version mismatch | `uv pip install ansible-core==2.21.1 --force-reinstall` |
| SOPS age key not found | Ensure `~/.config/sops/age/keys.txt` exists (see Step 3) |
| SSH connection refused | Target host must have SSH enabled. Verify with `ssh <host> echo ok` |
| `uv sync` fails on ARM64 | ARM64 is fully supported. Ensure Python 3.14+ is installed for ARM64 |

---

## Related Documents

- [../architecture/ARCHITECTURE.md](../architecture/ARCHITECTURE.md) - 7-layer platform architecture
- [../project/GLOSSARY.md](../GLOSSARY.md) - SDD/project workflow terminology
- [../project/ONBOARDING.md](../project/ONBOARDING.md) - Project workflow onboarding
- [INCIDENT_RESPONSE_DR.md](INCIDENT_RESPONSE_DR.md) - Incident response and disaster recovery procedures
- [VERSION_PINS.md](VERSION_PINS.md) - Pinned component versions
