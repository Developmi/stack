SHELL := /usr/bin/env bash

PKG ?= uv
ANSIBLE_INVENTORY ?= inventory/hosts.ini
PLAYBOOK ?= playbooks/site.yml
ANSIBLE_OPTS ?=
ANSIBLE_LIMIT ?=
ANSIBLE_TAGS ?=
ANSIBLE_SKIP_TAGS ?=

# Generic runner variables (see the `run` target)
TAGS ?=
SKIP_TAGS ?=
CHECK ?=

NUKE_CONFIRM_PHRASE ?= DESTROY_ALL_INFRASTRUCTURE

SOPS_FILE ?= inventory/group_vars/all/secrets.sops.yml
SOPS_SAMPLE ?= inventory/group_vars/all/secrets.sops.yml.example


BECOME_PROMPT_FLAG := $(shell if [ -f "$(ANSIBLE_INVENTORY)" ]; then \
	awk '/^[[:space:]]*#/ || /^[[:space:]]*$$/ || /^\[/ {next} \
	{user=""; for (i=2; i<=NF; i++) { if ($$i ~ /^ansible_user=/) { split($$i,a,"="); user=a[2]; break } }} \
	user != "" && user != "root" { print "--ask-become-pass"; exit }' "$(ANSIBLE_INVENTORY)"; \
fi)
# Vault prompt retirement (SOPS migration, D4/D10; task 2.11): the Ansible
# Vault is RETIRED from the public template, so the default is empty. The six
# tailscale trio consumers below keep referencing $(VAULT_PROMPT_FLAG); an
# operator/private-clone override (make deploy-hardening VAULT_PROMPT_FLAG=--ask-vault-pass)
# restores the prompt until the trio expires (OPERATIONS_RUNBOOK §7.4).
VAULT_PROMPT_FLAG ?= 
APT_FORCE ?= false
APT_FORCE_FLAG := $(if $(filter true,$(APT_FORCE)),--extra-vars "apt_force_cleanup=true",)

# Anchor variables
ANSIBLE_RUN = $(PKG) run ansible-playbook -i $(ANSIBLE_INVENTORY)
ANSIBLE_FLAGS = $(BECOME_PROMPT_FLAG) $(APT_FORCE_FLAG) $(ANSIBLE_OPTS)
ANSIBLE_LIMIT_FLAG = $(if $(ANSIBLE_LIMIT),--limit $(ANSIBLE_LIMIT),)

.DEFAULT_GOAL := help

## Setup

help: ## Show this help
	@echo "Usage: make <target> [VARIABLE=value]"
	@awk 'BEGIN {FS = ":.*## "} \
	  /^## / {section = $$0; sub(/^## /, "", section); if (section != prev) {print ""; print section ":"} prev = section} \
	  /^[a-zA-Z0-9_.-]+:.*## / {printf "  %-34s %s\n", $$1, $$2}' \
	  $(MAKEFILE_LIST)

sync: ## Setup: Sync Python toolchain
	@echo "Running $(PKG) sync..."
	$(PKG) sync

install-collections: ## Setup: Install Ansible Galaxy collections
	@echo "Installing Ansible collections from requirements.yml..."
	$(PKG) run ansible-galaxy collection install -r requirements.yml

setup-toolchain: ## Setup: Install the toolchain (scripts/setup.sh --install)
	@echo "Running bootstrap install script..."
	./scripts/setup.sh --install

check-toolchain: ## Setup: Validate the local toolchain (scripts/setup.sh --validate)
	@echo "Running validation (syntax checks)..."
	./scripts/setup.sh --validate

lint: ## Setup: Run yamllint + ansible-lint (strict)
	@set -e; \
	echo "Running yamllint (tracked files only)..."; \
	if ! $(PKG) run yamllint $$(git ls-files '*.yml' '*.yaml'); then \
		echo "ERROR: yamllint failed. Fix the YAML issues and re-run: make lint"; \
		echo "Hint: if the toolchain is missing, run: uv sync"; \
		exit 1; \
	fi; \
	echo "Running ansible-lint on all playbooks..."; \
	files=$$(find playbooks -name '*.yml' -not -path '*/\.*' | sort); \
	if ! $(PKG) run ansible-lint $$files; then \
		echo "ERROR: ansible-lint failed. Fix the playbook issues and re-run: make lint"; \
		echo "Hint: if the toolchain is missing, run: uv sync"; \
		exit 1; \
	fi

precommit-install: ## Setup: Install pre-commit hooks
	$(PKG) run pre-commit install

