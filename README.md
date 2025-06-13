# Loss Prevention Proxy Pipeline System

## Overview

This project provides a proxy pipeline system for loss prevention workloads in self-checkout systems, supporting camera-to-workload mapping, pipeline consolidation, and benchmarking.

## Folder Structure

- `configs/`: User configuration files
- `pipelines/`: Shell scripts for each workload
- `benchmarking/`: Benchmarking scripts (as submodule)
- `scripts/`: Pipeline launcher and utilities
- `docs/`: HLD and LLD documents

## Setup

1. Clone the repository and initialize submodules:
   ```
   git clone <repo-url>
   cd loss-prevention
   git submodule update --init --recursive
   ```
2. Edit configuration files in `configs/`.
3. Add or customize pipeline shell scripts in `pipelines/`.

## Usage

Run the pipeline launcher script:
```
make run INPUT_JSON=./configs/camera_to_workload.json
```

## Extending

- Add new workloads by creating new shell scripts and updating configs.
- Integrate new benchmarking scripts via the submodule.

