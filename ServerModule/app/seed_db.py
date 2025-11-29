"""
Database Seeder Script for IoT Plant Monitoring System

This script seeds the database with:
1. Admin user (admin@plantmonitor.local)
2. Test manufacturer user (manufacturer@plantmonitor.local)
3. Sample plant types (from Trefle API via TrefleScraper with fallback to hardcoded data)
4. Dummy consumer users
5. Device types and devices
6. Hubs and hub metrics
7. Sensor data
8. Alert rules and alerts

Usage:
    python seed_db.py [--reset]

Options:
    --reset     Drop and recreate all tables before seeding
"""

import os
import sys
import argparse
from datetime import datetime, timedelta
import random
import uuid

# Add parent directory to path for imports
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
# Add project root for scraper import
PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, PROJECT_ROOT)

from dotenv import load_dotenv
from sqlalchemy.orm import Session

load_dotenv()

# Import database utilities and models
from src.db.db_utils import get_session, create_engine_instance, get_db_interface
from src.db.base import Base, AlertSeverityEnum, AlertStatusEnum
from src.db.user_models import User
from src.db.plant_models import PlantType, Plant, PlantDeviceAssignment
from src.db.device_models import Device, DeviceType, Manufacturer
from src.db.hub_models import Hub, HubMetrics
from src.db.sensor_models import SensorData
from src.db.alert_models import AlertRule, Alert
from security import hash_password

# Import the scraper
from scrape_plant_data import TrefleScraper, COMMON_PLANTS


# =============================================================================
# CONFIGURATION
# =============================================================================

TREFLE_API_KEY = os.getenv("TREFLE_API_KEY", "")

DEFAULT_PASSWORD = "password123"  # For demo/development only


# =============================================================================
# TREFLE SCRAPER FUNCTIONS
# =============================================================================

def fetch_plants_from_trefle(limit: int = 20) -> list:
    """
    Fetch plant data from Trefle API using TrefleScraper.
    Returns a list of plant dictionaries with standardized fields.
    """
    if not TREFLE_API_KEY:
        print("[WARNING] No TREFLE_API_KEY found, using fallback plant data")
        return []

    try:
        # Initialize the scraper
        scraper = TrefleScraper(TREFLE_API_KEY)
        
        # Select a subset of plants to scrape
        plants_to_scrape = COMMON_PLANTS[:limit]
        
        print(f"[INFO] Fetching {len(plants_to_scrape)} plants from Trefle API...")
        
        # Scrape plant data
        scraped_data = scraper.scrape_plants(plants_to_scrape, delay=0.5)
        
        # Convert scraped data to our format
        plants = []
        for item in scraped_data:
            plant = {
                "name": item.get("name", "Unknown"),
                "scientific_name": item.get("scientific_name", "Unknown species"),
                "description": item.get("description") or "A beautiful houseplant.",
                "optimal_temperature": item.get("optimal_temperature", 22.0),
                "optimal_humidity": item.get("optimal_humidity", 50.0),
                "optimal_light": item.get("optimal_light", 1500.0),
                "optimal_moisture": item.get("optimal_humidity", 50.0) * 0.9,  # Derive from humidity
                "care_instructions": item.get("care_instructions") or "Water when soil is dry. Prefers indirect light.",
            }
            plants.append(plant)
        
        print(f"[SUCCESS] Fetched {len(plants)} plants from Trefle API")
        return plants
        
    except Exception as e:
        print(f"[WARNING] Trefle API error: {e}, using fallback")
        return []


