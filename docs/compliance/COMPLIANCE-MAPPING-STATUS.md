---
title: Compliance Mapping Status
type: compliance
owner: maintainers
audience: maintainer
version: v6.0.0
last-reviewed: 2026-07-16
status: active
project: developmi-stack
repo: github.com/Developmi/stack
---

# Compliance Mapping Status

This master document serves as the Single Source of Truth (SSOT) and consolidated entry point for all compliance frameworks, security controls, and evidence verification procedures in the Developmi Stack.

---

## 1. Scope and Assurance Model

### Technical Scope Validated in this Repository

- Bootstrap and hardening orchestration through root playbooks: `playbooks/site.yml`, `playbooks/l6/engine.yml`, `playbooks/l3/exporters.yml`, `playbooks/ops/nuke.yml`.
- Security controls implemented across roles: `security`, `crowdsec`, `tailscale_client`, `portainer`, `observability`, `compliance`.
- Inventory and role model based on `brain` and `muscle` host groups.
- Global and per-group behavior configured in `group_vars/all`, `group_vars/brain`, and `group_vars/muscle`.
- Quality controls defined with `.ansible-lint`, `.yamllint`, and `.pre-commit-config.yaml`.

### Compliance Assurance Boundaries

- This repository provides technical implementation evidence and mappings - it is not a formal certification.
- Framework mappings must be validated against your legal, sector, and audit context.
- NIST SC-28 is partially implemented: secrets-at-rest encryption is automated with SOPS + age (Ansible Vault only for the Tailscale trio until expiry); full disk encryption is audited but not provisioned by this suite.

---

## 2. Framework Coverage Matrix

The suite provides technical implementation controls and evidence generation for the following frameworks:

| Framework           | Version / Revision                         | Status                           | Applicable Controls / Scope                                                        | Controls Covered | Controls Pending | Evidence Collection    |
| ------------------- | ------------------------------------------ | -------------------------------- | ---------------------------------------------------------------------------------- | ---------------- | ---------------- | ---------------------- |
| **NIST SP 800-53**  | Rev 5                                      | Fully mapped / Implemented       | AC-2, CM-7, SC-7, SI-4, AU-12, SC-28                                               | 5/6              | SC-28 (partial)  | Yes - per control      |
| **NIST SP 800-207** | Final                                      | Implemented                      | Zero Trust Architecture overlay transport, identity/policy-based segmentation      | -                | -                | -                      |
| **CIS Benchmarks**  | Ubuntu 22.04 LTS v2.0.0 / Debian 12 v1.0.0 | Mapped per Ansible role          | SSH hardening, UFW/nftables posture, sysctl tuning, filesystem permissions         | -                | -                | Yes - role-level       |
| **DORA**            | EU 2022/2554                               | Mapped at architectural level    | ICT risk management, incident reporting, digital operational resilience testing    | -                | -                | No                     |
| **ENS**             | RD 311/2022                                | Technical-functional equivalence | Medium category: access control (op.acc), protection (op.exp), monitoring (op.mon) | -                | -                | Yes - via NIST overlap |
| **MITRE ATT&CK**    | v15                                        | Defensive controls mapped        | Defense evasion (T1562), privilege escalation (T1068), persistence (T1547)         | -                | -                | -                      |
| **SOC 2 Type II**   | -                                          | Stub - not yet implemented       | CC6.1, CC6.6, CC7.1, CC7.2 (overlapping with NIST controls)                        | 0                | All              | No                     |

### 2.1 Mapping Status Definitions

| Status                               | Definition                                                                                        |
| ------------------------------------ | ------------------------------------------------------------------------------------------------- |
| **Fully mapped / Implemented**       | Every applicable control has a corresponding Ansible role with task tags and evidence generation  |
| **Mapped per Ansible role**          | Controls are implemented by specific roles; evidence is role-level, not framework-level           |
| **Mapped at architectural level**    | The platform design addresses the framework requirements; specific controls may not be enumerated |
| **Technical-functional equivalence** | Controls are satisfied by equivalent technical measures, not 1:1 mapping                          |
| **Stub**                             | Framework acknowledged; mapping work is planned but not yet executed                              |

---

## 3. NIST Framework Alignment

### 3.1 NIST SP 800-53 Detailed Mapping

The following table traces each NIST SP 800-53 Rev 5 control to the Ansible role that implements it, the task tags used for targeted execution, the architecture layer, the evidence path, and the current implementation status. Source: [NIST_800_53.md](NIST/NIST_800_53.md).

