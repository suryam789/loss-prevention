#!/bin/bash
# Shell script for product_switching workload (object detection pipeline)
# Arguments: $1 = camera_id
#
# Usage:
#   ./product_switching.sh <camera_id>
# Example:
#   ./product_switching.sh cam1
#
# To test end-to-end via the pipeline system:
#   make run INPUT_JSON=./configs/camera_to_workload.json
# This will invoke the Python launcher, which will call this script as needed.
# Ensure you have a valid video file at /path/to/<camera_id>.mp4 or update the script accordingly.

echo "Running product_switching DLStreamer pipeline for camera: $1"
DLSTREAMER_CMD="gst-launch-1.0 filesrc location=/path/to/$1.mp4 ! decodebin ! videoconvert ! \
gvadetect model=product_switching_model.xml device=CPU ! gvawatermark ! fpsdisplaysink video-sink=xvimagesink sync=false"
echo "Executing: $DLSTREAMER_CMD"
eval $DLSTREAMER_CMD
echo "product_switching pipeline completed for camera: $1"
