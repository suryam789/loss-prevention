'''
* Copyright (C) 2024 Intel Corporation.
*
* SPDX-License-Identifier: Apache-2.0
'''

from gi.repository import Gst, GObject
import sys
import gi
import json
from copy import deepcopy
gi.require_version('Gst', '1.0')


class RoiMetadata:
    def __init__(self, disable=False, roi=""):
        self.roi = roi

    def process_frame(self, frame):

        if self.roi == "":
            return True

        for message in frame.messages():
            message_obj = json.loads(message)

            if "objects" in message_obj:
                frame.remove_message(message)
                message_objects_array = deepcopy(message_obj["objects"])

                roi_objects = []
                other_objects = []

                for obj in message_objects_array:
                    if "roi_type" in obj:
                        if obj["roi_type"] == self.roi:
                            roi_objects.append(obj)
                        else:
                            other_objects.append(obj)

                for obj in other_objects:
                    for objects in roi_objects:
                        if (obj["x"] >= objects["x"] and obj["x"] + obj["w"] <= objects["x"] + objects["w"] and
                                obj["y"] >= objects["y"] and obj["y"] + obj["h"] <= objects["y"] + objects["h"]):
                            obj["roi_type"] = self.roi

                message_obj["objects"] = other_objects + roi_objects

                frame.add_message(json.dumps(
                    message_obj, separators=(',', ':')))
                break
        return True
