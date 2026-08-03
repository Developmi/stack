SHELL := /usr/bin/env bash

PKG ?= uv
ANSIBLE_INVENTORY ?= inventory/hosts.ini
PLAYBOOK ?= playbooks/site.yml
ANSIBLE_OPTS ?=
ANSIBLE_LIMIT ?=
ANSIBLE_TAGS ?=
ANSIBLE_SKIP_TAGS ?=

VAULT_FILE ?= inventory/group_vars/all/secrets.yml
VAULT_SAMPLE ?= inventory/group_vars/all/secrets.yml.example
NUKE_CONFIRM_PHRASE ?= DESTROY_ALL_INFRASTRUCTURE


BECOME_PROMPT_FLAG := $(shell if [ -f "$(ANSIBLE_INVENTORY)" ]; then \
	awk '/^[[:space:]]*#/ || /^[[:space:]]*$$/ || /^\[/ {next} \
	{user=""; for (i=2; i<=NF; i++) { if ($$i ~ /^ansible_user=/) { split($$i,a,"="); user=a[2]; break } }} \
	user != "" && user != "root" { print "--ask-become-pass"; exit }' "$(ANSIBLE_INVENTORY)"; \
fi)
VAULT_PROMPT_FLAG ?= --ask-vault-pass
APT_FORCE ?= false
APT_FORCE_FLAG := $(if $(filter true,$(APT_FORCE)),--extra-vars "apt_force_cleanup=true",)

# Anchor variables
ANSIBLE_RUN = $(PKG) run ansible-playbook -i $(ANSIBLE_INVENTORY)
ANSIBLE_FLAGS = $(BECOME_PROMPT_FLAG) $(VAULT_PROMPT_FLAG) $(APT_FORCE_FLAG) $(ANSIBLE_OPTS)
ANSIBLE_LIMIT_FLAG = $(if $(ANSIBLE_LIMIT),--limit $(ANSIBLE_LIMIT),)

.DEFAULT_GOAL := help

# ====== Setup & Utility ======

