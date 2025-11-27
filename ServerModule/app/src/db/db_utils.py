import os
import logging
import psycopg2
from contextlib import contextmanager

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from src.db.base import Base

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class DBInterface:
    def __init__(self):
        self.DB_HOST = os.environ.get("POSTGRES_DB_HOST", "localhost")
        self.DB_PORT = os.environ.get("POSTGRES_DB_PORT", "5432")
        self.DB_USER = os.environ.get("POSTGRES_DB_USER", "iot_user")
        self.DB_PASSWORD = os.environ.get("POSTGRES_DB_PASSWORD", "iot_password")
        self.DB_NAME = os.environ.get("POSTGRES_DB_NAME", "iot_plant_db")
        
        self._engine = None
        self._session_factory = None
    
    @property
    def engine(self):
        if self._engine is None:
            self._engine = self._create_engine()
        return self._engine
    
    @property
    def session_factory(self):
        if self._session_factory is None:
            self._session_factory = sessionmaker(bind=self.engine)
        return self._session_factory
    
    def _create_engine(self):
        # Connection pooling configured for production use
        database_url = f'postgresql://{self.DB_USER}:{self.DB_PASSWORD}@{self.DB_HOST}:{self.DB_PORT}/{self.DB_NAME}'
        return create_engine(
            database_url,
            echo=False,
            pool_pre_ping=True,
            pool_recycle=3600,
            pool_size=10,
            max_overflow=20
        )
    
    def get_database_url(self):
        return f'postgresql://{self.DB_USER}:{self.DB_PASSWORD}@{self.DB_HOST}:{self.DB_PORT}/{self.DB_NAME}'
    
    def get_session(self):
        return self.session_factory()
    
    def init_db(self):
        try:
            Base.metadata.create_all(self.engine)
            logger.info("✓ Database schema initialized successfully!")
            return True
        except Exception as e:
            logger.error(f"✗ Error initializing database: {e}")
            return False
    
    def drop_all_tables(self):
        try:
            Base.metadata.drop_all(self.engine)
            logger.info("✓ All tables dropped successfully!")
            return True
        except Exception as e:
            logger.error(f"✗ Error dropping tables: {e}")
            return False
    
    @contextmanager
    def connect_to_db(self):
        # Context manager for raw psycopg2 connections with automatic cleanup
        cur = None
        conn = None
        try:
            conn = psycopg2.connect(
                dbname=self.DB_NAME,
                user=self.DB_USER,
                password=self.DB_PASSWORD,
                port=self.DB_PORT,
                host=self.DB_HOST
            )
            
            if conn.closed == 0:
                # logger.info("✓ Successfully connected to database")
                cur = conn.cursor()
                yield cur, conn
                conn.commit()
                # logger.info("✓ Committed changes to database")
        
        except psycopg2.DatabaseError as e:
            logger.error(f"✗ Database error: {e}")
            if conn:
                conn.rollback()
            raise
        
        except Exception as e:
            logger.error(f"✗ Connection error: {e}")
            raise
        
        finally:
            if cur:
                cur.close()
            if conn and conn.closed == 0:
                conn.close()
                # logger.info("✓ Closed database connection")
    
    def execute_query(self, query: str, params=None):
        with self.connect_to_db() as (cur, conn):
            if params:
                cur.execute(query, params)
            else:
                cur.execute(query)
            return cur.fetchall()
    
    def execute_update(self, query: str, params=None):
        with self.connect_to_db() as (cur, conn):
            if params:
                cur.execute(query, params)
            else:
                cur.execute(query)
            return cur.rowcount
    
    def get_plant_details(self, plant_type: str):
        query = f"""
            SELECT id, name, scientific_name, optimal_temperature, optimal_humidity, optimal_light, optimal_moisture, description, care_instructions
            FROM plant_types
            WHERE scientific_name = '{plant_type}'
        """
        result = self.execute_query(query, (plant_type,))

        return result[0] if result else None
    
    def get_device_by_id(self, device_id: int):
        query = "SELECT * FROM devices WHERE id = %s"
        results = self.execute_query(query, (device_id,))
        return results[0] if results else None
    
    def get_device_by_name(self, device_name: str):
        query = "SELECT manufacturer_id, name, device_type, description, communication_interface, supported_functions, data_unit, min_value, max_value, is_active FROM device_types WHERE name = %s"
        results = self.execute_query(query, (device_name,))
        return results[0] if results else None
    
    def insert_sensor_data(self, device_id: int, measurement_value: float, measurement_unit: str):
        query = """
            INSERT INTO sensor_data (device_id, measurement_value, measurement_unit, timestamp)
            VALUES (%s, %s, %s, NOW())
        """
        return self.execute_update(query, (device_id, measurement_value, measurement_unit))

    def register_new_device_type(
            self, 
            manufacturer_id: str, 
            name: str, 
            device_type: str, 
            communication_interface: str, 
            supported_functions: str, 
            data_unit: str, 
            min_value: float, 
            max_value: float, 
            is_active: bool,
            description: str | None = None, 
        ):

        query = """
            INSERT INTO device_types (manufacturer_id, name, device_type, description, communication_interface, supported_functions, data_unit, min_value, max_value, is_active, created_at, updated_at)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, NOW(), NOW())
        """
        self.execute_update(query, (
            manufacturer_id, 
            name, 
            device_type, 
            description, 
            communication_interface, 
            supported_functions, 
            data_unit, 
            min_value, 
            max_value, 
            is_active
        ))

        return self.get_device_type_id(name)
    
    def register_new_device(
            self, 
            user_id: int,   
            plant_id: int,
            device_type_id: int, 
            unique_identifier: str, 
            device_name: str, 
            is_active: bool = False, 
            last_data_received: str | None = None, 
            last_heartbeat: str | None = None, 
            location_description: str | None = None, 
            battery_level: float | None = None, 
            rssi: str | None = None
        ):
        query = """
            INSERT INTO devices (user_id, plant_id, device_type_id, unique_identifier, device_name, is_active, last_data_received, last_heartbeat, location_description, battery_level, rssi, created_at, updated_at)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, NOW(), NOW())
        """
        self.execute_update(query, (
            user_id, 
            plant_id,
            device_type_id, 
            unique_identifier, 
            device_name, 
            is_active, 
            last_data_received, 
            last_heartbeat, 
            location_description, 
            battery_level, 
            rssi
        ))

        return self.get_device_id(unique_identifier)
    
    def get_plant_type_id(self, scientific_name: str):
        query = """
            SELECT id FROM plant_types WHERE scientific_name = %s
        """

        results = self.execute_query(query, (scientific_name, ))

        return results[0][0] if results else None
    
    def get_plant_id(self, plant_name: str):
        query = """
            SELECT id FROM plants WHERE plant_name = %s
        """

        results = self.execute_query(query, (plant_name, ))

        return results[0][0] if results else None
    
    def register_new_plant_type(
        self, 
        name: str, 
        scientific_name: str, 
        optimal_temperature: float, 
        optimal_humidity: float, 
        optimal_light: float, 
        optimal_moisture: float, 
        description: str | None = None, 
        care_instructions: str | None = None,
    ):
        query = """
            INSERT INTO plant_types (name, scientific_name, optimal_temperature, optimal_humidity, optimal_light, optimal_moisture, description, care_instructions, created_at, updated_at)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, NOW(), NOW())
        """
        self.execute_update(query, (
            name, 
            scientific_name,
            optimal_temperature,
            optimal_humidity,
            optimal_light,
            optimal_moisture,
            description,
            care_instructions,
        ))

        return self.get_plant_type_id(scientific_name)
    
    def register_new_plant(
        self,
        user_id: int, 
        plant_type_id: str, 
        plant_name: str, 
        is_healthy: bool, 
        location: str | None = None, 
        planting_date: str | None = None, 
        health_status: str | None = None, 
        notes: str | None = None,
    ):
        query = """
            INSERT INTO plants (user_id, plant_type_id, plant_name, location, planting_date, is_healthy, health_status, notes, created_at, updated_at)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, NOW(), NOW())
        """
        self.execute_update(query, (
            user_id, 
            plant_type_id, 
            plant_name, 
            location, 
            planting_date, 
            is_healthy, 
            health_status, 
            notes,
        ))

        return self.get_plant_id(plant_name)
    
    def get_device_capabilities(self, device_type_id: str):
        query = """
            SELECT supported_functions FROM device_types WHERE id = %s
        """

        results = self.execute_query(query, (device_type_id, ))

        return results[0][0] if results else None
    
    def get_device_id(self, unique_identifier: str):
        query = """
            SELECT id FROM devices WHERE unique_identifier = %s
        """

        results = self.execute_query(query, (unique_identifier, ))

        return results[0][0] if results else None
    
    def get_device_type_id(self, name: str):
        query = """
            SELECT id FROM device_types WHERE name = %s
        """

        results = self.execute_query(query, (name, ))

        return results[0][0] if results else None
    
    def get_plant_details_by_id(self, plant_id: int):
        query = """
            SELECT user_id, plant_name FROM plants WHERE id = %s
        """

        results = self.execute_query(query, (plant_id, ))

        return results[0] if results else None
    
    def get_plant_user_id_by_name(self, plant_name: str):
        query = """
            SELECT user_id FROM plants WHERE plant_name = %s
        """

        results = self.execute_query(query, (plant_name, ))

        return results[0][0] if results else None
    
    def get_user_details_by_id(self, user_id: int):
        query = """
            SELECT email, username FROM users WHERE id = %s
        """

        results = self.execute_query(query, (user_id, ))

        return results[0] if results else None


_db_interface = None


def get_db_interface():
    global _db_interface
    if _db_interface is None:
        _db_interface = DBInterface()
    return _db_interface


def get_session():
    return get_db_interface().get_session()


def get_database_url():
    return get_db_interface().get_database_url()


def create_engine_instance():
    return get_db_interface().engine


def init_db():
    return get_db_interface().init_db()


def drop_all_tables():
    return get_db_interface().drop_all_tables()


if __name__ == "__main__":
    db_interface = DBInterface()
    return_value = db_interface.get_device_capabilities("Xiaomi Moisture Deluxe")
    print(return_value)