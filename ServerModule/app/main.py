from datetime import datetime, timedelta
from typing import Dict, Generator, List

import uvicorn
import os
from dotenv import load_dotenv
from fastapi import Body, Depends, FastAPI, HTTPException, status
from fastapi.responses import PlainTextResponse
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import OAuth2PasswordBearer
from jose import JWTError
from sqlalchemy.orm import Session

from auth_jwt import create_access_token, decode_access_token
from schemas import (
    ConsumerRegistration,
    DeviceActivation,
    DeviceCommand,
    DeviceCreation,
    HubCreate,
    HubUpdate,
    HubDeviceAssign,
    LoginRequest,
    NewPlantType,
    PasswordChange,
    PlantActivation,
    PlantSearch,
    PlantTypeFromDB,
    PlantTypeFromScratch,
    RegisterDevice,
    ResetPasswordRequest,
    TokenResponse,
    UserDetails,
    UserUpdate,
    DeviceData,
)
from security import hash_password, verify_password
from src.db.alert_models import Alert as AlertModel
from src.db.base import AlertStatusEnum
from src.db.db_utils import DBInterface, get_session
from src.db.device_models import Device as DeviceModel, DeviceType as DeviceTypeModel, Manufacturer as ManufacturerModel
from src.db.hub_models import Hub as HubModel
from src.db.plant_models import Plant as PlantModel, PlantType as PlantTypeModel
from src.db.sensor_models import SensorData as SensorDataModel
from src.db.user_models import User
from src.devices import Device, create_device_from_type
from src.logger import Logger
from src.plants import Plant as PlantDomain
from src.thread_manager import PlantThreadManager
from src.users import Consumer, Manufacturer

load_dotenv()

app = FastAPI()

# =============================================================================
# SERIALIZATION HELPERS
# =============================================================================
# These convert raw SQL tuples to dictionaries for JSON response

def serialize_user(row: tuple) -> dict:
    """Convert user tuple to dictionary."""
    if not row:
        return None
    return {
        "id": row[0],
        "email": row[1],
        "username": row[2],
        "role": row[3],
        # Skip password_hash (row[4])
        "first_name": row[5],
        "last_name": row[6],
        "phone_number": row[7],
        "is_active": row[8],
        "is_verified": row[9],
        "created_at": row[10].isoformat() if row[10] else None,
        "updated_at": row[11].isoformat() if row[11] else None,
        "last_login": row[12].isoformat() if row[12] else None,
    }

def serialize_plant_type(row: tuple) -> dict:
    """Convert plant_type tuple to dictionary."""
    if not row:
        return None
    return {
        "id": row[0],
        "name": row[1],
        "scientific_name": row[2],
        "description": row[3],
        "optimal_temperature": row[4],
        "optimal_humidity": row[5],
        "optimal_light": row[6],
        "optimal_moisture": row[7],
        "care_instructions": row[8],
        "created_at": row[9].isoformat() if row[9] else None,
        "updated_at": row[10].isoformat() if row[10] else None,
    }

def serialize_plant(row: tuple) -> dict:
    """Convert plant tuple to dictionary.
    
    health_status contains CSV: "brightness,humidity,temperature,moisture"
    """
    if not row:
        return None
    
    # Parse health_status CSV to extract sensor values
    health_status = row[7]
    brightness = None
    humidity = None
    temperature = None
    moisture = None
    
    if health_status:
        parts = health_status.split(',')
        if len(parts) >= 4:
            try:
                brightness = float(parts[0]) if parts[0] else None
                humidity = float(parts[1]) if parts[1] else None
                temperature = float(parts[2]) if parts[2] else None
                moisture = float(parts[3]) if parts[3] else None
            except (ValueError, IndexError):
                pass
    
    return {
        "id": row[0],
        "user_id": row[1],
        "plant_type_id": row[2],
        "plant_name": row[3],
        "location": row[4],
        "planting_date": row[5].isoformat() if row[5] else None,
        "is_healthy": row[6],
        "health_status": health_status,
        "notes": row[8],
        "current_light": brightness,
        "current_humidity": humidity,
        "current_temperature": temperature,
        "current_moisture": moisture,
        "last_watered": row[9].isoformat() if row[9] else None,
        "created_at": row[10].isoformat() if row[10] else None,
        "updated_at": row[11].isoformat() if row[11] else None,
    }

def serialize_hub(row: tuple) -> dict:
    """Convert hub tuple to dictionary."""
    if not row:
        return None
    return {
        "id": row[0],
        "user_id": row[1],
        "hub_id": row[2],
        "hub_link": row[3],
        "name": row[4],
        "location": row[5],
        "description": row[6],
        "is_online": row[7],
        "last_seen": row[8].isoformat() if row[8] else None,
        "last_heartbeat": row[9].isoformat() if row[9] else None,
        "ip_address": row[10],
        "mac_address": row[11],
        "firmware_version": row[12],
        "uptime_seconds": row[13],
        "messages_sent": row[14],
        "messages_received": row[15],
        "errors_count": row[16],
        "is_active": row[17],
        "created_at": row[18].isoformat() if row[18] else None,
        "updated_at": row[19].isoformat() if row[19] else None,
    }

def serialize_device(row: tuple) -> dict:
    """Convert device tuple to dictionary."""
    if not row:
        return None
    return {
        "id": row[0],
        "user_id": row[1],
        "hub_id": row[2],
        "plant_id": row[3],
        "device_type_id": row[4],
        "unique_identifier": row[5],
        "device_name": row[6],
        "is_active": row[7],
        "last_data_received": row[8].isoformat() if row[8] else None,
        "last_heartbeat": row[9].isoformat() if row[9] else None,
        "location_description": row[10],
        "battery_level": row[11],
        "rssi": row[12],
        "created_at": row[13].isoformat() if row[13] else None,
        "updated_at": row[14].isoformat() if row[14] else None,
    }

