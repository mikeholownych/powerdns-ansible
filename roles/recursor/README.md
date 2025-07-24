# recursor

Install and manage the PowerDNS Recursor for DNS resolution.

## Requirements
- Ansible 2.9+
- Root privileges on managed nodes

## Role Variables
Important variables are listed below. See `defaults/main.yml` for a complete reference.

| Variable | Default | Description |
|----------|---------|-------------|
| `recursor_port` | `5353` | Listening port for recursive queries |
| `recursor_api_enabled` | `false` | Enable the optional HTTP API |
| `recursor_api_port` | `8082` | API listening port |
| `recursor_api_key` | `""` | API authentication key |
| `recursor_dnssec_enabled` | `true` | Validate DNSSEC signatures |
| `recursor_api_bind_address` | `{{ ansible_default_ipv4.address }}` | API bind address |
| `recursor_allowed_networks` | `["127.0.0.1/8"]` | Networks allowed to query |

## Dependencies
None

## Example Playbook
```yaml
- hosts: recursor_servers
  roles:
    - role: recursor
```
