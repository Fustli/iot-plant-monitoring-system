import os
import logging
import psycopg2
from contextlib import contextmanager

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from db.base import Base

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
                logger.info("✓ Successfully connected to database")
                cur = conn.cursor()
                yield cur, conn
                conn.commit()
                logger.info("✓ Committed changes to database")
        
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
                logger.info("✓ Closed database connection")
    
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
        query = """
            SELECT id, plant_name, min_temperature, max_temperature, 
                   min_humidity, max_humidity, min_soil_moisture, max_soil_moisture, 
                   min_light_intensity
            FROM plants 
            WHERE plant_type_id = (SELECT id FROM plant_types WHERE name = %s)
        """
        return self.execute_query(query, (plant_type,))
    
    def get_device_by_id(self, device_id: int):
        query = "SELECT * FROM devices WHERE id = %s"
        results = self.execute_query(query, (device_id,))
        return results[0] if results else None
    
    def insert_sensor_data(self, device_id: int, measurement_value: float, measurement_unit: str):
        query = """
            INSERT INTO sensor_data (device_id, measurement_value, measurement_unit, timestamp)
            VALUES (%s, %s, %s, NOW())
        """
        return self.execute_update(query, (device_id, measurement_value, measurement_unit))


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

