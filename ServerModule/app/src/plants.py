from enum import Enum

from src.devices import Device
from src.db_utils import DBInterface


class Brightness(Enum):
    DIRECT_LIGHT = 1
    BRIGHT_INDIRECT_LIGHT = 2
    MEDIUM_LIGHT = 3
    LOW_LIGHT = 4
    NO_LIGHT = 5


class Plant:
    def __init__(
            self, 
            id: str, 
            plant_type: str,
            brightness: Brightness,
            sunlight_hours: float,
            humidity: float,
            temperature: float,
            soil_moisture: float,
        ):

        self.id = id
        self.plant_type = plant_type
        
        self.brightness = brightness
        self.sunlight_hours = sunlight_hours
        self.humidity = humidity
        self.temperature = temperature
        self.soil_moisture = soil_moisture

        self.devices: list[Device] = []


    @classmethod
    def from_database(cls, id: str, plant_type: str):
        db_interface = DBInterface()
    
        brightness, sunlight_hours, humidity, temperature, soil_moisture = db_interface.get_plant_details(plant_type)
    
        return cls(id, plant_type, brightness, sunlight_hours, humidity, temperature, soil_moisture)
        
