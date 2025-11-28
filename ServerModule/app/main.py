from datetime import datetime, timedelta
from typing import Dict, Generator, List

import uvicorn
from dotenv import load_dotenv
from fastapi import Body, Depends, FastAPI, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import OAuth2PasswordBearer
from jose import JWTError
from sqlalchemy.orm import Session

from auth_jwt import create_access_token, decode_access_token
from schemas import (
    DeviceActivation,
    DeviceCommand,
    DeviceCreation,
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
)
from security import hash_password, verify_password
from src.db.alert_models import Alert as AlertModel
from src.db.base import AlertStatusEnum
from src.db.db_utils import DBInterface, get_session
from src.db.device_models import Device as DeviceModel, DeviceType as DeviceTypeModel
from src.db.plant_models import Plant as PlantModel, PlantType as PlantTypeModel
from src.db.sensor_models import SensorData as SensorDataModel
from src.db.user_models import User
from src.devices import create_device_from_type
from src.logger import Logger
from src.measurements import Moisture
from src.plants import Plant as PlantDomain
from src.thread_manager import PlantThreadManager
from src.users import Consumer, Manufacturer

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

    def _normalize_moisture(self, value: float) -> Moisture:
        """
        General:
            Convert a numeric moisture value from the database to a Moisture enum.

        Parameters:
            value:
                Numeric moisture value, typically 0–100.

        Returns:
            A Moisture enum corresponding to the given numeric value.
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
                req_moisture=self._normalize_moisture(optimal_moisture),
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


system_state = SystemState()

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
    General:
        Public registration endpoint for consumer users only.

    Parameters:
        payload:
            UserDetails with consumer registration data.
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
        Check system and database health status for administrative monitoring.

    Parameters:
        current_admin:
            Authenticated admin user requesting system status.

    Returns:
        A dictionary indicating application and database health.
    """
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
    return users


@app.delete("/api/admin/users/{user_id}")
async def delete_user(
    user_id: int,
    current_admin: User = Depends(require_roles(["admin"])),
):
    """
    General:
        Delete or ban a user account by its identifier.

    Parameters:
        user_id:
            Identifier of the user to remove.
        current_admin:
            Authenticated admin user performing the deletion.

    Returns:
        The result of DBInterface.remove_user for the given user_id.
    """
    db_interface = DBInterface()
    return db_interface.remove_user(user_id)


@app.delete("/api/admin/manufacturers/{manufacturer_id}")
async def delete_manufacturer(
    manufacturer_id: int,
    current_admin: User = Depends(require_roles(["admin"])),
):
    """
    General:
        Delete a manufacturer entry by its identifier.

    Parameters:
        manufacturer_id:
            Identifier of the manufacturer to remove.
        current_admin:
            Authenticated admin user performing the deletion.

    Returns:
        The result of DBInterface.remove_manufacturer for the given manufacturer_id.
    """
    db_interface = DBInterface()
    return db_interface.remove_manufacturer(manufacturer_id)


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
    return devices


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
    return device_types


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
        and device_type.manufacturer_id != current_manufacturer.id
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
    return plant_types


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
    return device_types


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
        return devices
    else:
        return f"User {current_user.username} has no devices registered."


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