precommit-run: ## Setup: Run pre-commit on all files
	$(PKG) run pre-commit run --all-files

show-inventory: ## Setup: Print inventory path
	@test -f $(ANSIBLE_INVENTORY) && cat $(ANSIBLE_INVENTORY) || (echo "Inventory not found: $(ANSIBLE_INVENTORY)" && exit 1)

# Vault (RETIRED - SOPS migration, decouple-manager-sops 2.11)
# The vault-init/vault-encrypt/vault-edit/vault-view targets were removed.
# The vault file survives ONLY for the tailscale trio until key expiry
# (OPERATIONS_RUNBOOK §7.4); use the sops-* targets below for secrets.

## SOPS

sops-init: ## SOPS: Initialize secrets.sops.yml from example
	@if [ -f "$(SOPS_FILE)" ]; then \
		echo "SOPS file already exists: $(SOPS_FILE)"; \
	else \
		cp "$(SOPS_SAMPLE)" "$(SOPS_FILE)"; \
		echo "Created $(SOPS_FILE) from $(SOPS_SAMPLE)."; \
	fi

sops-encrypt: ## SOPS: Encrypt secrets file in place (age key required)
	@test -f "$(SOPS_FILE)" || (echo "Missing SOPS file: $(SOPS_FILE)" && exit 1)
	$(PKG) run sops --encrypt --in-place "$(SOPS_FILE)"

sops-edit: ## SOPS: Edit encrypted secrets (decrypts to $EDITOR, re-encrypts)
	@test -f "$(SOPS_FILE)" || (echo "Missing SOPS file: $(SOPS_FILE)" && exit 1)
	$(PKG) run sops edit "$(SOPS_FILE)"

sops-view: ## SOPS: View decrypted secrets
	@test -f "$(SOPS_FILE)" || (echo "Missing SOPS file: $(SOPS_FILE)" && exit 1)
	$(PKG) run sops decrypt "$(SOPS_FILE)"

## L1-L2

deploy-l1: ## L1-L2: Deploy L1 OS baseline hardening (kernel, packages, apparmor)
	@echo "=== L1: OS Baseline Hardening ==="
	$(ANSIBLE_RUN) playbooks/l1/baseline.yml $(ANSIBLE_FLAGS)

validate-l1: ## L1-L2: Audit L1 OS baseline (read-only, kernels, packages, modules)
	@echo "=== L1: Validation Audit ==="
	$(ANSIBLE_RUN) playbooks/ops/validate.yml $(ANSIBLE_FLAGS) $(ANSIBLE_LIMIT_FLAG) --tags l1-os-baseline

deploy-hardening: ## L1-L2: Deploy full L1+L2 hardening (site.yml)
	@echo "=== Full Hardening (L1 + L2) ==="
	# Tailscale trio consumer (D4): vault prompt pinned until trio expiry.
	$(ANSIBLE_RUN) playbooks/site.yml $(BECOME_PROMPT_FLAG) $(VAULT_PROMPT_FLAG) $(APT_FORCE_FLAG) $(ANSIBLE_OPTS) $(ANSIBLE_LIMIT_FLAG)

deploy: ## L1-L2: Alias for deploy-hardening (compatibility)
	@$(MAKE) deploy-hardening

