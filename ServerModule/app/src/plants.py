import datetime

from src.devices import Device, DeviceCollection
from src.db.db_utils import DBInterface
from src.measurements import MOISTURE_THRESHOLD, TEMPERATURE_THRESHOLD, HUMIDITY_THRESHOLD, BRIGHTNESS_THRESHOLD
from src.textbook import Textbook, MetricMessages
from src.logger import Logger


class Plant:
    def __init__(
            self,
            id: int, 
            name: str,
            user_id: int,
            req_brightness: float,
            req_humidity: float,
            req_temperature: float,
            req_moisture: float,
            health_status: str | None = None,
        ):
        """Instantiate a new Plant object with its type and required parameters."""

        self.id = id
        self.name = name
        self.user_id = user_id
        
        # Required values
        self._req_brightness = req_brightness
        self._req_humidity = req_humidity
        self._req_temperature = req_temperature
        self._req_moisture = req_moisture

        # Actual values
        self.act_brightness: float = None
        self.act_humidity: float = None
        self.act_temperature: float = None
        self.act_moisture: float = None

        # health_status can be either:
        # 1. A comma-separated string of sensor values: "brightness,humidity,temperature,moisture"
        # 2. A text status like "Good", "Needs attention" - in this case we don't have sensor data
        if health_status and "," in health_status:
            try:
                brightness, humidity, temperature, moisture = (float(x) for x in health_status.split(","))
                self.act_brightness = int(brightness)
                self.act_humidity = humidity
                self.act_temperature = temperature
                self.act_moisture = moisture
            except (ValueError, AttributeError):
                # If parsing fails, just ignore - we don't have sensor data
                pass

        self.logger = Logger(name=self.name)
        self.devices: DeviceCollection = DeviceCollection(self.name, self.logger)

        self.keep_alive: bool = False

        self.logger.info(Textbook.plant_object_creation + self.name)


    @classmethod
    def from_scratch(cls,
        plant_name: str,
        user_id: int,
        scientific_name: str,
        req_brightness: float,
        req_humidity: float,
        req_temperature: float,
        req_moisture: float,
        description: str | None = None,
        care_instructions: str | None = None,
        location: str | None = None,
        is_healthy: bool = True,
        health_status: str | None = None,
        notes: str | None = None,
    ):
        logger = Logger(name="Plant.from_scratch")
        db_interface = DBInterface()

        plant_type_id = db_interface.register_new_plant_type(
            scientific_name, scientific_name, req_temperature,
            req_humidity, req_brightness, req_moisture,
            description, care_instructions            
        )
        logger.info(Textbook.plant_type_creation_in_db + scientific_name)
        
        plant_id = db_interface.register_new_plant(
            user_id, plant_type_id, plant_name,
            is_healthy, location,
            datetime.datetime.utcnow(),
            health_status, notes,
        )
        logger.info(Textbook.plant_creation_in_db + plant_name)

<<<<<<< HEAD
=======
        req_moisture = Moisture.from_percentage(req_moisture)

>>>>>>> 5d115f2 (Frontend debug and new hub table)
        return cls(
            plant_id,
            plant_name, user_id, 
            req_brightness, req_humidity, 
            req_temperature, req_moisture,
            health_status,
        )
        

    @classmethod
    def from_database(cls,
        user_id: str,
        plant_name: str,
        scientific_name: str,
        is_healthy: bool = True,
        location: str | None = None,
        health_status: str | None = None,
        notes: str | None = None,
    ):
        """
        Instantiate a new Plant object from existing plant types in the database. 
        plant_type: str = scientific name of the plant
        """
        db_interface = DBInterface()
        logger = Logger(name="Plant.from_database")

        (   plant_type_id, name, scientific_name,
            req_temperature, req_humidity, 
            req_brightness, req_moisture,
            desc, care,
        ) = db_interface.get_plant_details_by_sci_name(scientific_name)

        plant_id = db_interface.register_new_plant(
            user_id, plant_type_id, 
            plant_name, is_healthy,
            location, datetime.datetime.utcnow(),
            health_status, notes
        )
        logger.info(Textbook.plant_creation_in_db + plant_name)
<<<<<<< HEAD
=======

        req_moisture = Moisture.from_percentage(req_moisture)
>>>>>>> 5d115f2 (Frontend debug and new hub table)
    
        return cls(
            plant_id,
            plant_name, user_id, 
            req_brightness, req_humidity, 
            req_temperature, req_moisture,
            health_status,
        )
    
    def register_device(self, device: Device):
        """Attach device to Plant."""
        self.devices.add_device(device)

    def remove_device(self, device: Device):
        """Detach device from Plant."""
        self.devices.remove_device(device)

    def update_moisture(self, moisture: float):
        self.act_moisture = moisture

    def update_brightness(self, brightness: int):
        self.act_brightness = brightness

    def update_temperature(self, temperature: float):
        self.act_temperature = temperature

    def update_humidity(self, humidity: float):
        self.act_humidity = humidity

    def start_plant_care(self):
        self.keep_alive = True

    def stop_plant_care(self):
        self.keep_alive = False

    def check_metric(self,
        metric: str,
        act_value: str, 
        req_value: str,
        threshold: float,
    ):
        metric_msgs: MetricMessages = getattr(Textbook, metric)

        if not act_value:
            return
        
        delta = req_value - act_value

        if abs(delta) <= threshold:
            self.logger.info(metric_msgs.ok)
            return
        elif delta < 0:
            msg = metric_msgs.high
        else:
            msg = metric_msgs.low

        self.logger.warning(msg)

        self.devices.send_command(metric, delta, msg)

        
    def keep_alive_cycle(self):
        self.check_metric(
            "moisture",
            act_value=self.act_moisture,
            req_value=self._req_moisture,
            threshold=MOISTURE_THRESHOLD,
        )

        self.check_metric(
            "brightness",
            act_value=self.act_brightness,
            req_value=self._req_brightness,
            threshold=BRIGHTNESS_THRESHOLD,
        )

        self.check_metric(
            "temperature",
            act_value=self.act_temperature,
            req_value=self._req_temperature,
            threshold=TEMPERATURE_THRESHOLD,
        )

        self.check_metric(
            "humidity",
            act_value=self.act_humidity,
            req_value=self._req_humidity,
            threshold=HUMIDITY_THRESHOLD,
        )

