from pydantic import BaseModel, EmailStr
from typing import Literal

Role = Literal["admin", "consumer", "manufacturer"]

class LoginRequest(BaseModel):
    email: EmailStr
    password: str

class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    role: Role
    username: str

class PlantTypeFromDB(BaseModel):
    name: str
    scientific_name: str
    is_healthy: bool = True
    location: str | None = None
    health_status: str | None = None
    notes: str | None = None

class PlantTypeFromScratch(BaseModel):
    name: str
    scientific_name: str
    req_brightness: float
    req_humidity: float
    req_temperature: float
    req_moisture: float
    description: str = None
    care_instructions: str = None
    location: str | None = None
    is_healthy: bool = True
    health_status: str | None = None
    notes: str | None = None

class DeviceCreation(BaseModel):
    plant_id: int
    device_type_name: str
    unique_identifier: str
    device_name: str
    is_active: bool = False
    last_data_received: str | None = None
    last_heartbeat: str | None = None
    location_description: str | None = None
    battery_level: float | None = None
    rssi: float | None = None

class PlantActivation(BaseModel):
    """
    plant_id = None affects all plants
    command=True activates, command=False deactivates the plant care.
    """
    plant_id: int | None = None
    command: bool = True

class DeviceActivation(BaseModel):
    """
    device_id = None affects all devices
    command=True activates, command=False deactivates the device.
    """
    device_id: int | None = None
    command: bool = True

class DeviceCommand(BaseModel):
    metric: str
    delta: float

class NewPlantType(BaseModel):
    name: str
    scientific_name: str
    req_brightness: float
    req_humidity: float
    req_temperature: float
    req_moisture: float
    description: str | None = None
    care_instructions: str | None = None

class UserDetails(BaseModel):
    email: str
    username: str
    role: str
    password_hash: str
    first_name: str | None = None
    last_name: str | None = None
    phone_number: str | None = None
    company_name: str | None = None  # For manufacturer registration
    is_active: bool = True
    is_verified: bool = False

class ConsumerRegistration(BaseModel):
    """Schema for public consumer registration - minimal fields required."""
    email: str
    username: str
    password: str
    first_name: str | None = None
    last_name: str | None = None

class PlantSearch(BaseModel):
    name: str | None = None
    scientific_name: str | None = None 

class PasswordChange(BaseModel):
    old_password: str
    new_password: str

class UserUpdate(BaseModel):
    """Schema for admin user updates - approve, verify, or change status."""
    role: Role | None = None
    is_active: bool | None = None
    is_verified: bool | None = None

class RegisterDevice(BaseModel):
    name: str
    device_type: str
    communication_interface: str
    supported_functions: str
    data_unit: str
    min_value: float
    max_value: float
    is_active: bool = True
    description: str | None = None

class ResetPasswordRequest(BaseModel):
    token: str
    new_password: str

class DeviceData(BaseModel):
    device_id: int
    data_type: str
    data: float
    data_unit: str
