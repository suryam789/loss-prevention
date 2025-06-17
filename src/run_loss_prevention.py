import os
import json
from pathlib import Path

CONFIG_CAMERA_TO_WORKLOAD = "configs/camera_to_workload.json"
CONFIG_WORKLOAD_TO_PIPELINE = "configs/workload_to_pipeline.json"
ASSETS_DIR = "assets"
VIDEOS_DIR = os.path.join(ASSETS_DIR, "videos")
MODELSERVER_DIR = "/home/user/pipelineserver"
MODELSERVER_MODELS_DIR = "/home/user/pipelineserver/models"
MODELSERVER_VIDEOS_DIR = "/home/user/pipelineserver/sample_videos"


def download_video_if_missing(video_name):
    video_path = os.path.join(MODELSERVER_VIDEOS_DIR, video_name)
    return video_path

def download_model_if_missing(model_name):
    model_path = os.path.join(MODELSERVER_MODELS_DIR, model_name)
    return model_path

def load_json(path):
    with open(path, "r") as f:
        return json.load(f)

def build_dynamic_gstlaunch_command(camera_id, workloads, workload_map):
    video_file = download_video_if_missing(f"{camera_id}.mp4")
    pipeline = f"filesrc location={video_file} ! decodebin ! videoconvert"
    for workload in workloads:
        pipeline_cfg = workload_map[workload][0]  # Take first pipeline config
        model = pipeline_cfg["model"]
        device = pipeline_cfg["device"]
        model_file = download_model_if_missing(model)
        pipeline += f" ! gvadetect model={model_file} device={device}"
    pipeline += " ! fakesink"
    return pipeline

def main():
    camera_config = load_json(CONFIG_CAMERA_TO_WORKLOAD)
    workload_map = load_json(CONFIG_WORKLOAD_TO_PIPELINE)["workload_pipeline_map"]

    commands = []
    for cam in camera_config["lane_config"]["cameras"]:
        camera_id = cam["camera_id"]
        workloads = cam["workloads"]
        command = build_dynamic_gstlaunch_command(camera_id, workloads, workload_map)
        commands.append(command)

    # Print each gst-launch command, one per line
    for cmd in commands:
        print(cmd)

if __name__ == "__main__":
    main()
