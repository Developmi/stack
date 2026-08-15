---
title: ADR-01 - Docker Compose - Engine & Manager separated
type: architecture
owner: maintainers
audience: all
version: v6.0.0
last-reviewed: 2026-06-28
status: accepted
principles: 1 (Simplicity), 6 (Boring)
project: developmi-stack
repo: github.com/Developmi/stack
---

## 1. Context

The Developmi Stack (v6.0.0) needs a container runtime strategy that works across heterogeneous environments - from local workstations to production brain nodes. In v5.5.0 (stack), Docker Compose and Portainer were implicitly coupled: deploying the runtime meant deploying both.

We needed a runtime model where Compose works without Portainer, and Portainer is an optional additive layer.

---

## 2. Decision

**Compose is the engine by default. Portainer is a manager, optional and independent.**

- Engine (obligatorio): Docker Compose - executes containers
- Manager (opcional): Portainer BE - UI + gestión sobre engine

**Regla explícita**: Compose NUNCA depende de Portainer. Un deploy con solo Compose y sin Portainer es 100% válido.

---

## 3. Consequences

### Positive

- Minimal deploy (local workstation, small VPS) requires zero management UI overhead
- Portainer is additive, not foundational - adding it is a toggle, not a re-architecture
- Future engines (Swarm, K3s) can enter as alternatives without rewriting manager logic

### Negative

- Two separate axes to maintain and test independently
- Operator must understand two deployment concepts (engine + optional manager)

---

## 4. Principle Reference

- **Principle 1 (Simplicity beats sophistication)**: Compose-only is the simplest deploy that works
- **Principle 6 (Boring technology beats novel technology)**: Docker Compose is battle-tested, boring, and predictable

---

## Related Documents

- [../ARCHITECTURE.md](../ARCHITECTURE.md) - 7-layer model, L6 runtime adapters
- [../LAYER_BOUNDARIES.md](../LAYER_BOUNDARIES.md) - L6 boundary contract
- [ADR-07.md](ADR-07.md) - Engine/Manager Decoupling (expands this decision)
