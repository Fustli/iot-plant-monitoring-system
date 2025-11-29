"""
Hub Models for IoT Plant Monitoring System

Hubs are physical gateway devices that users register at locations (home, work, etc.)
to communicate between smart devices and the cloud.
"""

from sqlalchemy import (
    Column, Integer, String, Float, DateTime, Boolean, ForeignKey,
    Text, Index, UniqueConstraint
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
    user_id = Column(Integer, ForeignKey('users.id', ondelete='CASCADE'), nullable=False)
    
    # Unique identifier for the hub (e.g., MAC address or serial number)
    hub_id = Column(String(255), unique=True, nullable=False, index=True)
    
    # Connection link/endpoint for the hub (e.g., MQTT broker URL, WebSocket URL)
    hub_link = Column(String(512), nullable=False)
    
    # Human-readable name and location
    name = Column(String(255), nullable=False)
    location = Column(String(255))  # e.g., "Home", "Office", "Greenhouse"
    description = Column(Text)
    
    # Connection status and health
    is_online = Column(Boolean, default=False, nullable=False, index=True)
    last_seen = Column(DateTime(timezone=True))
    last_heartbeat = Column(DateTime(timezone=True))
    
    # Network information
    ip_address = Column(String(45))  # Supports IPv6
    mac_address = Column(String(17))
    firmware_version = Column(String(50))
    
    # Metrics
    uptime_seconds = Column(Integer, default=0)
    messages_sent = Column(Integer, default=0)
    messages_received = Column(Integer, default=0)
    errors_count = Column(Integer, default=0)
    
    # Configuration
    is_active = Column(Boolean, default=True, nullable=False, index=True)
    
    # Timestamps
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), 
                       onupdate=func.now(), nullable=False)
    
    # Relationships
    owner = relationship('User', back_populates='hubs')
    devices = relationship('Device', back_populates='hub', cascade='all, delete-orphan')
    metrics = relationship('HubMetrics', back_populates='hub', cascade='all, delete-orphan')

    __table_args__ = (
        Index('idx_hub_user', 'user_id'),
        Index('idx_hub_hub_id', 'hub_id'),
        Index('idx_hub_is_online', 'is_online'),
        Index('idx_hub_is_active', 'is_active'),
    )

    def __repr__(self):
        return f'<Hub {self.name} ({self.hub_id})>'


class HubMetrics(Base):
    """
    Time-series metrics for hub performance monitoring.
    
    Stores periodic snapshots of hub health and performance metrics.
    """
    __tablename__ = 'hub_metrics'

    id = Column(Integer, primary_key=True, autoincrement=True)
    hub_id = Column(Integer, ForeignKey('hubs.id', ondelete='CASCADE'), nullable=False)
    
    # Timestamp of the metric snapshot
    timestamp = Column(DateTime(timezone=True), server_default=func.now(), nullable=False, index=True)
    
    # Connection metrics
    is_connected = Column(Boolean, default=False, nullable=False)
    latency_ms = Column(Float)  # Round-trip latency to cloud
    
    # Resource usage
    cpu_usage_percent = Column(Float)
    memory_usage_percent = Column(Float)
    disk_usage_percent = Column(Float)
    
    # Network metrics
    bandwidth_in_kbps = Column(Float)
    bandwidth_out_kbps = Column(Float)
    packet_loss_percent = Column(Float)
    
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