| Control ID | Control Name        | Role                        | Task Tags               | Layer  | Evidence Path                                                     | Status      |
| ---------- | ------------------- | --------------------------- | ----------------------- | ------ | ----------------------------------------------------------------- | ----------- |
| **AC-2**   | Account Management  | `security`                  | `ssh`, `nist,ac-2`      | L2     | `/srv/evidence/nist/ac-2/` (ssh_config, sudoers_audit, user_list) | Implemented |
| **CM-7**   | Least Functionality | `security`                  | `kernel`, `nist,cm-7`   | L2     | `/srv/evidence/nist/cm-7/` (kernel modules, services)             | Implemented |
| **SC-7**   | Boundary Protection | `security`                  | `firewall`, `nist,sc-7` | L2     | `/srv/evidence/nist/sc-7/` (ufw/nftables status, fail2ban)        | Implemented |
| **SI-4**   | System Monitoring   | `crowdsec`, `observability` | `crowdsec`, `nist,si-4` | L2, L3 | `/srv/evidence/nist/si-4/` (crowdsec alerts, auditd rules)        | Implemented |
| **AU-12**  | Audit Generation    | `compliance`                | `audit`, `nist,au-12`   | L2     | `/srv/evidence/nist/au-12/` (audit logs)                          | Implemented |

#### Control Detail

- **AC-2**: SSH hardening, root login restrictions, brute-force mitigation.
- **CM-7**: Module/filesystem reduction and sysctl security baseline.
- **SC-7**: Host boundary controls and segmentation posture.
- **SI-4**: Intrusion monitoring and detection via CrowdSec.
- **AU-12**: Audit generation with auditd rules and evidence extraction.
- **SC-28**: Encrypted secrets management (SOPS + age); disk encryption verification only (**partial** - not provisioned by this suite).

#### Compliance Playbook Invocation

```bash
ansible-playbook playbooks/l2/compliance.yml --tags nist,ac-2,nist,sc-7,nist,si-4,nist,au-12,nist,cm-7
```

Evidence output follows a per-control hierarchy under `/srv/evidence/nist/<control>/`.

### 3.2 NIST SP 800-207 (Zero Trust Architecture)

- Overlay-only transport is enforced in non-bootstrap playbooks (`playbooks/l6/engine.yml`, `playbooks/l3/exporters.yml`, `playbooks/ops/nuke.yml`) by asserting `ansible_host` belongs to the management subnet.
- Identity and policy-based segmentation are implemented via Tailscale tags and ACL automation.
- Portainer Edge Agent uses a pull model that avoids inbound management ports on managed nodes.

