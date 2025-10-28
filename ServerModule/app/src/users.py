from abc import ABC, abstractmethod

from src.plants import Plant
from src.devices import Device


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
        self.plants.append(plant)

    def get_plants(self) -> list[Plant]:
        return self.plants
    
    def register_device(self, plant: Plant, device: Device):
        pass