def serialize_device_type(row: tuple) -> dict:
    """Convert device_type tuple to dictionary."""
    if not row:
        return None
    return {
        "id": row[0],
        "manufacturer_id": row[1],
        "name": row[2],
        "device_type": row[3],
        "description": row[4],
        "communication_interface": row[5],
        "supported_functions": row[6],
        "data_unit": row[7],
        "min_value": row[8],
        "max_value": row[9],
        "is_active": row[10],
        "created_at": row[11].isoformat() if row[11] else None,
        "updated_at": row[12].isoformat() if row[12] else None,
    }

def serialize_plant_type_search(row: tuple) -> dict:
    """Convert plant_type search result tuple to dictionary (shorter field list)."""
    if not row:
        return None
    return {
        "id": row[0],
        "name": row[1],
        "scientific_name": row[2],
        "optimal_temperature": row[3],
        "optimal_humidity": row[4],
        "optimal_light": row[5],
        "optimal_moisture": row[6],
        "description": row[7],
        "care_instructions": row[8],
    }

def serialize_runtime_device(device: Device) -> dict:
    """
    Convert a runtime Device instance to a dictionary with key properties.
    """
    return {
        "id": getattr(device, "id", None),
        "user_id": getattr(device, "user_id", None),
        "device_type_id": getattr(device, "device_type_id", None),
        "unique_identifier": getattr(device, "unique_identifier", None),
        "device_name": getattr(device, "device_name", None),
        "is_active": getattr(device, "is_active", None),
        "capabilities": sorted(list(getattr(device, "capabilities", set()))),
    }


def serialize_runtime_plant(plant: PlantDomain) -> dict:
    """
    Convert a runtime PlantDomain instance to a dictionary, including attached devices.
    """
    # Collect attached devices from the DeviceCollection if present
    devices_data = []
    device_collection = getattr(plant, "devices", None)
    if device_collection is not None:
        for dev in getattr(device_collection, "devices", []):
            devices_data.append(serialize_runtime_device(dev))

    return {
        "id": getattr(plant, "id", None),
        "name": getattr(plant, "name", None),
        "user_id": getattr(plant, "user_id", None),
        "req_brightness": getattr(plant, "_req_brightness", None),
        "req_humidity": getattr(plant, "_req_humidity", None),
        "req_temperature": getattr(plant, "_req_temperature", None),
        "req_moisture": getattr(plant, "_req_moisture", None),
        "act_brightness": getattr(plant, "act_brightness", None),
        "act_humidity": getattr(plant, "act_humidity", None),
        "act_temperature": getattr(plant, "act_temperature", None),
        "act_moisture": getattr(plant, "act_moisture", None),
        "health_status": getattr(plant, "health_status", None),
        "devices": devices_data,
    }


def serialize_runtime_consumer(consumer: Consumer) -> dict:
    """
    Convert a runtime Consumer instance to a dictionary, including its plants and devices.
    """
    plants_data = []
    devices_data = []

    for plant in getattr(consumer, "plants", []):
        plant_dict = serialize_runtime_plant(plant)
        plants_data.append(plant_dict)
        # Devices are already inside plant_dict["devices"], but we also flatten them
        devices_data.extend(plant_dict.get("devices", []))

    return {
        "id": getattr(consumer, "id", None),
        "username": getattr(consumer, "username", None),
        "email": getattr(consumer, "email", None),
        "plants": plants_data,
        "devices": devices_data,
    }


def serialize_runtime_manufacturer(manufacturer: Manufacturer) -> dict:
    """
    Convert a runtime Manufacturer instance to a dictionary.
    """
    return {
        "id": getattr(manufacturer, "id", None),
        "username": getattr(manufacturer, "username", None),
    }

# CORS middleware - configurable via the `CORS_ORIGINS` env var.
# - Set `CORS_ORIGINS` to a comma-separated list of allowed origins in App Service
#   (e.g. https://myfrontend.azurewebsites.net) or to '*' to allow all origins.
cors_env = os.environ.get("CORS_ORIGINS", "")
if cors_env:
    if cors_env.strip() == "*":
        allow_origins = ["*"]
    else:
        allow_origins = [o.strip() for o in cors_env.split(",") if o.strip()]
else:
    # Development defaults
    allow_origins = [
        "http://localhost:3000",
        "http://127.0.0.1:3000",
        "http://0.0.0.0:3000",
    ]

