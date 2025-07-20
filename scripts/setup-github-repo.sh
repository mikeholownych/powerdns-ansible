#!/bin/bash
# GitHub Repository Setup Script
# Prepares the PowerDNS Operations Collection for GitHub publication

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
REPO_NAME="community.powerdns_ops"
GITHUB_ORG="ansible-collections"
BRANCH_NAME="main"

# Helper functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if git is installed
    if ! command -v git &> /dev/null; then
        log_error "Git is not installed. Please install git first."
        exit 1
    fi
    
    # Check if we're in a git repository
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        log_warning "Not in a git repository. Initializing..."
        git init
        git branch -M main
    fi
    
    # Check if GitHub CLI is available
    if command -v gh &> /dev/null; then
        log_success "GitHub CLI detected"
        GH_CLI_AVAILABLE=true
    else
        log_warning "GitHub CLI not found. Manual repository creation required."
        GH_CLI_AVAILABLE=false
    fi
    
    log_success "Prerequisites check completed"
}

# Clean up sensitive or development-only files
cleanup_files() {
    log_info "Cleaning up files for public release..."
    
    # Remove development files that shouldn't be public
    local files_to_remove=(
        ".vault_pass"
        "vault/secrets.yml"
        "ansible.log"
        "retry/"
        ".molecule/"
        "__pycache__/"
        "*.pyc"
        ".pytest_cache/"
        "local/"
        ".local/"
        "test-results/"
        "packaging/"
    )
    
    for file in "${files_to_remove[@]}"; do
        if [[ -e "$file" ]]; then
            rm -rf "$file"
            log_info "Removed: $file"
        fi
    done
    
    # Ensure sensitive inventory is generic
    if [[ -f "inventory/hosts.yml" ]]; then
        log_info "Updating inventory to use generic examples..."
        cat > inventory/hosts.yml << 'EOF'
---
# Example inventory for PowerDNS Operations Collection
# Copy this file and customize for your environment

all:
  children:
    powerdns_primary:
      hosts:
        dns1.example.com:
          ansible_host: 192.168.1.10
          server_role: primary
    
    powerdns_secondary:
      hosts:
        dns2.example.com:
          ansible_host: 192.168.1.11
          server_role: secondary
    
    powerdns_recursor:
      hosts:
        recursor1.example.com:
          ansible_host: 192.168.1.12
          server_role: recursor
    
    haproxy_servers:
      hosts:
        lb1.example.com:
          ansible_host: 192.168.1.13
          server_role: loadbalancer
    
    mysql_servers:
      hosts:
        db1.example.com:
          ansible_host: 192.168.1.14
        db2.example.com:
          ansible_host: 192.168.1.15

  vars:
    # Common variables
    ansible_user: ubuntu
    ansible_ssh_private_key_file: ~/.ssh/id_rsa
    
    # DNS configuration
    primary_domains:
      - example.com
      - internal.local
    
    # Network settings
    dns_network: "192.168.1.0/24"
    management_network: "192.168.1.0/24"
EOF
    fi
    
    log_success "File cleanup completed"
}

# Validate collection structure
validate_structure() {
    log_info "Validating Ansible collection structure..."
    
    # Required files for Ansible collection
    local required_files=(
        "galaxy.yml"
        "README.md"
        "LICENSE"
        "roles/"
        "CHANGELOG.md"
    )
    
    for file in "${required_files[@]}"; do
        if [[ ! -e "$file" ]]; then
            log_error "Required file missing: $file"
            exit 1
        fi
    done
    
    # Validate galaxy.yml
    if command -v ansible-galaxy &> /dev/null; then
        log_info "Validating galaxy.yml..."
        if ansible-galaxy collection build --force > /dev/null 2>&1; then
            log_success "Collection structure is valid"
            rm -f community-powerdns_ops-*.tar.gz
        else
            log_error "Collection structure validation failed"
            exit 1
        fi
    fi
    
    log_success "Structure validation completed"
}

# Set up git configuration
setup_git() {
    log_info "Setting up git configuration..."
    
    # Add all files to git
    git add .
    
    # Create initial commit if needed
    if ! git log --oneline -n 1 > /dev/null 2>&1; then
        log_info "Creating initial commit..."
        git commit -m "Initial commit: PowerDNS Operations Collection

- Enterprise-grade PowerDNS infrastructure automation
- Multi-node deployment with role-aware configuration
- DNSSEC automation and security hardening
- Self-healing and monitoring capabilities
- High availability clustering support
- Comprehensive testing and CI/CD pipeline"
    fi
    
    # Set up remote if not exists
    if ! git remote get-url origin > /dev/null 2>&1; then
        if [[ "$GH_CLI_AVAILABLE" == "true" ]]; then
            log_info "Remote will be set up during repository creation"
        else
            log_warning "No git remote configured. You'll need to add it manually:"
            log_warning "git remote add origin https://github.com/${GITHUB_ORG}/${REPO_NAME}.git"
        fi
    fi
    
    log_success "Git setup completed"
}

