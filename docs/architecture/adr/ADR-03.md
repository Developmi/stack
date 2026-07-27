---
title: ADR-03 - Four Layers of Variables
type: architecture
owner: maintainers
audience: all
version: v6.0.0
last-reviewed: 2026-06-28
status: accepted
principles: 7 (One operator, one runbook, 03:00)
project: developmi-stack
repo: github.com/Developmi/stack
---

## 1. Context

Ansible variable precedence in v5.5.0 used a three-layer model (group_vars → role defaults). With per-application profiles in v6.0.0, app-profile variables needed explicit precedence without duplicating configuration.

---

## 2. Decision

**Four-layer variable hierarchy with explicit precedence:**

```
1. app_<name>/vars.yml                 ← Per-application profile overrides
2. brain|muscle|local/main.yml        ← Per-group role config
3. all/main.yml                        ← Global safe defaults
4. roles/<role>/defaults/main.yml      ← Role-level fallbacks
```

Application profiles under `apps/` provide tested configuration references. The hierarchy ensures operators can override at any level without duplicating configuration.

---

## 3. Consequences

### Positive
- **Discoverable by path alone**: an operator at 03:00 knows exactly where to look - the file path IS the precedence
- **No config duplication**: per-group overrides sit in one directory per host class
- **Backward compatible**: existing `group_vars` and `role defaults` still work

### Negative
- Four layers can feel like "too many knobs" - mitigated by documented defaults at every level
- Operators must understand the hierarchy to avoid unintended overrides - mitigated by `ansible-playbook --check --diff`

---

## 4. Principle Reference

- **Principle 7 (One operator, one runbook, 03:00)**: Variable precedence is discoverable by file path alone - no searching, no guessing

---

## Related Documents

- [../ARCHITECTURE.md](../ARCHITECTURE.md) - Variable hierarchy section, role composition pattern
- [../GLOSSARY.md](../../GLOSSARY.md) - Variable hierarchy diagram
