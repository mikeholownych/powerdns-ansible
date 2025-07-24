# powerdns

Install and manage the PowerDNS authoritative server with MySQL backend, DNSSEC and API support.

## Requirements
- Ansible 2.9+
- Root privileges on managed nodes

## Role Variables
Refer to `defaults/main.yml` for the full list of tunable variables. Common options include:

| Variable | Default | Description |
|----------|---------|-------------|
| `powerdns_api_key` | `changeme` | API key for PowerDNS HTTP API |
| `powerdns_service_name` | `pdns` | Service name of the PowerDNS daemon |
| `powerdns_webserver_port` | `8081` | API webserver port |
| `primary_domains` | `[]` | List of zones managed on the primary server |

## Dependencies
- `mysql` role for database provisioning

## Example Playbook
```yaml
- hosts: powerdns_servers
  roles:
    - role: powerdns
```
