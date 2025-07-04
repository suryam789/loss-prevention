#!/bin/bash
#
# Copyright (C) 2025 Intel Corporation.
#
# SPDX-License-Identifier: Apache-2.0
#

# Get dynamic gst-launch command from Python script

echo "############# Generating GStreamer pipeline command ##########"
 
gst_cmd=$(python3 "$(dirname "$0")/gst-pipeline-generator.py")
echo "#############  GStreamer pipeline command generated succussfully ##########"

# Generate timestamp for log files
timestamp=$(date +"%Y%m%d_%H%M%S")
# Append logging pipeline to gst_cmd with proper line breaks
gst_cmd=$(printf "%s \\\\\n\\\\\n%s" "$gst_cmd" "2>&1 | tee /home/pipeline-server/results/pipeline_${timestamp}.log | (stdbuf -oL sed -n -E 's/.*total=([0-9]+\.[0-9]+) fps.*/\1/p' > /home/pipeline-server/results/fps_${timestamp}.log)")

# Print and run the pipeline command
echo "################# Running Pipeline ###################"
echo "$gst_cmd"
eval "$gst_cmd"

echo "############# GST COMMAND COMPLETED SUCCESSFULLY #############"

sleep 10m