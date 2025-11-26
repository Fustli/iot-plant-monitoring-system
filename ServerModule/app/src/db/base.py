from enum import Enum as PyEnum
from sqlalchemy.ext.declarative import declarative_base

Base = declarative_base()

class AlertSeverityEnum(PyEnum):
    INFO = "info"
    WARNING = "warning"
    CRITICAL = "critical"


class AlertStatusEnum(PyEnum):
    ACTIVE = "active"
    ACKNOWLEDGED = "acknowledged"
    RESOLVED = "resolved"
