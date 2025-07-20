# PowerDNS Operational Excellence Guide

This guide covers the advanced operational features for ongoing updates, upgrades, flexible feature toggles, and safe idempotent configuration changes in the PowerDNS infrastructure.

## 🎯 **OPERATIONAL MODES**

### Operation Modes
The system supports four distinct operation modes:

```yaml
# Set in vars/operational.yml or as extra vars
operation_mode: install    # Fresh installation
operation_mode: update     # Configuration updates only
operation_mode: upgrade    # Package upgrades + config updates
operation_mode: maintenance # Maintenance tasks only
```

### Usage Examples
```bash
# Fresh installation
ansible-playbook -i inventory/hosts.yml powerdns-operational-playbook.yml \
  -e "operation_mode=install"

# Configuration updates only
ansible-playbook -i inventory/hosts.yml powerdns-operational-playbook.yml \
  -e "operation_mode=update" --tags config

# Full system upgrade
ansible-playbook -i inventory/hosts.yml powerdns-operational-playbook.yml \
  -e "operation_mode=upgrade"

# Maintenance mode
ansible-playbook -i inventory/hosts.yml powerdns-operational-playbook.yml \
  -e "operation_mode=maintenance" --tags maintenance
```

## 🎛️ **FLEXIBLE FEATURE TOGGLES**

### DNS Features Configuration
Enable/disable specific functionality through the `dns_features` list:

```yaml
# vars/operational.yml
dns_features:
  - base              # Core PowerDNS (always required)
  - mysql             # MySQL backend
  - api               # PowerDNS API
  - logging           # Enhanced logging
  - monitoring        # Prometheus monitoring
  - security          # Security hardening
  - backup            # Backup functionality
  
  # Optional features (uncomment to enable)
  # - dnssec          # DNSSEC support
  # - zone_templates  # Zone template management
  # - ssl             # SSL/TLS support
  # - galera          # MySQL Galera cluster
  # - dnsdist         # DNSdist load balancer
  # - self_healing    # Self-healing automation
  # - zones_as_code   # Zones-as-Code management
```

### Feature-Specific Deployments
```bash
# Deploy only monitoring features
ansible-playbook powerdns-operational-playbook.yml \
  -e "dns_features=['base','mysql','monitoring']"

# Enable DNSSEC on existing installation
ansible-playbook powerdns-operational-playbook.yml \
  -e "operation_mode=update" \
  -e "dns_features=['base','mysql','api','dnssec']" \
  --tags dnssec

# Add load balancing to existing setup
ansible-playbook powerdns-operational-playbook.yml \
  -e "operation_mode=update" \
  -e "dns_features=['base','mysql','api','dnsdist']" \
  --tags dnsdist
```

## 🔄 **SAFE IDEMPOTENT OPERATIONS**

### Change Detection
The system automatically tracks configuration changes:

```yaml
# Automatic change detection
config_change_detection: true
force_config_update: false
restart_services_on_change: true

# Configuration hashing
track_config_changes: true
config_hash_algorithm: "sha256"
config_backup_on_change: true
```

### Idempotent Behavior
- **Configuration files**: Only updated if content changes
- **Services**: Only restarted if configuration changes
- **Packages**: Only installed/upgraded if version differs
- **Database**: Schema changes applied only if needed

### Change Tracking
```bash
# View configuration changes
powerdns-state show-changes

# View current configuration hashes
powerdns-state show-hashes

# Compare configurations
powerdns-state diff --from yesterday --to now
```

## 🏗️ **MULTI-NODE ROLE-AWARE BEHAVIOR**

### Server Roles
The system automatically detects and configures based on server roles:

```yaml
# Auto-detected from inventory groups
server_role: primary      # powerdns_primary group
server_role: secondary    # powerdns_secondary group  
server_role: recursor     # powerdns_recursor group
server_role: loadbalancer # haproxy_servers or dnsdist_servers group
```

### Role-Specific Features
```yaml
# Primary server features
primary_server_features:
  - zone_management
  - dnssec_signing
  - api_write_access
  - backup_source

# Secondary server features  
secondary_server_features:
  - zone_replication
  - backup_target
  - monitoring_client

# Recursor features
recursor_server_features:
  - recursive_queries
  - cache_management
  - forwarding_rules

# Load balancer features
loadbalancer_features:
  - health_checks
  - traffic_distribution
  - failover_detection
```

