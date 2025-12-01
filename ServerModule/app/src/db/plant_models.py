from sqlalchemy import (
    Column, Integer, String, Float, DateTime, Boolean, ForeignKey,
    Text, Index, UniqueConstraint
)
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from src.db.base import Base


class PlantType(Base):
    __tablename__ = 'plant_types'

    id = Column(Integer, primary_key=True, autoincrement=True)
    name = Column(String(255), nullable=False)
    scientific_name = Column(String(255), nullable=False, unique=True, index=True)
    description = Column(Text)
    optimal_temperature = Column(Float, nullable=False)
    optimal_humidity = Column(Float, nullable=False)
    optimal_light = Column(Float, nullable=False)
    optimal_moisture = Column(Float, nullable=False)
    care_instructions = Column(Text)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), 
                       onupdate=func.now(), nullable=False)

    plants = relationship('Plant', back_populates='plant_type', cascade='all, delete-orphan')

    def __repr__(self):
        return f'<PlantType {self.name}>'


class Plant(Base):
    __tablename__ = 'plants'

    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey('users.id', ondelete='CASCADE'), nullable=False)
    plant_type_id = Column(Integer, ForeignKey('plant_types.id', ondelete='RESTRICT'), nullable=False)
    plant_name = Column(String(255), unique=True, nullable=False)
    location = Column(String(255))
    planting_date = Column(DateTime(timezone=True))
    is_healthy = Column(Boolean, default=True, nullable=False, index=True)
    health_status = Column(String(100))  # CSV format: "brightness,humidity,temperature,moisture"
    notes = Column(Text)
    last_watered = Column(DateTime(timezone=True))
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), 
                       onupdate=func.now(), nullable=False)

    owner = relationship('User', back_populates='plants')
    plant_type = relationship('PlantType', back_populates='plants')
    device_assignments = relationship('PlantDeviceAssignment', back_populates='plant', cascade='all, delete-orphan')
    alerts = relationship('Alert', back_populates='plant', cascade='all, delete-orphan')

    __table_args__ = (
        Index('idx_plant_user', 'user_id'),
        Index('idx_plant_type', 'plant_type_id'),
        Index('idx_plant_is_healthy', 'is_healthy'),
    )

    def __repr__(self):
        return f'<Plant {self.plant_name}>'


class PlantDeviceAssignment(Base):
    __tablename__ = 'plant_device_assignments'

    id = Column(Integer, primary_key=True, autoincrement=True)
    plant_id = Column(Integer, ForeignKey('plants.id', ondelete='CASCADE'), nullable=False)
    device_id = Column(Integer, ForeignKey('devices.id', ondelete='CASCADE'), nullable=False)
    assignment_type = Column(String(100), nullable=False)
    is_active = Column(Boolean, default=True, nullable=False, index=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), 
                       onupdate=func.now(), nullable=False)

    plant = relationship('Plant', back_populates='device_assignments')
    device = relationship('Device', back_populates='plant_assignments')

    __table_args__ = (
        Index('idx_pda_plant', 'plant_id'),
        Index('idx_pda_device', 'device_id'),
        Index('idx_pda_is_active', 'is_active'),
        UniqueConstraint('plant_id', 'device_id', name='uq_plant_device_pair'),
    )

    def __repr__(self):
        return f'<PlantDeviceAssignment plant_id={self.plant_id} device_id={self.device_id}>'
