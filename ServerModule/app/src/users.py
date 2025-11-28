from abc import ABC, abstractmethod

from plants import Plant
from devices import Device, create_device_from_type
from db.db_utils import DBInterface
from logger import Logger
from measurements import Moisture
from thread_manager import PlantThreadManager
from textbook import Textbook

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
        name: str,
        device_type: str,
        communication_interface: str,
        supported_functions: list[str],
        data_unit: str,
        min_value: float,
        max_value: float,
        is_active: bool = True,
        description: str | None = None,
    ):
        """
        Register a new device type in the database.

        supported_functions is a list of capabilities like:
            ["moisture:read", "moisture:write", "temperature:read"]

        The list is normalized and stored as a comma-separated string.
        """
        db_interface = DBInterface()

        # Normalize & store in a deterministic order
        normalized = sorted({s.strip().lower() for s in supported_functions if s.strip()})
        supported_functions_str = ", ".join(normalized)

        db_interface.register_new_device_type(
            manufacturer_id=self.id,
            name=name,
            device_type=device_type,
            communication_interface=communication_interface,
            supported_functions=supported_functions_str,
            data_unit=data_unit,
            min_value=min_value,
            max_value=max_value,
            is_active=is_active,
            description=description,
        )
        


class Consumer(User):
    def __init__(self, id: str, username: str, email_address: str, thread_manager: PlantThreadManager):
        super().__init__(id, username)
        self.plants: list[Plant] = []
        self.email_address = email_address
        self.thread_manager = thread_manager

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
        db_interface = DBInterface()
        plant = Plant.from_scratch(
            name, self.id, scientific_name,
            req_brightness, req_humidity, 
            req_temperature, req_moisture,
            description, care_instructions,
            location, is_healthy, health_status, notes

        )
        self.plants.append(plant)
        self.thread_manager.add_plant(plant)

        self.logger.info(Textbook.attach_plant_to_consumer + name)

        return db_interface.get_plant_id(name)

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
        db_interface = DBInterface()

        plant = Plant.from_database(
            self.id, name, scientific_name, 
            is_healthy, location, health_status, notes
        )
        self.plants.append(plant)
        self.thread_manager.add_plant(plant)

        self.logger.info(Textbook.attach_plant_to_consumer + name)

        return db_interface.get_plant_id(name)

    def get_plants(self) -> list[Plant]:
        return self.plants
    
    def register_new_device(
            self,
            plant_id: int,
            device_type_name: str,
            unique_identifier: str, 
            device_name: str,
            is_active: bool = False,
            last_data_received = None,
            last_heartbeat = None,
            location_description = None,
            battery_level = None,
            rssi = None
    ):
        db_interface = DBInterface()
        device_type_id = db_interface.get_device_type_id(device_type_name)
        # 1) Persist device into DB (correct argument order)
        device_id = db_interface.register_new_device(
            user_id=self.id,
            plant_id=plant_id,
            device_type_id=device_type_id,
            unique_identifier=unique_identifier,
            device_name=device_name,
            is_active=is_active,
            last_data_received=last_data_received,
            last_heartbeat=last_heartbeat,
            location_description=location_description,
            battery_level=battery_level,
            rssi=rssi,
        )

        # 2) Create in-memory Device with dynamic capabilities
        new_device = create_device_from_type(
            device_id=device_id,
            user_id=self.id,
            device_type_id=device_type_id,
            unique_identifier=unique_identifier,
            device_name=device_name,
            is_active=is_active,
        )

        # 3) Attach to the appropriate Plant object
        for plant in self.plants:
            if getattr(plant, "id", None) == plant_id:
                plant.register_device(new_device)
                self.logger.info(Textbook.attach_device_to_plant + f"Plant: {plant.name} - Device: {unique_identifier}")
                return unique_identifier
            
        self.logger.error(f"Unable to attach {unique_identifier} device to plant {plant_id}.")

    def activate_device(self, plant_id: str, unique_identfier: str):
        for plant in self.plants:
            if plant.id == plant_id:
                device = plant.devices.get_device(unique_identfier)
                device.activate()

    def device_activation(self, device_id: int | None = None, command: bool = True):
        """
        Activate/deactivate a single device or all devices owned by this consumer.

        :param device_id: if None, affect all devices; otherwise only the given device id.
        :param command: True -> activate, False -> deactivate.
        """
        db_interface = DBInterface()

        for plant in self.plants:
            for device in plant.devices.devices:
                if device_id is not None and device.id != device_id:
                    continue

                if command:
                    device.activate()
                else:
                    device.deactivate()

                db_interface.set_device_active_state(device.id, command)

    def plant_care_activation(self, plant_id: int | None = None, command: bool = True):
        if plant_id:
            for plant in self.plants:
                if getattr(plant, "id", None) == plant_id:
                    if command:
                        plant.start_plant_care()
                    else:
                        plant.stop_plant_care()
                    return
        else:
            for plant in self.plants:
                if command:
                    plant.start_plant_care()
                else:
                    plant.stop_plant_care()

    def manually_control_device():
        pass
