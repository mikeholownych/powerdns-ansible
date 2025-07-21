import json
import logging
import os
import sys


class JsonFormatter(logging.Formatter):
    """Format logs as JSON strings."""

    def format(self, record: logging.LogRecord) -> str:
        log_record = {
            "level": record.levelname,
            "name": record.name,
            "message": record.getMessage(),
            "time": self.formatTime(record, self.datefmt),
        }
        if record.exc_info:
            log_record["exc_info"] = self.formatException(record.exc_info)
        return json.dumps(log_record)


def get_logger(name: str) -> logging.Logger:
    """Return a logger with JSON formatter."""
    logger = logging.getLogger(name)
    if logger.handlers:
        return logger
    handler = logging.StreamHandler(sys.stdout)
    handler.setFormatter(JsonFormatter())
    logger.addHandler(handler)
    level = os.environ.get("LOG_LEVEL", "INFO")
    logger.setLevel(level)
    return logger
