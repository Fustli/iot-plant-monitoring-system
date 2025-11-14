#!/usr/bin/env python3
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

from db.db_utils import DBInterface
from db import User, Plant, SensorData


def example_orm_operations():
    print("\n" + "="*60)
    print("Example 1: ORM Operations")
    print("="*60)
    
    db = DBInterface()
    session = db.get_session()
    
    try:
        users = session.query(User).all()
        print(f"Total users: {len(users)}")
        
        user = session.query(User).filter_by(email='demo@example.com').first()
        if user:
            print(f"Found user: {user.username}")
            print(f"User's plants: {len(user.plants)}")
        
        session.close()
        
    except Exception as e:
        print(f"Error: {e}")
        session.close()


def example_raw_sql_operations():
    print("\n" + "="*60)
    print("Example 2: Raw SQL Operations")
    print("="*60)
    
    db = DBInterface()
    
    try:
        results = db.get_plant_details('Monstera Deliciosa')
        if results:
            print(f"Found {len(results)} plant(s) of type 'Monstera Deliciosa'")
        
        device_data = db.get_device_by_id(1)
        if device_data:
            print(f"Device found: {device_data}")
        
        rows_affected = db.insert_sensor_data(device_id=1, measurement_value=22.5, measurement_unit='°C')
        print(f"Inserted sensor data: {rows_affected} row(s) affected")
        
    except Exception as e:
        print(f"Error: {e}")


def example_context_manager():
    print("\n" + "="*60)
    print("Example 3: Context Manager (Manual SQL)")
    print("="*60)
    
    db = DBInterface()
    
    try:
        with db.connect_to_db() as (cur, conn):
            cur.execute("""
                SELECT id, plant_name, location 
                FROM plants 
                LIMIT 5
            """)
            
            plants = cur.fetchall()
            print(f"Found {len(plants)} plant(s):")
            for plant_id, plant_name, location in plants:
                print(f"  - {plant_name} ({location})")
    
    except Exception as e:
        print(f"Error: {e}")


def example_initialization():
    print("\n" + "="*60)
    print("Example 4: Database Initialization")
    print("="*60)
    
    db = DBInterface()
    
    success = db.init_db()
    if success:
        print("✓ Database initialized successfully!")
    else:
        print("✗ Failed to initialize database")


if __name__ == '__main__':
    print("\n🗄️  IoT Plant Monitoring - Database Usage Examples\n")
    
    try:
        example_initialization()
        example_orm_operations()
        example_raw_sql_operations()
        example_context_manager()
    except Exception as e:
        print(f"\n⚠️  Examples require database to be initialized first!")
        print(f"Error: {e}")

