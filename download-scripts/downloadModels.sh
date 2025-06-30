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
CONFIG_JSON="/workspace/configs/workload_to_pipeline.json"

# Check for jq
if ! command -v jq &>/dev/null; then
    echo "[ERROR] jq is required but not installed. Please install jq." >&2
    exit 1
fi

# Extract all type/model from all arrays in the JSON (handle nested arrays in objects)
mapfile -t MODEL_PAIRS < <(jq -r '
  to_entries[] |
  if (.value | type == "array") then
    .value[] | select(.type and .model) | [.type, .model] | @tsv
  elif (.value | type == "object") then
    .value[]? | select(type == "array") | .[] | select(.type and .model) | [.type, .model] | @tsv
  else
    empty
  end
' "$CONFIG_JSON" | sort -u)

declare -A TYPE_MODELS

# Build associative array: TYPE_MODELS[type]="model1,model2,..."
for PAIR in "${MODEL_PAIRS[@]}"; do
    TYPE_RAW="$(echo "$PAIR" | cut -f1)"
    MODEL_NAME_RAW="$(echo "$PAIR" | cut -f2)"
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
        if [ -e "$MODEL_PATH" ]; then
            echo "[INFO] ########## $MODEL_NAME already exists, skipping download."
            continue
        fi
        echo "[INFO] ########### Processing $MODEL_NAME ($TYPE_KEY) ..."
        case "$TYPE_KEY" in
            gvadetect|object_detection)
                echo "[INFO] ######  Downloading and converting model: $MODEL_NAME"
                python3 "$SCRIPT_BASE_PATH/model_convert.py" export_yolo "$MODEL_NAME" "$MODELS_PATH"
                # Quantize if needed
                quant_dataset="$MODELS_PATH/datasets/coco128.yaml"
                if [ ! -f "$quant_dataset" ]; then
                    mkdir -p "$(dirname "$quant_dataset")"
                    wget --timeout=30 --tries=2 "https://raw.githubusercontent.com/ultralytics/ultralytics/v8.1.0/ultralytics/cfg/datasets/coco128.yaml" -O "$quant_dataset"
                fi
                python3 "$SCRIPT_BASE_PATH/model_convert.py" quantize_yolo "$MODEL_NAME" "$quant_dataset" "$MODELS_PATH"
                ;;
            gvaclassify|object_classification)
                echo "[INFO] ######  Downloading and converting object classification model: $MODEL_NAME"
                python3 "$SCRIPT_BASE_PATH/efnetv2s_download_quant.py" "$MODEL_NAME" "$MODELS_PATH"
                ;;
            face_detection)
                python3 "$SCRIPT_BASE_PATH/model_convert.py" face_detection "$MODEL_NAME" "$MODELS_PATH"
                ;;
            *)
                echo "[WARN] Unsupported type: $TYPE_KEY, skipping..."
                ;;
        esac
    done
done

echo "###################### Model downloading has been completed successfully #########################"