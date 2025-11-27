from dataclasses import dataclass


@dataclass(frozen=True)
class MetricMessages:
    low: str
    high: str
    ok: str
    no_sensor: str
    no_actuator: str


class Textbook:
    moisture = MetricMessages(
        low="Plant moisture has reached critically low levels! Commencing moisture increase...\n",
        high="Plant moisture has reached critically high levels! Commencing moisture decrease...\n",
        ok="Plant moisture is at acceptable levels.\n",
        no_sensor="Plant has no moisture sensor. Moisture values cannot be read.\n",
        no_actuator="Plant has no moisture actuator. Moisture cannot be altered.\n",
    )

    brightness = MetricMessages(
        low="Plant brightness has reached critically low levels! Commencing brightness increase...\n",
        high="Plant brightness has reached critically high levels! Commencing brightness decrease...\n",
        ok="Plant brightness is at acceptable levels.",
        no_sensor="Plant has no brightness sensor. Brightness values cannot be read.\n",
        no_actuator="Plant has no brightness actuator. Brightness cannot be altered.\n",
    )

    temperature = MetricMessages(
        low="Plant temperature has reached critically low levels! Commencing temperature increase...\n",
        high="Plant temperature has reached critically high levels! Commencing temperature decrease...\n",
        ok="Plant temperature is at acceptable levels.\n",
        no_sensor="Plant has no temperature sensor. Temperature values cannot be read.\n",
        no_actuator="Plant has no temperature actuator. Temperature cannot be altered.\n",
    )

    humidity = MetricMessages(
        low="Plant humidity has reached critically low levels! Commencing humidity increase...\n",
        high="Plant humidity has reached critically high levels! Commencing humidity decrease...\n",
        ok="Plant humidity is at acceptable levels.\n",
        no_sensor="Plant has no humidity sensor. Humidity values cannot be read.\n",
        no_actuator="Plant has no humidity actuator. Humidity cannot be altered.\n",
    )

    plant_object_creation = "Created Plant object with name: "
    plant_creation_in_db = "Created plant in plants table with plant_name: "
    plant_type_creation_in_db = "Created plant type in plant_types table with scientific_name: "

    device_object_creation = "Created Device object with unique_identifier: "
    device_creation_in_db = "Created device in devices table with unique_identifier: "
    device_type_creation_in_db = "Created device type in device_types table with name: "

    attach_plant_to_consumer = "Attached to consumer a new plant named: "
    attach_device_to_plant = "Attached to consumer's plant a new device. "
