from abc import ABC, abstractmethod


class Device(ABC):
    def __init__(self, id):
        self.id = id
    pass


class SensorDevice(Device):
    pass


class ExecutorDevice(Device):
    pass


class CombinedDevice(Device):
    pass
