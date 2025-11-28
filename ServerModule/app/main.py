from datetime import datetime, timedelta
from typing import Dict

from fastapi import Body
from src.db.device_models import DeviceType as DeviceTypeModel, Device as DeviceModel
from src.db.plant_models import PlantType as PlantTypeModel, Plant as PlantModel
from src.db.sensor_models import SensorData as SensorDataModel
from src.db.alert_models import Alert as AlertModel
from src.db.base import AlertStatusEnum
from src.logger import Logger
from src.users import Consumer, Manufacturer
from src.plants import Plant as PlantDomain
from src.devices import create_device_from_type
from src.measurements import Moisture
from src.thread_manager import PlantThreadManager
from schemas import ResetPasswordRequest
from security import verify_password, hash_password
from src.db.db_utils import DBInterface

import uvicorn
from fastapi import HTTPException, status, FastAPI, Depends
from fastapi.middleware.cors import CORSMiddleware
from jose import JWTError
from dotenv import load_dotenv
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy.orm import Session
from typing import Generator, List

from schemas import (
    LoginRequest, 
    TokenResponse,
    PlantTypeFromDB, 
    PlantTypeFromScratch,
    DeviceCreation,
    PlantActivation,
    DeviceActivation,
    DeviceCommand,
    NewPlantType,
    UserDetails,
    PlantSearch,
    PasswordChange,
    RegisterDevice,
)
from security import verify_password
from auth_jwt import create_access_token, decode_access_token
from src.db.user_models import User
from src.db.db_utils import get_session, DBInterface

load_dotenv()

app = FastAPI()

# CORS middleware - allow frontend to access the API
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost:3000",
        "http://127.0.0.1:3000",
        "http://0.0.0.0:3000",
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/auth/login")


def get_db() -> Generator[Session, None, None]:
    """
    FastAPI dependency that provides a SQLAlchemy Session
    and makes sure it is closed after the request.
    """
    db = get_session()
    try:
        yield db
    finally:
        db.close()


async def get_current_user(
    token: str = Depends(oauth2_scheme),
    db: Session = Depends(get_db),
) -> User:
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
    )

    try:
        payload = decode_access_token(token)
        user_id: str = payload.get("sub")
        if user_id is None:
            raise credentials_exception
    except JWTError:
        raise credentials_exception

    user = db.query(User).get(int(user_id))
    if user is None:
        raise credentials_exception

    return user


def require_roles(allowed_roles: List[str]):
    """
    Dependency factory to restrict access based on user.role.

    - manufacturer-only endpoint:  ["manufacturer", "admin"]
    - consumer-only endpoint:      ["consumer", "admin"]
    - admin-only endpoint:         ["admin"]
    - all roles:                   ["admin", "consumer", "manufacturer"]
    """
    async def _require_roles(current_user: User = Depends(get_current_user)) -> User:
        if current_user.role not in allowed_roles:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Not enough permissions",
            )
        return current_user

    return _require_roles