def get_fallback_plant_types() -> list:
    """
    Returns hardcoded plant type data as fallback when Trefle API is unavailable.
    """
    return [
        {
            "name": "Golden Pothos",
            "scientific_name": "Epipremnum aureum",
            "description": "Easy-to-care trailing vine with heart-shaped leaves.",
            "optimal_temperature": 21.0,
            "optimal_humidity": 50.0,
            "optimal_light": 1000.0,
            "optimal_moisture": 45.0,
            "care_instructions": "Water when top inch of soil is dry. Tolerates low light.",
        },
        {
            "name": "Peace Lily",
            "scientific_name": "Spathiphyllum wallisii",
            "description": "Elegant flowering plant that purifies air.",
            "optimal_temperature": 22.0,
            "optimal_humidity": 60.0,
            "optimal_light": 800.0,
            "optimal_moisture": 55.0,
            "care_instructions": "Keep soil moist. Will droop when thirsty.",
        },
        {
            "name": "Snake Plant",
            "scientific_name": "Sansevieria trifasciata",
            "description": "Hardy succulent with upright sword-like leaves.",
            "optimal_temperature": 23.0,
            "optimal_humidity": 40.0,
            "optimal_light": 1500.0,
            "optimal_moisture": 30.0,
            "care_instructions": "Water sparingly. Very drought tolerant.",
        },
        {
            "name": "Spider Plant",
            "scientific_name": "Chlorophytum comosum",
            "description": "Popular houseplant with arching leaves and baby plantlets.",
            "optimal_temperature": 20.0,
            "optimal_humidity": 50.0,
            "optimal_light": 1200.0,
            "optimal_moisture": 50.0,
            "care_instructions": "Water regularly. Produces babies on long stems.",
        },
        {
            "name": "Rubber Plant",
            "scientific_name": "Ficus elastica",
            "description": "Bold tropical plant with large glossy leaves.",
            "optimal_temperature": 22.0,
            "optimal_humidity": 55.0,
            "optimal_light": 1800.0,
            "optimal_moisture": 45.0,
            "care_instructions": "Wipe leaves to keep them shiny. Water when dry.",
        },
        {
            "name": "Monstera",
            "scientific_name": "Monstera deliciosa",
            "description": "Trendy tropical plant with iconic split leaves.",
            "optimal_temperature": 23.0,
            "optimal_humidity": 65.0,
            "optimal_light": 1000.0,
            "optimal_moisture": 55.0,
            "care_instructions": "Provide support for climbing. Keep humidity high.",
        },
        {
            "name": "Fiddle Leaf Fig",
            "scientific_name": "Ficus lyrata",
            "description": "Dramatic plant with large violin-shaped leaves.",
            "optimal_temperature": 21.0,
            "optimal_humidity": 50.0,
            "optimal_light": 2000.0,
            "optimal_moisture": 50.0,
            "care_instructions": "Needs consistent watering and bright light.",
        },
        {
            "name": "Boston Fern",
            "scientific_name": "Nephrolepis exaltata",
            "description": "Classic fern with lush, arching fronds.",
            "optimal_temperature": 18.0,
            "optimal_humidity": 70.0,
            "optimal_light": 600.0,
            "optimal_moisture": 65.0,
            "care_instructions": "Keep soil moist. Mist regularly for humidity.",
        },
        {
            "name": "Aloe Vera",
            "scientific_name": "Aloe barbadensis miller",
            "description": "Medicinal succulent with healing gel inside leaves.",
            "optimal_temperature": 24.0,
            "optimal_humidity": 35.0,
            "optimal_light": 2000.0,
            "optimal_moisture": 25.0,
            "care_instructions": "Water deeply but infrequently. Needs bright light.",
        },
        {
            "name": "ZZ Plant",
            "scientific_name": "Zamioculcas zamiifolia",
            "description": "Nearly indestructible plant with glossy dark leaves.",
            "optimal_temperature": 22.0,
            "optimal_humidity": 40.0,
            "optimal_light": 800.0,
            "optimal_moisture": 30.0,
            "care_instructions": "Extremely drought tolerant. Perfect for beginners.",
        },
    ]


# =============================================================================
# SEEDING FUNCTIONS
# =============================================================================

def seed_admin_user(session: Session) -> User:
    """Create admin user if not exists."""
    admin = session.query(User).filter(User.email == "admin@plantmonitor.com").first()
    
    if admin:
        print("[INFO] Admin user already exists")
        return admin
    
    admin = User(
        email="admin@plantmonitor.com",
        username="admin",
        role="admin",
        password_hash=hash_password(DEFAULT_PASSWORD),
        first_name="System",
        last_name="Administrator",
        is_active=True,
        is_verified=True,
    )
    session.add(admin)
    session.commit()
    print(f"[SUCCESS] Created admin user (admin@plantmonitor.com)")
    return admin


