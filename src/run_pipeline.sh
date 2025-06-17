#!/bin/bash

# Get dynamic gst-launch command(s) from Python script
PIPELINES=$(python3 "$(dirname "$0")/run_loss_prevention.py")

# Execute each pipeline command
while IFS= read -r PIPELINE; do
    echo "Running Pipeline:"
    echo "$PIPELINE"
    eval "$PIPELINE"
done <<< "$PIPELINES"
