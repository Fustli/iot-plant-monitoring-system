````markdown
# IoT Plant Monitoring - Database Quick Reference

## 📖 When to Use This Document

**Use this document when:**
- Need a quick syntax reminder during development
- Looking for copy-paste code examples
- Setting up the database for the first time
- Running database management commands
- Checking environment variable names
- Debugging N+1 queries or common mistakes

**What this contains:**
- Database schema overview (tables at a glance)
- Key fields for each table
- All enumerations and their values
- 7+ common usage patterns with code
- Relationship quick reference
- Environment variables list
- Database management commands
- Performance tips
- Common mistakes to avoid

**Not in this document:**
- Detailed field descriptions (see DB_MODULE_DOCUMENTATION.md)
- Complete API reference (see DB_MODULE_DOCUMENTATION.md)
- Visual diagrams (see DB_SCHEMA_VISUALIZATION.md)
- Learning guide or navigation (see DATABASE_DOCS_INDEX.md)

---

## 📊 Database Schema Overview

```
┌─────────────┐
│   Users     │ (user management)
└──────┬──────┘
       ├─ owns → Devices → sensor_data
       ├─ owns → Plants → alert_rules, alerts
       └─ creates → AlertRules, Alerts

┌────────────────────────┐
│ Device Ecosystem       │
├────────────────────────┤
│ Manufacturers          │ (vendors)
│ ├─ provide DeviceTypes │ (models)
│ │  └─ Devices          │ (instances)
│ └─→ sensor_data        │ (time-series)
└────────────────────────┘

┌────────────────────────┐
│ Plant Ecosystem        │
├────────────────────────┤
│ PlantTypes             │ (species, care specs)
│ └─ Plant               │ (individual)
│    ├─ PlantDevice...   │ (linked devices)
│    ├─ AlertRules       │ (conditions)
│    └─ Alerts           │ (triggered)
└────────────────────────┘
```

## 🗄️ Tables at a Glance

| Table | Purpose | Key Fields | Relationships |
|-------|---------|-----------|---------------|
| **users** | Account data | email, username, password_hash | owns devices, plants, rules, alerts |
| **manufacturers** | Device vendors | name, contact_email, is_verified | has device_types |
| **device_types** | Device models | name, device_type (enum), data_unit | belongs to manufacturer, has devices |
| **devices** | IoT instances | unique_identifier, device_name, battery_level | belongs to user/type, has sensor_data |
| **sensor_data** | Time-series measurements | measurement_value, timestamp, is_anomaly | belongs to device |
| **plant_types** | Plant species | name, scientific_name, care requirements | has many plants |
| **plants** | User's plants | plant_name, location, is_healthy | belongs to user/type, has assignments |
| **plant_device_assignments** | Device-plant mapping | assignment_type | links plants to devices |
| **alert_rules** | Alert conditions | parameter_name, condition_operator, threshold | belongs to user/plant, triggers alerts |
| **alerts** | Alert instances | severity, status, message | belongs to user/plant/rule |

## 🔑 Key Fields by Table

### Users
- `id` - Primary key
- `email` - Unique, for login
- `username` - Unique, for display
- `password_hash` - Bcrypt hash (NEVER plain text!)
- `is_active` - Enable/disable account
- `is_verified` - Email confirmed
- `created_at`, `updated_at` - Auto-timestamped

### Devices
- `id` - Primary key
- `unique_identifier` - MAC/UUID (must be unique)
- `device_name` - User-friendly name
- `battery_level` - % for wireless devices
- `last_data_received` - For heartbeat monitoring
- `is_active` - Device operational
- Foreign keys: `user_id`, `device_type_id`

### Plants
- `id` - Primary key
- `plant_name` - User's name for plant
- `is_healthy` - Overall health flag
- `health_status` - Description (Excellent, Wilting, etc.)
- `last_watered` - For watering reminders
- Foreign keys: `user_id`, `plant_type_id`

### SensorData
- `id` - Primary key
- `measurement_value` - The actual reading
- `measurement_unit` - °C, %, lux, etc.
- `timestamp` - When sensor took reading
- `is_anomaly` - Flag for unusual values
- `data_quality` - 0-100 confidence score
- Foreign key: `device_id`
- **Largest table** - has composite indexes on (device_id, timestamp)

### AlertRules
- `id` - Primary key
- `rule_name` - User-friendly name
- `parameter_name` - What to monitor (temperature, humidity, etc.)
- `condition_operator` - <, >, ==, !=
- `threshold_value` - Trigger value
- `severity` - INFO, WARNING, CRITICAL
- `is_active` - Enable/disable rule
- Foreign keys: `user_id`, `plant_id`

### Alerts
- `id` - Primary key
- `severity` - INFO, WARNING, CRITICAL
- `status` - ACTIVE, ACKNOWLEDGED, RESOLVED
- `message` - Human readable description
- `triggered_value` - Actual sensor value
- `threshold_value` - The limit that was exceeded
- `triggered_at` - When condition detected
- Foreign keys: `user_id`, `plant_id`, `rule_id`

## 📝 Enums

```python
DeviceTypeEnum:
  - SENSOR (measures)
  - ACTUATOR (controls)
  - COMBINED (both)

AlertSeverityEnum:
  - INFO (informational)
  - WARNING (should act soon)
  - CRITICAL (urgent)

AlertStatusEnum:
  - ACTIVE (unresolved)
  - ACKNOWLEDGED (user saw it)
  - RESOLVED (fixed/dismissed)
```

## 🚀 Quick Usage Examples

### Import
```python
from db.db_utils import DBInterface, get_session
from db import User, Plant, Device, SensorData, AlertRule, Alert
```

