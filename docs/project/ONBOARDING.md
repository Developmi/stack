---
title: Onboarding Guide
type: project
owner: maintainers
audience: all
version: v6.0.0
last-reviewed: 2026-07-16
status: active
project: developmi-stack
repo: github.com/Developmi/stack
---

# Onboarding Guide

Welcome to the Developmi Stack documentation. This guide helps you find the right reading path based on who you are and what you need.

---

## Start Here (If You're Not Sure)

If you don't identify with any of the personas below, here's a quick-reference table to help you find your starting point:

| I want to...                        | Start with                                                             |
| ----------------------------------- | ---------------------------------------------------------------------- |
| Understand what this project is     | [README.md](../../README.md) (root)                                    |
| See all available documentation     | [docs/README.md](../README.md)                                         |
| Understand the terminology          | [GLOSSARY.md](../GLOSSARY.md)                                          |
| Understand the v2 migration plan    | (archived - see ARCHITECTURE.md)                                       |

When in doubt, start with the [root README](../../README.md) - it explains what the project is for all audiences.

---

## Which Best Describes You?

Below are three reading paths tailored to the most common reader personas. Pick the one that fits.

---

## I'm a Maintainer

**Who this is for:** You own one or more documentation domains, manage releases, review PRs, or are responsible for the project's direction.

### Suggested Reading Order

1. **[ARCHITECTURE.md](../architecture/ARCHITECTURE.md)** - Understand the system: Layer 1-6 OS security model, network architecture, tech decisions, and NIST control implementation. This is the foundational document - you need to understand what the system IS before anything else.

2. **[GLOSSARY.md](../GLOSSARY.md)** - Learn the terminology. Critical: understand the brain↔Layer 0 and muscle↔Layer 1 terminology conflicts between current docs and v2 architecture.

3. **[PROJECT_WORKFLOW.md](PROJECT_WORKFLOW.md)** - Find your domain ownership. See which documents you are responsible for and their review cadence.

4. Your Owned Domain Documentation - Deep-dive your specific area:
   - Architecture owner → `docs/architecture/`, `docs/compliance/`
   - Operations owner → `docs/operations/`
   - Project governance owner → `docs/project/`
   - v2 planning owner → `docs/architecture/` (v2 content absorbed into ARCHITECTURE.md)

5. **[RELEASE.md](RELEASE.md)** - Learn the release procedure: pre-release validation, commit conventions, version bumping strategy, and post-release monitoring.

6. **[ROADMAP.md](ROADMAP.md)** - Understand the v5.5.0 priorities and the v2 strategic direction. See how current work connects to the long-term platform vision.

### What You'll Know After

- The full system architecture (Layer 1-6 OS security model)
- The terminology bridge between current and v2 docs
- Documentation conventions and standards
- Which documents you own and their review cadence
- The release process and quality gates
- The strategic direction (v5.5.0 + v2)

---

## I'm a Contributor

**Who this is for:** You want to submit documentation changes, code contributions, or bug reports. You're interested in the contribution workflow and project standards.

### Suggested Reading Order

1. **[CONTRIBUTING.md](../../CONTRIBUTING.md) (root)** - Canonical contribution guide. Start here to understand the workflow and standards.

2. **[CONTRIBUTORS_DOC_GUIDE.md](CONTRIBUTORS_DOC_GUIDE.md)** - Documentation-specific contribution guide: how to add a new doc, update cross-references, add glossary terms, and meet frontmatter requirements.

3. **[CODE_OF_CONDUCT.md](../../CODE_OF_CONDUCT.md)** - Community guidelines and expected behavior.

### What You'll Know After

- How to set up the development environment
- Commit message format and branch naming conventions
- PR workflow and review expectations
- How to contribute documentation (new docs, updates, glossary terms)
- Frontmatter and cross-linking requirements
- Code style, security, and NIST compliance requirements for contributions

### Optional Deep Dives

- [GLOSSARY.md](../GLOSSARY.md) - Terminology to use in your contributions
- [PROJECT_WORKFLOW.md](PROJECT_WORKFLOW.md) - Who reviews docs in each domain

---

## I'm an Operator

**Who this is for:** You run the Developmi Stack in production or lab environments. You deploy, verify, troubleshoot, and maintain the hardened infrastructure.

### Suggested Reading Order

1. **[README.md](../../README.md) (root)** - What this project is, quick start, operations with Make, and compliance overview. Start here for the operational context.

2. **[docs/README.md](../README.md)** - Documentation index. Find all operations documentation at a glance.

3. **[OPERATIONS_RUNBOOK.md](../operations/OPERATIONS_RUNBOOK.md)** - The definitive operations runbook: commands, audit, deployment, boot sequence, restart, rotation, and troubleshooting. This is your primary runbook.

4. **[COMPATIBILITY_MATRIX.md](../operations/COMPATIBILITY_MATRIX.md)** - Tested OS and architecture support matrix. Verify your platform is supported before deployment.

5. **[OPERATIONS_RUNBOOK.md §2](../operations/OPERATIONS_RUNBOOK.md)** - Production audit checklist (§2). Run through this before and after deployments to validate command execution paths.

6. **[EMERGENCY_ACCESS.md](../operations/EMERGENCY_ACCESS.md)** - Console/rescue recovery procedures. Critical for Phase 07 (Disable Root SSH). Know how to recover if SSH is misconfigured.


### What You'll Know After

- How to set up, deploy, and verify the hardening suite
- All available `make` targets and their usage
- Which OS platforms are supported
- How to audit command execution in production
- Emergency recovery procedures (console/rescue access)

### Optional Deep Dives

- [ARCHITECTURE.md](../architecture/ARCHITECTURE.md) - Understand the security layers you're deploying
- [compliance/INDEX.md](../compliance/INDEX.md) - Compliance framework matrix and controls overview
- [compliance/evidence/EVIDENCE_MODEL.md](../compliance/evidence/EVIDENCE_MODEL.md) - Evidence collection and retention model
- [GLOSSARY.md](../GLOSSARY.md) - Terminology reference

---

## Related Documents

- [README.md](../README.md) - Documentation index
- [GLOSSARY.md](../GLOSSARY.md) - Terminology definitions and bridge
- [CONTRIBUTING.md](../../CONTRIBUTING.md) - Canonical contribution guide
- [CONTRIBUTORS_DOC_GUIDE.md](CONTRIBUTORS_DOC_GUIDE.md) - Documentation contribution guide
