from __future__ import annotations

import os
import re
from typing import Dict, List

import yaml

from utils.logger import get_logger


class AuditAgent:
    """Audit Ansible roles and generate a validation report."""

    VARIABLE_PATTERN = re.compile(r"{{\s*([^\s{}|]+)\s*}}")

    def __init__(self, root_dir: str, config: Dict[str, any]):
        self.root_dir = os.path.abspath(root_dir)
        if not os.path.isdir(self.root_dir):
            raise ValueError(f"Root path not found: {self.root_dir}")
        self.config = config
        self.logger = get_logger(self.__class__.__name__)
        self.required_dirs = config["audit"]["required_role_dirs"]
        self.placeholders = config["audit"].get("placeholder_keywords", [])
        self.report_lines: List[str] = []

    def run(self, report_path: str | None = None) -> str:
        self.logger.info("Starting audit", extra={"root": self.root_dir})
        if report_path is None:
            report_path = os.path.join(self.root_dir, "validation_report.md")
        valid_items: List[str] = []
        missing_items: List[str] = []
        placeholders: List[str] = []
        suggestions: List[str] = []

        roles_dir = os.path.join(self.root_dir, "roles")
        if not os.path.isdir(roles_dir):
            self.logger.error("Roles directory missing", extra={"path": roles_dir})
            self.report_lines.append("## ❌ Missing or Broken")
            self.report_lines.append(f"- {roles_dir} — Missing directory")
            report = "\n".join(self.report_lines)
            with open(report_path, "w", encoding="utf-8") as f:
                f.write(report)
            return report_path

        for role in sorted(os.listdir(roles_dir)):
            role_path = os.path.join(roles_dir, role)
            if not os.path.isdir(role_path):
                continue
            missing = self._check_role_structure(role_path)
            if missing:
                missing_items.extend(missing)
            self._check_placeholders(role_path, placeholders)
            self._check_variables(role_path, missing_items, suggestions)
            valid_items.append(f"roles/{role}")

        self._write_section("## ✅ Valid Items", valid_items)
        self._write_section("## ❌ Missing or Broken", missing_items)
        self._write_section("## ⚠️ Placeholders Detected", placeholders)
        self._write_section("## 🛠 Fix Recommendations", suggestions)

        report = "\n".join(self.report_lines)
        with open(report_path, "w", encoding="utf-8") as f:
            f.write(report)
        self.logger.info("Report written", extra={"path": report_path})
        return report_path

    def _write_section(self, header: str, items: List[str]) -> None:
        self.report_lines.append(header)
        if items:
            for item in items:
                self.report_lines.append(f"- {item}")
        else:
            self.report_lines.append("- none")
        self.report_lines.append("")

    def _check_role_structure(self, role_path: str) -> List[str]:
        missing: List[str] = []
        for directory in self.required_dirs:
            dir_path = os.path.join(role_path, directory)
            if not os.path.isdir(dir_path):
                missing.append(f"{role_path}/{directory} — Missing directory")
        meta_main = os.path.join(role_path, "meta", "main.yml")
        if not os.path.isfile(meta_main):
            missing.append(f"{meta_main} — Missing file")
        else:
            try:
                with open(meta_main, "r", encoding="utf-8") as f:
                    yaml.safe_load(f)
            except yaml.YAMLError as exc:
                missing.append(f"{meta_main} — Invalid YAML: {exc}")
        self._validate_yaml_files(role_path, missing)
        return missing

    def _check_placeholders(self, role_path: str, results: List[str]) -> None:
        for root, _, files in os.walk(role_path):
            for fname in files:
                if not fname.endswith((".yml", ".yaml", ".j2", ".txt", ".md")):
                    continue
                fpath = os.path.join(root, fname)
                try:
                    with open(fpath, "r", encoding="utf-8") as f:
                        content = f.read()
                    for keyword in self.placeholders:
                        if keyword in content:
                            results.append(f"{fpath} contains '{keyword}'")
                except (OSError, UnicodeDecodeError) as exc:
                    self.logger.warning(
                        "Failed to read file", extra={"file": fpath, "error": str(exc)}
                    )

    def _check_variables(
        self, role_path: str, missing: List[str], suggestions: List[str]
    ) -> None:
        variables = self._load_defined_variables(role_path)
        used_vars = set()
        for root, _, files in os.walk(os.path.join(role_path, "tasks")):
            for fname in files:
                if fname.endswith((".yml", ".yaml")):
                    fpath = os.path.join(root, fname)
                    used_vars.update(self._extract_vars(fpath))
        undefined = used_vars - set(variables.keys())
        for var in sorted(undefined):
            missing.append(f"{role_path}: undefined variable '{var}'")
            suggestions.append(f"Define '{var}' in defaults/main.yml or vars/main.yml")

    def _extract_vars(self, path: str) -> List[str]:
        try:
            with open(path, "r", encoding="utf-8") as f:
                content = f.read()
        except OSError as exc:
            self.logger.warning(
                "Failed to read", extra={"file": path, "error": str(exc)}
            )
            return []
        return self.VARIABLE_PATTERN.findall(content)

    def _load_defined_variables(self, role_path: str) -> Dict[str, any]:
        vars_files = [
            os.path.join(role_path, "defaults", "main.yml"),
            os.path.join(role_path, "vars", "main.yml"),
        ]
        variables: Dict[str, any] = {}
        for vf in vars_files:
            if os.path.isfile(vf):
                try:
                    with open(vf, "r", encoding="utf-8") as f:
                        variables.update(yaml.safe_load(f) or {})
                except yaml.YAMLError as exc:
                    self.logger.warning(
                        "Invalid YAML", extra={"file": vf, "error": str(exc)}
                    )
        return variables

    def _validate_yaml_files(self, role_path: str, errors: List[str]) -> None:
        for root, _, files in os.walk(role_path):
            for fname in files:
                if fname.endswith((".yml", ".yaml")):
                    path = os.path.join(root, fname)
                    try:
                        with open(path, "r", encoding="utf-8") as f:
                            yaml.safe_load(f)
                    except (OSError, yaml.YAMLError) as exc:
                        errors.append(f"{path} — Invalid YAML: {exc}")
