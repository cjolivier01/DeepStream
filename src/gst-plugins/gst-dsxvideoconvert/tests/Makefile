# SPDX-FileCopyrightText: Copyright (c) 2026 NVIDIA CORPORATION & AFFILIATES. All rights reserved.
# SPDX-License-Identifier: Apache-2.0

PLUGIN_DIR ?= ../.build
NVDS_VERSION ?= 9.1
CUDA_VER ?= 13.2
DS_ROOT ?= /opt/nvidia/deepstream/deepstream-$(NVDS_VERSION)
CUDA_ROOT ?= /usr/local/cuda-$(CUDA_VER)
ROOT_DIR := $(abspath ../../../..)
PKGS := gstreamer-1.0 gstreamer-app-1.0 gstreamer-video-1.0
PLATFORM_CPPFLAGS :=
ifneq ($(strip $(AARCH64_IS_SBSA)),)
PLATFORM_CPPFLAGS += -DAARCH64_IS_SBSA
endif
METADATA_PROBE := .build/metadata_probe
BATCH_PROBE := .build/batch_probe
STRIDE_PROBE := .build/stride_probe
POOL_PROBE := .build/pool_probe

export GST_PLUGIN_PATH := $(abspath $(PLUGIN_DIR)):$(DS_ROOT)/lib/gst-plugins
export LD_LIBRARY_PATH := $(DS_ROOT)/lib:$(CUDA_ROOT)/lib64:$(LD_LIBRARY_PATH)
export DSX_PLUGIN_SO := $(abspath $(PLUGIN_DIR))/libgstdsxvideoconvert.so
export NVVIDEO_PLUGIN_SO := $(DS_ROOT)/lib/gst-plugins/libgstnvvideoconvert.so

.PHONY: check contract runtime metadata batch stride malformed controls clean

check: contract runtime metadata batch stride malformed controls

contract:
	python3 test_contract.py

runtime:
	python3 test_runtime.py

malformed:
	python3 test_malformed.py

controls: $(BATCH_PROBE) $(POOL_PROBE)
	@set -e; for option in contiguous block-linear compute-gpu copy-gpu; do \
		timeout 15s ./$(BATCH_PROBE) nvvideoconvert nvmm $$option \
			> .build/original-control-$$option.txt; \
		timeout 15s ./$(BATCH_PROBE) dsxvideoconvert nvmm $$option \
			> .build/replacement-control-$$option.txt; \
		diff -u .build/original-control-$$option.txt \
			.build/replacement-control-$$option.txt; \
	done
	rg '^batch=2,filled=2,.*contiguous=1$$' \
		.build/replacement-control-contiguous.txt
	timeout 15s ./$(POOL_PROBE) nvvideoconvert \
		> .build/original-pool.txt
	timeout 15s ./$(POOL_PROBE) dsxvideoconvert \
		> .build/replacement-pool.txt
	diff -u .build/original-pool.txt .build/replacement-pool.txt
	@echo "PASS: allocation and hardware-control behavior"

metadata: $(METADATA_PROBE)
	@set -e; for method in 0 1 2 3 4 5 6 7; do \
		timeout 15s ./$(METADATA_PROBE) nvvideoconvert $$method \
			> .build/original-metadata-$$method.txt; \
		timeout 15s ./$(METADATA_PROBE) dsxvideoconvert $$method \
			> .build/replacement-metadata-$$method.txt; \
		diff -u .build/original-metadata-$$method.txt \
			.build/replacement-metadata-$$method.txt; \
	done
	@echo "PASS: DeepStream metadata propagation and geometry parity"