deploy-first: ## L1-L2: First-deploy bootstrap mode (bootstrap_mode=true, auto-detects controller_ip)
	@echo "=== First Deploy: Bootstrap Mode ==="
	@EXTRA_E="" ; \
	if [ -n "$(ANSIBLE_OPTS)" ] && echo "$(ANSIBLE_OPTS)" | grep -qE '(^|\s)(-e\s+)?controller_ip='; then \
		echo "Using explicit controller_ip from ANSIBLE_OPTS"; \
	elif [ -n "$$SSH_CLIENT" ]; then \
		CONTROLLER_IP=$$(echo "$$SSH_CLIENT" | awk '{print $$1}'); \
		EXTRA_E="-e controller_ip=$$CONTROLLER_IP"; \
	elif [ -n "$$SSH_CONNECTION" ]; then \
		CONTROLLER_IP=$$(echo "$$SSH_CONNECTION" | awk '{print $$1}'); \
		EXTRA_E="-e controller_ip=$$CONTROLLER_IP"; \
	elif [ -n "$$SUDO_SSH_CLIENT" ]; then \
		CONTROLLER_IP=$$(echo "$$SUDO_SSH_CLIENT" | awk '{print $$1}'); \
		EXTRA_E="-e controller_ip=$$CONTROLLER_IP"; \
	else \
		echo "ERROR: Cannot auto-detect controller_ip."; \
		echo "Set SSH_CLIENT, SSH_CONNECTION, or pass -e controller_ip=X.X.X.X via ANSIBLE_OPTS."; \
		echo "Detected IPs on this host:"; \
		ip addr show 2>/dev/null || ifconfig 2>/dev/null; \
		exit 1; \
	fi; \
	$(MAKE) deploy-hardening ANSIBLE_OPTS="$(ANSIBLE_OPTS) -e bootstrap_mode=true $${EXTRA_E}" || exit $$?
	@echo ""
	@echo "=== POST-LOCKDOWN: UPDATE INVENTORY ==="
	@echo "Root SSH has been locked down. Ansible connections now require Tailscale IPs."
	@echo ""
	@echo "Step 1: Get Tailscale IPs"
	@echo "  Run on each host:   tailscale ip -4"
	@echo "  Or from controller: tailscale status | grep -E 'brain|muscle'"
	@echo ""
	@echo "Step 2: Update $(ANSIBLE_INVENTORY)"
	@echo "  Change ansible_host= to the Tailscale IP (100.x.x.x) for each host."
	@echo ""
	@read -r -p "Continue with L3+ deployment? [y/N] " _ans; \
	case "$${_ans:-n}" in [yY]*) ;; *) \
	  echo "Update inventory, then re-run with: make deploy-engine"; exit 0;; esac

deploy-bootstrap: ## L1-L2: Alias for deploy-first (compatibility)
	@$(MAKE) deploy-first

deploy-lockdown: ## L1-L2: Post-bootstrap lockdown - close public SSH
	@echo "=== L2: Lockdown ==="
	$(ANSIBLE_RUN) playbooks/l2/lockdown.yml $(ANSIBLE_OPTS)

deploy-compliance: ## L1-L2: Collect NIST 800-53 compliance evidence (read-only)
	@echo "=== L2: NIST 800-53 Compliance ==="
	# Tailscale trio consumer (D4): vault prompt pinned until trio expiry.
	$(ANSIBLE_RUN) playbooks/l2/compliance.yml $(BECOME_PROMPT_FLAG) $(VAULT_PROMPT_FLAG) $(ANSIBLE_LIMIT_FLAG) $(ANSIBLE_OPTS)

reconnect-tailscale: ## L1-L2: Reconnect Tailscale mesh (recovery, cloud console required)
	@echo "=== L2: Tailscale Reconnect ==="
	# Tailscale trio consumer (D4): vault prompt pinned until trio expiry.
	$(ANSIBLE_RUN) playbooks/l2/tailscale-recover.yml $(VAULT_PROMPT_FLAG) $(ANSIBLE_OPTS)

validate-l2: ## L1-L2: Audit L2 hardening and integrity (read-only)
	@echo "=== L2: Validation ==="
	$(ANSIBLE_RUN) playbooks/l2/validate.yml $(ANSIBLE_FLAGS) $(ANSIBLE_LIMIT_FLAG)

## L3

deploy-exporters: ## L3: Deploy Prometheus node_exporter + cadvisor on all hosts
	@echo "=== L3: Exporters ==="
	$(ANSIBLE_RUN) playbooks/l3/exporters.yml $(ANSIBLE_FLAGS)

deploy-monitoring-stack: ## L3: Deploy VictoriaMetrics + Loki + Grafana on brain
	@echo "=== L3: Monitoring Stack ==="
	$(ANSIBLE_RUN) playbooks/l3/stack.yml $(ANSIBLE_FLAGS)

deploy-monitoring: ## L3: Deploy exporters + monitoring stack (complete L3)
	@$(MAKE) deploy-exporters
	@$(MAKE) deploy-monitoring-stack

## L4

deploy-edge: ## L4: Deploy edge proxy (BACKEND=caddy, TARGET=<host>)
	@test -n "$(BACKEND)" || (echo "ERROR: BACKEND is required. Options: caddy. Usage: make deploy-edge BACKEND=caddy TARGET=brain-1"; exit 1)
	@test -n "$(TARGET)" || (echo "ERROR: TARGET is required. Usage: make deploy-edge BACKEND=caddy TARGET=brain-1"; exit 1)
	@echo "=== L4: Edge Proxy ($(BACKEND) on $(TARGET)) ==="
	$(ANSIBLE_RUN) playbooks/l4/edge.yml $(ANSIBLE_FLAGS) --limit "$(TARGET)" -e reverse_proxy_backend=$(BACKEND) -e target_group=$(TARGET)

