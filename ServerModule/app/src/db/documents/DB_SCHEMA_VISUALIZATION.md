````markdown
# Database Schema Visualization

## 📖 When to Use This Document

**Use this document when:**
- Need to visualize table relationships and structure
- Understanding data flow and how tables connect
- Planning queries and joins
- Reviewing cascade delete behavior
- Learning the index strategy
- Understanding cardinality between tables

**What this contains:**
- ASCII Entity Relationship Diagram (ERD) with all 10 tables
- Relational schema showing cardinality (1:N, M:N, etc.)
- Relationships matrix
- Data flow diagram showing how data moves through tables
- Query path examples with actual SQL code
- Index strategy explanation
- Cascade delete impact analysis

**Not in this document:**
- Detailed field descriptions (see DB_MODULE_DOCUMENTATION.md)
- Quick reference for common patterns (see DB_QUICK_REFERENCE.md)
- Setup instructions or API reference (see DB_MODULE_DOCUMENTATION.md)
- Navigation guide (see DATABASE_DOCS_INDEX.md)

---

## Entity Relationship Diagram (ERD)

### Visual Overview
```
                              ┌──────────────────┐
                              │      USERS       │
                              │──────────────────│
                              │ id (PK)          │
                              │ email (UNIQUE)   │
                              │ username (UNIQUE)│
                              │ password_hash    │
                              │ is_active        │
                              │ is_verified      │
                              │ created_at       │
                              │ updated_at       │
                              │ last_login       │
                              └────────┬─────────┘
                                       │
                    ┌──────────────────┼──────────────────┐
                    │                  │                  │
                    ▼                  ▼                  ▼
          ┌─────────────────┐ ┌──────────────┐ ┌──────────────────┐
          │    DEVICES      │ │    PLANTS    │ │  ALERT RULES     │
          │─────────────────│ │──────────────│ │──────────────────│
          │ id (PK)         │ │ id (PK)      │ │ id (PK)          │
          │ user_id (FK)    │ │ user_id (FK) │ │ user_id (FK)     │
          │ device_type_id  │ │ plant_type_id│ │ plant_id (FK)    │
          │ unique_id       │ │ plant_name   │ │ rule_name        │
          │ device_name     │ │ location     │ │ parameter_name   │
          │ is_active       │ │ is_healthy   │ │ condition_op     │
          │ battery_level   │ │ last_watered │ │ threshold_value  │
          │ rssi            │ │ created_at   │ │ severity (ENUM)  │
          │ last_data_recv  │ │ updated_at   │ │ is_active        │
          │ created_at      │ │              │ │ created_at       │
          │ updated_at      │ └──────┬───────┘ │ updated_at       │
          └────────┬────────┘         │        └────────┬─────────┘
                   │                  │                  │
                   │          ┌───────┴───────┐          │
                   ▼          ▼               ▼          ▼
         ┌──────────────────┐ │  ┌──────────────────┐ ┌──────┐
         │  SENSOR DATA     │ │  │ PLANT_DEVICE_... │ │ALERTS│
         │──────────────────│ │  │──────────────────│ │──────│
         │ id (PK)          │ │  │ id (PK)          │ │id(PK)│
         │ device_id (FK)   │ │  │ plant_id (FK)    │ │user_i│
         │ measurement_val  │ │  │ device_id (FK)   │ │plant_│
         │ measurement_unit │ │  │ assignment_type  │ │rule_i│
         │ data_quality     │ │  │ is_active        │ │sever │
         │ is_anomaly       │ │  │ created_at       │ │statu │
         │ timestamp (IDX)  │ │  │ updated_at       │ │messa │
         │ raw_data         │ │  └──────────────────┘ │trigg │
         └──────────────────┘ │                       │thre_ │
                              └───────────────────────┴──────┘
         ┌────────────────────────────────────────┐
         │      DEVICE ECOSYSTEM                  │
         ├────────────────────────────────────────┤
         │ MANUFACTURERS (1)                      │
         │   ├─ id (PK)                           │
         │   ├─ name (UNIQUE)                     │
         │   ├─ contact_email                     │
         │   └─ is_verified                       │
         │        │ (1:N)                         │
         │        ▼                               │
         │ DEVICE TYPES (N)                       │
         │   ├─ id (PK)                           │
         │   ├─ manufacturer_id (FK)              │
         │   ├─ name                              │
         │   ├─ device_type (ENUM)                │
         │   ├─ communication_interface           │
         │   ├─ data_unit                         │
         │   ├─ min_value, max_value              │
         │   └─ is_active                         │
         │        │ (1:N)                         │
         │        ▼                               │
         │ DEVICES (N)                            │
         │   [see above]                          │
         └────────────────────────────────────────┘

         ┌────────────────────────────────────────┐
         │      PLANT ECOSYSTEM                   │
         ├────────────────────────────────────────┤
         │ PLANT TYPES (1)                        │
         │   ├─ id (PK)                           │
         │   ├─ name (UNIQUE)                     │
         │   ├─ scientific_name                   │
         │   ├─ optimal_temperature               │
         │   ├─ optimal_humidity                  │
         │   ├─ optimal_light                     │
         │   └─ water_frequency_days              │
         │        │ (1:N)                         │
         │        ▼                               │
         │ PLANTS (N)                             │
         │   [see above]                          │
         │        │ (M:N via assignment)          │
         │        ▼                               │
         │ DEVICES (via PlantDeviceAssignment)    │
         └────────────────────────────────────────┘
```