help:
	@echo "Usage: make <target> [VARIABLE=value]"
	@echo ""
	@echo "Setup:"
	@echo "  ## Setup: sync              Sync Python toolchain via \$(PKG)"
	@echo "  ## Setup: install           Alias for sync"
	@echo "  ## Setup: install-collections  Install Ansible Galaxy collections"
	@echo "  ## Setup: bootstrap         Run scripts/setup.sh --install"
	@echo "  ## Setup: validate          Run scripts/setup.sh --validate"
	@echo "  ## Setup: lint              Run yamllint + ansible-lint through \$(PKG) run (strict)"
	@echo "  ## Setup: precommit-install Run pre-commit install"
	@echo "  ## Setup: precommit-run     Run pre-commit on all files"
	@echo "  ## Setup: show-inventory    Print configured inventory path"
	@echo ""
	@echo "Vault:"
	@echo "  ## Vault: vault-init        Copy secrets example if vault file is missing"
	@echo "  ## Vault: vault-encrypt     Encrypt \$(VAULT_FILE)"
	@echo "  ## Vault: vault-edit        Edit encrypted \$(VAULT_FILE)"
	@echo "  ## Vault: vault-view        View encrypted \$(VAULT_FILE)"
	@echo ""
	@echo "L1 - OS Baseline:"
	@echo "  ## L1: deploy-l1            Deploy L1 OS baseline hardening (kernel, packages, apparmor)"
	@echo "  ## L1: validate-l1          Audit L1 OS baseline (read-only, kernels, packages, modules)"
	@echo ""
	@echo "L2 - Hardening & Compliance:"
	@echo "  ## L2: deploy               Deploy L1+L2 full hardening (site.yml)"
	@echo "  ## L2: deploy-bootstrap     First-deploy bootstrap mode (sets nist_bootstrap=true, auto-detects controller_ip)"
	@echo "  ## L2: deploy-lockdown      Post-bootstrap lockdown - close public SSH"
	@echo "  ## L2: deploy-compliance-nist80053  Collect NIST 800-53 compliance evidence (read-only)"
	@echo "  ## L2: deploy-tailscale-reconnect   Reconnect Tailscale mesh (recovery, cloud console required)"
	@echo "  ## L2: validate-l2          Audit L2 hardening and integrity (read-only)"
	@echo ""
	@echo "L3 - Observability:"
	@echo "  ## L3: deploy-exporters     Deploy Prometheus node_exporter + cadvisor on all hosts"
	@echo "  ## L3: deploy-monitoring-stack  Deploy VictoriaMetrics + Loki + Grafana on brain"
	@echo "  ## L3: deploy-monitoring    Deploy exporters + monitoring stack (complete L3)"
	@echo "  ## L3: deploy-observability-%  Deploy specific observability component"
	@echo ""
	@echo "L4 - Networking/Edge:"
	@echo "  ## L4: deploy-edge          Deploy edge proxy. Usage: EDGE=caddy HOST=muscle-3"
	@echo ""
	@echo "L6 - Runtime:"
	@echo "  ## L6: deploy-engine        Deploy Docker Engine + compose plugin on all hosts"
	@echo "  ## L6: deploy-portainer     Deploy Portainer agents + manager"
	@echo "  ## L6: deploy-backup-stack  Deploy restic backup for Docker stacks (brain only)"
	@echo "  ## L6: deploy-backup-appdata  Deploy app data backup (PG/MySQL dumps to R2)"
	@echo "  ## L6: deploy-backup-timers Deploy systemd backup timers on all hosts"
	@echo "  ## L6: deploy-backup-databases  Deploy DB auto-discovery backups (PG + MariaDB)"
	@echo "  ## L6: deploy-backups       Deploy all backup layers (umbrella: stack→appdata→timers→databases)"
	@echo "  ## L6: backup-now           Trigger immediate stack backup on brain (Restic → R2)"
	@echo ""
	@echo "Ops - Operations:"
	@echo "  ## Ops: bootstrap-host      Bootstrap fresh host: system stability + create users as root"
	@echo "  ## Ops: deploy-local        Deploy workstation hardening (local class only)"
	@echo "  ## Ops: audit-full          Run full validation audit across all layers (read-only)"
	@echo "  ## Ops: nuke                DESTROY all infrastructure. Requires CONFIRM=\$(NUKE_CONFIRM_PHRASE)"
	@echo ""
	@echo "Verification:"
	@echo "  ## Ops: verify-tailscale    tailscale status on all hosts"
	@echo "  ## Ops: verify-crowdsec     CrowdSec alerts on all hosts"
	@echo "  ## Ops: verify-auditd       Tail audit logs on all hosts"
	@echo "  ## Ops: verify-observability  Check exporters and VM targets"
	@echo "  ## Ops: verify-timers       List backup-* timers on all hosts"
	@echo "  ## Ops: monitor-crowdsec    Run local CrowdSec monitor script"
	@echo ""
	@echo "Gates:"
	@echo "  ## Ops: gate-phase-07       Pre-flight checks before disabling root SSH"
	@echo "  ## Ops: verify-phase-07     3-stage verification (ping + whoami + root lockout)"
	@echo ""
	@echo "Meta:"
	@echo "  ## Meta: deploy-platform    Deploy complete platform (L2→L3→L6, sequential)"
	@echo "  ## Meta: deploy-custom      Run PLAYBOOK=<file>.yml"
	@echo "  ## Meta: dry-run            Run PLAYBOOK in check+diff mode"
	@echo "  ## Meta: check              Alias for dry-run"
	@echo "  ## Meta: deploy-tags        Run PLAYBOOK with ANSIBLE_TAGS=<tags>"
	@echo "  ## Meta: deploy-skip-tags   Run PLAYBOOK with ANSIBLE_SKIP_TAGS=<tags>"

sync: ## Setup: Sync Python toolchain
	@echo "Running $(PKG) sync..."
	$(PKG) sync

install: sync

install-collections: ## Setup: Install Ansible Galaxy collections
	@echo "Installing Ansible collections from requirements.yml..."
	$(PKG) run ansible-galaxy collection install -r requirements.yml

bootstrap: ## Setup: Run bootstrap install script
	@echo "Running bootstrap install script..."
	./scripts/setup.sh --install

validate: ## Setup: Run validation (syntax checks)
	@echo "Running validation (syntax checks)..."
	./scripts/setup.sh --validate

