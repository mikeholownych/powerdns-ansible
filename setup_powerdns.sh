#!/bin/bash

# PowerDNS Incremental Configuration Script
# Run by user 'mike' with passwordless sudo access
# Configures either PRIMARY or SECONDARY server based on .env file

set -euo pipefail

# Configuration variables
PDNS_CONFIG_FILE="/etc/powerdns/pdns.conf"
BACKUP_DIR="/etc/powerdns/backups"
LOG_FILE="/var/log/powerdns-config.log"
SERVICE_NAME="pdns"
ENV_FILE=".env"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Environment variables from .env file
API_KEY=""
DB_PASSWORD=""
SERVER_ROLE=""
MASTER_SERVER_IP=""
SLAVE_NOTIFICATION_IPS=""
ALLOW_AXFR_IPS=""
NS1_IP=""
NS2_IP=""
AD_PRIMARY_IP=""
AD_SECONDARY_IP=""

# Project-specific configuration variables
declare -A PROJECT_CONFIG=(
    ["NS1_IP"]="192.168.1.97"
    ["NS2_IP"]="192.168.1.98"
    ["AD_PRIMARY_IP"]="192.168.1.104"
    ["AD_SECONDARY_IP"]="192.168.1.123"
    ["PRIMARY_DOMAINS"]="home.lan,dns.holownych.com,kube.cluster,lan.holownych.com,servers.holownych.com"
    ["AD_DOMAINS"]="_msdcs.adroot.holownych.com,adroot.holownych.com"
    ["REVERSE_ZONES"]="1.168.192.in-addr.arpa,2.168.192.in-addr.arpa,5.0.10.in-addr.arpa"
)

# Logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | sudo tee -a "$LOG_FILE" > /dev/null 2>&1 || true
}

# Colored output functions
info() {
    echo -e "${BLUE}[INFO]${NC} $1"
    log "INFO: $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
    log "SUCCESS: $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
    log "WARNING: $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    log "ERROR: $1"
}

debug() {
    echo -e "${PURPLE}[DEBUG]${NC} $1"
    log "DEBUG: $1"
}

banner() {
    echo -e "${CYAN}[BANNER]${NC} $1"
    log "BANNER: $1"
}

# Show usage information
show_usage() {
    cat << EOF
PowerDNS Configuration Script - Enterprise Edition
Usage: $0 [OPTIONS]

OPTIONS:
    --interactive       Interactive configuration wizard (recommended)
    --install          Fresh PowerDNS installation
    --configure        Configure existing PowerDNS installation
    --mysql            Database setup only
    --backup           Backup current configuration
    --restore FILE     Restore from backup file
    --health-check     Run comprehensive health checks
    --sre-check        Validate SRE best practices
    --quick-recovery   Emergency recovery procedures
    --start            Start PowerDNS service
    --stop             Stop PowerDNS service
    --restart          Restart PowerDNS service
    --status           Show service status
    --logs             Show recent logs
    --help             Show this help message

EXAMPLES:
    $0 --interactive           # Guided setup (recommended)
    $0 --install               # Fresh installation
    $0 --health-check          # System health validation
    $0 --backup                # Create configuration backup
    $0 --restore backup.conf   # Restore from backup

ENVIRONMENT:
    The script uses a .env file for configuration. Run with --interactive
    to create this file through a guided wizard.

REQUIREMENTS:
    - Run as user 'mike' with passwordless sudo access
    - MySQL/MariaDB server installed and running
    - Network connectivity to configured servers

For more information, visit: https://doc.powerdns.com/
EOF
}

# Get current server IP
get_current_server_ip() {
    ip route get 8.8.8.8 2>/dev/null | grep -oP 'src \K\S+' || echo "127.0.0.1"
}

# Validate IP address format
validate_ip() {
    local ip="$1"
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        IFS='.' read -ra ADDR <<< "$ip"
        for i in "${ADDR[@]}"; do
            if [[ $i -gt 255 ]]; then
                return 1
            fi
        done
        return 0
    fi
    return 1
}

# Determine server role based on IP
determine_server_role_by_ip() {
    local current_ip=$(get_current_server_ip)
    
    if [[ "$current_ip" == "${PROJECT_CONFIG[NS1_IP]}" ]]; then
        echo "PRIMARY"
    elif [[ "$current_ip" == "${PROJECT_CONFIG[NS2_IP]}" ]]; then
        echo "SECONDARY"
    else
        echo "${SERVER_ROLE:-PRIMARY}"
    fi
}