## Relational Schema

### Core Relationships

```
1. USER OWNS DEVICES (1:N CASCADE)
   User.id ──1──┬──N── Device.user_id
                   └─ Cascade Delete: If user deleted → devices deleted

2. USER OWNS PLANTS (1:N CASCADE)
   User.id ──1──┬──N── Plant.user_id
                   └─ Cascade Delete: If user deleted → plants deleted

3. MANUFACTURER HAS DEVICE TYPES (1:N CASCADE)
   Manufacturer.id ──1──┬──N── DeviceType.manufacturer_id
                           └─ Cascade Delete: If mfg deleted → types deleted

4. DEVICE TYPE HAS DEVICES (1:N CASCADE)
   DeviceType.id ──1──┬──N── Device.device_type_id
                         └─ Restrict Delete: Can't delete type if devices exist

5. PLANT TYPE CONTAINS PLANTS (1:N RESTRICT)
   PlantType.id ──1──┬──N── Plant.plant_type_id
                        └─ Restrict Delete: Can't delete species if plants exist

6. DEVICE HAS SENSOR DATA (1:N CASCADE)
   Device.id ──1──┬──N── SensorData.device_id
                     └─ Cascade Delete: If device deleted → sensor data deleted

7. PLANT HAS ASSIGNMENTS (1:N CASCADE)
   Plant.id ──1──┬──N── PlantDeviceAssignment.plant_id
                    └─ Cascade Delete: If plant deleted → assignments deleted

8. DEVICE HAS ASSIGNMENTS (1:N CASCADE)
   Device.id ──1──┬──N── PlantDeviceAssignment.device_id
                     └─ Cascade Delete: If device deleted → assignments deleted

9. PLANT ↔ DEVICE (M:N via PlantDeviceAssignment)
   PlantDeviceAssignment.plant_id ← → .device_id
   Unique Constraint: (plant_id, device_id)
   Effect: Each device can monitor each plant only once

10. ALERT RULE TRIGGERS ALERTS (1:N CASCADE)
    AlertRule.id ──1──┬──N── Alert.rule_id
                         └─ Cascade Delete: If rule deleted → alerts deleted

11. PLANT HAS ALERT RULES (1:N CASCADE)
    Plant.id ──1──┬──N── AlertRule.plant_id
                     └─ Cascade Delete: If plant deleted → rules deleted

12. PLANT HAS ALERTS (1:N CASCADE)
    Plant.id ──1──┬──N── Alert.plant_id
                     └─ Cascade Delete: If plant deleted → alerts deleted

13. USER HAS ALERT RULES (1:N CASCADE)
    User.id ──1──┬──N── AlertRule.user_id
                    └─ Cascade Delete: If user deleted → rules deleted

14. USER HAS ALERTS (1:N CASCADE)
    User.id ──1──┬──N── Alert.user_id
                    └─ Cascade Delete: If user deleted → alerts deleted
```

## Table Cardinality Matrix

```
                FROM ║ TO → USERS | DEVICES | PLANTS | DEVICE_TYPES | PLANT_TYPES | ...
                ────╫───────────────────────────────────────────────────────────────
    USERS        (1) ║    -         1:N       1:N         -              -
    DEVICES      (N) ║    N:1        -         -          1:N            -
    PLANTS       (N) ║    N:1        -         -           -             1:N
    DEVICE_TYPES (N) ║    -          1:N       -           -              -
    PLANT_TYPES  (N) ║    -          -         1:N         -              -
    ...
```

## Data Flow Diagram

```
USER REGISTERS
      │
      ▼
   User (users table)
      │
      ├─→ Registers Device
      │         │
      │         ▼
      │   Device (devices table)
      │      ├─→ SensorData
      │      │   (sensor_data table)
      │      │   └─→ Anomaly Detection
      │      └─→ PlantDeviceAssignment
      │
      ├─→ Registers Plant
      │         │
      │         ▼
      │   Plant (plants table)
      │      ├─→ PlantDeviceAssignment
      │      │   (link to Device)
      │      ├─→ AlertRule
      │      │   (plants table)
      │      │   └─→ Alert
      │      │       (alerts table)
      │      │       ├─ Status: ACTIVE
      │      │       ├─ Status: ACKNOWLEDGED
      │      │       └─ Status: RESOLVED
      │      └─→ Health Status
      │
      └─→ Configures Rules
              │
              ▼
         AlertRule (alert_rules table)
              │
              └─→ When threshold exceeded
                      │
                      ▼
                   Alert (alerts table)
                      │
                      ├─ Severity: INFO
                      ├─ Severity: WARNING
                      └─ Severity: CRITICAL
```