class SystemState:
    """
    Holds in-memory domain objects (Consumers, Plants, Devices) and the
    background PlantThreadManager.
    """
    def __init__(self):
        self.thread_manager = PlantThreadManager(interval_seconds=300)
        self.consumers: Dict[int, Consumer] = {}
        self.manufacturers: Dict[int, Manufacturer] = {}
        self.logger = Logger(name="SystemState")
        self.initialized = False

    def _normalize_moisture(self, value: float) -> Moisture:
        """
        Map db moisture value (which may be a float 0-100) to Moisture enum.
        """
        try:
            return Moisture(int(value))
        except Exception:
            if value <= 33:
                return Moisture.DRY
            elif value <= 66:
                return Moisture.MOIST
            else:
                return Moisture.WET

    def load_from_db(self):
        """
        Build Consumer, Plant and Device objects from the database and start
        background plant-care threads.
        """
        if self.initialized:
            return

        db = DBInterface()
        # Make sure schema exists
        db.init_db()

        # --- Consumers ---
        consumers_rows = db.list_consumers() or []
        for row in consumers_rows:
            # users table: id, email, username, role, ...
            user_id = row[0]
            email = row[1]
            username = row[2]
            consumer = Consumer(user_id, username, email, self.thread_manager)
            self.consumers[user_id] = consumer

        # --- Plants ---
        plants_rows = db.list_plants() or []
        for row in plants_rows:
            # plants: id, user_id, plant_type_id, plant_name, location, planting_date,
            #         is_healthy, health_status, notes, created_at, updated_at
            plant_id, user_id, plant_type_id, plant_name, location, planting_date, is_healthy, health_status, notes, *_ = row

            consumer = self.consumers.get(user_id)
            if not consumer:
                # Non-consumer owners (e.g. admin) are ignored for in-memory care
                continue

            reqs = db.get_plant_type_requirements(plant_type_id)
            if not reqs:
                continue

            optimal_temperature, optimal_humidity, optimal_light, optimal_moisture = reqs

            plant = PlantDomain(
                plant_id,
                plant_name,
                user_id,
                req_brightness=optimal_light,
                req_humidity=optimal_humidity,
                req_temperature=optimal_temperature,
                req_moisture=self._normalize_moisture(optimal_moisture),
                health_status=health_status,
            )
            consumer.plants.append(plant)
            self.thread_manager.add_plant(plant)

        # --- Devices ---
        devices_rows = db.list_devices() or []
        for row in devices_rows:
            # devices: id, user_id, plant_id, device_type_id, unique_identifier,
            #          device_name, is_active, last_data_received, last_heartbeat,
            #          location_description, battery_level, rssi, created_at, updated_at
            device_id, user_id, plant_id, device_type_id, unique_identifier, device_name, is_active, last_data_received, last_heartbeat, location_description, battery_level, rssi, *_ = row

            consumer = self.consumers.get(user_id)
            if not consumer:
                continue

            device = create_device_from_type(
                device_id=device_id,
                user_id=user_id,
                device_type_id=device_type_id,
                unique_identifier=unique_identifier,
                device_name=device_name,
                is_active=is_active,
            )

            for plant in consumer.plants:
                if plant.id == plant_id:
                    plant.register_device(device)
                    break

        self.thread_manager.start()
        self.initialized = True
        self.logger.info("SystemState initialized")

    def get_consumer(self, user: User) -> Consumer:
        consumer = self.consumers.get(user.id)
        if consumer is None:
            consumer = Consumer(user.id, user.username, user.email, self.thread_manager)
            self.consumers[user.id] = consumer
        return consumer

    def get_manufacturer(self, user: User) -> Manufacturer:
        manufacturer = self.manufacturers.get(user.id)
        if manufacturer is None:
            manufacturer = Manufacturer(user.id, user.username)
            self.manufacturers[user.id] = manufacturer
        return manufacturer

system_state = SystemState()

# ---------------------------------------------------------------------------
# 1. Authentication
# ---------------------------------------------------------------------------

@app.post("/api/auth/login", response_model=TokenResponse)
async def login(payload: LoginRequest, db: Session = Depends(get_db)):
    # Look up by email (or username if you prefer)
    user = db.query(User).filter(User.email == payload.email).first()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password",
        )

    # Check password
    if not verify_password(payload.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password",
        )

    # Put id + role into JWT
    token_data = {
        "sub": str(user.id),
        "role": user.role,
    }
    access_token = create_access_token(token_data)

    return TokenResponse(
        access_token=access_token,
        role=user.role,
        username=user.username,
    )


