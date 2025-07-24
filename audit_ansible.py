"""Ansible collection audit helper.

This script scans roles and playbooks from the repository root and
generates a concise validation report in Markdown format.  It checks
for required role subdirectories, placeholder content, undefined
variables, and basic task metadata such as ``name`` and ``tags``.

The resulting report is written to ``validation_report.md`` in the
repository root.
"""

import os
import re
import glob
from collections import defaultdict
from typing import Dict, Iterable, List, Set

import yaml

ROOT_DIR = os.path.dirname(os.path.abspath(__file__))

ROLE_SUBDIRS = [
    "tasks",
    "defaults",
    "vars",
    "handlers",
    "templates",
    "files",
    "meta",
]

# Detect common placeholders or empty files.
PLACEHOLDER_RE = re.compile(r"TODO|REPLACE_ME", re.IGNORECASE)
# Capture Jinja variable usage.
VAR_RE = re.compile(r"{{\s*([^\s{}]+)\s*}}")


def find_roles(root: str) -> List[str]:
    """Return a list of role directories."""

    roles_path = os.path.join(root, "roles")
    return [
        os.path.join(roles_path, name)
        for name in os.listdir(roles_path)
        if os.path.isdir(os.path.join(roles_path, name))
    ] if os.path.isdir(roles_path) else []


def find_playbooks(root: str) -> List[str]:
    """Return a deduplicated list of playbook files relative to the root."""

    playbooks: set[str] = set()
    for dir_name in [".", "playbooks"]:
        path = os.path.join(root, dir_name)
        if not os.path.isdir(path):
            continue
        for fname in os.listdir(path):
            full = os.path.join(path, fname)
            if not fname.endswith((".yml", ".yaml")) or not os.path.isfile(full):
                continue
            if dir_name == "playbooks" or "playbook" in fname:
                playbooks.add(os.path.relpath(full, root))
    return sorted(playbooks)


def load_yaml(path: str):
    """Load YAML data, returning ``None`` on failure."""

    try:
        with open(path) as f:
            return yaml.safe_load(f) or {}
    except Exception:
        return None


def _extract_vars_from_string(content: str) -> Iterable[str]:
    """Yield Jinja variable names found in ``content``.

    Only the base variable name before any filters or attribute access
    is returned so ``foo.bar | default('x')`` becomes ``foo``.
    """

    for raw in VAR_RE.findall(content):
        var = raw.split("|")[0].strip()
        var = re.split(r"[.\[]", var)[0]
        if var:
            yield var


def collect_vars(role_path: str) -> Set[str]:
    """Collect all Jinja variables referenced in a role."""

    found: Set[str] = set()
    for sub in ["tasks", "handlers", "templates"]:
        sub_path = os.path.join(role_path, sub)
        if not os.path.isdir(sub_path):
            continue
        for root_dir, _, files in os.walk(sub_path):
            for fname in files:
                if fname.endswith((".yml", ".yaml", ".j2")):
                    with open(os.path.join(root_dir, fname)) as f:
                        found.update(_extract_vars_from_string(f.read()))
    return found


def check_role(role_path: str, defined_vars: Set[str]) -> Dict[str, List[str]]:
    """Inspect a single role and return findings."""

    findings: Dict[str, Set[str]] = defaultdict(set)

    # Missing standard directories and meta file
    for sub in ROLE_SUBDIRS:
        if not os.path.isdir(os.path.join(role_path, sub)):
            findings["missing"].add(f"{sub} directory")
    if not os.path.isfile(os.path.join(role_path, "meta", "main.yml")):
        findings["missing"].add("meta/main.yml")

    # Collect handler names
    handlers: Set[str] = set()
    for hfile in glob.glob(os.path.join(role_path, "handlers", "*.yml")):
        data = load_yaml(hfile)
        if isinstance(data, list):
            for task in data:
                if isinstance(task, dict) and task.get("name"):
                    handlers.add(task["name"])

    # Validate tasks recursively and gather variables
    used_vars = collect_vars(role_path)
    missing_tags: Dict[str, List[str]] = defaultdict(list)
    for root_dir, _, files in os.walk(os.path.join(role_path, "tasks")):
        for fname in files:
            if not fname.endswith(".yml"):
                continue
            tfile = os.path.join(root_dir, fname)
            data = load_yaml(tfile)
            if not isinstance(data, list):
                findings["broken"].add(f"Invalid YAML: {tfile}")
                continue
            for task in data:
                if not isinstance(task, dict):
                    continue
                if not task.get("name"):
                    findings["broken"].add(f"{tfile} - missing task name")
                if "tags" not in task:
                    missing_tags[tfile].append(task.get("name", "unnamed"))
                if "notify" in task:
                    targets = task["notify"]
                    if not isinstance(targets, list):
                        targets = [targets]
                    for trg in targets:
                        if trg not in handlers:
                            findings["broken"].add(
                                f"{tfile} notifies undefined handler '{trg}'"
                            )
    for tfile, tasks in missing_tags.items():
        findings["broken"].add(
            f"{tfile} missing tags for: {', '.join(tasks)}"
        )

    # Detect placeholder content
    for root_dir, _, files in os.walk(role_path):
        for fname in files:
            fpath = os.path.join(root_dir, fname)
            with open(fpath, errors="ignore") as fh:
                text = fh.read()
                if PLACEHOLDER_RE.search(text) or not text.strip():
                    findings["placeholders"].add(fpath)

    # Undefined variables
    undefined = used_vars - defined_vars
    ignored_prefixes = ("ansible_",)
    ignored_vars = {
        "item",
        "inventory_hostname",
        "inventory_hostname_short",
        "groups",
        "hostvars",
        "group_names",
        "loop",
        "geo_rule",
        "rule",
    }
    filtered = {
        var
        for var in undefined
        if not var.startswith(ignored_prefixes) and var not in ignored_vars
    }
    if filtered:
        findings["undefined_vars"].update(sorted(filtered))

    return {k: sorted(v) for k, v in findings.items()}