# Create GitHub repository
create_github_repo() {
    if [[ "$GH_CLI_AVAILABLE" == "true" ]]; then
        log_info "Creating GitHub repository..."
        
        # Check if repository already exists
        if gh repo view "${GITHUB_ORG}/${REPO_NAME}" > /dev/null 2>&1; then
            log_warning "Repository already exists: ${GITHUB_ORG}/${REPO_NAME}"
        else
            # Create repository
            gh repo create "${GITHUB_ORG}/${REPO_NAME}" \
                --public \
                --description "Production-ready PowerDNS infrastructure automation with enterprise-grade features" \
                --homepage "https://ansible-collections.github.io/community.powerdns_ops/" \
                --add-readme=false
            
            log_success "GitHub repository created"
        fi
        
        # Set up remote
        git remote add origin "https://github.com/${GITHUB_ORG}/${REPO_NAME}.git" 2>/dev/null || true
        
        # Push to GitHub
        log_info "Pushing to GitHub..."
        git push -u origin main
        
        log_success "Code pushed to GitHub"
    else
        log_warning "GitHub CLI not available. Manual steps required:"
        echo ""
        echo "1. Create repository at: https://github.com/new"
        echo "   - Repository name: ${REPO_NAME}"
        echo "   - Description: Production-ready PowerDNS infrastructure automation"
        echo "   - Public repository"
        echo ""
        echo "2. Add remote and push:"
        echo "   git remote add origin https://github.com/${GITHUB_ORG}/${REPO_NAME}.git"
        echo "   git push -u origin main"
    fi
}

# Set up GitHub repository settings
setup_github_settings() {
    if [[ "$GH_CLI_AVAILABLE" == "true" ]]; then
        log_info "Configuring GitHub repository settings..."
        
        # Enable GitHub Pages (if supported)
        gh api repos/"${GITHUB_ORG}/${REPO_NAME}"/pages \
            --method POST \
            --field source.branch=main \
            --field source.path=/docs \
            2>/dev/null || log_warning "Could not enable GitHub Pages"
        
        # Set repository topics
        gh api repos/"${GITHUB_ORG}/${REPO_NAME}"/topics \
            --method PUT \
            --field names='["ansible","powerdns","dns","infrastructure","automation","devops","security","monitoring","self-healing","high-availability"]' \
            2>/dev/null || log_warning "Could not set repository topics"
        
        log_success "GitHub settings configured"
    fi
}

# Display next steps
show_next_steps() {
    log_success "Repository setup completed!"
    echo ""
    log_info "Next steps:"
    echo ""
    echo "1. 🔧 Configure GitHub repository secrets:"
    echo "   - GALAXY_API_KEY: For Ansible Galaxy publishing"
    echo "   - PACKAGECLOUD_TOKEN: For package distribution"
    echo ""
    echo "2. 📋 Set up GitHub repository settings:"
    echo "   - Enable branch protection for main branch"
    echo "   - Require PR reviews and status checks"
    echo "   - Enable security alerts and dependency scanning"
    echo ""
    echo "3. 🚀 Trigger first CI/CD run:"
    echo "   - Push a small change to trigger workflows"
    echo "   - Verify all tests pass"
    echo "   - Check package building works"
    echo ""
    echo "4. 📦 Publish to Ansible Galaxy:"
    echo "   - Create a release tag (v1.0.0)"
    echo "   - Verify automatic publishing works"
    echo ""
    echo "5. 📚 Update documentation:"
    echo "   - Set up GitHub Pages for documentation"
    echo "   - Add usage examples and tutorials"
    echo ""
    if [[ "$GH_CLI_AVAILABLE" == "true" ]]; then
        echo "Repository URL: $(gh repo view --json url --jq .url)"
    else
        echo "Repository URL: https://github.com/${GITHUB_ORG}/${REPO_NAME}"
    fi
}

# Main execution
main() {
    echo ""
    log_info "PowerDNS Operations Collection - GitHub Setup"
    log_info "=============================================="
    echo ""
    
    check_prerequisites
    cleanup_files
    validate_structure
    setup_git
    create_github_repo
    setup_github_settings
    show_next_steps
    
    echo ""
    log_success "🎉 GitHub repository setup completed successfully!"
}

# Run main function
main "$@"
