import os
import logging
import psycopg2
import datetime
from contextlib import contextmanager

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from src.db.base import Base, AlertSeverityEnum, AlertStatusEnum
from src.db.alert_models import Alert

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
    
    def get_plant_details_by_sci_name(self, scientific_name: str):
        query = """
            SELECT id, name, scientific_name, optimal_temperature, optimal_humidity, optimal_light, optimal_moisture, description, care_instructions
            FROM plant_types
            WHERE scientific_name = %s
        """
        result = self.execute_query(query, (scientific_name,))

        return result[0] if result else None
    
    def get_plant_details_by_name(self, name: str):
        query = """
            SELECT id, name, scientific_name, optimal_temperature, optimal_humidity, optimal_light, optimal_moisture, description, care_instructions
            FROM plant_types
            WHERE name = %s
        """
        result = self.execute_query(query, (name,))

        return result[0] if result else None
    
    def get_device_by_id(self, device_id: int):
        """
        Return a device record as a dict with explicit columns.
        """
        query = """
            SELECT id, user_id, hub_id, plant_id, device_type_id, unique_identifier, 
                   device_name, is_active, last_data_received, last_heartbeat, 
                   location_description, battery_level, rssi, created_at, updated_at
            FROM devices WHERE id = %s
        """
        results = self.execute_query(query, (device_id,))
        if not results:
            return None
        r = results[0]
        return {
            "id": r[0],
            "user_id": r[1],
            "hub_id": r[2],
            "plant_id": r[3],
            "device_type_id": r[4],
            "unique_identifier": r[5],
            "device_name": r[6],
            "is_active": r[7],
            "last_data_received": r[8],
            "last_heartbeat": r[9],
            "location_description": r[10],
            "battery_level": r[11],
            "rssi": r[12],
            "created_at": r[13],
            "updated_at": r[14],
        }
    
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
            hub_id: int | None = None,
            is_active: bool = False, 
            last_data_received: str | None = None, 
            last_heartbeat: str | None = None, 
            location_description: str | None = None, 
            battery_level: float | None = None, 
            rssi: str | None = None
        ):
        query = """
            INSERT INTO devices (user_id, hub_id, plant_id, device_type_id, unique_identifier, device_name, is_active, last_data_received, last_heartbeat, location_description, battery_level, rssi, created_at, updated_at)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, NOW(), NOW())
        """
        self.execute_update(query, (
            user_id,
            hub_id,
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

    # ------------------ Hubs ------------------
    def register_hub(
        self,
        user_id: int | None,
        serial: str,
        name: str | None = None,
        is_active: bool = False,
        iothub_device_id: str | None = None,
        iothub_connection_string: str | None = None,
    ):
        """
        Register a hub record. When called by admin to pre-provision a hub,
        pass user_id=None and is_active=False. When called to claim a hub,
        pass user_id and leave is_active as-is.
        """
        query = """
            INSERT INTO hubs (user_id, serial, name, is_active, iothub_device_id, iothub_connection_string, created_at, updated_at)
            VALUES (%s, %s, %s, %s, %s, %s, NOW(), NOW())
        """
        try:
            self.execute_update(query, (user_id, serial, name, is_active, iothub_device_id, iothub_connection_string))
        except Exception:
            raise
        # return hub id
        return self.get_hub_by_serial(serial)

    def claim_hub_by_serial(self, serial: str, user_id: int):
        """
        Assign an existing hub to a user (claim). Returns number of rows updated.
        """
        query = "UPDATE hubs SET user_id = %s, updated_at = NOW() WHERE serial = %s AND (user_id IS NULL OR user_id = %s)"
        return self.execute_update(query, (user_id, serial, user_id))

    def activate_hub(self, serial: str, iothub_device_id: str | None = None, iothub_connection_string: str | None = None):
        """
        Mark a hub as active when the physical hub calls the activation endpoint.
        If the hub does not exist, create a new hub record in active state.
        """
        # Try to update existing hub
        try:
            params = [True, serial]
            query = "UPDATE hubs SET is_active = %s, last_seen = NOW(), updated_at = NOW() WHERE serial = %s"
            rows = self.execute_update(query, tuple(params))
            if rows and (iothub_device_id or iothub_connection_string):
                # update IoT Hub fields separately
                upd = "UPDATE hubs SET iothub_device_id = %s, iothub_connection_string = %s WHERE serial = %s"
                self.execute_update(upd, (iothub_device_id, iothub_connection_string, serial))
            if rows:
                return True

            # If not found, insert a new active hub record (unclaimed)
            insert = "INSERT INTO hubs (user_id, serial, name, is_active, iothub_device_id, iothub_connection_string, created_at, updated_at) VALUES (NULL, %s, NULL, %s, %s, %s, NOW(), NOW())"
            self.execute_update(insert, (serial, True, iothub_device_id, iothub_connection_string))
            return True
        except Exception:
            raise

    def get_hub_by_serial(self, serial: str):
        query = "SELECT id FROM hubs WHERE serial = %s"
        results = self.execute_query(query, (serial,))
        return results[0][0] if results else None

    def get_hub(self, hub_id: int):
        """
        Return a hub record as a dict with explicit columns to keep order stable.
        """
        query = """
            SELECT id, user_id, serial, iothub_device_id, iothub_connection_string, name, last_seen, status, is_active, created_at, updated_at
            FROM hubs WHERE id = %s
        """
        results = self.execute_query(query, (hub_id,))
        if not results:
            return None
        r = results[0]
        return {
            "id": r[0],
            "user_id": r[1],
            "serial": r[2],
            "iothub_device_id": r[3],
            "iothub_connection_string": r[4],
            "name": r[5],
            "last_seen": r[6],
            "status": r[7],
            "is_active": r[8],
            "created_at": r[9],
            "updated_at": r[10],
        }

    def list_hubs(self, user_id: int | None = None):
        constraint = ""
        params = None
        if user_id is not None:
            constraint = "WHERE user_id = %s"
            params = (user_id,)
        query = f"SELECT id, user_id, serial, iothub_device_id, iothub_connection_string, name, last_seen, status, is_active, created_at, updated_at FROM hubs {constraint}"
        results = self.execute_query(query, params) if params else self.execute_query(query)
        if not results:
            return None
        hubs = []
        for r in results:
            hubs.append({
                "id": r[0],
                "user_id": r[1],
                "serial": r[2],
                "iothub_device_id": r[3],
                "iothub_connection_string": r[4],
                "name": r[5],
                "last_seen": r[6],
                "status": r[7],
                "is_active": r[8],
                "created_at": r[9],
                "updated_at": r[10],
            })
        return hubs

    # Previously we had a hub_commands queue implementation (polling). That
    # has been removed in favor of invoking hub methods directly via Azure IoT
    # service APIs (direct method invocation). Keeping DB layer free of queue
    # helpers to avoid accidental use.
    
    def get_device_type_id(self, name: str):
        query = """
            SELECT id FROM device_types WHERE name = %s
        """

        results = self.execute_query(query, (name, ))

        return results[0][0] if results else None
    
    def get_plant_by_id(self, plant_id: int):
        query = """
            SELECT p.*, pt.optimal_temperature, pt.optimal_humidity, pt.optimal_light, pt.optimal_moisture
            FROM plants p
            LEFT JOIN plant_types pt ON p.plant_type_id = pt.id
            WHERE p.id = %s
        """

        results = self.execute_query(query, (plant_id, ))

        return results[0] if results else None

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
    
    def list_device_types(self, manufacturer_id: int = None):
        constraint = ""
        params = None
        if manufacturer_id is not None:
            constraint = "WHERE manufacturer_id = %s"
            params = (manufacturer_id,)
        query = f"SELECT * FROM device_types {constraint}"
        results = self.execute_query(query, params) if params else self.execute_query(query)
        return results if results else None

    def list_devices(self, user_id: int = None):
        constraint = ""
        params = None
        if user_id is not None:
            constraint = "WHERE user_id = %s"
            params = (user_id,)
        query = f"SELECT * FROM devices {constraint}"
        results = self.execute_query(query, params) if params else self.execute_query(query)
        return results if results else None

    def list_plants(self, user_id: int = None):
        constraint = ""
        params = None
        if user_id is not None:
            constraint = "WHERE p.user_id = %s"
            params = (user_id,)
        query = f"""
            SELECT p.*, pt.optimal_temperature, pt.optimal_humidity, pt.optimal_light, pt.optimal_moisture
            FROM plants p
            LEFT JOIN plant_types pt ON p.plant_type_id = pt.id
            {constraint}
        """
        results = self.execute_query(query, params) if params else self.execute_query(query)
        return results if results else None

    def list_users(self, user_id: int = None):
        constraint = ""
        params = None
        if user_id is not None:
            constraint = "WHERE id = %s"
            params = (user_id,)
        query = f"SELECT * FROM users {constraint}"
        results = self.execute_query(query, params) if params else self.execute_query(query)
        return results if results else None

    def list_manufacturers(self, manufacturer_id: int = None):
        constraint = ""
        params = None
        if manufacturer_id is not None:
            constraint = "WHERE id = %s"
            params = (manufacturer_id,)
        query = f"SELECT * FROM manufacturers {constraint}"
        results = self.execute_query(query, params) if params else self.execute_query(query)
        return results if results else None

    def list_plant_types(self):
        query = "SELECT * FROM plant_types"
        results = self.execute_query(query)
        return results if results else None

    def list_consumers(self):
        query = "SELECT * FROM users WHERE role = 'consumer'"
        results = self.execute_query(query)
        return results if results else None

    def remove_user(self, user_id: int):
        query = "DELETE FROM users WHERE id = %s"
        rows = self.execute_update(query, (user_id,))
        return rows > 0

    def remove_manufacturer(self, manufacturer_id: int):
        query = "DELETE FROM manufacturers WHERE id = %s"
        rows = self.execute_update(query, (manufacturer_id,))
        return rows > 0

    def remove_plant_type(self, plant_type_id: int):
        query = "DELETE FROM plant_types WHERE id = %s"
        rows = self.execute_update(query, (plant_type_id,))
        return rows > 0

    def remove_plant(self, plant_id: int):
        query = "DELETE FROM plants WHERE id = %s"
        rows = self.execute_update(query, (plant_id,))
        return rows > 0
    
    def remove_device(self, device_id: int):
        query = "DELETE FROM devices WHERE id = %s"
        rows = self.execute_update(query, (device_id,))
        return rows > 0

    def remove_hub(self, hub_id: int):
        """
        Remove a hub record by id. Returns True if a row was deleted.
        """
        query = "DELETE FROM hubs WHERE id = %s"
        rows = self.execute_update(query, (hub_id,))
        return rows > 0
    
    def get_plant_type_requirements(self, plant_type_id: int):
        """
        Return (optimal_temperature, optimal_humidity, optimal_light, optimal_moisture)
        for a given plant_type_id.
        """
        query = """
            SELECT optimal_temperature, optimal_humidity, optimal_light, optimal_moisture
            FROM plant_types
            WHERE id = %s
        """
        results = self.execute_query(query, (plant_type_id,))
        return results[0] if results else None
    
    def set_device_active_state(self, device_id: int, is_active: bool):
        """
        Toggle the is_active flag of a device.
        """
        query = """
            UPDATE devices
            SET is_active = %s, updated_at = NOW()
            WHERE id = %s
        """
        return self.execute_update(query, (is_active, device_id))
    
    def put_alert(
        self,
        user_id: int,
        plant_id: int,
        severity: AlertSeverityEnum,
        status: AlertStatusEnum,
        message: str,
        triggered_metric: float,
        threshold_value: float,
    ):
        session = get_session()
        alert = Alert(
            user_id=user_id,
            plant_id=plant_id,
            severity=severity,
            status=status,
            message=message,
            triggered_metric=triggered_metric,
            threshold_value=threshold_value,
            triggered_at=datetime.datetime.utcnow(),
            acknowledged_at=None,
            resolved_at=None,
            created_at=datetime.datetime.utcnow(),
            updated_at=datetime.datetime.utcnow(),
        )

        session.add(alert)
        session.commit()
        return alert


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
    return_value = db_interface.list_manufacturers(1)
    print(return_value)