batch: $(BATCH_PROBE)
	timeout 15s ./$(BATCH_PROBE) nvvideoconvert nvmm \
		> .build/original-batch-nvmm.txt
	timeout 15s ./$(BATCH_PROBE) dsxvideoconvert nvmm \
		> .build/replacement-batch-nvmm.txt
	diff -u .build/original-batch-nvmm.txt \
		.build/replacement-batch-nvmm.txt
	timeout 15s ./$(BATCH_PROBE) nvvideoconvert raw \
		> .build/original-batch-raw.txt
	rg -x 'raw-batch-error' .build/original-batch-raw.txt
	timeout 15s ./$(BATCH_PROBE) dsxvideoconvert raw \
		> .build/replacement-batch-raw.txt
	timeout 15s ./$(BATCH_PROBE) dsxvideoconvert raw caps-only \
		> .build/replacement-batch-caps-only.txt
	diff -u .build/replacement-batch-raw.txt \
		.build/replacement-batch-caps-only.txt
	sed -n 's/.*checksum=//p' .build/original-batch-nvmm.txt \
		> .build/original-batch-checksums.txt
	sed -n 's/.*checksum=//p' .build/replacement-batch-raw.txt \
		> .build/replacement-raw-checksums.txt
	diff -u .build/original-batch-checksums.txt \
		.build/replacement-raw-checksums.txt
	@echo "PASS: two-frame NVMM and RAW batch coverage"

stride: $(STRIDE_PROBE)
	timeout 15s ./$(STRIDE_PROBE) nvvideoconvert compact \
		> .build/original-stride-compact.txt
	timeout 15s ./$(STRIDE_PROBE) dsxvideoconvert compact \
		> .build/replacement-stride-compact.txt
	timeout 15s ./$(STRIDE_PROBE) dsxvideoconvert padded \
		> .build/replacement-stride-padded.txt
	timeout 15s ./$(STRIDE_PROBE) dsxvideoconvert custom \
		> .build/replacement-stride-custom.txt
	diff -u .build/original-stride-compact.txt \
		.build/replacement-stride-compact.txt
	diff -u .build/original-stride-compact.txt \
		.build/replacement-stride-padded.txt
	diff -u .build/original-stride-compact.txt \
		.build/replacement-stride-custom.txt
	timeout 15s ./$(STRIDE_PROBE) dsxvideoconvert undersized-positive \
		> .build/replacement-stride-undersized-positive.txt
	rg -x rejected .build/replacement-stride-undersized-positive.txt
	timeout 15s ./$(STRIDE_PROBE) dsxvideoconvert undersized-negative \
		> .build/replacement-stride-undersized-negative.txt
	rg -x rejected .build/replacement-stride-undersized-negative.txt
	@echo "PASS: compact, padded/custom GstVideoMeta, stale-meta filtering, and stride rejection"

$(METADATA_PROBE): test_metadata.cpp | .build
	$(CXX) -std=c++17 -Wall -Wextra -Werror \
		$(PLATFORM_CPPFLAGS) \
		-I$(ROOT_DIR)/includes -I$(CUDA_ROOT)/include \
		$(shell pkg-config --cflags $(PKGS)) \
		-o $@ $< -L$(DS_ROOT)/lib -Wl,-rpath,$(DS_ROOT)/lib \
		$(shell pkg-config --libs $(PKGS)) -lnvdsgst_meta -lnvds_meta

$(BATCH_PROBE): test_batch.cpp | .build
	$(CXX) -std=c++17 -Wall -Wextra -Werror \
		$(PLATFORM_CPPFLAGS) \
		-I$(ROOT_DIR)/includes -I$(CUDA_ROOT)/include \
		$(shell pkg-config --cflags $(PKGS)) \
		-o $@ $< -L$(DS_ROOT)/lib -Wl,-rpath,$(DS_ROOT)/lib \
		-L$(CUDA_ROOT)/lib64 $(shell pkg-config --libs $(PKGS)) \
		-lnvbufsurface -lnvdsgst_helper -lcudart

$(STRIDE_PROBE): test_stride.cpp | .build
	$(CXX) -std=c++17 -Wall -Wextra -Werror \
		$(PLATFORM_CPPFLAGS) \
		$(shell pkg-config --cflags $(PKGS)) -o $@ $< \
		$(shell pkg-config --libs $(PKGS))

$(POOL_PROBE): test_pool.cpp | .build
	$(CXX) -std=c++17 -Wall -Wextra -Werror \
		$(PLATFORM_CPPFLAGS) \
		$(shell pkg-config --cflags $(PKGS)) -o $@ $< \
		$(shell pkg-config --libs $(PKGS))

.build:
	mkdir -p $@

clean:
	rm -rf .build
