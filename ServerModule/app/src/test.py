import time
from db.db_utils import DBInterface
from users import Consumer
from plants import Plant
from thread_manager import PlantThreadManager


def test():
    """Tests a user adding a plant and a device to that plant."""
    thread_manager = PlantThreadManager(interval_seconds=5)
    thread_manager.start()

    consumer = Consumer(1, "demo_user", "demo@example.com", thread_manager)
    plant_id = consumer.register_plant_from_database(
        name='my monstera', 
        scientific_name='Monstera deliciosa', 
        location='my ass',
        health_status="1000,70,22,3"
    )
    unique_identifier = consumer.register_new_device(plant_id, 'Xiaomi Moisture Deluxe', 'my deluxe', 'Deluxe Moisture Machine by the window')
    consumer.activate_device(plant_id, unique_identifier)
    consumer.activate_plant_care(plant_id)

    time.sleep(300)


def test_threads():
    """DEFUNCT"""
    plant1 = Plant.from_scratch(
        name='plant1',
        user_id=1,
        scientific_name='test plant',
        req_brightness=500,
        req_humidity=20.0,
        req_temperature=21.0,
        req_moisture=1
    )

    plant2 = Plant.from_database(1, 'my monstera', 'Monstera deliciosa')

    plant1.act_humidity = 30
    plant2.act_temperature = 20
    plant2.act_moisture = 3

    plant1.keep_alive = True
    plant2.keep_alive = True

    manager = PlantThreadManager([plant1, plant2], interval_seconds=60)
    manager.start()

    time.sleep(300)


if __name__ == "__main__":
    test()