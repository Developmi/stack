---
title: Layer Boundary Contracts
type: architecture
owner: maintainers
audience: maintainer
version: v6.0.0
last-reviewed: 2026-07-31
status: active
project: developmi-stack
repo: github.com/Developmi/stack
---

# Layer Boundary Contracts - L0 to L6

Each layer in the 7-layer model defines a **boundary contract**: a set of
responsibilities, promises, constraints, and failure modes that every
developer, operator, and auditor can rely on. These contracts are the
enforcement mechanism for **Principle 8: Layers don't reach across boundaries**.

---

## Cross-Layer Rules

These rules apply to ALL boundaries and are non-negotiable:

| Rule                             | Description                                                                                                                                                     | Violation Example                                                |
| -------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------- |
| **Upward dependency only**       | L(n) depends ONLY on L(n-1). L(n) never depends on L(n+1).                                                                                                      | L5 referencing L6 runtime internals                              |
| **No skipping layers**           | L(n) calls L(n-1), never L(n-2). If L3 needs OS facts, it asks L2, not L1.                                                                                      | L3 directly running `apt` commands                               |
| **No circular dependencies**     | The dependency graph MUST be a DAG. L(n) → L(n-1) → … → L1 is the only flow.                                                                                    | L1 importing L4 ingress rules                                    |
| **L0 Isolation**                 | L0 is private. It is referenced ONLY as an external prerequisite. No OpenTofu configs, no cloud credentials, no provider-specific logic in the OpenSource repo. | `roles/L1_os_baseline/general/` containing `provider = "oracle"` |
| **Trust boundaries are one-way** | Upper layers TRUST lower layers. Lower layers NEVER trust upper layers. L2 does not assume L5 sent valid data.                                                  | L2 opening a port because L5 asked for it without validation     |

```
Dependency flow:  L0 (private) ← L1 ← L2 ← L3 ← L4 ← L5 ← L6
Trust flow:       L0 (private) → L1 → L2 → L3 → L4 → L5 → L6
```

---

## Layer L0 - Commercial Infra (IaC)

**Tag**: `l0-iac`
**Directories**: N/A (private repository, outside OpenSource scope)
**Audit Finding**: No OpenTofu or Terraform artifacts found in the OpenSource repo.

### Responsibility

L0 provisions the physical and virtual substrate on which L1–L6 run:
compute instances (VPS/bare-metal), block storage, DNS zones, VPC/subnet
topology, provider-specific security groups, and SSH access.

L0 is **entirely private**. Its implementation lives in a separate, private
repository. The OpenSource platform references L0 only as a documented
external prerequisite.

### Promises

1. **Provisioned compute** - hosts exist, are reachable via SSH, and have sufficient disk/CPU/RAM for the declared host class.
2. **DNS zones** - public and internal DNS zones are delegated and resolvable.
3. **Block storage** - persistent volumes are attached and mounted where the OS expects them.
4. **Provider security groups** - baseline network ACLs are in place (e.g., rate-limited SSH, no open ports except 22 and Tailscale).
5. **Architecture availability** - provisioned hosts match the declared architecture (amd64 or arm64).

### Forbids

- MUST NOT configure the OS (packages, users, kernel). That is L1.
- MUST NOT install or configure applications. That is L5/L6.
- MUST NOT set firewall rules beyond provider-level ACLs. That is L2.
- MUST NOT reference or depend on any OpenSource role, playbook, or variable.
- MUST NOT appear in the OpenSource repo - not even as documentation examples with real credentials.

### Depends On

- **Nothing** (bottom of the stack for the private infrastructure).
- L0 is the **root dependency** for the entire platform. Without L0, neither L1 nor any layer above can function.

### Provides To

- **L1 (OS Baseline)** - running hosts with SSH access, OS pre-installed (Ubuntu 22.04/24.04, Debian 11/12), architecture declared.

### Trust Level

**Private**. L0 holds cloud credentials, OpenTofu state (which may contain
sensitive resource IDs and IPs), and provider API tokens. Compromise of L0
means complete infrastructure compromise. L0 is NEVER exposed to the
OpenSource surface. Audit trail: `docs/compliance/evidence/L0_AUDIT.md`.

### Contract Breach

