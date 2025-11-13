from abc import ABC, abstractmethod

from plants import Plant
from devices import Device


class User(ABC):
    def __init__(self, id: str, username: str):
        self.id = id
        self.username = username
        


class Manufacturer(User):
    def __init__(self, id: str, username: str):
        super().__init__(id, username)

    def create_new_device():
        pass


class Consumer(User):
    def __init__(self, id: str, username: str):
        super().__init__(id, username)
        self.plants: list[Plant] = []

    def register_plant(self, plant: Plant):
        """Attach Plant to User."""
        self.plants.append(plant)

    def get_plants(self) -> list[Plant]:
        return self.plants
    
    def register_device(self, plant: Plant, device: Device):
        pass

