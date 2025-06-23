#!/bin/bash
#
# Copyright (C) 2024 Intel Corporation.
#
# SPDX-License-Identifier: Apache-2.0
#

modelPrecisionFP16INT8="FP16-INT8"
modelPrecisionFP32INT8="FP32-INT8"
modelPrecisionFP32="FP32"
# Default values
MODEL_NAME=${1:-yolo11n}
MODEL_TYPE=${2:-yolo_v11}
REFRESH_MODE=0

shift 2
while [ $# -gt 0 ]; do
    case "$1" in
        --refresh)
            echo "running model downloader in refresh mode"
            REFRESH_MODE=1
            ;;
        *)
            echo "Invalid flag: $1" >&2
            exit 1
            ;;
    esac
    shift
done

# Debugging output
echo "MODEL_NAME: $MODEL_NAME"
echo "MODEL_TYPE: $MODEL_TYPE"
echo "REFRESH_MODE: $REFRESH_MODE"

# Use MODELS_DIR env var if set, otherwise default to /models (for container) or /home/pipeline-server/models (for legacy)
MODELS_BASE_DIR="${MODELS_DIR:-/models}"
OUTPUT_DIR="$MODELS_BASE_DIR/object_detection/$MODEL_NAME"
if [ ! -d "$OUTPUT_DIR" ]; then
  echo "Creating output directory: $OUTPUT_DIR"
  mkdir -p "$OUTPUT_DIR"
else
  echo "Output directory already exists: $OUTPUT_DIR"
fi
echo "Output directory: $OUTPUT_DIR"

pwd 
ls /home 

pipelineZooModel="https://github.com/dlstreamer/pipeline-zoo-models/raw/main/storage/"

# Function to call the Python script for downloading and converting models
downloadModel() {
    local model_name=$1
    local model_type=$2
    echo "[INFO] Checking if YOLO model already exists: $MODEL_NAME"   
    local bin_path="$OUTPUT_DIR/FP16/${MODEL_NAME}.bin"
     if [ -f "$bin_path" ]; then
        echo "[INFO] Model $MODEL_NAME already exists at $bin_path. Skipping download and setup."
        return 1
    fi

    VENV_DIR="$HOME/.virtualenvs/dlstreamer"
    if [ ! -d "$VENV_DIR" ]; then
        echo "Creating virtual environment in $VENV_DIR..."
        python3 -m venv "$VENV_DIR" || { echo "Failed to create virtual environment"; exit 1; }
    fi

    echo "Activating virtual environment in $VENV_DIR..."
    source "$VENV_DIR/bin/activate"

    echo "Installing required Python packages..."
    pip install --no-cache-dir --upgrade pip
    pip install --no-cache-dir openvino==2024.6.0 openvino-dev ultralytics || { echo "Failed to install Python packages"; exit 1; }

    echo "Downloading and converting model: $model_name ($model_type)"
    python3 /scripts/download_convert_model.py "$MODEL_NAME" "$MODEL_TYPE" --output_dir "$OUTPUT_DIR"
    if [ $? -ne 0 ]; then
    echo "Error: Failed to download and convert model $model_name"
    exit 1
    fi

    echo "Model $model_name downloaded and converted successfully!"
}
# $1 model file name
# $2 download URL
# $3 model percision
getModelFiles() {
    # Get the models
    wget "$2"/"$3"/"$1"".bin" -P "$4"/"$1"/"$3"/
    wget "$2"/"$3"/"$1"".xml" -P "$4"/"$1"/"$3"/
}

# $1 model file name
# $2 download URL
# $3 json file name
# $4 process file name (this can be different than the model name ex. horizontal-text-detection-0001 is using horizontal-text-detection-0002.json)
# $5 precision folder
getProcessFile() {
    # Get process file
    wget "$2"/"$3".json -O "$5"/"$1"/"$4".json
}

# $1 model name
# $2 download label URL
# $3 label file name
getLabelFile() {
    wget "$2/$3" -P "$4"/"$1"
}


