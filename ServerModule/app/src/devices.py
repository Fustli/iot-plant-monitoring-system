from abc import ABC
from types import MappingProxyType
from src.db.db_utils import DBInterface
from src.textbook import Textbook, MetricMessages
from src.logger import Logger
from src.alert_sender import send_alert
from src.hub_control import invoke_direct_method


# The metrics and operations we support
_METRICS = ("temperature", "moisture", "brightness", "humidity")
_VALID_OPERATIONS = ("read", "write")
_ALLOWED_CAPABILITIES = frozenset(
    f"{m}:{op}" for m in _METRICS for op in _VALID_OPERATIONS
)
_ALLOWED_CAPABILITIES_RO = MappingProxyType(
    {c: True for c in _ALLOWED_CAPABILITIES}
)

def parse_supported_functions(supported_functions: str) -> set[str]:
    """
    Parse the supported_functions string from the database into a set of
    canonical capability strings like 'moisture:read', 'temperature:write'.
    Unknown/invalid entries are silently ignored.
    """
    if not supported_functions:
        return set()

    capabilities: set[str] = set()
    for raw in supported_functions.split(","):
        token = raw.strip()
        if not token:
            continue
        # normalize case
        token = token.lower()
        if token in _ALLOWED_CAPABILITIES_RO:
            capabilities.add(token)
    return capabilities


class Device(ABC):
    def __init__(
        self,
        id: int,
        user_id: int, 
        device_type_id: int, 
        unique_identifier: str, 
        device_name: str, 
        is_active: bool = False,
        capabilities: set[str] | None = None,
    ):
        self.id = id
        self.user_id = user_id
        self.device_type_id = device_type_id
        self.unique_identifier = unique_identifier
        self.device_name = device_name
        self.is_active = is_active
        self._capabilities = set(capabilities or [])
        self.logger = Logger(name=self.device_name)

    @property
    def capabilities(self) -> set[str]:
        return self._capabilities
    
    def has_capability(self, capability: str) -> bool:
        return capability in self._capabilities

    def supported_metrics(self) -> set[str]:
        """Return the metrics this device knows anything about."""
        return {cap.split(":", 1)[0] for cap in self._capabilities}

    def __repr__(self) -> str:
        return f"{self.__class__.__name__}(name={self.device_name!r})"
    
    def activate(self):
        self.is_active = True

    def deactivate(self):
        self.is_active = False

    def _send_actuator_command(self, metric: str, delta: float) -> None:
        # choose a topic and payload (example)
        topic = f"actuators/{self.unique_identifier}/set"
        payload = {"metric": metric, "delta": delta}

        # lookup DB to find hub + iothub info
        db = DBInterface()
        device = db.get_device(self.id)
        if not device:
            self.logger.error("Device DB record missing for id=%s", self.id)
            return

        hub_id = device.get("hub_id")
        if not hub_id:
            self.logger.error("Device %s not attached to a hub", self.id)
            return

        hub = db.get_hub(hub_id)
        if not hub:
            self.logger.error("Hub %s not found for device %s", hub_id, self.id)
            return

        iothub_conn = hub.get("iothub_connection_string")
        iothub_dev_id = hub.get("iothub_device_id")
        if not iothub_conn or not iothub_dev_id:
            self.logger.error("Hub %s lacks IoT Hub credentials/device id", hub_id)
            return

        try:
            resp = invoke_direct_method(iothub_conn, iothub_dev_id, topic, payload)
            self.logger.info("Actuator command sent: %s -> %s", topic, resp)
        except Exception as exc:
            self.logger.exception("Failed to send actuator command for device %s: %s", self.id, exc)

    def _read_sensor_value(self, metric: str):
        """
        TODO Placeholder for the real sensor read.
        Intentionally *does not* talk to hardware yet.
        """
        self.logger.info(
            f"Pretend reading sensor: metric={metric} from device={self.unique_identifier}"
        )
        return None



class DeviceCollection:
    """The devices associated with one Plant object."""
    def __init__(self, plant_name: str, logger: Logger):
        self.plant_name = plant_name
        self.devices: list[Device] = []
        self.logger = logger

    def add_device(self, device: Device):
        self.devices.append(device)

    def remove_device(self, device: Device):
        self.devices.remove(device)

    def get_device(self, unique_identifier: str):
        for device in self.devices:
            if device.unique_identifier == unique_identifier:
                return device
        self.logger.error(f"Unable to find device: {unique_identifier}")

    def send_command(self, metric: str, delta: float, msg: str):
        capability = f"{metric}:write"
        method_name = f"change_{metric}"
        metric_msgs: MetricMessages = getattr(Textbook, metric)
    
        actuators = [d for d in self.devices if capability in d.capabilities and d.is_active]

        if not actuators:
            self.logger.warning(metric_msgs.no_actuator)
            send_alert(self.plant_name, metric, delta, msg, metric_msgs.no_actuator)
            return

        send_alert(self.plant_name, metric, delta, msg)

        delta_fragment = delta / len(actuators)

        for device in actuators:
            method = getattr(device, method_name)
            method(delta_fragment)


def _attach_dynamic_methods(device: Device) -> None:
    """
    Attach read_<metric> / change_<metric> methods to a device instance
    based on its capabilities, e.g. 'moisture:read', 'moisture:write'.
    The methods are small closures around the generic stub methods.
    """
    for metric in _METRICS:
        cap_read = f"{metric}:read"
        cap_write = f"{metric}:write"

        if cap_read in device.capabilities:
            def make_read(m: str, dev: Device):
                def read():
                    return dev._read_sensor_value(m)
                return read
            setattr(device, f"read_{metric}", make_read(metric, device))

        if cap_write in device.capabilities:
            def make_change(m: str, dev: Device):
                def change(delta: float):
                    dev._send_actuator_command(m, delta)
                return change
            setattr(device, f"change_{metric}", make_change(metric, device))


def create_device_from_type(
    device_id: int,
    user_id: int,
    device_type_id: int,
    unique_identifier: str,
    device_name: str,
    is_active: bool = False,
) -> Device:
    """
    Factory: look up the device_type in the database, parse its supported_functions
    into capabilities, create a Device, and attach dynamic metric methods.
    """
    db_interface = DBInterface()
    supported_functions = db_interface.get_device_capabilities(device_type_id)
    
    capabilities = parse_supported_functions(supported_functions)

    device = Device(
        id=device_id,
        user_id=user_id,
        device_type_id=device_type_id,
        unique_identifier=unique_identifier,
        device_name=device_name,
        is_active=is_active,
        capabilities=capabilities,
    )

    _attach_dynamic_methods(device)
    return device


if __name__ == "__main__":
    print("main")