def seed_manufacturer_user(session: Session) -> User:
    """Create test manufacturer user if not exists."""
    manufacturer_user = session.query(User).filter(
        User.email == "manufacturer@plantmonitor.com"
    ).first()
    
    if manufacturer_user:
        # Ensure manufacturer profile exists
        manufacturer_profile = session.query(Manufacturer).filter(
            Manufacturer.user_id == manufacturer_user.id
        ).first()
        if not manufacturer_profile:
            manufacturer_profile = Manufacturer(
                user_id=manufacturer_user.id,
                name="Test Manufacturer Co.",
                description="Test manufacturer for demo purposes",
                contact_email="manufacturer@plantmonitor.com",
                is_verified=True,
            )
            session.add(manufacturer_profile)
            session.commit()
            print("[SUCCESS] Created manufacturer profile for existing user")
        print("[INFO] Manufacturer user already exists")
        return manufacturer_user
    
    manufacturer_user = User(
        email="manufacturer@plantmonitor.com",
        username="test_manufacturer",
        role="manufacturer",
        password_hash=hash_password(DEFAULT_PASSWORD),
        first_name="Test",
        last_name="Manufacturer",
        is_active=True,
        is_verified=True,
    )
    session.add(manufacturer_user)
    session.commit()
    
    # Create manufacturer profile linked to user
    manufacturer_profile = Manufacturer(
        user_id=manufacturer_user.id,
        name="Test Manufacturer Co.",
        description="Test manufacturer for demo purposes",
        contact_email="manufacturer@plantmonitor.com",
        is_verified=True,
    )
    session.add(manufacturer_profile)
    session.commit()
    
    print("[SUCCESS] Created manufacturer user (manufacturer@plantmonitor.com)")
    return manufacturer_user


def seed_dummy_users(session: Session, count: int = 5) -> list:
    """Create dummy consumer users."""
    users = []
    
    for i in range(1, count + 1):
        email = f"user{i}@example.com"
        existing = session.query(User).filter(User.email == email).first()
        
        if existing:
            users.append(existing)
            continue
        
        user = User(
            email=email,
            username=f"demo_user_{i}",
            role="consumer",
            password_hash=hash_password(DEFAULT_PASSWORD),
            first_name=f"Demo",
            last_name=f"User {i}",
            is_active=True,
            is_verified=True,
        )
        session.add(user)
        users.append(user)
    
    session.commit()
    print(f"[SUCCESS] Created {count} dummy consumer users")
    return users


def seed_plant_types(session: Session) -> list:
    """
    Seed plant types from Trefle API or fallback data.
    """
    # Try Trefle API first
    plants_data = fetch_plants_from_trefle(limit=15)
    
    # Use fallback if Trefle fails
    if not plants_data:
        plants_data = get_fallback_plant_types()
    
    plant_types = []
    
    for data in plants_data:
        # Check if already exists
        existing = session.query(PlantType).filter(
            PlantType.scientific_name == data["scientific_name"]
        ).first()
        
        if existing:
            plant_types.append(existing)
            continue
        
        plant_type = PlantType(
            name=data["name"],
            scientific_name=data["scientific_name"],
            description=data.get("description", ""),
            optimal_temperature=data["optimal_temperature"],
            optimal_humidity=data["optimal_humidity"],
            optimal_light=data["optimal_light"],
            optimal_moisture=data["optimal_moisture"],
            care_instructions=data.get("care_instructions", ""),
        )
        session.add(plant_type)
        plant_types.append(plant_type)
    
    session.commit()
    print(f"[SUCCESS] Seeded {len(plant_types)} plant types")
    return plant_types


def seed_sample_plants(session: Session, users: list, plant_types: list) -> list:
    """Create sample plants for users."""
    if not users or not plant_types:
        print("[WARNING] No users or plant types to create sample plants")
        return []
    
    plants = []
    locations = ["Living Room", "Bedroom", "Kitchen", "Office", "Balcony", "Bathroom"]
    
    for user in users:
        # Give each user 1-3 random plants
        num_plants = random.randint(1, 3)
        selected_types = random.sample(plant_types, min(num_plants, len(plant_types)))
        
        for i, plant_type in enumerate(selected_types):
            plant_name = f"{user.username}'s {plant_type.name}"
            
            # Check if exists
            existing = session.query(Plant).filter(Plant.plant_name == plant_name).first()
            if existing:
                plants.append(existing)
                continue
            
            # Generate realistic dummy sensor values based on plant type
            # Add some variance around optimal values
            moisture_variance = random.uniform(-15, 15)
            temp_variance = random.uniform(-3, 3)
            light_variance = random.uniform(-300, 300)
            
            current_moisture = max(10, min(90, plant_type.optimal_moisture + moisture_variance))
            current_temperature = max(15, min(35, plant_type.optimal_temperature + temp_variance))
            current_light = max(100, min(5000, plant_type.optimal_light + light_variance))
            
            # Some plants may have been watered recently
            last_watered = None
            if random.random() > 0.3:  # 70% have been watered
                last_watered = datetime.now() - timedelta(hours=random.randint(1, 72))
            
            plant = Plant(
                user_id=user.id,
                plant_type_id=plant_type.id,
                plant_name=plant_name,
                location=random.choice(locations),
                planting_date=datetime.now() - timedelta(days=random.randint(30, 365)),
                is_healthy=random.choice([True, True, True, False]),  # 75% healthy
                health_status="Good" if random.random() > 0.25 else "Needs attention",
                notes=f"A lovely {plant_type.name} plant.",
                current_moisture=round(current_moisture, 1),
                current_temperature=round(current_temperature, 1),
                current_light=round(current_light, 0),
                last_watered=last_watered,
            )
            session.add(plant)
            plants.append(plant)
    
    session.commit()
    print(f"[SUCCESS] Created {len(plants)} sample plants")
    return plants


