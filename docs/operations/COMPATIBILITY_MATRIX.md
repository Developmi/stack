---
title: Operating System Compatibility Matrix
type: operations
owner: maintainers
audience: operator
version: v6.0.0
last-reviewed: 2026-07-31
status: active
project: developmi-stack
repo: github.com/Developmi/stack
---

# Operating System Compatibility Matrix

This document defines the supported operating systems, architectures, common platform attributes, and procedures for introducing new platforms to the Developmi Stack.

---

## 1. Supported Operating Systems & Lifecycle

The matrix below reflects field-validated execution. Each platform has been deployed using the full playbook suite and verified in either production or lab environments.

### Tested Platforms & Status

| OS / Distribution | Codename | Arch  | Status                 | Verified Hosts | Provider      |
| :---------------- | :------- | :---- | :--------------------- | :------------- | :------------ |
| Ubuntu 22.04      | jammy    | amd64 | ✅ Supported           | brain & muscle | Hetzner       |
| Ubuntu 22.04      | jammy    | arm64 | ✅ Supported           | brain & muscle | Oracle Ampere |
| Ubuntu 24.04      | noble    | amd64 | ✅ Partially Supported | brain & muscle | Hetzner       |
| Ubuntu 24.04      | noble    | arm64 | ✅ Partially Supported | brain & muscle | Oracle Ampere |
| Debian 12         | bookworm | amd64 | ✅ Supported           | brain & muscle | Hetzner       |
| Debian 12         | bookworm | arm64 | ✅ Supported           | brain & muscle | Oracle Ampere |
| Debian 13         | trixie   | amd64 | 🔲 Planned             | brain & muscle | Hetzner       |
| Debian 13         | trixie   | arm64 | 🔲 Planned             | brain & muscle | Oracle Ampere |

**Status Legend:**

- **✅ Supported:** Full playbook suite validated; idempotent and production-ready.
- **✅ Partially Supported:** Core deployment path validated (`brain` and `muscle` roles tested successfully), but not every optional stack or edge scenario has completed validation.
- **🔲 Planned:** Repository mappings and package sources exist, but full validation has not yet been completed.
- **⛔ Blocked:** Known incompatibility prevents successful deployment.

### OS Attributes & EOL Target Dates

| OS               | Init / Package | Default Firewall       | Standard Support Ends | Extended / ESM Ends |
| :--------------- | :------------- | :--------------------- | :-------------------- | :------------------ |
| **Debian 12**    | systemd / apt  | Not default on minimal | 2026-06-10            | 2028-06-30 (LTS)    |
| **Ubuntu 22.04** | systemd / apt  | UFW                    | April 2027            | March 2032 (ESM)    |

_(Note: Both distributions use AppArmor as the default security module.)_

### Unsupported / Not Actively Tested

- **Ubuntu 20.04 (focal):** End of standard support lifecycle and not aligned with current hardening targets.
- **Debian 11 (bullseye):** Legacy compatibility may exist, but active validation and maintenance are not planned.

---

## 2. Architecture Support (AMD64 & ARM64)

Both major Linux server architectures (amd64 and arm64) are fully supported. The playbooks rely entirely on Ansible fact gathering for distribution, release codename, architecture, and kernel information, keeping the deployment flow architecture-agnostic. No architecture-specific playbook branching is required outside repository selection logic.

### App Profile Pre-Flight Validation (L5)

Every L5 application profile MUST declare a `supported_arch` field as an array of strings in its `profile.yml`. Valid values are `"amd64"` and `"arm64"`.

Before deploying any app profile, the `apps.yml` playbook asserts that the target host's architecture is in the supported list. If the assertion fails, deployment stops before any container is started. This pre-flight check was formalized in ADR-09 because arm64-only images on amd64 hosts (and vice versa) produced silent or cryptic failures during deploys.

### Sourcing Multi-Arch Components

All deployed components support both architectures through their respective native distribution channels; no manual `docker buildx` invocation is required:

- **Docker Images:** All application images use official multi-arch Docker images; Docker Engine automatically pulls the correct variant.
- **Docker Engine & CrowdSec:** Use multi-arch APT repositories (`download.docker.com` and `packagecloud.io/crowdsec/crowdsec`).
- **Caddy & Tailscale:** Provide official multi-arch binaries and APT packages (`pkgs.tailscale.com/stable/`).
- **Ansible Roles:** All roles and Galaxy collections are architecture-agnostic.

---

## 3. Platform Hardening & Conventions

### Kernel Module Blacklist (NIST CM-7)

The following kernel modules are explicitly blacklisted on all supported OSes to comply with NIST CM-7:

- `cramfs`
- `freevxfs`
- `hfs`
- `hfsplus`
- `squashfs`
- `udf`

### User Convention

The `ansible_user` variable must always be defined per-host inside inventory files (e.g., `inventory/hosts.ini`) and never globally inside `group_vars`.

- Debian root-provisioned nodes typically use `ansible_user=root`.
- Ubuntu cloud images typically use `ansible_user=ubuntu`.

---

## 4. Known Platform Limitations

| OS / Environment   | Issue                   | Impact                                             | Mitigation                                                                       |
| :----------------- | :---------------------- | :------------------------------------------------- | :------------------------------------------------------------------------------- |
| **Oracle ARM64**   | Slow APT mirror sync    | Initial bootstrap can take significantly longer    | `apt_refresh.yml` implements retries and extended lock timeouts.                 |
| **Oracle ARM64**   | Oracle-managed firewall | Ports may remain blocked despite UFW configuration | Security role flushes conflicting Oracle rules and applies deadman-switch logic. |
| **Debian Minimal** | Missing `rsyslog`       | `fail2ban` cannot read authentication logs         | Security role installs `rsyslog` automatically during bootstrap.                 |