@app.post("/api/auth/register")
async def register(
    payload: UserDetails,
    current_user: User = Depends(require_roles(["admin"])),
    db: Session = Depends(get_db),
):
    """Registers a new user account (admin only)."""
    existing = db.query(User).filter(
        (User.email == payload.email) | (User.username == payload.username)
    ).first()
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="User with this email or username already exists",
        )

    new_user = User(
        email=payload.email,
        username=payload.username,
        role=payload.role,
        # We treat password_hash field as the plain password in the API layer.
        password_hash=hash_password(payload.password_hash),
        first_name=payload.first_name,
        last_name=payload.last_name,
        phone_number=payload.phone_number,
        is_active=payload.is_active,
        is_verified=payload.is_verified,
    )
    db.add(new_user)
    db.commit()
    db.refresh(new_user)

    # Initialize domain object if relevant
    if new_user.role == "consumer":
        system_state.get_consumer(new_user)
    elif new_user.role == "manufacturer":
        system_state.get_manufacturer(new_user)

    return {
        "id": new_user.id,
        "email": new_user.email,
        "username": new_user.username,
        "role": new_user.role,
    }


@app.post("/api/auth/register/consumer")
async def register_consumer(
    payload: UserDetails,
    db: Session = Depends(get_db),
):
    """
    Public registration for consumer users only.
    Manufacturers and admins must be created by existing admins.
    """
    existing = db.query(User).filter(
        (User.email == payload.email) | (User.username == payload.username)
    ).first()
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="User with this email or username already exists",
        )

    new_user = User(
        email=payload.email,
        username=payload.username,
        role="consumer",
        password_hash=hash_password(payload.password_hash),
        first_name=payload.first_name,
        last_name=payload.last_name,
        phone_number=payload.phone_number,
        is_active=True,
        is_verified=False,
    )
    db.add(new_user)
    db.commit()
    db.refresh(new_user)

    system_state.get_consumer(new_user)

    return {
        "id": new_user.id,
        "email": new_user.email,
        "username": new_user.username,
    }



@app.get("/api/user/profile")
async def get_user_profile(
    current_user: User = Depends(
        require_roles(["admin", "consumer", "manufacturer"])
    ),
):
    """Returns current user details and preferences."""
    db_interface = DBInterface()
    user_details = db_interface.list_users(current_user.id)
    return user_details


@app.put("/api/user/profile")
async def update_user_profile(
    payload: UserDetails,
    current_user: User = Depends(
        require_roles(["admin", "consumer", "manufacturer"])
    ),
    db: Session = Depends(get_db),
):
    """Updates current user's profile details (not password)."""
    current_user.email = payload.email
    current_user.username = payload.username
    current_user.first_name = payload.first_name
    current_user.last_name = payload.last_name
    current_user.phone_number = payload.phone_number

    # Let admins update their own flags as well
    if current_user.role == "admin":
        current_user.is_active = payload.is_active
        current_user.is_verified = payload.is_verified

    db.commit()
    db.refresh(current_user)

    if current_user.role == "consumer":
        system_state.get_consumer(current_user)
    elif current_user.role == "manufacturer":
        system_state.get_manufacturer(current_user)

    return {
        "id": current_user.id,
        "email": current_user.email,
        "username": current_user.username,
        "role": current_user.role,
        "first_name": current_user.first_name,
        "last_name": current_user.last_name,
        "phone_number": current_user.phone_number,
    }


@app.post("/api/user/change-password")
async def change_password(
    payload: PasswordChange,
    current_user: User = Depends(
        require_roles(["admin", "consumer", "manufacturer"])
    ),
    db: Session = Depends(get_db),
):
    """Change user password."""
    if not verify_password(payload.old_password, current_user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Old password is incorrect",
        )

    current_user.password_hash = hash_password(payload.new_password)
    db.commit()
    return {"detail": "Password changed successfully"}


@app.post("/api/auth/forgot-password")
async def forgot_password(
    email: str = Body(..., embed=True),
    db: Session = Depends(get_db),
):
    """Initiate password reset flow."""
    user = db.query(User).filter(User.email == email).first()
    if not user:
        # Don't leak whether the email exists
        return {"detail": "If an account with this email exists, a reset link has been generated."}

    token_data = {"sub": str(user.id), "scope": "password_reset"}
    reset_token = create_access_token(token_data, expires_delta=timedelta(minutes=30))

    # In a real system we would email this token. For dev, just return it.
    return {
        "detail": "Password reset token generated",
        "reset_token": reset_token,
    }


