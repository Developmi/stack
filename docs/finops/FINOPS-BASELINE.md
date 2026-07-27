---
title: FinOps Baseline
type: Baseline
owner: maintainers
audience: all
version: v6.0.0
last-reviewed: 2026-07-05
status: active
project: developmi-stack
repo: github.com/Developmi/stack
---

# FinOps Baseline

## Overview

This document tracks cost estimation and financial governance across the Developmi Stack.
It establishes a per-node cost baseline for OpenSource-scoped layers (L1–L6), documents the
boundary with private cloud provisioning costs (L0), and references the Nuntu field case study
for aggregate OpEx comparison.

**Scope rule:** L0 cloud provisioning costs are private and explicitly excluded from this
OpenSource repository. L1–L6 compute resource costs are estimated here using generic
VPS/bare-metal equivalent tiers.

---

## L0 vs L1–L6 Cost Separation

> Source: [ARCHITECTURE.md](../architecture/ARCHITECTURE.md) §5 - 7-Layer Architecture Model

| Layer | Name             | Cost Responsibility                            | Scope        |
|-------|------------------|------------------------------------------------|--------------|
| L0    | Commercial Infra | Cloud provisioning (OpenTofu), compute instances, block storage, DNS zones, provider-specific security groups. | **Private - out of scope** |
| L1    | OS Baseline      | Package manager, update/hold policies, auto-upgrade checker, architecture detection. | OpenSource |
| L2    | Compliance       | SSH hardening, firewall (ufw/nftables), fail2ban, kernel hardening, CrowdSec, NIST/CIS evidence collection. | OpenSource |
| L3    | Observability    | VictoriaMetrics, Grafana, Loki, scrape targets, health endpoints, alerting rules. | OpenSource |
| L4    | Networking/Edge  | Caddy reverse proxy, TLS certificate management, WAF profiles, Caddy logging. | OpenSource |
| L5    | App Profiles     | YAML profile schema, compose templates, app vars/secrets, backup schedules and retention.                       | OpenSource |
| L6    | Runtime Adapters | Docker Engine, compose rendering/deploy, Portainer BE (optional), runtime-state backups. | OpenSource |

**Trust boundary:** L1–L6 are OpenSource. L0 is private/commercial, never referenced with
implementation details in this repository. Cost estimates for L1–L6 use VPS-equivalent
tiers only - no cloud provider pricing, contract rates, or region-specific SKUs are documented.

---

## Per-Node Cost Baseline

> Source: [ARCHITECTURE.md](../architecture/ARCHITECTURE.md) §7 - Host Classes (brain/muscle/local)

Estimated monthly cost ranges based on generic VPS/bare-metal equivalent tiers. Actual costs
depend on provider, region, committed use, and workload density - these are planning estimates,
not quotes.

| Node Type | Role                | Resources (guideline)               | Est. Monthly Cost (USD) | Notes |
|-----------|---------------------|--------------------------------------|-------------------------|-------|
| **brain** | Management node     | 4 vCPU, 8 GB RAM, 80 GB SSD         | $20–$40                | Moderate CPU. Runs Portainer, Grafana, ingress, backups, evidence collection. Persistent storage required. |
| **muscle**| Compute worker      | 8 vCPU, 16 GB RAM, 160 GB SSD       | $40–$80                | Higher CPU/RAM for application workloads. Runs Chatwoot, n8n, Twenty CRM, Metabase, etc. Persistent storage for app data. |
| **local** | Operator workstation| Variable (1–8 vCPU, 4–16 GB RAM)    | $0 (bring-your-own)    | Workstation-grade hardening. No observability, no backups. Tailscale manual auth. Operator-provided hardware. |

**Cost drivers per layer** (additive on top of base node):

| Layer | What adds cost                                                              | Cost driver type  |
|-------|-----------------------------------------------------------------------------|--------------------|
| L1    | None - package manager and update policies are CPU-idle background tasks.  | Negligible         |
| L2    | CrowdSec (lightweight agent). fail2ban (minimum CPU).                      | Negligible         |
| L3    | VictoriaMetrics (TSDB storage), Grafana (dashboards), Loki (log storage).  | Storage + RAM      |
| L4    | Caddy (lightweight, Go-compiled). WAF profiles (minimal overhead).         | Negligible         |
| L5    | App containers (PostgreSQL, Redis, app runtimes). Backup storage (retention). | CPU + RAM + Storage |
| L6    | Docker Engine (runtime overhead). Portainer BE (optional, ~256 MB RAM).    | Light              |

**Scaling model:** brain nodes scale 1 per platform (or ≥2 for HA). Muscle nodes scale
horizontally - add more as application workload grows. Local nodes are operator-provided
and incur no platform cost.

---

## Case Study Summary

> Source: [README.md](../../README.md) - FinOps Case Study (Nuntu)

| Metric                   | Before (SaaS Sprawl) | After (Sovereign Self-Hosted) | Impact                     |
|--------------------------|----------------------|-------------------------------|----------------------------|
| Annual Software OpEx     | $X (baseline)        | $0.3X                         | **-70%**                   |
| Platform Uptime (Prod)   | ~99.5%               | 99.8%                         | Higher reliability         |
| Data Sovereignty         | 0%                    | 100%                          | Full control               |
| WAF Efficacy             | N/A                   | >99% block, <1% false positive | Enterprise-grade perimeter |
| Incident Response Time   | Hours/Days           | Minutes                       | Stronger resilience        |
| Vendor Risk              | Critical             | Negligible                    | Supply-chain risk reduced  |

This is a field implementation narrative, not a vendor benchmark. Results depend on workload,
architecture, and governance discipline.

---

## Updating This Baseline

Update this document when any of the following occur:

1. **New node type** is introduced beyond brain/muscle/local.
2. **Provider change** shifts the VPS-equivalent pricing tiers (e.g., ARM64 Ampere nodes change the cost floor).
3. **Significant price change** in the self-hosted stack components (Docker, Caddy, PostgreSQL, etc.).
4. **New layer** or role added that materially affects compute, storage, or network cost.
5. **Case study refresh** - new field data from additional migrations or expanded Nuntu fleet.

To update:
- Adjust the per-node cost table with current planning estimates.
- Add a dated entry to the changelog below.
- If the case study section changes, sync with the root [README.md](../../README.md) FinOps Case Study section.

### Changelog

| Date       | Change                                        |
|------------|-----------------------------------------------|
| 2026-07-05 | Initial baseline: per-node table, L0/L1-L6 separation, Nuntu case study summary. |

---

## Cross-References

- [README.md](../../README.md) - FinOps Case Study (Nuntu) with aggregate before/after metrics
- [ARCHITECTURE.md](../architecture/ARCHITECTURE.md) - §5 L0/L1–L6 scope separation and trust boundaries; §7 host classes (brain/muscle/local)
- [ROADMAP.md](../project/ROADMAP.md) - FinOps Specialist role
- [ARCHITECTURE.md §5](../architecture/ARCHITECTURE.md#5-7-layer-architecture-model-full-specification) - Layer model (L0-L6) reference.
