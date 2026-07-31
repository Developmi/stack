---
title: ADR-06 - apps/ over recommended_apps/
type: architecture
owner: maintainers
audience: all
version: v6.0.0
last-reviewed: 2026-07-31
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
│   ├── docker-compose.yml   ← shared compose pattern (x-<app>-env anchors, pins)
│   ├── .env.example         ← namespaced <APP>_ variables (changeme secrets)
│   └── profile.yml          ← reduced 6-field schema (MUST)
├── n8n/
├── twenty-crm/
├── openwebui/
├── metabase/
├── nocodb/
├── clickhouse/
├── mariadb/
├── openlit/
├── postgresql/
├── uptime-kuma/
└── fastapi/                 ← Community-provided example (legacy layout, excluded)
```

`recommended_apps/` is archived. Every standardized app under `apps/` MUST
have a `profile.yml` with the reduced 6-field schema (see
[ARCHITECTURE.md §8](../ARCHITECTURE.md#8-application-profile-schema-reduced-6-field-specification)).

---

## 3. Consequences

### Positive

- **Schema enforcement**: every app declares what it needs (backup themes, monitoring, compliance tags, DR tier, architecture support)
- **Auditable catalog**: 11 standardized apps + fastapi example with consistent metadata enables automated compliance scans
- **Open core clarity**: commercial apps vs community examples are clearly distinguished

### Negative

- Migration from `recommended_apps/` to `apps/` requires manual restructuring per app
- Stricter schema means more upfront work per app - but this is the point

---

## 4. Status Update (2026-07-31)

Per change `apps-stack-standardization` (decisions D2/D5/D6/D7):

- The per-app layout was standardized to \*\*`docker-compose.yml` + `.env.example`
  - `profile.yml`\*\* (+ `assets/` only when compose bind-mounts files); the
    legacy `vars.yml`/`compose.yml.j2`/`secrets.yml` files are gone.
- The profile schema was reduced from 11 to **6 fields**; `name`/`version`/
  `target_group` dropped - app name derives from the directory path, version
  from the compose image pin (SSOT: `docs/operations/VERSION_PINS.md`).
- The compose pattern standard (anchors, namespaced vars, exact pins,
  hardening) is documented in [ARCHITECTURE.md §8](../ARCHITECTURE.md#8-application-profile-schema-reduced-6-field-specification) and
  [LAYER_BOUNDARIES.md L5](../LAYER_BOUNDARIES.md).
- The catalog (11 apps + fastapi) lives in [ARCHITECTURE.md §9](../ARCHITECTURE.md#9-application-catalog).

---

## 5. Principle Reference

- **Principle 9 (Open core, not open-washing)**: The `apps/` catalog is fully OpenSource with a clear, enforceable contract. Commercial-only additions live outside this repo.

---

## Related Documents

- [../ARCHITECTURE.md](../ARCHITECTURE.md) - Application profile schema, app catalog (11 apps + fastapi)
- [ADR-02.md](ADR-02.md) - YAML Profiles over DSL
