# Database Documentation Index

Welcome to the IoT Plant Monitoring System Database Documentation! This index helps you navigate the comprehensive database documentation for your team.

## 📚 Documentation Files

### 1. **DB_MODULE_DOCUMENTATION.md** (29 KB, 921 lines)
**The comprehensive reference guide for developers**

**Best for:** Learning the database system thoroughly, understanding all fields, advanced queries

**Contents:**
- ✅ Complete overview and architecture
- ✅ All 10 database tables with field descriptions
- ✅ Enumerations and their values
- ✅ Relationships and cascade rules
- ✅ Usage guide with practical examples
- ✅ Environment configuration
- ✅ Complete API reference for DBInterface
- ✅ Performance considerations
- ✅ Common patterns
- ✅ Troubleshooting guide
- ✅ Migration strategies

**Read this when:**
- Setting up the database for the first time
- Need detailed field descriptions
- Troubleshooting database issues
- Planning schema changes
- Understanding how relationships work

---

### 2. **DB_QUICK_REFERENCE.md** (9.8 KB, 372 lines)
**Quick lookup for frequent developers**

**Best for:** Daily development, copy-paste code examples, troubleshooting

**Contents:**
- ✅ Database schema overview (quick visual)
- ✅ Tables at a glance
- ✅ Key fields by table
- ✅ Enums quick reference
- ✅ Quick usage examples (7+ common patterns)
- ✅ Relationship reference
- ✅ Environment variables
- ✅ Database management commands
- ✅ Performance tips
- ✅ Common mistakes to avoid

**Read this when:**
- Need a quick syntax reminder
- Copying code examples
- Setting up database locally
- Running tests
- Common question lookup

---

### 3. **DB_SCHEMA_VISUALIZATION.md** (17 KB, 443 lines)
**Visual representation and data flow diagrams**

**Best for:** Understanding database structure visually, architecture planning

**Contents:**
- ✅ ASCII Entity Relationship Diagram (ERD)
- ✅ Relational schema with cardinality
- ✅ Relationships matrix
- ✅ Data flow diagram
- ✅ Query path examples with SQL
- ✅ Index strategy explanation
- ✅ Cascade delete impact analysis

**Read this when:**
- Visualizing table relationships
- Understanding data flow
- Planning queries
- Reviewing index strategy

---

## 🎯 Quick Start Path

### For New Team Members (First Time)
```
1. Read this file (5 min)
2. Read DB_QUICK_REFERENCE.md → Overview section (5 min)
3. Read DB_MODULE_DOCUMENTATION.md → Overview + Data Models (30 min)
4. Try examples from DB_QUICK_REFERENCE.md (20 min)
5. Review DB_SCHEMA_VISUALIZATION.md → ERD (10 min)

Total: ~70 minutes to get oriented
```

### For Day-to-Day Development
```
1. Keep DB_QUICK_REFERENCE.md bookmarked
2. Reference specific sections as needed
3. Use examples as copy-paste templates
```

### For Understanding Database Design
```
1. Start with DB_SCHEMA_VISUALIZATION.md (understand the structure)
2. Deep dive with DB_MODULE_DOCUMENTATION.md → Relationships & Cascades
3. Reference specific queries from examples
```

### For Troubleshooting Issues
```
1. Check DB_QUICK_REFERENCE.md → Common Mistakes
2. Search DB_MODULE_DOCUMENTATION.md → Troubleshooting section
3. Review query examples in DB_SCHEMA_VISUALIZATION.md
```

---

## 📖 Section Lookup Guide

### If you need to know about...

| Topic | Document | Section |
|-------|----------|---------|
| What tables exist? | Quick Reference | Tables at a Glance |
| Field descriptions | Main Doc | Data Models (section 3) |
| How to write a query | Quick Reference | Quick Usage Examples |
| Query performance tips | Main Doc | Performance Considerations |
| Relationship rules | Visualization | Relational Schema |
| Error messages | Main Doc | Troubleshooting |
| Environment setup | Quick Reference | Environment Variables |
| Data flow | Visualization | Data Flow Diagram |
| API methods | Main Doc | API Reference |
| Code examples | Quick Reference | Quick Usage Examples |
| Cascade delete rules | Visualization | Cascade Delete Impact |
| Database size | N/A | See current implementation |
| Common mistakes | Quick Reference | Common Mistakes |

---

## 🗂️ File Organization

```
project-root/
├── DB_MODULE_DOCUMENTATION.md    ← Comprehensive reference (START HERE)
├── DB_QUICK_REFERENCE.md         ← Daily lookup (BOOKMARK THIS)
├── DB_SCHEMA_VISUALIZATION.md    ← Visual diagrams (FOR DESIGN)
└── db/                           ← Actual code
    ├── base.py
    ├── user_models.py
    ├── device_models.py
    ├── plant_models.py
    ├── sensor_models.py
    ├── alert_models.py
    ├── db_utils.py
    ├── __init__.py
    └── scripts/
        ├── db_manager.py         (Use: python db_manager.py --help)
        ├── examples.py           (Working code examples)
        └── test_db_module.py     (Run tests: python test_db_module.py)
```

---

## 🚀 Getting Started (5 Minutes)

### 1. Install Dependencies
```bash
pip install -r requirements.txt
```

