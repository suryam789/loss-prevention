import uuid
import json

frame_counter = 0

def process_frame(frame):
    global frame_counter
    frame_counter += 1

    output = {
        "event_id": str(uuid.uuid4()),
        "frame_id": f"frame_{frame_counter:06d}",
        "station_id": "self_checkout_01",
        "camera_id": "camera_001",
        "camera_name": "self_checkout_overhead",
        "persons": []
    }

    # Optionally extract regions (ROIs) if available
    for roi in frame.regions():
        rect = roi.rect()  # returns normalized bbox
        output["persons"].append({
            "bbox": {
                "x": rect.x,
                "y": rect.y,
                "w": rect.w,
                "h": rect.h
            },
            "confidence": roi.confidence(),
            "person_id": str(uuid.uuid4())  # or assign based on ReID
        })

    json_line = json.dumps(output)
    #print(json_line)
    try:
        with open("/home/pipeline-server/results/person-data.jsonl", "a") as f:
            f.write(json_line + "\n")
    except Exception as e:
        print(f"[custom_reid] ERROR: Failed to write to /home/pipeline-server/results/person-data.jsonl: {e}")
    return True
