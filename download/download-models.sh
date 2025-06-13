#!/bin/bash


# Constants
modelPrecisionFP16INT8="FP16-INT8"
modelPrecisionFP32INT8="FP32-INT8"
modelPrecisionFP32="FP32"
pipelineZooModel="https://github.com/dlstreamer/pipeline-zoo-models/raw/main/storage"

# Default input args
MODEL_NAME=${1:-yolo11s}
MODEL_TYPE=${2:-yolo_v11}
REFRESH_MODE=0

# Parse arguments
for arg in "$@"; do
    if [[ "$arg" == "--refresh" ]]; then
        echo "[INFO] Refresh mode enabled"
        REFRESH_MODE=1
    fi
done

# Environment setup
MODEL_EXEC_PATH="$(dirname "$(readlink -f "$0")")"
MODEL_DIR="$MODEL_EXEC_PATH/../models"
mkdir -p "$MODEL_DIR" && cd "$MODEL_DIR" || { echo "Error: Failed to cd to $MODEL_DIR"; exit 1; }

if [ "$REFRESH_MODE" -eq 1 ]; then
    echo "[INFO] Cleaning existing models..."
    (cd "$MODEL_EXEC_PATH/.." && make clean-models)
fi

# ---- Functions ----

downloadModel() {
    echo "[INFO] Checking if YOLO model already exists: $MODEL_NAME"
    local output_dir="object_detection/$MODEL_NAME"
    local bin_path="$output_dir/FP16/${MODEL_NAME}.bin"
     
    if [ -f "$bin_path" ]; then
        echo "[INFO] Model $MODEL_NAME already exists at $bin_path. Skipping download and setup."
        return 1
    fi

    # Set up virtual environment and install dependencies only if model is not found
    VENV_DIR="$HOME/.virtualenvs/dlstreamer"
    if [ ! -d "$VENV_DIR" ]; then
        echo "[INFO] Creating virtual environment at $VENV_DIR"
        python3 -m venv "$VENV_DIR" || { echo "Error: venv creation failed"; exit 1; }
    fi

    echo "[INFO] Activating virtual environment..."
    source "$VENV_DIR/bin/activate"

    echo "[INFO] Installing required Python packages..."
    pip install --upgrade pip
    pip install openvino==2024.6.0 openvino-dev ultralytics || {
        echo "Error: pip install failed"
        exit 1
    }

    echo "[INFO] Downloading YOLO model: $MODEL_NAME ($MODEL_TYPE)"
    mkdir -p "$output_dir"
    python3 ../download_models/download_convert_model.py "$MODEL_NAME" "$MODEL_TYPE" --output_dir "$output_dir" || {
        echo "[ERROR] Failed to download and convert YOLO model"
        exit 1
    }

    echo "[INFO] YOLO model $MODEL_NAME downloaded successfully."
    return 0
}


getModelFiles() {
    local name="$1" url="$2" precision="$3" folder="$4"
    wget "$url/$precision/${name}.bin" -P "$folder/$name/$precision/"
    wget "$url/$precision/${name}.xml" -P "$folder/$name/$precision/"
}

getProcessFile() {
    local name="$1" url="$2" json="$3" target="$4" folder="$5"
    wget "$url/${json}.json" -O "$folder/$name/${target}.json"
}

downloadEfficientnetb0() {
    local name="efficientnet-b0"
    local folder="object_classification"
    local json_file="$folder/$name/$name.json"

    if [ ! -f "$json_file" ]; then
        echo "[INFO] Downloading EfficientNet $modelPrecisionFP32INT8..."
        local base_url="$pipelineZooModel/${name}_INT8/$modelPrecisionFP32INT8"
        wget "$base_url/${name}.bin" -P "$folder/$name/$modelPrecisionFP32"
        wget "$base_url/${name}.xml" -P "$folder/$name/$modelPrecisionFP32"
        wget "$pipelineZooModel/${name}_INT8/${name}.json" -P "$folder/$name"
        wget "https://raw.githubusercontent.com/dlstreamer/dlstreamer/master/samples/labels/imagenet_2012.txt" -P "$folder/$name"
    else
        echo "[INFO] EfficientNet already exists. Skipping..."
    fi
}

downloadHorizontalText() {
    local name="horizontal-text-detection-0002"
    local folder="text_detection"
    local json_file="$folder/$name/$name.json"

    if [ ! -f "$json_file" ]; then
        getModelFiles "$name" "$pipelineZooModel/$name" "$modelPrecisionFP16INT8" "$folder"
        getProcessFile "$name" "$pipelineZooModel/$name" "$name" "$name" "$folder"
        mv "$folder/$name/$modelPrecisionFP16INT8" "$folder/$name/$modelPrecisionFP32"
    else
        echo "[INFO] Horizontal text model already exists. Skipping..."
    fi
}

downloadTextRecognition() {
    local name="text-recognition-0012"
    local mod="text-recognition-0012-mod"
    local folder="text_recognition"
    local json_file="$folder/$name/$name.json"

    if [ ! -f "$json_file" ]; then
        getModelFiles "$mod" "$pipelineZooModel/$mod" "$modelPrecisionFP16INT8" "$folder"
        getProcessFile "$mod" "$pipelineZooModel/$mod" "$mod" "$mod" "$folder"
        mv "$folder/$mod" "$folder/$name"
        mv "$folder/$name/$modelPrecisionFP16INT8/${mod}.xml" "$folder/$name/$modelPrecisionFP16INT8/${name}.xml"
        mv "$folder/$name/$modelPrecisionFP16INT8/${mod}.bin" "$folder/$name/$modelPrecisionFP16INT8/${name}.bin"
        mv "$folder/$name/$modelPrecisionFP16INT8" "$folder/$name/$modelPrecisionFP32"
        mv "$folder/$name/${mod}.json" "$folder/$name/${name}.json"
    else
        echo "[INFO] Text recognition model already exists. Skipping..."
    fi
}

# ---- Run ----

downloadModel
downloadEfficientnetb0
downloadHorizontalText
downloadTextRecognition
