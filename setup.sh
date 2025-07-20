#!/bin/bash
# PowerDNS Ansible Setup Script
# Prepares the environment for PowerDNS deployment

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Logging functions
info() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }
banner() { echo -e "${CYAN}[SETUP]${NC} $1"; }

# Show usage
show_usage() {
    cat << EOF
PowerDNS Ansible Setup Script

Usage: $0 [OPTIONS]

OPTIONS:
    --install-deps      Install Ansible and dependencies
    --setup-vault       Setup Ansible Vault configuration
    --check-prereqs     Check prerequisites
    --generate-keys     Generate SSH keys for deployment
    --test-connection   Test connection to target servers
    --full-setup        Run complete setup process
    --help              Show this help message

EXAMPLES:
    $0 --full-setup                 # Complete setup process
    $0 --install-deps               # Install dependencies only
    $0 --setup-vault                # Setup vault only
    $0 --test-connection            # Test server connectivity

EOF
}

# Check if running as correct user
check_user() {
    if [[ "$USER" != "mike" ]]; then
        error "This script should be run as user 'mike'"
        exit 1
    fi
    
    info "Running as user: $USER"
}

# Check prerequisites
check_prerequisites() {
    banner "=== Checking Prerequisites ==="
    
    local missing_deps=()
    
    # Check Python
    if command -v python3 &> /dev/null; then
        local python_version=$(python3 --version | cut -d' ' -f2)
        success "Python 3 found: $python_version"
    else
        missing_deps+=("python3")
    fi
    
    # Check pip
    if command -v pip3 &> /dev/null; then
        success "pip3 found"
    else
        missing_deps+=("python3-pip")
    fi
    
    # Check git
    if command -v git &> /dev/null; then
        success "git found"
    else
        missing_deps+=("git")
    fi
    
    # Check SSH
    if command -v ssh &> /dev/null; then
        success "SSH found"
    else
        missing_deps+=("openssh-client")
    fi
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        error "Missing dependencies: ${missing_deps[*]}"
        info "Install with: sudo apt-get install ${missing_deps[*]}"
        return 1
    fi
    
    success "All prerequisites satisfied"
    return 0
}

# Install Ansible and dependencies
install_dependencies() {
    banner "=== Installing Dependencies ==="
    
    # Update package cache
    info "Updating package cache..."
    sudo apt-get update -qq
    
    # Install system packages
    info "Installing system packages..."
    sudo apt-get install -y python3 python3-pip git openssh-client sshpass
    
    # Install Ansible
    info "Installing Ansible..."
    pip3 install --user ansible
    
    # Add pip bin to PATH if not already there
    if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
        export PATH="$HOME/.local/bin:$PATH"
    fi
    
    # Install Ansible collections
    info "Installing Ansible collections..."
    ansible-galaxy collection install community.mysql
    ansible-galaxy collection install ansible.posix
    
    success "Dependencies installed successfully"
}

# Generate SSH keys
generate_ssh_keys() {
    banner "=== SSH Key Generation ==="
    
    local ssh_key_path="$HOME/.ssh/id_rsa"
    
    if [[ -f "$ssh_key_path" ]]; then
        warning "SSH key already exists: $ssh_key_path"
        read -p "Generate new key? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            info "Keeping existing SSH key"
            return 0
        fi
    fi
    
    info "Generating SSH key pair..."
    ssh-keygen -t rsa -b 4096 -f "$ssh_key_path" -N "" -C "mike@powerdns-ansible"
    
    success "SSH key generated: $ssh_key_path"
    
    info "Public key:"
    cat "${ssh_key_path}.pub"
    
    echo ""
    warning "Copy the public key above to your target servers:"
    info "ssh-copy-id mike@your-server-ip"
}

# Setup Ansible Vault
setup_vault() {
    banner "=== Ansible Vault Setup ==="
    
    # Create vault password file
    if [[ -f ".vault_pass" ]]; then
        warning "Vault password file already exists"
        read -p "Create new vault password? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            info "Keeping existing vault password"
            return 0
        fi
    fi
    
    info "Creating vault password..."
    read -s -p "Enter vault password: " vault_password
    echo
    read -s -p "Confirm vault password: " vault_password_confirm
    echo
    
    if [[ "$vault_password" != "$vault_password_confirm" ]]; then
        error "Passwords don't match"
        return 1
    fi
    
    echo "$vault_password" > .vault_pass
    chmod 600 .vault_pass
    success "Vault password file created"
    
    # Setup secrets file
    if [[ ! -f "vault/secrets.yml" ]]; then
        info "Creating secrets file from template..."
        cp vault/secrets-template.yml vault/secrets.yml
        
        info "Please edit vault/secrets.yml with your actual secrets"
        read -p "Open editor now? (Y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            ${EDITOR:-nano} vault/secrets.yml
        fi
        
        info "Encrypting secrets file..."
        ansible-vault encrypt vault/secrets.yml
        success "Secrets file encrypted"
    else
        info "Secrets file already exists"
    fi
}

