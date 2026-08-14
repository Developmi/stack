---
title: Development Roadmap
type: project
owner: maintainers
audience: all
version: v6.0.0-dev
last-reviewed: 2026-07-23
status: active
project: developmi-stack
repo: github.com/Developmi/stack
---

# Developmi Stack - Development Roadmap

## Vision

Consolidate the Developmi Stack as a practical, transparent, and auditable security baseline for hybrid infrastructure, keeping a balance between operational simplicity and compliance rigor.

## Current Status (Verified from Git History)

### Released Versions

This project starts at v6.0.0. Prior development history (v1.0.0 - v5.5.0) is maintained in the previous repository: [Miguel-DevOps/nist-hardening-suite](https://github.com/Miguel-DevOps/nist-hardening-suite).

### What Is Working Well in Current Working Tree (v6.0.0-dev)

- NIST-focused architecture remains consistent (`AC-2`, `CM-7`, `SC-7`, `SI-4`, `AU-12`, `SC-28` audit scope).
- Security stack is cohesive: SSH hardening, UFW/fail2ban, CrowdSec, Tailscale, SOPS + age secrets workflow.
- Operational playbooks (`playbooks/l6/engine.yml`, `playbooks/l3/exporters.yml`, `playbooks/ops/nuke.yml`) enforce Tailscale-only transport via `tailscale_subnet` source-of-truth variable.
- Observability deployment is fully automated end-to-end via Ansible and SOPS-encrypted secrets.
- Recommended app catalog now provides secure, Zero Trust-aligned deployment configurations for Chatwoot, Metabase, n8n, OpenWebUI, Twenty CRM, and Uptime Kuma.
- **Caddy Node Isolation (v5.4.0)**: Per-node Caddyfile routing via `target_group ∩ group_names`. Three-layer variable model: SOPS (domains, certs), inventory inline vars (caddy_node_id, caddy_coraza_mode per host), group_vars (caddy_type, caddy_admin_enabled defaults).
- **Caddy WAF v3.2.1 Alignment (NEW)**: WAF upgraded from pinned v2 to Coraza v2.5.0 / OWASP CRS v4.28.0. WAF config (coraza.conf, CRS rules) now baked into container image at `/etc/caddy/`. Role no longer deploys host-side WAF config - just renders Caddyfile with correct snippet paths and validates per-service `waf_mode`. Healthcheck aligned to `pgrep caddy`. compose.yml.j2 streamlined (removed dead WAF bind mounts).
- **APT Lock Detection (v5.3.0)**: Pre-flight lock detection using `fuser`/`pgrep` with auto-kill for stale processes (>15min) and `apt_force_cleanup=true` flag for deadlocked processes. Enhanced in v6.0.0-dev with stale lock file cleanup (empty/abandoned locks) and `changed_when: false` for idempotent runs.
- **OpenWebUI Recommended Bundle (v5.5.0)**: Self-hosted LLM chat interface with Docker Compose deployment, GPU passthrough support, and Caddy-first exposure model.
- **Molecule Test Suite (NEW v6.0.0-dev)**: Full molecule converge + idempotence + verify coverage for 3 layers:

  | Layer | Converge | Idempotence | Verify | Known Docker Limitations |
  |---|---|---|---|---|
  | **L1_os_baseline** | ✅ 0 failures | ✅ changed=0 | ✅ 5 assertions | Hostname module can't persist `/etc/hostname` in containers (EBUSY) - uses `nodename` fact instead |
  | **L2_compliance** | ✅ 0 failures | ✅ changed=0 | ✅ stub | auditd can't start (kernel audit not namespaced), sysctl kernel.*/net.* read-only in containers, ubuntu2204 sysctl false positive on `kptr_restrict` |
  | **L4_networking** | ✅ 0 failures | ✅ changed=0 | ✅ 17 assertions | sysctl UDP buffers read-only on Debian12; GHCR auth unavailable for compose deploy; `python3-requests` missing in geerlingguy images |

  All tests run on both Debian 12 and Ubuntu 22.04 in Docker containers, with container kernel limitations documented via `ignore_errors` / `changed_when: false`.
- **Idempotence Fixes (NEW v6.0.0-dev)**:
  - **Hostname**: Changed `ansible_facts['hostname']` → `ansible_facts['nodename']` so kernel hostname change is detected correctly inside Docker.
  - **Container names**: Molecules container names use hyphens instead of underscores - `hostnamectl` rejects underscores (RFC violation), causing `nodename` mismatch.
  - **Log file touches**: `ansible.builtin.file state: touch` on Caddy access/coraza-audit logs now uses `modification_time: preserve` + `access_time: preserve` to prevent false `changed` on every run.
  - **Sysctl UDP buffers**: `changed_when: false` on the HTTP/3 buffer tuning task - the config file write is idempotent; only live `sysctl -w` always reports changed.
  - **Stale lock cleanup**: `apt_lock_preflight.yml` removes empty/abandoned lock files without reporting changed.
- **ADR Cleanup (NEW v6.0.0-dev)**: Renamed `ADR-9.md` → `ADR-09.md` (consistent zero-padded numbering). Fixed stale cross-reference in `ADR-07.md` (referenced wrong topic). Added `replaced_by: code` to `ADR-08.md` (superseded ADR without successor).
- Toolchain is pinned with `uv` and Python `3.14` (`ansible-core 2.21.1`, `ansible-lint 26.6.0`, `yamllint 1.38.0`).
- Container kernel limitations are documented per-task with inline comments - no silent failures.

### Testing Coverage by Layer

| Layer | Molecule Scenario | Converge | Idempotence | Verify | Notes |
|---|---|---|---|---|---|
| **L1_os_baseline** | ✅ `L1_os_baseline` | ✅ | ✅ | ✅ 5 assertions | Full coverage |
| **L2_compliance** | ✅ `L2_compliance` | ✅ | ✅ | ⏳ stub | Verify needs real assertions |
| **L3_observability** | ❌ Not created | - | - | - | Pending |
| **L4_networking** | ✅ `L4_networking` | ✅ | ✅ | ✅ 17 assertions | Full coverage |
| **L5_apps** | ❌ Not created | - | - | - | Go-to-market first |
| **L6_runtime** | ❌ Not created | - | - | - | Pending (backup engine) |

### Improvement Focus (Without Overstating Risk)

- Reduce imperative tasks (`shell`/`command`) where native Ansible modules can improve idempotence and auditability.
- Improve tag semantics in destructive workflows (`playbooks/ops/nuke.yml`) for safer operations.
- Keep documentation, CI evidence, and implemented behavior aligned release to release.
- Close molecule testing gaps: L3, L6, and L2 verify assertions.
- Maintain security parity and update cadence for the expanded recommended apps catalog.
- Remove remaining wrapper/mirror dependencies from developer tooling where official upstream OSS alternatives exist.

## Priority Plan by Urgency

## U0 - Critical (0-30 days)

### U0.1 Hardening and Operability Hotfixes

- Refactor highest-impact imperative tasks in `playbooks/ops/nuke.yml` and core security roles.
- Keep exceptions documented when commands are technically required.
- NIST: `CM-6`, `CM-7`, `SI-10`.
- OWASP: `A05`.

### U0.2 Safer Execution Contracts

- Replace custom `all` tag usage with explicit operational tags (`destroy`, `data`, `network`, `verify`).
- Align runbook examples with real task tags.
- NIST: `CM-3`, `SC-7`.
- OWASP: `A05`, `A09`.

### U0.3 Close Molecule Testing Gaps

- **L2 verify**: Replace stub with real assertions (SSH config, nftables rules, auditd config files, sysctl file presence, user/group existence, fail2ban config, sudoers fragments). Current: `"Implement SDD assertions here"`.
- **L3_observability**: Create molecule scenario for L3 layer. Even a basic converge-only test validates the role doesn't crash. Observability depends on external services (CrowdSec, exporters) - mock or skip runtime validation.
- **L6_runtime**: Create molecule scenario for backup role. Tests the backup user/group creation, directory structure, and config rendering without executing actual backups.
- NIST: `CA-7`, `AU-6`, `SI-4`.
- OWASP: `A08`.

### U0.4 `make graph` Inventory Visualization

- Add Makefile target: `make graph` → runs `ansible-inventory --graph --vars` and optionally pipes to `dot` for visual output.
- Aids navigation in a YAML-only project (CodeGraph doesn't parse Ansible/YAML).
- NIST: `CM-3` (documentation).

### U0.5 `make test` Scenario Coverage

- Update `make test` to discover and run all molecule scenarios, not a hardcoded subset.
- Use `molecule list` or `molecule test --all` pattern.
- Fail the Make target if any scenario fails.

### Planned Release Target

- `v6.0.0` - Molecule testing baseline, Caddy WAF v3.2.1 alignment, ADR cleanup, and U0 operational hardening.

## U1 - High (30-60 days)

### U1.1 Inventory-Agnostic Security Defaults

- Continue removing host-specific assumptions.
- Formalize least-privilege defaults for Docker/UFW/IPv6 paths.
- NIST: `AC-2`, `SC-7`, `CM-7`.
- OWASP: `A01`, `A05`.

### U1.2 Compliance Evidence as Release Artifact

- Publish machine-readable evidence of controls in CI.
- Maintain control-to-task traceability matrix.
- NIST: `CA-2`, `CA-7`, `AU-12`.
- OWASP: `A09`.

### U1.3 Documentation-to-Implementation Alignment

- Ensure observability and security claims match deployed behavior.
- NIST: `SI-4`, `AU-12`.
- OWASP: `A09`.

### U1.4 SSOT Documentation Sync

- When architectural changes occur (new layers, renamed roles, altered contracts), update all SSOT docs simultaneously: `docs/architecture/ARCHITECTURE.md`, `docs/project/REPOSITORY_STRUCTURE.md`, `docs/architecture/LAYER_BOUNDARIES.md`.
- Enforce: no PR merges with doc-only drift flagged in review.
- NIST: `CM-3` (configuration management), `CA-7` (continuous monitoring).

### U1.5 Lint Target Refinement

- Split `make lint` into `make lint-yamllint` and `make lint-ansible` for faster debug cycles.
- Document `ansible-lint --generate-ignore` workflow for baseline management when new rules are introduced.
- NIST: `CA-7`.

### Planned Release Target

- `v6.1.0` - Doc alignment, lint ergonomics, and compliance evidence.

## U2 - Strategic (60-120 days)

### U2.1 Additional Controls and Security Depth

- Expand practical enforcement around `AC-3`, `SI-3`, and `SC-28` optional automation paths.

### U2.2 Policy-as-Code Guardrails

- Introduce guardrails for module usage and documented exceptions.

### U2.3 Scale and Platform Readiness

- Improve multi-node resilience and integration templates.

### U2.4 Graphify Codebase Mapping (Evaluation)

- Evaluate `pip install graphifyy` for generating cross-reference documentation.
- **Known limitation**: Like CodeGraph, Graphify treats YAML as DOCS type only (no symbolic analysis). Useful for general project topology, not Ansible-specific navigation.
- If evaluation passes: integrate into CI as optional documentation artifact.
- If evaluation fails: document the limitation and rely on `make graph` + structured docs.

### U2.5 Dependency Automation

- Evaluate Dependabot or Renovate for automated updates of Ansible Galaxy collections and GitHub Actions.
- Target: automated PRs for collection version bumps with `ansible-lint` + molecule gating.
- NIST: `CM-3` (configuration management), `SI-2` (flaw remediation).

### Planned Release Target

- `v7.0.0` - Policy maturity, scale readiness, and automation infrastructure.

## Future Implementations (Backlog)

- Interactive setup/diagnostics wizard.
- Compliance reporting outputs (JSON/HTML/PDF).
- Image provenance/signing pipeline.
- Managed monitoring operation packs.
- **Completed**: secrets lifecycle migrated from the transitional `ansible-vault` wrapper to SOPS + age (`community.sops`, `secrets.sops.yml`, `make sops-*`). The wrapper remains enabled only for the Tailscale trio until expiry gate D4 (OPERATIONS_RUNBOOK §7.4).
- [ ] **Toolchain migration policy**: prefer official upstream projects with OSI-approved licenses only (MIT/Apache/GPL/BSD) and avoid BSL/non-open-core runtime dependencies in control-plane tooling.
- [ ] Replace wrapper hook `shellcheck-py/shellcheck-py` (MIT wrapper) with official `koalaman/shellcheck` binary workflow (GPL-3.0) managed in reproducible CI/WSL bootstrap.
- [ ] Replace `pre-commit/mirrors-prettier` (archived mirror) with official Prettier distribution from `prettier/prettier` (MIT) via pinned `pnpm` execution in hooks (policy: no npm).
- **Completed**: secrets lifecycle migrated from the transitional `ansible-vault` wrapper to the official and auditable key-management baseline (Mozilla SOPS + age/GPG), including key custody, rotation, and recovery controls. Remaining `ansible-vault` usage is limited to the Tailscale trio until gate D4 (OPERATIONS_RUNBOOK §7.4).
- [ ] Support for advanced host metrics (`network_mode: host`) with dedicated segmentation, compensating controls, and NIST/CIS exception documentation.
- [ ] Improve cAdvisor zero-trust coverage on hardened Docker hosts (`userns-remap`) with explicit metric-tier profiles (strict, balanced, full) and documented tradeoffs per profile.
- [ ] Add optional per-node cAdvisor enablement in inventory/group vars so hardened nodes can run Node Exporter only while keeping centralized scrape configuration clean.
- [ ] Rename `tailscale_subnet` to a VPN-agnostic overlay variable (e.g. `management_overlay_subnet`) to support non-Tailscale overlays (Headscale, WireGuard, etc.) without requiring changes across multiple playbooks. `tailscale_subnet` would remain as an alias for backwards compatibility. Relevant controls: NIST `CM-6`, `SC-7`.
- [ ] **Coraza full activation checklist**: After OWASP CRS tuning period on muscle nodes (DetectionOnly), documented activation procedure with per-service WAF bypass audit, false-positive triage runbook, and gradual rollout plan (muscle-1 → muscle-2 → all workers).
- [ ] **Dynamic inventory migration**: If Terraform, AWX, or an OCI dynamic inventory plugin is adopted, the per-host `caddy_node_id` and `caddy_coraza_mode` inline vars in `hosts.ini` must be migrated to the new inventory system. The three-layer variable model (SOPS/inventory/group_vars) must be preserved regardless of the inventory backend.
- [ ] **Cloudflare Origin CA cert expiry monitoring**: The `cloudflare-origin-pull-ca.pem` CA bundle has a finite validity period. Action items: (1) Check current expiry: `openssl x509 -in roles/L4_networking/caddy/files/cloudflare-origin-pull-ca.pem -noout -enddate`. (2) Add Ansible preflight task: assert cert is not expired and warns at 30-day threshold using `openssl x509 -checkend 2592000`. (3) Document rotation process: download updated CA from Cloudflare's published URL, replace file, re-deploy via `playbooks/l4/edge.yml --tags cloudflare,sc-8`, validate with `curl --cacert cloudflare-origin-pull-ca.pem` against a CF-origin service.
- [ ] **Caddy multi-node rendering tests (follow-up to v5.4.0)**: While L4 molecule validates the role on a single node, multi-node Caddyfile rendering (brain vs muscle routes), `target_group`/`coraza_mode`/`admin_enabled` preflight assertions, and cert isolation need integration-level testing (separate from molecule's container scope).

## v2 Strategic Alignment

The (archived - see ARCHITECTURE.md) contains the operational migration plan and production acceptance checklist.

These documents are authoritative and maintained separately from this roadmap. See (archived - see ARCHITECTURE.md) for the current → v2 documentation mapping.

Key v2 themes relevant to this roadmap:

- **Layer 0-3 platform model** - How current OS security layers (1-6) map to v2 platform layers
- **Runtime abstraction** - Compose today, Swarm/Nomad/K3s/Kubernetes in the future
- **Evidence engine** - Machine-generated compliance evidence (currently manual)
- **Solo operator sustainability** - Day N processes must be automatable

## Success Criteria

### For U0

- `uv run ansible-lint playbooks/site.yml playbooks/l6/engine.yml playbooks/l3/exporters.yml playbooks/ops/nuke.yml` runs with no critical regressions.
- `uv run yamllint -c .yamllint .` runs clean for targeted release scope.
- `uv run ansible-playbook --syntax-check playbooks/site.yml playbooks/l6/engine.yml playbooks/l3/exporters.yml playbooks/ops/nuke.yml` passes.
- All 3 existing molecule scenarios pass (L1, L2, L4) on both Debian 12 and Ubuntu 22.04.
- L2 verify has real assertions (no longer a stub).
- L3 and L6 molecule scenarios exist with at least converge passing.

### For U1/U2

- Each release includes updated control mapping and evidence artifacts.
- Documentation and code claims remain synchronized.
- `make graph` provides visual inventory navigation.

## Governance Notes

- Keep claims verifiable and evidence-based.
- Prefer declarative Ansible modules; document imperative exceptions.
- Preserve pragmatic tone: highlight strengths, track improvements transparently.

---

Maintained by Miguel Lozano - Cloud Infrastructure Engineer & FinOps Specialist
Last updated: 2026-07-23

## Related Documents

- (archived - see ARCHITECTURE.md) - v2 Layer 0-3 platform model and 3-5 year vision
- (archived - see ARCHITECTURE.md) - Operational migration plan
- (archived - see ARCHITECTURE.md) - Current → v2 documentation migration
- [CHANGELOG.md](../../CHANGELOG.md) - Release history
- [RELEASE.md](RELEASE.md) - Release process and quality gates
