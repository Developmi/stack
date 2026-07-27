---
title: Operating System Compatibility Matrix
type: operations
owner: maintainers
audience: operator
version: v6.0.0
last-reviewed: 2026-07-16
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

| OS / Distribution | Codename | Arch | Status | Verified Hosts | Provider |
| :--- | :--- | :--- | :--- | :--- | :--- |
| Ubuntu 22.04 | jammy | amd64 | ✅ Supported | brain & muscle | Hetzner |
| Ubuntu 22.04 | jammy | arm64 | ✅ Supported | brain & muscle | Oracle Ampere |
| Ubuntu 24.04 | noble | amd64 | ✅ Partially Supported | brain & muscle | Hetzner |
| Ubuntu 24.04 | noble | arm64 | ✅ Partially Supported | brain & muscle | Oracle Ampere |
| Debian 12 | bookworm | amd64 | ✅ Supported | brain & muscle | Hetzner |
| Debian 12 | bookworm | arm64 | ✅ Supported | brain & muscle | Oracle Ampere |
| Debian 13 | trixie | amd64 | 🔲 Planned | brain & muscle | Hetzner |
| Debian 13 | trixie | arm64 | 🔲 Planned | brain & muscle | Oracle Ampere |

**Status Legend:**
*   **✅ Supported:** Full playbook suite validated; idempotent and production-ready.
*   **✅ Partially Supported:** Core deployment path validated (`brain` and `muscle` roles tested successfully), but not every optional stack or edge scenario has completed validation.
*   **🔲 Planned:** Repository mappings and package sources exist, but full validation has not yet been completed.
*   **⛔ Blocked:** Known incompatibility prevents successful deployment.

### OS Attributes & EOL Target Dates

| OS | Init / Package | Default Firewall | Standard Support Ends | Extended / ESM Ends |
| :--- | :--- | :--- | :--- | :--- |
| **Debian 12** | systemd / apt | Not default on minimal | 2026-06-10 | 2028-06-30 (LTS) |
| **Ubuntu 22.04** | systemd / apt | UFW | April 2027 | March 2032 (ESM) |

*(Note: Both distributions use AppArmor as the default security module.)*

### Unsupported / Not Actively Tested

*   **Ubuntu 20.04 (focal):** End of standard support lifecycle and not aligned with current hardening targets.
*   **Debian 11 (bullseye):** Legacy compatibility may exist, but active validation and maintenance are not planned.

---

## 2. Architecture Support (AMD64 & ARM64)

Both major Linux server architectures (amd64 and arm64) are fully supported. The playbooks rely entirely on Ansible fact gathering for distribution, release codename, architecture, and kernel information, keeping the deployment flow architecture-agnostic. No architecture-specific playbook branching is required outside repository selection logic.

### App Profile Pre-Flight Validation (L5)
Every L5 application profile MUST declare a `supported_arch` field as an array of strings in its `profile.yml`. Valid values are `"amd64"` and `"arm64"`. 

Before deploying any app profile, the `apps.yml` playbook asserts that the target host's architecture is in the supported list. If the assertion fails, deployment stops before any container is started. This pre-flight check was formalized in ADR-09 because arm64-only images on amd64 hosts (and vice versa) produced silent or cryptic failures during deploys.

### Sourcing Multi-Arch Components
All deployed components support both architectures through their respective native distribution channels; no manual `docker buildx` invocation is required:
*   **Docker Images:** All application images use official multi-arch Docker images; Docker Engine automatically pulls the correct variant.
*   **Docker Engine & CrowdSec:** Use multi-arch APT repositories (`download.docker.com` and `packagecloud.io/crowdsec/crowdsec`).
*   **Caddy & Tailscale:** Provide official multi-arch binaries and APT packages (`pkgs.tailscale.com/stable/`).
*   **Ansible Roles:** All roles and Galaxy collections are architecture-agnostic.

---

## 3. Platform Hardening & Conventions

### Kernel Module Blacklist (NIST CM-7)
The following kernel modules are explicitly blacklisted on all supported OSes to comply with NIST CM-7:
*   `cramfs`
*   `freevxfs`
*   `hfs`
*   `hfsplus`
*   `squashfs`
*   `udf`

### User Convention
The `ansible_user` variable must always be defined per-host inside inventory files (e.g., `inventory/hosts.ini`) and never globally inside `group_vars`.
*   Debian root-provisioned nodes typically use `ansible_user=root`.
*   Ubuntu cloud images typically use `ansible_user=ubuntu`.

---

## 4. Known Platform Limitations

| OS / Environment | Issue | Impact | Mitigation |
| :--- | :--- | :--- | :--- |
| **Oracle ARM64** | Slow APT mirror sync | Initial bootstrap can take significantly longer | `apt_refresh.yml` implements retries and extended lock timeouts. |
| **Oracle ARM64** | Oracle-managed firewall | Ports may remain blocked despite UFW configuration | Security role flushes conflicting Oracle rules and applies deadman-switch logic. |
| **Debian Minimal** | Missing `rsyslog` | `fail2ban` cannot read authentication logs | Security role installs `rsyslog` automatically during bootstrap. |

---

## 5. Adding Support for a New OS

Follow this validation sequence when introducing support for a new Linux distribution or release.

1.  **Add Docker Version Mapping:** Update `group_vars/all/images.yml` with the specific package string from the official Docker repositories.
2.  **Validate CrowdSec Repository:** Verify the new codename is available upstream at `https://packagecloud.io/crowdsec/crowdsec/`.
3.  **Validate Tailscale Repository:** Verify the target release exists at `https://pkgs.tailscale.com/stable/<distro>/<release>`.
4.  **Verify WireGuard Kernel Support:** Run `modprobe wireguard`. Ubuntu systems may require `linux-modules-extra-{{ kernel }}`.
5.  **Validate Facts:** Ensure Ansible can detect the `distribution_release`. If not, install `python3-distro` and ensure `gather_facts: true`.
6.  **Run Validation Sequence:**
    ```bash
    make validate
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

* [OPERATIONS_RUNBOOK.md](OPERATIONS_RUNBOOK.md) - Definitive operations runbook (commands, deployment, troubleshooting)
* [ARCHITECTURE.md](../architecture/ARCHITECTURE.md) - Component Architecture and Profile Schema definitions
* [ADR-09](../architecture/adr/ADR-09.md) - AMD64/ARM64 mandatory compatibility