import threading

from src.logger import Logger
from src.plants import Plant


class PlantThreadManager:
    """
    Manages the threads for the registered plants.
    Every 'interval_seconds' it wakes up and spawns worker threads for every plant
    which has keep_alive==True
    """

    def __init__(self, plants: list[Plant] = None, interval_seconds: int = 300):
        self._plants = list(plants) if plants is not None else []
        self._interval = interval_seconds

        self._lock = threading.Lock()
        self._stop_event = threading.Event()
        self._manager_thread: threading.Thread | None = None

        self.logger = Logger(name="PlantThreadManager")
        self.logger.info(f"Created PlantThreadManager.")

    def add_plant(self, plant: Plant):
        """Add a plant to be managed."""
        with self._lock:
            self._plants.append(plant)
            self.logger.info(f"Added {plant.name} to PlantThreadManager.")

    def remove_plant(self, plant: Plant):
        """Remove a plant from being managed."""
        with self._lock:
            self._plants = [p for p in self._plants if p is not plant]
            self.logger.info(f"Removed {plant.name} from PlantThreadManager.")

    def start(self):
        """
        Start the background manager thread (if not already running).
        """
        if self._manager_thread and self._manager_thread.is_alive():
            self.logger.info(f"PlantThreadManager already running.")
            return

        self._stop_event.clear()
        self._manager_thread = threading.Thread(
            target=self._run_loop,
            daemon=True,
        )
        self._manager_thread.start()
        self.logger.info(f"Started PlantThreadManager.")

    def stop(self):
        """
        Signal the manager thread to stop and wait for it to finish.
        """
        self._stop_event.set()
        if self._manager_thread:
            self._manager_thread.join()
        self.logger.info(f"Stopped PlantThreadManager.")

    def _run_loop(self):
        """
        Internal loop that wakes up every interval, spawns worker threads for
        all plants that have keep_alive == True, waits for those workers
        to finish, then sleeps again.
        """
        while not self._stop_event.is_set():
            self.logger.info(f"Running PlantThreadManager loop.")
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
            self.logger.error(f"Error in keep_alive for plant {plant.name}: {exc}")