### Multi-Node Coordination
```yaml
# Cluster-aware updates
cluster_aware_updates: true
rolling_update_enabled: true
rolling_update_batch_size: 1
rolling_update_delay: 60  # seconds

# Quorum requirements
require_quorum_for_changes: true
minimum_healthy_nodes: 1
```

## 📦 **VERSION MANAGEMENT**

### Package Version Control
```yaml
# Specify exact versions (optional)
powerdns_version: "4.8.3-4build3"
mysql_version: "8.0.35-0ubuntu0.22.04.1"
prometheus_version: "2.45.0"

# Version management policies
pin_package_versions: false
allowed_version_drift: "minor"  # major, minor, patch, none

# Update policies
auto_security_updates: true
auto_minor_updates: false
auto_major_updates: false
```

### Upgrade Procedures
```bash
# Safe upgrade with validation
ansible-playbook powerdns-operational-playbook.yml \
  -e "operation_mode=upgrade" \
  -e "validate_before_deploy=true" \
  -e "backup_before_upgrade=true"

# Rollback if needed
ansible-playbook powerdns-operational-playbook.yml \
  -e "operation_mode=rollback"
```

## 🔍 **VALIDATION AND TESTING**

### Pre-Deployment Validation
```bash
# Run validation only
ansible-playbook powerdns-operational-playbook.yml --tags validation

# Validate specific features
ansible-playbook powerdns-operational-playbook.yml \
  --tags validation \
  -e "dns_features=['base','mysql','dnssec']"
```

### Testing Framework
```bash
# Smoke tests (quick validation)
ansible-playbook powerdns-operational-playbook.yml --tags testing

# Integration tests (comprehensive)
ansible-playbook powerdns-operational-playbook.yml \
  -e "run_integration_tests=true" \
  --tags integration

# Performance tests
ansible-playbook powerdns-operational-playbook.yml \
  -e "run_performance_tests=true" \
  --tags performance
```

## 📊 **STATE MANAGEMENT**

### State Tracking
```bash
# View current system state
powerdns-state show

# Generate state report
powerdns-state report --format json

# Check for configuration drift
powerdns-state drift-check

# View change history
powerdns-state history --last 10
```

### State Reports
```bash
# Current state location
/var/lib/powerdns-state/reports/current-state.json

# Change log
/var/lib/powerdns-state/change-log.json

# Deployment metadata
/var/lib/powerdns-state/deployment-metadata.json
```

## 🔧 **OPERATIONAL COMMANDS**

### Daily Operations
```bash
# Check system health
powerdns-state health-check

# View service status
systemctl status pdns mysql prometheus

# Check DNS resolution
dig @localhost example.com SOA

# View logs
journalctl -u pdns -f
```

### Maintenance Operations
```bash
# Backup system
ansible-playbook powerdns-operational-playbook.yml \
  -e "operation_mode=maintenance" \
  --tags backup

# Update configurations only
ansible-playbook powerdns-operational-playbook.yml \
  -e "operation_mode=update" \
  --tags config

# Rotate DNSSEC keys
ansible-playbook powerdns-operational-playbook.yml \
  -e "operation_mode=maintenance" \
  --tags dnssec-rotation
```

### Emergency Procedures
```bash
# Emergency mode (minimal features)
ansible-playbook powerdns-operational-playbook.yml \
  -e "emergency_mode=true" \
  -e "dns_features=['base','mysql']"

# Quick rollback
ansible-playbook powerdns-operational-playbook.yml \
  -e "operation_mode=rollback" \
  --tags emergency

# Service recovery
/opt/self-healing/scripts/auto-recovery.sh --emergency
```

## 🎯 **TAG-BASED EXECUTION**

