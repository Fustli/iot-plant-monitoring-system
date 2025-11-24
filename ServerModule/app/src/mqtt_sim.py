

class MQTTSimulator:
    """Simulates devices sending info using MQTT."""
    def __init__(self):
        self.messages = [
            {
                "device_id": "id",
                "data_type": "Temperature",
                "data": "10.0",
                "data_unit": "Celsius"
            },
            {
                "device_id": "id",
                "data_type": "Humidity",
                "data": "60.0",
                "data_unit": "Percentage"
            },
            {
                "device_id": "id",
                "data_type": "Brightness",
                "data": "500",
                "data_unit": "lux"
            },
            {
                "device_id": "id",
                "data_type": "Moisture",
                "data": "WET",
                "data_unit": "Moisture"
            }
        ]

# TODO
# Gyűlnek a messagek egy log fileban, amit időnként átmásolunk a db-be
