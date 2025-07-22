#!/bin/bash
# Auto-generate missing role structure
for role in powerdns mysql security monitoring haproxy keepalived recursor prometheus galera dnsdist zones_as_code dnssec_automation validate_config clean_install security_hardening state_management self_healing; do
  mkdir -p "roles/$role"/{defaults,vars,handlers,templates,files,meta}
  
  # Create basic meta/main.yml
  cat > "roles/$role/meta/main.yml" << EOF
---
galaxy_info:
  role_name: $role
  author: PowerDNS Operations Team  
  description: $role configuration for PowerDNS infrastructure
  min_ansible_version: 2.15
  platforms:
    - name: Ubuntu
      versions: [20.04, 22.04]
    - name: Debian
      versions: [10, 11, 12]
    - name: EL
      versions: [8, 9]
dependencies: []
EOF

  # Create basic defaults/main.yml
  cat > "roles/$role/defaults/main.yml" << EOF
---
# Default variables for $role role
${role}_enabled: true
EOF

  # Create basic handlers/main.yml  
  cat > "roles/$role/handlers/main.yml" << EOF
---
# Handlers for $role role
- name: restart $role
  systemd:
    name: $role
    state: restarted
    enabled: true
  listen: "restart $role"
EOF

done
