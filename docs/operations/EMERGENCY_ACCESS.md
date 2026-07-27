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

## Related Documents

- [OPERATIONS_RUNBOOK.md](OPERATIONS_RUNBOOK.md) - Definitive operations runbook: commands, audit, deployment, restart, rotation, troubleshooting
- [COMPATIBILITY.md](COMPATIBILITY_MATRIX.md) - Tested OS and architecture support matrix
- [README.md](README.md) - Documentation index
