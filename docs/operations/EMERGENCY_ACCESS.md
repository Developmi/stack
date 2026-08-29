---
title: Emergency Access & Recovery Guide
type: operations
owner: maintainers
audience: operator
version: v6.0.0
last-reviewed: 2026-07-16
status: active
project: developmi-stack
repo: github.com/Developmi/stack
---

# Emergency Access & Recovery Guide

This document covers emergency console/rescue access and rollback procedures for
Phase 07 (Disable Root SSH).

## Console & Rescue Access

### brain-1 (Oracle Cloud Infrastructure)

Access via **OCI Console → Compute → Instances → brain-1 → Console Connection**.
Launch Cloud Shell or paste the connection string to open a serial console.
This bypasses SSH entirely and works even when sshd is misconfigured.

### muscle-1, muscle-2 (Hetzner)

Access via **Hetzner Robot Web UI → Server → Rescue**.
Activate the rescue system, reboot the server, and connect via the temporary
root password displayed in the Robot panel. Mount the disk:

```
mount /dev/sda1 /mnt
chroot /mnt /bin/bash
```

## Manual sshd_config Revert

If the automation user is locked out, run this from console/rescue:

```bash
sed -i 's/^PermitRootLogin no/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config && \
sed -i 's/^ChallengeResponseAuthentication no/ChallengeResponseAuthentication yes/' /etc/ssh/sshd_config && \
systemctl restart sshd
```

## Inventory Rollback (reverse Phase 3)

```bash
# brain-1 (current: ansible_user=root → was changed to automation)
sed -i 's/ansible_user=automation/ansible_user=root/' inventory/hosts.ini

# muscle-1 and muscle-2 (current: ansible_user=ubuntu → was changed to automation)
sed -i 's/ansible_user=automation/ansible_user=ubuntu/' inventory/hosts.ini
```

## ansible.cfg Rollback (reverse Phase 3)

```bash
sed -i 's/become_user = automation/become_user = root/' ansible.cfg
```

The exact line in `ansible.cfg` is line 21:

```
become_user = root
```

## Tailscale IPs (for direct SSH fallback)

| Host     | Tailscale IP |
| -------- | ------------ |
| brain-1  | 100.00.00.00 |
| muscle-1 | 100.00.00.00 |
| muscle-2 | 100.00.00.00 |

## Emergency IP Block (Caddy WAF UI)

Blocking an attacker IP is an **emergency change** (SP 800-128 emergency changes; ITIL ECAB). It takes effect immediately through the UI — it must not wait for a pipeline.

### Immediate action (≤5 minutes)

```bash
# 1. SSH to the node running caddy-waf-ui
ssh user@<host>

# 2. Block the IP via the UI API (loopback only)
curl -X POST http://127.0.0.1:8080/api/sites/<slug>/iprules \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $(docker inspect caddy-waf-ui --format '{{range .Config.Env}}{{println .}}{{end}}' | grep CADDY_UI_TOKEN | cut -d= -f2)" \
  -d '{"denylist": ["<attacker-ip>/32"]}'

# 3. Verify the block took effect (Caddy should return 403 for the blocked IP)
curl -I https://<domain>/ -H "X-Forwarded-For: <attacker-ip>"
```

### Retrospective approval (≤24h)

1. Document the emergency change in the incident log:
   - Who made the change
   - Which IP was blocked and why
   - What service/domain was targeted
   - Time of block and time of this documentation
2. Obtain retrospective approval from the team lead or designated approver
3. Complete a Post-Implementation Review (PIR):
   - Was the block effective?
   - Was the attacker mitigated?
   - Should the block be permanent (promote to IaC) or temporary?

### Promotion to IaC (if permanent)

```bash
# Add the IP deny rule to the Ansible overlay or ingress_services config
# Create a reviewed PR to promote the emergency denylist entry
# Review for removal once the threat is over
```

### Rollback

```bash
# Remove the IP from denylist via UI
# Or revert the overlay file from a snapshot:
# UI → Sites → select domain → History → select pre-block snapshot → Rollback
```

## Related Documents

- [OPERATIONS_RUNBOOK.md](OPERATIONS_RUNBOOK.md) - Definitive operations runbook: commands, audit, deployment, restart, rotation, troubleshooting
- [COMPATIBILITY.md](COMPATIBILITY_MATRIX.md) - Tested OS and architecture support matrix
- [README.md](README.md) - Documentation index
