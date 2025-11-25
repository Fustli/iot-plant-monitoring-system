from abc import ABC, abstractmethod

from plants import Plant
from devices import Device
from db.db_utils import DBInterface
from logger import Logger
from measurements import Moisture

class User(ABC):
    def __init__(self, id: str, username: str):
        self.id = id
        self.username = username
        self.logger = Logger(name=username)
        


class Manufacturer(User):
    def __init__(self, id: str, username: str):
        super().__init__(id, username)

    def register_new_device_type(
        self, 
    ):
        db_interface = DBInterface()
        # Create new device in device_types
        


class Consumer(User):
    def __init__(self, id: str, username: str, email_address: str):
        super().__init__(id, username)
        self.plants: list[Plant] = []
        self.email_address = email_address

    def register_plant(
        self,
        name: str,
        scientific_name: str,
        req_brightness: float,
        req_humidity: float,
        req_temperature: float,
        req_moisture: int,
        description: str = None,
        care_instructions: str = None,
        location: str | None = None,
        is_healthy: bool = True,
        health_status: str | None = None,
        notes: str | None = None,
    ):
        """Attach Plant to User."""
        plant = Plant.from_scratch(
            name, self.id, scientific_name,
            req_brightness, req_humidity, 
            req_temperature, req_moisture,
            description, care_instructions,
            location, is_healthy, health_status, notes

        )
        self.plants.append(plant)

    def register_plant_from_database(
        self, 
        name: str, 
        scientific_name: str,
        is_healthy: bool = True,
        location: str | None = None,
        health_status: str | None = None,
        notes: str | None = None,
    ):
        """Attach Plant to User."""
        plant = Plant.from_database(
            self.id, name, scientific_name, 
            is_healthy, location, health_status, notes
        )
        self.plants.append(plant)

    def get_plants(self) -> list[Plant]:
        return self.plants
    
    def register_new_device(
            self,
            plant_id: str,
            device_type_id: str, 
            unique_identifier: str, 
            device_name: str,
            is_active = False,
            last_data_received = None,
            last_heartbeat = None,
            location_description = None,
            battery_level = None,
            rssi = None
    ):
        db_interface = DBInterface()
        db_interface.register_new_device(
            self.id, 
            device_type_id, 
            unique_identifier, 
            device_name, 
            is_active, 
            last_data_received, 
            last_heartbeat, 
            location_description, 
            battery_level, 
            rssi
        )

        for plant in self.plants:
            if plant.id == plant_id:
                new_device = Device(
                    self.id,
                    device_type_id,
                    unique_identifier,
                    device_name,
                    is_active,
                )

                plant.register_device(new_device)

                db_interface.register_new_device(
                    self.id, 
                    device_type_id,
                    plant_id, 
                    unique_identifier, 
                    device_name, 
                    is_active, 
                    last_data_received, 
                    last_heartbeat, 
                    location_description, 
                    battery_level, 
                    rssi
                )

                return
            
        self.logger(f"Unable to attach {unique_identifier} device to {plant_id} plant.")

    def activate_device(self, plant_id: str, unique_identfier: str):
        for plant in self.plants:
            if plant.id == plant_id:
                device = plant.devices.get_device(unique_identfier)
                device.activate()
    
    def deactivate_device(self, plant_id: str, unique_identfier: str):
        for plant in self.plants:
            if plant.id == plant_id:
                device = plant.devices.get_device(unique_identfier)
                device.deactivate()

    def manually_control_device():
        pass
