from abc import ABC, abstractmethod
from measurements import Moisture, Brightness
from textbook import Textbook, MetricMessages
from logger import Logger

# Bejön az üzenet egy adott eszköztől -> frissítjük annak az eszköznek az adatát
# Le tudjuk kérni az eszköz által mért értéket
# A növény az egyes azonos típusú eszközei által mért értékeket "átlagolja"

class Device(ABC):
    def __init__(self, name: str):
        self.name = name

    @property
    def capabilities(self) -> set[str]:
        capabilities = set()
        if isinstance(self, MoistureSensor):
            capabilities.add("moisture:read")
        if isinstance(self, MoisturizeActuator):
            capabilities.add("moisture:write")
        if isinstance(self, BrightnessSensor):
            capabilities.add("brightness:read")
        if isinstance(self, BrightnessActuator):
            capabilities.add("brightness:write")
        if isinstance(self, TemperatureSensor):
            capabilities.add("temperature:read")
        if isinstance(self, TemperatureActuator):
            capabilities.add("temperature:write")
        if isinstance(self, HumiditySensor):
            capabilities.add("humidity:read")
        if isinstance(self, HumidityActuator):
            capabilities.add("humidity:write")
        return capabilities

    def __repr__(self) -> str:
        return f"{self.__class__.__name__}(name={self.name!r})"
    

class MoistureSensor(ABC):
    def __init__(self, name: str):
        self._name = name
        self._moisture: Moisture = None

    @abstractmethod
    def read_moisture(self) -> Moisture:
        pass

    @abstractmethod
    def update_moisture(self, moisture: Moisture):
        pass


class MoistureActuator(ABC):
    def __init__(self, name: str):
        self._name = name
        self._moisture: Moisture = None

    @abstractmethod
    def change_moisture(self, delta: int):
        pass


class BrightnessSensor(ABC):
    def __init__(self, name: str):
        self._name = name
        self._brightness: Brightness = None

    @abstractmethod
    def read_brightness(self) -> Brightness:
        pass

    @abstractmethod
    def update_brightness(self, brightness: Brightness):
        pass


class BrightnessActuator(ABC):
    def __init__(self, name: str):
        self._name = name

    @abstractmethod
    def change_brightness(self, delta: int):
        pass


class TemperatureSensor(ABC):
    def __init__(self, name: str):
        self._name = name
        self._temperature: float = None

    @abstractmethod
    def read_temperature(self) -> float:
        pass

    @abstractmethod
    def update_temperature(self, temperature: float):
        pass


class TemperatureActuator(ABC):
    def __init__(self, name: str):
        self._name = name

    @abstractmethod
    def change_temperature(self, delta: float):
        pass


class HumiditySensor(ABC):
    def __init__(self, name: str):
        self._name = name
        self._humidity: float = None

    @abstractmethod
    def read_humidity(self) -> float:
        pass

    @abstractmethod
    def update_humidity(self, humidity: float):
        pass


class HumidityActuator(ABC):
    def __init__(self, name: str):
        self._name = name

    @abstractmethod
    def change_humidity(self, humidity: float):
        pass


class SimpleMoisturizer(Device, MoistureSensor):
    def __init__(self, name: str):
        super().__init__(name)
        self._moisture = None


    def read_moisture(self) -> float:
        return self._moisture


class ComplexMoistureDevice(Device, MoistureSensor, MoisturizeActuator):
    def __init__(self, name: str):
        super().__init__(name)
        self._moisture = None


    def read_moisture(self) -> float:
        return self._moisture


    def change_moisture(self, delta: float) -> None:
        self._moisture = self._moisture + delta


class DeviceCollection:
    """The devices associated with one Plant object."""
    def __init__(self, plant_id: str, logger: Logger):
        self.plant_id = plant_id
        self.devices: list[Device] = []
        self.logger = logger

    def add_device(self, device: Device):
        self.devices.append(device)

    def remove_device(self, device: Device):
        self.devices.remove(Device)

    def send_command(self, metric: str, delta: float):
        capability = f"{metric}:write"
        method_name = f"change_{metric}"
        metric_msgs: MetricMessages = getattr(Textbook, metric)
    
        actuators = [d for d in self.devices if capability in d.capabilities]

        if not actuators:
            self.logger.warning(metric_msgs.no_actuator)
            return

        delta_fragment = delta / len(actuators)

        for device in actuators:
            method = getattr(device, method_name)
            method(delta_fragment)



if __name__ == "__main__":
    pot = ComplexMoistureDevice("Smart Pot #1")
    probe = SimpleMoisturizer("Soil Probe A")

    print(pot, pot.capabilities)     # {'moisture:read', 'moisture:write'}
    print(probe, probe.capabilities) # {'moisture:read'}

    print(pot)
