---
title: Contributor's Documentation Guide
type: project
owner: maintainers
audience: contributor
version: v6.0.0
last-reviewed: 2026-07-16
status: active
project: developmi-stack
repo: github.com/Developmi/stack
---

# Contributor's Documentation Guide

This guide is the Single Source of Truth (SSOT) for writing, organizing, formatting, and linking documentation in the **Developmi Stack**. It combines our documentation architecture, formatting conventions, cross-reference maps, and step-by-step contribution workflows.

> **For code contributions** (Ansible playbooks, roles, scripts, Docker configs), see the root `CONTRIBUTING.md`. This guide covers **documentation changes only**.

---

## 1. Documentation Architecture

The documentation is organized by audience and operational intent to prevent fragmentation.

### Directory Purposes & Decision Tree

Use this logic to determine where a document belongs:

| Primary Audience / Intent | Directory | Examples |
| :--- | :--- | :--- |
| **Everyone** (Cross-cutting reference) | `docs/` (root) | `GLOSSARY.md`, `ONBOARDING.md` |
| **Maintainers / Governance** | `docs/project/` | `CONTRIBUTORS_DOC_GUIDE.md`, `ROADMAP.md` |
| **Operators** (Day-to-day running) | `docs/operations/` | `OPERATIONS_RUNBOOK.md`, `COMPATIBILITY_MATRIX.md` |
| **Auditors** (Frameworks & Evidence) | `docs/compliance/` | `COMPLIANCE-MAPPING-STATUS.md`, `EVIDENCE_MODEL.md` |
| **Architects** (System Design) | `docs/architecture/` | `ARCHITECTURE.md`, `ADR-*.md` |

**Exception rule:** If a document serves multiple audiences equally, place it at the `docs/` root.

---

## 2. Standards & Conventions

### SSOT & Content Reuse Strategy
**Never duplicate knowledge.** If information exists in one document, link to it. 
*   **Term definitions:** Belong *only* in `GLOSSARY.md`.
*   **Doc conventions:** Belong *only* in this guide.
*   **If you need context:** Write a 1-sentence summary and provide a standard cross-reference link.

### File Naming Convention
*   `docs/` root, single-word: `UPPER_CASE.md` (e.g., `GLOSSARY.md`)
*   `docs/` root, multi-word: `UPPER_CASE_UNDERSCORE.md` (e.g., `EMERGENCY_ACCESS.md` - grandfathered)
*   Subdirectories: `SCREAMING_SNAKE_CASE.md` or `lowercase-kebab-case.md` depending on established patterns in that specific folder.

### Frontmatter Requirement
Every document **MUST** start with YAML frontmatter.

```yaml
---
title: Your Document Title
last_updated: YYYY-MM-DD
owner: Team/Role (or TBD)
audience: all|maintainer|contributor|operator
status: active|draft|deprecated
project: developmi-stack
version: vx.x.x
---

```

### Markdown Formatting

* **Headings:** Exactly one `#` heading per file (matching the `title`). Use `##` for sections, `###` for subsections.
* **Code Blocks:** Always specify a language tag (e.g., `bash`, `yaml`, `json`).
* **Tables:** Use standard pipe-aligned columns.
* **Line Length:** Keep prose lines under 120 characters where practical.
* **Related Documents:** Every document MUST end with a `## Related Documents` section.

---

## 3. Contribution Workflows

### How to Add a New Document

1. **Determine location:** Use the directory decision tree above.
2. **Name & frontmatter:** Apply the naming convention and required YAML block.
3. **Write content:** Follow the markdown and SSOT standards.
4. **Add Related Documents:** Append cross-references at the end of the file.
5. **Update Maps:** Add the file to the Cross-Reference Map (Section 4) and Ownership Registry.
6. **Update Glossary:** If you introduce new platform concepts, add them to `docs/GLOSSARY.md`.

### How to Update an Existing Document

1. Review frontmatter to understand audience and status.
2. Make changes, update the `last_updated` date to today.
3. If adding links, follow the strict cross-reference format and verify target existence.

---

## 4. Cross-Reference Map & Linking

### Link Format Standard

All cross-references must use relative paths and include a brief "why" explanation:

[Visible Text](../relative/path.md) - Brief explanation of why the document is related


### Link Validation

Before submitting a PR, verify all links resolve from the repository root:

```bash
find docs/ -name "*.md" -exec grep -oP '\[.*?\]\(\./[^)]+\)' {} \;

```

### Document Relationship Matrix

Use this map to understand how domains connect. Ensure you update this when adding new files.

| Document | Directory | Key Relationships | Type |
| --- | --- | --- | --- |
| `GLOSSARY.md` | `docs/` | `ARCHITECTURE.md`, `CONTRIBUTORS_DOC_GUIDE.md` | Peer |
| `ONBOARDING.md` | `docs/` | `README.md`, `GLOSSARY.md`, `ROADMAP.md` | Peer |
| `ARCHITECTURE.md` | `docs/architecture/` | `GLOSSARY.md`, `compliance/NIST/INDEX.md` | Parent |
| `COMPLIANCE-MAPPING.md` | `docs/compliance/` | `EVIDENCE_MODEL.md`, `NIST/NIST_800_53.md` | Parent |
| `EVIDENCE_MODEL.md` | `docs/compliance/` | `COMPLIANCE-MAPPING.md`, `PRODUCTION_ACCEPTANCE.md` | Child |
| `OPERATIONS_RUNBOOK.md` | `docs/operations/` | `COMPATIBILITY_MATRIX.md`, `INCIDENT_RESPONSE_DR.md` | Parent |
| `CONTRIBUTORS_DOC_GUIDE` | `docs/project/` | `CONTRIBUTING.md`, `GLOSSARY.md` | Child |
| `ROADMAP.md` | `docs/project/` | `CHANGELOG.md`, `RELEASE.md` | Parent |

*(Note: Relationship types are **Parent** [introduces/indexes children], **Child** [expands on parent], or **Peer** [same level of detail]).*

---

## 5. Maintenance & Review Cadence

Documents must be reviewed periodically to prevent staleness.

| Document Type | Review Frequency | Trigger |
| --- | --- | --- |
| Architecture (`docs/architecture/`) | Quarterly | Major architectural/Layer changes |
| Operations (`docs/operations/`) | Biannual | Post-incident or major deployment updates |
| Compliance (`docs/compliance/`) | Quarterly | Regulatory framework updates |
| Project (`docs/project/`) | Per release | Version bumps (e.g., v6.0 to v7.0) |
| Meta (`docs/` root) | Quarterly | Convention shifts |

**Stale Document Flagging:**
A document is stale if its `last_updated` date exceeds its cadence, references an old major version, or contains broken links.

---

## 6. Recommended Reading Paths

* **New to the Suite:** `README.md` (root) → `docs/ONBOARDING.md` → Persona-specific path.
* **Troubleshooting Deployment:** `OPERATIONS_RUNBOOK.md` → `COMPATIBILITY_MATRIX.md` → `EMERGENCY_ACCESS.md`.
* **Compliance Audit:** `COMPLIANCE-MAPPING-STATUS.md` → `NIST_800_53.md` → `EVIDENCE_MODEL.md`.

---

## Related Documents

* [GLOSSARY.md](../GLOSSARY.md) - Developmi Stack terminology definitions
* [ONBOARDING.md](ONBOARDING.md) - Persona-based reading paths
* [README.md](/README.md) - Project entry point
