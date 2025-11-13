import os
import logging
import psycopg2
from psycopg2._psycopg import cursor
from contextlib import contextmanager

from measurements import Brightness, Moisture


class DBInterface:
    def __init__(self):
        self.DB_USER = os.environ.get("POSTGRES_DB_USER", "admin")
        self.DB_PASSWORD = os.environ.get("POSTGRES_DB_PASSWORD", "admin")
        self.DB_PORT = os.environ.get("POSTGRES_DB_PORT", "5432")
        self.DB_HOST = os.environ.get("POSTGRES_DB_HOST", "localhost")
        self.DB_NAME = os.environ.get("POSTGRES_DB_NAME", "plant_database")

    @contextmanager
    def connect_to_db(self):
        cur, conn = None, None
        try:
            conn = psycopg2.connect(
                f"dbname={self.DB_NAME} user={self.DB_USER} password={self.DB_PASSWORD} port={self.DB_PORT} host={self.DB_HOST}"
            )

            if conn.closed == 0:
                logging.info("Successfully connected to database.")
                cur = conn.cursor()

                yield cur, conn

                conn.commit()
                logging.info("Commited changes to the database.")
                conn.close()
                logging.info("Closed database connection.")
        except ConnectionError:
            logging.error("Connection error.")
        finally:
            if cur:
                cur.close()
            if conn and conn.closed == 0:
                conn.close()
                logging.info("Closed database connection.")

    def get_plant_details(self, plant_type: str) -> tuple[Brightness, float, float, Moisture]:
        """Unfinished as we don't yet know the database structure."""
        with self.connect_to_db as (cur, conn):
            cur: cursor

            cur.execute(
                F"SELECT * FROM plants WHERE plant_type={plant_type}"
            )

            results = cur.fetchall()
            # Here we need to process and format the results

            return results
