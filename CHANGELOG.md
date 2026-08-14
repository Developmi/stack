---
title: Changelog
last_updated: 2026-08-09
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
- SOPS + age secrets management replacing the monolithic Ansible Vault: `community.sops` vars plugin (`ansible.cfg` `vars_plugins_enabled = host_group_vars,community.sops.sops`), `.sops.yaml` creation rules with per-file `encrypted_regex`, `secrets.sops.yml` + `managers/portainer.sops.yml`, and Makefile `sops-init`/`sops-encrypt`/`sops-edit`/`sops-view` targets mirroring the vault ones
- Manager variable confinement (N4): all `portainer_*` defaults moved to `inventory/group_vars/all/managers/portainer.yml`; the `--ask-vault-pass` flag retired from deploy targets (kept only on the six Tailscale trio consumers: deploy-hardening, deploy-compliance, reconnect-tailscale, deploy-local, nuke, provision-host)
- Documentation parity for the Compose-only deploy path: runbook "Deploy Path: Compose-only" section (deploy/verify/troubleshooting) + `public_net` condition for app compose files, ADR-07 L6 decoupling link, LAYER_BOUNDARIES `enable_portainer` references, and stale `apps/<name>/vars.yml` references removed (replaced by the operator-managed `.env` reality)

### Fixed

- Portainer role P0 fixes: deterministic Edge ID (`portainer_edge_id_resolved` now always equals `inventory_hostname` - the `portainer_edge_id`/`machine_id` chain is removed), a missing Edge key now fails the run with an assert naming the host and the `managers/portainer.sops.yml` fix (the silent debug skip is gone), and `portainer_edge_target_brain` is an explicit per-cluster hostname in `managers/portainer.yml` - the `groups['brain'][0]` fallback is removed from both group_vars and the role
- Dead secrets removed (zero consumers, design D3): `portainer_url`, `portainer_username`, `portainer_password`, `portainer_server_url`, and the vault copy of `observability_network_name` (redundant with the role default)
- Portainer version pin drift synced (VERSION_PINS.md): `2.39.3` → `2.39.5` to match `managers/portainer.yml`

### Fixed

- L1 kernel module blacklist: removed `vfat` (false-positive CM-7 finding on EFI-booted systems)
- L1 Universe repo source: check/enable/cleanup moved to the general dispatcher so it runs before any apt cache refresh (a stale amd64-URI deb822 source broke refreshes on ARM hosts under `any_errors_fatal`); mirror derived by host architecture (`l1_universe_uris`, `ports.ubuntu.com` for ARM), enable gated on the coverage check, stale amd64 deb822 source cleaned
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
- bootstrap: derive SSH identity from the inventory (`ansible_user` per host, `ansible_ssh_private_key_file` in `all:vars`) instead of hardcoded root + `id_ed25519`; derived `ansible_become` for cloud images; fail-fast asserts with informative messages when the identity is missing or unreachable
- Lockdown deadlock: `playbooks/l2/lockdown.yml` no longer relies on a `set_fact` transition that `-e` extra vars overrode (extra-var precedence beats `set_fact`), leaving the closing tasks skipped on the first deploy. The closing play now ALWAYS runs: root SSH is disabled, `AllowUsers` is pinned to Tailscale CGNAT, the firewall DROP is applied, the bootstrap ACCEPT exception is removed (UFW rule / nftables line) and `/etc/tailscale-recover.lock` is created at the end of the same run - no more deadlocked pre-flight on the next `make deploy`
- Renamed the legacy bootstrap variable (prefixed from the previous nist-hardening-suite repository) to `bootstrap_mode`: a first-deploy "bootstrap gate" switch, NOT a NIST control. It only controls pre-flight gating and the rendering of the bootstrap ACCEPT exception (SSH from `controller_ip`); set it ONLY via `-e` (`make deploy-bootstrap`), never in a vars file
- `deploy-edge` Makefile target now passes `-e target_group=$(HOST)`: the L4 play defaults `hosts:` to the `muscle` group, so `HOST=brain-1` previously matched 0 hosts; corrected backend list to `caddy` (only implemented backend)
- Caddy WAF: removed the obsolete `SecRuleUpdateActionById 900000` directive from the detection-only branch of the Caddyfile templates (`Caddyfile.j2`, `Caddyfile.example.j2`). Rule 900000 no longer exists in OWASP CRS 4.x (the `REQUEST-900-EXCLUSION-RULES-BEFORE-CRS.conf` anchor rule was removed; only a commented example ships), so Coraza 3.7 failed directive compilation and the ingress container crash-looped on any `detection_only` route. Detection-only now emits only `SecRuleEngine DetectionOnly`; enforcement is unaffected (paranoia anchors are the active 9011xx rules)
- `deploy-portainer` Makefile target now passes `-e enable_portainer=true`: the L6 Portainer play is double-gated on `enable_portainer` (play `end_play` pre-task + role `when`, ADR-02), so the target silently no-op'ed unless the variable was set in group_vars. The target now materializes the intent; the conservative `enable_portainer: false` group_vars default stays for direct playbook runs (`make run PLAYBOOK=...`)

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
