import json
from gstgva import VideoFrame

class ReIDHandler:
    def __init__(self):
        self.person_id_counter = 0

    def process_frame(self, frame: VideoFrame) -> bool:
        output = {
            "objects": [],
            "resolution": {
                "height": frame.video_info().height,
                "width": frame.video_info().width
            },
            #"timestamp": frame._gst_buffer.pts  # in nanoseconds
        }

        for roi in frame.regions():
            detection = {
                "detection": {
                    "bounding_box": {
                        "x_min": roi.bbox().x,
                        "y_min": roi.bbox().y,
                        "x_max": roi.bbox().x + roi.bbox().w,
                        "y_max": roi.bbox().y + roi.bbox().h,
                    },
                    "confidence": roi.confidence(),
                    "label_id": roi.label_id()
                },
                "id": roi.object_id(),
                "region_id": roi.region_id(),
                "x": roi.bbox().x,
                "y": roi.bbox().y,
                "w": roi.bbox().w,
                "h": roi.bbox().h
            }
            output["objects"].append(detection)

        print(json.dumps(output))  # or write to .jsonl file
        return True