### Available Tags
```bash
# Infrastructure tags
--tags validation      # Pre-deployment validation
--tags base           # Core PowerDNS installation
--tags mysql          # MySQL database setup
--tags galera         # Galera cluster setup
--tags dnsdist        # DNSdist load balancer
--tags haproxy        # HAProxy load balancer
--tags keepalived     # VRRP failover

# Feature tags
--tags dnssec         # DNSSEC configuration
--tags api            # PowerDNS API setup
--tags monitoring     # Prometheus monitoring
--tags security       # Security hardening
--tags backup         # Backup configuration
--tags logging        # Log management

# Operation tags
--tags config         # Configuration updates only
--tags packages       # Package management only
--tags testing        # Run tests
--tags cleanup        # Cleanup operations
--tags maintenance    # Maintenance tasks
```

### Tag Usage Examples
```bash
# Update only DNSSEC configuration
ansible-playbook powerdns-operational-playbook.yml \
  --tags dnssec \
  -e "operation_mode=update"

# Install monitoring only
ansible-playbook powerdns-operational-playbook.yml \
  --tags monitoring \
  -e "dns_features=['monitoring']"

# Run security hardening
ansible-playbook powerdns-operational-playbook.yml \
  --tags security \
  -e "operation_mode=update"
```

## 🔄 **ROLLING UPDATES**

### Rolling Update Configuration
```yaml
# Enable rolling updates for multi-node clusters
rolling_update_enabled: true
rolling_update_batch_size: 1      # Update one node at a time
rolling_update_delay: 60          # Wait 60 seconds between nodes
require_quorum_for_changes: true  # Ensure minimum nodes remain healthy
```

### Rolling Update Execution
```bash
# Perform rolling update
ansible-playbook powerdns-operational-playbook.yml \
  -e "operation_mode=update" \
  -e "rolling_update_enabled=true" \
  --serial 1

# Rolling upgrade with validation
ansible-playbook powerdns-operational-playbook.yml \
  -e "operation_mode=upgrade" \
  -e "validate_after_upgrade=true" \
  --serial 1
```

## 📈 **MONITORING AND ALERTING**

### Operational Metrics
- Configuration drift detection
- Service health monitoring
- Performance metrics collection
- Change tracking and auditing

### Alert Conditions
```yaml
# Alert thresholds
alert_on_config_drift: true
alert_on_service_failure: true
alert_on_performance_degradation: true

# Notification channels
notification_channels:
  - email
  - slack
  - webhook
```

## 🛡️ **SECURITY AND COMPLIANCE**

### Audit Logging
```yaml
# Comprehensive audit trail
audit_all_changes: true
audit_log_retention: 90  # days
audit_log_encryption: true

# Change approval workflow
require_change_approval: false
change_approval_timeout: 3600  # seconds
```

### Compliance Features
- Change tracking and approval workflows
- Encrypted audit logs
- Configuration drift detection
- Automated security hardening

## 🚀 **BEST PRACTICES**

### Development Workflow
1. **Test in staging** with same configuration
2. **Use feature flags** to enable/disable functionality
3. **Validate before deployment** with preflight checks
4. **Monitor after changes** with health checks
5. **Keep rollback ready** with backup points

### Production Operations
1. **Use rolling updates** for zero-downtime changes
2. **Enable drift detection** for configuration monitoring
3. **Automate backups** before major changes
4. **Monitor continuously** with Prometheus/Grafana
5. **Document changes** in change log

### Emergency Procedures
1. **Emergency mode** disables non-critical features
2. **Quick rollback** restores previous configuration
3. **Service recovery** automatically restarts failed services
4. **Health monitoring** provides real-time status
5. **Alert notifications** inform operators of issues

## 📋 **TROUBLESHOOTING**

### Common Issues
```bash
# Configuration validation failed
ansible-playbook powerdns-operational-playbook.yml --tags validation --check

# Service won't start
journalctl -u pdns --no-pager -l

# Database connectivity issues
mysql -u pdns_user -p -h database_host

# DNS resolution problems
dig @localhost example.com SOA +trace

# Monitoring not working
curl http://localhost:9090/metrics
```

### Recovery Procedures
```bash
# Restore from backup
ansible-playbook powerdns-operational-playbook.yml \
  -e "operation_mode=maintenance" \
  --tags restore

# Reset to known good state
ansible-playbook powerdns-operational-playbook.yml \
  -e "operation_mode=rollback"

# Emergency service restart
systemctl restart pdns mysql
```

This operational excellence framework provides enterprise-grade management capabilities for PowerDNS infrastructure with safe, predictable, and auditable operations.
