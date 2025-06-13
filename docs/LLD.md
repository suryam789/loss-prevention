# Low-Level Design (LLD): Loss Prevention Proxy Pipeline System

## 1. Modules

### a. Config Parser
- Reads `camera_to_workload.json` and `workload_to_pipeline.json`.
- Validates schema and required fields.

### b. Pipeline Consolidator
- For each camera, maps workloads to unique shell scripts.
- Consolidates workloads using the same script.

### c. Pipeline Launcher
- Launches shell scripts as subprocesses.
- Handles process monitoring and logging.

### d. Benchmarking Integration
- Invokes benchmarking scripts as subprocesses.
- Associates metrics with camera/workload.

### e. Reporting Module
- Generates execution plan (pipelines per camera).
- Summarizes total unique pipelines.
- Optionally estimates resource usage.

## 2. Data Structures

- **CameraConfig:** camera_id, workloads[]
- **WorkloadDefinition:** workload_name, script_path, type
- **ExecutionPlan:** camera_id, [script_paths]

## 3. Interfaces

- `parse_config(file_path) -> dict`
- `consolidate_pipelines(camera_config, workload_defs) -> execution_plan`
- `launch_pipeline(script_path, camera_id)`
- `run_benchmark(camera_id, workload_name)`

## 4. Error Handling

- Invalid config: log and exit.
- Script failure: log error, continue with others.

## 5. Extensibility

- Add new workload types by adding new shell scripts and updating config.
- Plug-in benchmarking scripts via submodule.
- Support for multiple camera types and user-supplied scripts.

