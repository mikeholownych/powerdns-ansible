## ✅ Valid Items
- roles/clean_install
- roles/powerdns
- roles/mysql
- playbooks/powerdns-playbook.yml

## ❌ Missing or Broken
- ansible-doc output empty for installed roles
- molecule default scenario schema invalid
- molecule security scenario requires Docker daemon
- workflow YAML files fail yamllint line-length checks

## ⚠️ Placeholders Detected
- none

## 🛠 Fix Recommendations
- add role docstrings or README metadata so `ansible-doc` renders
- update `molecule/default/molecule.yml` to a valid schema
- ensure Docker is available or switch to delegated driver for molecule
- shorten workflow YAML lines under 81 characters
