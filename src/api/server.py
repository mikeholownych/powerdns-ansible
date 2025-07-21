import os

from fastapi import Depends, FastAPI, HTTPException, Header
from fastapi.responses import FileResponse
import yaml

from agent.audit_agent import AuditAgent
from utils.logger import get_logger

app = FastAPI(title="AuditAgent API")
logger = get_logger("api")


def get_api_key(x_api_key: str = Header(...)) -> str:
    expected = os.environ.get("AGENT_API_KEY")
    if not expected or x_api_key != expected:
        raise HTTPException(status_code=401, detail="Unauthorized")
    return x_api_key


def load_config() -> dict:
    with open("config/config.yml", "r", encoding="utf-8") as f:
        return yaml.safe_load(f)


@app.post("/audit", dependencies=[Depends(get_api_key)])
def run_audit(root: str = "."):
    config = load_config()
    agent = AuditAgent(root, config)
    report = agent.run()
    return {"report": report}


@app.get("/report", dependencies=[Depends(get_api_key)])
def get_report():
    path = os.path.join(os.getcwd(), "validation_report.md")
    if not os.path.isfile(path):
        raise HTTPException(status_code=404, detail="Report not found")
    return FileResponse(path)
