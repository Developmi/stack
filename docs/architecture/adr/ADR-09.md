---
title: ADR-09 - AMD64/ARM64 Mandatory Compatibility
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

The platform targets heterogeneous hardware: AMD64 (x86_64) on traditional servers and ARM64 on Oracle Ampere instances. Not all applications and Docker images support both architectures. Deploying an AMD64-only image on an ARM64 host fails silently or with cryptic errors.

We needed a mechanism to declare, validate, and enforce architecture compatibility before deployment - not after failure.

---

## 2. Decision

**Every application profile MUST declare `supported_arch`. The deploy playbook validates that the target host's architecture is in the supported list before deploying.**

```yaml
# apps/chatwoot/profile.yml
supported_arch: [amd64, arm64] # MUST field
```

### Pre-flight validation

```yaml
# apps.yml (simplified)
- name: Assert architecture compatibility
  ansible.builtin.assert:
    that:
      - "ansible_architecture in app_profile.supported_arch"
    fail_msg: >
      {{ app_profile.name }} does not support {{ ansible_architecture }}.
      Supported architectures: {{ app_profile.supported_arch | join(', ') }}
```

### AMD64/ARM64 Compatibility Table (mandatory)

| Component                        | AMD64 | ARM64 (Ampere) | Notes                              |
| -------------------------------- | ----- | -------------- | ---------------------------------- |
| Debian 12 / Ubuntu 22.04         | ✅    | ✅             | ARM64 on Oracle Ampere             |
| Docker Engine                    | ✅    | ✅             | Same version on both               |
| Caddy                            | ✅    | ✅             | Official multi-arch binary         |
| Portainer BE                     | ✅    | ✅             | Multi-arch image                   |
| App images (chatwoot, n8n, etc.) | ✅    | ✅             | Verify per-app in `supported_arch` |
| CrowdSec                         | ✅    | ✅             | apt repo multi-arch                |
| Tailscale                        | ✅    | ✅             | Official multi-arch binary         |

---

## 3. Consequences

### Positive

- **Pre-deployment validation**: architecture mismatch caught before containers start
- **Declarative compatibility**: `supported_arch` is self-documenting - no guessing which apps run where
- **Principle 4 (Sovereignty)**: The operator chooses the hardware; the platform adapts

### Negative

- Every app profile must declare `supported_arch` - this is a MUST field, no default assumed
- Compatibility table must be maintained as new components are added

---

## 4. Principle Reference

- **Principle 4 (Sovereignty beats convenience)**: The operator controls hardware choice; the platform enforces compatibility, not lock-in

---

## Related Documents

- [../ARCHITECTURE.md](../ARCHITECTURE.md) - OS Support Matrix, AMD64/ARM64 compatibility section
- [ADR-02.md](ADR-02.md) - YAML Profiles over DSL (profile schema includes `supported_arch`)
