import time
import threading
import datetime

from devices import Device, DeviceCollection
from db.db_utils import DBInterface
from measurements import Moisture, TEMPERATURE_THRESHOLD, HUMIDITY_THRESHOLD, BRIGHTNESS_THRESHOLD
from textbook import Textbook, MetricMessages
from logger import Logger


class Plant:
    def __init__(
            self, 
            name: str,
            user_id: int,
            req_brightness: float,
            req_humidity: float,
            req_temperature: float,
            req_moisture: Moisture,
        ):
        """Instantiate a new Plant object with its type and required parameters."""

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
        self.act_moisture: Moisture = None

        self.logger = Logger(name=self.name)
        self.devices: DeviceCollection = DeviceCollection(self.name, self.logger)

        self.keep_alive: bool = False


    @classmethod
    def from_scratch(cls,
        name: str,
        user_id: int,
        scientific_name: str,
        req_brightness: float,
        req_humidity: float,
        req_temperature: float,
        req_moisture: int,
        description: str | None = None,
        care_instructions: str | None = None,
        location: str | None = None,
        is_healthy: bool = True,
        health_status: str | None = None,
        notes: str | None = None,
    ):
        db_interface = DBInterface()

        plant_type_id = db_interface.register_new_plant_type(
            name, scientific_name, req_temperature,
            req_humidity, req_brightness, req_moisture,
            description, care_instructions
        )
        db_interface.register_new_plant(
            user_id, plant_type_id, name,
            is_healthy, location,
            datetime.datetime.utcnow(),
            health_status, notes,
        )

        req_moisture = Moisture(req_moisture)

        return cls(
            name, user_id, 
            req_brightness, req_humidity, 
            req_temperature, req_moisture,
        )
        

    @classmethod
    def from_database(cls,
        user_id: str,
        name: str,
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

        (   plant_type_id, name, scientific_name,
            req_brightness, req_humidity, 
            req_temperature, req_moisture,
            desc, care,
        ) = db_interface.get_plant_details(scientific_name)

        db_interface.register_new_plant(
            user_id, plant_type_id, 
            name, is_healthy,
            location, datetime.datetime.utcnow(),
            health_status, notes
        )

        req_moisture = Moisture(req_moisture)
    
        return cls(
            name, user_id, 
            req_brightness, req_humidity, 
            req_temperature, req_moisture,
        )
    
    def register_device(self, device: Device):
        """Attach device to Plant."""
        self.devices.add_device(device)

    def remove_device(self, device: Device):
        """Detach device from Plant."""
        self.devices.remove_device(device)

    def update_moisture(self, moisture: Moisture):
        self.act_moisture = moisture

    def update_brightness(self, brightness: int):
        self.act_brightness = brightness

    def update_temperature(self, temperature: float):
        self.act_temperature = temperature

    def update_humidity(self, humidity: float):
        self.act_humidity = humidity

    def send_alert(self, subject: str):
        # TODO
        # Send email/notification to user_id.alert_address
        # Log alert in database
        print(subject)

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

        if abs(delta) < threshold:
            self.logger.info(metric_msgs.ok)
            return
        elif delta < 0:
            msg = metric_msgs.high
        else:
            msg = metric_msgs.low

        self.logger.info(msg)
    
        self.send_alert(msg)

        self.devices.send_command(metric, delta)

        
    def keep_alive_cycle(self):
        self.check_metric(
            "moisture",
            act_value=self.act_moisture,
            req_value=self._req_moisture,
            threshold=0,
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


class PlantThreadManager:
    """
    Manages the threads for the registered plants.
    Every 'interval_seconds' it wakes up and spawns worker threads for every plant
    which has 
    """

    def __init__(self, plants: list[Plant] = None, interval_seconds: int = 300):
        self._plants = list(plants) if plants is not None else []
        self._interval = interval_seconds

        self._lock = threading.Lock()
        self._stop_event = threading.Event()
        self._manager_thread: threading.Thread | None = None

        self.logger = Logger(name="PlantThreadManager")

    def add_plant(self, plant: Plant):
        """Add a plant to be managed."""
        with self._lock:
            self._plants.append(plant)

    def remove_plant(self, plant: Plant):
        """Remove a plant from being managed."""
        with self._lock:
            self._plants = [p for p in self._plants if p is not plant]

    def start(self):
        """
        Start the background manager thread (if not already running).
        """
        if self._manager_thread and self._manager_thread.is_alive():
            # Main thread already running
            return

        self._stop_event.clear()
        self._manager_thread = threading.Thread(
            target=self._run_loop,
            daemon=True,
        )
        self._manager_thread.start()

    def stop(self):
        """
        Signal the manager thread to stop and wait for it to finish.
        """
        self._stop_event.set()
        if self._manager_thread:
            self._manager_thread.join()

    def _run_loop(self):
        """
        Internal loop that wakes up every interval, spawns worker threads for
        all plants that have keep_alive == True, waits for those workers
        to finish, then sleeps again.
        """
        while not self._stop_event.is_set():
            # Take a snapshot of the plants under a lock
            with self._lock:
                plants_snapshot = list(self._plants)

            worker_threads: list[threading.Thread] = []

            for plant in plants_snapshot:
                if getattr(plant, "keep_alive", False):
                    t = threading.Thread(
                        target=self._run_keep_alive_once,
                        args=(plant,),
                        daemon=True,
                    )
                    t.start()
                    worker_threads.append(t)

            # Wait for all keep_alive calls of this cycle to complete
            for t in worker_threads:
                t.join()

            # Sleep until the next cycle, but wake up early if stopping
            if self._stop_event.wait(self._interval):
                break


    def _run_keep_alive_once(self, plant: Plant):
        """
        Wrapper so that any exception in keep_alive is caught and doesn't kill
        the manager loop.
        """
        try:
            plant.keep_alive_cycle()
        except Exception as exc:
            self.logger.error(f"Error in keep_alive for plant {plant.id}: {exc}")


def test_threads():
    plant1 = Plant.from_scratch(
        name='plant1',
        user_id=1,
        scientific_name='test plant',
        req_brightness=500,
        req_humidity=20.0,
        req_temperature=21.0,
        req_moisture=Moisture.DRY
    )

    plant2 = Plant.from_database(1, 'my monstera', 'Monstera deliciosa')

    plant1.act_humidity = 30
    plant2.act_temperature = 20
    plant2.act_moisture = Moisture.WET

    plant1.keep_alive = True
    plant2.keep_alive = True

    manager = PlantThreadManager([plant1, plant2], interval_seconds=60)
    manager.start()

    time.sleep(300)


if __name__ == "__main__":
    test_threads()