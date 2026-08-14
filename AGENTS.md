# developmi-stack

> **Public OpenSource** - Ansible hardening suite for Bare Metal Hosts or VPS

## Stack

- **Ansible** - Python 3.14+, uv, ansible-core 2.21.1 (pinned), ansible-lint 26.6.0
- **Testing** - Molecule (Docker driver v29.3.0+, Compose v5.3.1+)
- **Roles**: backup, backup-timers, security, L4_networking/caddy, user_hardening, and more
- **Target**: Debian 12, Ubuntu 22.04
- **Secrets**: SOPS + age (`inventory/group_vars/all/secrets.sops.yml`, `make sops-*`); the Tailscale trio stays vaulted until gate D4 (OPERATIONS_RUNBOOK §7.4)

## Commands

- Run: `make deploy`
- Lint: `make lint` (ansible-lint + yamllint)
- Test Full: `make test` (runs full Molecule suite)
- Test Layer: `make test-layer LAYER=X` (runs Molecule tests for a specific layer scenario)

## SDD Context

- **CodeGraph indexed**: enabled
- **Testing framework**: Molecule (Docker)
- **Strict TDD**: hybrid/gradual (transitioning phase)
- **Strict SDD (Spec Driven Development)**: enabled
- **Persistence**: Hybrid (Engram + .atl flat files)

## ⛔ CROSS-REFERENCE RULES (MANDATORY)

This is a **PUBLIC OpenSource repository**. It MUST remain self-contained.

### ALLOWED:

- ✅ Toolchain references (ansible-core versions, Python, uv)
- ✅ Public documentation URLs
- ✅ Ansible Galaxy collections and roles
- ✅ Generic infrastructure concepts (backup strategy, SSH hardening patterns)

### Violation = BLOCKING

## Pre-Resolved Context (auto-populated by orchestrator)

This section is populated by the orchestrator before launching sub-agents.

## SSOT Documentation Rule (from SDD complete-doc-gaps)

Every piece of knowledge MUST have a single, unambiguous, authoritative representation.

### Decision Ladder

1. **How-to guides** ("how do I do X?") → Extract procedures into dedicated docs. Keep genuinely new operational content.
2. **Reference** ("what is Y?") → Lives in `docs/architecture/ARCHITECTURE.md` as Single Source of Truth.
3. **Cross-references** → When a how-to doc needs context, include a ≤3 line summary + `[See ARCHITECTURE.md §N](../architecture/ARCHITECTURE.md#section-N)` link. NEVER copy full tables.
4. **Duplication** → Forbidden. If the same table appears in 3+ docs, strip it from all but ARCHITECTURE.md, replace with summary + link.

### Sources

- Diátaxis framework (tutorials/how-to/reference/explanation)
- GitLab SSOT hierarchy (generate > embed > cross-reference > never duplicate)
- EPPO (Every Page is Page One) - pages self-contained, link richly
- Kubernetes docs pattern - concepts self-contained, tasks summarize + link

### Enforcement

All new documentation PRs must follow this rule. Existing docs grandfathered - refactor opportunistically.

## Shared Docker Network (MUST)

- The shared external Docker network name MUST be defined via `shared_network_name` in `inventory/group_vars/all/main.yml`. NEVER hardcode the network name in roles, templates, or playbooks — reference `{{ shared_network_name }}` (or `observability_stack_network_name` where layer-specific).

## L3 Observability Stack Gate (MUST)

- When the L3 observability stack requires an external network that is missing, the role MUST present an interactive y/N prompt (message: "You need to run first the l4 stack to create ... for this layer. Continue anyway? [y/N]", 30s timeout). If declined, the play MUST stop gracefully with a message pointing to `make deploy-edge BACKEND=caddy TARGET=<host>`; it MUST NOT fail blindly.
- The assert "Assert external observability stack network exists" remains and only fires when the operator confirmed continuation.

## Phase Order Note (MUST)

- L4 (caddy) and L6 (portainer) create the shared Docker network; L3 (observability stack) consumes it. Deploy L4/L6 network creation before L3, or expect the interactive gate.

## App Compose Networks (MUST)

- Static app compose files under `apps/` reference the INTENTIONAL app-exposure bridge named `expose_network` (declared `external: true`). This is deliberate: static compose files cannot interpolate Ansible variables, so `shared_network_name` governs Ansible roles/templates/playbooks ONLY.
- Any Docker Compose app that must be reachable through Caddy (compose or Portainer) MUST join the SAME shared network (`{{ shared_network_name }}` / `public_net`) in addition to `expose_network`.
