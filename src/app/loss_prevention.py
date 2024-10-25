'''
* Copyright (C) 2024 Intel Corporation.
*
* SPDX-License-Identifier: Apache-2.0
'''

import os
import json
import paho.mqtt.client as mqtt

MQTT_BROKER_URL = os.getenv("MQTT_URL", "127.0.0.1")
MQTT_PORT = int(os.getenv("MQTT_PORT", "1883"))
MQTT_TOPIC = os.getenv("MQTT_TOPIC", "event/detection")
ROI_NAME = os.getenv("ROI_NAME", "BASKET")

current_objects_in_roi = {}

def on_message(client, userdata, message):
    global current_objects_in_roi

    frame_data = json.loads(message.payload.decode("utf-8"))
    objects_in_current_frame = {}

    if "objects" in frame_data:
        for obj in frame_data["objects"]:
            if obj.get("roi_type") == ROI_NAME and obj["detection"].get("label") == ROI_NAME:
                continue

            obj_id = obj["id"]
            label = obj["detection"]["label"]
            objects_in_current_frame[obj_id] = label

    entered_objects = {obj_id: label for obj_id, label in objects_in_current_frame.items() if obj_id not in current_objects_in_roi}
    left_objects = {obj_id: label for obj_id, label in current_objects_in_roi.items() if obj_id not in objects_in_current_frame}

    for obj_id, label in entered_objects.items():
        print(f"Object {label} (ID: {obj_id}) entered the {ROI_NAME} ROI.")

    for obj_id, label in left_objects.items():
        print(f"Object {label} (ID: {obj_id}) left the {ROI_NAME} ROI.")

    current_objects_in_roi = objects_in_current_frame
    
    print(f" Current objects in ROI: {current_objects_in_roi}")

def on_connect(client, userdata, flags, rc):
    print(f"Connected with result code {rc}")
    client.subscribe(MQTT_TOPIC)

client = mqtt.Client(client_id="", clean_session=True, userdata=None, protocol=mqtt.MQTTv311, transport="tcp")
client.on_connect = on_connect
client.on_message = on_message

client.connect(MQTT_BROKER_URL, MQTT_PORT, 60)
client.loop_forever()
