from sqlalchemy import (
    Column, Integer, String, Float, DateTime, Boolean, ForeignKey,
    Enum, Text, Index, UniqueConstraint
)
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from db.base import Base, DeviceTypeEnum


class Manufacturer(Base):
    __tablename__ = 'manufacturers'

    id = Column(Integer, primary_key=True, autoincrement=True)
    name = Column(String(255), unique=True, nullable=False, index=True)
    description = Column(Text)
    contact_email = Column(String(255))
    website = Column(String(255))
    is_verified = Column(Boolean, default=False, nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), 
                       onupdate=func.now(), nullable=False)

    device_types = relationship('DeviceType', back_populates='manufacturer', cascade='all, delete-orphan')

    def __repr__(self):
        return f'<Manufacturer {self.name}>'


class DeviceType(Base):
    __tablename__ = 'device_types'

    id = Column(Integer, primary_key=True, autoincrement=True)
    manufacturer_id = Column(Integer, ForeignKey('manufacturers.id', ondelete='CASCADE'), nullable=False)
    name = Column(String(255), nullable=False)
    device_type = Column(Enum(DeviceTypeEnum), nullable=False)
    description = Column(Text)
    communication_interface = Column(String(100))
    supported_functions = Column(Text)
    data_unit = Column(String(50))
    min_value = Column(Float)
    max_value = Column(Float)
    is_active = Column(Boolean, default=True, nullable=False, index=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), 
                       onupdate=func.now(), nullable=False)

    manufacturer = relationship('Manufacturer', back_populates='device_types')
    devices = relationship('Device', back_populates='device_type', cascade='all, delete-orphan')

    __table_args__ = (
        Index('idx_device_type_manufacturer', 'manufacturer_id'),
        Index('idx_device_type_is_active', 'is_active'),
        UniqueConstraint('manufacturer_id', 'name', name='uq_device_type_per_manufacturer'),
    )

    def __repr__(self):
        return f'<DeviceType {self.name}>'


class Device(Base):
    __tablename__ = 'devices'

    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey('users.id', ondelete='CASCADE'), nullable=False)
    device_type_id = Column(Integer, ForeignKey('device_types.id', ondelete='RESTRICT'), nullable=False)
    unique_identifier = Column(String(255), unique=True, nullable=False, index=True)
    device_name = Column(String(255), nullable=False)
    is_active = Column(Boolean, default=True, nullable=False, index=True)
    last_data_received = Column(DateTime(timezone=True))
    last_heartbeat = Column(DateTime(timezone=True))
    location_description = Column(String(255))
    battery_level = Column(Float)
    rssi = Column(Integer)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), 
                       onupdate=func.now(), nullable=False)

    owner = relationship('User', back_populates='devices')
    device_type = relationship('DeviceType', back_populates='devices')
    sensor_data = relationship('SensorData', back_populates='device', cascade='all, delete-orphan')
    plant_assignments = relationship('PlantDeviceAssignment', back_populates='device', cascade='all, delete-orphan')

    __table_args__ = (
        Index('idx_device_user', 'user_id'),
        Index('idx_device_unique_identifier', 'unique_identifier'),
        Index('idx_device_is_active', 'is_active'),
        Index('idx_device_type', 'device_type_id'),
    )

    def __repr__(self):
        return f'<Device {self.device_name}>'