# Check if running as mike with sudo access
check_user_and_sudo() {
    if [[ "$USER" != "mike" ]]; then
        error "This script must be run as user 'mike'"
        exit 1
    fi
    
    # Test sudo access
    if ! sudo -n true 2>/dev/null; then
        error "User 'mike' requires passwordless sudo access"
        exit 1
    fi
    
    info "Running as user 'mike' with sudo access"
}

# Detect Linux distribution
detect_distro() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        echo "$ID"
    elif [[ -f /etc/redhat-release ]]; then
        echo "centos"
    elif [[ -f /etc/debian_version ]]; then
        echo "debian"
    else
        echo "unknown"
    fi
}

# Check system dependencies
check_dependencies() {
    info "Checking system dependencies..."
    
    local missing_deps=()
    local required_commands=("curl" "openssl" "systemctl" "mysql")
    
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_deps+=("$cmd")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        warning "Missing dependencies: ${missing_deps[*]}"
        
        local distro=$(detect_distro)
        case "$distro" in
            "ubuntu"|"debian")
                info "Install with: sudo apt-get install curl openssl mysql-client"
                ;;
            "centos"|"rhel"|"rocky"|"alma"|"fedora")
                info "Install with: sudo dnf install curl openssl mysql"
                ;;
        esac
        
        read -p "Install missing dependencies automatically? (Y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            install_dependencies
        else
            error "Cannot proceed without required dependencies"
            return 1
        fi
    fi
    
    success "All dependencies satisfied"
    return 0
}

# Install missing dependencies
install_dependencies() {
    local distro=$(detect_distro)
    
    case "$distro" in
        "ubuntu"|"debian")
            sudo apt-get update -qq
            sudo apt-get install -y curl openssl mysql-client
            ;;
        "centos"|"rhel"|"rocky"|"alma"|"fedora")
            sudo dnf install -y curl openssl mysql
            ;;
        *)
            error "Cannot auto-install dependencies for $distro"
            return 1
            ;;
    esac
}

# Create backup directory
setup_backup_dir() {
    if [[ ! -d "$BACKUP_DIR" ]]; then
        sudo mkdir -p "$BACKUP_DIR"
        sudo chmod 750 "$BACKUP_DIR"
        info "Created backup directory: $BACKUP_DIR"
    fi
}

# Backup current configuration
backup_config() {
    local backup_name="$1"
    local backup_file="$BACKUP_DIR/pdns.conf.backup_${backup_name}_$(date +%Y%m%d_%H%M%S)"
    
    if [[ -f "$PDNS_CONFIG_FILE" ]]; then
        sudo cp "$PDNS_CONFIG_FILE" "$backup_file"
        sudo chmod 640 "$backup_file"
        info "Configuration backed up to: $backup_file" >&2
        echo "$backup_file"
    else
        warning "PowerDNS config file not found: $PDNS_CONFIG_FILE" >&2
        echo ""
    fi
}

# Restore configuration from backup
restore_config() {
    local backup_file="$1"
    if [[ -f "$backup_file" ]]; then
        sudo cp "$backup_file" "$PDNS_CONFIG_FILE"
        sudo chmod 640 "$PDNS_CONFIG_FILE"
        success "Configuration restored from: $backup_file"
        return 0
    else
        error "Backup file not found: $backup_file"
        return 1
    fi
}

# Load environment variables from .env file
load_env_file() {
    if [[ ! -f "$ENV_FILE" ]]; then
        error ".env file not found. Run with --interactive to create one."
        return 1
    fi
    
    # Source the .env file safely
    set -a
    source "$ENV_FILE"
    set +a
    
    # Validate required variables
    local required_vars=("API_KEY" "DB_PASSWORD" "SERVER_ROLE")
    local missing_vars=()
    
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            missing_vars+=("$var")
        fi
    done
    
    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        error "Missing required environment variables: ${missing_vars[*]}"
        return 1
    fi
    
    success "Environment variables loaded successfully"
    return 0
}

# Create secure MySQL connection config
setup_mysql_connection() {
    local mysql_config=$(mktemp)
    cat > "$mysql_config" << EOF
[client]
user=powerdns
password=$DB_PASSWORD
host=localhost
database=powerdns
EOF
    chmod 600 "$mysql_config"
    echo "$mysql_config"
}

