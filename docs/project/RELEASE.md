---
title: Release Procedure
type: project
owner: maintainers
audience: maintainer
version: v6.0.0
last-reviewed: 2026-07-16
status: active
project: developmi-stack
repo: github.com/Developmi/stack
---

# Release Procedure

Current latest release: `v6.0.0` (see [CHANGELOG.md](../../CHANGELOG.md) for the full history).

This document defines the standard process for all future releases.

## Automated Pre-Release Validation

All releases must pass automated checks before publication:

### Local Security Audit (Run Before Tagging)

Run this exact block locally before creating and pushing a tag:

```bash
# 1. Sync local toolchain
make sync

# 2. Validate detect-secrets baseline (tracked files only)
uv run detect-secrets scan --baseline .secrets.baseline $(git ls-files) > /dev/null

# 3. Ensure encrypted runtime secrets are not tracked
if git ls-files --error-unmatch group_vars/all/secrets.yml >/dev/null 2>&1; then
  echo "ERROR: group_vars/all/secrets.yml is tracked in git"
  exit 1
fi

# 4. Scan for high-risk hardcoded secret signatures
if rg -n --hidden -g '!.git' -g '!**/.venv/**' \
  -e 'ghp_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|AKIA[0-9A-Z]{16}|ASIA[0-9A-Z]{16}|-----BEGIN (RSA|OPENSSH|EC|DSA) PRIVATE KEY-----|xox[baprs]-[A-Za-z0-9-]{10,}' ; then
  echo "ERROR: Potential hardcoded secrets detected"
  exit 1
fi

# 5. Dependency vulnerability scan
uvx pip-audit -r requirements.txt
```

The GitHub `Security Audit` workflow now runs on tag pushes (`v*`) and `workflow_dispatch`.
Keeping the same commands locally prevents most remote tag audit failures.

```bash
# 1. Run full CI/CD pipeline
make precommit-run

# 2. Verify no secrets in codebase
uv run detect-secrets scan --baseline .secrets.baseline $(git ls-files)

# 3. Lint playbooks & YAML (scans all playbooks automatically - no PLAYBOOK= argument)
make lint

# 4. Syntax validation
make validate
uv run ansible-playbook --syntax-check playbooks/ops/nuke.yml
uv run ansible-inventory -i inventory/hosts.ini --list > /dev/null

# 5. Idempotence test (run twice, both should be identical)
make dry-run PLAYBOOK=playbooks/l6/engine.yml
make dry-run PLAYBOOK=playbooks/l6/engine.yml
```

GitHub Actions will automatically run the security audit on version tags.

## Manual Release Steps

### 1. Prepare Release Branch

```bash
git checkout master
git pull origin master
git checkout -b release/vX.Y.Z
```

### 2. Verify Documentation

- [ ] README.md is accurate and NIST claims match implementation
- [ ] docs/architecture/ARCHITECTURE.md reflects actual system design
- [ ] ../../CHANGELOG.md documents all changes for this release
- [ ] All links are valid (no broken references)

### 2.1 Organize Atomic Commits Before Release

Use small, logically grouped commits before the final release commit.
The repository history already follows Conventional Commit-style prefixes and releases should keep that convention:

- `feat:` for backwards-compatible features
- `fix:` for backwards-compatible bug fixes
- `docs:` for documentation-only changes
- `chore:` for tooling, config, or maintenance work
- `refactor:` for internal restructuring without behavior change
- `feat!:` or `fix!:` when a change is breaking for operators or consumers

Examples:

```bash
git commit -m "fix(ansible): use ansible_facts namespace across roles"
git commit -m "feat(ingress): add tracked Caddyfile example template"
git commit -m "feat!(tailscale): require OAuth client credentials for ACL automation"
```

### 3. Run All Validation (see above)

Complete all automated checks. All must pass before proceeding.

### 4. Create Release Commit and Tag

```bash
git commit -m "Release vX.Y.Z: Developmi Stack

Highlights:
- [add release highlights]
- [add compatibility/security changes]
- [add docs/ops improvements]

Validation:
- Quality gates passed with uv-managed toolchain
- Docs updated (README, ROADMAP, CHANGELOG)

See ../../CHANGELOG.md for full details."

git tag -a vX.Y.Z -m "Developmi Stack vX.Y.Z"
git push origin release/vX.Y.Z
git push origin vX.Y.Z
```

### 5. Create GitHub Release

1. Go to Releases → Create New Release
2. Title: `Developmi Stack vX.Y.Z`
3. Notes: Copy the corresponding `CHANGELOG.md` section
4. Set as latest release
5. Save & publish

## Post-Release Monitoring

- [ ] Monitor GitHub Issues for early adopter feedback
- [ ] Check GitHub Discussions for user questions
- [ ] Verify security reports arrive via proper channels
- [ ] Plan next patch/minor iteration based on feedback

## Version Bumping Strategy

Follow semantic versioning:

- **v5.5.0** - Feature bundles (recommended apps, security hardening, new capabilities - no breaking changes)
- **v5.5.1** - Security patches or operational fixes only (no new features)
- **v5.6.0** - New features, backwards compatible
- **v6.0.0** - Breaking changes, including operator-facing config/tooling migrations

Practical mapping for this repository:

- `fix:` only and no operator-visible behavior change: bump `PATCH`
- `feat:` with backwards-compatible variables/behavior: bump `MINOR`
- `feat!:` or any release requiring config migration or removing a supported path: bump `MAJOR`

---

**Note:** All releases require passing GitHub Actions security audit workflow.

## Related Documents

- [CHANGELOG.md](../../CHANGELOG.md) - Release history
- [ROADMAP.md](ROADMAP.md) - Planned evolution and priorities
- [CONTRIBUTING.md](../../CONTRIBUTING.md) - Contribution standards
- [PROJECT_WORKFLOW.md](PROJECT_WORKFLOW.md) - Document ownership and review cadence