lint: ## Setup: Run yamllint + ansible-lint (strict)
	@set -e; \
	echo "Running yamllint..."; \
	if ! $(PKG) run yamllint .; then \
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

# ====== Vault ======

vault-init: ## Vault: Initialize vault from example
	@if [ -f "$(VAULT_FILE)" ]; then \
		echo "Vault file already exists: $(VAULT_FILE)"; \
	else \
		cp "$(VAULT_SAMPLE)" "$(VAULT_FILE)"; \
		echo "Created $(VAULT_FILE) from $(VAULT_SAMPLE)."; \
	fi

vault-encrypt: ## Vault: Encrypt secrets file
	@test -f "$(VAULT_FILE)" || (echo "Missing vault file: $(VAULT_FILE)" && exit 1)
	$(PKG) run ansible-vault encrypt "$(VAULT_FILE)"

vault-edit: ## Vault: Edit encrypted secrets
	@test -f "$(VAULT_FILE)" || (echo "Missing vault file: $(VAULT_FILE)" && exit 1)
	$(PKG) run ansible-vault edit "$(VAULT_FILE)"

vault-view: ## Vault: View encrypted secrets
	@test -f "$(VAULT_FILE)" || (echo "Missing vault file: $(VAULT_FILE)" && exit 1)
	$(PKG) run ansible-vault view "$(VAULT_FILE)"

# ====== L1 - OS Baseline ======

deploy-l1: ## L1: Deploy OS baseline hardening
	@echo "=== L1: OS Baseline Hardening ==="
	$(ANSIBLE_RUN) playbooks/l1/baseline.yml $(ANSIBLE_FLAGS)

validate-l1: ## L1: Audit L1 OS baseline
	@echo "=== L1: Validation Audit ==="
	$(ANSIBLE_RUN) playbooks/ops/validate.yml $(ANSIBLE_FLAGS) $(ANSIBLE_LIMIT_FLAG) --tags l1-os-baseline

# ====== L2 - Hardening & Compliance ======

deploy: ## L2: Full hardening (site.yml)
	@echo "=== Full Hardening (L1 + L2) ==="
	$(ANSIBLE_RUN) playbooks/site.yml $(ANSIBLE_FLAGS) $(ANSIBLE_LIMIT_FLAG)

deploy-bootstrap: ## L2: First-deploy bootstrap mode (sets nist_bootstrap=true)
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
	$(MAKE) deploy ANSIBLE_OPTS="$(ANSIBLE_OPTS) -e nist_bootstrap=true $${EXTRA_E}" || exit $$?
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

deploy-lockdown: ## L2: Post-bootstrap lockdown - close public SSH
	@echo "=== L2: Lockdown ==="
	$(ANSIBLE_RUN) playbooks/l2/lockdown.yml $(VAULT_PROMPT_FLAG) $(ANSIBLE_OPTS)

deploy-compliance-nist80053: ## L2: NIST 800-53 compliance evidence
	@echo "=== L2: NIST 800-53 Compliance ==="
	$(ANSIBLE_RUN) playbooks/l2/compliance.yml $(BECOME_PROMPT_FLAG) $(VAULT_PROMPT_FLAG) $(ANSIBLE_LIMIT_FLAG) $(ANSIBLE_OPTS)

deploy-tailscale-reconnect: ## L2: Tailscale mesh recovery
	@echo "=== L2: Tailscale Reconnect ==="
	$(ANSIBLE_RUN) playbooks/l2/tailscale-recover.yml $(VAULT_PROMPT_FLAG) $(ANSIBLE_OPTS)

validate-l2: ## L2: Audit L2 hardening and integrity
	@echo "=== L2: Validation ==="
	$(ANSIBLE_RUN) playbooks/l2/validate.yml $(ANSIBLE_FLAGS) $(ANSIBLE_LIMIT_FLAG)

# ====== L3 - Observability ======

deploy-exporters: ## L3: Deploy Prometheus exporters
	@echo "=== L3: Exporters ==="
	$(ANSIBLE_RUN) playbooks/l3/exporters.yml $(ANSIBLE_FLAGS)

deploy-monitoring-stack: ## L3: Deploy monitoring stack on brain
	@echo "=== L3: Monitoring Stack ==="
	$(ANSIBLE_RUN) playbooks/l3/stack.yml $(ANSIBLE_FLAGS)

