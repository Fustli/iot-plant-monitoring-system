#!/usr/bin/env python3
"""
Database Module Test Script
Tests that all imports and models are working correctly
"""

import sys
from pathlib import Path

# Add project root to path
sys.path.insert(0, str(Path(__file__).parent.parent))

def test_imports():
    """Test that all database modules can be imported"""
    print("\n🧪 Testing Database Module Imports\n")
    print("=" * 60)
    
    try:
        print("✓ Importing base...")
        from db.base import Base, AlertSeverityEnum, AlertStatusEnum
        print("  - Base class imported")
        print("  - DeviceType: SENSOR, ACTUATOR, COMBINED")
        print("  - AlertSeverityEnum: INFO, WARNING, CRITICAL")
        print("  - AlertStatusEnum: ACTIVE, ACKNOWLEDGED, RESOLVED")
        
        print("\n✓ Importing user models...")
        from db.user_models import User
        print("  - User model loaded")
        
        print("\n✓ Importing device models...")
        from db.device_models import Manufacturer, DeviceType, Device
        print("  - Manufacturer model loaded")
        print("  - DeviceType model loaded")
        print("  - Device model loaded")
        
        print("\n✓ Importing plant models...")
        from db.plant_models import PlantType, Plant, PlantDeviceAssignment
        print("  - PlantType model loaded")
        print("  - Plant model loaded")
        print("  - PlantDeviceAssignment model loaded")
        
        print("\n✓ Importing sensor models...")
        from db.sensor_models import SensorData
        print("  - SensorData model loaded")
        
        print("\n✓ Importing alert models...")
        from db.alert_models import Alert
        print("  - Alert model loaded")
        
        print("\n✓ Importing database utilities...")
        from db.db_utils import DBInterface, get_db_interface
        print("  - DBInterface class loaded")
        print("  - get_db_interface() loaded")
        
        print("\n✓ Importing from db package...")
        from db import (
            User, Manufacturer, DeviceType, Device,
            PlantType, Plant, PlantDeviceAssignment,
            SensorData, Alert,
            get_session, get_db_interface
        )
        print("  - All models accessible from db package")
        
        return True
        
    except Exception as e:
        print(f"\n✗ Import error: {e}")
        import traceback
        traceback.print_exc()
        return False


def test_db_interface():
    """Test DBInterface initialization"""
    print("\n" + "=" * 60)
    print("🧪 Testing DBInterface Initialization\n")
    
    try:
        from db.db_utils import DBInterface
        
        print("✓ Creating DBInterface instance...")
        db = DBInterface()
        
        print(f"  - Host: {db.DB_HOST}")
        print(f"  - Port: {db.DB_PORT}")
        print(f"  - User: {db.DB_USER}")
        print(f"  - Database: {db.DB_NAME}")
        
        print("\n✓ Getting database URL...")
        url = db.get_database_url()
        # Mask password
        masked_url = url.replace(db.DB_PASSWORD, "***")
        print(f"  - {masked_url}")
        
        print("\n✓ DBInterface initialized successfully!")
        return True
        
    except Exception as e:
        print(f"\n✗ DBInterface error: {e}")
        import traceback
        traceback.print_exc()
        return False


def test_models_structure():
    """Test that models have expected attributes"""
    print("\n" + "=" * 60)
    print("🧪 Testing Database Models Structure\n")
    
    try:
        from db import User, Plant, Device, SensorData
        
        print("✓ Checking User model...")
        assert hasattr(User, '__tablename__')
        print(f"  - Table name: {User.__tablename__}")
        
        print("\n✓ Checking Plant model...")
        assert hasattr(Plant, '__tablename__')
        print(f"  - Table name: {Plant.__tablename__}")
        
        print("\n✓ Checking Device model...")
        assert hasattr(Device, '__tablename__')
        print(f"  - Table name: {Device.__tablename__}")
        
        print("\n✓ Checking SensorData model...")
        assert hasattr(SensorData, '__tablename__')
        print(f"  - Table name: {SensorData.__tablename__}")
        
        print("\n✓ All models have correct structure!")
        return True
        
    except Exception as e:
        print(f"\n✗ Model structure error: {e}")
        import traceback
        traceback.print_exc()
        return False


def main():
    """Run all tests"""
    print("\n" + "🌱 " * 20)
    print("IoT Plant Monitoring System - Database Module Tests")
    print("🌱 " * 20)
    
    results = []
    
    # Run tests
    results.append(("Module Imports", test_imports()))
    results.append(("DBInterface", test_db_interface()))
    results.append(("Models Structure", test_models_structure()))
    
    # Print summary
    print("\n" + "=" * 60)
    print("📊 TEST SUMMARY\n")
    
    passed = sum(1 for _, result in results if result)
    total = len(results)
    
    for name, result in results:
        status = "✓ PASS" if result else "✗ FAIL"
        print(f"  {status}: {name}")
    
    print(f"\nTotal: {passed}/{total} tests passed")
    
    if passed == total:
        print("\n🎉 All tests passed! Database module is ready to use.")
        print("\n📝 Next steps:")
        print("   1. Install PostgreSQL")
        print("   2. Create database: python db/scripts/db_manager.py init")
        print("   3. Seed demo data: python db/scripts/db_manager.py seed")
        return 0
    else:
        print("\n⚠️  Some tests failed. Check the output above.")
        return 1


if __name__ == '__main__':
    sys.exit(main())
