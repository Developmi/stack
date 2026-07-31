---
title: ADR-02 - YAML Profiles over DSL
type: architecture
owner: maintainers
audience: all
version: v6.0.0
last-reviewed: 2026-07-31
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

**Application profiles use YAML with a reduced 6-field schema.**

```yaml
# apps/<name>/profile.yml
supported_arch: [amd64, arm64] # MUST - verified per image manifest
depends_on: [] # SHOULD
monitoring: {
    enabled: true,
    health_endpoint: "/healthz",
    health_port: 5678,
    scrape_port: 5678,
  } # MUST
compliance_tags: [
    cis-docker:4.1,
    cis-docker:5.1,
    cis-os:5.1.2,
    soc2:cc6.1,
    iso27001:a.8.2.3,
  ] # MUST
dr_tier: tier1 # MUST - tier1 | tier2 | tier3
backup: {
    method: pg_dump,
    schedule: "*-*-* 00/4:00:00",
    retention,
    verification,
    db_type,
    db_name,
  } # MUST
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

## 4. Status Update (2026-07-31)

The original 11-field schema (with `compose_file`/`vars_file`/`secrets_file`
path fields, `name`, `version`, `target_group`) was **never enforced** and
referenced files that do not exist (`compose.yml.j2`, `vars.yml`, `secrets.yml`).
Per change `apps-stack-standardization` (decision D1/D6):

- Schema reduced to the **6 fields** above; `name`/`version`/`target_group`
  dropped - the app name is derived from the directory path, the version is
  the compose image pin (`${APP_IMAGE:-org/image:tag}`), SSOT in
  `docs/operations/VERSION_PINS.md`.
- `dr_tier` enum replaced `critical`/`standard`/`best-effort` with
  `tier1`/`tier2`/`tier3`.
- `compliance_tags` use the uniform vocabulary (CIS Docker/OS + SOC 2 + ISO
  27001; DB/cache apps add three controls).
- The authoritative schema reference is [ARCHITECTURE.md §8](../ARCHITECTURE.md#8-application-profile-schema-reduced-6-field-specification).

---

## 5. Principle Reference

- **Principle 3 (Automation beats documentation)**: Profile == machine-readable intent - no manual translation step
- **Principle 5 (Evidence beats assertion)**: Profile declares compliance tags, making evidence traceable to the profile declaration

---

## Related Documents

- [../ARCHITECTURE.md](../ARCHITECTURE.md) - reduced 6-field profile schema, app catalog
- [ADR-04.md](ADR-04.md) - Abstraction by Convention, Not Framework
