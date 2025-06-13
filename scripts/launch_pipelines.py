import json
import subprocess
import argparse
import os

def parse_config(path):
    with open(path, 'r') as f:
        return json.load(f)

def consolidate_pipelines(camera_config, workload_defs):
    plan = {}
    for cam in camera_config['lane_config']['cameras']:
        cam_id = cam['camera_id']
        workloads = cam['workloads']
        unique_scripts = set()
        for w in workloads:
            script = workload_defs['workload_definitions'][w]['script']
            unique_scripts.add(script)
        plan[cam_id] = list(unique_scripts)
    return plan

def launch_pipeline(script_path, camera_id):
    print(f"Launching {script_path} for camera {camera_id}")
    subprocess.Popen([script_path, camera_id])

def main():
    parser = argparse.ArgumentParser(description="Launch DLStreamer pipelines based on input JSON configs.")
    parser.add_argument('--camera-config', required=True, help='Path to camera-to-workload mapping JSON')
    parser.add_argument('--workload-config', required=True, help='Path to workload-to-pipeline mapping JSON')
    args = parser.parse_args()

    camera_config = parse_config(args.camera_config)
    workload_defs = parse_config(args.workload_config)
    plan = consolidate_pipelines(camera_config, workload_defs)

    print("Execution Plan:")
    for cam_id, scripts in plan.items():
        print(f"Camera {cam_id}:")
        for script in scripts:
            print(f"  - {script}")
            launch_pipeline(script, cam_id)
            # Optionally: launch benchmarking script here

if __name__ == "__main__":
    main()
