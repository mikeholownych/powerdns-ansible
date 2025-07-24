# dnsdist

Configure dnsdist to provide advanced DNS load balancing and filtering.

## Requirements
- Ansible 2.9+
- Root privileges on managed nodes

## Role Variables
Frequently used variables are shown below. Consult `defaults/main.yml` for the full set.

| Variable | Default | Description |
|----------|---------|-------------|
| `dnsdist_port` | `53` | Listening port for DNS traffic |
| `dnsdist_console_port` | `5199` | Administrative console port |
| `dnsdist_webserver_port` | `8083` | Optional web interface port |
| `dnsdist_enable_webserver` | `false` | Enable the internal web server |
| `dnsdist_geodns_enabled` | `false` | Enable GeoDNS routing support |
| `dnsdist_geodns_rules` | `[]` | GeoDNS country-to-pool mapping |
| `dnsdist_geodns_database_path` | `/usr/share/GeoIP/GeoLite2-Country.mmdb` | GeoIP database path |

## Dependencies
None

## Example Playbook
```yaml
- hosts: dns_load_balancers
  roles:
    - role: dnsdist
```
