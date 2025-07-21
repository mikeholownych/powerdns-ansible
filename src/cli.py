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
    parser.add_argument("command", choices=["run"], help="Command to execute")
    parser.add_argument("--root", default=".", help="Root directory to scan")
    parser.add_argument("--config", default="config/config.yml", help="Config file")
    args = parser.parse_args()

    logger = get_logger("CLI")
    config = load_config(args.config)

    if args.command == "run":
        agent = AuditAgent(args.root, config)
        report_path = agent.run()
        logger.info("Audit complete", extra={"report": report_path})


if __name__ == "__main__":
    main()
