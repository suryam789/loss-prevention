#!/bin/bash
#
# Copyright (C) 2025 Intel Corporation.
#
# SPDX-License-Identifier: Apache-2.0
#

set -euo pipefail

SCRIPT_BASE_PATH=/workspace/scripts/
# MODELS_PATH is set to /workspace/models by default, matching the container mount
MODELS_PATH="${MODELS_DIR:-/workspace/models}"
mkdir -p "$MODELS_PATH"
cd "$MODELS_PATH" || { echo "Failure to cd to $MODELS_PATH"; exit 1; }

pwd 

# Path to workload_to_pipeline.json
WORKLOAD_DIST="${WORKLOAD_DIST:-workload_to_pipeline.json}"
CONFIG_JSON="/workspace/configs/${WORKLOAD_DIST}"

echo "[INFO] Using workload configuration: ${WORKLOAD_DIST}"
echo "[INFO] Config path: ${CONFIG_JSON}"

if [[ ! -f "$CONFIG_JSON" ]]; then
    echo "[ERROR] Configuration file not found: $CONFIG_JSON" >&2
    exit 1
fi
# Check for jq
if ! command -v jq &>/dev/null; then
    echo "[ERROR] jq is required but not installed. Please install jq." >&2
    exit 1
fi

# Extract all type/model pairs from the JSON
mapfile -t MODEL_DATA < <(jq -r '
  .workload_pipeline_map[] | 
  .[] | 
  [.type, .model, .device, .precision] | @tsv
' "$CONFIG_JSON" | sort -u)

echo "[INFO] Found ${#MODEL_DATA[@]} model configurations to process."

declare -A TYPE_MODELS

# Build associative array: TYPE_MODELS[type]="model1,model2,..."
for DATA in "${MODEL_DATA[@]}"; do
    TYPE_RAW="$(echo "$DATA" | cut -f1)"
    MODEL_NAME_RAW="$(echo "$DATA" | cut -f2)"
    DEVICE="$(echo "$DATA" | cut -f3)"
    PRECISION="$(echo "$DATA" | cut -f4)"
    
    MODEL_NAME="${MODEL_NAME_RAW%.xml}"
    TYPE_KEY="$(echo "$TYPE_RAW" | tr '[:upper:]' '[:lower:]')"
    ENTRY="$MODEL_NAME"
    
    if [[ -z "${TYPE_MODELS[$TYPE_KEY]+x}" ]]; then
        TYPE_MODELS[$TYPE_KEY]="$ENTRY"
    else
        # Only add if not already present
        if [[ ",${TYPE_MODELS[$TYPE_KEY]}," != *",$ENTRY,"* ]]; then
            TYPE_MODELS[$TYPE_KEY]+=",$ENTRY"
        fi
    fi
done

echo "####### MODEL_TYPES ====  "${!TYPE_MODELS[@]}""

for TYPE_KEY in "${!TYPE_MODELS[@]}"; do
    IFS=',' read -ra MODELS <<< "${TYPE_MODELS[$TYPE_KEY]}"
    for MODEL_NAME in "${MODELS[@]}"; do
        MODEL_PATH="$MODELS_PATH/$MODEL_NAME"
        # Check if the model already exists (any precision)
        if find "$MODELS_PATH" -type f -path "*/$MODEL_NAME/*.xml" | grep -q "$MODEL_NAME.xml"; then
            echo "[INFO] ########## Model $MODEL_NAME already exists under $MODELS_PATH, skipping download."
            continue
        fi


        # Extract precision directly from JSON (unified logic)
        PRECISION=$(jq -r --arg model "$MODEL_NAME" '
          .workload_pipeline_map[] |
          .[] |
          select(.model == $model) |
          .precision // "FP16"
        ' "$CONFIG_JSON" | head -1)

        # Fallback if not found
        if [[ -z "$PRECISION" || "$PRECISION" == "null" ]]; then
            PRECISION="FP16"
        fi

        echo "[INFO] ########### Processing $MODEL_NAME ($TYPE_KEY) with precision $PRECISION ..."

        case "$TYPE_KEY" in
            gvadetect|object_detection)
                if [[ "$MODEL_NAME" == face-detection-retail-* ]]; then
                    echo "[INFO] ###### Downloading face detection model: $MODEL_NAME ($PRECISION)"
                    "$SCRIPT_BASE_PATH/omz-model-download.sh" "$MODEL_NAME" "$MODELS_PATH/object_detection" "$PRECISION"
                else
                    echo "[INFO] ###### Downloading YOLO model: $MODEL_NAME ($PRECISION)"
                    python3 "$SCRIPT_BASE_PATH/model_convert.py" export_yolo "$MODEL_NAME" "$MODELS_PATH"

                    quant_dataset="$MODELS_PATH/datasets/coco128.yaml"
                    if [ ! -f "$quant_dataset" ]; then
                        mkdir -p "$(dirname "$quant_dataset")"
                        wget --no-check-certificate --timeout=30 --tries=2 \
                            "https://raw.githubusercontent.com/ultralytics/ultralytics/v8.1.0/ultralytics/cfg/datasets/coco128.yaml" \
                            -O "$quant_dataset"
                    fi
                    python3 "$SCRIPT_BASE_PATH/model_convert.py" quantize_yolo "$MODEL_NAME" "$quant_dataset" "$MODELS_PATH"
                fi
                ;;
            gvaclassify|object_classification)
                if [[ "$MODEL_NAME" == face-reidentification-retail-* ]]; then
                    echo "[INFO] ###### Downloading face reidentification model: $MODEL_NAME ($PRECISION)"
                    "$SCRIPT_BASE_PATH/omz-model-download.sh" "$MODEL_NAME" "$MODELS_PATH/object_classification" "$PRECISION"
                else
                    echo "[INFO] ###### Downloading classification model: $MODEL_NAME ($PRECISION)"
                    python3 "$SCRIPT_BASE_PATH/effnetb0_download.py" "$MODEL_NAME" "$MODELS_PATH"
                fi
                ;;
            gvainference)
                echo "[INFO] ###### Downloading inference model: $MODEL_NAME ($PRECISION)"
                "$SCRIPT_BASE_PATH/omz-model-download.sh" "$MODEL_NAME" "$MODELS_PATH/object_classification" "$PRECISION"
                ;;
            *)
                echo "[WARN] Unsupported type: $TYPE_KEY (model: $MODEL_NAME)"
                ;;
        esac
    done
done





echo "###################### Model downloading has been completed successfully #########################"