| Failure Mode                                            | Consequence                                                                                         | Detection                                                           |
| ------------------------------------------------------- | --------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------- |
| Host unreachable via SSH                                | All layers fail. L1 cannot apply OS baseline.                                                       | Ansible `gather_facts` timeout. `make deploy` fails immediately.    |
| Wrong architecture provisioned (arm64 instead of amd64) | `supported_arch` validation in `apps.yml` blocks L5 deployment. L1–L4 may still apply but L5+ fail. | Pre-flight arch check in `apps.yml`.                                |
| Insufficient disk/CPU                                   | L5 apps fail to start (disk full), L6 containers crash.                                             | Monitoring alerts (L3). Docker health checks fail.                  |
| Provider security groups too permissive                 | L2 firewall cannot compensate for provider-level gaps.                                              | Security audit at L2; `compliance.yml` compares expected vs actual. |
| DNS not delegated                                       | L4 Caddy cannot obtain TLS certificates. External services unreachable.                             | Caddy logs TLS handshake failures. L3 health checks fail.           |

---

## Layer L1 - OS Baseline

**Tag**: `l1-os-baseline`
**Directories**: `roles/L1_os_baseline/general/`, `roles/L1_os_baseline/debian_12/`, `roles/L1_os_baseline/ubuntu_24.04/`, `roles/L1_os_baseline/debian_13_trixie/`
**Playbooks**: `playbooks/site.yml` (L1)

### Responsibility

L1 standardizes the operating system. It is the **bottom of the OpenSource
surface** - the first layer that any Ansible playbook touches. L1 owns:
package manager configuration (apt sources, pinning), update/hold policies,
auto-upgrade checker, OS family detection, Pop OS → Ubuntu normalization,
timezone, locale, and kernel module blacklisting (`cramfs`, `freevxfs`, etc.).

L1 MUST detect the host architecture (amd64/arm64) and make it available as
`ansible_architecture` for all upper layers.

### Promises

1. **Package manager is configured and consistent** - apt sources point to reliable mirrors, hold pins are applied, no stale or broken packages.
2. **Update policies are active** - unattended-upgrades configured per host class. Security updates auto-applied; non-security updates follow declared policy.
3. **OS family is normalized** - Pop OS is detected and remapped to Ubuntu. `ansible_distribution` and `ansible_os_family` are reliable facts for upper layers.
4. **Kernel modules are clean** - insecure/unnecessary modules (`cramfs`, `freevxfs`, `hfs`, `hfsplus`, `squashfs`, `udf`) are blacklisted.
5. **Architecture is declared** - `ansible_architecture` is set (amd64 or arm64) and available as a fact for all upper layers.
6. **Time and locale are correct** - timezone is set, NTP is active (via systemd-timesyncd or chrony).

### Forbids

- MUST NOT configure SSH. That is L2.
- MUST NOT configure firewall rules (ufw/nftables). That is L2.
- MUST NOT install or configure Docker. That is L6.
- MUST NOT install application packages (PostgreSQL, Redis, app-specific). That is L5/L6.
- MUST NOT touch monitoring agents or scrape targets. That is L3.
- MUST NOT reference cloud provider APIs or credentials. That is L0.

### Depends On

- **L0** - a running host with SSH access, pre-installed OS (Ubuntu 22.04/24.04, Debian 11/12).

### Provides To

- **L2 (Compliance)** - a standardized OS surface where SSH, firewall, and hardening roles can safely execute.
- **L3 (Observability)** - correct time/locale for log timestamps and metrics.
- **L6 (Runtime)** - Docker-compatible kernel and package state for `docker-ce` installation.

### Trust Level

**System**. L1 runs as root (Ansible becomes `root` or `sudo`). It is trusted
to configure the base OS. A compromised L1 can poison the package manager or
kernel - compromising every layer above it. However, L1 is the most
well-understood layer: it applies the same logic regardless of host class.

### Contract Breach

| Failure Mode                                 | Consequence                                                                                               | Detection                                                                                                                 |
| -------------------------------------------- | --------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------- |
| Package manager broken (404, unsigned repos) | L2 cannot install `ufw`, `fail2ban`, CrowdSec. L6 cannot install Docker.                                  | `apt update` → non-zero exit. `playbooks/site.yml` fails at L1.                                                           |
| Unattended-upgrades not configured           | Security patches not applied. CVEs accumulate.                                                            | `compliance.yml` checks `unattended-upgrades` status. L3 alerts if packages held > 30 days.                               |
| Pop OS not normalized                        | `ansible_distribution` returns "Pop!\_OS" instead of "Ubuntu". OS-specific `when:` conditions fail in L2. | `gather_facts` output shows unexpected `ansible_distribution`. `playbooks/site.yml` fails at L2 with undefined variables. |
| Kernel modules not blacklisted               | `cramfs`, `freevxfs` loadable. NIST control SC-7 violation.                                               | `compliance.yml` checks `/etc/modprobe.d/blacklist.conf`. Evidence missing from `/srv/evidence/nist/sc-7/`.               |
| Wrong timezone/NTP                           | Log timestamps are incorrect. TLS certificate validation may fail. Grafana dashboards show wrong times.   | L3 monitoring detects clock skew. Caddy logs show `x509: certificate has expired or is not yet valid`.                    |

