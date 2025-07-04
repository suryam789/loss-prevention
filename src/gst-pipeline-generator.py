import os
import json
from pathlib import Path
import copy
from datetime import datetime

CONFIG_CAMERA_TO_WORKLOAD = "/home/pipeline-server/configs/camera_to_workload.json"
CONFIG_WORKLOAD_TO_PIPELINE = "/home/pipeline-server/configs/workload_to_pipeline.json"


MODELSERVER_DIR = "/home/pipeline-server"
MODELSERVER_MODELS_DIR = "/home/pipeline-server/models"
MODELSERVER_VIDEOS_DIR = "/home/pipeline-server/sample-media"


def download_video_if_missing(video_name, width=None, fps=None):
    # Use default width and fps if not provided
    width = width if width is not None else 1920
    fps = fps if fps is not None else 15
    # Remove .mp4 extension if present for base name
    base_name = video_name[:-4] if video_name.endswith('.mp4') else video_name
    # Compose the expected file name
    file_name = f"{base_name}-{width}-{fps}-bench.mp4"
    video_path = os.path.join(MODELSERVER_VIDEOS_DIR, file_name)
    return video_path

def download_model_if_missing(model_name, model_type=None, precision=None):
    if model_type == "gvadetect" and precision:
        precision_lower = precision.lower()
        return f"{MODELSERVER_MODELS_DIR}/object_detection/{model_name}/{precision}/{model_name}.xml"
    elif model_type == "gvaclassify" and precision and precision == "INT8":
        base_path = f"{MODELSERVER_MODELS_DIR}/object_classification/{model_name}"
        model_path = f"{base_path}/{precision}/{model_name}.xml"
        label_path = f"{base_path}/{precision}/{model_name}.txt"
        proc_path = f"{base_path}/{precision}/{model_name}.json"
        return model_path, label_path, proc_path
    elif model_type == "gvadetect":
        return f"{MODELSERVER_MODELS_DIR}/object_detection/{model_name}/{precision}/{model_name}.xml"
    elif model_type == "gvaclassify":
        base_path = f"{MODELSERVER_MODELS_DIR}/object_classification/{model_name}"
        model_path = f"{base_path}/{precision}/{model_name}.xml"       
        return model_path, label_path, proc_path
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
    # Add inference-region=1 if region_of_interest is present in cfg (from workload_to_pipeline.json)
    inference_region = ""
    if cfg["type"] == "gvadetect" and cfg.get("region_of_interest") is not None:
        inference_region = " inference-region=1"
    if cfg["type"] == "gvadetect":
        model_path = download_model_if_missing(model, "gvadetect", precision)
        elem = f"gvadetect{inference_region} model={model_path} device={device}"
    elif cfg["type"] == "gvaclassify":
        model_path, label_path, proc_path = download_model_if_missing(model, "gvaclassify", precision)
        elem = f"gvaclassify model={model_path} device={device} labels={label_path} model-proc={proc_path}"
    else:
        model_path = download_model_if_missing(model)
        elem = f"{cfg['type']} model={model_path} device={device}"
    return elem