### Initialize
```python
db = DBInterface()
db.init_db()  # Create tables
session = db.get_session()
```

### Create User
```python
user = User(
    email='alice@example.com',
    username='alice',
    password_hash='$2b$12$...',  # bcrypt hash
    first_name='Alice'
)
session.add(user)
session.commit()
```

### Create Plant
```python
plant = Plant(
    user_id=1,
    plant_type_id=5,  # Monstera
    plant_name='Big Monstera',
    location='Living room corner'
)
session.add(plant)
session.commit()
```

### Link Device to Plant
```python
from db import PlantDeviceAssignment

assignment = PlantDeviceAssignment(
    plant_id=1,
    device_id=3,
    assignment_type='temperature'
)
session.add(assignment)
session.commit()
```

### Query User's Plants
```python
user = session.query(User).get(1)
for plant in user.plants:
    print(f"{plant.plant_name}: {plant.plant_type.name}")
```

### Get Last 24h Sensor Data
```python
from datetime import datetime, timedelta

now = datetime.utcnow()
yesterday = now - timedelta(hours=24)

readings = session.query(SensorData).filter(
    SensorData.device_id == 3,
    SensorData.timestamp >= yesterday
).order_by(SensorData.timestamp.desc()).all()
```

### Create Alert Rule
```python
from db.base import AlertSeverityEnum

rule = AlertRule(
    user_id=1,
    plant_id=1,
    rule_name='Low Moisture',
    parameter_name='soil_moisture',
    condition_operator='<',
    threshold_value=25,
    severity=AlertSeverityEnum.WARNING
)
session.add(rule)
session.commit()
```

### Get Active Alerts
```python
from db.base import AlertStatusEnum

alerts = session.query(Alert).filter(
    Alert.user_id == 1,
    Alert.status == AlertStatusEnum.ACTIVE
).all()

for alert in alerts:
    print(f"{alert.severity}: {alert.message}")
```

### Acknowledge Alert
```python
from datetime import datetime

alert = session.query(Alert).get(1)
alert.status = AlertStatusEnum.ACKNOWLEDGED
alert.acknowledged_at = datetime.utcnow()
session.commit()
```

## 🔗 Relationships Reference

```
User → Devices (1 user, many devices)
User → Plants (1 user, many plants)
User → AlertRules (1 user, many rules)
User → Alerts (1 user, many alerts)

Manufacturer → DeviceTypes (1 mfg, many types)
DeviceType → Devices (1 type, many devices)

PlantType → Plants (1 species, many instances)

Plant ↔ Device (many-to-many via PlantDeviceAssignment)
Plant → AlertRules (1 plant, many rules)
Plant → Alerts (1 plant, many alerts)

AlertRule → Alerts (1 rule, many alert instances)
Device → SensorData (1 device, many readings)
```

## 💾 Environment Variables

```bash
POSTGRES_DB_HOST=localhost
POSTGRES_DB_PORT=5432
POSTGRES_DB_USER=iot_user
POSTGRES_DB_PASSWORD=iot_password
POSTGRES_DB_NAME=iot_plant_db
```

## 🛠️ Database Management Commands

```bash
# Initialize database (create all tables)
python db/scripts/db_manager.py init

# Seed with demo data
python db/scripts/db_manager.py seed

# View database statistics
python db/scripts/db_manager.py info

# Reset database (⚠️ delete all data)
python db/scripts/db_manager.py reset --confirm
```

## ⚡ Performance Tips

1. **Always use indexes** - They're already in place
2. **Close sessions** - Don't leave them hanging
3. **Batch operations** - Group inserts/updates
4. **Use joinedload for relationships**:
   ```python
   from sqlalchemy.orm import joinedload
   devices = session.query(Device).options(
       joinedload(Device.device_type)
   ).all()
   ```
5. **Composite indexes for time-series**:
   - SensorData indexed on (device_id, timestamp)

## ❌ Common Mistakes

1. ❌ Storing plain text passwords
   ```python
   # BAD
   user.password_hash = "mypassword"
   
   # GOOD
   import bcrypt
   user.password_hash = bcrypt.hashpw(password.encode(), bcrypt.gensalt())
   ```

2. ❌ N+1 query problem
   ```python
   # BAD - N+1 queries
   devices = session.query(Device).all()
   for d in devices:
       print(d.device_type.name)  # Extra query each time!
   
   # GOOD - Use join
   devices = session.query(Device).join(DeviceType).all()
   ```

3. ❌ Not closing sessions
   ```python
   # BAD
   session = db.get_session()
   user = session.query(User).get(1)
   # forgot to close!
   
   # GOOD
   session = db.get_session()
   try:
       user = session.query(User).get(1)
   finally:
       session.close()
   ```

4. ❌ Cascading deletes unexpectedly
   ```python
   # CAREFUL - Deleting a user cascades to ALL their data
   session.delete(user)
   session.commit()  # Deletes devices, plants, alerts, everything!
   ```

## 📖 Need More Details?

See **DB_MODULE_DOCUMENTATION.md** for:
- Detailed field descriptions
- Complete relationship diagrams
- Advanced query examples
- Migration strategies
- Troubleshooting guide

## 🧪 Run Tests

```bash
cd /path/to/project
PYTHONPATH=. python db/scripts/test_db_module.py
```

Expected output:
```
✓ PASS: Module Imports
✓ PASS: DBInterface
✓ PASS: Models Structure
```

## 📞 Support

For questions or issues:
1. Check examples: `db/scripts/examples.py`
2. Run tests: `db/scripts/test_db_module.py`
3. Review full docs: `DB_MODULE_DOCUMENTATION.md`