---

## Layer L2 - Compliance

**Tag**: `l2-compliance`
**Directories**: `roles/L2_compliance/general/`, `roles/L2_compliance/nist_800_53/`
**Playbooks**: `playbooks/site.yml` (L2), `playbooks/l2/compliance.yml`

### Responsibility

L2 hardens the host and collects evidence of compliance. It is the
**security-critical layer** - compromise here compromises everything above.
L2 owns: SSH hardening (keys-only, no root login, strict ciphers), firewall
(ufw on Ubuntu, nftables on Debian - auto-dispatched), fail2ban (jail
configuration per host class), kernel hardening (sysctl), CrowdSec (with
enforcement vs detection-only toggle), OCI killswitch (conditional, Ubuntu
OCI only), NIST/CIS evidence collection to `/srv/evidence/`, and Tailscale
client enrollment.

The `hardening_profile` dispatcher (`server` | `workstation`) controls
intensity: `server` applies full hardening (CrowdSec enforcement, fail2ban 1h
bantime, strict UFW deny), `workstation` applies tailored hardening
(CrowdSec skipped, fail2ban 10m bantime, UFW deny with relaxed outbound).

### Promises

1. **SSH is hardened** - password auth disabled, root login disabled, key-only access, strict cipher/MAC/KEX algorithms.
2. **Firewall is active and enforcing** - default deny inbound. Only declared ports are open. Backend auto-selected: ufw on Ubuntu, nftables on Debian 12.
3. **fail2ban is running** - configured per host class. Protects SSH from brute-force.
4. **CrowdSec is operational** - installed and configured. Enforcement or detection-only per `hardening_profile`.
5. **Kernel is hardened** - sysctl parameters applied (`net.ipv4.tcp_syncookies`, `kernel.kptr_restrict`, etc.). NIST CM-7 controls verified.
6. **Compliance evidence is collected** - machine-generated evidence files written to `/srv/evidence/nist/<control>/`. Traceable to Ansible task tags.
7. **Tailscale is enrolled** - host is connected to the Tailscale mesh. `brain`/`muscle` use automated auth; `local` uses manual auth.

### Forbids

- MUST NOT manage packages, APT sources, or update policies. That is L1.
- MUST NOT install Docker or configure Docker networking. That is L6.
- MUST NOT deploy application containers. That is L5/L6.
- MUST NOT configure reverse proxy or TLS certificates. That is L4.
- MUST NOT configure monitoring agents or scrape targets. That is L3.

- MUST NOT open a port because an upper layer requested it without operator confirmation.

### Depends On

- **L1 (OS Baseline)** - standardized package manager, correct OS facts, kernel modules blacklisted.
- **L0** - for host existence and SSH access (initial connection before Tailscale enrollment).

### Provides To

- **L3 (Observability)** - secured SSH access for agent installation, audit logs for monitoring, CrowdSec alerts as metrics.
- **L4 (Networking)** - open ports 80/443 for Caddy, Tailscale network for internal routing.
- **L5 (Application Profiles)** - secured host where apps can safely run. CrowdSec protects app endpoints from attacks.
- **L6 (Runtime)** - secured host where Docker daemon can safely run. Firewall protects Docker API from unauthorized access.

### Trust Level

**Security-critical**. L2 is the highest OpenSource trust level. It controls
SSH access, firewall, and intrusion detection. A compromised L2 means an
attacker can:

- Open any port (firewall bypass)
- Disable SSH hardening (password brute-force)
- Silence CrowdSec alerts (persistent undetected access)
- Falsify compliance evidence (regulatory violations)

L2 roles are the most heavily reviewed code in the platform. Every change
must pass ansible-lint and manual security review.

### Contract Breach

| Failure Mode                          | Consequence                                                         | Detection                                                                                         |
| ------------------------------------- | ------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------- |
| SSH hardening not applied             | Password auth enabled, root login allowed. Brute-force vector open. | `compliance.yml` checks `/etc/ssh/sshd_config`. Evidence missing from `/srv/evidence/nist/ac-2/`. |
| Firewall not running or misconfigured | All ports exposed. L4 Caddy is the only line of defense.            | `ufw status` / `nft list ruleset`. `compliance.yml` checks. L3 monitors open ports.               |
| fail2ban not active                   | SSH brute-force attacks succeed over time.                          | `systemctl status fail2ban`. L3 alert if fail2ban process missing.                                |
| CrowdSec disabled or misconfigured    | Intrusions not detected. No collaborative blocking.                 | `cscli metrics`. L3 alert if CrowdSec API unreachable.                                            |
| Kernel hardening missing              | Kernel vulnerable to known exploits. NIST CM-7 violation.           | `sysctl -a` diff. Evidence missing from `/srv/evidence/nist/cm-7/`.                               |
| Compliance evidence missing           | Audit fails. NIST controls cannot be verified. Regulatory penalty.  | `compliance.yml` run shows missing files. Auditor rejects evidence package.                       |
| Tailscale not enrolled                | Host unreachable via mesh. Caddy cannot route internal traffic.     | `tailscale status`. L4 Caddy shows 502 to upstream services.                                      |

