---
title: ADR-05 - Variable-Driven OS Dispatch
type: architecture
owner: maintainers
audience: all
version: v6.0.0
last-reviewed: 2026-06-28
status: accepted
principles: 4 (Sovereignty)
project: developmi-stack
repo: github.com/Developmi/stack
---

## 1. Context

The platform targets Debian 12 and Ubuntu 22.04 (and potentially Debian 11, Ubuntu 24.04). These OSes have different firewall backends (nftables vs ufw), package names, and default configurations.

The naive approach scatters `when: ansible_os_family == "Debian"` conditionals across every role - making OS-specific logic hard to find, audit, and extend.

---

## 2. Decision

**Centralized `os_*` variables with a variable-driven dispatcher pattern.**

```yaml
# group_vars/all/main.yml
os_firewall_backend: "{{ 'nftables' if ansible_os_family == 'Debian' and ansible_distribution_major_version == '12' else 'ufw' }}"
```

Each role dispatches to the correct backend:

```yaml
# roles/L2_compliance/general/tasks/security/main.yml
- name: Apply firewall rules
  ansible.builtin.include_tasks: "{{ os_firewall_backend }}_rules.yml"
```

---

## 3. Consequences

### Positive
- **Single source of truth**: all OS detection logic lives in `all/main.yml`
- **Testable**: changing `os_firewall_backend` is a single variable change, not scattered `when:` audits
- **Extensible**: adding a new OS means adding one new variable definition + one new backend task file

### Negative
- Variable names must be stable and well-documented - if `os_firewall_backend` changes name, all dispatchers break
- Dispatcher pattern requires all backends to follow the same naming convention (`<backend>_rules.yml`)

---

## 4. Principle Reference

- **Principle 4 (Sovereignty beats convenience)**: The operator chooses the OS; the platform adapts without demanding a specific distro

---

## Related Documents

- [../ARCHITECTURE.md](../ARCHITECTURE.md) - OS Support Matrix, AMD64/ARM64 compatibility
- [../LAYER_BOUNDARIES.md](../LAYER_BOUNDARIES.md) - L1 OS Baseline contract
