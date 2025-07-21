import os
import yaml
import re
from collections import defaultdict

ROOT_DIR = os.path.dirname(os.path.abspath(__file__))

ROLE_SUBDIRS = ["tasks", "defaults", "vars", "handlers", "templates", "files", "meta"]
PLACEHOLDER_RE = re.compile(r"TODO|REPLACE_ME", re.IGNORECASE)
VAR_RE = re.compile(r"{{\s*([^\s{}]+)\s*}}")


def find_roles(root):
    roles_path = os.path.join(root, "roles")
    roles = []
    if os.path.isdir(roles_path):
        for name in os.listdir(roles_path):
            path = os.path.join(roles_path, name)
            if os.path.isdir(path):
                roles.append(path)
    return roles


def load_yaml(path):
    try:
        with open(path) as f:
            return yaml.safe_load(f) or {}
    except Exception:
        return None


def collect_vars(role_path):
    vars_found = defaultdict(set)
    for sub in ["tasks", "handlers", "templates"]:
        sub_path = os.path.join(role_path, sub)
        if not os.path.isdir(sub_path):
            continue
        for root, _, files in os.walk(sub_path):
            for fname in files:
                if fname.endswith(('.yml', '.yaml', '.j2')):
                    fpath = os.path.join(root, fname)
                    with open(fpath) as f:
                        content = f.read()
                        for var in VAR_RE.findall(content):
                            vars_found[sub].add(var.split('|')[0])
    return vars_found


def check_role(role_path):
    missing = []
    placeholders = []
    vars_used = collect_vars(role_path)
    for sub in ROLE_SUBDIRS:
        sub_path = os.path.join(role_path, sub)
        if not os.path.isdir(sub_path):
            missing.append(f"{sub} directory")
        else:
            # check placeholder files
            for root, _, files in os.walk(sub_path):
                for fname in files:
                    fpath = os.path.join(root, fname)
                    with open(fpath) as f:
                        text = f.read()
                        if PLACEHOLDER_RE.search(text) or not text.strip():
                            placeholders.append(fpath)
    return missing, placeholders, vars_used


def load_all_defined_vars():
    defined = set()
    for varfile in ["vars/main.yml", "vars/operational.yml"]:
        path = os.path.join(ROOT_DIR, varfile)
        data = load_yaml(path)
        if isinstance(data, dict):
            defined.update(data.keys())
    # group_vars or defaults not present
    return defined


def main():
    report = {"valid": [], "missing": [], "placeholders": [], "undefined_vars": []}
    defined_vars = load_all_defined_vars()
    for role in find_roles(ROOT_DIR):
        missing, placeholders, vars_used = check_role(role)
        role_name = os.path.basename(role)
        if missing:
            report["missing"].append({role_name: missing})
        else:
            report["valid"].append(role_name)
        if placeholders:
            report["placeholders"].extend(placeholders)
        # check vars
        used = set().union(*vars_used.values())
        undefined = used - defined_vars
        if undefined:
            report["undefined_vars"].append({role_name: sorted(undefined)})
    print(yaml.dump(report, default_flow_style=False))

if __name__ == "__main__":
    main()