@app.post("/api/auth/reset-password")
async def reset_password(
    payload: ResetPasswordRequest,
    db: Session = Depends(get_db),
):
    """Reset password with token."""
    try:
        data = decode_access_token(payload.token)
    except JWTError:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid or expired token",
        )

    if data.get("scope") != "password_reset":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid token scope",
        )

    user_id = data.get("sub")
    if not user_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid token payload",
        )

    user = db.query(User).get(int(user_id))
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found",
        )

    user.password_hash = hash_password(payload.new_password)
    db.commit()
    return {"detail": "Password has been reset"}



# ---------------------------------------------------------------------------
# 2. Administrator (System Management)
# ---------------------------------------------------------------------------

@app.get("/api/admin/system/status")
async def get_system_status(
    current_admin: User = Depends(require_roles(["admin"])),
):
    """Monitors server health, resources, and database connection status."""
    db_interface = DBInterface()
    db_ok = False
    try:
        db_interface.execute_query("SELECT 1")
        db_ok = True
    except Exception:
        db_ok = False

    return {
        "application": "ok",
        "database": "ok" if db_ok else "error",
    }


@app.get("/api/admin/users")
async def list_admin_users(
    current_admin: User = Depends(require_roles(["admin"])),
):
    """Lists all registered users for database maintenance."""
    db_interface = DBInterface()
    users = db_interface.list_users()
    return users


@app.delete("/api/admin/users/{user_id}")
async def delete_user(
    user_id: int,
    current_admin: User = Depends(require_roles(["admin"])),
):
    """Deletes a user account or bans a user."""
    db_interface = DBInterface()
    return db_interface.remove_user(user_id)


@app.delete("/api/admin/manufacturers/{manufacturer_id}")
async def delete_user(
    manufacturer_id: int,
    current_admin: User = Depends(require_roles(["admin"])),
):
    """Deletes a user account or bans a user."""
    db_interface = DBInterface()
    return db_interface.remove_manufacturer(manufacturer_id)


@app.get("/api/admin/devices")
async def list_all_devices_admin(
    current_admin: User = Depends(require_roles(["admin"])),
):
    """Lists all devices in the system for administrative oversight."""
    db_interface = DBInterface()
    devices = db_interface.list_devices()
    return devices


@app.get("/api/admin/device_types")
async def list_all_devices_admin(
    current_admin: User = Depends(require_roles(["admin"])),
):
    """Lists all devices in the system for administrative oversight."""
    db_interface = DBInterface()
    device_types = db_interface.list_device_types()
    return device_types

@app.get("/api/admin/plants")
async def list_all_devices_admin(
    current_admin: User = Depends(require_roles(["admin"])),
):
    """Lists all devices in the system for administrative oversight."""
    db_interface = DBInterface()
    plants = db_interface.list_plants()
    return plants


# ---------------------------------------------------------------------------
# 3. Device Manufacturer
# ---------------------------------------------------------------------------

@app.post("/api/manufacturer/device-types")
async def register_device_type(
    payload: RegisterDevice,
    current_manufacturer: User = Depends(
        require_roles(["manufacturer", "admin"])
    ),
):
    """Registers a new type of device with its capabilities and documentation."""
    manufacturer_domain = system_state.get_manufacturer(current_manufacturer)

    supported_functions_list = [
        s.strip() for s in payload.supported_functions.split(",") if s.strip()
    ]

    manufacturer_domain.register_new_device_type(
        name=payload.name,
        device_type=payload.device_type,
        communication_interface=payload.communication_interface,
        supported_functions=supported_functions_list,
        data_unit=payload.data_unit,
        min_value=payload.min_value,
        max_value=payload.max_value,
        is_active=payload.is_active,
        description=payload.description,
    )

    return {"detail": "Device type registered successfully"}



@app.get("/api/manufacturer/device-types")
async def list_device_types(
    current_manufacturer: User = Depends(
        require_roles(["manufacturer", "admin"])
    ),
):
    """Lists device types created by this manufacturer."""
    db_interface = DBInterface()
    device_types = db_interface.list_device_types(current_manufacturer.id)
    return device_types


