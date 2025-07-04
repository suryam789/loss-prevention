# Copyright © 2025 Intel Corporation. All rights reserved.
# SPDX-License-Identifier: Apache-2.0

.PHONY: update-submodules download-models download-samples download-sample-videos build-assets-downloader run-assets-downloader build-pipeline-runner run-loss-prevention

# Asset directories (shared between containers)
ASSETS_DIR ?= /opt/retail-assets
MODELS_DIR := $(ASSETS_DIR)/models
SAMPLES_DIR := $(ASSETS_DIR)/sample-media

download-models:
	ASSETS_DIR=$(ASSETS_DIR) MODELS_DIR=$(MODELS_DIR) ./download-scripts/download_models.sh

download-samples:
	ASSETS_DIR=$(ASSETS_DIR) SAMPLES_DIR=$(SAMPLES_DIR) ./download-scripts/download_videos.sh

download-sample-videos:
	cd performance-tools/benchmark-scripts && ./download_sample_videos.sh

build-model-downloader:
	@echo "Building assets downloader"
	docker build --build-arg HTTPS_PROXY=${HTTPS_PROXY} --build-arg HTTP_PROXY=${HTTP_PROXY} -t model-downloader:lp -f docker/Dockerfile.downloader .
	@echo "assets downloader completed"

run-model-downloader:
	@echo "Running assets downloader"
	docker run --rm \
		-e HTTP_PROXY=${HTTP_PROXY} \
		-e HTTPS_PROXY=${HTTPS_PROXY} \
		-e http_proxy=${HTTP_PROXY} \
		-e https_proxy=${HTTPS_PROXY} \
		-e MODELS_DIR=/workspace/models \
		-e SAMPLES_DIR=/workspace/sample-media \
		-v "$(shell pwd)/models:/workspace/models" \
		model-downloader:lp
	@echo "assets downloader completed"


build-pipeline-runner:
	docker build --build-arg HTTPS_PROXY=${HTTPS_PROXY} --build-arg HTTP_PROXY=${HTTP_PROXY} -t pipeline-runner:lp -f docker/Dockerfile.pipeline .


run-pipeline-runner:
	@echo "Running pipeline runner"
	xhost +local:root
	docker run -it \
		--env DISPLAY=$(DISPLAY) \
		--env XDG_RUNTIME_DIR=$(XDG_RUNTIME_DIR) \
		--volume /tmp/.X11-unix:/tmp/.X11-unix \
		-e HTTP_PROXY=${HTTP_PROXY} \
		-e HTTPS_PROXY=${HTTPS_PROXY} \
		-e http_proxy=${HTTP_PROXY} \
		-e https_proxy=${HTTPS_PROXY} \
		--volume $(PWD)/results:/home/pipeline-server/results \
		pipeline-runner:latest
	xhost -local:root
	@echo "pipeline runner container completed successfully"


update-submodules:
	@echo "Cloning performance tool repositories"
	git submodule deinit -f .
	git submodule update --init --recursive
	git submodule update --remote --merge
	@echo "Submodules updated (if any present)."

build-benchmark:
	cd performance-tools && $(MAKE) build-benchmark-docker

benchmark: build-benchmark
	cd performance-tools/benchmark-scripts && python3 benchmark.py --compose_file ../../src/docker-compose.yml --pipeline $(PIPELINE_COUNT) --results_dir $(RESULTS_DIR)


run-lp: | download-sample-videos
	@echo downloading the models
	$(MAKE) build-model-downloader
	$(MAKE) run-model-downloader
	@echo builing pipeline runner
	$(MAKE) build-pipeline-runner
	@echo Running loss prevention pipeline
	$(MAKE) run-render-mode

down-lp:
	docker compose -f src/docker-compose.yml down

run-render-mode:
	@if [ -z "$(DISPLAY)" ] || ! echo "$(DISPLAY)" | grep -qE "^:[0-9]+(\.[0-9]+)?$$"; then \
		echo "ERROR: Invalid or missing DISPLAY environment variable."; \
		echo "Please set DISPLAY in the format ':<number>' (e.g., ':0')."; \
		echo "Usage: make <target> DISPLAY=:<number>"; \
		echo "Example: make $@ DISPLAY=:0"; \
		exit 1; \
	fi
	@echo "Using DISPLAY=$(DISPLAY)"
	@xhost +local:docker
	@RENDER_MODE=1 docker compose -f src/docker-compose.yml up -d
