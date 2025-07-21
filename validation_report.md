## ✅ Valid Items
- roles/clean_install
- roles/common
- roles/dnsdist
- roles/dnssec_automation
- roles/haproxy
- roles/keepalived
- roles/monitoring
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

## ⚠️ Placeholders Detected
- None

## 🛠 Fix Recommendations
- Review tasks/handlers in roles/galera for missing tags or handlers

## 📊 Score
97/100

## 🔜 Next Actions
- Address missing directories and meta files
- Ensure each task has name and tags
- Define any undefined variables in defaults or vars
