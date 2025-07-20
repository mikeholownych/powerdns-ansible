# Clean Install Guide

## Overview

The PowerDNS Ansible playbook now includes a comprehensive clean install feature that allows you to completely remove all existing PowerDNS and MySQL components before performing a fresh installation.

## ⚠️ WARNING

**DESTRUCTIVE OPERATION**: The clean install process will permanently delete:
- All PowerDNS packages and configurations
- All MySQL/MariaDB packages and databases
- All DNS zones and records
- All monitoring and security configurations
- All log files and data directories
- All created users and systemd services

**This action is IRREVERSIBLE!**

## How It Works

The clean install functionality is implemented as a new Ansible role called `clean_install` that:

1. **Stops all services** - PowerDNS, MySQL, and monitoring services
2. **Removes packages** - Uses `purge` on Debian/Ubuntu to remove configurations
3. **Deletes data directories** - Removes `/var/lib/mysql`, `/etc/powerdns`, etc.
4. **Cleans configurations** - Removes config files, systemd overrides, scripts
5. **Removes users/groups** - Cleans up created system users
6. **Prepares for fresh install** - Cleans package cache and reloads systemd

## Usage

### Basic Clean Install

```bash
# Enable clean install with confirmation prompt
ansible-playbook powerdns-playbook.yml --ask-vault-pass --extra-vars "perform_clean_install=true"
```

### Force Clean Install (No Confirmation)

```bash
# DANGEROUS: Skip confirmation prompt
ansible-playbook powerdns-playbook.yml --ask-vault-pass --extra-vars "perform_clean_install=true clean_install_force=true"
```

### Clean Install Only (Skip Other Roles)

```bash
# Run only the clean install role
ansible-playbook powerdns-playbook.yml --tags clean_install --ask-vault-pass --extra-vars "perform_clean_install=true"
```

### Using Configuration File

```bash
# Use the example configuration
ansible-playbook powerdns-playbook.yml --extra-vars "@examples/clean-install-example.yml" --ask-vault-pass
```

## Configuration Variables

### Required Variables

- `perform_clean_install: true` - Enables the clean install process

### Optional Variables

- `clean_install_force: false` - Skip confirmation prompt (dangerous!)
- `clean_install_backup_before: false` - Backup before cleaning (future feature)

### Example Configuration

```yaml
# In vars/main.yml or as extra-vars
perform_clean_install: true
clean_install_force: false
clean_install_backup_before: false
```

## What Gets Removed

### Packages
- **PowerDNS**: pdns-server, pdns-backend-mysql, pdns-tools, pdns-recursor
- **MySQL/MariaDB**: mysql-server, mariadb-server, clients, and related packages
- **Monitoring**: prometheus, node_exporter, and related tools

### Directories
- `/etc/powerdns` - PowerDNS configuration
- `/var/lib/mysql` - MySQL data directory
- `/var/lib/powerdns` - PowerDNS data
- `/var/log/powerdns` - PowerDNS logs
- `/var/log/mysql` - MySQL logs
- `/etc/mysql` - MySQL configuration
- `/usr/local/bin/*` - Management scripts

### Services
- PowerDNS systemd service and overrides
- MySQL/MariaDB systemd service and overrides
- Monitoring services (health checks, metrics)
- Logrotate configurations

### Users and Groups
- `powerdns` user and group
- `mysql` user and group
- `prometheus` user and group

## Safety Features

### Confirmation Prompt
By default, the clean install will pause and ask for confirmation before proceeding:

```
Press ENTER to continue with clean install or Ctrl+C to abort
```

### Conditional Execution
The clean install only runs when `perform_clean_install` is explicitly set to `true`.

### Check Mode Support
You can run in check mode to see what would be removed:

```bash
ansible-playbook powerdns-playbook.yml --check --extra-vars "perform_clean_install=true"
```

## Integration with Main Playbook

The clean install role is integrated as the first role in the main playbook:

```yaml
roles:
  - role: clean_install
    tags: ['clean_install', 'cleanup']
    when: perform_clean_install | default(false)
  - role: common
    tags: ['common', 'setup']
  # ... other roles
```

## Best Practices

### 1. Always Backup First
Before running a clean install, ensure you have backups of:
- DNS zone data
- Database dumps
- Configuration files
- Any custom scripts or modifications

### 2. Test in Development
Always test the clean install process in a development environment first.

### 3. Use Check Mode
Run with `--check` to see what would be removed before actually doing it.

### 4. Document Your Environment
Keep documentation of your current configuration to help with reconfiguration.

### 5. Plan Downtime
The clean install process will cause service downtime. Plan accordingly.

## Troubleshooting

### Clean Install Doesn't Run
- Verify `perform_clean_install=true` is set
- Check that the role condition is met
- Ensure you're not skipping the clean_install tag

### Services Won't Stop
- Some services may need manual intervention
- Check for processes that might be holding resources
- Use `systemctl status` to check service states

### Permission Errors
- Ensure the playbook is running with `become: yes`
- Check that the user has sudo privileges
- Verify file permissions on directories being removed

### Incomplete Cleanup
- Some files may be protected or in use
- Check for mount points or special filesystems
- Review the logs for any error messages

## Recovery

If you need to recover after a clean install:

1. **Restore from Backup**: Use your backup procedures to restore data
2. **Reconfigure**: Run the full playbook to reinstall and configure
3. **Verify**: Run health checks to ensure everything is working

## Example Workflow

```bash
# 1. Backup current system (your backup procedure)
./backup-powerdns.sh

# 2. Test clean install in check mode
ansible-playbook powerdns-playbook.yml --check --extra-vars "perform_clean_install=true"

# 3. Perform clean install
ansible-playbook powerdns-playbook.yml --extra-vars "perform_clean_install=true" --ask-vault-pass

# 4. Verify installation
ansible-playbook powerdns-playbook.yml --tags health --ask-vault-pass
```

## Files Created/Modified

- `roles/clean_install/tasks/main.yml` - Main clean install tasks
- `roles/clean_install/handlers/main.yml` - Clean install handlers
- `vars/main.yml` - Added clean install configuration variables
- `powerdns-playbook.yml` - Added clean_install role
- `examples/clean-install-example.yml` - Example configuration
- `README.md` - Updated with clean install documentation

---

**Remember**: Clean install is a destructive operation. Always backup your data and test in a non-production environment first!