def seed_device_types(session: Session, manufacturer: Manufacturer) -> list:
    """Create sample device types for the manufacturer."""
    device_types_data = [
        {
            "name": "SoilMoisture Pro v1",
            "device_type": "sensor",
            "description": "High-precision soil moisture sensor with capacitive technology",
            "communication_interface": "MQTT",
            "supported_functions": "moisture_reading,calibration,sleep_mode",
            "data_unit": "%",
            "min_value": 0.0,
            "max_value": 100.0,
        },
        {
            "name": "TempHumidity Sensor v2",
            "device_type": "sensor",
            "description": "Combined temperature and humidity sensor for ambient monitoring",
            "communication_interface": "MQTT",
            "supported_functions": "temperature_reading,humidity_reading,dew_point",
            "data_unit": "°C/%",
            "min_value": -40.0,
            "max_value": 85.0,
        },
        {
            "name": "LightMeter LX500",
            "device_type": "sensor",
            "description": "Light intensity sensor measuring lux levels for plant health",
            "communication_interface": "MQTT",
            "supported_functions": "lux_reading,uv_index",
            "data_unit": "lux",
            "min_value": 0.0,
            "max_value": 100000.0,
        },
        {
            "name": "SmartPump Mini",
            "device_type": "actuator",
            "description": "Compact water pump for automated plant watering",
            "communication_interface": "MQTT",
            "supported_functions": "pump_on,pump_off,flow_rate,schedule",
            "data_unit": "ml/min",
            "min_value": 0.0,
            "max_value": 500.0,
        },
        {
            "name": "GrowLight Controller",
            "device_type": "actuator",
            "description": "Smart LED grow light controller with spectrum adjustment",
            "communication_interface": "MQTT",
            "supported_functions": "on_off,brightness,color_temp,timer",
            "data_unit": "%",
            "min_value": 0.0,
            "max_value": 100.0,
        },
        {
            "name": "pH Sensor Pro",
            "device_type": "sensor",
            "description": "Accurate pH sensor for soil and water monitoring",
            "communication_interface": "MQTT",
            "supported_functions": "ph_reading,temperature_compensation",
            "data_unit": "pH",
            "min_value": 0.0,
            "max_value": 14.0,
        },
    ]
    
    device_types = []
    for data in device_types_data:
        existing = session.query(DeviceType).filter(DeviceType.name == data["name"]).first()
        if existing:
            device_types.append(existing)
            continue
        
        device_type = DeviceType(
            manufacturer_id=manufacturer.id,
            **data
        )
        session.add(device_type)
        device_types.append(device_type)
    
    session.commit()
    print(f"[SUCCESS] Created {len(device_types)} device types")
    return device_types


