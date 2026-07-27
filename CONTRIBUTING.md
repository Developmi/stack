---
title: Contributing Guide
last_updated: 2026-06-20
owner: TBD
audience: contributor
status: complete
---

# Contributing to NIST-Compliant Hardening Suite

Thank you for your interest in contributing to the NIST-Compliant Hardening Suite! This document provides guidelines and instructions for contributing.

## Code of Conduct

By participating in this project, you agree to abide by our [Code of Conduct](CODE_OF_CONDUCT.md).

## How to Contribute

### Reporting Bugs

- Use the GitHub Issues tracker.
- Describe the bug in detail: steps to reproduce, expected behavior, actual behavior.
- Include relevant logs, error messages, and system information.
- Include environment details: OS, runtime version, Ansible version.

### Suggesting Enhancements

- Open an issue with the "enhancement" label.
- Describe the feature, its use case, and potential implementation approach.

### Submitting Pull Requests

1. Fork the repository.
2. Create a feature branch (`git checkout -b feature/your-feature`).
3. Make your changes, following the code style and conventions.
4. Write or update tests as necessary.
5. Ensure your code passes `ansible-lint` and `yamllint`.
6. Commit your changes with descriptive Conventional Commit-style messages.
7. Push to your fork and open a pull request.

A maintainer will review within 5 business days.

### Branch Naming

Use the following branch naming convention:

```
feat/short-description
fix/issue-number-description
docs/update-readme
chore/bump-dependencies
refactor/simplify-module
perf/optimize-playbook
test/add-molecule-tests
```

### Commit Standard

This project uses [Conventional Commits](https://www.conventionalcommits.org/):

```
feat: add new endpoint for user authentication
fix: resolve memory leak in connection pool
docs: update README with Docker instructions
chore: bump eslint to v9.x
refactor: simplify Ansible module structure
perf: optimize playbook execution
test: add integration tests for playbooks/nuke.yml
```

Append `!` for breaking changes:

```
feat!(tailscale): require OAuth credentials for ACL automation
fix!(portainer): remove legacy edge key variable
```

Types: `feat` · `fix` · `docs` · `chore` · `refactor` · `perf` · `test`

## Development Setup

### Prerequisites

- Python 3.14+
- uv
- Docker (for testing container roles)
- Pre-commit hooks
- GNU Make

### Local Testing

#### Install Development Environment

```bash
# Sync local toolchain
make sync

# Install required Ansible collections
make install-collections

# Install pre-commit hooks
make precommit-install
```

#### Run Local Validation

````bash
# Run all pre-commit hooks
make precommit-run

# OR run individual checks:

# Strict lint gate for selected playbook
make lint PLAYBOOK=playbooks/site.yml

# Validate setup and playbook syntax checks
make validate

# Compliance evidence-only execution
make compliance

# Targeted deployments
make deploy-tags PLAYBOOK=playbooks/site.yml ANSIBLE_TAGS='nist,sc-7'

# Playbook syntax check
make dry-run PLAYBOOK=playbooks/stacks.yml

# Inventory validation
make show-inventory

# Test playbook structure (dry-run with check mode)
make dry-run PLAYBOOK=playbooks/stacks.yml

# Secret Detection Baseline
If detect-secrets reports false positives (e.g., example values in comments), update the baseline:
```bash
uv run detect-secrets scan --baseline .secrets.baseline $(git ls-files)
git add .secrets.baseline
````

#### Automated Testing with GitHub Actions

All pull requests automatically trigger:

1. **Ansible Lint** - Playbook quality checks
2. **YAML Lint** - YAML syntax and style validation
3. **Secret Detection** - Prevent credential commits
4. **Security Audit** - NIST 800-53 control verification
5. **Container Scanning** - Docker Compose security practices
6. **Documentation Validation** - Consistency checks

See `.github/workflows/` for workflow definitions.

## Code Style and Conventions

### Ansible Best Practices

- Use `ansible.builtin` modules when possible.
- Keep roles focused and single-purpose.
- Use meaningful variable names with descriptive comments.
- Follow Ansible Galaxy metadata standards.

### YAML Formatting

- Use 2-space indentation.
- Use consistent spacing around colons and dashes.
- Keep line length under 100 characters where possible.

### Documentation

- Update README.md when adding new features.
- Document new variables in `group_vars/all/secrets.yml.example`.
- Include inline comments for complex logic.

## Security Considerations

### Secrets Management (SC-28 Compliance)

**Critical Rule: NEVER commit real secrets to any branch.**

#### Handling Secrets Correctly

```bash
# ❌ WRONG - This exposes the secret
portainer_edge_keys_by_node:
   brain-1: "abcd1234xyz"

# ✅ RIGHT - Use Ansible Vault
ansible-vault encrypt group_vars/all/secrets.yml
# Then reference: {{ portainer_edge_keys_by_node[inventory_hostname] }} (decrypted at runtime only)
```

#### Secret Detection Automated Protection

This repository uses `detect-secrets` to prevent accidental commits:

- **Local pre-commit hooks** – Block commits with exposed secrets before they reach Git
- **GitHub Actions CI** – Secondary check on every PR
- **`.secrets.baseline`** – Configuration to ignore false positives (e.g., example values in docs)

If you see "Potential secrets detected in commit" error:

1. **Remove the secret** from the file immediately
2. **Use Ansible Vault** to encrypt sensitive data:
   ```bash
   make vault-encrypt
   ```
3. **Update baseline** if it's a legitimate false positive:
   ```bash
   uv run detect-secrets scan --baseline .secrets.baseline $(git ls-files)
   ```

### Critical Requirements

- **Never commit secrets or sensitive data** – detect-secrets runs on every commit
- **Use Ansible Vault** for all encrypted variables (`ansible-vault encrypt`)
- **Validate all inputs** and use secure defaults
- **Follow principle of least privilege** – no root/privileged default containers
- **Idempotence is mandatory** – tasks must produce same result on multiple runs
- **Document security decisions** – explain why choices were made

### NIST 800-53 Compliance

All code contributions must maintain compliance with implemented NIST controls:

- **AC-2** (Account Management): SSH hardening, password policies
- **CM-7** (Least Functionality): Disable unnecessary services/modules
- **SC-7** (Boundary Protection): Firewall rules, network isolation
- **SI-4** (System Monitoring): CrowdSec, auditd required
- **AU-12** (Audit Logging): Comprehensive audit trail
- **SC-28** (Data at Rest): Vault encryption required

### Container Security Standards

- All containers must have `security_opt: [no-new-privileges:true]`
- Docker socket mounts are high-risk and must only be used when operationally required, with explicit risk documentation
- Containers should run as unprivileged users (uid 65534 minimum)
- Resource limits must be defined (CPU, memory)
- Never run as root unless architecturally necessary

## Review Process

- All pull requests require at least one maintainer review.
- Changes must pass CI checks (ansible-lint, yamllint).
- Documentation updates are required for new features.
- Breaking changes require major version updates.

## Questions?

Feel free to reach out via GitHub Issues or discussions.

Thank you for helping make this project better!

## Related Documents

- [CONTRIBUTORS_DOC_GUIDE.md](CONTRIBUTORS_DOC_GUIDE.md) - How to contribute documentation specifically
- [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) - Community guidelines
- [RELEASE.md](RELEASE.md) - Release process and quality gates
- [DOC_ARCHITECTURE.md](../DOC_ARCHITECTURE.md) - Documentation conventions
- [GLOSSARY.md](../GLOSSARY.md) - Terminology definitions