---

## Layer L3 - Observability

**Tag**: `l3-observability`
**Directories**: `roles/L3_observability/general/`, `roles/L3_observability/app_templates/`
**Playbooks**: `playbooks/l3/exporters.yml`, `playbooks/l3/stack.yml`

### Responsibility

L3 collects, stores, and visualizes system and application metrics, logs, and
traces. It owns: VictoriaMetrics (metrics storage), Grafana (dashboards),
Loki (log aggregation), scrape target configuration, health check endpoints,
and alerting rules. L3 is the **monitoring layer** - it watches everything
above and below it without modifying it.

L3 is deployed only on `brain` and `muscle` host classes. `local` hosts skip
L3 entirely.

### Promises

1. **Metrics are collected** - VictoriaMetrics scrapes all declared targets. System metrics (CPU, RAM, disk, network) and application metrics (if exposed) are stored.
2. **Dashboards are available** - Grafana is accessible (via Caddy/L4). Pre-configured dashboards for host health, Docker containers, and per-app metrics.
3. **Logs are aggregated** - Loki collects logs from Caddy (L4), Docker containers (L6), and system journal. Searchable via Grafana.
4. **Health checks run** - application health endpoints (declared in L5 profiles) are scraped. Unhealthy endpoints trigger alerts.
5. **Alerts fire** - pre-configured alerting rules notify operators of: host down, disk full, service unreachable, certificate expiry, CrowdSec alerts, backup failures.

### Forbids

- MUST NOT configure firewall rules. That is L2.
- MUST NOT modify SSH configuration. That is L2.
- MUST NOT touch application data or databases. That is L5.
- MUST NOT configure Docker or Portainer. That is L6.
- MUST NOT expose metrics endpoints to the public internet (L4 routes them internally).
- MUST NOT store secrets or credentials in dashboards (use Grafana environment variables from SOPS).

### Depends On

- **L2 (Compliance)** - secured SSH access for agent installation, CrowdSec alerts as metrics input, audit logs for Loki.
- **L1 (OS Baseline)** - correct time/locale for accurate timestamps.
- **L0** - for host existence (indirect via L1/L2).

### Provides To

- **L4 (Networking)** - health check endpoints for Caddy upstream services.
- **L5 (Application Profiles)** - monitoring of app health (`monitoring.health_endpoint`), backup job status, DB metrics.
- **L6 (Runtime)** - Docker container metrics (CPU, RAM, restart count), Portainer health.

### Trust Level

**Monitoring**. L3 has read access to metrics and logs across all layers. It
has write access limited to its own configuration (Grafana dashboards,
VictoriaMetrics scrape configs, alerting rules). L3 does NOT have: shell
access to hosts, Docker socket access, application database credentials, or
firewall modification capability. A compromised L3 can:

- Falsify metrics (hide an intrusion)
- Suppress alerts (delay incident response)
- Read logs (exfiltrate sensitive data from log lines)

L3 is trusted to observe but not to act. It is the "canary in the coal mine"

- if L3 is silent, assume something is wrong.

### Contract Breach

| Failure Mode                        | Consequence                                                                    | Detection                                                                                              |
| ----------------------------------- | ------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------ |
| VictoriaMetrics down or unreachable | No metrics collected. Dashboards show gaps. Alerts do not fire.                | Self-monitoring: VictoriaMetrics health endpoint. L3 alert if scrape interval missed > 2x.             |
| Grafana unavailable                 | Operators cannot view dashboards. Incident response depends on raw log access. | Caddy (L4) returns 502 for Grafana domain. Health check fails.                                         |
| Loki not ingesting logs             | Log search unavailable. Post-incident forensics impossible.                    | Grafana Loki data source shows "no data." L3 alert on log ingestion rate = 0.                          |
| Scrape targets misconfigured        | Application metrics missing. Health checks not running.                        | L3 alert: target down. App health dashboard shows gaps.                                                |
| Alerts not firing                   | Incident goes undetected. Operator learns of outage from users.                | Alerting rule test suite. Periodic "heartbeat" alert confirms pipeline is working.                     |
| Metrics endpoint exposed publicly   | Prometheus/VictoriaMetrics data accessible without auth. Information leak.     | L3 audit: check Grafana/VictoriaMetrics bind address. L4 Caddy logs show unauthorized access attempts. |

