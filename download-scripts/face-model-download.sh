#!/bin/bash



# Usage: face-model-download.sh <model_name> <output_dir>
MODEL_NAME=${1:-"face-detection-retail-0004"}
# Decide subdir based on model type
if [[ "$MODEL_NAME" == *reidentification* ]]; then
    SUBDIR="object_classification"
else
    SUBDIR="object_detection"
fi
MODELS_PATH=${2:-"models/$SUBDIR"}

if [[ -z "$MODEL_NAME" || -z "$MODELS_PATH" ]]; then
    echo "Usage: $0 <model_name> <output_dir>"
    exit 1
fi

set -e



echo "Creating a directory for models at $MODELS_PATH..."
mkdir -p "$MODELS_PATH"

MODEL_XML_FP16="$MODELS_PATH/$MODEL_NAME/FP16/$MODEL_NAME.xml"
MODEL_XML_FP32="$MODELS_PATH/$MODEL_NAME/FP32/$MODEL_NAME.xml"
if [ -f "$MODEL_XML_FP16" ] && [ -f "$MODEL_XML_FP32" ]; then
    echo "Model $MODEL_NAME already downloaded at $MODEL_XML_FP16 and $MODEL_XML_FP32 ✓"
    # If object_classification, ensure <model_name>.json exists with required content
    if [[ "$SUBDIR" == "object_classification" ]]; then
        JSON_PATH="$MODELS_PATH/$MODEL_NAME/$MODEL_NAME.json"
        if [ ! -f "$JSON_PATH" ]; then
            echo "Creating $JSON_PATH with required content..."
            cat > "$JSON_PATH" <<EOF
{
  "json_schema_version": "2.0.0",
  "layout": "NCHW",
  "input_preproc": [
    {
      "layer_name": "0",
      "resize": "aspect_ratio",
      "convert_to": "RGB",
      "format": "RGB"
    }
  ],
  "output_postproc": [
    {
      "type": "embedding",
      "name": "1790179219426"
    }
  ]
}
EOF
        fi
    fi
    # If object_detection, ensure <model_name>.json exists with required content
    if [[ "$SUBDIR" == "object_detection" ]]; then
        JSON_PATH="$MODELS_PATH/$MODEL_NAME/$MODEL_NAME.json"
        if [ ! -f "$JSON_PATH" ]; then
            echo "Creating $JSON_PATH for object_detection with required content..."
            cat > "$JSON_PATH" <<EOF
{
    "json_schema_version": "2.2.0",
    "input_preproc": [],
    "output_postproc": [
        {
            "converter": "detection_output",
            "labels": [
                "background",
                "face"
            ]
        }
    ]
}
EOF
        fi
    fi
else
    echo "Downloading model $MODEL_NAME using Open Model Zoo downloader..."
    omz_downloader --name "$MODEL_NAME" --output_dir "$MODELS_PATH"
    # OMZ puts models in models/intel/<model_name> or models/public/<model_name>, move to $MODELS_PATH/<model_name>
    if [ -d "$MODELS_PATH/intel/$MODEL_NAME" ]; then
        echo "Moving model from $MODELS_PATH/intel/$MODEL_NAME to $MODELS_PATH/$MODEL_NAME ..."
        mv "$MODELS_PATH/intel/$MODEL_NAME" "$MODELS_PATH/" || true
        rmdir --ignore-fail-on-non-empty "$MODELS_PATH/intel" 2>/dev/null || true
    elif [ -d "$MODELS_PATH/public/$MODEL_NAME" ]; then
        echo "Moving model from $MODELS_PATH/public/$MODEL_NAME to $MODELS_PATH/$MODEL_NAME ..."
        mv "$MODELS_PATH/public/$MODEL_NAME" "$MODELS_PATH/" || true
        rmdir --ignore-fail-on-non-empty "$MODELS_PATH/public" 2>/dev/null || true
    fi
    # If object_classification, ensure <model_name>.json exists with required content
    if [[ "$SUBDIR" == "object_classification" ]]; then
        JSON_PATH="$MODELS_PATH/$MODEL_NAME/$MODEL_NAME.json"
        if [ ! -f "$JSON_PATH" ]; then
            echo "Creating $JSON_PATH with required content..."
            cat > "$JSON_PATH" <<EOF
{
  "json_schema_version": "2.0.0",  
  "layout": "NCHW",
  "input_preproc": [
    {
      "resize": "aspect_ratio",
      "convert_to": "RGB"
    }
  ],
  "output_postproc": [
    {
      "type": "embedding"
    }
  ]
}
EOF
        fi
    fi
    # If object_detection, ensure <model_name>.json exists with required content
    if [[ "$SUBDIR" == "object_detection" ]]; then
        JSON_PATH="$MODELS_PATH/$MODEL_NAME/$MODEL_NAME.json"
        if [ ! -f "$JSON_PATH" ]; then
            echo "Creating $JSON_PATH for object_detection with required content..."
            cat > "$JSON_PATH" <<EOF
{
    "json_schema_version": "2.2.0",
    "input_preproc": [],
    "output_postproc": [
        {
            "converter": "detection_output",
            "labels": [
                "background",
                "face"
            ]
        }
    ]
}
EOF
        fi
    fi
    echo "Listing downloaded model(s)..."
    find "$MODELS_PATH" -name "*.xml" -o -name "*.bin" | sort
    echo "Model download completed successfully! ✓"
fi


