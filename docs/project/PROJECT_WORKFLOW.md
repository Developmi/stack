---
title: Project Workflow Onboarding
type: project
owner: maintainers
audience: maintainer
version: v6.0.0
last-reviewed: 2026-07-16
status: active
project: developmi-stack
repo: github.com/Developmi/stack
---

# Project Workflow Onboarding

How to navigate the SDD workflow, documentation ecosystem, and project conventions. For developer setup (clone, install, run playbooks), see [the operations onboarding](../operations/DEVELOPER_SETUP.md).

---

## Quick Start: Find Your Path

| I want to...                               | Start here                                                                         |
| ------------------------------------------ | ---------------------------------------------------------------------------------- |
| Understand the platform architecture       | [../architecture/ARCHITECTURE.md](../architecture/ARCHITECTURE.md)                 |
| Set up my development environment          | [../operations/DEVELOPER_SETUP.md](../operations/DEVELOPER_SETUP.md)               |
| Understand SDD workflow terms              | [GLOSSARY.md](../GLOSSARY.md)                                                      |
| Know how docs are organized                | [ARCHITECTURE.md](../architecture/ARCHITECTURE.md)                                 |
| Find all related documents                 | [README.md](../README.md)                                                          |
| Contribute documentation                   | [CONTRIBUTORS_DOC_GUIDE.md](CONTRIBUTORS_DOC_GUIDE.md)                             |
| Understand the 10 architectural principles | [../architecture/ARCHITECTURE.md](../architecture/ARCHITECTURE.md) §4              |
| See all architecture decisions             | [../architecture/adr/](../architecture/adr/)                                       |
| Deploy applications                        | [ARCHITECTURE.md](../architecture/ARCHITECTURE.md) §8 (Application Profile Schema) |

---

## I'm a Maintainer

### Reading Path

1. [../architecture/ARCHITECTURE.md](../architecture/ARCHITECTURE.md) - 7-layer model, 10 principles, OS matrix, host classes
2. [../GLOSSARY.md](../GLOSSARY.md) - Platform terminology
3. [ARCHITECTURE.md](../architecture/ARCHITECTURE.md) - Documentation conventions
4. [CODEOWNERS](../../.github/CODEOWNERS) - Who owns which files and directories
5. Domain-specific docs in `docs/architecture/`, `docs/compliance/`, `docs/operations/`

---

## I'm a Contributor

### Reading Path

1. [../CONTRIBUTING.md](../../CONTRIBUTING.md) - Contribution standards (canonical)
2. [CONTRIBUTORS_DOC_GUIDE.md](CONTRIBUTORS_DOC_GUIDE.md) - How to contribute documentation
3. [ARCHITECTURE.md](../architecture/ARCHITECTURE.md) - Conventions to follow
4. [GLOSSARY.md](../GLOSSARY.md) - Project terms

---

## I'm an Operator

### Reading Path

1. [../operations/DEVELOPER_SETUP.md](../operations/DEVELOPER_SETUP.md) - Developer setup
2. [../operations/INCIDENT_RESPONSE_DR.md](../operations/INCIDENT_RESPONSE_DR.md) - Incident response and disaster recovery runbooks
3. [../operations/VERSION_PINS.md](../operations/VERSION_PINS.md) - Pinned component versions
4. [../architecture/ARCHITECTURE.md](../architecture/ARCHITECTURE.md) - Architecture reference

---

## Owner Responsibilities

Every documentation artifact in the Developmi Stack has an assigned owner (documented in `.github/CODEOWNERS`) responsible for its accuracy, review cadence, and lifecycle.

1. **Accuracy**: The owner ensures the document's technical content is correct and aligned with the current implementation.
2. **Review**: The owner reviews the document at the specified cadence and updates the `last-reviewed` date in its frontmatter.
3. **Lifecycle**: The owner decides when a document is deprecated, archived, or superseded.
4. **Cross-References**: The owner ensures related documents and cross-references are updated when content changes.

---

## Related Documents

- [../operations/DEVELOPER_SETUP.md](../operations/DEVELOPER_SETUP.md) - Developer environment setup
- [GLOSSARY.md](../GLOSSARY.md) - SDD/project workflow terminology
- [ARCHITECTURE.md](../architecture/ARCHITECTURE.md) - Documentation conventions
- [README.md](../README.md) - Full document relationship matrix