---

## Layer L4 - Networking / Edge

**Tag**: `l4-networking`
**Directories**: `roles/L4_networking/general/`, `roles/L4_networking/caddy/`, `roles/L4_networking/traefik/`, `roles/L4_networking/nginx/`
**Playbooks**: `playbooks/l4/edge.yml`

### Responsibility

L4 is the **edge layer** - the boundary between the public internet and the
internal platform. It owns: Caddy reverse proxy (custom Docker image by
default, pluggable via PR for Traefik/nginx), TLS certificate management
(Cloudflare Origin Certs now, ACME/AWS future), WAF profiles (Coraza/Caddy),
Caddy logging, and `ingress_services` routing configuration.

L4 translates external DNS names to internal Docker service ports. Every
request from the public internet passes through L4 before reaching any
application (L5).

### Promises

1. **Reverse proxy is running** - Caddy serves as the single ingress point. All external traffic terminates TLS at Caddy.
2. **TLS certificates are deployed** - Cloudflare Origin Certificates are loaded and served. Caddy auto-renews if ACME is used.
3. **WAF is active** - Coraza/Caddy WAF rules protect against OWASP Top 10: SQLi, XSS, path traversal, rate limiting.
4. **Request routing is correct** - `ingress_services` entries route domains to the correct container port.
5. **Caddy logs are structured** - JSON-formatted access logs shipped to Loki (L3) for analysis and alerting.

### Forbids

- MUST NOT manage Docker containers (start/stop/restart). That is L6.
- MUST NOT configure application databases. That is L5.
- MUST NOT configure monitoring targets. That is L3.
- MUST NOT open firewall ports. That is L2.
- MUST NOT store application secrets in Caddy configuration. Secrets live in L5.
- MUST NOT hardcode upstream container IPs (containers are ephemeral - use Docker DNS or service names).

### Depends On

- **L2 (Compliance)** - ports 80/443 open in firewall. Tailscale enrolled if internal-only routing is needed.
- **L6 (Runtime)** - Docker running (Caddy runs as a container). Docker network available for service discovery.
- **L1** - for OS time/locale (TLS validity checks).
- **L0** - for DNS zone delegation (indirect).

### Provides To

- **L5 (Application Profiles)** - HTTPS ingress for all apps. `ingress_services` routes `domain:port` to the correct app container.
- **L3 (Observability)** - Caddy access logs for traffic analysis and anomaly detection.

### Trust Level

**Edge**. L4 is the **first line of defense** against the public internet.
Caddy is exposed on ports 80/443. A compromised L4 means:

- TLS certificates can be stolen or replaced (MITM attacks)
- WAF can be bypassed (SQLi, XSS reach applications)
- Request routing can be hijacked (traffic sent to the wrong backend or domain)
- Logs can be suppressed or falsified (cover tracks)

L4 is the highest-risk OpenSource layer because it is publicly reachable.
Caddy configuration changes require the same review rigor as L2 changes.

### Contract Breach

| Failure Mode                       | Consequence                                                           | Detection                                                                                        |
| ---------------------------------- | --------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------ |
| Caddy not running or unreachable   | All apps are inaccessible from the internet. 502/503 for all domains. | L3 alert: Caddy health endpoint unreachable. External health check (e.g., UptimeRobot) confirms. |
| TLS certificate expired or invalid | Browsers show security warnings. Users cannot access apps.            | Caddy logs `x509: certificate expired`. L3 alert on cert expiry < 7 days.                        |
| WAF misconfigured or bypassed      | SQLi, XSS, path traversal reach applications.                         | Caddy WAF audit log. L3 anomaly detection on request patterns. Penetration test.                 |

| Caddy logs not shipped to Loki | No access logs. Post-incident forensics impossible. | L3 alert: Caddy log ingestion rate = 0. Grafana Loki shows gap for Caddy log stream. |
| Docker network unavailable | Caddy cannot reach upstream containers. 502 Bad Gateway. | Caddy logs 502 to upstream. `docker network ls` shows missing network. L3 health check shows app container up but unreachable via Caddy. |

---

## Layer L5 - Application Profiles

**Tag**: `l5-app-profile`
**Directories**: `apps/`
**Playbooks**: N/A (reference-only; compose files are operator-managed)

### Responsibility

L5 defines application profiles - tested reference configurations for the
operator to deploy. It owns: the reduced 6-field YAML profile schema
(`profile.yml`), the standard `apps/<app>/` layout (`docker-compose.yml` with
the `x-<app>-env` anchor pattern, `.env.example`, optional `assets/`), backup
themes (method/schedule/retention/verification) consumed by
`roles/L6_runtime/backup/`, and pre-flight validation (architecture check).

