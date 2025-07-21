import os
import asyncio

from fastapi import Depends, FastAPI, HTTPException, Header
from fastapi.responses import FileResponse
import yaml

from agent.audit_agent import AuditAgent
from utils.logger import get_logger
from utils.rate_limiter import TokenBucket

app = FastAPI(title="AuditAgent API")
logger = get_logger("api")
config: dict | None = None
rate_limiter: TokenBucket | None = None


def get_api_key(x_api_key: str = Header(...)) -> str:
    expected = os.environ.get("AGENT_API_KEY")
    if not expected or x_api_key != expected:
        raise HTTPException(status_code=401, detail="Unauthorized")
    return x_api_key


def check_rate_limit() -> None:
    if rate_limiter and not rate_limiter.consume():
        raise HTTPException(status_code=429, detail="Too Many Requests")


def load_config() -> dict:
    with open("config/config.yml", "r", encoding="utf-8") as f:
        return yaml.safe_load(f)


@app.on_event("startup")
def startup() -> None:
    global config, rate_limiter
    config = load_config()
    rl_conf = config.get("rate_limit", {})
    rate_limiter = TokenBucket(rl_conf.get("max_calls", 5), rl_conf.get("period", 60))


@app.post("/audit", dependencies=[Depends(get_api_key), Depends(check_rate_limit)])
async def run_audit(root: str = "."):
    agent = AuditAgent(root, config)
    report = await asyncio.to_thread(agent.run)
    return {"report": report}


@app.get("/report", dependencies=[Depends(get_api_key), Depends(check_rate_limit)])
async def get_report() -> FileResponse:
    path = os.path.join(os.getcwd(), "validation_report.md")
    if not os.path.isfile(path):
        raise HTTPException(status_code=404, detail="Report not found")
    return FileResponse(path)
