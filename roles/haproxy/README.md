# haproxy

Provide high availability and load balancing for PowerDNS and related services.

## Requirements
- Ansible 2.9+
- Root privileges on managed nodes

## Role Variables
Common variables are shown below. See `defaults/main.yml` for the full list.

| Variable | Default | Description |
|----------|---------|-------------|
| `haproxy_frontend_port` | `53` | Frontend listener port for DNS traffic |
| `haproxy_stats_port` | `8404` | Port for the HAProxy statistics interface |
| `haproxy_stats_password` | `""` | Password for the statistics interface |
| `haproxy_max_connections` | `2000` | Maximum concurrent connections |
| `haproxy_ssl_enabled` | `false` | Enable TLS termination |
| `haproxy_firewall_enabled` | `true` | Manage firewall rules |
| `haproxy_api_port` | `8081` | API listener port |
| `haproxy_mysql_port` | `3306` | MySQL backend port |

## Dependencies
None

## Example Playbook
```yaml
- hosts: load_balancers
  roles:
    - role: haproxy
```