def build_dynamic_gstlaunch_command(camera, workloads, workload_map, branch_idx=0, model_instance_map=None, model_instance_counter=None, timestamp=None):
    if model_instance_map is None:
        model_instance_map = {}
    if model_instance_counter is None:
        model_instance_counter = [0]  # Use list for mutability in nested scope
    file_src = camera["fileSrc"]
    video_name = file_src.split("|")[0].strip()
    width = camera.get("width", 1920)
    fps = camera.get("fps", 15)
    video_file = download_video_if_missing(video_name, width, fps)
    # Add videorate and set framerate to 10/1 as in the example
    pipeline = f"filesrc location={video_file} ! decodebin ! videorate ! video/x-raw,framerate=10/1 ! videoconvert"
    all_steps = []
    for w in workloads:
        if w in workload_map:
            all_steps.extend(workload_map[w])
    # Do NOT deduplicate steps: allow all steps from all workloads, even if models are the same
    rois = []
    seen_rois = set()
    for step in all_steps:
        roi = step.get("region_of_interest")
        if roi:
            roi_tuple = (roi.get('x', 0), roi.get('y', 0), roi.get('width', 1), roi.get('height', 1))
            if roi_tuple not in seen_rois:
                seen_rois.add(roi_tuple)
                rois.append(roi)
    if rois:
        roi_strs = [f"roi={r['x']},{r['y']},{r['width']},{r['height']}" for r in rois]
        gvaattachroi_elem = "gvaattachroi " + " ".join(roi_strs)
        pipeline += f" ! {gvaattachroi_elem}"
    inference_types = {"gvadetect", "gvaclassify"}
    # Use unique model-instance-id per step in the stream
    detect_count = 1
    classify_count = 1
    for i, step in enumerate(all_steps):
        if not rois and i == 0 and step["type"] in inference_types:
            pipeline += " ! gvaattachroi"
        if step["type"] == "gvadetect":
            model_instance_id = f"detect{branch_idx+1}_{detect_count}"
            detect_count += 1
            elem = build_gst_element(step)
            elem = elem.replace("gvadetect", f"gvadetect model-instance-id={model_instance_id}")
            pipeline += f" ! {elem} ! queue max-size-buffers=10"
        elif step["type"] == "gvaclassify":
            model_instance_id = f"classify{branch_idx+1}_{classify_count}"
            classify_count += 1
            elem = build_gst_element(step)
            elem = elem.replace("gvaclassify", f"gvaclassify model-instance-id={model_instance_id}")
            pipeline += f" ! {elem} ! queue max-size-buffers=10"
        else:
            pipeline += f" ! {build_gst_element(step)}"
        if i < len(all_steps) - 1:
            pipeline += " ! queue"
    # Save results to /home/pipeline-server/results in the container (which should be mounted to host results dir)
    tee_name = f"t{branch_idx+1}"
    results_dir = "/home/pipeline-server/results"
    out_file = f"{results_dir}/rs-{branch_idx+1}_{timestamp}.jsonl"
    # GStreamer: no backslash after tee, only after each branch
    pipeline += f" ! gvametaconvert format=json ! tee name={tee_name} "
    pipeline += f"    {tee_name}. ! queue ! gvametapublish method=file file-path={out_file} ! fakesink \\\n"
    pipeline += f"    {tee_name}. ! queue ! gvawatermark ! videoconvert ! fpsdisplaysink video-sink=autovideosink text-overlay=false signal-fps-measurements=true"
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
    # Ensure results directory exists at project root before running pipeline
    results_dir = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "results"))
    os.makedirs(results_dir, exist_ok=True)
    
    # Generate timestamp for all files
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    
    camera_config = load_json(CONFIG_CAMERA_TO_WORKLOAD)
    workload_map = load_json(CONFIG_WORKLOAD_TO_PIPELINE)["workload_pipeline_map"]
    pipelines = []
    model_instance_map = {}
    model_instance_counter = [0]
    for idx, cam in enumerate(camera_config["lane_config"]["cameras"]):
        workloads = [w.lower() for w in cam["workloads"]]
        norm_workload_map = {k.lower(): v for k, v in workload_map.items()}
        pipeline = build_dynamic_gstlaunch_command(cam, workloads, norm_workload_map, branch_idx=idx, model_instance_map=model_instance_map, model_instance_counter=model_instance_counter, timestamp=timestamp)
        pipelines.append(pipeline.strip())
    # Print gst-launch-1.0 -e and all pipelines without extra newline after the command
    print("gst-launch-1.0 -e \\\n", end="")
    for idx, p in enumerate(pipelines):
        end = " \\" if idx < len(pipelines) - 1 else ""
        print(f"  {p}{end}", end="")
        if idx < len(pipelines) - 1:
            print()
    print()

if __name__ == "__main__":
    main()