> [!NOTE]
> Reference: [NIST SP 800-207](https://csrc.nist.gov/pubs/sp/800/207/final)

### 3.3 NIST SP 800-171 (Controlled Unclassified Information)

See [NIST_800_171.md](NIST/NIST_800_171.md) - mapping is pending. Overlapping controls from AC, CM, SC, SI, and AU families in 800-53 may partially satisfy 800-171 requirements.

### 3.4 CIS Benchmarks Level 1 (Ubuntu/Debian)

- SSH baseline hardening aligns with CIS secure remote administration expectations.
- UFW default-deny posture aligns with host firewall baseline requirements.
- Kernel/filesystem and sysctl hardening align with least-functionality and network hardening practices.
- Audit and security telemetry align with logging and monitoring expectations.

> [!NOTE]
> Reference: [CIS Benchmarks](https://www.cisecurity.org/cis-benchmarks)

### 3.5 MITRE ATT&CK (Blue Team Defensive Mapping)

- Defensive tooling in this suite is mapped to high-probability attack paths: brute force, exposed service exploitation, and lateral movement.
- Coverage validates NIST control implementations against real-world adversary techniques.

> [!NOTE]
> Reference: [MITRE ATT&CK](https://attack.mitre.org/)

---

## 4. ENS - Esquema Nacional de Seguridad

### 4.1 Overview and Scope

The ENS (Esquema Nacional de Seguridad) is Spain's national security framework for electronic administration. Established by Royal Decree 311/2022, it defines security principles and requirements for public sector systems, classified into Basic, Medium, and High categories.

The Developmi Stack provides technical-functional equivalence for the **Medium category**, covering access control, protection, and monitoring dimensions.

### 4.2 ENS Requirements Mapping

Technical-functional equivalence means controls are satisfied by equivalent technical measures rather than a 1:1 mapping. The ENS mapping leverages the existing NIST 800-53 control implementation and evidence collection pipeline:

| ENS Dimension               | Control Family | Ansible Suite Capability                                                                          | Evidence Path                                           |
| --------------------------- | -------------- | ------------------------------------------------------------------------------------------------- | ------------------------------------------------------- |
| **Access Control (op.acc)** | AC-2           | SSH hardening (keys-only, no root), fail2ban brute-force mitigation, user account management      | `/srv/evidence/nist/ac-2/`                              |
| **Protection (op.exp)**     | SC-7, CM-7     | UFW/nftables default-deny firewall, kernel hardening, least-functionality module blacklisting     | `/srv/evidence/nist/sc-7/`, `/srv/evidence/nist/cm-7/`  |
| **Monitoring (op.mon)**     | SI-4, AU-12    | CrowdSec intrusion detection, auditd audit generation, observability stack (Prometheus + Grafana) | `/srv/evidence/nist/si-4/`, `/srv/evidence/nist/au-12/` |

### 4.3 EU Sovereignty / Cloud-Exit Context

- The same hardening baseline is portable across OCI and Hetzner bare metal, supporting cloud-exit strategies, data sovereignty, and reduced provider lock-in.
- Infrastructure-as-code (Ansible) ensures that the hardening posture is reproducible, auditable, and provider-agnostic.

> [!NOTE]
> References: [ENS CCN-CERT](https://www.ccn-cert.cni.es/) \| [ENS BOE (RD 311/2022)](https://www.boe.es/)

---

## 5. DORA - Digital Operational Resilience Act

### 5.1 Overview and Scope

DORA (Regulation EU 2022/2554) establishes a comprehensive framework for digital operational resilience in the EU financial sector.

### 5.2 DORA Requirements Mapping

Continuous monitoring and incident visibility are supported through CrowdSec and the observability stack. Operational repeatability and traceability are supported through Ansible automation and linted infrastructure-as-code.

| DORA Pillar                        | Ansible Suite Capability                                                                                                                | Evidence                                      |
| ---------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------- |
| **ICT Risk Management**            | Idempotent hardening playbooks (`playbooks/site.yml`, `playbooks/l6/engine.yml`) enforce consistent security baselines across all hosts | Playbook output, lint reports                 |
| **Incident Detection**             | CrowdSec intrusion detection with real-time alerts; observability stack (Prometheus + Grafana) for monitoring                           | CrowdSec alerts, Prometheus metrics           |
| **Incident Reporting**             | Audit trail via auditd (AU-12) and compliance playbook output; all evidence is timestamped YAML                                         | `/srv/evidence/nist/au-12/`                   |
| **Operational Resilience Testing** | Production acceptance gates verify hardening baseline before deployment; `--check --diff` dry-run mode validates no drift               | `PRODUCTION_ACCEPTANCE.md` verification gates |
| **Third-Party Risk**               | Infrastructure-as-code ensures all provider dependencies are explicitly declared and versioned in playbooks and inventories             | Inventory files, role requirements            |

> [!NOTE]
> References: [DORA Regulation (EU) 2022/2554](https://eur-lex.europa.eu/legal-content/EN/TXT/?uri=CELEX%3A32022R2554) \| [EIOPA Digital Operational Resilience](https://www.eiopa.europa.eu/browse/digital-operational-resilience-act-dora_en)

---

## 6. SOC 2 Type II (Stub)

### 6.1 Future Inclusion Rationale

SOC 2 Type II is the dominant assurance framework for SaaS platforms, covering trust service criteria for Security, Availability, Processing Integrity, Confidentiality, and Privacy. As the Developmi Stack provides a foundation for secure SaaS deployment, SOC 2 mapping is a natural extension.

### 6.2 Overlap with Implemented Frameworks

Several NIST SP 800-53 controls already implemented partially satisfy SOC 2 Common Criteria:

| SOC 2 CC  | Description                             | Overlapping NIST Control       | Status                    |
| --------- | --------------------------------------- | ------------------------------ | ------------------------- |
| **CC6.1** | Logical and physical access controls    | AC-2 (Account Management)      | Potential 1:1 mapping TBD |
| **CC6.6** | External boundary protection            | SC-7 (Boundary Protection)     | Potential 1:1 mapping TBD |
| **CC7.1** | Detection and monitoring                | SI-4 (System Monitoring)       | Potential 1:1 mapping TBD |
| **CC7.2** | Incident detection in normal operations | AU-12 (Audit Generation), SI-4 | Potential 1:1 mapping TBD |

### 6.3 Future Frameworks Evaluation

| Framework         | Rationale                                                  | Status                     |
| ----------------- | ---------------------------------------------------------- | -------------------------- |
| **ISO 27001**     | Widely recognized international standard                   | Under evaluation           |
| **SOC 2 Type II** | Service organization controls for SaaS platforms           | Under evaluation - stub    |
| **PCI DSS**       | Payment card data security (if platform handles card data) | Not applicable (currently) |

---

## 7. Evidence Collection Model

Evidence is collected automatically and on-demand according to the model defined in [EVIDENCE_MODEL.md](evidence/EVIDENCE_MODEL.md).

### 7.1 Collection Triggers

| Trigger           | Mechanism                                                                    | Schedule                                   |
| ----------------- | ---------------------------------------------------------------------------- | ------------------------------------------ |
| **Playbook run**  | `compliance.yml` with NIST control tags                                      | After each `playbooks/site.yml` deployment |
| **Cron schedule** | Systemd timer invoking `compliance.yml` nightly                              | Daily at 02:00 UTC                         |
| **Manual**        | Operator invokes `make compliance` for pre-audit evidence refresh            | On-demand                                  |
| **Post-incident** | Operator runs compliance after any security incident or configuration change | On-demand                                  |

### 7.2 Evidence YAML Format

All evidence files follow a consistent YAML structure:

```yaml
control: ac-2
host: <hostname>
timestamp: 2026-06-28T02:00:00Z
playbook: l2/compliance.yml
ansible_version: 2.20.4
checks:
  - name: <check_description>
    expected: <expected_value>
    actual: <actual_value>
    status: pass | fail
```

### 7.3 Storage Structure

```
/srv/evidence/
├── nist/             ← NIST 800-53 / ENS evidence
│   ├── ac-2/         ← Account Management
│   ├── cm-7/         ← Least Functionality
│   ├── sc-7/         ← Boundary Protection
│   ├── si-4/         ← System Monitoring
│   └── au-12/        ← Audit Generation
├── cis/              ← CIS benchmark evidence
│   ├── ssh/
│   ├── ufw/
│   └── sysctl/
└── app-specific/     ← Per-application evidence
```

**File naming convention**: `<ISO8601-timestamp>_<control-id>_<check-type>.yml`

### 7.4 Verification Checklist

An auditor confirms evidence is current and complete by:

1. **Check recency**: Evidence files should be ≤ 24 hours old for daily collections.
2. **Run dry-run compliance playbook**: Confirms no configuration drift (`ansible-playbook playbooks/l2/compliance.yml --check --diff`).
3. **Cross-reference against control list**: Verify all NIST controls have corresponding evidence files.
4. **Validate YAML syntax**: All evidence reports must be valid YAML (`yamllint /srv/evidence/`).

### 7.5 Retention Policies

| Data Type                 | Retention Period | Rotation Policy                           |
| ------------------------- | ---------------- | ----------------------------------------- |
| **Daily evidence**        | 30 days          | Delete files older than 30 days via cron  |
| **Weekly snapshots**      | 90 days          | Keep one snapshot per week for 13 weeks   |
| **Monthly snapshots**     | 1 year           | Keep one snapshot per month for 12 months |
| **Audit-ready snapshots** | Indefinite       | Manual archiving before formal audits     |

---

## 8. Tag and Layer Conventions

### 8.1 Layer Tag Mapping

| Layer Tag          | Controls Covered              |
| ------------------ | ----------------------------- |
| `l2-compliance`    | AC-2, CM-7, SC-7, SI-4, AU-12 |
| `l3-observability` | SI-4 (monitoring)             |

Controls are tagged using `nist,ac-2` / `cis,1.1` format per the `hardening_profile` dispatcher. For the complete tagging model, see [ARCHITECTURE.md §3](../architecture/ARCHITECTURE.md#layer-4-compliance-networking).

---

## 9. Residual Risk Notes

- SC-28 full-disk encryption remains an external provisioning responsibility.
- A mapped control does not imply legal certification readiness without contextual validation and evidence collection.
- Regulatory mappings are technical and implementation-centric by design.

---

## 10. Cross-References

- [NIST_800_53.md](NIST/NIST_800_53.md) - Control → Role → Evidence traceability details
- [NIST_800_171.md](NIST/NIST_800_171.md) - CUI mapping (TBD)
- [EVIDENCE_MODEL.md](evidence/EVIDENCE_MODEL.md) - Evidence collection, verification, and retention details
- [PRODUCTION_ACCEPTANCE.md](evidence/PRODUCTION_ACCEPTANCE.md) - Production acceptance gates and verification criteria
- [../architecture/ARCHITECTURE.md](../architecture/ARCHITECTURE.md) - 7-layer model with compliance integration
- [../security/HARDENING-STATUS.md](../security/HARDENING-STATUS.md) - hardening_profile dispatcher information
