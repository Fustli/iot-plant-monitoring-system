from datetime import datetime
from enum import IntEnum


class LogLevel(IntEnum):
    DEBUG = 10
    INFO = 20
    WARNING = 30
    ERROR = 40


class Logger:
    def __init__(self, name: str, level: LogLevel = LogLevel.INFO):
        self.name = name
        self.level = level

    def _should_log(self, level: LogLevel) -> bool:
        return level >= self.level

    def _format(self, level: LogLevel, message: str) -> str:
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        level_name = level.name
        return f"[{timestamp}] [{self.name}] [{level_name}] {message}"

    def _write(self, formatted: str) -> None:
        # Console
        print(formatted)

    def log(self, level: LogLevel, message: str) -> None:
        if not self._should_log(level):
            return
        formatted = self._format(level, message)
        self._write(formatted)

    # Convenience helpers
    def debug(self, message: str) -> None:
        self.log(LogLevel.DEBUG, message)

    def info(self, message: str) -> None:
        self.log(LogLevel.INFO, message)

    def warning(self, message: str) -> None:
        self.log(LogLevel.WARNING, message)

    def error(self, message: str) -> None:
        self.log(LogLevel.ERROR, message)
