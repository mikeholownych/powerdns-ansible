# mysql

Provision a MySQL/MariaDB server for use by PowerDNS. Handles basic security hardening and optional replication.

## Requirements
- Ansible 2.9+
- Root privileges on managed nodes

## Role Variables
See `defaults/main.yml` for all options. Common variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `mysql_root_password` | *(unset)* | Root password for the database server |
| `mysql_service_name` | distribution dependent | Service name for MySQL/MariaDB |
| `mysql_replication_user` | `replication` | Replication user when replication is enabled |

## Example Playbook
```yaml
- hosts: database_servers
  roles:
    - role: mysql
```