# Test connection to servers
test_connection() {
    banner "=== Testing Server Connectivity ==="
    
    if [[ ! -f "inventory/hosts.yml" ]]; then
        error "Inventory file not found: inventory/hosts.yml"
        return 1
    fi
    
    info "Testing Ansible connectivity..."
    if ansible all -m ping; then
        success "All servers are reachable"
    else
        error "Some servers are not reachable"
        info "Check SSH keys and server accessibility"
        return 1
    fi
    
    info "Testing sudo access..."
    if ansible all -m shell -a "sudo whoami"; then
        success "Sudo access confirmed on all servers"
    else
        error "Sudo access issues detected"
        return 1
    fi
}

# Validate configuration
validate_config() {
    banner "=== Configuration Validation ==="
    
    # Check inventory
    if [[ -f "inventory/hosts.yml" ]]; then
        success "Inventory file found"
        
        info "Validating inventory..."
        if ansible-inventory --list > /dev/null; then
            success "Inventory syntax is valid"
        else
            error "Inventory syntax errors detected"
            return 1
        fi
    else
        error "Inventory file missing: inventory/hosts.yml"
        return 1
    fi
    
    # Check playbook
    if [[ -f "powerdns-playbook.yml" ]]; then
        success "Main playbook found"
        
        info "Validating playbook syntax..."
        if ansible-playbook powerdns-playbook.yml --syntax-check; then
            success "Playbook syntax is valid"
        else
            error "Playbook syntax errors detected"
            return 1
        fi
    else
        error "Main playbook missing: powerdns-playbook.yml"
        return 1
    fi
    
    # Check vault
    if [[ -f "vault/secrets.yml" ]]; then
        success "Vault secrets file found"
        
        if [[ -f ".vault_pass" ]]; then
            info "Testing vault decryption..."
            if ansible-vault view vault/secrets.yml > /dev/null; then
                success "Vault decryption successful"
            else
                error "Vault decryption failed"
                return 1
            fi
        else
            warning "Vault password file not found"
        fi
    else
        warning "Vault secrets file not found"
    fi
    
    success "Configuration validation completed"
}

# Run deployment
run_deployment() {
    banner "=== Running PowerDNS Deployment ==="
    
    warning "This will deploy PowerDNS to your servers"
    read -p "Continue with deployment? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        info "Deployment cancelled"
        return 0
    fi
    
    info "Starting PowerDNS deployment..."
    
    # Run the playbook
    if ansible-playbook powerdns-playbook.yml --ask-vault-pass; then
        success "PowerDNS deployment completed successfully!"
        
        echo ""
        info "=== Deployment Summary ==="
        info "PowerDNS servers have been configured and are ready for use"
        info "Management scripts are available on target servers:"
        info "  - /usr/local/bin/pdns-zone-manager.sh"
        info "  - /usr/local/bin/pdns-stats.sh"
        info "  - /usr/local/bin/pdns-maintenance.sh"
        info "  - /usr/local/bin/powerdns-health-check.sh"
        
    else
        error "Deployment failed"
        return 1
    fi
}

# Full setup process
full_setup() {
    banner "=== PowerDNS Ansible Full Setup ==="
    
    info "This will perform a complete setup including:"
    info "  1. Check prerequisites"
    info "  2. Install dependencies"
    info "  3. Generate SSH keys (if needed)"
    info "  4. Setup Ansible Vault"
    info "  5. Validate configuration"
    info "  6. Test server connectivity"
    info "  7. Run deployment"
    
    echo ""
    read -p "Continue with full setup? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        info "Setup cancelled"
        return 0
    fi
    
    # Run setup steps
    check_prerequisites || return 1
    install_dependencies || return 1
    generate_ssh_keys || return 1
    setup_vault || return 1
    validate_config || return 1
    test_connection || return 1
    
    echo ""
    success "Setup completed successfully!"
    
    read -p "Run deployment now? (Y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        run_deployment
    else
        info "Run deployment later with: ansible-playbook powerdns-playbook.yml --ask-vault-pass"
    fi
}

# Main execution
main() {
    # Check if running as correct user
    check_user
    
    # Parse command line arguments
    case "${1:-}" in
        "--install-deps")
            install_dependencies
            ;;
        "--setup-vault")
            setup_vault
            ;;
        "--check-prereqs")
            check_prerequisites
            ;;
        "--generate-keys")
            generate_ssh_keys
            ;;
        "--test-connection")
            test_connection
            ;;
        "--validate-config")
            validate_config
            ;;
        "--deploy")
            run_deployment
            ;;
        "--full-setup")
            full_setup
            ;;
        "--help"|"-h")
            show_usage
            ;;
        "")
            info "PowerDNS Ansible Setup Script"
            info "Use --help for usage information"
            info "Use --full-setup for complete setup process"
            ;;
        *)
            error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
