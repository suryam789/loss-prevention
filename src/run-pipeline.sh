#!/bin/bash
#
# Copyright (C) 2025 Intel Corporation.
#
# SPDX-License-Identifier: Apache-2.0
#

# Get dynamic gst-launch command from Python script
# gst_cmd=$(python3 "$(dirname "$0")/gst-pipeline-generator.py")

# # Print and run the pipeline command
# echo "Running Pipeline:"
# echo "$gst_cmd"
# eval "$gst_cmd"

echo "############# RUNNING MANUAL GST COMMAND #############"

pwd

echo '{"roi": {"x": 311, "y": 888, "w": 755, "h": 445}}' > roi.txt
my_cmd="gst-launch-1.0 -e   filesrc location=/home/pipeline-server/sample-media/fake-detection-video-32658412-1920-15-bench.mp4 ! decodebin !   videoconvert ! videoscale !   gvaattachroi roi=100,150,200,300 !   video/x-raw,width=1920,height=1080 !   gvadetect inference-region=1 model=/home/pipeline-server/models/object_detection/yolo11n/INT8/yolo11n.xml device=CPU ! queue !   gvaclassify model=/home/pipeline-server/models/object_classification/efficientnet-b0/FP32/efficientnet-b0.xml device=CPU ! queue !   gvawatermark ! videoconvert !   fpsdisplaysink video-sink=fakesink text-overlay=false signal-fps-measurements=true"
echo "$my_cmd"
eval "$my_cmd"
echo "############# MANUAL GST COMMAND COMPLETED #############"

