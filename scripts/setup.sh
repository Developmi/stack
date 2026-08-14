#!/usr/bin/env bash
# ==============================================================================
# Bootstrap Script
# ==============================================================================
# Purpose: Safe bootstrap and validation
# Usage: ./setup.sh [--install|--validate|--help]
# ==============================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
REPO_NAME="stack"
REPO_URL="https://github.com/Developmi/stack.git"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Functions
print_header() {
    echo -e "\n${BLUE}=== $1 ===${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

enter_repo_root() {
    cd "$REPO_ROOT"
}

require_uv() {
    if ! command -v uv &> /dev/null; then
        print_error "uv is not installed"
        print_info "Install uv and re-run this script."
        print_info "Reference: https://docs.astral.sh/uv/"
        return 1
    fi
}

check_prerequisites() {
    print_header "Checking Prerequisites"
    require_uv || return 1

    if [[ ! -f "pyproject.toml" ]]; then
        print_error "pyproject.toml not found"
        return 1
    fi

    if [[ ! -f "requirements.yml" ]]; then
        print_error "requirements.yml not found"
        return 1
    fi

    print_success "uv is available"

    if ! uv run ansible --version > /dev/null 2>&1; then
        print_warning "Ansible tooling is not ready yet"
        print_info "Run: uv sync"
        return 1
    fi

    if ! uv run ansible-vault --version > /dev/null 2>&1; then
        print_warning "ansible-vault (Tailscale trio wrapper) is not ready yet"
        print_info "Run: uv sync"
        return 1
    fi

    if [[ -f "$HOME/.ssh/id_ed25519" || -f "$HOME/.ssh/id_rsa" ]]; then
        print_success "SSH key found"
    else
        print_warning "No SSH key found in ~/.ssh/"
        print_info "Generate one with: ssh-keygen -t ed25519"
    fi

    print_success "All prerequisites satisfied"
}

sync_toolchain() {
    print_header "Syncing Toolchain"
    require_uv || return 1
    uv sync
    print_success "Toolchain synchronized"
}

install_collections() {
    print_header "Installing Ansible Collections"

    if [[ -f "requirements.yml" ]]; then
        uv run ansible-galaxy collection install -r requirements.yml
        print_success "Ansible collections installed"
    else
        print_error "requirements.yml not found"
        return 1
    fi
}

validate_inventory() {
    print_header "Validating Inventory"

    if [[ -f "inventory/hosts.ini" ]]; then
        print_success "inventory/hosts.ini exists"

        # Check for placeholder IPs
        if grep -q "100\.100\.100\|203\.0\.113" inventory/hosts.ini; then
            print_warning "Inventory contains placeholder IP addresses"
            print_info "Edit inventory/hosts.ini with your actual server IPs"
        fi
    else
        print_warning "inventory/hosts.ini not found"
        print_info "Copy the example: cp inventory/hosts.ini.example inventory/hosts.ini"
        print_info "Then edit with your server details"
    fi
}

setup_secrets() {
    print_header "Setting Up Encrypted Secrets"

    if [[ -f "inventory/group_vars/all/secrets.sops.yml" ]]; then
        print_success "secrets.sops.yml already exists"
        print_info "To edit: make sops-edit"
        return 0
    fi

    if [[ -f "inventory/group_vars/all/secrets.sops.yml.example" ]]; then
        print_info "Copying example secrets file..."
        cp inventory/group_vars/all/secrets.sops.yml.example inventory/group_vars/all/secrets.sops.yml
        chmod 600 inventory/group_vars/all/secrets.sops.yml

        print_warning "Secrets file created but NOT encrypted"
        print_info "To encrypt: make sops-encrypt (age key required)"
        print_info "Required secrets (edit with make sops-edit):"
        echo "  - vault_github_token (GitHub Personal Access Token)"
        echo "  - vault_image_namespace / vault_github_username (registry)"
        echo "  - restic_r2_* and restic_password_* (backups)"
        echo "  - The Tailscale trio (tailscale_auth_key, tailscale_acl_key,"
        echo "    tailscale_acl_client_id) stays in the Ansible vault"
        echo "    (secrets.yml) until expiry (OPERATIONS_RUNBOOK §7.4)."
    else
        print_error "secrets.sops.yml.example not found"
        return 1
    fi
}

validate_playbooks() {
    print_header "Validating Ansible Playbooks"

    if [[ -f "playbooks/site.yml" ]]; then
        uv run ansible-playbook playbooks/site.yml --syntax-check
        print_success "playbooks/site.yml syntax valid"
    else
        print_error "playbooks/site.yml not found"
        return 1
    fi

    for pb in \
        playbooks/l1/baseline.yml \
        playbooks/l2/compliance.yml \
        playbooks/l2/hardening.yml \
        playbooks/l2/lockdown.yml \
        playbooks/l2/tailscale-recover.yml \
        playbooks/l2/validate.yml \
        playbooks/l3/exporters.yml \
        playbooks/l3/stack.yml \
        playbooks/l4/edge.yml \
        playbooks/l6/backup-appdata.yml \
        playbooks/l6/backup-databases.yml \
        playbooks/l6/backup-stack.yml \
        playbooks/l6/backup-timers.yml \
        playbooks/l6/engine.yml \
        playbooks/l6/portainer.yml \
        playbooks/ops/bootstrap.yml \
        playbooks/ops/local-devices.yml \
        playbooks/ops/nuke.yml \
        playbooks/ops/validate.yml \
        playbooks/_shared/apt_lock_preflight.yml; do
        if [[ -f "$pb" ]]; then
            uv run ansible-playbook "$pb" --syntax-check && print_success "$pb syntax valid"
        else
            print_warning "$pb not found (optional)"
        fi
    done
}

validate_secrets() {
    print_header "Validating Secrets"

    if [[ -f "inventory/group_vars/all/secrets.sops.yml" ]]; then
        print_success "secrets.sops.yml exists"
        local secret_mode
        secret_mode=$(stat -c "%a" inventory/group_vars/all/secrets.sops.yml 2>/dev/null || echo "600")
        if [[ "$secret_mode" != "600" ]]; then
            print_warning "secrets.sops.yml permissions are not 600"
            print_info "Fix: chmod 600 inventory/group_vars/all/secrets.sops.yml"
        fi
    else
        print_warning "secrets.sops.yml not found"
        print_info "Copy the example: cp inventory/group_vars/all/secrets.sops.yml.example inventory/group_vars/all/secrets.sops.yml"
        print_info "Then encrypt it: make sops-encrypt"
    fi
}

show_next_steps() {
    print_header "Next Steps"

    echo -e "${GREEN}1.${NC} Edit inventory/hosts.ini with your server IPs"
    echo -e "${GREEN}2.${NC} Configure secrets (SOPS + age):"
    echo -e "   ${BLUE}make sops-encrypt${NC}"
    echo -e "   ${BLUE}make sops-edit${NC} (edit later)"
    echo -e "${GREEN}3.${NC} Run full hardening:"
    echo -e "   ${BLUE}make deploy${NC}"

    echo -e "\n${YELLOW}Need help?${NC}"
    echo -e "📚 Documentation: ${REPO_URL}"
    echo -e "💼 Professional services: See documentation for details."
}

run_validation() {
    print_header "Running Complete Validation"

    check_prerequisites
    validate_inventory
    validate_secrets
    validate_playbooks

    print_success "Validation complete!"
    show_next_steps
}

show_help() {
    cat << EOF
Developmi Stack - Bootstrap Script

Usage: ./setup.sh [OPTION]

Options:
    --install    Sync toolchain and install collections
    --validate   Run complete validation (default)
    --help       Show this help message

Examples:
    ./setup.sh --install   # Sync toolchain and install Ansible collections
  ./setup.sh --validate  # Validate setup and show next steps
  ./setup.sh             # Same as --validate

Environment:
  This script sets up the Developmi Stack for first use.
    It checks prerequisites, syncs the toolchain, installs collections,
    and validates configuration.

Business Model:
  The hardening script is FREE (MIT licensed).
  Extended monitoring and compliance auditing services available.
EOF
}

# Main execution
main() {
    local mode="validate"

    # Parse arguments
    if [[ $# -gt 0 ]]; then
        case "$1" in
            --install)
                mode="install"
                ;;
            --validate)
                mode="validate"
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    fi

    enter_repo_root

    print_header "Developmi Stack Bootstrap"
    print_info "Mode: $mode"
    print_info "Repository: $REPO_NAME"
    print_info "Business Model: Open Source Code, Optional Monitoring Services"
    echo ""

    case "$mode" in
        install)
            require_uv || exit 1
            sync_toolchain
            install_collections
            check_prerequisites
            validate_inventory
            setup_secrets
            validate_playbooks
            print_success "Installation complete!"
            ;;
        validate)
            run_validation
            ;;
    esac

    echo -e "\n${GREEN}=== Bootstrap Complete ===${NC}"
}

# Run main function with all arguments
main "$@"
