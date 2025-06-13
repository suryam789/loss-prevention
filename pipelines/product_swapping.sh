#!/bin/bash
# Shell script for product_swapping workload (object detection pipeline)
# Arguments: $1 = camera_id

echo "Running product_swapping DLStreamer pipeline for camera: $1"
DLSTREAMER_CMD="gst-launch-1.0 filesrc location=/path/to/$1.mp4 ! decodebin ! videoconvert ! \
gvadetect model=product_swapping_model.xml device=CPU ! gvawatermark ! fpsdisplaysink video-sink=xvimagesink sync=false"
echo "Executing: $DLSTREAMER_CMD"
eval $DLSTREAMER_CMD
echo "product_swapping pipeline completed for camera: $1"
