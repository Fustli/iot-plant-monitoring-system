from abc import ABC, abstractmethod


class Device(ABC):
    def __init__(self, id):
        self.id = id


class SensorDevice(Device):
    """A type of device which is only capable of transmitting data."""
    def __init__(self, id):
        super().__init__(id)


class ExecutorDevice(Device):
    """A type of device which is capable of executing certain commands, and also sends status messages."""
    def __init__(self, id):
        super().__init__(id)


class CombinedDevice(Device):
    """A type of device which is capable of both transmitting data and executing commands."""
    def __init__(self, id):
        super().__init__(id)


