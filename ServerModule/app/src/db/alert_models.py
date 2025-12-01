from sqlalchemy import (
    Column, Integer, String, Float, DateTime, Boolean, ForeignKey,
    Enum, Text, Index
)
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from src.db.base import Base, AlertSeverityEnum, AlertStatusEnum


class Alert(Base):
    __tablename__ = 'alerts'

    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey('users.id', ondelete='CASCADE'), nullable=False)
    plant_id = Column(Integer, ForeignKey('plants.id', ondelete='CASCADE'), nullable=False)
    severity = Column(Enum(AlertSeverityEnum), nullable=False)
    status = Column(Enum(AlertStatusEnum), default=AlertStatusEnum.ACTIVE, nullable=False, index=True)
    message = Column(Text, nullable=False)
    triggered_metric = Column(Text)
    threshold_value = Column(Float)
    triggered_at = Column(DateTime(timezone=True), nullable=False, index=True)
    acknowledged_at = Column(DateTime(timezone=True))
    resolved_at = Column(DateTime(timezone=True))
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), 
                       onupdate=func.now(), nullable=False)

    user = relationship('User', back_populates='alerts')
    plant = relationship('Plant', back_populates='alerts')

    __table_args__ = (
        Index('idx_alert_user', 'user_id'),
        Index('idx_alert_plant', 'plant_id'),
        Index('idx_alert_status', 'status'),
        Index('idx_alert_triggered_at', 'triggered_at'),
    )

    def __repr__(self):
        return f'<Alert severity={self.severity} status={self.status}>'