def seed_hubs(session: Session, users: list) -> list:
    """Create hubs for consumer users."""
    hubs = []
    hub_locations = ["Home", "Office", "Greenhouse", "Garden Shed", "Balcony"]
    
    for user in users:
        # Each user gets 1-2 hubs
        num_hubs = random.randint(1, 2)
        
        for i in range(num_hubs):
            hub_uuid = str(uuid.uuid4())[:8].upper()
            hub_id_str = f"HUB-{user.id}-{hub_uuid}"
            
            existing = session.query(Hub).filter(Hub.hub_id == hub_id_str).first()
            if existing:
                hubs.append(existing)
                continue
            
            location = random.choice(hub_locations)
            is_online = random.choice([True, True, True, False])  # 75% online
            
            hub = Hub(
                user_id=user.id,
                hub_id=hub_id_str,
                hub_link=f"mqtt://broker.plantmonitor.local:1883/{hub_id_str}",
                name=f"{user.username}'s {location} Hub",
                location=location,
                description=f"IoT gateway hub for {location.lower()} plant monitoring",
                is_online=is_online,
                last_seen=datetime.now() - timedelta(minutes=random.randint(0, 60)) if is_online else datetime.now() - timedelta(hours=random.randint(1, 48)),
                last_heartbeat=datetime.now() - timedelta(seconds=random.randint(0, 300)) if is_online else None,
                ip_address=f"192.168.1.{random.randint(100, 254)}",
                mac_address=":".join([f"{random.randint(0, 255):02X}" for _ in range(6)]),
                firmware_version=f"v{random.randint(1, 3)}.{random.randint(0, 9)}.{random.randint(0, 9)}",
                uptime_seconds=random.randint(3600, 2592000) if is_online else 0,
                messages_sent=random.randint(1000, 100000),
                messages_received=random.randint(500, 50000),
                errors_count=random.randint(0, 100),
                is_active=True,
            )
            session.add(hub)
            hubs.append(hub)
    
    session.commit()
    print(f"[SUCCESS] Created {len(hubs)} hubs")
    return hubs


def seed_hub_metrics(session: Session, hubs: list) -> list:
    """Create sample hub metrics for time-series data."""
    all_metrics = []
    
    for hub in hubs:
        # Generate metrics for the last 24 hours (every 15 minutes = 96 entries)
        num_entries = random.randint(20, 96)
        
        for i in range(num_entries):
            timestamp = datetime.now() - timedelta(minutes=i * 15)
            
            metric = HubMetrics(
                hub_id=hub.id,
                timestamp=timestamp,
                is_connected=hub.is_online or random.random() > 0.2,
                latency_ms=random.uniform(5.0, 150.0),
                cpu_usage_percent=random.uniform(5.0, 80.0),
                memory_usage_percent=random.uniform(20.0, 70.0),
                disk_usage_percent=random.uniform(10.0, 50.0),
                bandwidth_in_kbps=random.uniform(1.0, 100.0),
                bandwidth_out_kbps=random.uniform(0.5, 50.0),
                packet_loss_percent=random.uniform(0.0, 5.0),
                connected_devices_count=random.randint(1, 10),
                active_devices_count=random.randint(1, 8),
                messages_per_minute=random.randint(5, 100),
                errors_per_minute=random.randint(0, 5),
            )
            session.add(metric)
            all_metrics.append(metric)
    
    session.commit()
    print(f"[SUCCESS] Created {len(all_metrics)} hub metrics entries")
    return all_metrics


def seed_devices(session: Session, users: list, hubs: list, plants: list, device_types: list) -> list:
    """Create devices for users and optionally assign to plants."""
    devices = []
    
    # Create a mapping of user_id to their hubs
    user_hubs = {}
    for hub in hubs:
        if hub.user_id not in user_hubs:
            user_hubs[hub.user_id] = []
        user_hubs[hub.user_id].append(hub)
    
    # Create a mapping of user_id to their plants
    user_plants = {}
    for plant in plants:
        if plant.user_id not in user_plants:
            user_plants[plant.user_id] = []
        user_plants[plant.user_id].append(plant)
    
    for user in users:
        if user.id not in user_hubs:
            continue
        
        # Each user gets 2-6 devices
        num_devices = random.randint(2, 6)
        
        for i in range(num_devices):
            device_uuid = str(uuid.uuid4())[:12].upper()
            unique_id = f"DEV-{device_uuid}"
            
            existing = session.query(Device).filter(Device.unique_identifier == unique_id).first()
            if existing:
                devices.append(existing)
                continue
            
            device_type = random.choice(device_types)
            hub = random.choice(user_hubs[user.id])
            
            # 70% chance to assign to a plant
            plant = None
            if user.id in user_plants and user_plants[user.id] and random.random() < 0.7:
                plant = random.choice(user_plants[user.id])
            
            is_active = random.choice([True, True, True, False])
            
            device = Device(
                user_id=user.id,
                hub_id=hub.id,
                plant_id=plant.id if plant else None,
                device_type_id=device_type.id,
                unique_identifier=unique_id,
                device_name=f"{device_type.name} #{i + 1}",
                is_active=is_active,
                last_data_received=datetime.now() - timedelta(minutes=random.randint(0, 120)) if is_active else None,
                last_heartbeat=datetime.now() - timedelta(seconds=random.randint(0, 300)) if is_active else None,
                location_description=f"Near {plant.plant_name}" if plant else hub.location,
                battery_level=random.uniform(20.0, 100.0) if random.random() > 0.3 else None,
                rssi=random.randint(-90, -30) if is_active else None,
            )
            session.add(device)
            devices.append(device)
    
    session.commit()
    print(f"[SUCCESS] Created {len(devices)} devices")
    return devices