# Setup MySQL database and user
setup_database() {
    info "Setting up MySQL database for PowerDNS..."
    
    # Check if MySQL is running
    if ! systemctl is-active --quiet mysql && ! systemctl is-active --quiet mariadb; then
        error "MySQL/MariaDB service is not running"
        return 1
    fi
    
    # Create database and user
    local mysql_root_config=$(mktemp)
    cat > "$mysql_root_config" << 'EOF'
[client]
user=root
EOF
    chmod 600 "$mysql_root_config"
    
    # Create database
    mysql --defaults-file="$mysql_root_config" -e "CREATE DATABASE IF NOT EXISTS powerdns;" 2>/dev/null || {
        error "Failed to create PowerDNS database. Please ensure MySQL root access is configured."
        rm -f "$mysql_root_config"
        return 1
    }
    
    # Create user and grant privileges
    mysql --defaults-file="$mysql_root_config" -e "CREATE USER IF NOT EXISTS 'powerdns'@'localhost' IDENTIFIED BY '$DB_PASSWORD';" 2>/dev/null
    mysql --defaults-file="$mysql_root_config" -e "GRANT ALL PRIVILEGES ON powerdns.* TO 'powerdns'@'localhost';" 2>/dev/null
    mysql --defaults-file="$mysql_root_config" -e "FLUSH PRIVILEGES;" 2>/dev/null
    
    rm -f "$mysql_root_config"
    
    # Test connection
    local mysql_config=$(setup_mysql_connection)
    if mysql --defaults-file="$mysql_config" -e "SELECT 1;" &>/dev/null; then
        success "Database setup completed successfully"
        rm -f "$mysql_config"
        return 0
    else
        error "Failed to connect to PowerDNS database"
        rm -f "$mysql_config"
        return 1
    fi
}

# Generate PowerDNS configuration
generate_pdns_config() {
    info "Generating PowerDNS configuration for $SERVER_ROLE server..."
    
    local config_content=""
    local current_ip=$(get_current_server_ip)
    
    # Common configuration
    config_content+="# PowerDNS Configuration - Generated $(date)
# Server Role: $SERVER_ROLE
# Server IP: $current_ip

# Basic settings
config-dir=/etc/powerdns
daemon=yes
guardian=yes
setuid=pdns
setgid=pdns

# Logging
log-dns-details=yes
log-dns-queries=yes
loglevel=4
logging-facility=0

# Performance tuning
cache-ttl=20
negquery-cache-ttl=60
query-cache-ttl=20
recursive-cache-ttl=10

# Security
allow-recursion=127.0.0.1,192.168.0.0/16
local-address=$current_ip
local-port=53

# Database backend
launch=gmysql
gmysql-host=localhost
gmysql-user=powerdns
gmysql-password=$DB_PASSWORD
gmysql-dbname=powerdns

# API settings
api=yes
api-key=$API_KEY
webserver=yes
webserver-address=$current_ip
webserver-port=8081
webserver-allow-from=127.0.0.1,192.168.0.0/16

"

    # Role-specific configuration
    if [[ "$SERVER_ROLE" == "PRIMARY" ]]; then
        config_content+="# PRIMARY server configuration
master=yes
slave=no

# Zone transfers
allow-axfr-ips=${ALLOW_AXFR_IPS:-192.168.0.0/16}
also-notify=${SLAVE_NOTIFICATION_IPS:-}

# SOA settings
default-soa-name=ns1.${PROJECT_CONFIG[PRIMARY_DOMAINS]%%,*}
default-soa-mail=admin.${PROJECT_CONFIG[PRIMARY_DOMAINS]%%,*}

"
    else
        config_content+="# SECONDARY server configuration
master=no
slave=yes

# Master server
slave-cycle-interval=60
"
        if [[ -n "$MASTER_SERVER_IP" ]]; then
            config_content+="# Configured master servers
# Add master zones via pdnsutil or API
"
        fi
    fi
    
    # Write configuration
    echo "$config_content" | sudo tee "$PDNS_CONFIG_FILE" > /dev/null
    sudo chmod 640 "$PDNS_CONFIG_FILE"
    sudo chown root:pdns "$PDNS_CONFIG_FILE" 2>/dev/null || true
    
    success "PowerDNS configuration generated successfully"
}

