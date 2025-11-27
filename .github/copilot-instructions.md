# IoT Plant Monitoring System - AI Agent Guide

## Architecture Overview

This is a multi-component IoT plant monitoring system with **3 main subsystems**:

1. **ServerModule** - Python backend with PostgreSQL database and MQTT handling
2. **Hub** - Local MQTT broker + gateway service for device communication  
3. **flutter_app** - Flutter mobile frontend (demo/prototype with mock data)

**Data Flow**: IoT Devices → MQTT → Hub Gateway → Cloud/ServerModule ← Flutter App

## Key Development Patterns

### Database Architecture
- **ORM**: SQLAlchemy 2.0 with 10 normalized tables (Users, Devices, Plants, SensorData, etc.)
- **Interface**: Use `db.db_utils.DBInterface` class - supports both ORM and raw SQL
- **Location**: `ServerModule/app/src/db/` contains all models and utilities
- **Setup**: Always run `python db/scripts/db_manager.py init` before development

```python
# Standard database pattern
from db.db_utils import DBInterface
db = DBInterface()
session = db.get_session()
```

### MQTT Communication
- **Broker**: Mosquitto in Docker container (Hub/mosquitto/)
- **Gateway**: Python service that bridges MQTT ↔ Cloud (Hub/gateway/)
- **Topics**: Use pattern `home/sensors/+` and `home/actuators/+`
- **Startup**: `cd Hub && docker-compose up --build`

### Flutter Structure  
- **State Management**: Provider pattern (not implemented yet - screens are placeholders)
- **Models**: Dart classes mirror database schema exactly (see `flutter_app/lib/models/`)
- **Colors**: Use `AppColors` constants from `constants/app_colors.dart`
- **Current State**: Mock data only, no backend connection

## Environment Setup

### Python Backend
```bash
# Create Python 3.12.4 environment
conda create -n plant_server python==3.12.4
conda activate plant_server
pip install -r requirements.txt
pip install -r ServerModule/app/src/db/requirements.txt
```

### Database
```bash
# PostgreSQL setup (required)
createdb iot_plant_db
createuser iot_user
python ServerModule/app/src/db/scripts/db_manager.py init
```

### Docker Services
```bash
# Start PostgreSQL
docker-compose up postgres

# Start MQTT Hub 
cd Hub && docker-compose up --build
```

## Critical File Locations

- **Database Models**: `ServerModule/app/src/db/*_models.py`
- **DB Interface**: `ServerModule/app/src/db/db_utils.py` 
- **Gateway Logic**: `Hub/gateway/gateway.py`
- **Flutter Models**: `flutter_app/lib/models/`
- **Environment**: `.env` (copy from `.env.example`)

## Common Operations

### Database Operations
```python
# Get user's plants with devices
user_plants = session.query(Plant).filter_by(user_id=1).all()
for plant in user_plants:
    devices = plant.devices  # Uses PlantDeviceAssignment relationship
```

### MQTT Testing
```bash
# Test message sending
python Hub/test/send_test_message.py

# Mock cloud server
python Hub/test/mock_server.py
```

### Flutter Development
```bash
cd flutter_app
flutter pub get
flutter run  # Runs with mock data
```

## Database Schema Key Points

- **Cascade Rules**: User deletion cascades to all their data
- **Relationships**: Plants ↔ Devices is many-to-many via `PlantDeviceAssignment`
- **Enums**: Use `AlertSeverityEnum`, `AlertStatusEnum`, `DeviceTypeEnum` from `base.py`
- **Time-Series**: `SensorData` table optimized with composite index on `(device_id, timestamp)`

## Integration Boundaries

- **Hub ↔ ServerModule**: HTTP POST to cloud endpoints with JSON payloads
- **Flutter ↔ ServerModule**: Not implemented (planned REST API)
- **MQTT ↔ Hub**: Standard MQTT pub/sub on topics like `home/sensors/#`

## Project Status (Nov 2025)

- ✅ Database schema complete and tested
- ✅ Hub MQTT gateway functional  
- ✅ Flutter UI structure defined
- ⏳ ServerModule business logic (mostly stubs)
- ⏳ Flutter backend integration
- ⏳ Device simulator implementations

## Development Commands

```bash
# Database management
python db/scripts/db_manager.py init|seed|reset

# Testing 
python db/scripts/test_db_module.py
flutter test  # (in flutter_app/)

# Environment setup
./setup_env.sh
```

When working on this codebase, always check the comprehensive database docs at `ServerModule/app/src/db/documents/` for detailed API references.