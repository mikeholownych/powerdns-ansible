import sys
from pathlib import Path

import src.cli as cli
from tests.test_agent import create_role


def test_cli_run(tmp_path, monkeypatch):
    tmpdir = create_role(tmp_path)
    config = Path("config/config.yml")
    monkeypatch.setattr(
        sys,
        "argv",
        ["cli.py", "run", "--root", str(tmpdir), "--config", str(config)],
    )
    cli.main()
    assert (tmpdir / "validation_report.md").is_file()
