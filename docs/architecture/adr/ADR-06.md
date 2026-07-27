---
title: ADR-06 - apps/ over recommended_apps/
type: architecture
owner: maintainers
audience: all
version: v6.0.0
last-reviewed: 2026-06-28
status: accepted
principles: 9 (Open core, not open-washing)
project: developmi-stack
repo: github.com/Developmi/stack
---

## 1. Context

The stack v5.5.0 had a `recommended_apps/` directory - a flat collection of Docker Compose files loosely organized by application. There was no schema enforcement, no required fields, and no distinction between "community example" and "production profile."

v6.0.0 needed a structured, enforceable contract for every application the platform supports.

---

## 2. Decision

**Replace `recommended_apps/` with `apps/` - structured application profiles with an enforced schema.**

```
apps/
├── chatwoot/
│   ├── profile.yml       ← 11-field schema (MUST)
│   └── vars.yml
├── n8n/
├── twenty-crm/
├── openwebui/
├── metabase/
├── nocodb/
└── fastapi/              ← Community-provided example
```

`recommended_apps/` is archived. Every app under `apps/` MUST have a `profile.yml` with the 11-field schema.

---

## 3. Consequences

### Positive
- **Schema enforcement**: every app declares what it needs (secrets, backup, monitoring, architecture support)
- **Auditable catalog**: 7 apps with consistent metadata enables automated compliance scans
- **Open core clarity**: commercial apps vs community examples are clearly distinguished

### Negative
- Migration from `recommended_apps/` to `apps/` requires manual restructuring per app
- Stricter schema means more upfront work per app - but this is the point

---

## 4. Principle Reference

- **Principle 9 (Open core, not open-washing)**: The `apps/` catalog is fully OpenSource with a clear, enforceable contract. Commercial-only additions live outside this repo.

---

## Related Documents

- [../ARCHITECTURE.md](../ARCHITECTURE.md) - Application profile schema, app catalog (7 apps)
- [ADR-02.md](ADR-02.md) - YAML Profiles over DSL
