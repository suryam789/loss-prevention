'''
* Copyright (C) 2024 Intel Corporation.
*
* SPDX-License-Identifier: Apache-2.0
'''

import os
import json
from flask import Flask, jsonify
import time
import paho.mqtt.client as mqtt
import threading

# MQTT and ROI Configuration
MQTT_BROKER_URL = os.getenv("MQTT_URL", "127.0.0.1")
MQTT_PORT = int(os.getenv("MQTT_PORT", "1883"))
MQTT_TOPIC = os.getenv("MQTT_TOPIC", "event/detection")
ROI_NAMES = os.getenv("ROI_NAMES", "BASKET,BAGGING").split(',')

current_objects_in_roi = {roi_name: {} for roi_name in ROI_NAMES}
alerts = []

app = Flask(__name__)

@app.route('/current_objects', methods=['GET'])
def get_current_objects():    
    formatted_data = {
        roi_name: [{"id": obj_id, "label": label} for obj_id, label in objects.items()]
        for roi_name, objects in current_objects_in_roi.items()
    }
    return jsonify(formatted_data)

@app.route('/alerts', methods=['GET'])
def get_alerts():
    return jsonify({"alerts": alerts})

def on_message(client, userdata, message):
    global current_objects_in_roi

    frame_data = json.loads(message.payload.decode("utf-8"))
    objects_in_current_frame = {roi_name: {} for roi_name in ROI_NAMES}

    if "objects" in frame_data:
        for obj in frame_data["objects"]:
            roi_type = obj.get("roi_type")
            label = obj["detection"]["label"]
            obj_id = obj["id"]
            
            if roi_type in ROI_NAMES and label != roi_type:
                objects_in_current_frame[roi_type][obj_id] = label

    for roi_name in ROI_NAMES:
        entered_objects = {
            obj_id: label for obj_id, label in objects_in_current_frame[roi_name].items()
            if obj_id not in current_objects_in_roi[roi_name]
        }
        left_objects = {
            obj_id: label for obj_id, label in current_objects_in_roi[roi_name].items()
            if obj_id not in objects_in_current_frame[roi_name]
        }
        
        print_logs(roi_name, entered_objects, left_objects)                
        
        current_objects_in_roi[roi_name] = objects_in_current_frame[roi_name]
    
    print(f"Current objects in ROIs: {current_objects_in_roi}")

def print_logs(roi_name, entered_objects, left_objects):
    for obj_id, label in entered_objects.items():
        print(f"Object {label} (ID: {obj_id}) entered the {roi_name} ROI.")

    for obj_id, label in left_objects.items():
        if roi_name == "BAGGING":
            print(f"ALERT: Object {label} (ID: {obj_id}) was inside the BAGGING ROI and has now left.")            
            alerts.append({
                "id": obj_id,
                "label": label,
                "timestamp": int(time.time())
            })
        else:
            print(f"Object {label} (ID: {obj_id}) left the {roi_name} ROI.")

def on_connect(client, userdata, flags, rc):
    print(f"Connected to MQTT")
    client.subscribe(MQTT_TOPIC)

def start_mqtt_client():
    client = mqtt.Client(client_id="", clean_session=True, userdata=None, protocol=mqtt.MQTTv311, transport="tcp")
    client.on_connect = on_connect
    client.on_message = on_message

    client.connect(MQTT_BROKER_URL, MQTT_PORT, 60)
    client.loop_forever()

mqtt_thread = threading.Thread(target=start_mqtt_client)
mqtt_thread.start()

if __name__ == '__main__':
    app.run(port=5000)