@app.put("/api/manufacturer/device-types/{device_type_id}")
async def update_device_type(
    device_type_id: int,
    payload: RegisterDevice,
    current_manufacturer: User = Depends(
        require_roles(["manufacturer", "admin"])
    ),
    db: Session = Depends(get_db),
):
    """Updates documentation or function descriptions for a device type."""
    device_type = db.query(DeviceTypeModel).get(device_type_id)
    if not device_type:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Device type not found",
        )

    if current_manufacturer.role != "admin" and device_type.manufacturer_id != current_manufacturer.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not enough permissions",
        )

    device_type.name = payload.name
    device_type.device_type = payload.device_type
    device_type.communication_interface = payload.communication_interface
    device_type.supported_functions = payload.supported_functions
    device_type.data_unit = payload.data_unit
    device_type.min_value = payload.min_value
    device_type.max_value = payload.max_value
    device_type.description = payload.description
    device_type.is_active = payload.is_active

    db.commit()
    db.refresh(device_type)
    return device_type



# ---------------------------------------------------------------------------
# 4. Plants
# ---------------------------------------------------------------------------

@app.post("/api/plant-type")
async def add_new_plant_type(
    payload: NewPlantType,
    current_admin: User = Depends(require_roles(["admin"])),
):
    """Adds a new plant species to the public catalog with its requirements."""
    db_interface = DBInterface()
    return db_interface.register_new_plant_type(
        payload.name,
        payload.scientific_name,
        payload.req_temperature,
        payload.req_humidity,
        payload.req_brightness,
        payload.req_moisture,
        payload.description,
        payload.care_instructions,
    )


@app.put("/api/plant-types/{species_id}")
async def update_plant_species(
    species_id: int,
    payload: NewPlantType,
    current_admin: User = Depends(require_roles(["admin"])),
    db: Session = Depends(get_db),
):
    """Modifies requirements for an existing plant species."""
    plant_type = db.query(PlantTypeModel).get(species_id)
    if not plant_type:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Plant type not found",
        )

    plant_type.name = payload.plant_name
    plant_type.scientific_name = payload.scientific_name
    plant_type.optimal_temperature = payload.req_temperature
    plant_type.optimal_humidity = payload.req_humidity
    plant_type.optimal_light = payload.req_brightness
    plant_type.optimal_moisture = payload.req_moisture
    plant_type.description = payload.description
    plant_type.care_instructions = payload.care_instructions

    db.commit()
    db.refresh(plant_type)
    return plant_type


@app.delete("/api/plant-type/{species_id}")
async def delete_plant_species(
    species_id: int,
    current_admin: User = Depends(require_roles(["admin"])),
):
    """Removes a species from the catalog."""
    db_interface = DBInterface()
    ok = db_interface.remove_plant_type(species_id)
    if not ok:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Plant type not found",
        )
    return {"detail": "Plant type removed"}


@app.get("/api/consumer/plant-types")
async def list_plant_types(
    current_user: User = Depends(require_roles(["consumer", "admin"])),
):
    """Lists available plant types for the user to select from when adding a new plant."""
    db_interface = DBInterface()
    plant_types = db_interface.list_plant_types()
    return plant_types


@app.get("/api/consumer/plant-types/search")
async def search_plant_types(
    payload: PlantSearch,
    current_user: User = Depends(require_roles(["consumer", "admin"])),
):
    """Search plant types by name or scientific name."""
    db_interface = DBInterface()
    if payload.scientific_name:
        plant_type = db_interface.get_plant_details_by_sci_name(payload.scientific_name)
        return plant_type
    elif payload.name:
        plant_type = db_interface.get_plant_details_by_name(payload.name)
        return plant_type
    else:
        return "No name or scientific name was given. Could not return plant type."