def seed_sensor_data(session: Session, devices: list) -> list:
    """Create sample sensor data for devices."""
    all_sensor_data = []
    
    # Only create sensor data for sensor-type devices
    sensor_devices = [d for d in devices if d.device_type and "sensor" in d.device_type.device_type.lower()]
    
    for device in sensor_devices:
        # Generate data for the last 7 days (every 30 minutes = ~336 entries)
        num_entries = random.randint(50, 336)
        
        # Base value depends on device type
        if "moisture" in device.device_type.name.lower():
            base_value = random.uniform(30, 70)
            variance = 15
            unit = "%"
        elif "temp" in device.device_type.name.lower():
            base_value = random.uniform(18, 28)
            variance = 5
            unit = "°C"
        elif "light" in device.device_type.name.lower():
            base_value = random.uniform(500, 2000)
            variance = 500
            unit = "lux"
        elif "ph" in device.device_type.name.lower():
            base_value = random.uniform(5.5, 7.5)
            variance = 0.5
            unit = "pH"
        else:
            base_value = random.uniform(40, 60)
            variance = 20
            unit = device.device_type.data_unit
        
        for i in range(num_entries):
            timestamp = datetime.now() - timedelta(minutes=i * 30)
            
            # Simulate value drift with some noise
            value = base_value + random.uniform(-variance, variance)
            
            # Clamp to device type range
            value = max(device.device_type.min_value, min(device.device_type.max_value, value))
            
            # 5% chance of anomaly
            is_anomaly = random.random() < 0.05
            if is_anomaly:
                value = value * random.choice([0.5, 1.5, 2.0])
                value = max(device.device_type.min_value, min(device.device_type.max_value, value))
            
            sensor_data = SensorData(
                device_id=device.id,
                measurement_value=round(value, 2),
                measurement_unit=unit,
                data_quality=random.randint(85, 100),
                is_anomaly=is_anomaly,
                timestamp=timestamp,
                raw_data=f'{{"value": {value}, "unit": "{unit}", "device": "{device.unique_identifier}"}}',
            )
            session.add(sensor_data)
            all_sensor_data.append(sensor_data)
    
    session.commit()
    print(f"[SUCCESS] Created {len(all_sensor_data)} sensor data entries")
    return all_sensor_data