deploy-monitoring: ## L3: Complete L3 (exporters + stack)
	@$(MAKE) deploy-exporters
	@$(MAKE) deploy-monitoring-stack

deploy-observability-%: ## L3: Deploy specific observability component
	@echo "=== L3: Observability ($*) ==="
	$(ANSIBLE_RUN) playbooks/l3/stack.yml $(ANSIBLE_FLAGS) --tags "l3-observability,$*"

# ====== L4 - Networking/Edge ======

deploy-edge: ## L4: Deploy edge proxy
	@test -n "$(EDGE)" || (echo "ERROR: EDGE is required. Options: caddy, traefik, nginx. Usage: make deploy-edge EDGE=caddy HOST=muscle-3"; exit 1)
	@test -n "$(HOST)" || (echo "ERROR: HOST is required. Usage: make deploy-edge EDGE=caddy HOST=muscle-3"; exit 1)
	@echo "=== L4: Edge Proxy ($(EDGE) on $(HOST)) ==="
	$(ANSIBLE_RUN) playbooks/l4/edge.yml $(ANSIBLE_FLAGS) --limit "$(HOST)" -e edge_backend=$(EDGE)

# ====== L6 - Runtime ======

deploy-engine: ## L6: Deploy Docker Engine
	@echo "=== L6: Docker Engine ==="
	$(ANSIBLE_RUN) playbooks/l6/engine.yml $(ANSIBLE_FLAGS)

deploy-portainer: ## L6: Deploy Portainer
	@echo "=== L6: Portainer ==="
	$(ANSIBLE_RUN) playbooks/l6/portainer.yml $(ANSIBLE_FLAGS)

deploy-backup-stack: ## L6: Deploy restic stack backup (brain only)
	@echo "=== L6: Stack Backup ==="
	$(ANSIBLE_RUN) playbooks/l6/backup-stack.yml $(ANSIBLE_FLAGS) --limit brain

deploy-backup-appdata: ## L6: Deploy app data backup
	@echo "=== L6: App Data Backup ==="
	$(ANSIBLE_RUN) playbooks/l6/backup-appdata.yml $(BECOME_PROMPT_FLAG) $(VAULT_PROMPT_FLAG) $(ANSIBLE_OPTS)

deploy-backup-timers: ## L6: Deploy systemd backup timers
	@echo "=== L6: Backup Timers ==="
	$(ANSIBLE_RUN) playbooks/l6/backup-timers.yml $(BECOME_PROMPT_FLAG) $(VAULT_PROMPT_FLAG) $(ANSIBLE_OPTS)

deploy-backup-databases: ## L6: Deploy database auto-discovery backups
	@echo "=== L6: Database Backup ==="
	$(ANSIBLE_RUN) playbooks/l6/backup-databases.yml $(BECOME_PROMPT_FLAG) $(VAULT_PROMPT_FLAG) $(ANSIBLE_OPTS)

deploy-backups: ## L6: Deploy all backup layers
	@echo "=== L6: All Backups ==="
	@$(MAKE) deploy-backup-stack
	@$(MAKE) deploy-backup-appdata
	@$(MAKE) deploy-backup-timers
	@$(MAKE) deploy-backup-databases
	@echo "=== Backups: COMPLETE ==="

backup-now: ## L6: Manual backup trigger (brain only)
	@echo "=== L6: Manual Backup Trigger ==="
	$(ANSIBLE_RUN) playbooks/l6/backup-stack.yml $(BECOME_PROMPT_FLAG) $(VAULT_PROMPT_FLAG) $(ANSIBLE_OPTS) --tags backup --limit brain

# ====== Ops - Operations ======

bootstrap-host: ## Ops: Bootstrap fresh host as root
	@echo "=== Ops: Bootstrap Host ==="
	$(ANSIBLE_RUN) playbooks/ops/bootstrap.yml $(VAULT_PROMPT_FLAG) $(ANSIBLE_OPTS)

deploy-local: ## Ops: Deploy workstation hardening
	@echo "=== Ops: Local Devices ==="
	$(ANSIBLE_RUN) playbooks/ops/local-devices.yml $(BECOME_PROMPT_FLAG) $(VAULT_PROMPT_FLAG) $(ANSIBLE_OPTS)

