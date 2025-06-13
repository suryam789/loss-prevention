#!/bin/bash
# Shell script for hidden_item workload (object detection pipeline)
# Arguments: $1 = camera_id

echo "Running hidden_item DLStreamer pipeline for camera: $1"
# Example DLStreamer pipeline command (replace with actual pipeline as needed)
DLSTREAMER_CMD="gst-launch-1.0 filesrc location=/path/to/$1.mp4 ! decodebin ! videoconvert ! \
gvadetect model=hidden_item_model.xml device=CPU ! gvawatermark ! fpsdisplaysink video-sink=xvimagesink sync=false"
echo "Executing: $DLSTREAMER_CMD"
eval $DLSTREAMER_CMD
echo "hidden_item pipeline completed for camera: $1"
