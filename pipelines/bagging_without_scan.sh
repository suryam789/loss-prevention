#!/bin/bash
# Shell script for bagging_without_scan workload (object detection pipeline)
# Arguments: $1 = camera_id

echo "Running bagging_without_scan DLStreamer pipeline for camera: $1"
DLSTREAMER_CMD="gst-launch-1.0 filesrc location=/path/to/$1.mp4 ! decodebin ! videoconvert ! \
gvadetect model=bagging_without_scan_model.xml device=CPU ! gvawatermark ! fpsdisplaysink video-sink=xvimagesink sync=false"
echo "Executing: $DLSTREAMER_CMD"
eval $DLSTREAMER_CMD
echo "bagging_without_scan pipeline completed for camera: $1"