audit-full: ## Ops: Full validation audit (all layers)
	@echo "=== Ops: Full Validation Audit ==="
	$(ANSIBLE_RUN) playbooks/ops/validate.yml $(BECOME_PROMPT_FLAG) $(VAULT_PROMPT_FLAG) $(ANSIBLE_OPTS) $(ANSIBLE_LIMIT_FLAG)

nuke: ## Ops: DESTROY all infrastructure
	@test "$(CONFIRM)" = "$(NUKE_CONFIRM_PHRASE)" || (echo "ERROR: Nuke requires explicit confirmation. Set CONFIRM=$(NUKE_CONFIRM_PHRASE)" && exit 1)
	@echo "=== NUKE: DESTROYING ALL INFRASTRUCTURE ==="
	$(ANSIBLE_RUN) playbooks/ops/nuke.yml $(ANSIBLE_FLAGS)

# ====== Verification ======

verify-tailscale:
	$(PKG) run ansible all -i $(ANSIBLE_INVENTORY) -m command -a "tailscale status"

verify-crowdsec:
	$(PKG) run ansible all -i $(ANSIBLE_INVENTORY) -m shell -a "timeout 15 cscli alerts list || echo 'crowdsec OK (no alerts or timeout)'"

verify-auditd:
	$(PKG) run ansible all -i $(ANSIBLE_INVENTORY) -m shell -a "tail -n 50 /var/log/audit/audit.log"

verify-observability:
	$(PKG) run ansible all -i $(ANSIBLE_INVENTORY) -m shell -a "docker ps -a | grep -E 'node-exporter|cadvisor'" $(ANSIBLE_FLAGS)
	$(PKG) run ansible all -i $(ANSIBLE_INVENTORY) -m shell -a "curl -fsS http://127.0.0.1:9100/metrics >/dev/null && echo node_exporter_ok" $(ANSIBLE_FLAGS)
	$(PKG) run ansible all -i $(ANSIBLE_INVENTORY) -m shell -a "curl -fsS http://127.0.0.1:18080/metrics >/dev/null && echo cadvisor_ok || echo cadvisor_limited_or_down" $(ANSIBLE_FLAGS)
	$(PKG) run ansible brain -i $(ANSIBLE_INVENTORY) -m shell -a "docker inspect victoria-metrics loki grafana blackbox-exporter 2>/dev/null | grep -c running | grep -q '^4$$' && docker inspect grafana 2>/dev/null | grep -c 'RestartCount.: 0' | grep -q '^1$$' && echo stack_containers_running || echo STACK_CONTAINERS_DOWN" $(ANSIBLE_FLAGS)

verify-timers:
	$(PKG) run ansible all -i $(ANSIBLE_INVENTORY) -m shell -a \
		"systemctl list-timers --all | grep backup- || echo 'NO_BACKUP_TIMERS'"

monitor-crowdsec:
	@echo "Running CrowdSec monitor script..."
	./scripts/monitor-crowdsec.sh

# ====== Gates ======

gate-phase-07:
	@echo "=== PHASE 07 GATE CHECK ==="
	@test -f docs/operations/EMERGENCY_ACCESS.md || (echo "FAIL: docs/operations/EMERGENCY_ACCESS.md not found" && exit 1)
	@echo "Pre-flight: emergency-access.md exists"
	@echo "Testing SSH as automation user on all hosts..."
	# NOTE: Assumes automation user has NOPASSWD sudo. If become password is
	# vault-protected, add --ask-vault-pass to the ansible command.
	@$(PKG) run ansible all -i $(ANSIBLE_INVENTORY) -u automation --become -m shell -a "whoami" \
		|| (echo "FAIL: automation user SSH/become check" && exit 1)
	@echo ""
	@echo "=== GATE PASSED ==="

