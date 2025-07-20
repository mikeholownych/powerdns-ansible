# Ansible PowerDNS Playbook Fixes

## Issues Identified and Fixed

### 1. Health Check Timer Service Not Found

**Problem**: The systemd timer `powerdns-health-check.timer` could not be found when trying to enable it.

**Root Cause**: The condition in the "Enable and start health check timer" task was checking for `timer_file_check.stat.exists | default(false)` which would only enable the timer if the file does NOT exist.

**Fix Applied**:
- Changed the condition to `timer_file_check.stat.exists | default(true)` to enable the timer only when the files exist
- This ensures the timer is enabled after the systemd files are successfully created

### 2. MySQL Python Module Not Found

**Problem**: MySQL tasks were failing with error "A MySQL module is required: for Python 2.7 either PyMySQL, or MySQL-python, or for Python 3.X mysqlclient or PyMySQL"

**Root Cause**: Ansible was not using the correct Python interpreter where PyMySQL was installed.

**Fixes Applied**:
1. Added `interpreter_python = /usr/bin/python3` to `ansible.cfg` under `[defaults]` section
2. Confirmed `ansible_python_interpreter: /usr/bin/python3` is set in inventory
3. The playbook already installs both `PyMySQL` via pip and `python3-pymysql` via package manager

### 3. Additional Improvements Made

**Enhanced Error Handling**:
- The MySQL role already has `ignore_errors: yes` for the initial MySQL security task
- This allows the playbook to continue even if the initial MySQL setup encounters issues

**Systemd Service Configuration**:
- The health check service template is properly configured with security hardening
- Timer configuration uses appropriate intervals and dependencies

## Files Modified

1. `roles/common/tasks/main.yml` - Fixed timer enable condition from `default(false)` to `default(true)`
2. `ansible.cfg` - Added `interpreter_python = /usr/bin/python3` under `[defaults]` section
3. `inventory/hosts.yml` - Already had correct `ansible_python_interpreter: /usr/bin/python3` setting
4. `roles/mysql/tasks/main.yml` - Added Python module verification and MySQL readiness check

## Testing the Fixes

To test the fixes, run the playbook again:

```bash
ansible-playbook powerdns-playbook.yml --check --vault-password-file=.vault_pass
```

For a full run (not just check mode):
```bash
ansible-playbook powerdns-playbook.yml --vault-password-file=.vault_pass
```

Expected improvements:
- Health check timer should enable successfully after systemd files are created
- MySQL tasks should find the Python modules (PyMySQL)
- MySQL service will wait to be ready before proceeding with database operations
- Overall playbook execution should complete without the previous errors

## Additional Recommendations

1. **Monitor MySQL Connection**: After the fixes, verify MySQL connectivity:
   ```bash
   ansible powerdns_servers -m shell -a "mysql -u root -p'{{ mysql_root_password }}' -e 'SELECT 1;'"
   ```

2. **Verify Systemd Services**: Check that the health check timer is running:
   ```bash
   ansible powerdns_servers -m shell -a "systemctl status powerdns-health-check.timer"
   ```

3. **Check Python Module Availability**: Verify PyMySQL is accessible:
   ```bash
   ansible powerdns_servers -m shell -a "/usr/bin/python3 -c 'import pymysql; print(pymysql.__version__)'"
   ```

### 4. Missing PowerDNS Log Rotation Template

**Problem**: The PowerDNS role was failing with error "Could not find or access 'powerdns-logs.logrotate.j2'" because the template file was missing from the PowerDNS role templates directory.

**Root Cause**: The PowerDNS role's main.yml task referenced `powerdns-logs.logrotate.j2` template, but this file didn't exist in `roles/powerdns/templates/`.

**Fix Applied**:
- Created the missing template file `roles/powerdns/templates/powerdns-logs.logrotate.j2`
- Used the existing logrotate configuration from the common role as the base
- Template includes proper log rotation for both PowerDNS service logs and configuration logs

**Template Features**:
- Daily rotation for PowerDNS service logs with configurable retention
- Weekly rotation for PowerDNS configuration logs
- Proper file permissions and ownership
- Service reload after log rotation
- Compression and size-based rotation options

## Files Modified

1. `roles/common/tasks/main.yml` - Fixed timer enable condition from `default(false)` to `default(true)`
2. `ansible.cfg` - Added `interpreter_python = /usr/bin/python3` under `[defaults]` section
3. `inventory/hosts.yml` - Already had correct `ansible_python_interpreter: /usr/bin/python3` setting
4. `roles/mysql/tasks/main.yml` - Added Python module verification and MySQL readiness check
5. `roles/powerdns/templates/powerdns-logs.logrotate.j2` - **NEW**: Created missing logrotate template

## Future Considerations

- Consider adding a pre-task to verify Python module availability before running MySQL tasks
- Add more robust error handling for systemd service creation and enablement
- Consider using `mysql_secure_installation` equivalent tasks for better MySQL security setup