# Service management functions
manage_service() {
    local action="$1"
    
    case "$action" in
        "start")
            info "Starting PowerDNS service..."
            sudo systemctl start "$SERVICE_NAME"
            ;;
        "stop")
            info "Stopping PowerDNS service..."
            sudo systemctl stop "$SERVICE_NAME"
            ;;
        "restart")
            info "Restarting PowerDNS service..."
            sudo systemctl restart "$SERVICE_NAME"
            ;;
        "status")
            sudo systemctl status "$SERVICE_NAME" --no-pager
            return $?
            ;;
        "enable")
            info "Enabling PowerDNS service..."
            sudo systemctl enable "$SERVICE_NAME"
            ;;
        *)
            error "Invalid service action: $action"
            return 1
            ;;
    esac
    
    if [[ "$action" != "status" ]]; then
        sleep 2
        if systemctl is-active --quiet "$SERVICE_NAME"; then
            success "PowerDNS service $action completed successfully"
        else
            error "PowerDNS service $action failed"
            return 1
        fi
    fi
}

# Health check functions
health_check() {
    banner "=== PowerDNS Health Check ==="
    
    local health_status=0
    
    # Service status
    info "Checking PowerDNS service status..."
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        success "PowerDNS service is running"
    else
        error "PowerDNS service is not running"
        health_status=1
    fi
    
    # Configuration file
    info "Checking configuration file..."
    if [[ -f "$PDNS_CONFIG_FILE" ]]; then
        success "Configuration file exists: $PDNS_CONFIG_FILE"
    else
        error "Configuration file missing: $PDNS_CONFIG_FILE"
        health_status=1
    fi
    
    # Database connectivity
    info "Checking database connectivity..."
    if [[ -f "$ENV_FILE" ]]; then
        load_env_file
        local mysql_config=$(setup_mysql_connection)
        if mysql --defaults-file="$mysql_config" -e "SELECT 1;" &>/dev/null; then
            success "Database connection successful"
        else
            error "Database connection failed"
            health_status=1
        fi
        rm -f "$mysql_config"
    else
        warning "No .env file found, skipping database check"
    fi
    
    # DNS resolution test
    info "Testing DNS resolution..."
    local current_ip=$(get_current_server_ip)
    if dig @"$current_ip" localhost +short &>/dev/null; then
        success "DNS resolution test passed"
    else
        warning "DNS resolution test failed (may be normal if no zones configured)"
    fi
    
    # API endpoint test
    if [[ -f "$ENV_FILE" ]]; then
        info "Testing API endpoint..."
        local api_response=$(curl -s -H "X-API-Key: $API_KEY" "http://$current_ip:8081/api/v1/servers" 2>/dev/null || echo "")
        if [[ -n "$api_response" ]]; then
            success "API endpoint responding"
        else
            warning "API endpoint not responding"
        fi
    fi
    
    if [[ $health_status -eq 0 ]]; then
        success "=== Health check completed successfully ==="
    else
        error "=== Health check found issues ==="
    fi
    
    return $health_status
}