## L6

deploy-engine: ## L6: Deploy Docker Engine + compose plugin on all hosts
	@echo "=== L6: Docker Engine ==="
	$(ANSIBLE_RUN) playbooks/l6/engine.yml $(ANSIBLE_FLAGS)

deploy-portainer: ## L6: Deploy Portainer agents + manager
	@echo "=== L6: Portainer ==="
	$(ANSIBLE_RUN) playbooks/l6/portainer.yml -e enable_portainer=true $(ANSIBLE_FLAGS)

deploy-backup-stack: ## L6: Deploy restic backup for Docker stacks (brain only)
	@echo "=== L6: Stack Backup ==="
	$(ANSIBLE_RUN) playbooks/l6/backup-stack.yml $(ANSIBLE_FLAGS) --limit brain

deploy-backup-appdata: ## L6: Deploy app data backup (PG/MySQL dumps to R2)
	@echo "=== L6: App Data Backup ==="
	$(ANSIBLE_RUN) playbooks/l6/backup-appdata.yml $(BECOME_PROMPT_FLAG) $(ANSIBLE_OPTS)

deploy-backup-timers: ## L6: Deploy systemd backup timers on all hosts
	@echo "=== L6: Backup Timers ==="
	$(ANSIBLE_RUN) playbooks/l6/backup-timers.yml $(BECOME_PROMPT_FLAG) $(ANSIBLE_OPTS)

deploy-backup-databases: ## L6: Deploy DB auto-discovery backups (PG + MariaDB)
	@echo "=== L6: Database Backup ==="
	$(ANSIBLE_RUN) playbooks/l6/backup-databases.yml $(BECOME_PROMPT_FLAG) $(ANSIBLE_OPTS)

deploy-backups: ## L6: Deploy all backup layers (umbrella: stack→appdata→timers→databases)
	@echo "=== L6: All Backups ==="
	@$(MAKE) deploy-backup-stack
	@$(MAKE) deploy-backup-appdata
	@$(MAKE) deploy-backup-timers
	@$(MAKE) deploy-backup-databases
	@echo "=== Backups: COMPLETE ==="

backup-now: ## L6: Trigger immediate stack backup on brain (Restic → R2)
	@echo "=== L6: Manual Backup Trigger ==="
	$(ANSIBLE_RUN) playbooks/l6/backup-stack.yml $(BECOME_PROMPT_FLAG) $(ANSIBLE_OPTS) --tags stack_backup --limit brain

## Ops

provision-host: ## Ops: Provision fresh host (system stability + create users as root)
	@echo "=== Ops: Provision Host ==="
	# Tailscale trio consumer (D4): vault prompt pinned until trio expiry.
	$(ANSIBLE_RUN) playbooks/ops/bootstrap.yml $(VAULT_PROMPT_FLAG) $(ANSIBLE_OPTS)

deploy-local: ## Ops: Deploy workstation hardening (local class only)
	@echo "=== Ops: Local Devices ==="
	# Tailscale trio consumer (D4): vault prompt pinned until trio expiry.
	$(ANSIBLE_RUN) playbooks/ops/local-devices.yml $(BECOME_PROMPT_FLAG) $(VAULT_PROMPT_FLAG) $(ANSIBLE_OPTS)

audit-full: ## Ops: Full validation audit across L1 + L2 (read-only, sequential)
	@echo "=== Ops: Full Validation Audit (L1 + L2) ==="
	$(ANSIBLE_RUN) playbooks/ops/validate.yml $(BECOME_PROMPT_FLAG) $(ANSIBLE_OPTS) $(ANSIBLE_LIMIT_FLAG) && \
	$(ANSIBLE_RUN) playbooks/l2/validate.yml $(BECOME_PROMPT_FLAG) $(ANSIBLE_OPTS) $(ANSIBLE_LIMIT_FLAG)

nuke: ## Ops: DESTROY all infrastructure. Requires CONFIRM=$(NUKE_CONFIRM_PHRASE)
	@test "$(CONFIRM)" = "$(NUKE_CONFIRM_PHRASE)" || (echo "ERROR: Nuke requires explicit confirmation. Set CONFIRM=$(NUKE_CONFIRM_PHRASE)" && exit 1)
	@echo "=== NUKE: DESTROYING ALL INFRASTRUCTURE ==="
	# Tailscale trio consumer (D4): vault prompt pinned until trio expiry.
	$(ANSIBLE_RUN) playbooks/ops/nuke.yml $(BECOME_PROMPT_FLAG) $(VAULT_PROMPT_FLAG) $(APT_FORCE_FLAG) $(ANSIBLE_OPTS)

