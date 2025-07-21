import os
from pathlib import Path

import yaml
from fastapi.testclient import TestClient

import api.server as server


def setup_module(module):
    os.environ["AGENT_API_KEY"] = "test"


def setup_function(function):
    if server.rate_limiter:
        server.rate_limiter.tokens = server.rate_limiter.max_tokens


def test_audit_endpoint(tmp_path):
    role = tmp_path / "roles" / "demo"
    (role / "tasks").mkdir(parents=True)
    (role / "defaults").mkdir()
    (role / "tasks" / "main.yml").write_text(
        "- name: t\n  debug:\n    msg: '{{ msg }}'\n"
    )
    (role / "defaults" / "main.yml").write_text(yaml.safe_dump({"msg": "hi"}))

    with TestClient(server.app) as client:
        resp = client.post(
            "/audit", params={"root": str(tmp_path)}, headers={"x-api-key": "test"}
        )
        assert resp.status_code == 200
        report_path = Path(resp.json()["report"])
        assert report_path.exists()


def test_rate_limit(tmp_path):
    role = tmp_path / "roles" / "demo"
    (role / "tasks").mkdir(parents=True)
    (role / "defaults").mkdir()
    (role / "tasks" / "main.yml").write_text(
        "- name: t\n  debug:\n    msg: '{{ msg }}'\n"
    )
    (role / "defaults" / "main.yml").write_text(yaml.safe_dump({"msg": "hi"}))

    with TestClient(server.app) as client:
        for _ in range(5):
            r = client.post(
                "/audit", params={"root": str(tmp_path)}, headers={"x-api-key": "test"}
            )
            assert r.status_code == 200
        r = client.post(
            "/audit", params={"root": str(tmp_path)}, headers={"x-api-key": "test"}
        )
        assert r.status_code == 429

