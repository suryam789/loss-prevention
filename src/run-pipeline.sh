#!/bin/bash

# -----------------------------
# Configuration & Environment
# -----------------------------
CAMERA_STREAM="${CAMERA_STREAM:-camera_to_workload.json}"
WORKLOAD_DIST="${WORKLOAD_DIST:-workload_to_pipeline.json}"

export CAMERA_STREAM
export WORKLOAD_DIST

echo "################# Using camera config: $CAMERA_STREAM ###################"
echo "################# Using workload config: $WORKLOAD_DIST ###################"

export PYTHONPATH=/home/pipeline-server/src:$PYTHONPATH

# Use TIMESTAMP env variable if set, otherwise fallback to date
cid=$(date +%Y%m%d%H%M%S)$(date +%6N | cut -c1-6)
export TIMESTAMP=$cid
echo "===============TIMESTAMP===================: $TIMESTAMP"

CONTAINER_NAME="${CONTAINER_NAME//\"/}" # Remove double quotes
cid="${cid}_${CONTAINER_NAME}"
echo "==================CONTAINER_NAME: ${CONTAINER_NAME}"
echo "cid: $cid"

echo "############# Generating GStreamer pipeline command ##########"
echo "################### RENDER_MODE ################# $RENDER_MODE"

gst_cmd=$(python3 "$(dirname "$0")/gst-pipeline-generator.py")
echo "#############  GStreamer pipeline command generated successfully ##########"

# -----------------------------
# Prepare pipelines directory
# -----------------------------
pipelines_dir="/home/pipeline-server/pipelines"
mkdir -p "$pipelines_dir"

if [ -d "$pipelines_dir" ]; then
    echo "################# Pipelines directory exists: $pipelines_dir ###################"
else
    echo "################# ERROR: Failed to create pipelines directory: $pipelines_dir ###################"
fi

# Create pipeline.sh
pipeline_file="$pipelines_dir/pipeline.sh"
echo "################# Creating pipeline file: $pipeline_file ###################"
echo "#!/bin/bash" > "$pipeline_file"
echo "# Generated GStreamer pipeline command" >> "$pipeline_file"
echo "# Generated on: $(date)" >> "$pipeline_file"
echo "" >> "$pipeline_file"
echo "$gst_cmd" >> "$pipeline_file"
chmod +x "$pipeline_file"

if [ -f "$pipeline_file" ]; then
    echo "################# Pipeline file created successfully: $pipeline_file ###################"
    echo "################# File size: $(stat -c%s "$pipeline_file") bytes ###################"
else
    echo "################# ERROR: Failed to create pipeline file: $pipeline_file ###################"
fi

# -----------------------------
# Prepare result directory
# -----------------------------
results_dir="/home/pipeline-server/results"
mkdir -p "$results_dir"

# Count filesrc lines to determine number of streams
filesrc_count=$(grep -c "filesrc location=" "$pipeline_file")
echo "Found $filesrc_count filesrc lines in $pipeline_file"

# Create per-stream pipeline log files
declare -a pipeline_logs
for i in $(seq 1 $filesrc_count); do
    logfile="$results_dir/pipeline${cid}_stream${i}.log"
    pipeline_logs+=("$logfile")
    > "$logfile"  # empty the file
done

# -----------------------------
# Run pipeline and capture FPS
# -----------------------------
gst_log="$results_dir/gst-launch_$cid.log"
echo "################# Running Pipeline ###################"
echo "GST_DEBUG=\"GST_TRACER:7\" GST_TRACERS='latency_tracer(flags=pipeline)' bash $pipeline_file"

gst_log="$results_dir/gst-launch_$cid.log"

# Run gst-launch in background and tee to log
stdbuf -oL bash "$pipeline_file" 2>&1 | tee "$gst_log" &
GST_PID=$!

# Read the gst log file in "tail -F" mode
tail -F "$gst_log" | while read -r line; do
    # Match FpsCounter lines
    if [[ "$line" =~ FpsCounter.*number-streams=([0-9]+).*per-stream=.*\((.*)\) ]]; then
        num_streams="${BASH_REMATCH[1]}"
        fps_values="${BASH_REMATCH[2]}"

        # Only process if number-streams matches filesrc count
        if [[ "$num_streams" -eq "$filesrc_count" ]]; then
            # Remove spaces after commas and split
            IFS=',' read -ra fps_array <<< "$(echo "$fps_values" | tr -d ' ')"
            for idx in "${!fps_array[@]}"; do
                fps="${fps_array[idx]}"
                if [[ idx -lt ${#pipeline_logs[@]} ]]; then
                    echo "$fps" >> "${pipeline_logs[idx]}"
                fi
            done
        fi
    fi
done

wait $GST_PID


echo "############# GST COMMAND COMPLETED SUCCESSFULLY #############"
