from db.db_utils import DBInterface

def send_alert(plant_id: int, metric: str, delta: float, msg: str, no_actuators=False):
    db_interface = DBInterface()
    user_id, plant_name = db_interface.get_plant_details_by_id(plant_id)

    if delta > 0:
        adjective = "high"
    if delta < 0:
        adjective = "low"
    else:
        return

    header = f"Your plant {plant_name} has dangerously {adjective} {metric}!"
