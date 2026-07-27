---
title: Security Policy
last_updated: 2026-06-20
owner: TBD
audience: all
status: complete
---

# Security policy

## Supported versions

| Version | Supported              |
| ------- | ---------------------- |
| 5.2.x   | ✅ Yes                 |
| 5.1.x   | ✅ Yes                 |
| 5.0.x   | ✅ Yes                 |
| 4.x     | ⚠️ Security fixes only |
| < 4.0   | ❌ No                  |

## Reporting a vulnerability

**Do not open a public GitHub issue for security vulnerabilities.**

Report vulnerabilities privately via one of these channels:

- **GitHub Security Advisories:** [Report a vulnerability](https://github.com/Developmi/stack/security/advisories/new)
- **Email:** miguel@developmi.com - encrypt with PGP if the finding is critical.

Include in your report:

- Description of the vulnerability and its potential impact.
- Steps to reproduce or a proof-of-concept.
- Affected versions.
- Any suggested mitigations.

## Response timeline

| Stage              | Target time                |
| ------------------ | -------------------------- |
| Acknowledgment     | 48 hours                   |
| Initial assessment | 5 business days            |
| Fix or mitigation  | 30 days (critical: 7 days) |
| Public disclosure  | After fix is available     |

## Disclosure policy

This project follows coordinated disclosure. We ask that you give us reasonable time to address the vulnerability before public disclosure. We will credit reporters in the release notes unless anonymity is requested.

## Scope

This policy covers the Ansible playbooks, roles, templates, and Docker Compose configurations in this repository. It does not cover:

- Vulnerabilities in upstream dependencies (report those to the respective maintainers).
- Misconfigurations in user deployments that deviate from documented procedures.
- Social engineering or phishing attacks against individual contributors.

## Related Documents

- [docs/compliance/COMPLIANCE.md](docs/compliance/INDEX.md) - Executive compliance overview