verify-phase-07:
	@echo "=== PHASE 07 VERIFICATION ==="
	# Stage (a): SSH connectivity + privilege escalation (ansible ping module)
	# NOTE: Assumes automation user has NOPASSWD sudo. If become password is
	# vault-protected, add --ask-vault-pass.
	@echo "--- Stage (a): ping all hosts as automation ---"
	@$(PKG) run ansible all -i $(ANSIBLE_INVENTORY) -u automation --become -m ping \
		|| (echo "FAIL: ping check" && exit 1)
	@echo ""
	# Stage (b): Verify become escalation actually yields root (whoami output)
	# NOTE: Assumes automation user has NOPASSWD sudo. If become password is
	# vault-protected, add --ask-vault-pass.
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

# ====== Meta - Full deployments & utilities ======

deploy-platform: ## Meta: Deploy complete platform
	@echo "=== Full Platform Deployment ==="
	@$(MAKE) deploy
	@$(MAKE) deploy-monitoring
	@$(MAKE) deploy-engine
	@$(MAKE) deploy-portainer
	@$(MAKE) deploy-backups
	@echo "=== Full Platform: COMPLETE ==="

deploy-custom:
	@test -n "$(PLAYBOOK)" || (echo "Set PLAYBOOK=<file>.yml" && exit 1)
	@test -f "$(PLAYBOOK)" || (echo "Playbook not found: $(PLAYBOOK)" && exit 1)
	$(ANSIBLE_RUN) $(PLAYBOOK) $(ANSIBLE_FLAGS) $(ANSIBLE_LIMIT_FLAG)

dry-run:
	@test -f "$(PLAYBOOK)" || (echo "Playbook not found: $(PLAYBOOK)" && exit 1)
	@echo "Running dry-run for $(PLAYBOOK)..."
	$(ANSIBLE_RUN) $(PLAYBOOK) $(ANSIBLE_FLAGS) --check --diff $(ANSIBLE_LIMIT_FLAG)

check: dry-run

deploy-tags:
	@test -f "$(PLAYBOOK)" || (echo "Playbook not found: $(PLAYBOOK)" && exit 1)
	@test -n "$(ANSIBLE_TAGS)" || (echo "Set ANSIBLE_TAGS=<tag1,tag2>" && exit 1)
	$(ANSIBLE_RUN) $(PLAYBOOK) $(ANSIBLE_FLAGS) --tags "$(ANSIBLE_TAGS)" $(ANSIBLE_LIMIT_FLAG)

deploy-skip-tags:
	@test -f "$(PLAYBOOK)" || (echo "Playbook not found: $(PLAYBOOK)" && exit 1)
	@test -n "$(ANSIBLE_SKIP_TAGS)" || (echo "Set ANSIBLE_SKIP_TAGS=<tag1,tag2>" && exit 1)
	$(ANSIBLE_RUN) $(PLAYBOOK) $(ANSIBLE_FLAGS) --skip-tags "$(ANSIBLE_SKIP_TAGS)" $(ANSIBLE_LIMIT_FLAG)


# Execute the whole test suite (L1 a L4)
test:
	@echo "=> Executing The Whole Molecule Suite..."
	uv run molecule test --all

# Execute specific layer (ex: make test-layer LAYER=L1_os_baseline)
test-layer:
	@if [ -z "$(LAYER)" ]; then \
		echo "⛔ ERROR: You should specify the layer. Example: make test-layer LAYER=L1_os_baseline"; \
		exit 1; \
	fi
	@echo "=> Executing test layer for: $(LAYER)"
	uv run molecule test -s $(LAYER)

# Unified .PHONY - all targets sorted by section then alphabetically

.PHONY: bootstrap help install install-collections lint \
	precommit-install precommit-run show-inventory sync validate \
	vault-edit vault-encrypt vault-init vault-view \
	deploy-l1 validate-l1 \
	deploy deploy-bootstrap deploy-compliance-nist80053 deploy-lockdown \
	deploy-tailscale-reconnect validate-l2 \
	deploy-exporters deploy-monitoring deploy-monitoring-stack \
	deploy-edge \
	backup-now deploy-backup-appdata deploy-backup-databases deploy-backup-stack \
	deploy-backup-timers deploy-backups deploy-engine deploy-portainer \
	audit-full bootstrap-host deploy-local nuke \
	monitor-crowdsec verify-auditd verify-crowdsec verify-observability \
	verify-tailscale verify-timers \
	gate-phase-07 verify-phase-07 \
	check deploy-custom deploy-platform deploy-skip-tags deploy-tags dry-run \
	test test-layer