@app.get("/api/consumer/my-plants")
async def list_user_plants(
    current_user: User = Depends(require_roles(["consumer", "admin"])),
):
    """Lists the user's registered plants with their status."""
    db_interface = DBInterface()
    plant_types = db_interface.list_plants(current_user.id)
    if plant_types:
        return plant_types
    else:
        return "The user has no registered plants."


@app.post("/api/consumer/plant-from-scratch")
async def create_new_plant_from_scratch(
    payload: PlantTypeFromScratch,
    current_user: User = Depends(require_roles(["consumer", "admin"])),
):
    """Registers a new plant and plant_type manually."""
    consumer = system_state.get_consumer(current_user)
    plant_id = consumer.register_plant(
        name=payload.name,
        scientific_name=payload.scientific_name,
        req_brightness=payload.req_brightness,
        req_humidity=payload.req_humidity,
        req_temperature=payload.req_temperature,
        req_moisture=payload.req_moisture,
        description=payload.description,
        care_instructions=payload.care_instructions,
        location=payload.location,
        is_healthy=payload.is_healthy,
        health_status=payload.health_status,
        notes=payload.notes,
    )
    return {"plant_id": plant_id}


@app.post("/api/consumer/plant-from-database")
async def create_new_plant_from_db(
    payload: PlantTypeFromDB,
    current_user: User = Depends(require_roles(["consumer", "admin"])),
):
    """Registers a new plant by selecting a species from the database."""
    consumer = system_state.get_consumer(current_user)
    plant_id = consumer.register_plant_from_database(
        name=payload.name,
        scientific_name=payload.scientific_name,
        is_healthy=payload.is_healthy,
        location=payload.location,
        health_status=payload.health_status,
        notes=payload.notes,
    )
    return {"plant_id": plant_id}


@app.get("/api/consumer/my-plants/{plant_id}")
async def get_my_plant(
    plant_id: int,
    current_user: User = Depends(require_roles(["consumer", "admin"])),
):
    """Gets details of a plant."""
    db_interface = DBInterface()
    plant = db_interface.get_plant_by_id(plant_id)
    if plant:
        return plant
    else:
        return f"User {current_user.username} has no plant with the id {plant_id}"


@app.post("/api/consumer/my-plants/activation")
async def plant_activation(
    payload: PlantActivation,
    current_user: User = Depends(require_roles(["consumer", "admin"])),
):
    """Activates or deactivates plant care for all or one specific plant."""
    consumer = system_state.get_consumer(current_user)
    consumer.plant_care_activation(plant_id=payload.plant_id, command=payload.command)
    return {
        "detail": "Plant care " + ("activated" if payload.command else "deactivated")
    }


@app.put("/api/consumer/my-plants/{plant_id}")
async def update_my_plant(
    plant_id: int,
    payload: PlantTypeFromDB,
    current_user: User = Depends(require_roles(["consumer", "admin"])),
    db: Session = Depends(get_db),
):
    """Updates an existing plant's details."""
    plant = db.query(PlantModel).get(plant_id)
    if not plant:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Plant not found",
        )

    if current_user.role != "admin" and plant.user_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not enough permissions",
        )

    plant.plant_name = payload.name
    plant.location = payload.location
    plant.is_healthy = payload.is_healthy
    plant.health_status = payload.health_status
    plant.notes = payload.notes

    db.commit()
    db.refresh(plant)

    # sync in-memory
    consumer = system_state.get_consumer(current_user)
    for p in consumer.plants:
        if p.id == plant_id:
            p.name = plant.plant_name
            if payload.health_status:
                try:
                    brightness, humidity, temperature, moisture = (float(x) for x in payload.health_status.split(","))
                    p.act_brightness = int(brightness)
                    p.act_humidity = humidity
                    p.act_temperature = temperature
                    p.act_moisture = Moisture(int(moisture))
                except Exception:
                    # Ignore malformed health_status
                    pass
            break

    return {
        "id": plant.id,
        "plant_name": plant.plant_name,
        "location": plant.location,
        "is_healthy": plant.is_healthy,
        "health_status": plant.health_status,
        "notes": plant.notes,
    }


