---
title: Documentation Index
type: project
owner: maintainers
audience: all
version: v6.0.0
last-reviewed: 2026-07-26
status: active
project: developmi-stack
repo: github.com/Developmi/stack
---

# Documentation Index

This folder centralizes project documentation by objective and operational domain.

---

## Quick Start

The Developmi Stack is an enterprise-grade Ansible hardening framework for NIST-aligned Debian and Ubuntu infrastructure. If you're new:

- **I want to run this suite** → Start with the [root README](../README.md), then [OPERATIONS_RUNBOOK.md](operations/OPERATIONS_RUNBOOK.md)
- **I want to contribute** → Start with [CONTRIBUTING.md](../CONTRIBUTING.md)
- **I maintain this project** → Start with [PROJECT_WORKFLOW.md](project/PROJECT_WORKFLOW.md)
- **I need to understand the architecture** → Start with [ARCHITECTURE.md](architecture/ARCHITECTURE.md)
- **How are applications managed?** → Application state and deployment (L5) are completely agnostic. Developers can manage their apps via Portainer, raw Docker Compose via SSH, or future orchestrators (Swarm, K8s, K3s).

For all available documentation, see the directory listing below.

---

## Structure

### Architecture

- [architecture/ARCHITECTURE.md](architecture/ARCHITECTURE.md): system design, security layers (L1-L6), and core technical decisions.

### Operations

- [operations/OPERATIONS_RUNBOOK.md](operations/OPERATIONS_RUNBOOK.md): definitive operations runbook - command reference, production audit, app deployment, boot sequence, restart, rotation, and troubleshooting.
- [operations/INCIDENT_RESPONSE_DR.md](operations/INCIDENT_RESPONSE_DR.md): incident response and disaster recovery runbook.
- [operations/DEVELOPER_SETUP.md](operations/DEVELOPER_SETUP.md): operator environment setup guide.

### Emergency Access

- [operations/EMERGENCY_ACCESS.md](operations/EMERGENCY_ACCESS.md): console/rescue recovery procedures for Phase 07.

### Compliance

- [compliance/INDEX.md](compliance/INDEX.md): compliance framework matrix and structure overview.
- [compliance/COMPLIANCE-MAPPING-STATUS.md](compliance/COMPLIANCE-MAPPING-STATUS.md): master framework mapping status (NIST, CIS, ENS, DORA, SOC 2).
- [compliance/evidence/EVIDENCE_MODEL.md](compliance/evidence/EVIDENCE_MODEL.md): evidence collection and retention model.

### Project & Community

- [project/ROADMAP.md](project/ROADMAP.md): planned evolution and priorities.
- [../CHANGELOG.md](../CHANGELOG.md): release history.
- [project/RELEASE.md](project/RELEASE.md): release process and quality gates.
- [project/CONTRIBUTORS_DOC_GUIDE.md](project/CONTRIBUTORS_DOC_GUIDE.md): how to contribute documentation.
- [project/PROJECT_WORKFLOW.md](project/PROJECT_WORKFLOW.md): project workflow and owner responsibilities.
- [../CONTRIBUTING.md](../CONTRIBUTING.md): contribution standards (canonical).
- [../CODE_OF_CONDUCT.md](../CODE_OF_CONDUCT.md): community guidelines.

### Reference

- [GLOSSARY.md](GLOSSARY.md): terminology definitions and concept mapping.

---

## Related Documents

- [GLOSSARY.md](GLOSSARY.md) - Terminology definitions
- [../CONTRIBUTING.md](../CONTRIBUTING.md) - Contribution standards
- [../README.md](../README.md) (root) - Project-level README