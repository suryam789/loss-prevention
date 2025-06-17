# Copyright © 2025 Intel Corporation. All rights reserved.
# SPDX-License-Identifier: Apache-2.0

MODEL ?= yolo11n
MODEL_TYPE ?= yolo_v11

download-models:
	./download_models/downloadModels.sh ${MODEL} ${MODEL_TYPE}

download-sample-videos:
	cd performance-tools/benchmark-scripts && ./download_sample_videos.sh

build:
	docker build --build-arg HTTPS_PROXY=${HTTPS_PROXY} --build-arg HTTP_PROXY=${HTTP_PROXY} --target build-default -t dlstreamer:dev -f src/Dockerfile src/

update-submodules:
	@git submodule update --init --recursive
	@git submodule update --remote --merge	

run-loss-prevention: | download-models update-submodules download-sample-videos
	@echo "Building automated self checkout app"
	$(MAKE) build
	@echo Running automated self checkout pipeline
	$(MAKE) run-render-mode
