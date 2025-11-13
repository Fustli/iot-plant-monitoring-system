from enum import IntEnum

# TODO make ENVs
TEMPERATURE_THRESHOLD = 5.0
HUMIDITY_THRESHOLD = 5.0

class Brightness(IntEnum):
    NO_LIGHT = 1
    LOW_LIGHT = 2
    MEDIUM_LIGHT = 3
    BRIGHT_INDIRECT_LIGHT = 4
    DIRECT_LIGHT = 5
    

class Moisture(IntEnum):
    DRY = 1
    MOIST = 2
    WET = 3
