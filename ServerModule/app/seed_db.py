"""
Database Seeder Script for IoT Plant Monitoring System

This script seeds the database with:
1. Admin user (admin@plantmonitor.local)
2. Test manufacturer user (manufacturer@plantmonitor.local)
3. Sample plant types (from Trefle API via TrefleScraper with fallback to hardcoded data)
4. Dummy consumer users

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
from src.db.base import Base
from src.db.user_models import User
from src.db.plant_models import PlantType, Plant
from src.db.device_models import Device, DeviceType, Manufacturer
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
            
            plant = Plant(
                user_id=user.id,
                plant_type_id=plant_type.id,
                plant_name=plant_name,
                location=random.choice(locations),
                planting_date=datetime.now() - timedelta(days=random.randint(30, 365)),
                is_healthy=random.choice([True, True, True, False]),  # 75% healthy
                health_status="Good" if random.random() > 0.25 else "Needs attention",
                notes=f"A lovely {plant_type.name} plant.",
            )
            session.add(plant)
            plants.append(plant)
    
    session.commit()
    print(f"[SUCCESS] Created {len(plants)} sample plants")
    return plants


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
        print("\n[STEP] Seeding users...")
        admin = seed_admin_user(session)
        manufacturer = seed_manufacturer_user(session)
        consumers = seed_dummy_users(session, count=5)
        
        # Seed plant types
        print("\n[STEP] Seeding plant types...")
        plant_types = seed_plant_types(session)
        
        # Seed sample plants for consumers
        print("\n[STEP] Creating sample plants...")
        seed_sample_plants(session, consumers, plant_types)
        
        print("\n" + "=" * 60)
        print("[SUCCESS] Database seeding complete!")
        print("=" * 60)
        print("\n[INFO] Login credentials (password for all: " + DEFAULT_PASSWORD + "):")
        print(f"   Admin:        admin@plantmonitor.com")
        print(f"   Manufacturer: manufacturer@plantmonitor.com")
        print(f"   Consumers:    user1@example.com ... user5@example.com")
        print()
        
    except Exception as e:
        session.rollback()
        print(f"\n[ERROR] Error during seeding: {e}")
        raise
    finally:
        session.close()


if __name__ == "__main__":
    main()
