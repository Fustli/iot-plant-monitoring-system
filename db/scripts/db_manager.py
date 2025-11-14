#!/usr/bin/env python3
import os
import sys
from pathlib import Path
from datetime import datetime, timedelta
import argparse

sys.path.insert(0, str(Path(__file__).parent.parent))

from db.base import DeviceTypeEnum, AlertSeverityEnum, AlertStatusEnum
from db.user_models import User
from db.device_models import Manufacturer, DeviceType, Device
from db.plant_models import PlantType, Plant, PlantDeviceAssignment
from db.sensor_models import SensorData
from db.alert_models import AlertRule, Alert
from db.db_utils import DBInterface, get_session, init_db, drop_all_tables


def seed_demo_data(session):
    print("\n📊 Seeding demo data...")
    
    try:
        user = User(
            email='demo@example.com',
            username='demo_user',
            password_hash='$2b$12$demo_hashed_password',
            first_name='Demo',
            last_name='User',
            is_verified=True,
            is_active=True
        )
        session.add(user)
        session.flush()
        
        mfg_xiaomi = Manufacturer(
            name='Xiaomi',
            description='Xiaomi smart home devices',
            contact_email='support@xiaomi.com',
            website='https://www.xiaomi.com',
            is_verified=True
        )
        mfg_sonoff = Manufacturer(
            name='Sonoff',
            description='Sonoff IoT devices',
            contact_email='support@sonoff.tech',
            website='https://sonoff.tech',
            is_verified=True
        )
        session.add_all([mfg_xiaomi, mfg_sonoff])
        session.flush()
        
        thermometer = DeviceType(
            manufacturer_id=mfg_xiaomi.id,
            name='Smart Thermometer',
            device_type=DeviceTypeEnum.SENSOR,
            communication_interface='MQTT',
            supported_functions='read_temperature',
            data_unit='°C',
            min_value=-20,
            max_value=60,
            is_active=True
        )
        humidity_sensor = DeviceType(
            manufacturer_id=mfg_xiaomi.id,
            name='Humidity Sensor',
            device_type=DeviceTypeEnum.SENSOR,
            communication_interface='MQTT',
            supported_functions='read_humidity',
            data_unit='%',
            min_value=0,
            max_value=100,
            is_active=True
        )
        soil_moisture = DeviceType(
            manufacturer_id=mfg_sonoff.id,
            name='Soil Moisture Sensor',
            device_type=DeviceTypeEnum.SENSOR,
            communication_interface='MQTT',
            supported_functions='read_moisture',
            data_unit='%',
            min_value=0,
            max_value=100,
            is_active=True
        )
        light_meter = DeviceType(
            manufacturer_id=mfg_xiaomi.id,
            name='Light Meter',
            device_type=DeviceTypeEnum.SENSOR,
            communication_interface='MQTT',
            supported_functions='read_light_intensity',
            data_unit='lux',
            min_value=0,
            max_value=150000,
            is_active=True
        )
        pump = DeviceType(
            manufacturer_id=mfg_sonoff.id,
            name='Smart Pump',
            device_type=DeviceTypeEnum.ACTUATOR,
            communication_interface='MQTT',
            supported_functions='turn_on,turn_off,set_flow_rate',
            is_active=True
        )
        session.add_all([thermometer, humidity_sensor, soil_moisture, light_meter, pump])
        session.flush()
        
        device_temp = Device(
            user_id=user.id,
            device_type_id=thermometer.id,
            unique_identifier='xiaomi_temp_001',
            device_name='Living Room Thermometer',
            is_active=True,
            location_description='Living room shelf',
            battery_level=95
        )
        device_humidity = Device(
            user_id=user.id,
            device_type_id=humidity_sensor.id,
            unique_identifier='xiaomi_humidity_001',
            device_name='Living Room Humidity Sensor',
            is_active=True,
            location_description='Living room shelf',
            battery_level=92
        )
        device_moisture = Device(
            user_id=user.id,
            device_type_id=soil_moisture.id,
            unique_identifier='sonoff_moisture_001',
            device_name='Plant Moisture Sensor',
            is_active=True,
            location_description='In soil',
            battery_level=87
        )
        device_light = Device(
            user_id=user.id,
            device_type_id=light_meter.id,
            unique_identifier='xiaomi_light_001',
            device_name='Window Light Meter',
            is_active=True,
            location_description='Window sill',
            battery_level=98
        )
        device_pump = Device(
            user_id=user.id,
            device_type_id=pump.id,
            unique_identifier='sonoff_pump_001',
            device_name='Plant Watering Pump',
            is_active=True,
            location_description='Under sink',
        )
        session.add_all([device_temp, device_humidity, device_moisture, device_light, device_pump])
        session.flush()
        
        monstera = PlantType(
            name='Monstera Deliciosa',
            scientific_name='Monstera deliciosa',
            description='Climbing plant with large, heart-shaped leaves',
            optimal_temperature=22.5,
            optimal_humidity=72.5,
            optimal_light=1000,
            water_frequency_days=7
        )
        pothos = PlantType(
            name='Golden Pothos',
            scientific_name='Epipremnum aureum',
            description='Vining plant with golden leaves',
            optimal_temperature=20,
            optimal_humidity=65,
            optimal_light=500,
            water_frequency_days=7
        )
        snake_plant = PlantType(
            name='Snake Plant',
            scientific_name='Sansevieria trifasciata',
            description='Succulent with striped, upright leaves',
            optimal_temperature=21.5,
            optimal_humidity=47.5,
            optimal_light=300,
            water_frequency_days=14
        )
        session.add_all([monstera, pothos, snake_plant])
        session.flush()
        
        plant1 = Plant(
            user_id=user.id,
            plant_type_id=monstera.id,
            plant_name='My Monstera',
            location='Living room corner',
            notes='Recently propagated',
            last_watered=datetime.utcnow() - timedelta(days=3)
        )
        plant2 = Plant(
            user_id=user.id,
            plant_type_id=pothos.id,
            plant_name='Golden Pothos #1',
            location='Bedroom shelf',
            notes='Climbing the trellis nicely',
            last_watered=datetime.utcnow() - timedelta(days=5)
        )
        session.add_all([plant1, plant2])
        session.flush()
        
        for device, assignment_type in [
            (device_moisture, 'soil_moisture'),
            (device_temp, 'temperature'),
            (device_humidity, 'humidity'),
            (device_light, 'light'),
            (device_pump, 'pump')
        ]:
            assignment = PlantDeviceAssignment(
                plant_id=plant1.id,
                device_id=device.id,
                assignment_type=assignment_type
            )
            session.add(assignment)
        session.flush()
        
        now = datetime.utcnow()
        for i in range(30):
            session.add(SensorData(
                device_id=device_temp.id,
                measurement_value=22 + (i % 5) * 0.5,
                measurement_unit='°C',
                timestamp=now - timedelta(hours=30-i)
            ))
            session.add(SensorData(
                device_id=device_humidity.id,
                measurement_value=65 + (i % 7) * 2,
                measurement_unit='%',
                timestamp=now - timedelta(hours=30-i)
            ))
            session.add(SensorData(
                device_id=device_moisture.id,
                measurement_value=45 - (i * 0.5),
                measurement_unit='%',
                timestamp=now - timedelta(hours=30-i)
            ))
        session.flush()
        
        rule1 = AlertRule(
            user_id=user.id,
            plant_id=plant1.id,
            rule_name='Low Soil Moisture',
            rule_type='threshold',
            parameter_name='soil_moisture',
            condition_operator='<',
            threshold_value=25,
            severity=AlertSeverityEnum.WARNING,
            is_active=True
        )
        rule2 = AlertRule(
            user_id=user.id,
            plant_id=plant1.id,
            rule_name='Temperature Too Low',
            rule_type='threshold',
            parameter_name='temperature',
            condition_operator='<',
            threshold_value=15,
            severity=AlertSeverityEnum.CRITICAL,
            is_active=True
        )
        session.add_all([rule1, rule2])
        session.flush()
        
        alert = Alert(
            user_id=user.id,
            plant_id=plant1.id,
            rule_id=rule1.id,
            severity=AlertSeverityEnum.WARNING,
            status=AlertStatusEnum.ACTIVE,
            message='Soil moisture is critically low at 18%',
            triggered_value=18,
            threshold_value=25,
            triggered_at=datetime.utcnow()
        )
        session.add(alert)
        
        session.commit()
        print("✓ Demo data seeded successfully!")
        
    except Exception as e:
        session.rollback()
        print(f"✗ Error seeding demo data: {e}")
        raise


