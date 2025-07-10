# Loss Prevention Pipeline System

## Overview

The Loss Prevention Pipeline System is an open-source reference implementation for building and deploying video analytics pipelines for retail loss prevention use cases. It leverages Intel® hardware and software, GStreamer, and OpenVINO™ to enable scalable, real-time object detection and classification at the edge.

## 📋 Prerequisites

- Ubuntu 24.04 or newer (Linux recommended)
- [Docker](https://docs.docker.com/engine/install/)
- [Make](https://www.gnu.org/software/make/) (`sudo apt install make`)
- Intel hardware (CPU, iGPU, dGPU, NPU)
- Intel drivers (see [Intel GPU drivers](https://dgpu-docs.intel.com/driver/client/overview.html))
- Sufficient disk space for models, videos, and results

## 🚀 QuickStart

> The first run will download models, videos, and build Docker images. This may take some time.


### 1. Download models and videos

```sh
make download-models
make download-camera-videos
```

### 2. Run loss prevention application

```sh
make run-render-mode
```

> OR , User can directly run single make command that internally called all above command and run the Loss Prevention application.

### 3. Run Loss Prevention pipeline runner

```sh
make run-lp
```

### 4. Stop all containers

```sh
make down-lp
```

### 4. Run benchmarking on CPU/NPU/GPU
```sh
make  DEVICE_ENV=res/all-cpu.env RENDER_MODE=1 benchmark
make  DEVICE_ENV=res/all-npu.env RENDER_MODE=1 benchmark
make  DEVICE_ENV=res/all-gpu.env RENDER_MODE=1 benchmark
```



## 🛠️ Other Useful Make Commands

- `make clean-images` — Remove dangling Docker images
- `make clean-containers` — Remove stopped containers
- `make clean-images` — Remove dangling Docker images
- `make clean-containers` — Remove stopped containers
- `make clean-all` — Remove all unused Docker resources
- `make validate-all-configs` — Validate all configuration files

## ⚙️ Configuration

The application is highly configurable via JSON files in the `configs/` directory:

- **`camera_to_workload.json`**: Maps each camera to one or more workloads. To add or remove a camera, edit the `lane_config.cameras` array in this file. Each camera entry can specify its video source, region of interest, and assigned workloads.
    - Example:
      ```json
      {
        "lane_config": {
          "cameras": [
            {
              "camera_id": "cam1",
              "fileSrc": "sample-media/video1.mp4",
              "region_of_interest": {"x": 100, "y": 100, "width": 800, "height": 600},
              "workloads": ["items_in_basket", "multi_product_identification"]
            },
            ...
          ]
        }
      }
      ```
- **`workload_to_pipeline.json`**: Maps each workload name to a pipeline definition (sequence of GStreamer elements and models). To add or update a workload, edit the `workload_pipeline_map` in this file.
    - Example:
      ```json
      {
        "workload_pipeline_map": {
          "items_in_basket": [
            {"type": "gvadetect", "model": "yolo11n", "precision": "INT8", "device": "CPU"},
            {"type": "gvaclassify", "model": "efficientnet-v2-b0", "precision": "INT8", "device": "CPU"}
          ],
          ...
        }
      }
      ```

**To try a new camera or workload:**
1. Edit `configs/camera_to_workload.json` to add your camera and assign workloads.
2. Edit `configs/workload_to_pipeline.json` to define or update the pipeline for your workload.
3. (Optional) Place your video files in the appropriate directory and update the `fileSrc` path.
4. Re-run the pipeline as described above.

## 📁 Project Structure

- `configs/` — Configuration files (camera/workload mapping, pipeline mapping)
- `docker/` — Dockerfiles for downloader and pipeline containers
- `docs/` — Documentation (HLD, LLD, system design)
- `download-scripts/` — Scripts for downloading models and videos
- `src/` — Main source code and pipeline runner scripts
- `Makefile` — Build automation and workflow commands

---

For advanced usage, benchmarks, and troubleshooting, see the `docs/` directory.

