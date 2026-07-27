# L1 OS Baseline - Ubuntu 22.04

| Field | Value |
|-------|-------|
| Status | `supported` |
| Last validated | 2026-07-07 |
| Ansible version | 2.20.4 |
| Distribution | Ubuntu 22.04 (Jammy) |
| Package manager | apt |

## Key differences from other variants

- **Universe repo enabled**: adds `universe` apt source for additional packages
- **security packages**: ufw, apt-listchanges, needrestart, unattended-upgrades, apparmor-profiles, apparmor-utils
- **UFW**: package installed but service NOT enabled (L2 responsibility)
- **Kernel**: 6.8 HWE (Hardware Enablement)

## Dependencies

- `general/tasks/` - apt_refresh, packages, hostname, timezone_locale
- `roles/L1_os_baseline/defaults/main.yml` - l1_apt_lock_timeout, l1_file_mode
- `roles/L1_os_baseline/vars/main.yml` - OS-specific kernel, blacklist, and pinned pkg vars
