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
    req_moisture: int
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
    last_data_received = None
    last_heartbeat = None
    location_description = None
    battery_level = None
    rssi = None

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
    plant_name: str
    scientific_name: str
    req_brightness: float
    req_humidity: float
    req_temperature: float
    req_moisture: int
    description: str | None = None
    care_instructions: str | None = None

class UserDetails(BaseModel):
    email: str
    username: str
    role: str
    password_hash: str
    first_name: str
    last_name: str
    phone_number: str
    is_active: bool
    is_verified: bool