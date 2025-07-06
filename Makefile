# Copyright © 2025 Intel Corporation. All rights reserved.
# SPDX-License-Identifier: Apache-2.0

.PHONY: update-submodules download-models download-samples download-sample-videos build-assets-downloader run-assets-downloader build-pipeline-runner run-loss-prevention clean-images clean-all validate-config validate-camera-config validate-all-configs


# Default values for benchmark
PIPELINE_COUNT ?= 1
RESULTS_DIR ?= ../results


download-sample-videos: | validate-camera-config
	cd performance-tools/benchmark-scripts && ./download_sample_videos.sh


build-model-downloader: | validate-pipeline-config
	@echo "Building assets downloader"
	@docker rmi model-downloader:lp 2>/dev/null || true
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
	@echo "Building pipeline runner"
	@docker rmi pipeline-runner:lp 2>/dev/null || true
	docker build --build-arg HTTPS_PROXY=${HTTPS_PROXY} --build-arg HTTP_PROXY=${HTTP_PROXY} -t pipeline-runner:lp -f docker/Dockerfile.pipeline .
	@echo "pipeline runner build completed"


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
	@if [ -n "$(DEVICE_ENV)" ]; then \
		echo "Loading device environment from $(DEVICE_ENV)"; \
		cd performance-tools/benchmark-scripts && bash -c "set -a; source ../../src/$(DEVICE_ENV); set +a; python3 benchmark.py --compose_file ../../src/docker-compose.yml --pipelines $(PIPELINE_COUNT) --results_dir $(RESULTS_DIR)"; \
	else \
		cd performance-tools/benchmark-scripts && python3 benchmark.py --compose_file ../../src/docker-compose.yml --pipelines $(PIPELINE_COUNT) --results_dir $(RESULTS_DIR); \
	fi


run-lp: | validate-pipeline-config download-sample-videos validate-all-configs
	@echo downloading the models
	$(MAKE) build-model-downloader
	$(MAKE) run-model-downloader
	@echo builing pipeline runner
	$(MAKE) build-pipeline-runner
	@echo Running loss prevention pipeline
	$(MAKE) run-render-mode
	@echo Cleaning up dangling images...
	@docker image prune -f

down-lp:
	docker compose -f src/docker-compose.yml down

clean-images:
	@echo "Cleaning up dangling Docker images..."
	docker image prune -f
	@echo "Dangling images cleaned up"

clean-all:
	@echo "Cleaning up all unused Docker resources..."
	docker system prune -f
	@echo "All unused Docker resources cleaned up"

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



validate-pipeline-config:
	@echo "Validating pipeline configuration..."
	@python3 src/validate_configs.py --validate-pipeline

validate-camera-config:
	@echo "Validating camera configuration..."
	@python3 src/validate_configs.py --validate-camera

validate-all-configs:
	@echo "Validating all configuration files..."
	@python3 src/validate_configs.py --validate-all