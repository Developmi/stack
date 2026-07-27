---
title: ADR-07 - Engine/Manager Decoupling
type: architecture
owner: maintainers
audience: all
version: v6.0.0
last-reviewed: 2026-06-28
status: accepted
principles: 1 (Simplicity), 8 (Boundaries)
project: developmi-stack
repo: github.com/Developmi/stack
replaces: ADR-01 (superseded - ADR-07 expands and formalizes the same decision)
---

## 1. Context

The Developmi Stack (v6.0.0) runs containerized workloads across heterogeneous environments - local workstations, single-server brain nodes, and multi-node clusters. In v5.5.0 (stack), Docker Compose and Portainer were implicitly coupled: deploying the runtime meant deploying both together, and removing Portainer was not a documented path.

We needed a runtime model where:
- **Compose works without Portainer**. A minimal deploy should require zero management UI overhead.
- **Portainer is additive, not foundational**. Adding a manager should be a toggle - not a re-architecture.
- **Future engines don't fork the platform**. Swarm and K3s must enter as alternative engines without rewriting manager logic, app profiles, or deploy playbooks.

---

## 2. Decision

### Two-Axis Model

Engine and Manager are **completely independent axes** of the L6 Runtime Adapter layer:

| Axis | Cardinality | Now (v6.0.0) | Future |
|------|-------------|--------------|--------|
| **Engine** | Mandatory (exactly one) | Docker Compose | Swarm, K3s |
| **Manager** | Optional (zero or one) | None / Portainer BE | Rancher, Komodo, Dockge |

### Engine (mandatory)

Docker Compose is the default and primary engine. The engine role (`roles/L6_runtime/general/`) installs Docker, configures daemon settings, and exposes the Docker socket for manager consumption - but **never requires** a manager to function.

### Manager (optional)

Portainer BE is the first optional manager. It deploys as a standalone stack via `roles/L6_runtime/portainer/`. The manager:
- Connects to the Docker socket on the same host (local agent mode)
- Manages stacks via the Compose API, not via proprietary orchestration
- **Does not own** the engine lifecycle - stopping Portainer leaves all Compose stacks running

### Critical Rule

> **Compose NUNCA depende de Portainer. Un deploy sin Portainer es 100% válido.**

- `roles/docker/` has zero references to `roles/stack_portainer/`
- `playbooks/l6/engine.yml` deploys engine alone; `playbooks/l6/portainer.yml` adds manager
- App deploy (`apps.yml`) resolves via engine alone - manager is never in the hot path

---

## 3. Consequences

### Positive
- Minimal footprint deploy: Compose-only for local workstations and small VPS
- Manager as toggle: add Portainer later without redeploying anything
- Engine-agnostic platform: future Swarm/K3s support changes one adapter
- Principle 1 (Simplicity): One deploy path always works - Compose
- Principle 8 (Boundaries): L6 internal boundary - Engine knows nothing about Manager

### Negative
- No unified dashboard by default (add Portainer post-deploy with one playbook run)
- Two deploy paths to document (`playbooks/l6/engine.yml` vs `playbooks/l6/portainer.yml`)

---

## 4. Principle Reference

- **Principle 1 (Simplicity beats sophistication)**: Compose-only is the simplest deploy that works
- **Principle 8 (Layers don't reach across boundaries)**: Engine never imports Manager

---

## Related Documents

- [../ARCHITECTURE.md](../ARCHITECTURE.md) - L6 runtime adapters section
- [ADR-01.md](ADR-01.md) - Docker Compose - Engine y Manager separados (origin of this decision)
- [ADR-09.md](ADR-09.md) - AMD64/ARM64 Mandatory Compatibility (complements architecture portability)
