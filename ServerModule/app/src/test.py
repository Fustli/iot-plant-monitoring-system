import time
from src.db.db_utils import DBInterface
from src.users import Consumer
from src.plants import Plant
from src.thread_manager import PlantThreadManager


def test1():
    """Tests a user adding a plant and a device to that plant."""
    thread_manager = PlantThreadManager(interval_seconds=5)
    thread_manager.start()

    consumer = Consumer(1, "demo_user", "demo@example.com", thread_manager)
    plant_id = consumer.register_plant_from_database(
        name='test1 plant', 
        scientific_name='Monstera deliciosa', 
        location='my ass',
        health_status="1000,70,22,3"
    )
    unique_identifier = consumer.register_new_device(plant_id, 'Xiaomi Moisture Deluxe', 'test1 device', 'Deluxe Moisture Machine by the window')
    consumer.activate_device(plant_id, unique_identifier)
    consumer.plant_care_activation(plant_id)

    time.sleep(300)


def test2():
    """Tests a user adding a plant and different devices to that plant."""
    thread_manager = PlantThreadManager(interval_seconds=10)
    thread_manager.start()

    consumer = Consumer(1, "demo_user", "demo@example.com", thread_manager)
    plant_id = consumer.register_plant_from_database(
        name='test2 plant', 
        scientific_name='Monstera deliciosa', 
        location='my ass',
        health_status="1000,70,22,3"
    )
    unique_identifier1 = consumer.register_new_device(plant_id, 'Xiaomi Moisture Deluxe', 'test2 device 1', '1st Deluxe Moisture Machine by the window')
    consumer.activate_device(plant_id, unique_identifier1)
    unique_identifier2 = consumer.register_new_device(plant_id, 'Xiaomi Moisture Deluxe', 'test2 device 2', '2nd Deluxe Moisture Machine by the window')
    consumer.activate_device(plant_id, unique_identifier2)
    consumer.plant_care_activation(plant_id)

    time.sleep(300)


def test3():
    """Tests a user adding two plants and one device to each plant."""
    thread_manager = PlantThreadManager(interval_seconds=10)
    thread_manager.start()

    consumer = Consumer(1, "demo_user", "demo@example.com", thread_manager)
    plant_id1 = consumer.register_plant_from_database(
        name='test3 plant1', 
        scientific_name='Monstera deliciosa', 
        location='my ass',
        health_status="1000,70,22,3"
    )
    plant_id2 = consumer.register_plant(
        name='test3 plant2',
        scientific_name='Cacti Maximus',
        req_brightness=1000,
        req_humidity=10,
        req_temperature=25,
        req_moisture=1,
        health_status="1000, 11, 20, 1"
    )
    unique_identifier1 = consumer.register_new_device(plant_id1, 'Xiaomi Moisture Deluxe', 'test3 moisture', 'Deluxe Moisture Machine by the window')
    consumer.activate_device(plant_id1, unique_identifier1)

    unique_identifier2 = consumer.register_new_device(plant_id2, 'Xiaomi Temperature Deluxe', 'test3 temperature', 'Deluxe Temperature Machine on the floor')
    consumer.activate_device(plant_id2, unique_identifier2)
    
    consumer.plant_care_activation()

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
    test3()