def seed_alert_rules(session: Session, users: list, plants: list) -> list:
    """Create sample alert rules for plants."""
    all_rules = []
    
    rule_templates = [
        {
            "rule_name": "Low Moisture Alert",
            "rule_type": "threshold",
            "parameter_name": "soil_moisture",
            "condition_operator": "<",
            "threshold_value": 30.0,
            "severity": AlertSeverityEnum.WARNING,
        },
        {
            "rule_name": "High Temperature Warning",
            "rule_type": "threshold",
            "parameter_name": "temperature",
            "condition_operator": ">",
            "threshold_value": 30.0,
            "severity": AlertSeverityEnum.WARNING,
        },
        {
            "rule_name": "Critical Temperature",
            "rule_type": "threshold",
            "parameter_name": "temperature",
            "condition_operator": ">",
            "threshold_value": 35.0,
            "severity": AlertSeverityEnum.CRITICAL,
        },
        {
            "rule_name": "Low Light Alert",
            "rule_type": "threshold",
            "parameter_name": "light_level",
            "condition_operator": "<",
            "threshold_value": 200.0,
            "severity": AlertSeverityEnum.INFO,
        },
        {
            "rule_name": "Overwatering Alert",
            "rule_type": "threshold",
            "parameter_name": "soil_moisture",
            "condition_operator": ">",
            "threshold_value": 85.0,
            "severity": AlertSeverityEnum.WARNING,
        },
    ]
    
    # Create user-plants mapping
    user_plants = {}
    for plant in plants:
        if plant.user_id not in user_plants:
            user_plants[plant.user_id] = []
        user_plants[plant.user_id].append(plant)
    
    for user in users:
        if user.id not in user_plants:
            continue
        
        for plant in user_plants[user.id]:
            # Each plant gets 1-3 random alert rules
            num_rules = random.randint(1, 3)
            selected_templates = random.sample(rule_templates, min(num_rules, len(rule_templates)))
            
            for template in selected_templates:
                rule_name = f"{plant.plant_name} - {template['rule_name']}"
                
                existing = session.query(AlertRule).filter(
                    AlertRule.user_id == user.id,
                    AlertRule.plant_id == plant.id,
                    AlertRule.rule_name == rule_name
                ).first()
                
                if existing:
                    all_rules.append(existing)
                    continue
                
                rule = AlertRule(
                    user_id=user.id,
                    plant_id=plant.id,
                    rule_name=rule_name,
                    rule_type=template["rule_type"],
                    parameter_name=template["parameter_name"],
                    condition_operator=template["condition_operator"],
                    threshold_value=template["threshold_value"],
                    severity=template["severity"],
                    is_active=random.choice([True, True, True, False]),  # 75% active
                )
                session.add(rule)
                all_rules.append(rule)
    
    session.commit()
    print(f"[SUCCESS] Created {len(all_rules)} alert rules")
    return all_rules


def seed_alerts(session: Session, alert_rules: list) -> list:
    """Create sample alerts from alert rules."""
    all_alerts = []
    
    for rule in alert_rules:
        # 30% chance for each rule to have triggered alerts
        if random.random() > 0.3:
            continue
        
        # Generate 1-5 alerts per rule
        num_alerts = random.randint(1, 5)
        
        for i in range(num_alerts):
            triggered_at = datetime.now() - timedelta(hours=random.randint(1, 168))  # Last week
            
            # Random status
            status_choice = random.choice([
                AlertStatusEnum.ACTIVE,
                AlertStatusEnum.ACTIVE,
                AlertStatusEnum.ACKNOWLEDGED,
                AlertStatusEnum.RESOLVED,
            ])
            
            # Generate a triggered value that would trigger this rule
            if rule.condition_operator == "<":
                triggered_value = rule.threshold_value - random.uniform(5, 20)
            else:
                triggered_value = rule.threshold_value + random.uniform(5, 20)
            
            alert = Alert(
                user_id=rule.user_id,
                plant_id=rule.plant_id,
                rule_id=rule.id,
                severity=rule.severity,
                status=status_choice,
                message=f"Alert: {rule.rule_name} triggered. Value: {triggered_value:.2f} (threshold: {rule.threshold_value})",
                triggered_value=triggered_value,
                threshold_value=rule.threshold_value,
                triggered_at=triggered_at,
                acknowledged_at=triggered_at + timedelta(minutes=random.randint(5, 60)) if status_choice in [AlertStatusEnum.ACKNOWLEDGED, AlertStatusEnum.RESOLVED] else None,
                resolved_at=triggered_at + timedelta(hours=random.randint(1, 24)) if status_choice == AlertStatusEnum.RESOLVED else None,
            )
            session.add(alert)
            all_alerts.append(alert)
    
    session.commit()
    print(f"[SUCCESS] Created {len(all_alerts)} alerts")
    return all_alerts


def seed_plant_device_assignments(session: Session, plants: list, devices: list) -> list:
    """Create plant-device assignments for many-to-many relationship."""
    assignments = []
    
    # Group devices by user
    user_devices = {}
    for device in devices:
        if device.user_id not in user_devices:
            user_devices[device.user_id] = []
        user_devices[device.user_id].append(device)
    
    for plant in plants:
        if plant.user_id not in user_devices:
            continue
        
        available_devices = user_devices[plant.user_id]
        if not available_devices:
            continue
        
        # Assign 1-3 devices to each plant
        num_assignments = min(random.randint(1, 3), len(available_devices))
        selected_devices = random.sample(available_devices, num_assignments)
        
        for device in selected_devices:
            existing = session.query(PlantDeviceAssignment).filter(
                PlantDeviceAssignment.plant_id == plant.id,
                PlantDeviceAssignment.device_id == device.id
            ).first()
            
            if existing:
                assignments.append(existing)
                continue
            
            assignment = PlantDeviceAssignment(
                plant_id=plant.id,
                device_id=device.id,
                assignment_type="monitoring",  # or "watering", "lighting", etc.
                is_active=True,
            )
            session.add(assignment)
            assignments.append(assignment)
    
    session.commit()
    print(f"[SUCCESS] Created {len(assignments)} plant-device assignments")
    return assignments