gate-lockdown: ## Ops: Pre-flight checks before disabling root SSH
	@echo "=== PHASE 07 GATE CHECK ==="
	@test -f docs/operations/EMERGENCY_ACCESS.md || (echo "FAIL: docs/operations/EMERGENCY_ACCESS.md not found" && exit 1)
	@echo "Pre-flight: emergency-access.md exists"
	@echo "Testing SSH as automation user on all hosts..."
	# NOTE: Assumes automation user has NOPASSWD sudo. If a become password is
	# required, add --ask-become-pass to the ansible command.
	@$(PKG) run ansible all -i $(ANSIBLE_INVENTORY) -u automation --become -m shell -a "whoami" \
		|| (echo "FAIL: automation user SSH/become check" && exit 1)
	@echo ""
	@echo "=== GATE PASSED ==="

## Verify

verify-lockdown: ## Verify: 3-stage verification (ping + whoami + root lockout)
	@echo "=== PHASE 07 VERIFICATION ==="
	# Stage (a): SSH connectivity + privilege escalation (ansible ping module)
	# NOTE: Assumes automation user has NOPASSWD sudo. If a become password is
	# required, add --ask-become-pass.
	@echo "--- Stage (a): ping all hosts as automation ---"
	@$(PKG) run ansible all -i $(ANSIBLE_INVENTORY) -u automation --become -m ping \
		|| (echo "FAIL: ping check" && exit 1)
	@echo ""
	# Stage (b): Verify become escalation actually yields root (whoami output)
	# NOTE: Assumes automation user has NOPASSWD sudo. If a become password is
	# required, add --ask-become-pass.
	@echo "--- Stage (b): whoami --become (expect root on all hosts) ---"
	@$(PKG) run ansible all -i $(ANSIBLE_INVENTORY) -u automation --become -m shell -a "whoami" \
		|| (echo "FAIL: whoami check" && exit 1)
	@echo ""
	# Stage (c): Confirm root SSH is blocked - direct SSH as root should fail
	# with exit code 255 (locked out). Uses ansible_host= from inventory when
	# present, otherwise falls back to the bare hostname.
	@echo "--- Stage (c): root SSH lockout verification ---"
	@failed=0; \
	hosts=$$(awk '/^#/ || /^\[/ || !NF {next} { for(i=1;i<=NF;i++) { if($$i ~ /^ansible_host=/) { split($$i,a,"="); print a[2]; next } } print $$1 }' $(ANSIBLE_INVENTORY)); \
	for host in $$hosts; do \
		printf "root@%s ... " "$$host"; \
		if ssh -o ConnectTimeout=5 -o BatchMode=yes root@"$$host" exit 2>/dev/null; then \
			echo "UNEXPECTEDLY CONNECTED - FAIL"; failed=1; \
		else \
			rc=$$?; \
			if [ "$$rc" = "255" ]; then \
				echo "locked out (OK)"; \
			else \
				echo "unexpected exit code $$rc - FAIL"; failed=1; \
			fi; \
		fi; \
	done; \
	if [ "$$failed" = "1" ]; then \
		echo "FAIL: root SSH lockout incomplete"; exit 1; \
	fi
	@echo ""
	@echo "=== VERIFICATION PASSED ==="

verify-tailscale: ## Verify: tailscale status on all hosts
	$(PKG) run ansible all -i $(ANSIBLE_INVENTORY) -m command -a "tailscale status"

verify-crowdsec: ## Verify: CrowdSec alerts on all hosts
	$(PKG) run ansible all -i $(ANSIBLE_INVENTORY) -m shell -a "timeout 15 cscli alerts list || echo 'crowdsec OK (no alerts or timeout)'"

verify-auditd: ## Verify: Tail audit logs on all hosts
	$(PKG) run ansible all -i $(ANSIBLE_INVENTORY) -m shell -a "tail -n 50 /var/log/audit/audit.log"

