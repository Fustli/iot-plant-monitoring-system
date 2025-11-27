import os
import smtplib
from email.message import EmailMessage
from db.db_utils import DBInterface

def send_alert(plant_name: str, metric: str, delta: float, msg: str, actuators_msg: str = ""):
    APP_PASSWORD = os.environ["GMAIL_APP_PASSWORD"]
    db_interface = DBInterface()
    user_id = db_interface.get_plant_user_id_by_name(plant_name)
    user_email, username = db_interface.get_user_details_by_id(user_id)

    if delta < 0:
        adjective = "high"
    elif delta > 0:
        adjective = "low"
    else:
        return
    
    if actuators_msg == "":
        actuators_msg = "Your device(s) are working on solving this problem."
    else:
        actuators_msg += f"Please add the appropriate device. Without an actuator device the plant's {metric} cannot be modified."

    targetemail_to = [user_email]

    subject = f"Your plant {plant_name} has dangerously {adjective} {metric}!"

    emailtxt=f"""
        Dear {username}

        There seems to be an issue with your {plant_name} plant:
        {msg}
        The difference between your plant's required and actual {metric} is {delta}.
        {actuators_msg}



        IOT PLANT CARE SYSTEM 
        This is an automated message, please do not reply.
        """
    
    sender = 'iot.plant.care.system@gmail.com'

    msg = EmailMessage()
    msg['Subject'] = subject
    msg['From'] = sender
    msg['To'] = ", ".join(targetemail_to)
    msg.set_content(emailtxt)
    # SMTP szerverrel való kapcsolódás (pl. Gmail)
    with smtplib.SMTP_SSL('smtp.gmail.com', 465) as smtp:
        smtp.login(sender, APP_PASSWORD)
        smtp.send_message(msg)
