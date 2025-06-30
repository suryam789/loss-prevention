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

build-assets-downloader:
	@echo "Building assets downloader"
	docker build --build-arg HTTPS_PROXY=${HTTPS_PROXY} --build-arg HTTP_PROXY=${HTTP_PROXY} -t assets-downloader:latest -f docker/Dockerfile.downloader .
	@echo "assets downloader completed"

run-assets-downloader:
	docker run --rm \
		-e HTTP_PROXY=${HTTP_PROXY} \
 		-e HTTPS_PROXY=${HTTPS_PROXY} \
 		-e http_proxy=${HTTP_PROXY} \
 		-e https_proxy=${HTTPS_PROXY} \
		-e MODELS_DIR=/workspace/models -v "$(shell pwd)/models:/workspace/models" assets-downloader:latest

# run-assets-downloader:
# 	@echo "Running assets downloader"
# 	docker run \
# 		-e HTTP_PROXY=${HTTP_PROXY} \
# 		-e HTTPS_PROXY=${HTTPS_PROXY} \
# 		-e http_proxy=${HTTP_PROXY} \
# 		-e https_proxy=${HTTPS_PROXY} \
# 		-v $(MODELS_DIR):/models \
# 		-v $(SAMPLES_DIR):/sample-media \
# 		assets-downloader:latest
# 	@echo "assets downloader completed"


build-pipeline-runner:
	docker build --build-arg HTTPS_PROXY=${HTTPS_PROXY} --build-arg HTTP_PROXY=${HTTP_PROXY} -t pipeline-runner:latest -f docker/Dockerfile.pipeline .

update-submodules:
	@echo "Cloning performance tool repositories"
	git submodule deinit -f .
	git submodule update --init --recursive
	git submodule update --remote --merge
	@echo "Submodules updated (if any present)."

run-loss-prevention: | build-assets-downloader build-pipeline-runner update-submodules download-sample-videos
	@echo "Building automated self checkout app"
	$(MAKE) build
	@echo Running automated self checkout pipeline
	$(MAKE) run-render-mode