The app name is **derived from the profile directory path** (`apps/<name>/profile.yml`
→ `<name>`) by the backup role - there is no `name` field. Versions come from
the compose image pin (`${APP_IMAGE:-org/image:tag}`) - there is no `version`
field. The schema reference (fields, validation rules, dropped fields) lives in
[ARCHITECTURE.md §8](ARCHITECTURE.md#8-application-profile-schema-reduced-6-field-specification).

L5 is the **reference layer** - tested YAML profiles that the operator may
use to deploy their own application instances.

### Promises

1. **Profile schema is enforced** - every `profile.yml` declares the 6 fields: `supported_arch`, `depends_on`, `monitoring`, `compliance_tags`, `dr_tier`, `backup`; `name`/`version`/`target_group` are absent.
2. **Compose pattern is uniform** - every standardized app follows the shared pattern: `x-<app>-env` anchors, namespaced `<APP>_` variables, `${VAR:-default}` tunables, `${APP_IMAGE:-...}` pins, healthchecks on every service, hardening (init, cap_drop, no-new-privileges, named volumes).
3. **Architecture is documented** - `supported_arch` in each profile declares the architectures the pinned image is published for, verified per manifest.
4. **Dependencies are declared** - `depends_on` lists the roles/apps required before deployment.
5. **Backup themes are declared** - `backup.method`, `schedule`, retention, and `verification` per DR tier; `db_type`/`db_name` retained for backup-role dispatch.

### Forbids

- MUST NOT execute containers directly. Container lifecycle belongs to L6 (operator-managed at deploy time).
- MUST NOT configure firewall rules. That is L2.
- MUST NOT configure monitoring targets. That is L3 (L5 only declares `monitoring.health_endpoint` - L3 acts on it).
- MUST NOT configure Caddy ingress routes. That is L4 (L5 only provides ingress service data - L4 renders it).
- MUST NOT store application secrets in committed files. `.env.example` carries `changeme` placeholders; the operator provides real values in `.env`.
- MUST NOT import variables from `group_vars/{brain,muscle,local}/` - host-class variables belong to the host, not the app.
- MUST NOT reference files that do not exist (`compose.yml.j2`, `vars.yml`, `secrets.yml` are not part of the standardized layout).

### Depends On

- **L4 (Networking/Edge)** - Caddy must be deployed for HTTPS ingress, TLS certificates available.
- **L6 (Runtime)** - Docker Engine required for container execution.
- **L2 (Compliance)** - host security (firewall, CrowdSec, fail2ban) protects app ports.
- **L1** - for OS facts (indirect via L2/L6).

### Provides To

- **L6 (Runtime)** - compose files + `.env.example` + profile schema (backup themes for `roles/L6_runtime/backup/`).
- **L4 (Networking)** - ingress service data (domain, port) for reverse proxy configuration.
- **L3 (Observability)** - `monitoring.health_endpoint` and `monitoring.scrape_port` for each app.

### Trust Level

**Application**. L5 profiles describe application configurations. The trust
model applies when the operator deploys these profiles: applications process
user data, connect to databases, and handle authentication. The platform
provides the security substrate (L2 firewall, L4 WAF, L6 Docker isolation)
that operators rely on when running applications.

### Contract Breach

| Failure Mode                           | Consequence                                                                        | Detection                                                                                          |
| -------------------------------------- | ---------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------- |
| Profile missing MUST fields            | Profile validation fails. Operator cannot use the profile.                         | Schema check: the 6 fields must be present; `name`/`version`/`target_group` must be absent.        |
| `supported_arch` mismatch              | Profile declares arch the target host does not support.                            | Pre-flight arch check. Error: "Host arch 'arm64' not in supported_arch ['amd64']".                 |
| `changeme` placeholder reaches runtime | Containers start with default/example credentials.                                 | Operator review on deploy; `detect-secrets` scan of `apps/`.                                       |
| Backup job fails silently              | App data not backed up. Data loss on disk failure.                                 | L3 alert: backup job exit code ≠ 0. Grafana dashboard shows "last backup age" > schedule interval. |
| App profile references host-class vars | Profile picks up wrong port/firewall config from host group. Cross-layer coupling. | Lint rule: profiles must not import `group_vars/{brain,muscle,local}/` variables.                  |

---

## Layer L6 - Runtime Adapters

**Tag**: `l6-runtime`
**Directories**: `roles/L6_runtime/general/`, `roles/L6_runtime/docker_compose/`, `roles/L6_runtime/portainer/`, `roles/L6_runtime/backup/`
**Playbooks**: `playbooks/l6/engine.yml`, `playbooks/l6/portainer.yml`, `playbooks/l6/backup-stack.yml`, `playbooks/l6/backup-appdata.yml`, `playbooks/l6/backup-timers.yml`

### Responsibility

L6 defines **how** to run - it is the execution layer. It owns: Docker Engine
installation and configuration (`roles/L6_runtime/docker_compose/`), compose rendering and deploy
(`roles/L6_runtime/compose/deploy.yml.j2`), Portainer BE as an optional Manager
(`roles/L6_runtime/portainer/`), and runtime-state backups
(`roles/L6_runtime/backup/`). Future adapters: Swarm (`roles/L6_runtime/swarm/`), K3s
(`roles/L6_runtime/k3s/`).

The Engine (Compose default, Swarm/K3s future) and Manager (none or Portainer
BE) are **independent axes**. Compose MUST NEVER depend on Portainer. A
deployment without Portainer is 100% valid and functional.

L6 also owns `roles/L6_runtime/backup/` - which protects both runtime state (Portainer
configs, compose state, manager metadata) and application data (DB dumps, app configs).
The former `roles/backup` (L5) and `roles/stack_backup` (L6) were consolidated into a single
role with `backup_role_source` dispatch per ADR-09.

### Promises

1. **Docker Engine is running** - installed from `docker.com` apt repo, configured with daemon options from group vars, Docker Compose plugin available.
2. **Compose stacks are deployed** - L5 profiles are rendered via `roles/L6_runtime/compose/deploy.yml.j2` into `docker-compose.yml` + `.env` files at `/srv/app/<name>/`. Containers are running and healthy.
3. **Portainer is optional and independent** - if `enable_portainer: true`, Portainer BE is deployed as a Compose stack. Portainer manages stacks via the Docker socket but removing Portainer does NOT stop or remove any Compose stack.
4. **Runtime state is backed up** - `roles/L6_runtime/backup/` protects Portainer configs, compose project state, and Docker runtime metadata via `backup_role_source` dispatch.
5. **Future runtimes are abstracted** - the `roles/L6_runtime/` directory structure defines adapter slots for Swarm and K3s. Same L5 profile schema, different rendering logic.
6. **Docker socket is protected** - access restricted to the `docker` group. No unauthenticated access to the Docker API.

### Forbids

- MUST NOT modify application profiles (`apps/`). That is L5.
- MUST NOT configure firewall rules. That is L2.
- MUST NOT touch application data (DB contents, uploads, app configs). That is L5 (`roles/L6_runtime/backup/`).
- MUST NOT configure monitoring targets. That is L3 (though it may expose container metrics for L3 to scrape).
- MUST NOT configure Caddy ingress. That is L4.
- MUST NOT hardcode profile-specific logic in runtime adapters. The adapter reads the profile schema; it does not contain per-app conditionals.
- MUST NOT allow Compose to depend on Portainer. The Engine-Manager decoupling is non-negotiable (ADR-07).

### Depends On

- **L5 (Application Profiles)** - rendered compose templates, resolved `.env` files, `supported_arch` validation.
- **L2 (Compliance)** - secured host. Docker socket protected by L2 firewall. No unauthorized access to Docker API.
- **L1 (OS Baseline)** - compatible kernel and package state for Docker installation. Architecture declared for multi-arch image pulls.
- **L0** - for host existence (indirect via L1/L2).

### Provides To

- **L4 (Networking)** - Docker network and service DNS for Caddy upstream routing.
- **L3 (Observability)** - Docker container metrics (CPU, RAM, restart count), Portainer health, backup job status.

### Trust Level

**Runtime**. L6 has Docker socket access - effectively root on the host. A
compromised L6 means:

- Attacker can start, stop, or modify any container (including Caddy/L4 and Grafana/L3)
- Docker socket exposed = host root compromise (container escape via privileged mode or volume mounts)
- Portainer compromised = UI-based control over all stacks
- `roles/L6_runtime/backup/` data leaked = runtime configs and Portainer metadata exposed

L6 is the most privileged OpenSource layer after L2. Docker socket access
implies the ability to bypass L2 firewall (by launching containers with
`--network host`), read L5 app data (by mounting volumes), and disrupt L3
monitoring (by stopping monitoring containers).

### Contract Breach

| Failure Mode                             | Consequence                                                                                           | Detection                                                                                                                     |
| ---------------------------------------- | ----------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------- |
| Docker Engine not running or unreachable | No containers can be deployed or managed. All `docker compose` commands fail.                         | `systemctl status docker`. L3 alert: Docker daemon down. `apps.yml` fails at L6 step.                                         |
| Docker socket exposed without auth       | Attacker with network access controls all containers. Host root compromise possible.                  | Audit: check `docker.service` socket binding (`unix:///var/run/docker.sock` only, no TCP). L2 firewall blocks port 2375/2376. |
| Compose stack fails to deploy            | App not running. `docker compose up` exits non-zero.                                                  | `apps.yml` fails. L3 health check shows app container missing. Caddy returns 502.                                             |
| Portainer removed and stacks break       | Violation of ADR-07. Compose stacks are coupled to Portainer.                                         | Integration test: remove Portainer container, verify `docker compose ls` shows all stacks still active.                       |
| `backup` not running                     | Runtime state not backed up. Portainer configs lost on disk failure.                                  | L3 alert: `backup` job exit code ≠ 0. Backup age exceeds schedule interval.                                                   |
| `backup` touches app data                | Boundary violation: L6 accessing L5 data. Backups are incomplete (runtime state mixed with app data). | Audit: `roles/L6_runtime/backup/` tasks must not reference `/srv/app/<name>/` or app database paths.                          |
| Compose depends on Portainer for deploy  | Portainer becomes required. Engine-Manager decoupling violated. Can't deploy without Portainer.       | CI test: deploy an app profile with `enable_portainer: false`. Must succeed.                                           |
| Adapter uses per-app conditionals        | `deploy.yml.j2` contains `if app == "chatwoot"`. Runtime adapter is not agnostic.                     | Code review: `roles/L6_runtime/compose/deploy.yml.j2` must contain zero app names.                                            |

---

## Contract Breach Summary

| Layer  | Catastrophic Failure                                   | Blast Radius                                                                                                        |
| ------ | ------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------- |
| **L0** | Host unreachable or misprovisioned                     | ALL layers fail. Platform offline.                                                                                  |
| **L1** | Package manager broken, OS misdetected                 | L2 cannot install security tools, L4 TLS fails (time skew), L6 cannot install Docker.                               |
| **L2** | Firewall down, SSH wide open, CrowdSec disabled        | Complete host compromise. Every layer above is accessible to attackers.                                             |
| **L3** | Monitoring silent                                      | Incidents undetected. Operators learn of outages from users. Post-incident forensics impossible.                    |
| **L4** | Caddy down, TLS expired, WAF bypassed                  | All apps unreachable. MITM possible. Web attacks reach applications unfiltered.                                     |
| **L5** | Profile invalid, secrets missing, backup silent        | Reference profiles unusable. Operator cannot deploy applications safely.                                            |
| **L6** | Docker down, socket exposed, Compose-Portainer coupled | Containers cannot run. If socket exposed: host root compromise. If coupled: Portainer becomes mandatory dependency. |

### Recovery Priority

In a total platform failure, restore layers **bottom-up**:

1. **L0** - Verify hosts are reachable via SSH.
2. **L1** - Apply `playbooks/l1/baseline.yml`. Verify package state and OS facts.
3. **L2** - Apply `playbooks/l2/hardening.yml` then `playbooks/l2/compliance.yml`. Verify SSH, firewall, fail2ban, CrowdSec.
4. **L6** - Apply `playbooks/l6/engine.yml`. Docker must be running before anything else.
5. **L4** - Apply `playbooks/l4/edge.yml`. Reverse proxy must be up before apps.
6. **L5** - Validate profile schemas. Application deployment and data restoration are the operator's responsibility (profiles exist as reference only).
7. **L3** - Apply `playbooks/l3/exporters.yml` then `playbooks/l3/stack.yml`. Observability comes last - you need something to observe first.

---

## References

- Architecture: See ARCHITECTURE.md - 7-Layer Model Definition, Directory Layout, and Compliance Mapping
- Architecture: `docs/architecture/ARCHITECTURE.md` - §5 (7-Layer Architecture Model)
- ADR-07: [ADR-07.md](adr/ADR-07.md) - Engine/Manager decoupling
- ADR-08: [ADR-08.md](adr/ADR-08.md) - Backup Roles Consolidation (superseded)
- ADR-09: [ADR-09.md](adr/ADR-09.md) - AMD64/ARM64 Mandatory Compatibility

---

## Related Documents

- `docs/architecture/ARCHITECTURE.md` - Full architecture specification (directory layout, OS matrix, role composition, principles, app catalog)
- `docs/GLOSSARY.md` - Terminology bridge
- `docs/compliance/COMPLIANCE-MAPPING-STATUS.md` - Compliance framework overview and mapping status
- `docs/compliance/evidence/EVIDENCE_MODEL.md` - Evidence collection audit trail
- `docs/operations/DEVELOPER_SETUP.md` - Operator onboarding guide
- `docs/operations/INCIDENT_RESPONSE_DR.md` - Incident response and disaster recovery runbook (includes layer-by-layer recovery procedure)
