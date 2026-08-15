---
title: ADR-04 - Abstraction by Convention, Not Framework
type: architecture
owner: maintainers
audience: all
version: v6.0.0
last-reviewed: 2026-06-28
status: accepted
principles: 8 (Boundaries), 10 (Reversibility)
project: developmi-stack
repo: github.com/Developmi/stack
---

## 1. Context

The platform must support multiple runtime engines (Compose today, Swarm/K3s tomorrow) without forking the application profile schema. A framework approach (e.g., a Python abstraction layer that maps profiles to runtimes) would add complexity and lock-in.

---

## 2. Decision

**Abstraction by convention, not framework.** The profile schema decouples "what" (application intent) from "how" (runtime-specific rendering). No runtime framework needed.

| Profile Field                | Compose (today)              | Swarm (future)         |
| ---------------------------- | ---------------------------- | ---------------------- |
| `compose_file`               | Render + `docker compose up` | Ignored                |
| `secrets`                    | Vault → .env                 | Vault → Docker secrets |
| `backup.db_type`             | pg_dump container            | pg_dump pod            |
| `monitoring.health_endpoint` | HTTP check                   | K8s liveness probe     |

> **Obsolete note (2026-08-09, decouple-manager-sops):** profile secrets now resolve from SOPS + age (`inventory/group_vars/all/secrets.sops.yml`), not Ansible Vault. Historical record - kept verbatim.

The profile schema contains zero Compose-specific directives. `compose_file` is a path hint, not a runtime switch.

---

## 3. Consequences

### Positive

- **No framework lock-in**: adding a new runtime means writing one adapter file, not rewriting profiles
- **KISS**: conventions are Ansible-native (file paths, variable names, Jinja2 templates)
- **Reversible**: removing a runtime means deleting its adapter directory - zero profile changes

### Negative

- Convention-based abstraction requires discipline - profile fields must stay generic
- Adapter writers must understand both the profile schema AND the target runtime - documented in `roles/L6_runtime/` READMEs

---

## 4. Principle Reference

- **Principle 8 (Layers don't reach across boundaries)**: The profile schema (L5) never references runtime details (L6)
- **Principle 10 (Reversibility over optimization)**: No framework means no irreversible architectural commitment

---

## Related Documents

- [../ARCHITECTURE.md](../ARCHITECTURE.md) - Profile-to-runtime mapping table, runtime adapter section
- [ADR-02.md](ADR-02.md) - YAML Profiles over DSL
