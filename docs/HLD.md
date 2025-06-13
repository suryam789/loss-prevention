# High-Level Design (HLD): Loss Prevention Proxy Pipeline System

## 1. Objective

Design a proxy pipeline architecture to optimize execution of loss prevention workloads in automated self-checkout systems, ensuring efficient camera-to-workload mapping, pipeline consolidation, and resource benchmarking. The system should allow user customization and future extensibility.

## 2. Workloads and Execution Model

- Supports multiple loss prevention workloads:
  - hidden_item
  - product_switching
  - product_swapping
  - bagging_without_scan
- Each workload is implemented as a DLStreamer pipeline (shell script).
- Pipelines may differ by model, parameters, or logic, even for the same workload type.
- Each workload results in an independently runnable GStreamer pipeline unless two or more workloads can share the exact same pipeline.

## 3. User Configuration Inputs

- **Camera-to-Workload Mapping File:** Specifies which workloads are assigned to each camera.
- **Workload-to-Pipeline Mapping File:** Maps each workload to its shell script path and type. Allows user overrides.

## 4. Pipeline Consolidation Logic

- For each camera, determine the set of unique shell scripts required.
- If multiple workloads use the same script, only one pipeline instance is launched.
- Consolidation is based on script path, not just workload type.

## 5. Benchmarking Integration

- Benchmarking scripts are integrated as a Git submodule.
- When pipelines are launched, benchmarking scripts run in parallel to collect latency, CPU/GPU utilization, memory, and bandwidth metrics.
- Metrics are logged per camera and per workload.

## 6. System Output

- Execution plan: how many pipelines are launched per camera.
- Consolidated summary: total unique pipelines.
- Optional resource estimation: how many lanes can run on available hardware.
- Benchmark logs per camera/workload.

## 7. Extensibility and Future-Proofing

- Support for multiple camera types (RTSP, USB, File input).
- User-supplied shell scripts and parameterization.
- Future: dynamic scheduling, real-time consolidation, support for additional Vision AI workloads.

