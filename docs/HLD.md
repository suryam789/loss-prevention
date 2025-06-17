# High-Level Design (HLD): Loss Prevention Proxy Pipeline System

## 1. System Overview
The Loss Prevention Proxy Pipeline System is designed to optimize and manage the execution of loss prevention workloads in automated self-checkout environments. It provides a flexible, extensible, and efficient architecture for mapping cameras to workloads, consolidating pipelines, and benchmarking resource usage.

## 2. Major Components
- **Asset Preparation Service**: Downloads and prepares required models and video files (see `downloads/`).
- **Pipeline Execution Service**: Launches and manages GStreamer pipelines for each camera/workload, consolidates pipelines, and runs benchmarking tools (see `src/`).
- **Configuration Management**: Handles user-provided JSON files for camera-to-workload and workload-to-pipeline mappings (see `configs/`).
- **Benchmarking Integration**: Collects and logs performance metrics for each pipeline.
- **Dockerization**: Uses `docker/` for containerization and `docker-compose.yml` for orchestration.

## 3. Data Flow Diagram
```
User Configs (configs/) ──▶ Asset Preparation (downloads/) ──▶ Pipeline Execution (src/) ──▶ Benchmarking ──▶ Output Artifacts
```

## 4. Deployment Architecture
- Two Docker containers:
  - `asset-prep`: Handles asset downloads (see `docker/Dockerfile.downloader`).
  - `pipeline-exec`: Runs pipelines and benchmarking (see `docker/Dockerfile.pipelines`).
- Benchmarking repo as a Git submodule.

## 5. Extensibility
- Modular, config-driven design for easy addition of new workloads, camera types, and benchmarking tools.
- Documentation and design details in `docs/`.

---

For diagrams or further breakdowns, see system_design.md and LLD.md.
