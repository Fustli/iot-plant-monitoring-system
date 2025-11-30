"""
Hub Models for IoT Plant Monitoring System

Hubs are physical gateway devices that users register at locations (home, work, etc.)
to communicate between smart devices and the cloud.
"""

from sqlalchemy import (
    Column, Integer, String, DateTime, Boolean, ForeignKey, Text, Index
)
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from src.db.base import Base


class Hub(Base):
    """
    Hub represents a physical gateway device at a user's location.
    
    Each hub acts as a bridge between IoT devices (sensors/actuators) and the cloud.
    Users can have multiple hubs at different locations (home, office, etc.)
    """
    __tablename__ = 'hubs'

    id = Column(Integer, primary_key=True, autoincrement=True)
    # user_id can be NULL when an admin pre-provisions a hub (unclaimed)
    user_id = Column(Integer, ForeignKey('users.id', ondelete='CASCADE'), nullable=True, index=True)
    serial = Column(String(255), unique=True, nullable=False, index=True)
    # Optional Azure IoT Hub device id and connection string for hubs
    iothub_device_id = Column(String(255), nullable=True)
    iothub_connection_string = Column(Text, nullable=True)
    name = Column(String(255), nullable=True)
    last_seen = Column(DateTime(timezone=True))
    status = Column(String(50), default='unknown')
    # Hubs are pre-provisioned by admin and become active when the hub calls the
    # activation endpoint. Default to False to require explicit activation.
    is_active = Column(Boolean, default=False, nullable=False, index=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False)

    owner = relationship('User', back_populates='hubs')
    devices = relationship('Device', back_populates='hub')
    metrics = relationship('HubMetrics', back_populates='hub', cascade='all, delete-orphan')

    __table_args__ = (
        Index('idx_hub_user', 'user_id'),
        Index('idx_hub_serial', 'serial'),
        Index('idx_hub_is_active', 'is_active'),
    )

    def __repr__(self):
        return f'<Hub {self.serial}>'



class HubMetrics(Base):
    """
    Time-series metrics for hub performance monitoring.

    Stores periodic snapshots of hub health and performance metrics.
    """
    __tablename__ = 'hub_metrics'

    id = Column(Integer, primary_key=True, autoincrement=True)
    hub_id = Column(Integer, ForeignKey('hubs.id', ondelete='CASCADE'), nullable=False, index=True)

    # Timestamp of the metric snapshot
    timestamp = Column(DateTime(timezone=True), server_default=func.now(), nullable=False, index=True)

    # Connection metrics
    is_connected = Column(Boolean, default=False, nullable=False)
    latency_ms = Column(Integer)

    # Resource usage (percent)
    cpu_usage_percent = Column(Integer)
    memory_usage_percent = Column(Integer)
    disk_usage_percent = Column(Integer)

    # Network metrics
    bandwidth_in_kbps = Column(Integer)
    bandwidth_out_kbps = Column(Integer)
    packet_loss_percent = Column(Integer)

    # Device metrics
    connected_devices_count = Column(Integer, default=0)
    active_devices_count = Column(Integer, default=0)

    # Message throughput
    messages_per_minute = Column(Integer, default=0)
    errors_per_minute = Column(Integer, default=0)

    # Relationships
    hub = relationship('Hub', back_populates='metrics')

    __table_args__ = (
        Index('idx_hub_metrics_hub_id', 'hub_id'),
        Index('idx_hub_metrics_timestamp', 'timestamp'),
        Index('idx_hub_metrics_composite', 'hub_id', 'timestamp'),
    )

    def __repr__(self):
        return f'<HubMetrics hub={self.hub_id} at {self.timestamp}>'
