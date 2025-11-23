"""Logging configuration for the gateway package."""
import logging
import os


def configure_logging(level_env: str = "LOG_LEVEL"):
    level_name = os.getenv(level_env, "INFO").upper()
    level = getattr(logging, level_name, logging.INFO)

    root = logging.getLogger()
    # Avoid adding multiple handlers in case configure_logging is called twice
    if not root.handlers:
        handler = logging.StreamHandler()
        fmt = "%(asctime)s %(levelname)-5s [%(name)s] %(message)s"
        handler.setFormatter(logging.Formatter(fmt))
        root.addHandler(handler)

    root.setLevel(level)


def get_logger(name: str = "gateway"):
    configure_logging()
    return logging.getLogger(name)