@app.delete("/api/consumer/my-plants/{plant_id}")
async def delete_my_plant(
    plant_id: int,
    current_user: User = Depends(require_roles(["consumer", "admin"])),
):
    """Removes an existing plant from the database and from the system."""
    db_interface = DBInterface()
    ok = db_interface.remove_plant(plant_id)

    consumer = system_state.get_consumer(current_user)
    for plant in list(consumer.plants):
        if plant.id == plant_id:
            consumer.plants.remove(plant)
            system_state.thread_manager.remove_plant(plant)
            break

    if not ok:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Plant not found",
        )

    return {"detail": "Plant removed"}


# ---------------------------------------------------------------------------
# 6. Devices
# ---------------------------------------------------------------------------

@app.post("/api/consumer/devices/register")
async def register_user_device(
    payload: DeviceCreation,
    current_user: User = Depends(require_roles(["consumer", "admin"])),
):
    """Registers a purchased device to the user's account using its Unique ID."""
    consumer = system_state.get_consumer(current_user)
    unique_identifier = consumer.register_new_device(
        plant_id=payload.plant_id,
        device_type_name=payload.device_type_name,
        unique_identifier=payload.unique_identifier,
        device_name=payload.device_name,
        is_active=payload.is_active,
        last_data_received=payload.last_data_received,
        last_heartbeat=payload.last_heartbeat,
        location_description=payload.location_description,
        battery_level=payload.battery_level,
        rssi=payload.rssi,
    )
    return {
        "unique_identifier": unique_identifier,
        "detail": "Device registered and attached to plant",
    }


@app.get("/api/consumer/device-types")
async def list_available_device_types(
    current_user: User = Depends(require_roles(["consumer", "admin", "manufacturer"])),
):
    """Lists device types."""
    db_interface = DBInterface()
    device_types = db_interface.list_device_types()
    return device_types


@app.get("/api/consumer/my-devices")
async def list_my_devices(
    current_user: User = Depends(require_roles(["consumer", "admin"])),
):
    """Lists all devices owned by the user."""
    db_interface = DBInterface()
    devices = db_interface.list_devices(current_user.id)
    if devices:
        return devices
    else:
        return f"User {current_user.username} has no devices registered."


@app.post("/api/consumer/my-devices/activation")
async def device_activation(
    payload: DeviceActivation,
    current_user: User = Depends(require_roles(["consumer", "admin"])),
):
    """Activates or deactivates all or one specific device."""
    consumer = system_state.get_consumer(current_user)
    consumer.device_activation(device_id=payload.device_id, command=payload.command)
    return {
        "detail": "Devices " + ("activated" if payload.command else "deactivated")
    }



@app.delete("/api/consumer/my-devices/{device_id}")
async def remove_my_device(
    device_id: int,
    current_user: User = Depends(require_roles(["consumer", "admin"])),
):
    """Removes a device from the user's account."""
    db_interface = DBInterface()
    ok = db_interface.remove_device(device_id)

    consumer = system_state.get_consumer(current_user)
    for plant in consumer.plants:
        for dev in list(plant.devices.devices):
            if dev.id == device_id:
                plant.devices.remove_device(dev)
                break

    if not ok:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Device not found",
        )
    return {"detail": "Device removed"}



# ---------------------------------------------------------------------------
# 7. Monitoring & Control
# ---------------------------------------------------------------------------

@app.get("/api/consumer/devices/{device_id}/history")
async def get_device_history(
    device_id: int,
    current_user: User = Depends(require_roles(["consumer", "admin"])),
    db: Session = Depends(get_db),
):
    """Retrieves historical sensor data (time-series) for charts."""
    device = db.query(DeviceModel).get(device_id)
    if not device:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Device not found",
        )

    if current_user.role != "admin" and device.user_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not enough permissions",
        )

    rows = (
        db.query(SensorDataModel)
        .filter(SensorDataModel.device_id == device_id)
        .order_by(SensorDataModel.timestamp.desc())
        .limit(500)
        .all()
    )

    return [
        {
            "id": r.id,
            "device_id": r.device_id,
            "value": r.measurement_value,
            "unit": r.measurement_unit,
            "timestamp": r.timestamp,
            "is_anomaly": r.is_anomaly,
        }
        for r in rows
    ]


