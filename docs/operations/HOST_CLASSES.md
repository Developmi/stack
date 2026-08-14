---
title: How to Assign and Manage Host Classes
type: operations
owner: maintainers
audience: operator
version: v6.0.0
last-reviewed: 2026-07-16
status: active
project: developmi-stack
repo: github.com/Developmi/stack
---

# How to Assign and Manage Host Classes

This guide walks you through assigning hosts to classes (`brain`, `muscle`, `local`), migrating hosts between classes, and verifying the result. Host classes control which Ansible roles, hardening profiles, and platform services apply to a node. Assigning the wrong class means the wrong profile is deployed.

*(Source: ARCHITECTURE.md §7)*

## Before You Start

You need to understand what each class does before assigning one.

**Capability summary** - `brain` nodes are management (Portainer, Grafana, backups); `muscle` nodes run application workloads; `local` nodes are operator workstations with minimal platform footprint. For the full 10-row capability matrix (backups, observability, CrowdSec, Tailscale auth, UFW policy, fail2ban bantime, etc.), see [ARCHITECTURE.md §7 - Capability Matrix](../architecture/ARCHITECTURE.md#7-host-classes-brain-muscle-local).

**Role summary** - `brain` and `muscle` get the full L1-L6 role stack (with brain-only management roles), `local` gets L1-L2 plus Docker engine only. For the complete per-class allowed-roles table, see [ARCHITECTURE.md §7 - Allowed Roles per Class](../architecture/ARCHITECTURE.md#7-host-classes-brain-muscle-local).

**Hardening profile** - the `hardening_profile` dispatcher (in [HARDENING-STATUS.md](../security/HARDENING-STATUS.md#hardening-profile-dispatcher)) routes `brain`/`muscle` → `server`, `local` → `workstation`.

> **Legacy variables (documented, not used):** `node_role` (still present in `inventory/hosts.ini.example`), `server_role` and `server_type` (in `inventory/group_vars/{brain,muscle,local}/main.yml`) are legacy classifiers with no code usage. The real classifiers are `host_class` (inventory group membership) + `hardening_profile`. Do not build new logic on the legacy vars; `server_type` is only consumed as a cosmetic display string in `playbooks/ops/local-devices.yml`. They are kept in the repo for reference only and may be removed in a future major release.

**Brain vs muscle roles** - both run Docker, but with different purposes:
- **brain** = operations + observability (runs Docker, monitoring stack, edge proxy, backup orchestration)
- **muscle** = application runtime (runs Docker, application containers, backup-db for databases)

The suite does NOT deploy applications - it prepares the hardened foundation. Application deployment is the operator's responsibility using reference profiles at `apps/`.

## Assigning a Host to a Class

### Prerequisites

- Ansible inventory file (`hosts.yml` or equivalent) is writable
- `inventory/group_vars/` directory structure exists: `brain/`, `muscle/`, `local/`
- SOPS age private key available at `~/.config/sops/age/keys.txt` to decrypt `secrets.sops.yml` (the Tailscale trio in `secrets.yml` is the only vaulted exception until gate D4, OPERATIONS_RUNBOOK §7.4)
- Bootstrap identity follows the inventory: SSH as `root` on classic VPS/lab hosts; on cloud images (OCI/AWS/GCP) SSH as the cloud image user (non-root, NOPASSWD sudo). `ansible_become` is derived from `ansible_user`. Declare `ansible_user` per host and `ansible_ssh_private_key_file` in `all:vars`.

### Step 1 - Create or verify the group_vars file

```bash
# For a new brain node:
mkdir -p inventory/group_vars/brain
test -f inventory/group_vars/brain/main.yml || cat > inventory/group_vars/brain/main.yml <<'EOF'
hardening_profile: server
# Add brain-specific vars below (observability endpoints, backup targets, etc.)
EOF
```

Repeat for `muscle` or `local`, setting `hardening_profile: server` or `hardening_profile: workstation` respectively.

### Step 2 - Tag the host in inventory

Add the host to the matching Ansible group in your inventory file:

```yaml
# inventory/hosts.yml
all:
  children:
    brain:
      hosts:
        mgmt-node-01:
          ansible_host: 10.0.0.10
    muscle:
      hosts:
        worker-01:
          ansible_host: 10.0.0.20
        worker-02:
          ansible_host: 10.0.0.21
    local:
      hosts:
        dev-laptop:
          ansible_host: 192.168.1.50
```

### Step 3 - Verify group_vars are loaded

```bash
# Confirm the host picks up the right hardening_profile
ansible mgmt-node-01 -m debug -a "var=hardening_profile"

# List all facts for the host to verify group membership
ansible mgmt-node-01 -m setup | grep ansible_playbook_dir
```

### Step 4 - Dry-run with the new class

```bash
uv run ansible-playbook -i inventory/hosts.yml site.yml --limit mgmt-node-01 --check --diff
```

If the dry-run shows unexpected changes (e.g., a `local` host picking up server-grade hardening), recheck the inventory group membership and `group_vars` file path.

## Class Migration Procedure

Migrating a host between classes (e.g., promoting a `local` node to `muscle`, or downgrading a `brain` → `muscle`) requires careful reconfiguration - the hardening profile and allowed roles change.

### brain → muscle migration

1. **Backup existing configuration**
   ```bash
   mkdir -p backups/$(date +%Y%m%d)
   ansible <hostname> -m fetch \
     --src=/etc/ssh/sshd_config \
     --dest=backups/$(date +%Y%m%d)/ \
     --flat
   ```

2. **Reassign group in inventory** - move the host from the `brain` group to the `muscle` group in `inventory/hosts.yml`. If the host is the *only* brain, you must first designate another node as brain or accept that management services (Portainer, Grafana) will go down.

3. **Review role differences** - `muscle` excludes management-only roles. Verify `site.yml` or your playbook does not assign brain-only roles (e.g., `portainer` as primary server) to this host.

4. **Dry-run the migration**
   ```bash
   uv run ansible-playbook -i inventory/hosts.yml site.yml \
     --limit <hostname> --check --diff
   ```
   Watch for:
   - Firewall rule deltas (UFW policy may not change between brain/muscle, but verify)
   - Role removals that would stop services (Portainer server, observability dashboards)
   - Backup target reassignment

5. **Apply**
   ```bash
   uv run ansible-playbook -i inventory/hosts.yml site.yml --limit <hostname>
   ```

### muscle → brain migration

Same steps in reverse, plus:

- Ensure the new brain has sufficient persistent storage for backups and evidence
- Verify observability dashboards are reachable after migration
- If HA, add the new brain to the HA configuration

### local → muscle migration

**This is a significant class change** - the host goes from workstation-grade hardening to server-grade. Steps:

1. Apply muscle `group_vars` per the assignment procedure above
2. Dry-run first - expect SSH config changes, UFW policy tightening, and new service installations (CrowdSec, observability agents, backup timers)
3. Ensure Tailscale auth switches from manual to automated (provision `--authkey`)
4. Apply with `--limit` to avoid unintended changes on other hosts

## Verification Checklist

Run these commands after assigning a class or after a migration to confirm the host is in the expected state.

### Per-class verification

```bash
# 1. Confirm hardening_profile is correct
ansible <hostname> -m debug -a "var=hardening_profile"
# Expected: "server" for brain/muscle, "workstation" for local

# 2. Check active roles (via ansible-playbook tag report)
uv run ansible-playbook -i inventory/hosts.yml site.yml \
  --limit <hostname> --list-tags

# 3. Verify group membership
ansible <hostname> -m debug -a "var=group_names"
# Expected: ["brain"], ["muscle"], or ["local"]

# 4. Check UFW status (brain/muscle)
ansible <hostname> -m shell -a "ufw status verbose" --become

# 5. Check fail2ban status (all classes)
ansible <hostname> -m shell -a "fail2ban-client status" --become

# 6. Check CrowdSec (brain/muscle only)
ansible <hostname> -m shell -a "cscli metrics" --become

# 7. Check Tailscale connectivity
ansible <hostname> -m shell -a "tailscale status" --become

# 8. Full system facts snapshot (compare before/after migration)
ansible <hostname> -m setup > facts_$(date +%Y%m%d).json
```

### Sample verification output

```bash
$ ansible mgmt-node-01 -m debug -a "var=hardening_profile"
mgmt-node-01 | SUCCESS => {
    "hardening_profile": "server"
}

$ ansible mgmt-node-01 -m debug -a "var=group_names"
mgmt-node-01 | SUCCESS => {
    "group_names": [
        "brain"
    ]
}
```

## Troubleshooting

### Wrong hardening profile applied

**Symptom:** `hardening_profile` returns `workstation` on a server host (or vice versa).

**Causes:**
- Host is in the wrong Ansible group
- `inventory/group_vars/<class>/main.yml` is missing or misspelled

**Fix:**
```bash
# Check which vars files are loaded
ansible <hostname> -m debug -a "var=vars"
# Verify the group file exists
ls -la inventory/group_vars/{brain,muscle,local}/main.yml
```

### Missing group_vars file

**Symptom:** `hardening_profile` is undefined, playbook fails with `'hardening_profile' is undefined`.

**Fix:** Create the file per the assignment procedure above, or add a default in `inventory/group_vars/all/main.yml` (with a loud comment that it must be overridden):
```yaml
# inventory/group_vars/all/main.yml
# ponytail: fallback default; every host SHOULD set this in its class group_vars
hardening_profile: "UNDEFINED - set per host class!"
```

### Role mismatch

**Symptom:** A `local` host runs CrowdSec or backup roles it should not have.

**Cause:** `site.yml` or playbook does not gate roles on group membership.

**Fix:** Add `when: "'local' not in group_names"` conditionals in the playbook, or restructure plays so roles are applied per group:
```yaml
- hosts: brain:muscle
  roles:
    - crowdsec
    - observability
    - backup
    - backup-timers
```

### Role removed but service still running

**Symptom:** After brain→muscle migration, Portainer or Grafana is still running on the muscle node.

**Fix:** Ansible roles are additive by default - they do not automatically stop services when a role is removed from a host. Manually stop and disable:
```bash
ansible <hostname> -m systemd -a "name=portainer state=stopped enabled=no" --become
```

## Cross-References

- [ARCHITECTURE.md §7 - Host Classes and Capability Profiles](../architecture/ARCHITECTURE.md#7-host-classes-brain-muscle-local) - SSOT for capability matrix and allowed roles
- [GLOSSARY.md - Host Classes](../GLOSSARY.md#host-classes) - Platform terminology
- [HARDENING-STATUS.md - Hardening Profile Dispatcher](../security/HARDENING-STATUS.md#hardening-profile-dispatcher) - Profile dispatch logic
- [LAYER_BOUNDARIES.md](../architecture/LAYER_BOUNDARIES.md) - L3 deployment scoping
- [OPERATIONS_RUNBOOK.md](OPERATIONS_RUNBOOK.md) - Boot sequence per layer
