import sys
from pathlib import Path

import yaml

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "src"))
from agent.audit_agent import AuditAgent


def create_role(tmpdir: Path):
    role_path = tmpdir / "roles" / "sample"
    (role_path / "tasks").mkdir(parents=True)
    (role_path / "defaults").mkdir()
    with open(role_path / "tasks" / "main.yml", "w") as f:
        f.write("- name: Test\n  debug:\n    msg: '{{ message }}'\n")
    with open(role_path / "defaults" / "main.yml", "w") as f:
        yaml.safe_dump({"message": "hello"}, f)
    return tmpdir


def test_agent_generates_report(tmp_path):
    tmpdir = create_role(tmp_path)
    config = yaml.safe_load(Path("config/config.yml").read_text())
    agent = AuditAgent(str(tmpdir), config)
    report_file = tmpdir / "out.md"
    report = agent.run(str(report_file))
    assert Path(report).is_file()
    content = Path(report).read_text()
    assert "roles/sample" in content


def test_agent_lists_playbooks(tmp_path):
    tmpdir = create_role(tmp_path)
    playbook_dir = tmpdir / "playbooks"
    playbook_dir.mkdir()
    playbook = playbook_dir / "test_playbook.yml"
    playbook.write_text(
        """
- hosts: all
  roles:
    - sample
"""
    )
    config = yaml.safe_load(Path("config/config.yml").read_text())
    agent = AuditAgent(str(tmpdir), config)
    report_file = tmpdir / "out.md"
    report = agent.run(str(report_file))
    assert Path(report).is_file()
    content = Path(report).read_text()
    assert "playbooks/test_playbook.yml" in content
