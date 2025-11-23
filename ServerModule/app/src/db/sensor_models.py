from sqlalchemy import (
    Column, Integer, Float, DateTime, Boolean, ForeignKey,
    String, Index, Text
)
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from db.base import Base


class SensorData(Base):
    __tablename__ = 'sensor_data'

    id = Column(Integer, primary_key=True, autoincrement=True)
    device_id = Column(Integer, ForeignKey('devices.id', ondelete='CASCADE'), nullable=False)
    measurement_value = Column(Float, nullable=False)
    measurement_unit = Column(String(50))
    data_quality = Column(Integer, default=100)
    is_anomaly = Column(Boolean, default=False, index=True)
    timestamp = Column(DateTime(timezone=True), server_default=func.now(), nullable=False, index=True)
    raw_data = Column(Text)

    device = relationship('Device', back_populates='sensor_data')

    __table_args__ = (
        Index('idx_sensor_data_device', 'device_id'),
        Index('idx_sensor_data_timestamp', 'timestamp'),
        Index('idx_sensor_data_device_timestamp', 'device_id', 'timestamp'),
        Index('idx_sensor_data_is_anomaly', 'is_anomaly'),
    )

    def __repr__(self):
        return f'<SensorData device_id={self.device_id} value={self.measurement_value}>'