verify-observability: ## Verify: Check exporters and VM targets
	$(PKG) run ansible all -i $(ANSIBLE_INVENTORY) -m shell -a "docker ps -a | grep -E 'node-exporter|cadvisor'" $(ANSIBLE_FLAGS)
	$(PKG) run ansible all -i $(ANSIBLE_INVENTORY) -m shell -a "curl -fsS http://127.0.0.1:9100/metrics >/dev/null && echo node_exporter_ok" $(ANSIBLE_FLAGS)
	$(PKG) run ansible all -i $(ANSIBLE_INVENTORY) -m shell -a "curl -fsS http://127.0.0.1:18080/metrics >/dev/null && echo cadvisor_ok || echo cadvisor_limited_or_down" $(ANSIBLE_FLAGS)
	$(PKG) run ansible brain -i $(ANSIBLE_INVENTORY) -m shell -a "docker inspect victoria-metrics loki grafana blackbox-exporter 2>/dev/null | grep -c running | grep -q '^4$$' && docker inspect grafana 2>/dev/null | grep -c 'RestartCount.: 0' | grep -q '^1$$' && echo stack_containers_running || echo STACK_CONTAINERS_DOWN" $(ANSIBLE_FLAGS)

verify-timers: ## Verify: List backup-* timers on all hosts
	$(PKG) run ansible all -i $(ANSIBLE_INVENTORY) -m shell -a \
		"systemctl list-timers --all | grep backup- || echo 'NO_BACKUP_TIMERS'"

monitor-crowdsec: ## Verify: Run local CrowdSec monitor script
	@echo "Running CrowdSec monitor script..."
	./scripts/monitor-crowdsec.sh

## Meta

deploy-platform: ## Meta: Deploy complete platform (hardening → engine → monitoring → portainer → backups). L4 edge requires explicit parameters and is NOT included
	@echo "=== Full Platform Deployment ==="
	@$(MAKE) deploy-hardening
	@$(MAKE) deploy-engine
	@$(MAKE) deploy-monitoring
	@$(MAKE) deploy-portainer
	@$(MAKE) deploy-backups
	@echo "=== Full Platform: COMPLETE ==="

run: ## Meta: Run any playbook. PLAYBOOK= required; TAGS=, SKIP_TAGS=, CHECK=1 (--check --diff)
	@test -n "$(PLAYBOOK)" || (echo "Set PLAYBOOK=<file>.yml" && exit 1)
	@test -f "$(PLAYBOOK)" || (echo "Playbook not found: $(PLAYBOOK)" && exit 1)
	$(ANSIBLE_RUN) $(PLAYBOOK) $(ANSIBLE_FLAGS) $(ANSIBLE_LIMIT_FLAG) \
		$(if $(TAGS),--tags "$(TAGS)") \
		$(if $(SKIP_TAGS),--skip-tags "$(SKIP_TAGS)") \
		$(if $(filter 1,$(CHECK)),--check --diff)

deploy-tags: ## Meta: Alias for run with TAGS (compatibility)
	@test -n "$(ANSIBLE_TAGS)" || (echo "Set ANSIBLE_TAGS=<tag1,tag2>" && exit 1)
	@$(MAKE) run TAGS="$(ANSIBLE_TAGS)"

dry-run: ## Meta: Alias for run CHECK=1 (compatibility)
	@$(MAKE) run CHECK=1

check: dry-run ## Meta: Alias for dry-run (compatibility)

## Test

test: ## Test: Run the whole Molecule suite (all layers)
	@echo "=> Executing The Whole Molecule Suite..."
	uv run molecule test --all

test-layer: ## Test: Run a specific Molecule layer (make test-layer LAYER=L1_os_baseline)
	@if [ -z "$(LAYER)" ]; then \
		echo "⛔ ERROR: You should specify the layer. Example: make test-layer LAYER=L1_os_baseline"; \
		exit 1; \
	fi
	@echo "=> Executing test layer for: $(LAYER)"
	uv run molecule test -s $(LAYER)

# Unified .PHONY - all targets sorted by section then alphabetically

.PHONY: help sync install-collections setup-toolchain check-toolchain lint \
	precommit-install precommit-run show-inventory \
	sops-edit sops-encrypt sops-init sops-view \
	deploy deploy-bootstrap deploy-compliance deploy-first deploy-hardening \
	deploy-l1 deploy-lockdown reconnect-tailscale validate-l1 validate-l2 \
	deploy-exporters deploy-monitoring deploy-monitoring-stack \
	deploy-edge \
	backup-now deploy-backup-appdata deploy-backup-databases deploy-backup-stack \
	deploy-backup-timers deploy-backups deploy-engine deploy-portainer \
	audit-full deploy-local gate-lockdown nuke provision-host \
	monitor-crowdsec verify-auditd verify-crowdsec verify-lockdown \
	verify-observability verify-tailscale verify-timers \
	check deploy-platform deploy-tags dry-run run \
	test test-layer