@app.post("/api/consumer/devices/{device_id}/command")
async def send_device_command(
    device_id: int,
    payload: DeviceCommand,
    current_user: User = Depends(require_roles(["consumer", "admin"])),
    db: Session = Depends(get_db),
):
    """Sends a manual command to an actuator (e.g., 'Water Now')."""
    device = db.query(DeviceModel).get(device_id)
    if not device:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Device not found",
        )

    if current_user.role != "admin" and device.user_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not enough permissions",
        )

    consumer = system_state.get_consumer(current_user)
    target_device = None
    for plant in consumer.plants:
        for d in plant.devices.devices:
            if d.id == device_id:
                target_device = d
                break
        if target_device:
            break

    if not target_device:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Device is not attached to any loaded plant",
        )

    method_name = f"change_{payload.metric}"
    method = getattr(target_device, method_name, None)
    if method is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Device does not support metric '{payload.metric}'",
        )

    method(payload.delta)
    return {"detail": "Command sent"}


@app.get("/api/consumer/alerts/{user_id}")
async def get_alerts(
    user_id: int,
    current_user: User = Depends(require_roles(["consumer", "admin"])),
    db: Session = Depends(get_db),
):
    """Retrieves active system alerts (e.g., low moisture, device failure)."""
    if current_user.role != "admin" and current_user.id != user_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not enough permissions",
        )

    alerts = (
        db.query(AlertModel)
        .filter(
            AlertModel.user_id == user_id,
            AlertModel.status == AlertStatusEnum.ACTIVE,
        )
        .order_by(AlertModel.triggered_at.desc())
        .all()
    )

    return [
        {
            "id": a.id,
            "plant_id": a.plant_id,
            "severity": a.severity.value,
            "status": a.status.value,
            "message": a.message,
            "triggered_value": a.triggered_value,
            "threshold_value": a.threshold_value,
            "triggered_at": a.triggered_at,
        }
        for a in alerts
    ]


@app.put("/api/consumer/alerts/{alert_id}/acknowledge")
async def acknowledge_alert(
    alert_id: int,
    current_user: User = Depends(require_roles(["consumer", "admin"])),
    db: Session = Depends(get_db),
):
    """Mark alert as acknowledged."""
    alert = db.query(AlertModel).get(alert_id)
    if not alert:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Alert not found",
        )

    if current_user.role != "admin" and alert.user_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not enough permissions",
        )

    alert.status = AlertStatusEnum.ACKNOWLEDGED
    alert.acknowledged_at = datetime.utcnow()
    db.commit()
    db.refresh(alert)

    return {"detail": "Alert acknowledged"}


@app.put("/api/consumer/alerts/{alert_id}/resolve")
async def resolve_alert(
    alert_id: int,
    current_user: User = Depends(require_roles(["consumer", "admin"])),
    db: Session = Depends(get_db),
):
    """Mark alert as resolved."""
    alert = db.query(AlertModel).get(alert_id)
    if not alert:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Alert not found",
        )

    if current_user.role != "admin" and alert.user_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not enough permissions",
        )

    alert.status = AlertStatusEnum.RESOLVED
    if alert.acknowledged_at is None:
        alert.acknowledged_at = datetime.utcnow()
    alert.resolved_at = datetime.utcnow()
    db.commit()
    db.refresh(alert)

    return {"detail": "Alert resolved"}



def init():
    """
    Initialize DB schema (if needed), load domain objects and start threads.
    """
    try:
        system_state.load_from_db()
    except Exception as exc:
        # Don't crash import on init failures; they will show up quickly anyway.
        print(f"[INIT] Failed to initialize domain model: {exc}")


@app.on_event("startup")
def on_startup():
    init()


if __name__ == "__main__":
    init()
    uvicorn.run(app)
