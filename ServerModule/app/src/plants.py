import time
import threading

from devices import Device, DeviceCollection
from db_utils import DBInterface
from measurements import Brightness, Moisture, TEMPERATURE_THRESHOLD, HUMIDITY_THRESHOLD
from textbook import Textbook, MetricMessages
from logger import Logger, LogLevel


class Plant:
    def __init__(
            self, 
            id: str, 
            plant_type: str,
            req_brightness: Brightness,
            req_humidity: float,
            req_temperature: float,
            req_moisture: Moisture,
            alert_address: str | None = None
        ):
        """Instantiate a new Plant object with its type and required parameters."""

        self.id = id
        self.plant_type = plant_type
        
        # Required values
        self._req_brightness = req_brightness
        self._req_humidity = req_humidity
        self._req_temperature = req_temperature
        self._req_moisture = req_moisture

        # Actual values
        self.act_brightness: Brightness = None
        self.act_humidity: float = None
        self.act_temperature: float = None
        self.act_moisture: Moisture = None

        self.logger = Logger(name=id, level=LogLevel.INFO)
        self.devices: DeviceCollection = DeviceCollection(self.id, self.logger)

        self.alert_address = alert_address

        self.keep_alive: bool = False

        


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
        self.devices.add_device(device)

    def remove_device(self, device: Device):
        """Detach device from Plant."""
        self.devices.remove_device(device)

    def update_moisture(self, moisture: Moisture):
        self.act_moisture = moisture

    def update_brightness(self, brightness: Brightness):
        self.act_brightness = brightness

    def update_temperature(self, temperature: float):
        self.act_temperature = temperature

    def update_humidity(self, humidity: float):
        self.act_humidity = humidity

    def send_alert(self, subject: str):
        # TODO
        # Send email/notification
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

        self.logger.warning(msg)
    
        if self.alert_address:
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
            threshold=0,
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
        # plants: optional initial iterable of Plant instances
        self._plants = list(plants) if plants is not None else []
        self._interval = interval_seconds

        self._lock = threading.Lock()
        self._stop_event = threading.Event()
        self._manager_thread: threading.Thread | None = None

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

    @staticmethod
    def _run_keep_alive_once(plant: Plant):
        """
        Wrapper so that any exception in keep_alive is caught and doesn't kill
        the manager loop.
        """
        try:
            plant.keep_alive_cycle()
        except Exception as exc:
            # TODO real logger
            print(f"Error in keep_alive for plant {plant.id}: {exc}")


def test_threads():
    plant1 = Plant(
        id='plant1',
        plant_type="low_maintenance",
        req_brightness=Brightness.LOW_LIGHT,
        req_humidity=20.0,
        req_temperature=21.0,
        req_moisture=Moisture.DRY
    )

    plant2 = Plant(
        id='plant2',
        plant_type="high_maintenance",
        req_brightness=Brightness.DIRECT_LIGHT,
        req_humidity=40.0,
        req_temperature=21.0,
        req_moisture=Moisture.MOIST
    )

    plant1.act_humidity = 30
    plant2.act_temperature = 20

    plant1.keep_alive = True
    plant2.keep_alive = True

    manager = PlantThreadManager([plant1, plant2], interval_seconds=60)
    manager.start()

    time.sleep(300)


if __name__ == "__main__":
    test_threads()