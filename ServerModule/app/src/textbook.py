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
        low="Plant moisture has reached critically low levels! Commencing moisture increase...",
        high="Plant moisture has reached critically high levels! Commencing moisture decrease...",
        ok="Plant moisture is at acceptable levels.",
        no_sensor="Plant has no moisture sensor. Moisture values cannot be read.",
        no_actuator="Plant has no moisture actuator. Moisture cannot be altered.",
    )

    brightness = MetricMessages(
        low="Plant brightness has reached critically low levels! Commencing brightness increase...",
        high="Plant brightness has reached critically high levels! Commencing brightness decrease...",
        ok="Plant brightness is at acceptable levels.",
        no_sensor="Plant has no brightness sensor. Brightness values cannot be read.",
        no_actuator="Plant has no brightness actuator. Brightness cannot be altered.",
    )

    temperature = MetricMessages(
        low="Plant temperature has reached critically low levels! Commencing temperature increase...",
        high="Plant temperature has reached critically high levels! Commencing temperature decrease...",
        ok="Plant temperature is at acceptable levels.",
        no_sensor="Plant has no temperature sensor. Temperature values cannot be read.",
        no_actuator="Plant has no temperature actuator. Temperature cannot be altered.",
    )

    humidity = MetricMessages(
        low="Plant humidity has reached critically low levels! Commencing humidity increase...",
        high="Plant humidity has reached critically high levels! Commencing humidity decrease...",
        ok="Plant humidity is at acceptable levels.",
        no_sensor="Plant has no humidity sensor. Humidity values cannot be read.",
        no_actuator="Plant has no humidity actuator. Humidity cannot be altered.",
    )


