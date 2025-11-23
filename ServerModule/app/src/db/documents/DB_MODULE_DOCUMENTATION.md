````markdown
# IoT Plant Monitoring System - Database Module Documentation

## 📖 When to Use This Document

**Use this document when:**
- Setting up the database for the first time
- Need detailed field descriptions and constraints
- Understanding relationships and cascade rules
- Writing complex queries or advanced operations
- Troubleshooting database-related issues
- Reviewing the complete DBInterface API

**What this contains:**
- Complete overview and architecture
- All 10 database tables with full field documentation
- Enumerations and their values
- All relationships with cascade behavior
- Usage guide with 15+ practical code examples
- Environment configuration
- Complete API reference for DBInterface class
- Performance optimization tips
- Common patterns and best practices
- Troubleshooting guide
- Index strategy explanation

**Not in this document:**
- Quick syntax reference (see DB_QUICK_REFERENCE.md)
- Visual diagrams (see DB_SCHEMA_VISUALIZATION.md)
- Navigation guide (see DATABASE_DOCS_INDEX.md)

---

## Table of Contents
1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Data Models](#data-models)
4. [Enumerations](#enumerations)
5. [Relationships & Cascades](#relationships--cascades)
6. [Usage Guide](#usage-guide)
7. [Environment Configuration](#environment-configuration)
8. [API Reference](#api-reference)

---

## Overview

The database module provides a robust, scalable PostgreSQL-based persistence layer for the IoT Plant Monitoring System. It uses **SQLAlchemy 2.0** as the ORM (Object-Relational Mapping) framework and supports both ORM-based and raw SQL operations through psycopg2.

**Key Features:**
- ✅ 10+ normalized database tables
- ✅ Comprehensive relationships with cascading deletes
- ✅ Connection pooling for production use
- ✅ Support for both ORM (SQLAlchemy) and raw SQL (psycopg2)
- ✅ Automatic timestamp tracking (created_at, updated_at)
- ✅ Indexed queries for optimal performance
- ✅ Environment-based configuration

---

## Architecture

### File Structure
```
db/
├── base.py              # Base class and enumerations
├── user_models.py       # User entity
├── device_models.py     # Device, Manufacturer, DeviceType entities
├── plant_models.py      # Plant, PlantType, PlantDeviceAssignment entities
├── sensor_models.py     # SensorData (time-series) entity
├── alert_models.py      # AlertRule and Alert entities
├── db_utils.py          # DBInterface for connection management
├── __init__.py          # Package exports
└── scripts/
    ├── db_manager.py    # CLI for database management (init, seed, reset)
    ├── examples.py      # Usage examples
    └── test_db_module.py # Unit tests
```

### Database Connection Flow
```
Environment Variables (.env)
         ↓
   DBInterface
         ↓
   ┌─────┴─────┐
   ↓           ↓
SQLAlchemy  psycopg2
  (ORM)      (Raw SQL)
   ↓           ↓
PostgreSQL Database
```

---

## Data Models

### 1. User Model
**Table:** `users`  
**Purpose:** Stores user account information and authentication data

| Field | Type | Constraints | Description |
|-------|------|-----------|-------------|
| `id` | Integer | PK, AutoInc | Unique user identifier |
| `email` | String(255) | UNIQUE, NOT NULL, INDEX | User's email address (login credential) |
| `username` | String(100) | UNIQUE, NOT NULL, INDEX | Display name (login credential) |
| `password_hash` | String(255) | NOT NULL | Bcrypt-hashed password (never store plain text) |
| `first_name` | String(100) | - | User's first name |
| `last_name` | String(100) | - | User's last name |
| `phone_number` | String(20) | - | Contact phone number |
| `is_active` | Boolean | NOT NULL, Default=True, INDEX | Account status (disabled accounts can't login) |
| `is_verified` | Boolean | NOT NULL, Default=False | Email verification status |
| `created_at` | DateTime | NOT NULL, DEFAULT=NOW() | Account creation timestamp |
| `updated_at` | DateTime | NOT NULL, DEFAULT=NOW() | Last profile update timestamp |
| `last_login` | DateTime | - | Last login time for analytics |

**Indexes:** email, username, is_active (for active user filtering)

**Example:**
```python
user = User(
    email='john@example.com',
    username='john_doe',
    password_hash='$2b$12$...',
    first_name='John',
    last_name='Doe',
    is_verified=True
)
session.add(user)
```

---

### 2. Manufacturer Model
**Table:** `manufacturers`  
**Purpose:** Catalog of IoT device manufacturers

| Field | Type | Constraints | Description |
|-------|------|-----------|-------------|
| `id` | Integer | PK, AutoInc | Unique manufacturer ID |
| `name` | String(255) | UNIQUE, NOT NULL, INDEX | Manufacturer name (e.g., "Xiaomi", "Sonoff") |
| `description` | Text | - | Company description or product overview |
| `contact_email` | String(255) | - | Support email address |
| `website` | String(255) | - | Company website URL |
| `is_verified` | Boolean | NOT NULL, Default=False | Verification status |
| `created_at` | DateTime | NOT NULL, DEFAULT=NOW() | Registration timestamp |
| `updated_at` | DateTime | NOT NULL, DEFAULT=NOW() | Last update timestamp |

**Example:**
```python
manufacturer = Manufacturer(
    name='Xiaomi',
    description='Xiaomi smart home solutions',
    contact_email='support@xiaomi.com',
    website='https://www.xiaomi.com',
    is_verified=True
)
```

---

### 3. DeviceType Model
**Table:** `device_types`  
**Purpose:** Catalog of device models and their specifications

| Field | Type | Constraints | Description |
|-------|------|-----------|-------------|
| `id` | Integer | PK, AutoInc | Unique device type ID |
| `manufacturer_id` | Integer | FK→manufacturers, NOT NULL, CASCADE | Reference to manufacturer |
| `name` | String(255) | NOT NULL | Device model name (e.g., "Smart Thermometer") |
| `device_type` | Enum | NOT NULL | Type: SENSOR, ACTUATOR, or COMBINED |
| `description` | Text | - | Device capabilities and features |
| `communication_interface` | String(100) | - | Protocol: MQTT, WiFi, Zigbee, etc. |
| `supported_functions` | Text | - | Comma-separated capabilities (e.g., "read_temp, read_humidity") |
| `data_unit` | String(50) | - | Measurement unit (e.g., "°C", "%", "lux") |
| `min_value` | Float | - | Minimum sensor/actuator value |
| `max_value` | Float | - | Maximum sensor/actuator value |
| `is_active` | Boolean | NOT NULL, Default=True, INDEX | Availability for registration |
| `created_at` | DateTime | NOT NULL, DEFAULT=NOW() | Registration timestamp |
| `updated_at` | DateTime | NOT NULL, DEFAULT=NOW() | Last update timestamp |

**Unique Constraint:** (manufacturer_id, name) - Each manufacturer can't have duplicate device types

**Example:**
```python
device_type = DeviceType(
    manufacturer_id=1,
    name='Smart Thermometer',
    device_type=DeviceTypeEnum.SENSOR,
    communication_interface='MQTT',
    supported_functions='read_temperature',
    data_unit='°C',
    min_value=-20.0,
    max_value=60.0
)
```

---

### 4. Device Model
**Table:** `devices`  
**Purpose:** Individual IoT devices owned and registered by users

| Field | Type | Constraints | Description |
|-------|------|-----------|-------------|
| `id` | Integer | PK, AutoInc | Unique device instance ID |
| `user_id` | Integer | FK→users, NOT NULL, CASCADE | Owner of the device |
| `device_type_id` | Integer | FK→device_types, NOT NULL, RESTRICT | Reference to device model |
| `unique_identifier` | String(255) | UNIQUE, NOT NULL, INDEX | MAC address, UUID, or serial number |
| `device_name` | String(255) | NOT NULL | User-friendly display name |
| `is_active` | Boolean | NOT NULL, Default=True, INDEX | Device operational status |
| `last_data_received` | DateTime | - | Timestamp of last successful data transmission |
| `last_heartbeat` | DateTime | - | Timestamp of last device ping/connectivity check |
| `location_description` | String(255) | - | Physical location (e.g., "Living room shelf") |
| `battery_level` | Float | - | Battery percentage (0-100) for wireless devices |
| `rssi` | Integer | - | Signal strength (dBm) for WiFi/wireless devices |
| `created_at` | DateTime | NOT NULL, DEFAULT=NOW() | Device registration timestamp |
| `updated_at` | DateTime | NOT NULL, DEFAULT=NOW() | Last device update timestamp |

**Indexes:** user_id, unique_identifier, is_active, device_type_id

**Example:**
```python
device = Device(
    user_id=1,
    device_type_id=3,
    unique_identifier='xiaomi_temp_001',
    device_name='Living Room Thermometer',
    location_description='Shelf above TV',
    battery_level=95,
    rssi=-45
)
```

---

### 5. PlantType Model
**Table:** `plant_types`  
**Purpose:** Catalog of plant species with care requirements

| Field | Type | Constraints | Description |
|-------|------|-----------|-------------|
| `id` | Integer | PK, AutoInc | Unique plant species ID |
| `name` | String(255) | UNIQUE, NOT NULL, INDEX | Common plant name (e.g., "Monstera") |
| `scientific_name` | String(255) | - | Botanical scientific name |
| `description` | Text | - | Plant characteristics and appearance |
| `optimal_temperature` | Float | - | Ideal temperature in °C |
| `optimal_humidity` | Float | - | Ideal humidity percentage (0-100) |
| `optimal_light` | Float | - | Ideal light level in lux |
| `water_frequency_days` | Integer | - | Recommended watering interval in days |
| `care_instructions` | Text | - | General care guidelines |
| `created_at` | DateTime | NOT NULL, DEFAULT=NOW() | Entry creation timestamp |
| `updated_at` | DateTime | NOT NULL, DEFAULT=NOW() | Last update timestamp |

**Example:**
```python
plant_type = PlantType(
    name='Monstera Deliciosa',
    scientific_name='Monstera deliciosa',
    description='Climbing plant with fenestrated leaves',
    optimal_temperature=22.5,
    optimal_humidity=72.5,
    optimal_light=1000,
    water_frequency_days=7,
    care_instructions='Keep soil moist, provide bright indirect light'
)
```

---

### 6. Plant Model
**Table:** `plants`  
**Purpose:** Individual user plants tracked in the system

| Field | Type | Constraints | Description |
|-------|------|-----------|-------------|
| `id` | Integer | PK, AutoInc | Unique plant instance ID |
| `user_id` | Integer | FK→users, NOT NULL, CASCADE | Plant owner |
| `plant_type_id` | Integer | FK→plant_types, NOT NULL, RESTRICT | Reference to plant species |
| `plant_name` | String(255) | NOT NULL | User's custom name for the plant |
| `location` | String(255) | - | Physical location in home |
| `planting_date` | DateTime | - | When the plant was planted/acquired |
| `last_watered` | DateTime | - | Last manual watering timestamp |
| `is_healthy` | Boolean | NOT NULL, Default=True, INDEX | Health status (updated by alerts) |
| `health_status` | String(50) | - | Status description (e.g., "Excellent", "Wilting") |
| `notes` | Text | - | User notes and observations |
| `created_at` | DateTime | NOT NULL, DEFAULT=NOW() | Plant registration timestamp |
| `updated_at` | DateTime | NOT NULL, DEFAULT=NOW() | Last update timestamp |

**Indexes:** user_id, plant_type_id, is_healthy (for filtering unhealthy plants)

**Example:**
```python
plant = Plant(
    user_id=1,
    plant_type_id=5,
    plant_name='Big Monstera',
    location='Living room corner',
    planting_date=datetime(2023, 1, 15),
    notes='Recently repotted, looks healthy'
)
```

---

### 7. PlantDeviceAssignment Model
**Table:** `plant_device_assignments`  
**Purpose:** Maps which devices monitor which plants (many-to-many relationship)

| Field | Type | Constraints | Description |
|-------|------|-----------|-------------|
| `id` | Integer | PK, AutoInc | Unique assignment ID |
| `plant_id` | Integer | FK→plants, NOT NULL, CASCADE | Reference to plant |
| `device_id` | Integer | FK→devices, NOT NULL, CASCADE | Reference to device |
| `assignment_type` | String(100) | NOT NULL | Role: "soil_moisture", "temperature", "humidity", "light", "pump" |
| `is_active` | Boolean | NOT NULL, Default=True, INDEX | Assignment status |
| `created_at` | DateTime | NOT NULL, DEFAULT=NOW() | Assignment date |
| `updated_at` | DateTime | NOT NULL, DEFAULT=NOW() | Last update |

**Unique Constraint:** (plant_id, device_id) - Each device can only be assigned once per plant

**Example:**
```python
# Assign temperature sensor to Monstera
assignment = PlantDeviceAssignment(
    plant_id=1,
    device_id=3,
    assignment_type='temperature'
)
```

---

### 8. SensorData Model
**Table:** `sensor_data`  
**Purpose:** Time-series storage of device measurements (largest table, optimized for queries)

| Field | Type | Constraints | Description |
|-------|------|-----------|-------------|
| `id` | Integer | PK, AutoInc | Unique measurement ID |
| `device_id` | Integer | FK→devices, NOT NULL, CASCADE | Source device |
| `measurement_value` | Float | NOT NULL | Numeric sensor reading |
| `measurement_unit` | String(50) | - | Unit of measurement (°C, %, lux, etc.) |
| `data_quality` | Integer | NOT NULL, Default=100 | Quality score (0-100, 100=perfect) |
| `is_anomaly` | Boolean | NOT NULL, Default=False, INDEX | Flag for anomalous readings |
| `timestamp` | DateTime | NOT NULL, INDEX | Measurement time (can differ from received_at) |
| `raw_data` | Text | - | Raw sensor output for debugging |

**Indexes:** device_id, timestamp, (device_id, timestamp), is_anomaly  
**Note:** These composite and single-field indexes enable efficient time-range queries like "get last 24 hours of temperature data"

**Example:**
```python
sensor_reading = SensorData(
    device_id=3,
    measurement_value=22.5,
    measurement_unit='°C',
    timestamp=datetime.utcnow(),
    data_quality=100,
    is_anomaly=False
)
```

---

### 9. AlertRule Model
**Table:** `alert_rules`  
**Purpose:** User-defined conditions that trigger alerts

| Field | Type | Constraints | Description |
|-------|------|-----------|-------------|
| `id` | Integer | PK, AutoInc | Unique rule ID |
| `user_id` | Integer | FK→users, NOT NULL, CASCADE | Rule owner |
| `plant_id` | Integer | FK→plants, NOT NULL, CASCADE | Plant being monitored |
| `rule_name` | String(255) | NOT NULL | User-friendly rule name |
| `rule_type` | String(100) | NOT NULL | Type: "threshold", "range", "deviation" |
| `parameter_name` | String(100) | NOT NULL | What to monitor: "temperature", "humidity", "soil_moisture" |
| `condition_operator` | String(20) | NOT NULL | Operator: "<", ">", "==", "!=" |
| `threshold_value` | Float | NOT NULL | Trigger threshold (e.g., 25 for "temp < 25") |
| `severity` | Enum | NOT NULL, Default=WARNING | INFO, WARNING, or CRITICAL |
| `is_active` | Boolean | NOT NULL, Default=True, INDEX | Enable/disable rule without deleting |
| `created_at` | DateTime | NOT NULL, DEFAULT=NOW() | Rule creation timestamp |
| `updated_at` | DateTime | NOT NULL, DEFAULT=NOW() | Last modification |

**Indexes:** user_id, plant_id, is_active

**Example:**
```python
# Alert if soil moisture drops below 25%
rule = AlertRule(
    user_id=1,
    plant_id=1,
    rule_name='Low Soil Moisture',
    rule_type='threshold',
    parameter_name='soil_moisture',
    condition_operator='<',
    threshold_value=25,
    severity=AlertSeverityEnum.WARNING
)
```

---

### 10. Alert Model
**Table:** `alerts`  
**Purpose:** Alert instances triggered when rules are violated (audit trail)

| Field | Type | Constraints | Description |
|-------|------|-----------|-------------|
| `id` | Integer | PK, AutoInc | Unique alert instance ID |
| `user_id` | Integer | FK→users, NOT NULL, CASCADE | Alert recipient |
| `plant_id` | Integer | FK→plants, NOT NULL, CASCADE | Affected plant |
| `rule_id` | Integer | FK→alert_rules, NOT NULL, CASCADE | Triggered rule |
| `severity` | Enum | NOT NULL | INFO, WARNING, or CRITICAL |
| `status` | Enum | NOT NULL, Default=ACTIVE, INDEX | ACTIVE, ACKNOWLEDGED, or RESOLVED |
| `message` | Text | NOT NULL | Human-readable alert message |
| `triggered_value` | Float | - | The actual sensor value that triggered the alert |
| `threshold_value` | Float | - | The threshold that was exceeded |
| `triggered_at` | DateTime | NOT NULL, INDEX | When the condition was detected |
| `acknowledged_at` | DateTime | - | When user acknowledged the alert |
| `resolved_at` | DateTime | - | When the issue was resolved |
| `created_at` | DateTime | NOT NULL, DEFAULT=NOW() | Alert creation timestamp |
| `updated_at` | DateTime | NOT NULL, DEFAULT=NOW() | Last status update |

**Indexes:** user_id, plant_id, rule_id, status (for filtering active alerts), triggered_at (for sorting)

**Alert Lifecycle:**
1. ACTIVE → Alert just triggered, user hasn't seen it
2. ACKNOWLEDGED → User saw the alert and confirmed receipt
3. RESOLVED → Condition is fixed or alert manually closed

**Example:**
```python
alert = Alert(
    user_id=1,
    plant_id=1,
    rule_id=5,
    severity=AlertSeverityEnum.WARNING,
    status=AlertStatusEnum.ACTIVE,
    message='Soil moisture dropped to 18% (threshold: 25%)',
    triggered_value=18,
    threshold_value=25,
    triggered_at=datetime.utcnow()
)
```

---

## Enumerations

Enumerations provide type safety and standardization for common fields:

### DeviceTypeEnum
```python
class DeviceTypeEnum(Enum):
    SENSOR = "sensor"        # Measures environment (temperature, humidity, etc.)
    ACTUATOR = "actuator"    # Controls things (pump, light, heater, etc.)
    COMBINED = "combined"    # Both sensor + actuator (smart thermostat)
```

### AlertSeverityEnum
```python
class AlertSeverityEnum(Enum):
    INFO = "info"           # Informational (2.5L water added)
    WARNING = "warning"     # Should take action (soil moisture at 30%)
    CRITICAL = "critical"   # Urgent action needed (soil moisture at 10%)
```

### AlertStatusEnum
```python
class AlertStatusEnum(Enum):
    ACTIVE = "active"              # Alert is unresolved
    ACKNOWLEDGED = "acknowledged"  # User saw it but condition persists
    RESOLVED = "resolved"          # Condition fixed or dismissed
```

---

## Relationships & Cascades

### Cascade Rules
- **`cascade='all, delete-orphan'`**: If parent is deleted, delete children automatically
  - User → Devices, Plants, AlertRules, Alerts (orphaned when user deleted)
  
- **`ondelete='CASCADE'`**: Database-level cascade (fast, enforced at DB)
  - User deletion cascades to owned devices/plants
  
- **`ondelete='RESTRICT'`**: Prevent deletion if children exist (maintains referential integrity)
  - Can't delete PlantType if plants reference it
  - Can't delete DeviceType if devices reference it

### Relationship Graph
```
User (1)
├── ├─→ Devices (many) ─CASCADE
│   │   ├─→ SensorData (many) ─CASCADE
│   │   └─→ PlantDeviceAssignment (many) ─CASCADE
│   │
│   ├─→ Plants (many) ─CASCADE
│   │   ├─→ PlantType (1) ─RESTRICT
│   │   ├─→ PlantDeviceAssignment (many) ─CASCADE
│   │   ├─→ AlertRules (many) ─CASCADE
│   │   └─→ Alerts (many) ─CASCADE
│   │
│   ├─→ AlertRules (many) ─CASCADE
│   │   └─→ Alert (many) ─CASCADE
│   │
│   └─→ Alerts (many) ─CASCADE

Device (1)
├─→ DeviceType (1) ─RESTRICT
│   └─→ Manufacturer (1) ─CASCADE
└─→ SensorData (many) ─CASCADE
```

---

## Usage Guide

### Setup & Initialization

#### 1. Environment Configuration
Create `.env` file in project root:
```bash
POSTGRES_DB_HOST=localhost
POSTGRES_DB_PORT=5432
POSTGRES_DB_USER=iot_user
POSTGRES_DB_PASSWORD=iot_password
POSTGRES_DB_NAME=iot_plant_db
```

#### 2. Initialize Database
```bash
python db/scripts/db_manager.py init
```

#### 3. Seed Demo Data
```bash
python db/scripts/db_manager.py seed
```

### Basic ORM Operations

#### Creating Records
```python
from db.db_utils import DBInterface

db = DBInterface()
session = db.get_session()

# Create a user
new_user = User(
    email='alice@example.com',
    username='alice',
    password_hash='hashed_password_here',
    first_name='Alice'
)
session.add(new_user)
session.commit()
print(f"User created with ID: {new_user.id}")
```

#### Querying Records
```python
# Get a single user by email
user = session.query(User).filter_by(email='alice@example.com').first()

# Get all active users
active_users = session.query(User).filter(User.is_active == True).all()

# Get user's plants
user_plants = session.query(Plant).filter_by(user_id=user.id).all()
for plant in user_plants:
    print(f"{plant.plant_name}: {plant.plant_type.name}")
```

#### Updating Records
```python
# Update plant health status
plant = session.query(Plant).get(1)
plant.is_healthy = False
plant.health_status = "Wilting"
session.commit()
```

#### Deleting Records
```python
# Delete a device (cascades to sensor data and assignments)
device = session.query(Device).get(1)
session.delete(device)
session.commit()
```

### Advanced Queries

#### Time-Series Sensor Data
```python
from datetime import datetime, timedelta

# Get last 24 hours of temperature readings for a device
now = datetime.utcnow()
last_24h = now - timedelta(hours=24)

readings = session.query(SensorData).filter(
    SensorData.device_id == 3,
    SensorData.timestamp >= last_24h
).order_by(SensorData.timestamp.desc()).all()

for reading in readings:
    print(f"{reading.timestamp}: {reading.measurement_value}{reading.measurement_unit}")
```

#### Alert Analysis
```python
# Get all unresolved critical alerts for a user
critical_alerts = session.query(Alert).filter(
    Alert.user_id == 1,
    Alert.severity == AlertSeverityEnum.CRITICAL,
    Alert.status != AlertStatusEnum.RESOLVED
).all()

# Acknowledge all alerts for a plant
from datetime import datetime
plant_alerts = session.query(Alert).filter_by(plant_id=1).all()
for alert in plant_alerts:
    alert.status = AlertStatusEnum.ACKNOWLEDGED
    alert.acknowledged_at = datetime.utcnow()
session.commit()
```

#### Join Queries
```python
# Get all plants of a specific species for all users
monstera_plants = session.query(Plant).join(PlantType).filter(
    PlantType.name == 'Monstera Deliciosa'
).all()

# Get all active devices for a user with their latest sensor data
devices_with_data = session.query(Device, SensorData).filter(
    Device.user_id == 1,
    Device.is_active == True
).outerjoin(SensorData).all()
```

### Raw SQL Operations (psycopg2)

```python
# Get top 5 plants with most sensor anomalies
with db.connect_to_db() as (cur, conn):
    cur.execute("""
        SELECT p.plant_name, COUNT(sd.id) as anomaly_count
        FROM plants p
        JOIN plant_device_assignments pda ON p.id = pda.plant_id
        JOIN sensor_data sd ON pda.device_id = sd.device_id
        WHERE sd.is_anomaly = true
        GROUP BY p.id, p.plant_name
        ORDER BY anomaly_count DESC
        LIMIT 5
    """)
    
    results = cur.fetchall()
    for plant_name, count in results:
        print(f"{plant_name}: {count} anomalies")
```

---

## Environment Configuration

### Configuration Variables
All database connection parameters are read from environment variables (via `.env`):

| Variable | Default | Description |
|----------|---------|-------------|
| `POSTGRES_DB_HOST` | localhost | PostgreSQL server hostname |
| `POSTGRES_DB_PORT` | 5432 | PostgreSQL server port |
| `POSTGRES_DB_USER` | iot_user | Database username |
| `POSTGRES_DB_PASSWORD` | iot_password | Database password |
| `POSTGRES_DB_NAME` | iot_plant_db | Database name |

### Why Environment Variables?
- ✅ Security: Credentials never hardcoded in source
- ✅ Flexibility: Different configs for dev/test/production
- ✅ CI/CD Integration: Easy to inject secrets in deployment pipelines
- ✅ Deployment: Can change without code changes

### Example `.env` for Production
```bash
# Production database on AWS RDS
POSTGRES_DB_HOST=iot-db.us-east-1.rds.amazonaws.com
POSTGRES_DB_PORT=5432
POSTGRES_DB_USER=prod_user
POSTGRES_DB_PASSWORD=very_secure_password_123
POSTGRES_DB_NAME=iot_plant_prod
```

---

## API Reference

### DBInterface Class

#### Constructor
```python
db = DBInterface()
```
Reads environment variables and initializes connection pool (lazy-loaded).

#### Properties

##### `engine`
```python
engine = db.engine  # SQLAlchemy engine with connection pooling
```
- Lazy-loads on first access
- Connection pool: 10 base connections, 20 overflow
- Pre-ping enabled: validates connections before use
- Recycles connections after 1 hour

##### `session_factory`
```python
session_factory = db.session_factory  # SQLAlchemy SessionFactory
```
- Bound to the engine
- Use `get_session()` instead of calling directly

#### Methods

##### `get_session()`
```python
session = db.get_session()  # Returns new SQLAlchemy Session
try:
    # Use session for queries
    user = session.query(User).get(1)
finally:
    session.close()
```
- Creates new session bound to engine
- **Always close when done** or use context manager

##### `init_db()`
```python
success = db.init_db()  # Returns bool
```
- Creates all tables based on SQLAlchemy models
- Safe to call multiple times (creates only missing tables)
- Returns True on success, False on error

##### `drop_all_tables()`
```python
success = db.drop_all_tables()  # Returns bool
```
- **CAUTION:** Deletes all tables and data
- Only use in dev/test environments
- Returns True on success, False on error

##### `connect_to_db()` (Context Manager)
```python
with db.connect_to_db() as (cursor, connection):
    cursor.execute("SELECT * FROM users WHERE id = %s", (1,))
    result = cursor.fetchone()
    # Auto-commits on success, rolls back on exception
```
- Raw psycopg2 connection for performance-critical queries
- Auto-commits changes when exiting normally
- Auto-rolls back on exception
- Auto-closes cursor and connection

#### Helper Methods

##### `execute_query(query, params=None)`
```python
results = db.execute_query("SELECT * FROM plants WHERE user_id = %s", (1,))
# Returns: [(id, name, location, ...), ...]
```
- Convenience wrapper around raw SQL SELECT
- Handles connection lifecycle automatically

##### `execute_update(query, params=None)`
```python
affected = db.execute_update(
    "UPDATE plants SET is_healthy = %s WHERE id = %s",
    (True, 1)
)
# Returns number of affected rows
```
- Convenience wrapper for INSERT/UPDATE/DELETE
- Auto-commits on success

##### `get_database_url()`
```python
url = db.get_database_url()  # "postgresql://user:pwd@host:port/db"
```
- Returns full connection string (useful for logging without credentials visible)

---

## Performance Considerations

### Indexes
All critical query fields have indexes:
- **Lookups:** email, username, device unique_identifier
- **Filtering:** is_active, is_healthy, is_anomaly
- **Time-Series:** timestamp, (device_id, timestamp)

### Connection Pooling
- Pool size: 10 base connections
- Overflow: 20 additional connections when needed
- Pre-ping: Validates stale connections
- Recycle: 1-hour connection lifespan

### Query Optimization Tips
```python
# ❌ Bad: N+1 queries (1 query per device)
devices = session.query(Device).all()
for device in devices:
    print(device.device_type.name)  # 1 extra query each

# ✅ Good: Eager loading (1 query total)
devices = session.query(Device).options(
    joinedload(Device.device_type)
).all()

# ✅ Also good: Join query
devices = session.query(Device).join(DeviceType).all()
```

---

## Common Patterns

### Pattern: Create & Link Resources
```python
# Create user with plant and devices
user = User(email='bob@example.com', username='bob')
session.add(user)
session.flush()  # Get user.id without committing

plant = Plant(user_id=user.id, plant_type_id=1, plant_name='My First Plant')
session.add(plant)
session.flush()

device = Device(user_id=user.id, device_type_id=1, device_name='Temp Sensor')
session.add(device)
session.flush()

assignment = PlantDeviceAssignment(
    plant_id=plant.id,
    device_id=device.id,
    assignment_type='temperature'
)
session.add(assignment)
session.commit()  # Commit all at once
```

### Pattern: Audit Trail
```python
# Get all changes to a plant
plant = session.query(Plant).get(1)
print(f"Created: {plant.created_at}")
print(f"Last updated: {plant.updated_at}")

# All alerts ever triggered for a plant (audit trail)
all_alerts = session.query(Alert).filter_by(plant_id=1).order_by(
    Alert.triggered_at.desc()
).all()
```

### Pattern: Bulk Operations
```python
# Mark all alerts as acknowledged for a user
session.query(Alert).filter_by(user_id=1).update(
    {Alert.status: AlertStatusEnum.ACKNOWLEDGED}
)
session.commit()

# Disable all inactive devices
session.query(Device).filter(Device.is_active == False).delete()
session.commit()
```

---

## Troubleshooting

### Issue: "Table already exists"
```python
# Solution: Use extend_existing=True or drop and recreate
db.drop_all_tables()
db.init_db()
```

### Issue: "Foreign key violation"
```python
# Cause: Deleting parent with restricted child relationships
# Solution: Either delete children first or use CASCADE
```

### Issue: "Connection pool exhausted"
```python
# Cause: Sessions not being closed
# Solution: Always use try/finally or context managers
try:
    session = db.get_session()
    # queries...
finally:
    session.close()
```

### Issue: "Stale connection"
```python
# Pre-ping is enabled, shouldn't happen, but if it does:
# Solution: The connection pool auto-recovers
```

---

For questions or contributions, refer to `db/scripts/examples.py` and `db/scripts/test_db_module.py` for working code examples.
