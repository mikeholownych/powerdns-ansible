# PowerDNS Ansible Playbook - Enhanced Features

This document describes the enhanced features added to the PowerDNS Ansible playbook for enterprise-grade deployment with high availability, load balancing, and failover capabilities.

## 🚀 New Features Added

### 1. 🔧 HAProxy Load Balancing
- **DNS Load Balancing**: Round-robin load balancing for DNS queries (UDP/TCP)
- **API Load Balancing**: Load balancing for PowerDNS API endpoints
- **MySQL Load Balancing**: Database connection load balancing
- **Health Checks**: Intelligent health monitoring with automatic backend removal
- **Statistics Dashboard**: Web-based HAProxy statistics at `:8404/stats`
- **Management Scripts**: Command-line tools for HAProxy management

**Key Files:**
- `roles/haproxy/` - Complete HAProxy role
- `roles/haproxy/templates/haproxy.cfg.j2` - Main configuration template
- `roles/haproxy/templates/haproxy-stats.sh.j2` - Management script

### 2. 🌐 PowerDNS Recursor Split Architecture
- **Separate Recursive Service**: Dedicated PowerDNS Recursor instances
- **Split-Horizon DNS**: Forward local zones to authoritative servers
- **Performance Optimized**: Dedicated caching and recursion settings
- **DNSSEC Validation**: Built-in DNSSEC validation support
- **API Support**: Optional Recursor API for monitoring
- **Integration**: Seamless integration with authoritative servers

**Key Files:**
- `roles/recursor/` - Complete Recursor role
- `roles/recursor/templates/recursor.conf.j2` - Recursor configuration
- `roles/recursor/templates/forward-zones.conf.j2` - Zone forwarding

### 3. 🔐 Enhanced MySQL High Availability
- **Master-Slave Replication**: Automatic MySQL replication setup
- **Failover Scripts**: Automated failover and promotion scripts
- **Health Monitoring**: Continuous replication health checks
- **Read-Only Management**: Automatic read-only mode switching
- **Backup Integration**: Enhanced backup with replication awareness
- **Performance Tuning**: Replication-optimized MySQL configuration

**Key Files:**
- Enhanced `roles/mysql/tasks/main.yml` with replication support
- `roles/mysql/templates/mysql-replication-master.cnf.j2`
- `roles/mysql/templates/mysql-replication-slave.cnf.j2`

### 4. ⚡ Keepalived VRRP Failover
- **Virtual IP Management**: Automatic VIP failover between servers
- **Service Health Checks**: Multi-service health monitoring
- **Priority-Based Failover**: Intelligent failover based on service health
- **Notification System**: Email and webhook notifications
- **Multiple VIPs**: Separate VIPs for different services
- **Preemption Control**: Configurable preemption behavior

**Key Files:**
- `roles/keepalived/` - Complete Keepalived role
- `roles/keepalived/templates/keepalived.conf.j2` - VRRP configuration
- `roles/keepalived/templates/check_*.sh.j2` - Health check scripts

## 📋 Architecture Overview

```
                    ┌─────────────────┐
                    │   HAProxy LB    │
                    │  192.168.1.95   │
                    │  VIP: .100/.101 │
                    └─────────┬───────┘
                              │
              ┌───────────────┼───────────────┐
              │               │               │
    ┌─────────▼─────────┐    │    ┌─────────▼─────────┐
    │   PowerDNS Auth   │    │    │   PowerDNS Auth   │
    │  192.168.1.97     │    │    │  192.168.1.98     │
    │  (Primary)        │    │    │  (Secondary)      │
    └─────────┬─────────┘    │    └─────────┬─────────┘
              │              │              │
    ┌─────────▼─────────┐    │    ┌─────────▼─────────┐
    │   MySQL Master   │    │    │   MySQL Slave     │
    │  192.168.1.97     │    │    │  192.168.1.98     │
    └───────────────────┘    │    └───────────────────┘
                             │
              ┌──────────────┼──────────────┐
              │              │              │
    ┌─────────▼─────────┐    │    ┌─────────▼─────────┐
    │  PowerDNS Recursor│    │    │  PowerDNS Recursor│
    │  192.168.1.99     │    │    │  192.168.1.100    │
    └───────────────────┘    │    └───────────────────┘
                             │
                    ┌────────▼────────┐
                    │   Keepalived    │
                    │   VRRP Master   │
                    └─────────────────┘
```

## 🛠️ Configuration

### Inventory Configuration

The enhanced inventory includes new server groups:

```yaml
# inventory/hosts.yml
powerdns_recursor:
  hosts:
    recursor1.holownych.com:
      ansible_host: 192.168.1.99
    recursor2.holownych.com:
      ansible_host: 192.168.1.100

haproxy_servers:
  hosts:
    lb1.holownych.com:
      ansible_host: 192.168.1.95
    lb2.holownych.com:
      ansible_host: 192.168.1.96
```

### Variable Configuration

Key variables in `vars/main.yml`:

