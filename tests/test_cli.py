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


def test_cli_run_custom_report(tmp_path, monkeypatch):
    tmpdir = create_role(tmp_path)
    report = tmpdir / "custom.md"
    config = Path("config/config.yml")
    monkeypatch.setattr(
        sys,
        "argv",
        [
            "cli.py",
            "run",
            "--root",
            str(tmpdir),
            "--config",
            str(config),
            "--report",
            str(report),
        ],
    )
    cli.main()
    assert report.is_file()


def test_cli_serve(monkeypatch):
    monkeypatch.setattr(
        sys,
        "argv",
        ["cli.py", "serve", "--host", "127.0.0.1", "--port", "9999"],
    )
    called = {}

    def fake_run(app, host="", port=0):
        called["host"] = host
        called["port"] = port

    monkeypatch.setattr("uvicorn.run", fake_run)
    cli.main()
    assert called == {"host": "127.0.0.1", "port": 9999}
