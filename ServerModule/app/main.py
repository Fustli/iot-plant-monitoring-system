import uvicorn
from fastapi import HTTPException, status, FastAPI, Depends
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
from src.db.db_utils import get_session

load_dotenv()

app = FastAPI()
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
    current_user: User = Depends(
        require_roles(["admin"])
    ),
):
    """Registers a new user account."""
    pass

@app.post("/api/auth/register/consumer")
async def register_consumer(
    payload: UserDetails
):
    """
    Public registration for consumer users only.
    Manufacturers and admins must be created by existing admins.
    """
    pass


@app.get("/api/user/profile")
async def get_user_profile(
    current_user: User = Depends(
        require_roles(["admin", "consumer", "manufacturer"])
    ),
):
    """Returns current user details and preferences."""
    pass


@app.put("/api/user/profile")
async def update_user_profile(
    payload: UserDetails,
    current_user: User = Depends(
        require_roles(["admin", "consumer", "manufacturer"])
    ),
):
    """Updates user details or deletes the account."""
    pass

@app.post("/api/user/change-password")
async def change_password(
    payload: PasswordChange,
    current_user: User = Depends(
        require_roles(["admin", "consumer", "manufacturer"])
    ),
):
    """Change user password."""
    pass

@app.post("/api/auth/forgot-password")
async def forgot_password(
    email: str
):
    """Initiate password reset flow."""
    pass

@app.post("/api/auth/reset-password")
async def reset_password(
    token: str, 
    new_password: str
):
    """Reset password with token."""
    pass


# ---------------------------------------------------------------------------
# 2. Administrator (System Management)
# ---------------------------------------------------------------------------

@app.get("/api/admin/system/status")
async def get_system_status(
    current_admin: User = Depends(require_roles(["admin"])),
):
    """Monitors server health, resources, and database connection status."""
    pass


@app.get("/api/admin/users")
async def list_admin_users(
    current_admin: User = Depends(require_roles(["admin"])),
):
    """Lists all registered users for database maintenance."""
    pass


@app.delete("/api/admin/users/{user_id}")
async def delete_user(
    user_id: int,
    current_admin: User = Depends(require_roles(["admin"])),
):
    """Deletes a user account or bans a user."""
    pass


@app.get("/api/admin/devices")
async def list_all_devices_admin(
    current_admin: User = Depends(require_roles(["admin"])),
):
    """Lists all devices in the system for administrative oversight."""
    pass


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
    pass


@app.get("/api/manufacturer/device-types")
async def list_device_types(
    current_manufacturer: User = Depends(
        require_roles(["manufacturer", "admin"])
    ),
):
    """Lists device types created by this manufacturer."""
    pass


@app.put("/api/manufacturer/device-types/{device_type_id}")
async def update_device_type(
    device_type_id: int,
    payload: RegisterDevice,
    current_manufacturer: User = Depends(
        require_roles(["manufacturer", "admin"])
    ),
):
    """Updates documentation or function descriptions for a device type."""
    pass


# ---------------------------------------------------------------------------
# 4. Plants
# ---------------------------------------------------------------------------

@app.post("/api/plant-type")
async def add_new_plant_type(
    payload: NewPlantType,
    current_admin: User = Depends(require_roles(["admin"])),
):
    """Adds a new plant species to the public catalog with its requirements."""
    pass


@app.put("/api/plant-species/{species_id}")
async def update_plant_species(
    species_id: int,
    payload: NewPlantType,
    current_admin: User = Depends(require_roles(["admin"])),
):
    """Modifies requirements for an existing plant species."""
    pass


@app.delete("/api/plant-species/{species_id}")
async def delete_plant_species(
    species_id: int,
    current_admin: User = Depends(require_roles(["admin"])),
):
    """Removes a species from the catalog."""
    pass


@app.get("/api/consumer/plant-types")
async def list_plant_types(
    current_user: User = Depends(require_roles(["consumer", "admin"])),
):
    """Lists available plant types for the user to select from when adding a new plant."""
    pass


@app.get("/api/consumer/plant-types/search")
async def search_plant_types(
    payload: PlantSearch,
    current_user: User = Depends(require_roles(["consumer", "admin"])),
):
    """Search plant types by name or scientific name."""
    pass


@app.get("/api/consumer/my-plants")
async def list_user_plants(
    current_user: User = Depends(require_roles(["consumer", "admin"])),
):
    """Lists the user's registered plants with their status."""
    pass


