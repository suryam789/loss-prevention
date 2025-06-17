# Low-Level Design (LLD): Loss Prevention Proxy Pipeline System

## 1. Asset Preparation Service
- **Input**: List of required models and videos (from `configs/`).
- **Logic**:
  - Check if each asset exists locally in the appropriate directory.
  - If missing, download from predefined sources using scripts in `downloads/`.
  - Validate integrity and store in designated directories.
- **Output**: Ready-to-use assets for pipeline execution.

## 2. Configuration Management
- **Files**:
  - `configs/camera_to_workload.json`: Maps cameras to workloads.
  - `configs/workload_to_pipeline.json`: Maps workloads to pipeline scripts and parameters.
- **Logic**:
  - Parse and validate JSON files.
  - Provide APIs/utilities for other services to query mappings.

## 3. Pipeline Execution Service
- **Input**: Config files, prepared assets.
- **Logic**:
  - For each camera, determine unique set of required pipelines (by script path).
  - Consolidate workloads using the same pipeline.
  - Construct and launch GStreamer pipelines (shell scripts in `src/`) per camera.
  - For each launched pipeline, start a benchmarking process in parallel.
- **Output**: Execution plan, pipeline logs, benchmark logs.

## 4. Benchmarking Integration
- **Input**: Running pipeline process.
- **Logic**:
  - Launch benchmarking scripts as subprocesses.
  - Collect metrics: latency, CPU/GPU/memory/bandwidth.
  - Parse and log metrics per camera/workload.
- **Output**: Structured logs and summary reports.

## 5. Output Artifacts
- **Execution Plan**: JSON summary of pipelines per camera.
- **Consolidated Summary**: Total unique pipelines running.
- **Benchmark Logs**: Metrics per camera/workload.
- **Resource Estimation**: (Optional) Lanes supported on current hardware.

## 6. Error Handling & Logging
- Log all errors and warnings with context.
- Validate all user inputs and asset downloads.
- Provide clear error messages for missing/invalid configs or assets.

---

For sequence diagrams, class diagrams, or further breakdowns, see system_design.md and HLD.md.