def print_database_info(session):
    print("\n📈 Database Statistics:")
    print(f"  Users: {session.query(User).count()}")
    print(f"  Manufacturers: {session.query(Manufacturer).count()}")
    print(f"  Device Types: {session.query(DeviceType).count()}")
    print(f"  Devices: {session.query(Device).count()}")
    print(f"  Plant Types: {session.query(PlantType).count()}")
    print(f"  Plants: {session.query(Plant).count()}")
    print(f"  Sensor Data Points: {session.query(SensorData).count()}")
    print(f"  Alert Rules: {session.query(AlertRule).count()}")
    print(f"  Alerts: {session.query(Alert).count()}")


def main():
    parser = argparse.ArgumentParser(
        description='IoT Plant Monitoring System - Database Management'
    )
    
    parser.add_argument(
        'action',
        choices=['init', 'seed', 'info', 'reset'],
        help='Database action to perform'
    )
    parser.add_argument('--host', default='localhost')
    parser.add_argument('--port', type=int, default=5432)
    parser.add_argument('--user', default='iot_user')
    parser.add_argument('--password', default='iot_password')
    parser.add_argument('--database', default='iot_plant_db')
    
    args = parser.parse_args()
    
    os.environ['POSTGRES_DB_HOST'] = args.host
    os.environ['POSTGRES_DB_PORT'] = str(args.port)
    os.environ['POSTGRES_DB_USER'] = args.user
    os.environ['POSTGRES_DB_PASSWORD'] = args.password
    os.environ['POSTGRES_DB_NAME'] = args.database
    
    print("🌱 IoT Plant Monitoring System - Database Manager")
    print(f"📍 Database URL: postgresql://{args.user}:***@{args.host}:{args.port}/{args.database}")
    
    db = DBInterface()
    
    try:
        if args.action == 'init':
            print("\n🔧 Initializing database...")
            db.init_db()
            
        elif args.action == 'seed':
            print("\n🌿 Seeding database with demo data...")
            session = db.get_session()
            seed_demo_data(session)
            session.close()
            
        elif args.action == 'info':
            print("\n📊 Fetching database information...")
            session = db.get_session()
            print_database_info(session)
            session.close()
            
        elif args.action == 'reset':
            print("\n⚠️  WARNING: This will drop all tables and data!")
            confirm = input("Type 'YES' to confirm: ")
            if confirm.lower() == 'yes':
                db.drop_all_tables()
                print("🔧 Reinitializing database...")
                db.init_db()
                print("✓ Database reset complete!")
            else:
                print("✗ Reset cancelled")
    
    except Exception as e:
        print(f"\n✗ Error: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == '__main__':
    main()
