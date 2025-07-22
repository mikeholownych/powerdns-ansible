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
    """Return a logger with JSON formatter and file handler."""
    logger = logging.getLogger(name)
    if logger.handlers:
        return logger

    formatter = JsonFormatter()

    stream_handler = logging.StreamHandler(sys.stdout)
    stream_handler.setFormatter(formatter)
    logger.addHandler(stream_handler)

    log_dir = os.environ.get("LOG_DIR", "logs")
    os.makedirs(log_dir, exist_ok=True)
    file_handler = logging.FileHandler(os.path.join(log_dir, f"{name}.log"))
    file_handler.setFormatter(formatter)
    logger.addHandler(file_handler)

    level = os.environ.get("LOG_LEVEL", "INFO")
    logger.setLevel(level)
    return logger
