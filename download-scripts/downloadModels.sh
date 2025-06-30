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

# Extract all model_category/model/model_type (optional) from all arrays in the JSON (handle nested arrays in objects)
mapfile -t MODEL_PAIRS < <(jq -r '
  to_entries[] |
  if (.value | type == "array") then
    .value[] | select(.model_category and .model) | [.model_category, .model, (.model_type // "")] | @tsv
  elif (.value | type == "object") then
    .value[]? | select(type == "array") | .[] | select(.model_category and .model) | [.model_category, .model, (.model_type // "")] | @tsv
  else
    empty
  end
' "$CONFIG_JSON" | sort -u)

declare -A CATEGORY_MODELS

# Build associative array: CATEGORY_MODELS[category]="model1|type1,model2|type2,..."
for PAIR in "${MODEL_PAIRS[@]}"; do
    MODEL_CATEGORY_ORIG="$(echo "$PAIR" | cut -f1)"
    MODEL_NAME_RAW="$(echo "$PAIR" | cut -f2)"
    MODEL_TYPE_RAW="$(echo "$PAIR" | cut -f3)"
    MODEL_NAME="${MODEL_NAME_RAW%.xml}"
    MODEL_TYPE="$MODEL_TYPE_RAW"
    MODEL_CATEGORY="$(echo "$MODEL_CATEGORY_ORIG" | tr '[:upper:]' '[:lower:]')"
    ENTRY="$MODEL_NAME|$MODEL_TYPE"
    if [[ -z "${CATEGORY_MODELS[$MODEL_CATEGORY]+x}" ]]; then
        CATEGORY_MODELS[$MODEL_CATEGORY]="$ENTRY"
    else
        # Only add if not already present
        if [[ ",${CATEGORY_MODELS[$MODEL_CATEGORY]}," != *",$ENTRY,"* ]]; then
            CATEGORY_MODELS[$MODEL_CATEGORY]+=",$ENTRY"
        fi
    fi
done

echo "####### MODEL_CATEGORIES"${!CATEGORY_MODELS[@]}

for MODEL_CATEGORY in "${!CATEGORY_MODELS[@]}"; do
    IFS=',' read -ra MODELS <<< "${CATEGORY_MODELS[$MODEL_CATEGORY]}"
    for MODEL_PAIR in "${MODELS[@]}"; do
        MODEL_NAME="${MODEL_PAIR%%|*}"
        MODEL_TYPE="${MODEL_PAIR#*|}"
        MODEL_PATH="$MODELS_PATH/$MODEL_NAME"
        if [ -e "$MODEL_PATH" ]; then
            echo "[INFO] $MODEL_NAME already exists, skipping download."
            continue
        fi
        echo "[INFO] Processing $MODEL_NAME ($MODEL_CATEGORY, $MODEL_TYPE) ..."
        case "$MODEL_CATEGORY" in
            object_detection)
                python3 "$SCRIPT_BASE_PATH/model_convert.py" export_yolo "$MODEL_NAME" "$MODEL_TYPE" "$MODELS_PATH"
                # Quantize if needed
                quant_dataset="$MODELS_PATH/datasets/coco128.yaml"
                if [ ! -f "$quant_dataset" ]; then
                    mkdir -p "$(dirname "$quant_dataset")"
                    wget --timeout=30 --tries=2 "https://raw.githubusercontent.com/ultralytics/ultralytics/v8.1.0/ultralytics/cfg/datasets/coco128.yaml" -O "$quant_dataset"
                fi
                python3 "$SCRIPT_BASE_PATH/model_convert.py" quantize_yolo "$MODEL_NAME" "$quant_dataset" "$MODELS_PATH"
                ;;
            object_classification)
                python3 "$SCRIPT_BASE_PATH/model_convert.py" object_classification "$MODEL_NAME" "$MODELS_PATH"
                ;;
            face_detection)
                python3 "$SCRIPT_BASE_PATH/model_convert.py" face_detection "$MODEL_NAME" "$MODELS_PATH"
                ;;
            *)
                echo "[WARN] Unsupported model category: $MODEL_CATEGORY, skipping..."
                ;;
        esac
    done
done

echo "###################### Model downloading has been completed successfully #########################"