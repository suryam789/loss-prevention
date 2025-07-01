import os
import json
from pathlib import Path
import copy

CONFIG_CAMERA_TO_WORKLOAD = "/home/pipeline-server/configs/camera_to_workload.json"
CONFIG_WORKLOAD_TO_PIPELINE = "/home/pipeline-server/configs/workload_to_pipeline.json"

ASSETS_DIR = "/home/pipeline-server/assets"
VIDEOS_DIR = os.path.join(ASSETS_DIR, "videos")
MODELSERVER_DIR = "/home/pipeline-server"
MODELSERVER_MODELS_DIR = "/home/pipeline-server/models"
MODELSERVER_VIDEOS_DIR = "/home/pipeline-server/sample-media"


def download_video_if_missing(video_name):
    video_path = os.path.join(MODELSERVER_VIDEOS_DIR, video_name)
    return video_path

def download_model_if_missing(model_name, model_type=None, precision=None):
    if model_type == "gvadetect" and precision:
        precision_lower = precision.lower()
        return f"{MODELSERVER_MODELS_DIR}/object_detection/{model_name}/{precision}/{model_name}.xml"
    elif model_type == "gvaclassify" and precision:
        return f"{MODELSERVER_MODELS_DIR}/object_classification/{model_name}/{precision}/{model_name}.xml"
    elif model_type == "gvadetect":
        return f"{MODELSERVER_MODELS_DIR}/object_detection/{model_name}/{precision}/{model_name}.xml"
    elif model_type == "gvaclassify":
        return f"{MODELSERVER_MODELS_DIR}/object_classification/{model_name}/{precision}/{model_name}.xml"
    else:
        # fallback
        return os.path.join(MODELSERVER_MODELS_DIR, model_name)

def load_json(path):
    with open(path, "r") as f:
        return json.load(f)

def pipeline_cfg_signature(cfg):
    # Remove fields that don't affect pipeline structure (like device, ROI order doesn't matter)
    sig = copy.deepcopy(cfg)
    sig.pop('device', None)
    sig.pop('region_of_interest', None)
    return json.dumps(sig, sort_keys=True)

def build_gst_element(cfg):
    model = cfg["model"]
    device = cfg["device"]
    precision = cfg.get("precision", "")
    if cfg["type"] == "gvadetect":
        model_path = download_model_if_missing(model, "gvadetect", precision)
        elem = f"gvadetect model={model_path} device={device}"
    elif cfg["type"] == "gvaclassify":
        model_path = download_model_if_missing(model, "gvaclassify", precision)
        elem = f"gvaclassify model={model_path} device={device}"
    else:
        model_path = download_model_if_missing(model)
        elem = f"{cfg['type']} model={model_path} device={device}"
    return elem

def build_dynamic_gstlaunch_command(camera, workloads, workload_map, branch_idx=0):
    # Always use fileSrc for video file
    file_src = camera["fileSrc"]
    video_name = file_src.split("|")[0].strip()
    video_file = download_video_if_missing(video_name)
    # Use width/fps from camera config if present, else default
    width = camera.get("width", 1920)
    fps = camera.get("fps", 15)
    pipeline = f"filesrc location={video_file} ! decodebin ! videoconvert"
    # Gather all pipeline configs for this camera's workloads (flatten all steps for all workloads)
    all_steps = []
    for w in workloads:
        if w in workload_map:
            all_steps.extend(workload_map[w])
    # Remove consecutive duplicate steps (by signature)
    unique_steps = []
    last_sig = None
    for step in all_steps:
        sig = pipeline_cfg_signature(step)
        if sig != last_sig:
            unique_steps.append(step)
        last_sig = sig
    # Collect all unique ROIs from unique_steps
    rois = []
    seen_rois = set()
    for step in unique_steps:
        roi = step.get("region_of_interest")
        if roi:
            roi_tuple = (roi.get('x', 0), roi.get('y', 0), roi.get('width', 1), roi.get('height', 1))
            if roi_tuple not in seen_rois:
                seen_rois.add(roi_tuple)
                rois.append(roi)
    # Build gvaattachroi element if any unique ROIs exist
    if rois:
        roi_strs = [f"roi={r['x']},{r['y']},{r['width']},{r['height']}" for r in rois]
        gvaattachroi_elem = "gvaattachroi " + " ".join(roi_strs)
        pipeline += f" ! {gvaattachroi_elem}"
    # Find index of first inference element
    inference_types = {"gvadetect", "gvaclassify"}
    first_infer_idx = next((i for i, step in enumerate(unique_steps) if step["type"] in inference_types), 0)
    infer_count = 0
    # Build pipeline, inserting gvaattachroi before first inference if not already added
    for i, step in enumerate(unique_steps):
        # If no ROIs and this is the first inference, insert gvaattachroi here (for completeness)
        if not rois and i == first_infer_idx:
            pipeline += " ! gvaattachroi"
        # Assign unique model-instance-id for each inference element
        if step["type"] in inference_types:
            model_instance_id = f"id{branch_idx*10+infer_count}"
            infer_count += 1
            elem = build_gst_element(step)
            elem = elem.replace(step["type"], f"{step['type']} model-instance-id={model_instance_id}")
            pipeline += f" ! {elem}"
        else:
            pipeline += f" ! {build_gst_element(step)}"
        if i < len(unique_steps) - 1:
            pipeline += " ! queue"
    # Add gvametaconvert, gvametapublish, and fakesink with unique output file
    pipeline += f" ! gvametaconvert ! gvametapublish method=file file-path=/tmp/out{branch_idx+1}.jsonl ! fakesink"
    return pipeline

def format_pipeline_multiline(pipeline):
    # Split pipeline into elements
    elems = [e.strip() for e in pipeline.split('!') if e.strip()]
    formatted = []
    for idx, elem in enumerate(elems):
        is_first = idx == 0
        indent = '' if is_first else '  '
        if idx < len(elems) - 1:
            line = f"{indent}{elem} ! \\"
        else:
            line = f"{indent}{elem}"
        formatted.append(line)
    return '\n'.join(formatted)

def format_pipeline_branch(pipeline):
    # Remove any trailing ! or whitespace
    pipeline = pipeline.strip()
    if pipeline.endswith('!'):
        pipeline = pipeline[:-1].strip()
    # Wrap in parentheses for GStreamer parallel branches
    return f'({pipeline})'

def main():
    camera_config = load_json(CONFIG_CAMERA_TO_WORKLOAD)
    workload_map = load_json(CONFIG_WORKLOAD_TO_PIPELINE)["workload_pipeline_map"]
    pipelines = []
    for idx, cam in enumerate(camera_config["lane_config"]["cameras"]):
        workloads = [w.lower() for w in cam["workloads"]]
        norm_workload_map = {k.lower(): v for k, v in workload_map.items()}
        pipeline = build_dynamic_gstlaunch_command(cam, workloads, norm_workload_map, branch_idx=idx)
        pipelines.append(pipeline.strip())
    # Output a single gst-launch command with all branches concatenated (no parentheses)
    print("gst-launch-1.0 -e \\")
    for idx, p in enumerate(pipelines):
        end = " \\" if idx < len(pipelines) - 1 else ""
        print(f"  {p}{end}")
    print()

if __name__ == "__main__":
    main()
