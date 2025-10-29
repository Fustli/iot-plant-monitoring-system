import time
from enum import IntEnum

from src.devices import Device
from src.db_utils import DBInterface


# TODO not like this
TEMPERATURE_THRESHOLD = 5.0
HUMIDITY_THRESHOLD = 5.0


class Brightness(IntEnum):
    NO_LIGHT = 1
    LOW_LIGHT = 2
    MEDIUM_LIGHT = 3
    BRIGHT_INDIRECT_LIGHT = 4
    DIRECT_LIGHT = 5
    

class Moisture(IntEnum):
    DRY = 1
    MOIST = 2
    WET = 3


class Plant:
    def __init__(
            self, 
            id: str, 
            plant_type: str,
            req_brightness: Brightness,
            req_humidity: float,
            req_temperature: float,
            req_moisture: Moisture,
        ):
        """Instantiate a new Plant object with its type and required parameters."""

        self.id = id
        self.plant_type = plant_type
        
        # TODO
        # Maybe a plant_config dict would be better than these values?
        # Maybe just for the constructor or something
        self._req_brightness = req_brightness
        self._req_humidity = req_humidity
        self._req_temperature = req_temperature
        self._req_moisture = req_moisture

        # TODO
        # Where the hell do we get the actual values?
        # Each status message gets accepted
        # Then we check if the act_value and the recorded value differs significantly (constant parameter)
        # And only update if it changes significantly
        self.act_brightness: Brightness = None
        self.act_humidity: float = None
        self.act_temperature: float = None
        self.act_moisture: Moisture = None

        self.devices: list[Device] = []

        self.stop_plant_care: bool = False


    @classmethod
    def from_database(cls, id: str, plant_type: str):
        """Instantiate a new Plant object from existing plant types in the database."""
        db_interface = DBInterface()
    
        (
            req_brightness, 
            req_humidity, 
            req_temperature, 
            req_moisture
        ) = db_interface.get_plant_details(plant_type)
    
        return cls(
                id, 
                plant_type, 
                req_brightness, 
                req_humidity, 
                req_temperature, 
                req_moisture
            )
    

    def register_device(self, device: Device):
        """Attach device to Plant."""
        self.devices.append(device)


    def activate_plant_care(self):
        self.run_keep_alive()


    def increase_moisture(self):
        # Send to the devices an increase moisture order
        pass


    def decrease_moisture(self):
        # Send to the devices an decrease moisture order
        pass


    def increase_brightness(self, level: int):
        # Send to the devices an increase brightness order
        pass


    def decrease_brightness(self, level: int):
        # Send to the devices an decrease brightness order
        pass


    def increase_temperature(self, amount: float):
        pass


    def decrease_temperature(self, amount: float):
        pass


    def increase_humidity(self, amount: float):
        pass


    def decrease_humidity(self, amount: float):
        pass


    def update_moisture(self, moisture: Moisture):
        self.act_moisture = moisture


    def update_brightness(self, brightness: Brightness):
        self.act_brightness = brightness

    
    def update_temperature(self, temperature: float):
        self.act_temperature = temperature


    def update_humidity(self, humidity: float):
        self.act_humidity = humidity
    
    
    def run_keep_alive(self):
        # TODO maybe separate thread for each plant?
        while self.stop_plant_care is False:
            # Check Moisture
            if self.act_moisture < self._req_moisture:
                print("|WARNING| - Plant moisture has reached critically low levels! Commencing moisture increase...")
                self.increase_moisture()
            elif self.act_moisture > self._req_moisture:
                print("|WARNING| - Plant moisture has reached critically high levels! Commencing moisture decrease...")
                self.decrease_moisture()
            else:
                print("|INFO| - Plant moisture is on acceptable levels.")

            # Check Brightness
            if self.act_brightness < self._req_brightness:
                diff = self._req_brightness - self.act_brightness
                print("|WARNING| - Plant brightness has reached critically low levels! Commencing brightness increase...")
                self.increase_brightness(diff)
            elif self.act_brightness > self._req_brightness:
                diff = self.act_brightness - self._req_brightness
                print("|WARNING| - Plant brightness has reached critically high levels! Commencing brightness decrease...")
                self.decrease_brightness(diff)
            else:
                print("|INFO| - Plant brightness is on acceptable levels.")

            # Check temperature
            if self.act_temperature < self._req_temperature:
                diff = self._req_temperature - self.act_temperature
                print("|WARNING| - Plant temperature has reached critically low levels! Commencing temperature increase...")
                if diff > TEMPERATURE_THRESHOLD:
                    self.increase_temperature(diff)
            elif self.act_temperature > self._req_temperature:
                diff = self.act_temperature - self._req_temperature
                print("|WARNING| - Plant temperature has reached critically high levels! Commencing temperature decrease...")
                if diff > TEMPERATURE_THRESHOLD:
                    self.decrease_temperature(diff)
            else:
                print("|INFO| - Plant temperature is on acceptable levels.")

            # Check humidity
            if self.act_humidity < self._req_humidity:
                diff = self._req_humidity - self.act_humidity
                print("|WARNING| - Plant humidity has reached critically low levels! Commencing humidity increase...")
                if diff > HUMIDITY_THRESHOLD:
                    self.increase_humidity(diff)
            elif self.act_humidity > self._req_humidity:
                diff = self.act_humidity - self._req_humidity
                print("|WARNING| - Plant humidity has reached critically high levels! Commencing humidity decrease...")
                if diff > HUMIDITY_THRESHOLD:
                    self.decrease_humidity(diff)
            else:
                print("|INFO| - Plant humidity is on acceptable levels.")

            time.sleep(60)
