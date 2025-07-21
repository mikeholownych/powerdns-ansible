import argparse
import os
import yaml

from agent.audit_agent import AuditAgent
from utils.logger import get_logger


def load_config(path: str) -> dict:
    with open(path, "r", encoding="utf-8") as f:
        return yaml.safe_load(f)


def main() -> None:
    parser = argparse.ArgumentParser(description="Audit Ansible Collection")
    parser.add_argument("command", choices=["run", "serve"], help="Command to execute")
    parser.add_argument("--root", default=".", help="Root directory to scan")
    parser.add_argument("--config", default="config/config.yml", help="Config file")
    parser.add_argument("--host", default="0.0.0.0", help="API host")
    parser.add_argument("--port", type=int, default=8000, help="API port")
    parser.add_argument(
        "--report", default=None, help="Path to output validation report"
    )
    args = parser.parse_args()

    logger = get_logger("CLI")
    config = load_config(args.config)

    if args.command == "run":
        root = os.path.abspath(os.path.expanduser(args.root))
        if not os.path.isdir(root):
            logger.error("Root path not found", extra={"root": root})
            raise SystemExit(1)
        agent = AuditAgent(root, config)
        report = args.report
        if report:
            report = os.path.abspath(os.path.expanduser(report))
        report_path = agent.run(report)
        logger.info("Audit complete", extra={"report": report_path})
    elif args.command == "serve":
        import uvicorn

        logger.info("Starting API server", extra={"host": args.host, "port": args.port})
        uvicorn.run("api.server:app", host=args.host, port=args.port)


if __name__ == "__main__":
    main()