# SRE best practices check
sre_check() {
    banner "=== SRE Best Practices Validation ==="
    
    local sre_score=0
    local total_checks=10
    
    # File permissions
    info "Checking file permissions..."
    if [[ -f "$PDNS_CONFIG_FILE" ]] && [[ "$(stat -c %a "$PDNS_CONFIG_FILE")" == "640" ]]; then
        success "PowerDNS config file has secure permissions (640)"
        ((sre_score++))
    else
        warning "PowerDNS config file permissions should be 640"
    fi
    
    if [[ -f "$ENV_FILE" ]] && [[ "$(stat -c %a "$ENV_FILE")" == "600" ]]; then
        success ".env file has secure permissions (600)"
        ((sre_score++))
    else
        warning ".env file permissions should be 600"
    fi
    
    # Backup directory
    info "Checking backup configuration..."
    if [[ -d "$BACKUP_DIR" ]]; then
        success "Backup directory exists"
        ((sre_score++))
    else
        warning "Backup directory not found"
    fi
    
    # Service configuration
    info "Checking service configuration..."
    if systemctl is-enabled --quiet "$SERVICE_NAME"; then
        success "PowerDNS service is enabled for auto-start"
        ((sre_score++))
    else
        warning "PowerDNS service should be enabled for auto-start"
    fi
    
    # Logging
    info "Checking logging configuration..."
    if [[ -f "$LOG_FILE" ]]; then
        success "Log file exists and is accessible"
        ((sre_score++))
    else
        warning "Log file not found or not accessible"
    fi
    
    # Security checks
    info "Checking security configuration..."
    if [[ -f "$PDNS_CONFIG_FILE" ]] && grep -q "api-key=" "$PDNS_CONFIG_FILE"; then
        success "API key is configured"
        ((sre_score++))
    else
        warning "API key should be configured for security"
    fi
    
    # Network configuration
    info "Checking network configuration..."
    local current_ip=$(get_current_server_ip)
    if [[ "$current_ip" != "127.0.0.1" ]]; then
        success "Server has proper network configuration"
        ((sre_score++))
    else
        warning "Server network configuration may need attention"
    fi
    
    # Database security
    info "Checking database security..."
    if [[ -f "$ENV_FILE" ]]; then
        load_env_file
        if [[ ${#DB_PASSWORD} -ge 12 ]]; then
            success "Database password meets minimum length requirements"
            ((sre_score++))
        else
            warning "Database password should be at least 12 characters"
        fi
    fi
    
    # Monitoring readiness
    info "Checking monitoring readiness..."
    if [[ -f "$PDNS_CONFIG_FILE" ]] && grep -q "webserver=yes" "$PDNS_CONFIG_FILE"; then
        success "Web server enabled for monitoring"
        ((sre_score++))
    else
        warning "Web server should be enabled for monitoring"
    fi
    
    # Documentation
    info "Checking documentation..."
    if [[ -f "README.md" ]] || [[ -f "SETUP.md" ]]; then
        success "Documentation files found"
        ((sre_score++))
    else
        warning "Consider adding documentation (README.md or SETUP.md)"
    fi
    
    # Calculate score
    local percentage=$((sre_score * 100 / total_checks))
    
    echo ""
    banner "=== SRE Score: $sre_score/$total_checks ($percentage%) ==="
    
    if [[ $percentage -ge 80 ]]; then
        success "Excellent SRE compliance!"
    elif [[ $percentage -ge 60 ]]; then
        warning "Good SRE compliance, room for improvement"
    else
        error "SRE compliance needs attention"
    fi
    
    return $((total_checks - sre_score))
}

# Quick recovery procedures
quick_recovery() {
    banner "=== PowerDNS Quick Recovery ==="
    
    info "Starting emergency recovery procedures..."
    
    # Stop service
    info "Stopping PowerDNS service..."
    sudo systemctl stop "$SERVICE_NAME" 2>/dev/null || true
    
    # Check for backup
    if [[ -d "$BACKUP_DIR" ]]; then
        local latest_backup=$(ls -t "$BACKUP_DIR"/pdns.conf.backup_* 2>/dev/null | head -1)
        if [[ -n "$latest_backup" ]]; then
            warning "Found backup: $latest_backup"
            read -p "Restore from this backup? (Y/n): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Nn]$ ]]; then
                restore_config "$latest_backup"
            fi
        fi
    fi
    
    # Regenerate configuration if .env exists
    if [[ -f "$ENV_FILE" ]]; then
        info "Regenerating configuration from .env file..."
        load_env_file && generate_pdns_config
    fi
    
    # Restart service
    info "Starting PowerDNS service..."
    manage_service start
    
    # Run health check
    sleep 3
    health_check
    
    success "Quick recovery completed"
}

# Interactive .env file creation with validation
interactive_env_setup() {
    banner "=== INTERACTIVE POWERDNS CONFIGURATION SETUP ==="
    info "This will guide you through creating a secure .env configuration file"
    echo ""
    
    # Check if .env already exists
    if [[ -f "$ENV_FILE" ]]; then
        warning ".env file already exists"
        read -p "Do you want to overwrite it? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            info "Keeping existing .env file"
            return 0
        fi
        # Create backup directory if it doesn't exist
        setup_backup_dir
        cp "$ENV_FILE" "${BACKUP_DIR}/env.backup.$(date +%Y%m%d_%H%M%S)" 2>/dev/null || true
        info "Existing .env backed up"
    fi
    
    # Detect current server IP and suggest role
    local current_ip=$(get_current_server_ip)
    local suggested_role="PRIMARY"
    
    if [[ "$current_ip" == "${PROJECT_CONFIG[NS1_IP]}" ]]; then
        suggested_role="PRIMARY"
        info "Detected IP $current_ip matches ns1 - suggesting PRIMARY role"
    elif [[ "$current_ip" == "${PROJECT_CONFIG[NS2_IP]}" ]]; then
        suggested_role="SECONDARY" 
        info "Detected IP $current_ip matches ns2 - suggesting SECONDARY role"
    else
        warning "Current IP $current_ip doesn't match expected project IPs"
        info "Expected: ${PROJECT_CONFIG[NS1_IP]} (PRIMARY) or ${PROJECT_CONFIG[NS2_IP]} (SECONDARY)"
    fi
    
    echo ""
    info "=== SERVER ROLE CONFIGURATION ==="
    echo "Available roles:"
    echo "  PRIMARY   - Master server (ns1: ${PROJECT_CONFIG[NS1_IP]})"
    echo "  SECONDARY - Slave server (ns2: ${PROJECT_CONFIG[NS2_IP]})"
    echo ""
    
    local server_role
    while true; do
        read -p "Enter server role [$suggested_role]: " server_role
        server_role=${server_role:-$suggested_role}
        
        if [[ "$server_role" == "PRIMARY" ]] || [[ "$server_role" == "SECONDARY" ]]; then
            break
        else
            error "Invalid role. Please enter PRIMARY or SECONDARY"
        fi
    done
    
    echo ""
    info "=== API KEY CONFIGURATION ==="
    info "API key is used for REST API authentication (64 characters recommended)"
    
    local api_key
    echo "Options:"
    echo "  1. Generate secure random key (recommended)"
    echo "  2. Enter custom key"
    echo ""
    
    read -p "Choose option [1]: " key_option
    key_option=${key_option:-1}
    
    if [[ "$key_option" == "1" ]]; then
        api_key=$(openssl rand -hex 32)
        success "Generated secure API key: ${api_key:0:8}...${api_key: -8}"
    else
        while true; do
            read -s -p "Enter API key (will be hidden): " api_key
            echo
            if [[ ${#api_key} -ge 32 ]]; then
                break
            else
                error "API key must be at least 32 characters long"
            fi
        done
    fi
    
    echo ""
    info "=== DATABASE CONFIGURATION ==="
    info "MySQL database password for PowerDNS user"
    
    local db_password
    echo "Options:"
    echo "  1. Generate secure random password (recommended)"
    echo "  2. Enter custom password"
    echo ""
    
    read -p "Choose option [1]: " db_option
    db_option=${db_option:-1}
    
    if [[ "$db_option" == "1" ]]; then
        db_password=$(openssl rand -base64 24 | tr -d '=+/' | cut -c1-20)
        success "Generated secure database password"
    else
        while true; do
            read -s -p "Enter database password (will be hidden): " db_password
            echo
            read -s -p "Confirm database password: " db_password_confirm
            echo
            
            if [[ "$db_password" == "$db_password_confirm" ]] && [[ ${#db_password} -ge 12 ]]; then
                break
            else
                if [[ "$db_password" != "$db_password_confirm" ]]; then
                    error "Passwords don't match"
                else
                    error "Password must be at least 12 characters long"
                fi
            fi
        done
    fi
    
    echo ""
    info "=== NETWORK CONFIGURATION ==="
    
    # Set defaults based on role and current setup
    local ns1_ip="${PROJECT_CONFIG[NS1_IP]}"
    local ns2_ip="${PROJECT_CONFIG[NS2_IP]}"
    local ad_primary_ip="${PROJECT_CONFIG[AD_PRIMARY_IP]}"
    local ad_secondary_ip="${PROJECT_CONFIG[AD_SECONDARY_IP]}"
    
    read -p "Primary DNS server IP [$ns1_ip]: " input_ns1
    ns1_ip=${input_ns1:-$ns1_ip}
    
    read -p "Secondary DNS server IP [$ns2_ip]: " input_ns2
    ns2_ip=${input_ns2:-$ns2_ip}
    
    read -p "AD Primary server IP [$ad_primary_ip]: " input_ad1
    ad_primary_ip=${input_ad1:-$ad_primary_ip}
    
    read -p "AD Secondary server IP [$ad_secondary_ip]: " input_ad2
    ad_secondary_ip=${input_ad2:-$ad_secondary_ip}
    
    # Role-specific configuration
    local slave_notification_ips=""
    local allow_axfr_ips=""
    local master_server_ip=""
    
    if [[ "$server_role" == "PRIMARY" ]]; then
        echo ""
        info "=== PRIMARY SERVER CONFIGURATION ==="
        
        slave_notification_ips="$ns2_ip"
        read -p "Slave notification IPs [$slave_notification_ips]: " input_slaves
        slave_notification_ips=${input_slaves:-$slave_notification_ips}
        
        allow_axfr_ips="$ns2_ip,$ad_primary_ip,$ad_secondary_ip,192.168.0.0/16"
        read -p "Allow AXFR from IPs/networks [$allow_axfr_ips]: " input_axfr
        allow_axfr_ips=${input_axfr:-$allow_axfr_ips}
        
    else
        echo ""
        info "=== SECONDARY SERVER CONFIGURATION ==="
        
        master_server_ip="$ns1_ip"
        read -p "Master server IP [$master_server_ip]: " input_master
        master_server_ip=${input_master:-$master_server_ip}
    fi
    
    echo ""
    info "=== CONFIGURATION SUMMARY ==="
    echo "Server Role: $server_role"
    echo "Current IP: $current_ip"
    echo "Primary DNS: $ns1_ip"
    echo "Secondary DNS: $ns2_ip"
    echo "AD Primary: $ad_primary_ip"
    echo "AD Secondary: $ad_secondary_ip"
    if [[ "$server_role" == "PRIMARY" ]]; then
        echo "Slave Notifications: $slave_notification_ips"
        echo "AXFR Allowed: $allow_axfr_ips"
    else
        echo "Master Server: $master_server_ip"
    fi
    echo ""
    
    read -p "Save this configuration? (Y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        warning "Configuration cancelled"
        return 1
    fi
    
    # Create .env file
    info "Creating .env file..."
    
    cat > "$ENV_FILE" << EOF
# PowerDNS Configuration Environment Variables
# Project: Split-brain DNS cluster with AD integration
# Generated on: $(date)
# Server Role: $server_role
# Server IP: $current_ip

# Core Configuration
API_KEY="$api_key"
DB_PASSWORD="$db_password"
SERVER_ROLE="$server_role"

# Network Configuration
NS1_IP="$ns1_ip"
NS2_IP="$ns2_ip"
AD_PRIMARY_IP="$ad_primary_ip"
AD_SECONDARY_IP="$ad_secondary_ip"

# Role-specific Configuration
MASTER_SERVER_IP="$master_server_ip"
SLAVE_NOTIFICATION_IPS="$slave_notification_ips"
ALLOW_AXFR_IPS="$allow_axfr_ips"

# Project Domains (comma-separated)
PRIMARY_DOMAINS="${PROJECT_CONFIG[PRIMARY_DOMAINS]}"
AD_DOMAINS="${PROJECT_CONFIG[AD_DOMAINS]}"
REVERSE_ZONES="${PROJECT_CONFIG[REVERSE_ZONES]}"

# Security Settings
WEBSERVER_ALLOW_FROM="127.0.0.1,192.168.0.0/16"
LOCAL_ADDRESS="$current_ip"

# Performance Tuning
CACHE_TTL="20"
NEGQUERY_CACHE_TTL="60"
QUERY_CACHE_TTL="20"
RECURSIVE_CACHE_TTL="10"

# Logging
LOG_DNS_DETAILS="yes"
LOG_DNS_QUERIES="yes"
LOGLEVEL="4"
EOF
    
    # Set secure permissions
    chmod 600 "$ENV_FILE"
    
    success "Configuration saved to $ENV_FILE with secure permissions (600)"
    
    # Offer to continue with setup
    echo ""
    read -p "Continue with PowerDNS installation and configuration? (Y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        return 0
    else
        info "Configuration complete. Run '$0 --install' to continue setup."
        return 1
    fi
}

# Install PowerDNS
install_powerdns() {
    banner "=== PowerDNS Installation ==="
    
    local distro=$(detect_distro)
    
    case "$distro" in
        "ubuntu"|"debian")
            info "Installing PowerDNS on Ubuntu/Debian..."
            sudo apt-get update -qq
            sudo apt-get install -y pdns-server pdns-backend-mysql mysql-server
            ;;
        "centos"|"rhel"|"rocky"|"alma"|"fedora")
            info "Installing PowerDNS on RHEL/CentOS/Fedora..."
            sudo dnf install -y pdns pdns-backend-mysql mariadb-server
            sudo systemctl enable --now mariadb
            ;;
        *)
            error "Unsupported distribution: $distro"
            return 1
            ;;
    esac
    
    # Enable and start MySQL if not running
    if ! systemctl is-active --quiet mysql && ! systemctl is-active --quiet mariadb; then
        info "Starting database service..."
        sudo systemctl enable mysql mariadb 2>/dev/null || true
        sudo systemctl start mysql mariadb 2>/dev/null || true
    fi
    
    success "PowerDNS installation completed"
}

# Show recent logs
show_logs() {
    info "Recent PowerDNS logs:"
    echo ""
    
    # System logs
    if command -v journalctl &> /dev/null; then
        sudo journalctl -u "$SERVICE_NAME" --no-pager -n 20
    fi
    
    # Custom log file
    if [[ -f "$LOG_FILE" ]]; then
        echo ""
        info "Custom log entries:"
        sudo tail -20 "$LOG_FILE" 2>/dev/null || true
    fi
}

# Cleanup function for temporary files
cleanup() {
    local exit_code=$?
    
    # Remove any temporary MySQL config files
    find /tmp -name "tmp.*" -user "$USER" -type f -exec rm -f {} \; 2>/dev/null || true
    
    exit $exit_code
}

# Set trap for cleanup
trap cleanup EXIT

# Main execution logic
main() {
    # Initialize logging
    sudo mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true
    sudo touch "$LOG_FILE" 2>/dev/null || true
    
    # Check user and sudo access first
    check_user_and_sudo
    
    # Parse command line arguments
    case "${1:-}" in
        "--help"|"-h")
            show_usage
            exit 0
            ;;
        "--interactive")
            banner "PowerDNS Interactive Setup"
            check_dependencies || exit 1
            setup_backup_dir
            interactive_env_setup || exit 1
            install_powerdns || exit 1
            setup_database || exit 1
            load_env_file || exit 1
            generate_pdns_config || exit 1
            manage_service enable
            manage_service restart || exit 1
            health_check
            success "Interactive setup completed successfully!"
            ;;
        "--install")
            banner "PowerDNS Fresh Installation"
            check_dependencies || exit 1
            install_powerdns || exit 1
            if [[ -f "$ENV_FILE" ]]; then
                load_env_file || exit 1
                setup_database || exit 1
                generate_pdns_config || exit 1
                manage_service enable
                manage_service restart || exit 1
            else
                warning "No .env file found. Run with --interactive first."
                exit 1
            fi
            ;;
        "--configure")
            banner "PowerDNS Configuration"
            load_env_file || exit 1
            setup_backup_dir
            backup_config "pre-configure"
            generate_pdns_config || exit 1
            manage_service restart || exit 1
            ;;
        "--mysql")
            banner "Database Setup"
            load_env_file || exit 1
            setup_database || exit 1
            ;;
        "--backup")
            setup_backup_dir
            backup_file=$(backup_config "manual")
            if [[ -n "$backup_file" ]]; then
                success "Backup created: $backup_file"
            else
                error "Backup failed"
                exit 1
            fi
            ;;
        "--restore")
            if [[ -z "${2:-}" ]]; then
                error "Please specify backup file to restore"
                exit 1
            fi
            restore_config "$2" || exit 1
            manage_service restart || exit 1
            ;;
        "--health-check")
            health_check || exit 1
            ;;
        "--sre-check")
            sre_check
            ;;
        "--quick-recovery")
            quick_recovery || exit 1
            ;;
        "--start")
            manage_service start || exit 1
            ;;
        "--stop")
            manage_service stop || exit 1
            ;;
        "--restart")
            manage_service restart || exit 1
            ;;
        "--status")
            manage_service status
            ;;
        "--logs")
            show_logs
            ;;
        "")
            # Default behavior - full setup
            banner "PowerDNS Full Setup"
            check_dependencies || exit 1
            
            if [[ ! -f "$ENV_FILE" ]]; then
                warning "No .env file found. Starting interactive setup..."
                interactive_env_setup || exit 1
            fi
            
            load_env_file || exit 1
            setup_backup_dir
            backup_config "pre-setup"
            setup_database || exit 1
            generate_pdns_config || exit 1
            manage_service enable
            manage_service restart || exit 1
            health_check
            success "PowerDNS setup completed successfully!"
            ;;
        *)
            error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
}

# Script entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