---

## 5. Shared Engine Compatibility (L5 Apps)

Shared engine lines must be pinned identically across all consumers (exact pins: [VERSION_PINS.md](VERSION_PINS.md)):

| Shared line    | Pin                      | Consumers                                                              | Notes                                                                                                                           |
| :------------- | :----------------------- | :--------------------------------------------------------------------- | :------------------------------------------------------------------------------------------------------------------------------ |
| **PostgreSQL** | `17.10` / `17.10-alpine` | chatwoot, n8n, metabase, twenty-crm, nocodb, postgresql, openwebui (7) | pgvector must match the PG major; openwebui migrated 16→17                                                                      |
| **Valkey**     | `9.1.1`                  | chatwoot, n8n, twenty-crm, openwebui (4)                               | 9.x loads 8.x RDB (cache-only, in-place boot verified at apply)                                                                 |
| **ClickHouse** | `26.3.17.56`             | clickhouse (native), openlit (embedded service, decision D9) (2)       | 26.3 IS the LTS branch (no `-lts` suffix); openlit's embedded instance requires an apply-time smoke test, fallback pin `24.4.1` |
| **pgvector**   | `0.8.6-pg17`             | chatwoot DB (1)                                                        | Must stay on the postgres 17 line                                                                                               |

### Upgrade Paths Across Major / Data-Format Boundaries

Every pin change crossing a major or data-format boundary documents its migration impact here (APP-VERSION-PINNING-004):

| App                                       | Path                                                              | Required steps                                                                                                                                                                            |
| :---------------------------------------- | :---------------------------------------------------------------- | :---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **twenty-crm** 1.x→2.x                    | 1.19 → 1.20 → 1.21 → 1.22 → 1.23 → 2.26.0                         | Incremental only - direct jumps hit migration bug #19863. `pg_dump` before EVERY step. First v2.26 boot requires `ENCRYPTION_KEY` (at-rest envelope). arm64 manifest-verified in v2.26.0. |
| **openwebui** postgres 16→17              | `pg_dump` → restore into `postgres:17.10-alpine` → launch v0.11.0 | Pre-flight dump before apply; verify data after restore.                                                                                                                                  |
| **clickhouse** 24.4→26.3                  | Pre-upgrade backup → upgrade → verify                             | Pre-upgrade backup REQUIRED (`clickhouse-backup create` or `ALTER TABLE ... FREEZE`); verify row counts post-upgrade. 26.3 enables async inserts by default.                              |
| **openlit** embedded clickhouse 24.4→26.3 | Pin `26.3.17.56` + apply-time smoke test                          | Smoke: boot, dashboard :3001, send one test trace visible in UI. Fallback: pin embedded clickhouse to `24.4.1`. 26.3 enables async inserts by default (no config file - env-only setup).  |
| **valkey** 8→9                            | In-place boot (9.x loads 8.x RDB)                                 | On failure: delete cache volume and rebuild (cache-only, safe).                                                                                                                           |

---

## 6. Adding Support for a New OS

Follow this validation sequence when introducing support for a new Linux distribution or release.

1.  **Add Docker Version Mapping:** Update `group_vars/all/images.yml` with the specific package string from the official Docker repositories.
2.  **Validate CrowdSec Repository:** Verify the new codename is available upstream at `https://packagecloud.io/crowdsec/crowdsec/`.
3.  **Validate Tailscale Repository:** Verify the target release exists at `https://pkgs.tailscale.com/stable/<distro>/<release>`.
4.  **Verify WireGuard Kernel Support:** Run `modprobe wireguard`. Ubuntu systems may require `linux-modules-extra-{{ kernel }}`.
5.  **Validate Facts:** Ensure Ansible can detect the `distribution_release`. If not, install `python3-distro` and ensure `gather_facts: true`.
6.  **Run Validation Sequence:**
    ```bash
    make check-toolchain
    make lint
    make dry-run PLAYBOOK=playbooks/site.yml
    make deploy-tags PLAYBOOK=playbooks/site.yml ANSIBLE_TAGS='base,system,packages'
    make deploy # Full deployment
    make deploy # Idempotency validation (should report changed=0)
    ```
7.  **Update Matrix:** Move the OS entry to `✅ Supported` in this document and commit alongside the code.

### Production Architecture Verification Gate

As part of the production acceptance gate, you must verify all apps declare `supported_arch`:

```bash
# Count app profiles
find apps/ -name profile.yml | wc -l

# Count profiles declaring supported_arch
grep -l "supported_arch" apps/*/profile.yml | wc -l

```

Both counts must match; a missing field is a blocking failure for production release.

---

## Related Documents

- [OPERATIONS_RUNBOOK.md](OPERATIONS_RUNBOOK.md) - Definitive operations runbook (commands, deployment, troubleshooting)
- [VERSION_PINS.md](VERSION_PINS.md) - Exact image pins (SSOT) for apps and shared engines
- [ARCHITECTURE.md](../architecture/ARCHITECTURE.md) - Component Architecture and Profile Schema definitions
- [ADR-09](../architecture/adr/ADR-09.md) - AMD64/ARM64 mandatory compatibility