def reset_database():
    """Drop all tables and recreate them."""
    engine = create_engine_instance()
    print("[WARNING] Resetting database - dropping all tables...")
    Base.metadata.drop_all(bind=engine)
    print("[SUCCESS] Tables dropped")
    
    print("[INFO] Creating tables...")
    Base.metadata.create_all(bind=engine)
    print("[SUCCESS] Tables created")


# =============================================================================
# MAIN
# =============================================================================

def ensure_tables_exist():
    """Create tables if they don't exist."""
    engine = create_engine_instance()
    Base.metadata.create_all(bind=engine)
    print("[INFO] Database tables ensured")


def main():
    parser = argparse.ArgumentParser(description="Seed the database with initial data")
    parser.add_argument(
        "--reset",
        action="store_true",
        help="Drop and recreate all tables before seeding",
    )
    args = parser.parse_args()
    
    print("=" * 60)
    print("IoT Plant Monitoring System - Database Seeder")
    print("=" * 60)
    
    if args.reset:
        reset_database()
    else:
        # Ensure tables exist even without reset
        ensure_tables_exist()
    
    session = get_session()
    
    try:
        # Seed users
        print("\n[STEP 1/10] Seeding users...")
        admin = seed_admin_user(session)
        manufacturer_user = seed_manufacturer_user(session)
        consumers = seed_dummy_users(session, count=5)
        
        # Get manufacturer profile for device types
        manufacturer_profile = session.query(Manufacturer).filter(
            Manufacturer.user_id == manufacturer_user.id
        ).first()
        
        # Seed plant types
        print("\n[STEP 2/10] Seeding plant types...")
        plant_types = seed_plant_types(session)
        
        # Seed sample plants for consumers
        print("\n[STEP 3/10] Creating sample plants...")
        plants = seed_sample_plants(session, consumers, plant_types)
        
        # Seed device types
        print("\n[STEP 4/10] Creating device types...")
        device_types = seed_device_types(session, manufacturer_profile)
        
        # Seed hubs for consumers
        print("\n[STEP 5/10] Creating hubs...")
        hubs = seed_hubs(session, consumers)
        
        # Seed hub metrics
        print("\n[STEP 6/10] Creating hub metrics...")
        seed_hub_metrics(session, hubs)
        
        # Seed devices
        print("\n[STEP 7/10] Creating devices...")
        devices = seed_devices(session, consumers, hubs, plants, device_types)
        
        # Seed sensor data
        print("\n[STEP 8/10] Creating sensor data...")
        seed_sensor_data(session, devices)
        
        # Seed alert rules
        print("\n[STEP 9/10] Creating alert rules...")
        alert_rules = seed_alert_rules(session, consumers, plants)
        
        # Seed alerts
        print("\n[STEP 10/10] Creating alerts...")
        seed_alerts(session, alert_rules)
        
        # Create plant-device assignments
        print("\n[BONUS] Creating plant-device assignments...")
        seed_plant_device_assignments(session, plants, devices)
        
        print("\n" + "=" * 60)
        print("[SUCCESS] Database seeding complete!")
        print("=" * 60)
        print("\n[INFO] Login credentials (password for all: " + DEFAULT_PASSWORD + "):")
        print(f"   Admin:        admin@plantmonitor.com")
        print(f"   Manufacturer: manufacturer@plantmonitor.com")
        print(f"   Consumers:    user1@example.com ... user5@example.com")
        print()
        print("[INFO] Seeded data summary:")
        print(f"   - {len(consumers)} consumer users")
        print(f"   - {len(plant_types)} plant types")
        print(f"   - {len(plants)} plants")
        print(f"   - {len(device_types)} device types")
        print(f"   - {len(hubs)} hubs")
        print(f"   - {len(devices)} devices")
        print(f"   - {len(alert_rules)} alert rules")
        print()
        
    except Exception as e:
        session.rollback()
        print(f"\n[ERROR] Error during seeding: {e}")
        raise
    finally:
        session.close()


if __name__ == "__main__":
    main()
