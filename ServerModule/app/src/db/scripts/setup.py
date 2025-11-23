#!/usr/bin/env python3
"""
Database Setup Script
Automated setup for PostgreSQL and database initialization
Run this after installing dependencies: pip install -r db/requirements.txt
"""

import subprocess
import sys
import os
from pathlib import Path

# Add the project root to Python path
project_root = Path(__file__).parent.parent.parent
sys.path.insert(0, str(project_root))

# Also add the db directory to handle relative imports
db_root = Path(__file__).parent.parent
sys.path.insert(0, str(db_root))


def print_header(text):
    """Print formatted header"""
    print(f"\n{'='*60}")
    print(f"  {text}")
    print(f"{'='*60}\n")


def print_step(step_num, text):
    """Print formatted step"""
    print(f"\n[Step {step_num}] {text}")
    print("-" * 40)


def check_postgresql():
    """Check if PostgreSQL is installed"""
    print_step(1, "Checking PostgreSQL installation")
    try:
        result = subprocess.run(['psql', '--version'], capture_output=True, text=True)
        print(f"✓ PostgreSQL found: {result.stdout.strip()}")
        return True
    except FileNotFoundError:
        print("✗ PostgreSQL not found. Please install PostgreSQL first.")
        print("  Ubuntu/Debian: sudo apt-get install postgresql")
        print("  macOS: brew install postgresql")
        print("  Windows: https://www.postgresql.org/download/windows/")
        return False


def check_python_dependencies():
    """Check if Python dependencies are installed"""
    print_step(2, "Checking Python dependencies")
    try:
        import sqlalchemy
        import psycopg2
        print(f"✓ SQLAlchemy {sqlalchemy.__version__} found")
        print(f"✓ psycopg2 {psycopg2.__version__} found")
        return True
    except ImportError as e:
        print(f"✗ Missing dependency: {e}")
        print("  Run: pip install -r db/requirements.txt")
        return False


def create_postgresql_user_and_db(host='localhost', user='iot_user', password='iot_password', database='iot_plant_db'):
    """Create PostgreSQL user and database"""
    print_step(3, "Creating PostgreSQL user and database")
    
    print(f"Configuration:")
    print(f"  Host: {host}")
    print(f"  Database: {database}")
    print(f"  User: {user}")
    print(f"  Password: {'*' * len(password)}")
    
    try:
        # Check if database exists
        check_cmd = f"psql -h {host} -U postgres -lqt | grep -c {database}"
        result = subprocess.run(check_cmd, shell=True, capture_output=True)
        
        if result.returncode == 0 and int(result.stdout.strip()) > 0:
            print(f"✓ Database '{database}' already exists")
        else:
            print(f"  Creating database '{database}'...")
            subprocess.run(
                f"createdb -h {host} -U postgres {database}",
                shell=True,
                check=True,
                capture_output=True
            )
            print(f"  ✓ Database created")
        
        # Check if user exists
        check_user_cmd = f"psql -h {host} -U postgres -t -c \"SELECT 1 FROM pg_roles WHERE rolname='{user}'\" | grep -c 1"
        result = subprocess.run(check_user_cmd, shell=True, capture_output=True)
        
        if result.returncode == 0 and int(result.stdout.strip()) > 0:
            print(f"✓ User '{user}' already exists")
        else:
            print(f"  Creating user '{user}'...")
            create_user_cmd = f"psql -h {host} -U postgres -c \"CREATE USER {user} WITH PASSWORD '{password}'\""
            subprocess.run(create_user_cmd, shell=True, check=True, capture_output=True)
            print(f"  ✓ User created")
        
        # Grant privileges
        print(f"  Granting privileges...")
        grant_cmd = f"psql -h {host} -U postgres -c \"GRANT ALL PRIVILEGES ON DATABASE {database} TO {user}\""
        subprocess.run(grant_cmd, shell=True, check=True, capture_output=True)
        print(f"  ✓ Privileges granted")
        
        return True
        
    except subprocess.CalledProcessError as e:
        print(f"✗ Error creating database/user: {e}")
        print("  You may need to run this script with sudo or as postgres user")
        print("  Alternative: Create manually with:")
        print(f"    createdb {database}")
        print(f"    createuser {user}")
        print(f"    psql -U postgres -c \"ALTER USER {user} WITH PASSWORD '{password}'\"")
        print(f"    psql -U postgres -c \"GRANT ALL PRIVILEGES ON DATABASE {database} TO {user}\"")
        return False


def create_env_file():
    """Create .env file from template"""
    print_step(4, "Creating .env configuration file")
    
    env_template = Path(__file__).parent / '.env.example'
    env_file = Path(__file__).parent / '.env'
    
    if env_file.exists():
        print("✓ .env file already exists")
        return True
    
    try:
        import shutil
        shutil.copy(env_template, env_file)
        print(f"✓ Created .env file from template")
        print(f"  Location: {env_file}")
        return True
    except Exception as e:
        print(f"✗ Error creating .env file: {e}")
        return False


def initialize_database():
    """Initialize database schema"""
    print_step(5, "Initializing database schema")
    
    try:
        from db.db_utils import DBInterface
        
        db = DBInterface()
        print(f"Connecting to: {db.get_database_url()}")
        db.init_db()
        print("✓ Database schema initialized successfully!")
        return True
        
    except Exception as e:
        print(f"✗ Error initializing database: {e}")
        import traceback
        traceback.print_exc()
        return False


def seed_demo_data():
    """Optionally seed demo data"""
    print_step(6, "Seeding demo data (optional)")
    
    response = input("Do you want to seed demo data? (y/n): ").strip().lower()
    
    if response != 'y':
        print("Skipping demo data seeding")
        return True
    
    try:
        from db.db_utils import DBInterface
        from db.scripts.examples import seed_demo_data as seed
        
        db = DBInterface()
        session = db.get_session()
        seed(session)
        session.close()
        print("✓ Demo data seeded successfully!")
        return True
        
    except Exception as e:
        print(f"✗ Error seeding demo data: {e}")
        import traceback
        traceback.print_exc()
        return False


def main():
    """Main setup flow"""
    print_header("IoT Plant Monitoring System - Database Setup")
    
    steps = [
        ("PostgreSQL Installation", check_postgresql),
        ("Python Dependencies", check_python_dependencies),
        ("PostgreSQL User & Database", lambda: create_postgresql_user_and_db()),
        (".env Configuration", create_env_file),
        ("Database Schema", initialize_database),
        ("Demo Data", seed_demo_data),
    ]
    
    success_count = 0
    failed_steps = []
    
    for step_name, step_func in steps:
        try:
            if step_func():
                success_count += 1
            else:
                failed_steps.append(step_name)
        except Exception as e:
            print(f"✗ Unexpected error in {step_name}: {e}")
            failed_steps.append(step_name)
    
    # Summary
    print_header("Setup Summary")
    print(f"✓ Completed: {success_count}/{len(steps)} steps")
    
    if failed_steps:
        print(f"✗ Failed steps: {', '.join(failed_steps)}")
        print("\nPlease fix the errors above and try again.")
        return 1
    else:
        print("\n🎉 Database setup completed successfully!")
        print("\nNext steps:")
        print("  1. Start your PostgreSQL server (if not already running)")
        print("  2. Test the connection: python db/scripts/db_manager.py info")
        print("  3. View database info: python db/scripts/db_manager.py info")
        print("\nFor more information, see db/README.md")
        return 0


if __name__ == '__main__':
    sys.exit(main())
