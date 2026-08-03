---
title: Changelog
last_updated: 2026-08-02
owner: TBD
audience: all
status: active
---

# Changelog

## v6.1.0-dev (2026-08-02)

### Added

- Shared Docker user-namespace remap detection include used by the observability, ingress, and runtime layers to compute effective UID/GID and subordinate range offsets
- `shared_network_name` inventory variable as the single source of truth for the shared external Docker network; L4 edge and L6 manager roles now reference it instead of hardcoding
- Interactive L3 pre-flight gate when the observability stack requires an external network that is missing: a y/N prompt (30 s timeout) instructs the operator to deploy the L4 stack first, and a declined answer stops the play cleanly
- NIST 800-53 compliance evidence collection (AC-2, AU-12, CM-7, SC-7, SI-4, SC-28) writing per-control reports under `/srv/evidence/nist/<control>/`
- Grafana 13-compatible alert rule provisioning with a fixed VictoriaMetrics datasource UID
- Conditional Telegram contact point in the Grafana notifier (rendered only when a bot token is defined)
- `cron` package in L6 runtime prerequisites (required for the Docker garbage-collection cron job)
- Non-root user-namespace compatibility for Postgres-family services (`user: "999:999"`), Node services tmpfs mounts with explicit uid/gid, and healthchecks sourcing credentials from the environment

### Fixed

- L1 kernel module blacklist: removed `vfat` (false-positive CM-7 finding on EFI-booted systems)
- L3 observability pre-flight: base directory is now created before bind-mount targets (ENOENT on first run)
- L3 userns detection include: missing shared file restored and invalid Jinja filter replaced (`splitlines` → `split('\n')`)
- Backup role dispatcher: undefined-safe guards on all branches (no more crash when `backup_role_source` is unset)
- Backup timer discovery: corrected application profile path resolution
- Caddy pre-flight localhost `stat` no longer requires sudo on the control node
- Metabase compose: removed unsupported read-only rootfs (the official image entrypoint writes to `/etc` and `/app`) and added the capabilities required by its privilege drop
- N8N compose: writable cache tmpfs with uid/gid for the web and worker services
- MariaDB healthcheck: uses environment-sourced credentials (the image default probe ignores them)
- Uptime Kuma compose: removed read-only rootfs (overlayfs incompatibility under user-namespace remap)
- L2 compliance dispatcher: corrected duplicated role path segments and invalid `../nist_800_53` includes; user hardening no longer terminates the whole play when connecting as the automation user
- `deploy-compliance-nist80053` Makefile target now honors `ANSIBLE_LIMIT`
- `verify-observability` Makefile target passes vault/become flags and validates container health instead of host ports
- Documented one-time Grafana datasource UID migration for existing deployments

## v6.0.0-dev (2026-07-26)

### Initial Release (New Repository)

- Complete Ansible NIST 800-53 hardening suite (7 layers L0-L6)
- Debian 12 + Ubuntu 22.04, amd64 + arm64
- Tailscale ACL management with tag-based routing
- Caddy WAF v3.2.1 edge proxy
- Observability stack: VictoriaMetrics, Loki, Grafana
- Backup stack: Restic (DB + stack config)
- Molecule test suite with Docker driver
- Reference application profiles at apps/ (user-managed)

### Prior History

Prior development from v1.0.0 to v5.5.0 is maintained in the
[Miguel-DevOps/nist-hardening-suite](https://github.com/Miguel-DevOps/nist-hardening-suite) repository.