app.add_middleware(
    CORSMiddleware,
    allow_origins=allow_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/auth/login")


def get_manufacturer_profile_id(user_id: int) -> int | None:
    """Get the manufacturer profile ID for a user."""
    db_interface = DBInterface()
    result = db_interface.execute_query(
        "SELECT id FROM manufacturers WHERE user_id = %s",
        (user_id,)
    )
    if result and len(result) > 0:
        return result[0][0]
    return None


def get_db() -> Generator[Session, None, None]:
    """
    General:
        Provide a SQLAlchemy database session for the duration of the request.

    Parameters:
        (none directly; used as a FastAPI dependency)

    Returns:
        A SQLAlchemy Session that is closed after the request completes.
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
    """
    General:
        Resolve the current authenticated user from the bearer token.

    Parameters:
        token:
            Bearer token injected by OAuth2PasswordBearer.
        db:
            Database session dependency used to load the user.

    Returns:
        The authenticated User instance.

    Raises:
        HTTPException: If the token is invalid or the user cannot be found.
    """
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
    General:
        Create a dependency that restricts access based on the user's role.

    Parameters:
        allowed_roles:
            List of allowed role values (e.g. ["admin", "consumer"]).

    Returns:
        A dependency function that returns the current user if allowed.

    Raises:
        HTTPException: If the user's role is not permitted.
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
    General:
        Hold in-memory domain objects (Consumers, Plants, Devices) and manage
        the background PlantThreadManager that runs plant care logic.
    """

    def __init__(self):
        self.thread_manager = PlantThreadManager(interval_seconds=300)
        self.consumers: Dict[int, Consumer] = {}
        self.manufacturers: Dict[int, Manufacturer] = {}
        self.logger = Logger(name="SystemState")
        self.initialized = False

    def load_from_db(self):
        """
        General:
            Load Consumers, Plants and Devices from the database and start
            background plant-care threads if not yet initialized.

        Parameters:
            (none)

        Returns:
            None. Populates internal maps and starts the thread manager.
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
            (
                plant_id,
                user_id,
                plant_type_id,
                plant_name,
                location,
                planting_date,
                is_healthy,
                health_status,
                notes,
                *_,
            ) = row

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
                req_moisture=optimal_moisture,
                health_status=health_status,
            )
            consumer.plants.append(plant)
            self.thread_manager.add_plant(plant)

        # --- Devices ---
        devices_rows = db.list_devices() or []
        for row in devices_rows:
            (
                device_id,
                user_id,
                plant_id,
                device_type_id,
                unique_identifier,
                device_name,
                is_active,
                last_data_received,
                last_heartbeat,
                location_description,
                battery_level,
                rssi,
                *_,
            ) = row

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
        """
        General:
            Get or create the in-memory Consumer domain object for a user.

        Parameters:
            user:
                User ORM object representing the consumer.

        Returns:
            Consumer domain object associated with the user.
        """
        consumer = self.consumers.get(user.id)
        if consumer is None:
            consumer = Consumer(user.id, user.username, user.email, self.thread_manager)
            self.consumers[user.id] = consumer
        return consumer

    def get_manufacturer(self, user: User) -> Manufacturer:
        """
        General:
            Get or create the in-memory Manufacturer domain object for a user.

        Parameters:
            user:
                User ORM object representing the manufacturer.

        Returns:
            Manufacturer domain object associated with the user.
        """
        manufacturer = self.manufacturers.get(user.id)
        if manufacturer is None:
            manufacturer = Manufacturer(user.id, user.username)
            self.manufacturers[user.id] = manufacturer
        return manufacturer
    
    def remove_user(self, user_id: int):
        """
        General:
            Remove a user and related in-memory domain objects from the system state.

        Parameters:
            user_id:
                Identifier of the user to remove.

        Returns:
            None. Any matching consumer/manufacturer is removed from caches and
            plants are detached from the thread manager.
        """
        # Remove consumer and its plants from the manager
        consumer = self.consumers.pop(user_id, None)
        if consumer:
            # Detach plants from the thread manager
            for plant in list(consumer.plants):
                self.thread_manager.remove_plant(plant)

        # Remove manufacturer, if present
        self.manufacturers.pop(user_id, None)

    def remove_manufacturer(self, manufacturer_id: int):
        """
        General:
            Remove a manufacturer from the in-memory system state.

        Parameters:
            manufacturer_id:
                Identifier of the manufacturer to remove.

        Returns:
            None. Any matching manufacturer is removed from the cache.
        """
        self.manufacturers.pop(manufacturer_id, None)


system_state = SystemState()


@app.get("/health")
async def health_check():
    """Lightweight health endpoint for container/platform probes."""
    return PlainTextResponse("healthy", status_code=200)

# ---------------------------------------------------------------------------
# 1. Authentication
# ---------------------------------------------------------------------------


@app.post("/api/auth/login", response_model=TokenResponse)
async def login(payload: LoginRequest, db: Session = Depends(get_db)):
    """
    General:
        Authenticate a user with email and password and issue a JWT access token.

    Parameters:
        payload:
            LoginRequest containing the user's email and password.
        db:
            Database session dependency used to look up the user.

    Returns:
        TokenResponse with an access token, token type, role and username.

    Raises:
        HTTPException: If the email or password is incorrect.
    """
    user = db.query(User).filter(User.email == payload.email).first()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password",
        )

    if not verify_password(payload.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password",
        )

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
    """
    General:
        Create a new user account (admin-only operation).

    Parameters:
        payload:
            UserDetails describing the new user, including role and password.
        current_user:
            Authenticated admin user performing the registration.
        db:
            Database session dependency used to create the user.

    Returns:
        A dictionary containing basic details of the newly created user.

    Raises:
        HTTPException: If a user with the same email or username already exists.
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
        role=payload.role,
        # password_hash field is treated as the plain password in the API layer.
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

    if new_user.role == "consumer":
        system_state.get_consumer(new_user)
    elif new_user.role == "manufacturer":
        # Create manufacturer profile in database
        company_name = payload.company_name or f"{new_user.username}'s Company"
        manufacturer_profile = ManufacturerModel(
            user_id=new_user.id,
            name=company_name,
            description="Manufacturer profile",
            contact_email=new_user.email,
            is_verified=False,
        )
        db.add(manufacturer_profile)
        db.commit()
        system_state.get_manufacturer(new_user)

    return {
        "id": new_user.id,
        "email": new_user.email,
        "username": new_user.username,
        "role": new_user.role,
    }


@app.post("/api/auth/register/consumer")
async def register_consumer(
    payload: ConsumerRegistration,
    db: Session = Depends(get_db),
):
    """
    General:
        Public registration endpoint for consumer users only.

    Parameters:
        payload:
            ConsumerRegistration with consumer registration data.
        db:
            Database session dependency used to create the user.

    Returns:
        A dictionary with basic details of the newly registered consumer.

    Raises:
        HTTPException: If a user with the same email or username already exists.
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
        password_hash=hash_password(payload.password),
        first_name=payload.first_name,
        last_name=payload.last_name,
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
    """
    General:
        Retrieve the profile and details of the current authenticated user.

    Parameters:
        current_user:
            Authenticated user whose profile is being requested.

    Returns:
        User details as returned by DBInterface.list_users for this user.
    """
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
    """
    General:
        Update the profile of the current authenticated user (excluding password).

    Parameters:
        payload:
            UserDetails with updated profile information.
        current_user:
            Authenticated user whose profile is being updated.
        db:
            Database session dependency used to persist changes.

    Returns:
        A dictionary with the updated user profile data.
    """
    current_user.email = payload.email
    current_user.username = payload.username
    current_user.first_name = payload.first_name
    current_user.last_name = payload.last_name
    current_user.phone_number = payload.phone_number

    if current_user.role == "admin":
        current_user.is_active = payload.is_active
        current_user.is_verified = payload.is_verified

    db.commit()
    db.refresh(current_user)

    # ---- keep runtime domain objects in sync ----
    if current_user.role == "consumer":
        consumer = system_state.get_consumer(current_user)
        consumer.username = current_user.username
        consumer.email = current_user.email
    elif current_user.role == "manufacturer":
        manufacturer = system_state.get_manufacturer(current_user)
        manufacturer.username = current_user.username

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
    """
    General:
        Change the password of the current authenticated user.

    Parameters:
        payload:
            PasswordChange containing the old and new passwords.
        current_user:
            Authenticated user whose password is being changed.
        db:
            Database session dependency used to persist the new password.

    Returns:
        A dictionary with a success message if the password was changed.

    Raises:
        HTTPException: If the old password is incorrect.
    """
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
    """
    General:
        Initiate a password reset flow by generating a reset token.

    Parameters:
        email:
            Email address of the account to reset the password for.
        db:
            Database session dependency used to locate the user.

    Returns:
        A dictionary with a generic detail message and, in development,
        a reset_token if the account exists.
    """
    user = db.query(User).filter(User.email == email).first()
    if not user:
        return {
            "detail": "If an account with this email exists, a reset link has been generated."
        }

    token_data = {"sub": str(user.id), "scope": "password_reset"}
    reset_token = create_access_token(token_data, expires_delta=timedelta(minutes=30))

    return {
        "detail": "Password reset token generated",
        "reset_token": reset_token,
    }


@app.post("/api/auth/reset-password")
async def reset_password(
    payload: ResetPasswordRequest,
    db: Session = Depends(get_db),
):
    """
    General:
        Reset a user's password using a previously issued reset token.

    Parameters:
        payload:
            ResetPasswordRequest containing the reset token and new password.
        db:
            Database session dependency used to update the user.

    Returns:
        A dictionary confirming that the password has been reset.

    Raises:
        HTTPException: If the token is invalid, expired, or the user cannot be found.
    """
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
    """
    General:
        Inspect the current in-memory system state and list all “alive” domain
        objects (Users, Consumers, Manufacturers, Plants, Devices).

        - Users are loaded from the database.
        - Consumers and Manufacturers are the in-memory domain objects stored in
          SystemState.
        - Plants and Devices are taken from the currently loaded Consumer
          domain objects and their attached Plant/Device instances.

    Parameters:
        current_admin:
            Authenticated admin user requesting system state information.

    Returns:
        A dictionary with:
            - users:       All user records from the database (serialized).
            - consumers:   All in-memory Consumer domain objects with their plants
                           and devices.
            - manufacturers: All in-memory Manufacturer domain objects.
            - plants:      All in-memory Plant domain objects (flattened list).
            - devices:     All in-memory Device domain objects (flattened and
                           de-duplicated by id).
    """
    db_interface = DBInterface()

    db_ok = False
    try:
        db_interface.execute_query("SELECT 1")
        db_ok = True
    except Exception:
        db_ok = False

    # --- Database-backed User instances ---
    user_rows = db_interface.list_users() or []
    users_data = [serialize_user(row) for row in user_rows]

    # --- Runtime Consumers & Manufacturers from SystemState ---
    consumers_runtime = [
        serialize_runtime_consumer(c)
        for c in system_state.consumers.values()
    ]
    manufacturers_runtime = [
        serialize_runtime_manufacturer(m)
        for m in system_state.manufacturers.values()
    ]

    # --- Flatten runtime Plants & Devices from all Consumers ---
    runtime_plants: list[dict] = []
    runtime_devices: list[dict] = []

    for consumer in system_state.consumers.values():
        for plant in getattr(consumer, "plants", []):
            plant_dict = serialize_runtime_plant(plant)
            runtime_plants.append(plant_dict)

            device_collection = getattr(plant, "devices", None)
            if device_collection is not None:
                for dev in getattr(device_collection, "devices", []):
                    runtime_devices.append(serialize_runtime_device(dev))

    # De-duplicate devices by id
    seen_device_ids = set()
    unique_runtime_devices = []
    for d in runtime_devices:
        did = d.get("id")
        if did is not None and did in seen_device_ids:
            continue
        if did is not None:
            seen_device_ids.add(did)
        unique_runtime_devices.append(d)

    # --- Database statistics ---
    db_plants = db_interface.list_plants() or []
    db_devices = db_interface.list_devices() or []
    db_device_types = db_interface.list_device_types() or []
    
    # Count users by role (role is at index 3, not 4 which is password_hash)
    consumers_count = sum(1 for u in user_rows if u[3] == 'consumer')
    manufacturers_count = sum(1 for u in user_rows if u[3] == 'manufacturer')
    admins_count = sum(1 for u in user_rows if u[3] == 'admin')
    
    # Get device types with supported_functions in "name:mode" format
    device_types_formatted = []
    for dt in db_device_types:
        dt_dict = serialize_device_type(dt)
        # Parse supported_functions from comma-separated to "name:mode" format
        supported_funcs = dt_dict.get('supported_functions', '') or ''
        funcs_list = [f.strip() for f in supported_funcs.split(',') if f.strip()]
        # Format as "function:read" or "function:write" based on device_type
        device_type_str = dt_dict.get('device_type', 'sensor')
        mode = 'read' if device_type_str == 'sensor' else 'write'
        formatted_funcs = ','.join([f"{f}:{mode}" for f in funcs_list])
        dt_dict['supported_functions_formatted'] = formatted_funcs
        device_types_formatted.append(dt_dict)

    return {
        "application": "ok",
        "database": "ok" if db_ok else "error",
        # Database statistics
        "stats": {
            "users_total": len(user_rows),
            "consumers_count": consumers_count,
            "manufacturers_count": manufacturers_count,
            "admins_count": admins_count,
            "plants_count": len(db_plants),
            "devices_count": len(db_devices),
            "device_types_count": len(db_device_types),
        },
        # Full data
        "users": users_data,
        "consumers": consumers_runtime,
        "manufacturers": manufacturers_runtime,
        "plants": runtime_plants,
        "devices": unique_runtime_devices,
        "device_types": device_types_formatted,
    }


@app.get("/api/admin/users")
async def list_admin_users(
    current_admin: User = Depends(require_roles(["admin"])),
):
    """
    General:
        List all registered users for administrative review and maintenance.

    Parameters:
        current_admin:
            Authenticated admin user requesting the listing.

    Returns:
        A list of users as returned by DBInterface.list_users.
    """
    db_interface = DBInterface()
    users = db_interface.list_users()
    return [serialize_user(u) for u in users] if users else []


@app.delete("/api/admin/users/{user_id}")
async def delete_user(
    user_id: int,
    current_admin: User = Depends(require_roles(["admin"])),
):
    """
    General:
        Delete a user account and remove related domain objects from system state.

    Parameters:
        user_id:
            Identifier of the user to delete.
        current_admin:
            Authenticated admin user performing the deletion.

    Returns:
        A dictionary with a detail message upon successful removal.

    Raises:
        HTTPException: If the user cannot be found.
    """
    db_interface = DBInterface()
    result = db_interface.remove_user(user_id)

    # If your DB helper returns something falsy when nothing was deleted:
    if not result:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found",
        )

    # Keep in-memory state in sync
    system_state.remove_user(user_id)

    return {"detail": "User removed"}


@app.patch("/api/admin/users/{user_id}")
async def update_user(
    user_id: int,
    payload: UserUpdate,
    current_admin: User = Depends(require_roles(["admin"])),
    db: Session = Depends(get_db),
):
    """
    General:
        Update user properties like role, is_active, or is_verified.
        Used by admins to approve manufacturers or deactivate users.

    Parameters:
        user_id:
            Identifier of the user to update.
        payload:
            UserUpdate schema with optional fields to update.
        current_admin:
            Authenticated admin user performing the update.
        db:
            Database session dependency.

    Returns:
        A dictionary with the updated user details.

    Raises:
        HTTPException: If the user cannot be found.
    """
    user = db.query(User).get(user_id)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found",
        )

    # Prevent admin from demoting themselves
    if user_id == current_admin.id and payload.role and payload.role != "admin":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cannot change your own admin role",
        )

    # Update only provided fields
    if payload.role is not None:
        user.role = payload.role
    if payload.is_active is not None:
        user.is_active = payload.is_active
    if payload.is_verified is not None:
        user.is_verified = payload.is_verified

    db.commit()
    db.refresh(user)

    return {
        "id": user.id,
        "email": user.email,
        "username": user.username,
        "role": user.role,
        "first_name": user.first_name,
        "last_name": user.last_name,
        "phone_number": user.phone_number,
        "is_active": user.is_active,
        "is_verified": user.is_verified,
        "created_at": user.created_at.isoformat() if user.created_at else None,
        "updated_at": user.updated_at.isoformat() if user.updated_at else None,
    }


@app.delete("/api/admin/manufacturers/{manufacturer_id}")
async def delete_manufacturer(
    manufacturer_id: int,
    current_admin: User = Depends(require_roles(["admin"])),
    db: Session = Depends(get_db),
):
    """
    General:
        Delete a manufacturer and remove it from system state.

    Parameters:
        manufacturer_id:
            Identifier of the manufacturer profile to delete.
        current_admin:
            Authenticated admin user performing the deletion.
        db:
            Database session dependency.

    Returns:
        A dictionary with a detail message upon successful removal.

    Raises:
        HTTPException: If the manufacturer cannot be found.
    """
    # Find manufacturer profile to get owning user_id
    manufacturer = db.query(ManufacturerModel).get(manufacturer_id)
    if not manufacturer:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Manufacturer not found",
        )

    owner_user_id = manufacturer.user_id

    # Delete manufacturer profile from DB
    db.delete(manufacturer)
    db.commit()

    # Keep in-memory state in sync: remove manufacturer domain object by user_id
    system_state.manufacturers.pop(owner_user_id, None)

    return {"detail": "Manufacturer removed"}



@app.get("/api/admin/devices")
async def list_all_devices_admin(
    current_admin: User = Depends(require_roles(["admin"])),
):
    """
    General:
        List all devices registered in the system for administrative oversight.

    Parameters:
        current_admin:
            Authenticated admin user requesting the listing.

    Returns:
        A list of devices as returned by DBInterface.list_devices.
    """
    db_interface = DBInterface()
    devices = db_interface.list_devices()
    return [serialize_device(d) for d in devices] if devices else []


@app.get("/api/admin/device_types")
async def list_all_device_types_admin(
    current_admin: User = Depends(require_roles(["admin"])),
):
    """
    General:
        List all device types defined in the system for administrative oversight.

    Parameters:
        current_admin:
            Authenticated admin user requesting the listing.

    Returns:
        A list of device types as returned by DBInterface.list_device_types.
    """
    db_interface = DBInterface()
    device_types = db_interface.list_device_types()
    return [serialize_device_type(dt) for dt in device_types] if device_types else []


@app.get("/api/admin/plants")
async def list_all_plants_admin(
    current_admin: User = Depends(require_roles(["admin"])),
):
    """
    General:
        List all plants registered in the system for administrative oversight.

    Parameters:
        current_admin:
            Authenticated admin user requesting the listing.

    Returns:
        A list of plants as returned by DBInterface.list_plants.
    """
    db_interface = DBInterface()
    plants = db_interface.list_plants()
    return [serialize_plant(p) for p in plants] if plants else []


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
    """
    General:
        Register a new device type with its capabilities and documentation.

    Parameters:
        payload:
            RegisterDevice describing the device type and its capabilities.
        current_manufacturer:
            Authenticated manufacturer or admin creating the device type.

    Returns:
        A dictionary with a detail message confirming registration.
    """
    manufacturer_domain = system_state.get_manufacturer(current_manufacturer)

    supported_functions_list = [
        s.strip() for s in payload.supported_functions.split(",") if s.strip()
    ]

    try:
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
    except Exception as e:
        error_msg = str(e)
        if "duplicate key" in error_msg or "unique" in error_msg.lower():
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Device type with name '{payload.name}' already exists",
            )
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to register device type: {error_msg}",
        )

    return {"detail": "Device type registered successfully"}


@app.get("/api/manufacturer/device-types")
async def list_device_types(
    current_manufacturer: User = Depends(
        require_roles(["manufacturer", "admin"])
    ),
):
    """
    General:
        List device types created by the current manufacturer.

    Parameters:
        current_manufacturer:
            Authenticated manufacturer or admin requesting the listing.

    Returns:
        A list of device types owned by the manufacturer.
    """
    db_interface = DBInterface()
    manufacturer_profile_id = get_manufacturer_profile_id(current_manufacturer.id)
    if manufacturer_profile_id is None:
        return []
    device_types = db_interface.list_device_types(manufacturer_profile_id)
    return [serialize_device_type(dt) for dt in device_types] if device_types else []


@app.put("/api/manufacturer/device-types/{device_type_id}")
async def update_device_type(
    device_type_id: int,
    payload: RegisterDevice,
    current_manufacturer: User = Depends(
        require_roles(["manufacturer", "admin"])
    ),
    db: Session = Depends(get_db),
):
    """
    General:
        Update documentation and properties for an existing device type.

    Parameters:
        device_type_id:
            Identifier of the device type to update.
        payload:
            RegisterDevice with updated device type data.
        current_manufacturer:
            Authenticated manufacturer or admin performing the update.
        db:
            Database session dependency used to persist changes.

    Returns:
        The updated DeviceType ORM instance.

    Raises:
        HTTPException: If the device type does not exist or the user lacks permission.
    """
    device_type = db.query(DeviceTypeModel).get(device_type_id)
    if not device_type:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Device type not found",
        )

    if (
        current_manufacturer.role != "admin"
        and device_type.manufacturer_id != get_manufacturer_profile_id(current_manufacturer.id)
    ):
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


@app.delete("/api/manufacturer/device-types/{device_type_id}")
async def delete_device_type(
    device_type_id: int,
    current_manufacturer: User = Depends(require_roles(["manufacturer", "admin"])),
    db: Session = Depends(get_db),
):
    """
    General:
        Remove a device type from the catalog.

    Parameters:
        device_type_id:
            ID of the device type to delete.
        current_manufacturer:
            Authenticated manufacturer or admin performing the deletion.
        db:
            Database session dependency.

    Returns:
        Success message.

    Raises:
        HTTPException: If the device type does not exist or the user lacks permission.
    """
    device_type = db.query(DeviceTypeModel).get(device_type_id)
    if not device_type:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Device type not found",
        )

    if (
        current_manufacturer.role != "admin"
        and device_type.manufacturer_id != get_manufacturer_profile_id(current_manufacturer.id)
    ):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not enough permissions",
        )

    db.delete(device_type)
    db.commit()
    return {"message": "Device type deleted successfully"}


# ---------------------------------------------------------------------------
# 4. Plants
# ---------------------------------------------------------------------------


@app.post("/api/plant-type")
async def add_new_plant_type(
    payload: NewPlantType,
    current_admin: User = Depends(require_roles(["admin"])),
):
    """
    General:
        Add a new plant species to the public catalog with its care requirements.

    Parameters:
        payload:
            NewPlantType defining the species name and required conditions.
        current_admin:
            Authenticated admin user creating the plant type.

    Returns:
        The result of DBInterface.register_new_plant_type for the new species.
    """
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
    """
    General:
        Modify the requirements and details for an existing plant species.

    Parameters:
        species_id:
            Identifier of the plant species to update.
        payload:
            NewPlantType with updated requirements and descriptions.
        current_admin:
            Authenticated admin user performing the update.
        db:
            Database session dependency used to persist changes.

    Returns:
        The updated PlantType ORM instance.

    Raises:
        HTTPException: If the plant type does not exist.
    """
    plant_type = db.query(PlantTypeModel).get(species_id)
    if not plant_type:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Plant type not found",
        )

    plant_type.name = payload.name
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
    """
    General:
        Remove a plant species from the public catalog.

    Parameters:
        species_id:
            Identifier of the plant species to remove.
        current_admin:
            Authenticated admin user performing the removal.

    Returns:
        A dictionary with a detail message upon successful removal.

    Raises:
        HTTPException: If the plant type cannot be found.
    """
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
    """
    General:
        List available plant types a consumer can choose from when adding plants.

    Parameters:
        current_user:
            Authenticated consumer or admin requesting the list.

    Returns:
        A list of plant types as returned by DBInterface.list_plant_types.
    """
    db_interface = DBInterface()
    plant_types = db_interface.list_plant_types()
    return [serialize_plant_type(pt) for pt in plant_types] if plant_types else []


@app.get("/api/consumer/plant-types/search")
async def search_plant_types(
    payload: PlantSearch,
    current_user: User = Depends(require_roles(["consumer", "admin"])),
):
    """
    General:
        Search for plant types by common name or scientific name.

    Parameters:
        payload:
            PlantSearch containing optional name or scientific_name to search.
        current_user:
            Authenticated consumer or admin performing the search.

    Returns:
        Plant type details if found, otherwise an informational string.
    """
    db_interface = DBInterface()
    if payload.scientific_name:
        plant_type = db_interface.get_plant_details_by_sci_name(
            payload.scientific_name
        )
        return serialize_plant_type_search(plant_type) if plant_type else None
    elif payload.name:
        plant_type = db_interface.get_plant_details_by_name(payload.name)
        return serialize_plant_type_search(plant_type) if plant_type else None
    else:
        return {"error": "No name or scientific name was given."}


@app.get("/api/consumer/my-plants")
async def list_user_plants(
    current_user: User = Depends(require_roles(["consumer", "admin"])),
):
    """
    General:
        List all plants registered to the current consumer.

    Parameters:
        current_user:
            Authenticated consumer or admin requesting their plant list.

    Returns:
        A list of plants for the user or a message if none are registered.
    """
    db_interface = DBInterface()
    plants = db_interface.list_plants(current_user.id)
    if plants:
        return [serialize_plant(p) for p in plants]
    else:
        return []


@app.post("/api/consumer/plant-from-scratch")
async def create_new_plant_from_scratch(
    payload: PlantTypeFromScratch,
    current_user: User = Depends(require_roles(["consumer", "admin"])),

):
    """
    General:
        Register a new plant and its plant_type manually with custom requirements.

    Parameters:
        payload:
            PlantTypeFromScratch defining requirements and initial plant details.
        current_user:
            Authenticated consumer or admin adding the plant.

    Returns:
        A dictionary with the generated plant_id for the new plant.
    """
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
    """
    General:
        Register a new plant by selecting a species from the existing catalog.

    Parameters:
        payload:
            PlantTypeFromDB with selected plant type and plant details.
        current_user:
            Authenticated consumer or admin adding the plant.

    Returns:
        A dictionary with the generated plant_id for the new plant.
    """
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
    """
    General:
        Retrieve details of a specific plant owned by the current user.

    Parameters:
        plant_id:
            Identifier of the plant to retrieve.
        current_user:
            Authenticated consumer or admin requesting the plant.

    Returns:
        Plant details if found, otherwise an informational string.
    """
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
    """
    General:
        Activate or deactivate automatic care for one or all of the user's plants.

    Parameters:
        payload:
            PlantActivation specifying plant_id (optional) and command flag.
        current_user:
            Authenticated consumer or admin toggling plant care.

    Returns:
        A dictionary with a detail message about the new care status.
    """
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
    """
    General:
        Update details of one of the current user's plants.

    Parameters:
        plant_id:
            Identifier of the plant to update.
        payload:
            PlantTypeFromDB containing updated plant fields (name, health, etc.).
        current_user:
            Authenticated consumer or admin performing the update.
        db:
            Database session dependency used to persist changes.

    Returns:
        A dictionary containing the updated plant data.

    Raises:
        HTTPException: If the plant does not exist or access is forbidden.
    """
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

    consumer = system_state.get_consumer(current_user)
    for p in consumer.plants:
        if p.id == plant_id:
            p.name = plant.plant_name
            if payload.health_status:
                try:
                    brightness, humidity, temperature, moisture = (
                        float(x) for x in payload.health_status.split(",")
                    )
                    p.act_brightness = int(brightness)
                    p.act_humidity = humidity
                    p.act_temperature = temperature
                    p.act_moisture = moisture
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
    """
    General:
        Remove one of the current user's plants from the system.

    Parameters:
        plant_id:
            Identifier of the plant to delete.
        current_user:
            Authenticated consumer or admin performing the deletion.

    Returns:
        A dictionary with a detail message upon successful removal.

    Raises:
        HTTPException: If the plant cannot be found.
    """
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
    """
    General:
        Register a purchased device to the user's account and attach it to a plant.

    Parameters:
        payload:
            DeviceCreation with device type, unique identifier, and plant mapping.
        current_user:
            Authenticated consumer or admin registering the device.

    Returns:
        A dictionary containing the unique_identifier and a detail message.
    """
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
    """
    General:
        List all device types that can be used in the system.

    Parameters:
        current_user:
            Authenticated user (consumer, manufacturer, or admin).

    Returns:
        A list of device types as returned by DBInterface.list_device_types.
    """
    db_interface = DBInterface()
    device_types = db_interface.list_device_types()
    return [serialize_device_type(dt) for dt in device_types] if device_types else []


@app.get("/api/consumer/my-devices")
async def list_my_devices(
    current_user: User = Depends(require_roles(["consumer", "admin"])),
):
    """
    General:
        List all devices owned by the current user.

    Parameters:
        current_user:
            Authenticated consumer or admin requesting the list.

    Returns:
        A list of devices or a message if none are registered.
    """
    db_interface = DBInterface()
    devices = db_interface.list_devices(current_user.id)
    if devices:
        return [serialize_device(d) for d in devices]
    else:
        return []


@app.post("/api/consumer/my-devices/activation")
async def device_activation(
    payload: DeviceActivation,
    current_user: User = Depends(require_roles(["consumer", "admin"])),
):
    """
    General:
        Activate or deactivate all or a specific device owned by the user.

    Parameters:
        payload:
            DeviceActivation specifying device_id (optional) and command flag.
        current_user:
            Authenticated consumer or admin toggling device activation.

    Returns:
        A dictionary with a detail message describing the new device state.
    """
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
    """
    General:
        Remove a device from the user's account and detach it from any plants.

    Parameters:
        device_id:
            Identifier of the device to remove.
        current_user:
            Authenticated consumer or admin performing the removal.

    Returns:
        A dictionary with a detail message upon successful removal.

    Raises:
        HTTPException: If the device cannot be found.
    """
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
    """
    General:
        Retrieve historical sensor data for a device for charting and analysis.

    Parameters:
        device_id:
            Identifier of the device to fetch history for.
        current_user:
            Authenticated consumer or admin requesting history.
        db:
            Database session dependency used to query sensor data.

    Returns:
        A list of measurement records including value, unit, timestamp, and anomaly flag.

    Raises:
        HTTPException: If the device does not exist or access is forbidden.
    """
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

@app.post("/api/device/receive-data")
async def receive_device_data(
    payload: DeviceData,
    db: Session = Depends(get_db),
):
    """
    General:
        Receive telemetry data from a device, store it in the database, update
        the device metadata and refresh the corresponding plant's live metrics
        and health_status (moisture now stored as a percentage).

    Parameters:
        payload:
            DeviceData containing:
                - device_id: ID of the device sending data.
                - data_type: Type of the metric (e.g. "temperature",
                  "humidity", "brightness", "moisture").
                - data: Measured value (for moisture this is a percentage).
                - data_unit: Unit of the measurement (e.g. "°C", "%", "lux").
        db:
            Database session dependency used to update device, plant and sensor
            data tables.

    Returns:
        A dictionary containing:
            - detail: Status message.
            - device_id: ID of the device that sent the data.
            - plant_id: ID of the plant affected (if any).
            - metric: Normalized metric name.
            - value: Stored measurement value.
            - unit: Measurement unit.
            - timestamp: ISO-format timestamp when data was recorded.
            - health_status: Updated health_status string of the plant
              (if applicable).

    Raises:
        HTTPException:
            - 404 if the device does not exist.
    """
    # ------------------------------------------------------------------
    # 1. Look up device
    # ------------------------------------------------------------------
    device = db.query(DeviceModel).get(payload.device_id)
    if not device:
        raise HTTPException(
            status_code=404,
            detail="Device not found",
        )

    # Normalize metric name
    metric_name = payload.data_type.lower()

    # ------------------------------------------------------------------
    # 2. Store raw measurement in sensor_data
    # ------------------------------------------------------------------
    now = datetime.utcnow()

    sensor_record = SensorDataModel(
        device_id=device.id,
        measurement_value=float(payload.data),
        measurement_unit=payload.data_unit,
        timestamp=now,
    )
    db.add(sensor_record)

    # ------------------------------------------------------------------
    # 3. Update device metadata
    # ------------------------------------------------------------------
    device.last_data_received = now
    device.last_heartbeat = now
    # (If later you extend DeviceData with battery/rssi, update them here.)

    # ------------------------------------------------------------------
    # 4. Update plant health_status in DB & live PlantDomain
    # ------------------------------------------------------------------
    plant = db.query(PlantModel).get(device.plant_id) if device.plant_id else None
    new_health_status = None

    # Mapping indices in health_status: brightness, humidity, temperature, moisture(%)
    metric_index = None
    if metric_name in ("brightness", "light", "illumination"):
        metric_index = 0
    elif metric_name in ("humidity", "air_humidity", "relative_humidity"):
        metric_index = 1
    elif metric_name in ("temperature", "temp"):
        metric_index = 2
    elif metric_name in ("moisture", "soil_moisture", "soil"):
        metric_index = 3

    if plant and metric_index is not None:
        # health_status is "brightness,humidity,temperature,moisture"
        parts = [0.0, 0.0, 0.0, 0.0]
        if plant.health_status:
            try:
                existing = [float(x) for x in str(plant.health_status).split(",")]
                for i in range(min(4, len(existing))):
                    parts[i] = existing[i]
            except Exception:
                # If parsing fails, keep default zeros
                pass

        parts[metric_index] = float(payload.data)
        new_health_status = ",".join(str(v) for v in parts)
        plant.health_status = new_health_status

        # ----- Sync live PlantDomain object in SystemState -----
        consumer = system_state.consumers.get(device.user_id)
        if consumer:
            for runtime_plant in consumer.plants:
                if runtime_plant.id == plant.id:
                    if metric_index == 0:
                        runtime_plant.act_brightness = float(payload.data)
                    elif metric_index == 1:
                        runtime_plant.act_humidity = float(payload.data)
                    elif metric_index == 2:
                        runtime_plant.act_temperature = float(payload.data)
                    elif metric_index == 3:
                        runtime_plant.act_moisture = float(payload.data)
                    break

    # ------------------------------------------------------------------
    # 5. Commit changes and return response
    # ------------------------------------------------------------------
    db.commit()
    db.refresh(device)
    if plant:
        db.refresh(plant)

    return {
        "detail": "Device data received",
        "device_id": device.id,
        "plant_id": plant.id if plant else None,
        "metric": metric_name,
        "value": float(payload.data),
        "unit": payload.data_unit,
        "timestamp": now.isoformat(),
        "health_status": new_health_status,
    }


@app.post("/api/consumer/devices/{device_id}/command")
async def send_device_command(
    device_id: int,
    payload: DeviceCommand,
    current_user: User = Depends(require_roles(["consumer", "admin"])),
    db: Session = Depends(get_db),
):
    """
    General:
        Send a manual control command to an actuator device (e.g. water now).

    Parameters:
        device_id:
            Identifier of the target device.
        payload:
            DeviceCommand specifying the metric and delta to apply.
        current_user:
            Authenticated consumer or admin issuing the command.
        db:
            Database session dependency used to verify ownership.

    Returns:
        A dictionary with a detail message confirming that the command was sent.

    Raises:
        HTTPException: If the device does not exist, is not attached, or metric is unsupported.
    """
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
    """
    General:
        Retrieve active alerts for a given user (e.g. low moisture, device failure).

    Parameters:
        user_id:
            Identifier of the user whose alerts are being retrieved.
        current_user:
            Authenticated consumer or admin requesting alerts.
        db:
            Database session dependency used to query alerts.

    Returns:
        A list of active alerts with status, message, values, and timestamps.

    Raises:
        HTTPException: If access is forbidden for the requested user_id.
    """
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
    """
    General:
        Mark a specific alert as acknowledged by the user.

    Parameters:
        alert_id:
            Identifier of the alert to acknowledge.
        current_user:
            Authenticated consumer or admin acknowledging the alert.
        db:
            Database session dependency used to update the alert.

    Returns:
        A dictionary with a detail message confirming acknowledgment.

    Raises:
        HTTPException: If the alert does not exist or access is forbidden.
    """
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
    """
    General:
        Mark a specific alert as resolved, optionally acknowledging it as well.

    Parameters:
        alert_id:
            Identifier of the alert to resolve.
        current_user:
            Authenticated consumer or admin resolving the alert.
        db:
            Database session dependency used to update the alert.

    Returns:
        A dictionary with a detail message confirming resolution.

    Raises:
        HTTPException: If the alert does not exist or access is forbidden.
    """
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
    General:
        Initialize the system state by loading domain objects from the database
        and starting background threads if needed.

    Parameters:
        (none)

    Returns:
        None. Any initialization errors are printed to the console.
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
