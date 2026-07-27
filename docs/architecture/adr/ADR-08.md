---
title: ADR-08 - Backup Roles Consolidation
type: architecture
owner: maintainers
audience: all
version: v6.0.0
last-reviewed: 2024-11-15 (original) / 2026-07-07 (superseded)
status: superseded
replaced_by: code (consolidated into roles/L6_runtime/backup/ with backup_role_source selection)
principles: 1 (Simplicity), 8 (Boundaries)
project: developmi-stack
repo: github.com/Developmi/stack
---

## Context

Originally, backup responsibilities were split across three Ansible roles:

- `roles/backup/` - handled app-data backups (L5)
- `roles/stack_backup/` - handled runtime-state backups (L6)
- `roles/backup-timers/` - handled cron-based backup scheduling

This separation was motivated by layer purity: L5 (apps) should not know about L6 (runtime) internals.

## Decision (Superseded)

The original decision to separate backup roles was superseded by the layer-refactor. All three roles are now consolidated into a single role at `roles/L6_runtime/backup/`, with source selection controlled by the `backup_role_source` variable at the playbook level.

## Why Consolidated

- The separation added maintenance burden without proportional benefit
- Three roles shared overlapping logic (borg/restic invocation, retention policies, cron scheduling)
- The layer purity concern is now handled at the VARIABLE level (`backup_role_source`), not the role level
- Single source of truth for backup configuration, easier to audit and debug

## Consequences

- **Positive**: Simpler maintenance, single set of defaults, unified testing surface
- **Negative**: Role is larger (~40 files). `backup_role_source` must be set correctly per playbook invocation
- **Migration**: Playbooks `backup-l5.yml` and `backup-timers.yml` both reference `roles/L6_runtime/backup/` with different `backup_role_source` values

---

## Related Documents

- [../ARCHITECTURE.md](../ARCHITECTURE.md) - 7-layer model, L5/L6 responsibilities
- [ADR-01.md](ADR-01.md) - Engine/Manager separation (origin)
- [ADR-07.md](ADR-07.md) - Engine/Manager Decoupling (complements this ADR)
