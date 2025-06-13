# Usage:
# make run INPUT_JSON=./configs/camera_to_workload.json

INPUT_JSON ?= ./configs/camera_to_workload.json
WORKLOAD_CONFIG ?= ./configs/workload_to_pipeline.json

.PHONY: run


download-models:
	@echo "Downloading sample videos..."
	./download/download_models.sh

download-samples:
	@echo "Downloading sample videos..."
	./download/download_samples.sh

run:
	@echo "Launching DLStreamer pipelines using input: $(INPUT_JSON)"
	python3 scripts/launch_pipelines.py --camera-config $(INPUT_JSON) --workload-config $(WORKLOAD_CONFIG)