## Query Path Examples

### Example 1: Get All Plants for a User with Their Assigned Devices

```
Query Start: User.id = 1
      │
      ├─→ users.id = 1
      │
      ├─→ plants.user_id = 1
      │
      ├─→ plant_device_assignments.plant_id = plants.id
      │
      └─→ devices.id = plant_device_assignments.device_id
              │
              ▼
         Retrieved: User → Plants → Assignments → Devices
```

**SQL:**
```sql
SELECT 
    u.username,
    p.plant_name,
    d.device_name,
    pda.assignment_type
FROM users u
JOIN plants p ON u.id = p.user_id
JOIN plant_device_assignments pda ON p.id = pda.plant_id
JOIN devices d ON pda.device_id = d.id
WHERE u.id = 1;
```

### Example 2: Get Recent Sensor Data for a Plant's Devices

```
Query Start: Plant.id = 1
      │
      ├─→ plants.id = 1
      │
      ├─→ plant_device_assignments.plant_id = 1
      │
      ├─→ devices.id = plant_device_assignments.device_id
      │
      └─→ sensor_data.device_id = devices.id
          AND sensor_data.timestamp > NOW() - 24 HOURS
              │
              ▼
         Retrieved: Plant → Assignments → Devices → Recent Sensor Readings
```

**SQL:**
```sql
SELECT 
    p.plant_name,
    d.device_name,
    sd.measurement_value,
    sd.measurement_unit,
    sd.timestamp
FROM plants p
JOIN plant_device_assignments pda ON p.id = pda.plant_id
JOIN devices d ON pda.device_id = d.id
JOIN sensor_data sd ON d.id = sd.device_id
WHERE p.id = 1
  AND sd.timestamp > NOW() - INTERVAL '24 hours'
ORDER BY sd.timestamp DESC;
```

### Example 3: Get Active Alerts with Their Rules

```
Query Start: User.id = 1
      │
      ├─→ users.id = 1
      │
      ├─→ alerts.user_id = 1
      │
      ├─→ alert_rules.id = alerts.rule_id
      │
      └─→ plants.id = alerts.plant_id
              │
              ▼
         Retrieved: User → Alerts with Rules and Affected Plants
```

**SQL:**
```sql
SELECT 
    u.username,
    a.severity,
    a.status,
    a.message,
    ar.rule_name,
    p.plant_name,
    a.triggered_at
FROM users u
JOIN alerts a ON u.id = a.user_id
JOIN alert_rules ar ON a.rule_id = ar.id
JOIN plants p ON a.plant_id = p.id
WHERE u.id = 1
  AND a.status = 'active'
ORDER BY a.severity DESC, a.triggered_at DESC;
```

## Index Strategy

### Primary Indexes (Single Column)
```
Lookup Performance:
users.email              → Quick user login
users.username           → Quick user search
devices.unique_identifier→ Quick device lookup by UUID/MAC
plants.plant_name        → Quick plant search
```

### Filtering Indexes
```
Performance:
users.is_active          → Query active/inactive users
devices.is_active        → Query operational devices
plants.is_healthy        → Query healthy/unhealthy plants
alerts.status            → Query by alert status
alerts.is_anomaly        → Detect anomalies
```

### Time-Series Index (Composite)
```
Optimization:
sensor_data(device_id, timestamp)
  → Get all readings for a device in time range
  → Typical query: "readings for device 3 from 2pm-3pm today"
  → Without index: O(n) full table scan
  → With index: O(log n) direct access to range
```

## Cascade Delete Impact

### Scenario: Delete User
```
User deleted
  ├─→ User.devices CASCADE DELETED
  │    ├─→ Device.sensor_data CASCADE DELETED
  │    └─→ Device assignments CASCADE DELETED
  ├─→ User.plants CASCADE DELETED
  │    ├─→ Plant assignments CASCADE DELETED
  │    ├─→ Plant alert_rules CASCADE DELETED
  │    │    └─→ Rule alerts CASCADE DELETED
  │    └─→ Plant alerts CASCADE DELETED
  └─→ User.alert_rules CASCADE DELETED
       └─→ Rule alerts CASCADE DELETED

Result: 1 DELETE on users → 10-100+ cascading deletes
        (proportional to user's data volume)
```

### Scenario: Try to Delete PlantType
```
Attempt to delete PlantType
  └─→ Database CHECK: Are there any plants of this type?
      └─→ IF YES → RESTRICT: Deletion prevented
      └─→ IF NO → Allowed to proceed

Result: PROTECTS data integrity
        (can't delete reference type if instances exist)
```

See **DB_MODULE_DOCUMENTATION.md** for detailed field descriptions and usage.