# efficientnet-b0 (model isunsupported in {'FP32-INT8'} precisions, so we have custom downloading function below:
downloadEfficientnetb0() {
    efficientnetb0="efficientnet-b0"
    modelType=object_classification
    # Use MODELS_BASE_DIR for all downloads
    efficientnet_dir="$MODELS_BASE_DIR/$modelType/$efficientnetb0"
    customefficientnetb0Modelfile="$efficientnet_dir/$efficientnetb0.json"
    if [ ! -f $customefficientnetb0Modelfile ]; then
        echo "downloading model efficientnet $modelPrecisionFP32INT8 model..."
        mkdir -p "$efficientnet_dir/$modelPrecisionFP32"
        wget "https://github.com/dlstreamer/pipeline-zoo-models/raw/main/storage/efficientnet-b0_INT8/$modelPrecisionFP32INT8/efficientnet-b0.bin" -P "$efficientnet_dir/$modelPrecisionFP32"
        wget "https://github.com/dlstreamer/pipeline-zoo-models/raw/main/storage/efficientnet-b0_INT8/$modelPrecisionFP32INT8/efficientnet-b0.xml" -P "$efficientnet_dir/$modelPrecisionFP32"
        wget "https://github.com/dlstreamer/pipeline-zoo-models/raw/main/storage/efficientnet-b0_INT8/efficientnet-b0.json" -P "$efficientnet_dir"
        wget "https://raw.githubusercontent.com/dlstreamer/dlstreamer/master/samples/labels/imagenet_2012.txt" -P "$efficientnet_dir"
    else
        echo "efficientnet $modelPrecisionFP32INT8 model already exists, skip downloading..."
    fi
}

downloadHorizontalText() {
    horizontalText0002="horizontal-text-detection-0002"
    modelType="text_detection"
    # Use MODELS_BASE_DIR for all downloads
    horizontal_dir="$MODELS_BASE_DIR/$modelType/$horizontalText0002"
    horizontaljsonfilepath="$horizontal_dir/$horizontalText0002.json"

    if [ ! -f $horizontaljsonfilepath ]; then
        mkdir -p "$horizontal_dir/$modelPrecisionFP32"
        getModelFiles $horizontalText0002 $pipelineZooModel$horizontalText0002 $modelPrecisionFP16INT8 "$MODELS_BASE_DIR/$modelType"
        getProcessFile $horizontalText0002 $pipelineZooModel$horizontalText0002 $horizontalText0002 $horizontalText0002 "$MODELS_BASE_DIR/$modelType"
        mv "$MODELS_BASE_DIR/$modelType/$horizontalText0002/$modelPrecisionFP16INT8" "$horizontal_dir/$modelPrecisionFP32"
    else
        echo "horizontalText0002 $modelPrecisionFP16INT8 model already exists, skip downloading..."
    fi
}

downloadTextRecognition() {
    textRec0012Mod="text-recognition-0012-mod"
    textRec0012="text-recognition-0012"
    modelType="text_recognition"
    # Use MODELS_BASE_DIR for all downloads
    textrec_dir="$MODELS_BASE_DIR/$modelType/$textRec0012"
    textrecmod_dir="$MODELS_BASE_DIR/$modelType/$textRec0012Mod"
    textRec0012Modjsonfilepath="$textrec_dir/$textRec0012.json"

    if [ ! -f $textRec0012Modjsonfilepath ]; then
        mkdir -p "$textrec_dir/$modelPrecisionFP32"
        getModelFiles $textRec0012Mod $pipelineZooModel$textRec0012Mod $modelPrecisionFP16INT8 "$MODELS_BASE_DIR/$modelType"
        getProcessFile $textRec0012Mod $pipelineZooModel$textRec0012Mod $textRec0012Mod $textRec0012Mod "$MODELS_BASE_DIR/$modelType"
        # Move only if source exists
        if [ -d "$textrecmod_dir" ]; then
            mv "$textrecmod_dir" "$textrec_dir"
        fi
        if [ -f "$textrec_dir/$modelPrecisionFP16INT8/$textRec0012Mod.xml" ]; then
            mv "$textrec_dir/$modelPrecisionFP16INT8/$textRec0012Mod.xml" "$textrec_dir/$modelPrecisionFP16INT8/$textRec0012.xml"
        fi
        if [ -f "$textrec_dir/$modelPrecisionFP16INT8/$textRec0012Mod.bin" ]; then
            mv "$textrec_dir/$modelPrecisionFP16INT8/$textRec0012Mod.bin" "$textrec_dir/$modelPrecisionFP16INT8/$textRec0012.bin"
        fi
        if [ -d "$textrec_dir/$modelPrecisionFP16INT8" ]; then
            mv "$textrec_dir/$modelPrecisionFP16INT8" "$textrec_dir/$modelPrecisionFP32"
        fi
        if [ -f "$textrec_dir/$textRec0012Mod.json" ]; then
            mv "$textrec_dir/$textRec0012Mod.json" "$textrec_dir/$textRec0012.json"
        fi
    else
        echo "textRec0012 $modelPrecisionFP16INT8 model already exists, skip downloading..."
    fi
}

### Run custom downloader section below:
downloadModel "$MODEL_NAME" "$MODEL_TYPE"
downloadEfficientnetb0
downloadHorizontalText
downloadTextRecognition