### 2. Create Environment File
```bash
cp .env.example .env
# Edit .env with your PostgreSQL credentials
```

### 3. Initialize Database
```bash
python db/scripts/db_manager.py init
```

### 4. Seed Demo Data (Optional)
```bash
python db/scripts/db_manager.py seed
```

### 5. Run Tests
```bash
python db/scripts/test_db_module.py
```

---

## 📊 Database Models Overview

The system has **10 main tables**:

1. **Users** - User accounts and authentication
2. **Manufacturers** - IoT device vendors
3. **DeviceTypes** - Device models and specifications
4. **Devices** - Individual IoT devices owned by users
5. **PlantTypes** - Plant species and care requirements
6. **Plants** - Individual user plants
7. **PlantDeviceAssignment** - Links plants to devices (many-to-many)
8. **SensorData** - Time-series sensor measurements
9. **AlertRules** - Alert conditions defined by users
10. **Alerts** - Alert instances triggered by rules

**Relationships:** Highly normalized with intelligent cascade rules

**Scale:** Current implementation supports production use

---

## 🔑 Key Concepts

### Cascade Rules
- When a User is deleted → All their Devices, Plants, Alerts are deleted
- When a Plant is deleted → All its Assignments and Alerts are deleted
- When a Device is deleted → All its Sensor Data is deleted
- **Protection:** Can't delete PlantType or DeviceType if instances exist (RESTRICT)

### Relationships
- **1:N** (One-to-Many): One manufacturer has many device types
- **N:1** (Many-to-One): Many devices belong to one user
- **M:N** (Many-to-Many): Many plants can have many devices (via PlantDeviceAssignment)

### Enums
- **DeviceTypeEnum:** SENSOR, ACTUATOR, COMBINED
- **AlertSeverityEnum:** INFO, WARNING, CRITICAL
- **AlertStatusEnum:** ACTIVE, ACKNOWLEDGED, RESOLVED

### Time-Series Optimization
- SensorData table has composite index (device_id, timestamp)
- Enables efficient "last 24 hours" queries
- Largest table (store ~20M readings/year for 5k devices)

---

## 💡 Common Tasks

### Create a New User
```python
from db import User
from db.db_utils import DBInterface

db = DBInterface()
session = db.get_session()

user = User(
    email='john@example.com',
    username='john',
    password_hash='bcrypt_hash_here'
)
session.add(user)
session.commit()
```

### Query User's Plants
```python
user = session.query(User).get(1)
for plant in user.plants:
    print(f"{plant.plant_name}: {plant.plant_type.name}")
```

### Get Recent Sensor Data
```python
from datetime import datetime, timedelta

now = datetime.utcnow()
yesterday = now - timedelta(hours=24)

readings = session.query(SensorData).filter(
    SensorData.device_id == 1,
    SensorData.timestamp >= yesterday
).order_by(SensorData.timestamp.desc()).all()
```

### Create Alert Rule
```python
from db import AlertRule
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

---

## ❓ FAQ

**Q: Where do I start?**  
A: Read DB_QUICK_REFERENCE.md first, then DB_MODULE_DOCUMENTATION.md

**Q: How do I run a custom query?**  
A: See "Raw SQL Operations" in DB_MODULE_DOCUMENTATION.md

**Q: Can I delete a plant?**  
A: Yes - it cascades to delete assignments, alerts, and alert rules

**Q: How large can the database get?**  
A: See DB_SCHEMA_VISUALIZATION.md → Storage Estimation section

**Q: What if I delete a user by mistake?**  
A: All their data is deleted (use backups for recovery)

**Q: How do I fix N+1 query problems?**  
A: See DB_QUICK_REFERENCE.md → Common Mistakes

---

## 🔗 Related Files

- `.env` - Database credentials (never commit!)
- `.env.example` - Template for .env
- `requirements.txt` - Python dependencies (includes SQLAlchemy, psycopg2)
- `README.md` - Project overview

---

## 📞 Support & Resources

### In This Repository
- `db/scripts/examples.py` - Working code examples
- `db/scripts/test_db_module.py` - Unit tests showing usage
- `db/scripts/db_manager.py` - Database management CLI

### External Resources
- [SQLAlchemy Documentation](https://docs.sqlalchemy.org/)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
- [psycopg2 Documentation](https://www.psycopg.org/)

---

## 📋 Checklist for New Contributors

- [ ] Read DB_QUICK_REFERENCE.md
- [ ] Review DB_SCHEMA_VISUALIZATION.md
- [ ] Set up `.env` file
- [ ] Run `python db/scripts/db_manager.py init`
- [ ] Run tests: `python db/scripts/test_db_module.py`
- [ ] Try examples from `db/scripts/examples.py`
- [ ] Read DB_MODULE_DOCUMENTATION.md for deep dive
- [ ] Bookmark these docs

---

## 📞 Support & Resources

## 📝 Documentation Updates

These documents are accurate as of November 14, 2025.

When updating documentation:
1. Update corresponding `.md` file
2. Update code examples if models changed
3. Update storage estimates if scale changed
4. Increment version if schema changed

Current schema version: 1.0 (stable)

---

**Last Updated:** November 14, 2025  
**Database Version:** PostgreSQL 12+  
**ORM Version:** SQLAlchemy 2.0.23  
**Status:** ✅ Production Ready
