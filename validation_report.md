## ✅ Valid Items
- roles/clean_install
- roles/common
- roles/dnsdist
- roles/dnssec_automation
- roles/haproxy
- roles/mysql
- roles/powerdns
- roles/prometheus
- roles/recursor
- roles/security
- roles/security_hardening
- roles/self_healing
- roles/selfheal
- roles/state_management
- roles/validate_config
- roles/zones_as_code

## ❌ Missing or Broken
- galera: /workspace/powerdns-ansible/roles/galera/tasks/main.yml notifies undefined handler 'restart galera-health-check'
- galera: /workspace/powerdns-ansible/roles/galera/tasks/main.yml notifies undefined handler 'restart mysql'
- galera: /workspace/powerdns-ansible/roles/galera/tasks/main.yml notifies undefined handler 'start galera-health-check-timer'
- monitoring: /workspace/powerdns-ansible/roles/monitoring/tasks/install_prometheus.yml notifies undefined handler 'reload systemd'
- monitoring: /workspace/powerdns-ansible/roles/monitoring/tasks/install_prometheus.yml notifies undefined handler 'restart node_exporter'
- keepalived: /workspace/powerdns-ansible/roles/keepalived/tasks/main.yml notifies undefined handler 'reload firewall'
- keepalived: /workspace/powerdns-ansible/roles/keepalived/tasks/main.yml notifies undefined handler 'reload systemd'
- keepalived: /workspace/powerdns-ansible/roles/keepalived/tasks/main.yml notifies undefined handler 'restart keepalived'
- keepalived: /workspace/powerdns-ansible/roles/keepalived/tasks/main.yml notifies undefined handler 'restart keepalived-check'
- keepalived: /workspace/powerdns-ansible/roles/keepalived/tasks/main.yml notifies undefined handler 'start keepalived-check-timer'

## ⚠️ Placeholders Detected
- None

## 🛠 Fix Recommendations
- Address `ansible-lint` failures (1458 detected, reduced from 1602)
- Continue replacing `ignore_errors` with explicit failure checks across roles

## 📊 Score
90/100

## 🔜 Next Actions
- Address missing directories and meta files
- Ensure each task has name and tags
- Define any undefined variables in defaults or vars
