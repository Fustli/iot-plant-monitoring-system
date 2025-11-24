from enum import IntEnum

# TODO make ENVs
TEMPERATURE_THRESHOLD = 2.0
HUMIDITY_THRESHOLD = 5.0
BRIGHTNESS_THRESHOLD = 50.0    

class Moisture(IntEnum):
    DRY = 1
    MOIST = 2
    WET = 3