@app.post("/api/consumer/plant-from-scratch")
async def create_new_plant_from_scratch(
    payload: PlantTypeFromScratch,
    current_user: User = Depends(require_roles(["consumer", "admin"])),
):
    """Registers a new plant and plant_type manually."""
    pass


@app.post("/api/consumer/plant-from-database")
async def create_new_plant_from_db(
    payload: PlantTypeFromDB,
    current_user: User = Depends(require_roles(["consumer", "admin"])),
):
    """Registers a new plant by selecting a species from the database."""
    pass


@app.get("/api/consumer/my-plants/{plant_id}")
async def get_my_plant(
    plant_id: int,
    current_user: User = Depends(require_roles(["consumer", "admin"])),
):
    """Gets details of a plant."""
    pass

@app.post("/api/consumer/my-plants/activation")
async def plant_activation(
    payload: PlantActivation,
    current_user: User = Depends(require_roles(["consumer", "admin"])),
):
    """Activates or deactivates plant care for all or one specific plant."""
    pass


@app.put("/api/consumer/my-plants/{plant_id}")
async def update_my_plant(
    plant_id: int,
    payload: PlantTypeFromDB,
    current_user: User = Depends(require_roles(["consumer", "admin"])),
):
    """Updates an existing plant's details."""
    pass


@app.delete("/api/consumer/my-plants/{plant_id}")
async def delete_my_plant(
    plant_id: int,
    current_user: User = Depends(require_roles(["consumer", "admin"])),
):
    """Removes an existing plant from the database and from the system."""
    pass


# ---------------------------------------------------------------------------
# 6. Devices
# ---------------------------------------------------------------------------

@app.post("/api/consumer/devices/register")
async def register_user_device(
    payload: DeviceCreation,
    current_user: User = Depends(require_roles(["consumer", "admin"])),
):
    """Registers a purchased device to the user's account using its Unique ID."""
    pass

@app.get("/api/consumer/device-types")
async def list_available_device_types(
    current_user: User = Depends(require_roles(["consumer", "admin", "manufacturer"])),
):
    """Lists device types."""
    pass


@app.get("/api/consumer/my-devices")
async def list_my_devices(
    current_user: User = Depends(require_roles(["consumer", "admin"])),
):
    """Lists all devices owned by the user."""
    pass


@app.post("/api/consumer/my-devices/activation")
async def plant_activation(
    payload: DeviceActivation,
    current_user: User = Depends(require_roles(["consumer", "admin"])),
):
    """Activates or deactivates all or one specific device."""
    pass


@app.delete("/api/consumer/my-devices/{device_id}")
async def remove_my_device(
    device_id: int,
    current_user: User = Depends(require_roles(["consumer", "admin"])),
):
    """Removes a device from the user's account."""
    pass


# ---------------------------------------------------------------------------
# 7. Monitoring & Control
# ---------------------------------------------------------------------------

@app.get("/api/consumer/devices/{device_id}/history")
async def get_device_history(
    device_id: int,
    current_user: User = Depends(require_roles(["consumer", "admin"])),
):
    """Retrieves historical sensor data (time-series) for charts."""
    pass


@app.post("/api/consumer/devices/{device_id}/command")
async def send_device_command(
    device_id: int,
    payload: DeviceCommand,
    current_user: User = Depends(require_roles(["consumer", "admin"])),
):
    """Sends a manual command to an actuator (e.g., 'Water Now')."""
    pass


@app.get("/api/consumer/alerts/{user_id}")
async def get_alerts(
    user_id: int,
    current_user: User = Depends(require_roles(["consumer", "admin"])),
):
    """Retrieves active system alerts (e.g., low moisture, device failure)."""
    pass


@app.put("/api/consumer/alerts/{alert_id}/acknowledge")
async def acknowledge_alert(
    current_user: User = Depends(require_roles(["consumer", "admin"])),
):
    """Mark alert as acknowledged."""
    pass


@app.put("/api/consumer/alerts/{alert_id}/resolve")
async def resolve_alert(
    current_user: User = Depends(require_roles(["consumer", "admin"])),
):
    pass
    """Mark alert as resolved."""


# ---------------------------------------------------------------------------
# Init function from original file
# ---------------------------------------------------------------------------

def init():
    # Lekéri az összes user-t és létrehozza őket
    # Lekéri az összes plantet és létrehozza őket és összekapcsolja őket a userekkel
    # Lekéri az összes device-t és létrehozza őket és összekapcsolja a növényekkel
    # aktiváljuk az összes device-t
    # aktiváljuk az összes plant-et
    pass


if __name__ == "__main__":
    uvicorn.run(app)
