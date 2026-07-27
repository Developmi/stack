---
title: ADR-02 - YAML Profiles over DSL
type: architecture
owner: maintainers
audience: all
version: v6.0.0
last-reviewed: 2026-06-28
status: accepted
principles: 3 (Automation), 5 (Evidence)
project: developmi-stack
repo: github.com/Developmi/stack
---

## 1. Context

Application profiles define what an app needs: secrets, backup policy, monitoring targets, compliance tags, DR tier. We needed a format that is Ansible-native, self-documenting, and requires zero new tooling.

Options considered: a custom DSL, JSON schema, Python dataclasses, and YAML.

---

## 2. Decision

**Application profiles use YAML with a fixed 11-field schema.**

```yaml
# apps/<name>/profile.yml
name: chatwoot                        # MUST
version: "4.12.1"                     # MUST
compose_file: compose.yml.j2          # MUST
vars_file: vars.yml                   # MUST
secrets_file: secrets.yml             # MUST
supported_arch: [amd64, arm64]        # MUST
depends_on: [L4_networking/caddy, backup]   # SHOULD
backup: { schedule, retention, ... }  # SHOULD
monitoring: { health_endpoint, ... }  # SHOULD
compliance_tags: [ac-2, sc-7, ...]    # SHOULD
dr_tier: critical                     # SHOULD
```

---

## 3. Consequences

### Positive
- **Ansible-native**: YAML is Ansible's first-class data format - no parsing overhead
- **Self-documenting**: field names are human-readable; no DSL grammar to learn
- **Zero new tooling**: `ansible.builtin.include_vars` loads profiles directly
- **Version-controlled diffability**: YAML diffs are readable, reviewable, mergable

### Negative
- Less expressive than a DSL for complex conditional logic (mitigated by Ansible's `when:` in playbooks)
- YAML footguns (anchors, aliases, indentation) - mitigated by schema validation

---

## 4. Principle Reference

- **Principle 3 (Automation beats documentation)**: Profile == machine-readable intent - no manual translation step
- **Principle 5 (Evidence beats assertion)**: Profile declares compliance tags, making evidence traceable to the profile declaration

---

## Related Documents

- [../ARCHITECTURE.md](../ARCHITECTURE.md) - 11-field profile schema, app catalog
- [ADR-04.md](ADR-04.md) - Abstraction by Convention, Not Framework