def _gather_keys(obj) -> Set[str]:
    keys: Set[str] = set()
    if isinstance(obj, dict):
        for k, v in obj.items():
            keys.add(k)
            keys.update(_gather_keys(v))
    elif isinstance(obj, list):
        for item in obj:
            keys.update(_gather_keys(item))
    return keys


def load_all_defined_vars() -> Set[str]:
    """Return a set of all defined variable names."""

    defined: Set[str] = set()
    # Root-level vars, inventory and group/host vars
    var_files = glob.glob(os.path.join(ROOT_DIR, "vars", "*.yml"))
    var_files += glob.glob(os.path.join(ROOT_DIR, "inventory", "*.yml"))
    var_files += glob.glob(os.path.join(ROOT_DIR, "group_vars", "**", "*.yml"), recursive=True)
    var_files += glob.glob(os.path.join(ROOT_DIR, "host_vars", "**", "*.yml"), recursive=True)
    for path in var_files:
        data = load_yaml(path)
        if isinstance(data, dict):
            defined.update(_gather_keys(data))

    # Role defaults/vars
    for role in find_roles(ROOT_DIR):
        role_vars = glob.glob(os.path.join(role, "defaults", "*.yml"))
        role_vars += glob.glob(os.path.join(role, "vars", "*.yml"))
        for path in role_vars:
            data = load_yaml(path)
            if isinstance(data, dict):
                defined.update(_gather_keys(data))

    return defined


def main() -> None:
    """Run the audit and write ``validation_report.md``."""

    defined_vars = load_all_defined_vars()
    report: Dict[str, Dict[str, List[str]]] = {}
    valid_roles: List[str] = []
    playbooks: List[str] = find_playbooks(ROOT_DIR)

    for role in find_roles(ROOT_DIR):
        role_name = os.path.basename(role)
        findings = check_role(role, defined_vars)
        if any(findings.values()):
            report[role_name] = findings
        else:
            valid_roles.append(role_name)

    lines: List[str] = []
    lines.append("## ✅ Valid Items")
    if valid_roles:
        for r in sorted(valid_roles):
            lines.append(f"- roles/{r}")
    if playbooks:
        for p in playbooks:
            lines.append(f"- {p}")
    if not valid_roles and not playbooks:
        lines.append("- None")

    lines.append("\n## ❌ Missing or Broken")
    if report:
        for role, info in report.items():
            for category in ("missing", "broken", "undefined_vars"):
                for item in info.get(category, []):
                    lines.append(f"- {role}: {item}")
    else:
        lines.append("- None")

    lines.append("\n## ⚠️ Placeholders Detected")
    placeholders = [
        f"- {role}: {path}"
        for role, info in report.items()
        for path in info.get("placeholders", [])
    ]
    lines.extend(placeholders or ["- None"])

    lines.append("\n## 🛠 Fix Recommendations")
    if report:
        for role, info in report.items():
            if info.get("missing"):
                lines.append(
                    f"- Add {', '.join(info['missing'])} to roles/{role}"
                )
            if info.get("broken"):
                lines.append(
                    f"- Review tasks/handlers in roles/{role} for missing tags or handlers"
                )
            if info.get("undefined_vars"):
                lines.append(
                    f"- Define variables {', '.join(info['undefined_vars'])}"
                )
    else:
        lines.append("- No issues found")

    # Simple scoring: start from 100 and subtract one point per issue
    issue_count = sum(
        len(items) for info in report.values() for items in info.values()
    )
    score = max(0, 100 - issue_count)

    lines.append("\n## 📊 Score")
    lines.append(f"{score}/100")

    lines.append("\n## 🔜 Next Actions")
    if report:
        lines.append("- Address missing directories and meta files")
        lines.append("- Ensure each task has name and tags")
        lines.append("- Define any undefined variables in defaults or vars")
    else:
        lines.append("- Collection structure looks good")

    with open(os.path.join(ROOT_DIR, "validation_report.md"), "w") as fh:
        fh.write("\n".join(lines) + "\n")

    print("Validation report written to validation_report.md")

if __name__ == "__main__":
    main()
