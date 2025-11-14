# IoT Plant Monitoring System 🌱

*We give you the tools - whether you take care of your plants or let them die as usual is up to you.*

---

## 📅 Project Deadlines

| Task | Due Date | Status |
|------|-----------|---------|
| **Feladat specifikáció** | Monday, 20 October 2025, 11:59 PM | ✔️ Done |
| **Feladat dokumentáció** | Monday, 1 December 2025, 11:59 PM | ⏳ Pending |
| **Feladat szoftver** | Monday, 1 December 2025, 11:59 PM | ⏳ Pending |

---

## 📋 Project Description

### 🇭🇺 Hungarian
A cél egy olyan keretrendszer létrehozása, ahol a felhasználók a megvásárolt (vagy készített), különböző okoseszköz-gyártók által árult eszközöket egy felületen integrálhatják, és kialakíthatják belőlük a szobanövényüket ellátó rendszert. Emellett a feladat tartalmazza demo eszközök implementálását is: fénymérő, talajnedvesség mérő, szivattyú és redőnyvezérlő/lámpa szimuláció, stb.

### 🇬🇧 English
The goal is to create a framework where users can integrate purchased (or self-made) smart devices from various manufacturers into a single interface, and build a system to care for their houseplants. The project also includes the implementation of demo devices: light meter, soil moisture sensor, water pump, and blind/light controller simulations, etc.

---

## 👥 Roles

### **Server Administrator**
- System maintenance and management

### **Smart Device Manufacturer** 
- Can create support for their manufactured smart devices (thermometer, light meter, lights, blind controllers, etc.)
- Support includes communication interface description, functionality description, and device type

### **User**
- Register devices with identification/authentication
- Set up alert contacts  
- Specify plant needs for soil moisture and light intensity
- Select plants from database

### **Plant Database Manager**
- Register plants with their specific requirements
- Manual correction capabilities for imported data

---

## 🔧 Technical Features

### **Demo Devices**
- 🌞 Light meter simulation
- 💧 Soil moisture sensor simulation
- ⚡ Water pump controller  
- 🪟 Blind/light controller simulation

### **Security & Protocols**
- 🔒 Users can only access their own devices
- 🆔 Unambiguous device identification
- 📡 Preferred protocols: MQTT, CoAP, or Matter

---

## 👷 Working on the project

### ServerModule
#### Specifications
- 💻 Contains the python server, on which the business logic runs
- 📁 Deals with Postgresql DB operations
- 📡 Handles incoming MQTT message from sensors and controllers
- 📱 Provides interfaces to the frontend applications
- 🌲 Provides the Plant Monitoring System™️ business logic

### Usage
- 🐍 Create a virtual environment with Python 3.12.10 (e.g. with conda) and activate it
- #️⃣ conda create -n plant_server python==3.12.4
- #️⃣ conda activate plant_server
- 📃 Install the requirements.txt
- #️⃣ pip install -r requirements.txt
- ✔️ Now you are all set to work on the ServerModule

## 🗄️ Database Module

The database module (`db/`) contains the PostgreSQL ORM schema using SQLAlchemy, with support for both ORM and raw SQL queries.

### Structure
- `base.py` - Base class and enumerations
- `*_models.py` - Modular entity definitions (user, device, plant, sensor, alert)
- `db_utils.py` - Database interface supporting both ORM and raw SQL (psycopg2)
- `requirements.txt` - Database dependencies
- `.env.example` - Configuration template (matches ServerModule environment variables)
- `scripts/db_manager.py` - Database initialization and management CLI
- `scripts/examples.py` - Usage examples
- `INTEGRATION.md` - ServerModule integration guide

### Quick Start

1. **Install dependencies:**
   ```bash
   pip install -r db/requirements.txt
   ```

2. **Create PostgreSQL database:**
   ```bash
   createdb iot_plant_db
   createuser iot_user
   psql -U postgres -d iot_plant_db -c "ALTER USER iot_user WITH PASSWORD 'iot_password';"
   ```

3. **Initialize database:**
   ```bash
   python db/scripts/db_manager.py init
   ```

4. **Seed demo data (optional):**
   ```bash
   python db/scripts/db_manager.py seed
   ```

### Usage in ServerModule

The `db.DBInterface` class supports both ORM and raw SQL:

```python
# Raw SQL (what ServerModule needs)
from db.db_utils import DBInterface

db = DBInterface()
results = db.get_plant_details('Monstera')
db.insert_sensor_data(device_id=1, measurement_value=22.5, measurement_unit='°C')

# Or ORM operations
from db import get_session, User
session = get_session()
users = session.query(User).all()
```

See [`db/INTEGRATION.md`](db/INTEGRATION.md) for complete integration examples.


---

*BME-VIK Szoftver Architektúrák project - Making plant care less deadly since 2025* 🚀