```yaml
# HAProxy Configuration
haproxy_enabled: true
haproxy_stats_enabled: true
haproxy_dns_port: 53
haproxy_api_enabled: true

# Recursor Configuration
recursor_enabled: true
recursor_port: 5353
recursor_auth_integration_enabled: true

# Keepalived Configuration
keepalived_enabled: true
keepalived_virtual_ip: 192.168.1.100
keepalived_dns_virtual_ip: 192.168.1.101

# MySQL Replication
mysql_replication_enabled: true
mysql_ha_enabled: true
```

## 🚀 Deployment

### Full Deployment
```bash
# Deploy all components
ansible-playbook -i inventory/hosts.yml powerdns-playbook.yml

# Deploy specific components
ansible-playbook -i inventory/hosts.yml powerdns-playbook.yml --tags haproxy
ansible-playbook -i inventory/hosts.yml powerdns-playbook.yml --tags recursor
ansible-playbook -i inventory/hosts.yml powerdns-playbook.yml --tags keepalived
```

### Targeted Deployments
```bash
# Deploy only to HAProxy servers
ansible-playbook -i inventory/hosts.yml powerdns-playbook.yml --limit haproxy_servers

# Deploy only to Recursor servers
ansible-playbook -i inventory/hosts.yml powerdns-playbook.yml --limit powerdns_recursor

# Enable specific features
ansible-playbook -i inventory/hosts.yml powerdns-playbook.yml -e "mysql_replication_enabled=true"
```

## 📊 Monitoring and Management

### HAProxy Statistics
- **URL**: `http://192.168.1.95:8404/stats`
- **Credentials**: admin/admin123 (configurable)
- **Features**: Real-time backend status, connection statistics, manual server control

### Management Scripts
```bash
# HAProxy management
/usr/local/bin/haproxy-stats.sh status
/usr/local/bin/haproxy-stats.sh health
/usr/local/bin/haproxy-stats.sh test

# Keepalived management
/usr/local/bin/keepalived-status.sh
/usr/local/bin/keepalived-monitor.sh

# MySQL replication status
/usr/local/bin/mysql-health-check.sh
```

### Health Checks
- **PowerDNS**: DNS query response, API availability
- **MySQL**: Connection test, replication status
- **HAProxy**: Backend availability, response times
- **Keepalived**: VIP status, service health

## 🔧 Customization

### HAProxy Backends
Add custom backends by modifying `haproxy.cfg.j2`:
```jinja2
backend custom_backend
    mode http
    balance roundrobin
    server web1 192.168.1.10:80 check
    server web2 192.168.1.11:80 check
```

### Keepalived VIPs
Configure additional VIPs in `vars/main.yml`:
```yaml
keepalived_custom_instances:
  - name: VI_CUSTOM
    router_id: 54
    vip: 192.168.1.103
    priority: 100
```

### Recursor Forwarding
Configure zone forwarding in `vars/main.yml`:
```yaml
recursor_forward_zones:
  example.com: "192.168.1.10;192.168.1.11"
  internal.local: "192.168.1.20"
```

## 🔍 Troubleshooting

### Common Issues

1. **VIP Not Assigned**
   ```bash
   # Check keepalived status
   systemctl status keepalived
   ip addr show | grep 192.168.1.100
   ```

2. **HAProxy Backend Down**
   ```bash
   # Check backend health
   /usr/local/bin/haproxy-stats.sh health
   curl -s http://192.168.1.95:8404/stats
   ```

3. **MySQL Replication Lag**
   ```bash
   # Check replication status
   mysql -e "SHOW SLAVE STATUS\G"
   /usr/local/bin/mysql-health-check.sh
   ```

4. **DNS Resolution Issues**
   ```bash
   # Test DNS resolution
   dig @192.168.1.100 example.com
   dig @192.168.1.101 google.com
   ```

### Log Locations
- **HAProxy**: `/var/log/haproxy.log`
- **Keepalived**: `/var/log/keepalived.log`, `/var/log/keepalived-notify.log`
- **PowerDNS**: `/var/log/powerdns/`
- **MySQL**: `/var/log/mysql/`

## 🔐 Security Considerations

### Firewall Rules
The playbook automatically configures firewall rules for:
- DNS (53/tcp, 53/udp)
- PowerDNS API (8081/tcp)
- HAProxy Stats (8404/tcp)
- Recursor (5353/tcp, 5353/udp)
- VRRP Protocol (112)

### Authentication
- **HAProxy Stats**: Username/password authentication
- **PowerDNS API**: API key authentication
- **MySQL**: Dedicated monitoring users with minimal privileges
- **Keepalived**: VRRP authentication

## 📈 Performance Tuning

### HAProxy Optimization
- Connection pooling
- Health check intervals
- Load balancing algorithms
- Timeout configurations

### MySQL Replication
- Binary log optimization
- InnoDB settings for replication
- Network timeout configurations
- Crash-safe replication settings

### PowerDNS Recursor
- Cache size optimization
- Thread configuration
- Network timeout tuning
- DNSSEC validation settings

## 🎯 Next Steps

1. **SSL/TLS**: Add SSL termination to HAProxy
2. **Monitoring**: Integrate with Prometheus/Grafana
3. **Automation**: Add automated failover testing
4. **Scaling**: Add horizontal scaling capabilities
5. **Backup**: Enhance backup strategies for HA setup

---

For detailed configuration options, see the individual role documentation and template files.
