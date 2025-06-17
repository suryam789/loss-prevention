# System Design: Loss Prevention Proxy Pipeline System

## 1. Architecture Overview

- The system is organized into the following main directories and files:
  - `configs/`: JSON configuration files for camera-to-workload and workload-to-pipeline mapping.
  - `docker/`: Dockerfiles for asset preparation and pipeline execution containers.
  - `docs/`: Documentation (HLD, LLD, system design).
  - `downloads/`: Scripts for downloading models and videos.
  - `src/`: Main source code and pipeline runner scripts.
  - `docker-compose.yml`: Docker Compose configuration for multi-container orchestration.
  - `Makefile`: Build automation.

- The system is composed of two main services, each running in its own Docker container:
  1. **Asset Preparation Service**: Downloads required models and video files.
  2. **Pipeline Execution Service**: Launches and manages GStreamer pipelines for loss prevention workloads, and runs benchmarking tools in parallel.

---

## 2. Key Components

### A. Configuration Management

- **Camera-to-Workload Mapping**: JSON file mapping each camera to its assigned workloads.
- **Workload-to-Pipeline Mapping**: JSON file mapping each workload to its pipeline (shell script and parameters).

### B. Asset Preparation Service

- Checks for the existence of required video and model files.
- Downloads missing assets from predefined sources (e.g., Pexels for videos, model zoo for models).
- Prepares a ready-to-use environment for pipeline execution.

### C. Pipeline Execution Service

- Reads configuration files to determine which pipelines to launch per camera.
- Consolidates workloads per camera to minimize redundant pipeline launches (based on unique script paths).
- Constructs and launches GStreamer pipelines (using DLStreamer shell scripts).
- Integrates benchmarking scripts to collect performance metrics (latency, CPU/GPU/memory/bandwidth).
- Logs and outputs metrics per camera and per workload.

### D. Benchmarking Integration

- Benchmarks run in parallel with each pipeline.
- Metrics are parsed and consolidated for downstream analysis.

### E. Extensibility

- Supports multiple camera types (RTSP, USB, file input).
- Allows user-supplied shell scripts and parameterization.
- Designed for future enhancements (dynamic scheduling, real-time consolidation, new workload types).

---

## 3. Data Flow

1. **User Input**: User provides (or defaults to) configuration files.
2. **Asset Preparation**: Service checks/downloads required assets.
3. **Execution Planning**: System parses configs, consolidates pipelines, and generates an execution plan.
4. **Pipeline Launch**: GStreamer pipelines are launched per camera as per the plan.
5. **Benchmarking**: Benchmarking scripts run in parallel, collecting and logging metrics.
6. **Output Generation**: System outputs execution plan, summary, and resource estimation (optional), along with benchmark logs.

---

## 4. Output Artifacts

- **Execution Plan**: JSON summary of pipelines per camera.
- **Consolidated Summary**: Total unique pipelines running.
- **Benchmark Logs**: Metrics per camera/workload.
- **Resource Estimation**: (Optional) Lanes supported on current hardware.

---

## 5. Deployment

- Two Docker containers:
  - `asset-prep`: Handles model/video downloads.
  - `pipeline-exec`: Runs pipelines and benchmarking.
- Benchmarking repo included as a Git submodule.

---

## 6. Extensibility & Future-Proofing

- Modular design for easy addition of new workloads, camera types, and benchmarking tools.
- Config-driven for user customization.
- Ready for dynamic scheduling and real-time pipeline consolidation in future versions.

---

For detailed diagrams or further breakdowns, see HLD and LLD documents.
