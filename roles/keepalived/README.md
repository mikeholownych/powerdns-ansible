# keepalived

Deploy VRRP based failover for PowerDNS services.

## Requirements
- Ansible 2.9+
- Root privileges on managed nodes

## Role Variables
Key variables are listed below. See `defaults/main.yml` for details.

| Variable | Default | Description |
|----------|---------|-------------|
| `keepalived_virtual_ipaddress` | `["192.168.1.100"]` | Virtual IPs managed by keepalived |
| `keepalived_router_id` | `51` | VRRP router ID |
| `keepalived_priority` | `100` | Priority of the local node |
| `keepalived_vrrp_auth_password` | `changeme` | Authentication password |

## Dependencies
None

## Example Playbook
```yaml
- hosts: dns_servers
  roles:
    - role: keepalived
```
