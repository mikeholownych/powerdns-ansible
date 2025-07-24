# common

Prepare systems for PowerDNS deployment. Installs required packages, sets base configuration and provides health check utilities.

## Requirements
- Ansible 2.9+
- Root privileges on managed nodes

## Role Variables
See `defaults/main.yml` for full list.

| Variable | Default | Description |
|----------|---------|-------------|
| `common_alert_email` | `ops@example.com` | Address for system alerts |
| `powerdns_user` | `pdns` | System user for PowerDNS processes |
| `powerdns_config_dir` | `/etc/powerdns` | Base configuration directory |

## Example Playbook
```yaml
- hosts: all
  roles:
    - role: common
```
