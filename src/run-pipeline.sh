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
# Print and run the pipeline command
echo "################# Running Pipeline ###################"
echo "$gst_cmd"
eval "$gst_cmd"

echo "############# GST COMMAND COMPLETED SUCCESSFULLY #############"