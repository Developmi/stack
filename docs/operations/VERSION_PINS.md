---
title: Version Pinning Strategy
type: operations
owner: maintainers
audience: operator
version: v6.0.0
last-reviewed: 2026-07-16
status: active
project: developmi-stack
repo: github.com/Developmi/stack
---

# Version Pinning Strategy

Every component consumed by the platform - from the Python runtime down to
individual container images - must have an explicit, auditable version pin.
This guarantees reproducibility across environments, eliminates "works on my
machine" failures, and aligns with the **"Boring Technology"** principle.

---

## Pinning Table

| #   | Component                        | Pinned Version                                                                                         | Rationale                                                                                                                                                                                                                                     | Upgrade Process                                                                                                                                                                                                                                        |
| --- | -------------------------------- | ------------------------------------------------------------------------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| 1   | **Python**                       | `>=3.14` (floor)                                                                                       | Minimum version required for `ansible-core 2.21.1` compatibility. The floor is declared in `pyproject.toml` (`requires-python`). Actual runtime version managed by the operator via `uv` or system Python.                                    | Bump floor after ansible-core bumps its own requirement. Verify all dependencies (`ansible-lint`, `yamllint`, `jinja2`) are compatible with the new floor before committing.                                                                           |
| 2   | **ansible-core**                 | `==2.21.1`                                                                                             | The execution engine. Pinning the exact minor avoids unexpected module deprecations or behaviour changes. Defined in `pyproject.toml` dependencies.                                                                                           | Review the [ansible-core porting guide](https://docs.ansible.com/ansible-core/devel/porting_guides/porting_guides.html) for the target version. Run `make lint` + `make dry-run` across all playbooks. Verify idempotency (`changed=0` on second run). |
| 3   | **ansible-lint**                 | `==26.6.0`                                                                                             | Ensures playbooks follow the same rule set on every machine. Prevents CI-vs-local drift. Defined in `pyproject.toml`. The version is aligned with the ansible-core pin - upgrading one typically requires the other.                          | Check [ansible-lint changelog](https://github.com/ansible/ansible-lint/releases) for new rules. Run `make lint` and fix violations before committing the bump.                                                                                         |
| 4   | **Docker Engine**                | Per-OS pins in `inventory/group_vars/all/images.yml`                                                             | Reproducible cluster behaviour depends on identical Engine versions across nodes. Pins are per-distribution-codename to match Docker's packaging convention (e.g., `5:29.5.3-1~debian.12~bookworm` for Debian 12).                            | Test on a single node first: `make deploy-tags PLAYBOOK=playbooks/l6/engine.yml ANSIBLE_TAGS='docker' --limit=<test-node>`. Verify `docker version` matches expected output. Roll back by reverting the pin in `images.yml` and re-running the playbook.  |
| 5   | **Ansible Galaxy Collections**   | Pinned in `requirements.yml`                                                                           | Three collections are required: `community.general` (13.0.1), `ansible.posix` (2.2.0), `community.docker` (5.2.1). `community.sops` has been removed. Pins prevent Galaxy from pulling breaking major versions on a fresh `ansible-galaxy install`. | Run `make install-collections` in a clean environment. Execute `make dry-run` for all playbooks. Check each collection's changelog for module deprecations.                                                                                           |
| 6   | **Caddy WAF (reverse proxy)**    | `ghcr.io/developmi/caddy-waf:v3.2.1`                                                               | The ingress layer is the first line of defence. Pinning the WAF image ensures consistent Coraza rule sets and TLS handling across deployments. Defined in `inventory/group_vars/all/images.yml`.                                                        | Build and push the new image tag. Verify WAF rule set compatibility (Coraza version must match). Run `make deploy-tags PLAYBOOK=playbooks/l4/edge.yml ANSIBLE_TAGS='l4-networking'`. Smoke-test a health endpoint through the proxy.                    |
| 7   | **Portainer (optional manager)** | Server `2.39.3`, Agent `2.39.3`                                                                        | Manager and agent MUST stay at the same version. Portainer is optional (ADR-07) but when deployed, version drift between server and agent breaks edge-agent communication. Defined in `inventory/group_vars/all/images.yml`.                            | Review [Portainer release notes](https://docs.portainer.io/v/ce-2.39/release-notes). Upgrade agent first, then server. Verify edge-agent connectivity in the Portainer UI before considering the upgrade complete.                                     |
| 8   | **Observability Stack**          | VictoriaMetrics `v1.148.0`, Loki `3.6.13`, Grafana `13.1.1`, Node Exporter `v1.12.1`, cAdvisor `v0.60.5` | Monitoring is a contractual interface (L3). Version drift between exporters, databases, and dashboards causes silent metric gaps. All images pinned in `inventory/group_vars/all/images.yml`.                                                           | Upgrade in this order: exporters → VictoriaMetrics/Loki → Grafana. After each step, verify dashboards render and alert rules still fire. Roll back by reverting the tag and re-deploying the monitoring playbook.                                      |
| 9   | **Application Images**           | Per-app in `apps/<name>/vars.yml`                                                                | Chatwoot (`v4.12.1`), n8n (`2.20.6`), Twenty CRM (`0.40.7`), Open WebUI (`v0.9.5`), Metabase (`v0.53.7`), Uptime Kuma (`2.0.2`). App images are the most volatile - upstream releases may break DB migrations or change env-var contracts. | Check the upstream changelog for breaking changes (especially DB migration notes). Test on a staging environment. Run the app's health endpoint after deploy. Keep the previous tag in a comment for one release cycle as quick rollback.              |
| 10  | **Sidecar Images**               | Valkey `9.0.3`, PostgreSQL `17` / `17-alpine`, pgvector `pg17`                                         | Sidecars must stay compatible with their app's expected version. A Valkey major bump can break chatwoot/n8n/twenty cache connections. pgvector must match the PostgreSQL major.                                                               | Upgrade sidecar BEFORE the app that depends on it (app may not support the new sidecar version yet). Verify DB connection, cache connectivity, and data persistence after upgrade.                                                                     |

---

## Upgrade Process

### Pre-Upgrade Checklist

1. **Read the changelog** of the target version. Look for breaking changes, deprecated
   features, and required migration steps.
2. **Check compatibility** between the component and its dependents:
   - `ansible-core` ↔ `ansible-lint` (must stay aligned)
   - `Portainer server` ↔ `Portainer agent` (identical version required)
   - App images ↔ sidecar images (DB, cache)
3. **Pin a specific test node** for the upgrade. Never upgrade all nodes simultaneously.
4. **Back up** before upgrading any stateful component (database sidecars, Portainer).

### Upgrade Steps

```bash
# 1. Create a branch for the version bump
git checkout -b bump/<component>-<old>→<new>

# 2. Update the pin in the relevant file
#    - pyproject.toml for Python packages
#    - requirements.yml for Galaxy collections
#    - inventory/group_vars/all/images.yml for infrastructure images
#    - apps/<name>/vars.yml for application image tags

# 3. Install/test the new version
make lint                    # ansible-lint must pass with new rules
make dry-run PLAYBOOK=playbooks/site.yml

# 4. Deploy to a single test node
make deploy-tags PLAYBOOK=playbooks/l6/engine.yml ANSIBLE_TAGS='<tag>' --limit=<test-node>

# 5. Verify
#    - Check service health endpoints
#    - Verify idempotency (second run → changed=0)
#    - Run smoke tests (login, data access, backups)

# 6. If successful, deploy to remaining nodes
make deploy

# 7. Keep old version reference for one cycle
#    - Add a comment line with the previous pin: # vX.Y.Z (last known good)
```

### Rollback

```bash
# Revert the pin to the previous known-good version
git revert <bump-commit>

# Re-deploy the playbook targeting the affected layer
make deploy-tags PLAYBOOK=<playbook> ANSIBLE_TAGS='<tag>'

# Verify services are healthy again
```

### What to Check After Every Upgrade

| Check           | Command / Method                                      | Expected             |
| --------------- | ----------------------------------------------------- | -------------------- |
| Idempotency     | `make deploy` (second run)                            | `changed=0`          |
| Lint            | `make lint`                                           | Zero errors          |
| App health      | `curl -s https://<domain>/health`                     | HTTP 200             |
| DB connectivity | App logs, admin panel login                           | Working              |
| Backups         | `make deploy-tags ANSIBLE_TAGS='backup'`              | No errors            |
| Monitoring      | Grafana dashboards load, alerts not firing spuriously | Dashboards populated |

---

## Where Pins Live

| Component Group                                                    | Source of Truth                                    |
| ------------------------------------------------------------------ | -------------------------------------------------- |
| Python packages (`ansible-core`, `ansible-lint`, `jinja2`, etc.)   | `pyproject.toml` → `dependencies`                  |
| Python floor version                                               | `pyproject.toml` → `requires-python`               |
| Ansible Galaxy collections                                         | `requirements.yml`                                 |
| Infrastructure images (Caddy, Portainer, observability, Tailscale) | `inventory/group_vars/all/images.yml`                        |
| Application images                                                 | `apps/<name>/vars.yml`                            |
| Sidecar images (Valkey, PostgreSQL, pgvector)                      | `apps/<name>/vars.yml`                             |
| Docker Engine packages                                             | `inventory/group_vars/all/images.yml` → `docker_version_map` |

---

## Related Documents

- [COMPATIBILITY.md](COMPATIBILITY_MATRIX.md) - OS and architecture compatibility matrix.
- [OPERATIONS_RUNBOOK.md](OPERATIONS_RUNBOOK.md) - Operational command reference.
- Architecture: [ADR-07 (Engine/Manager Decoupling)](../architecture/adr/ADR-07.md)