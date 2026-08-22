# SPDX-FileCopyrightText: Copyright (c) 2026 NVIDIA CORPORATION & AFFILIATES. All rights reserved.
# SPDX-License-Identifier: Apache-2.0

PLUGIN_DIR ?= ../.build
NVDS_VERSION ?= 9.1
CUDA_VER ?= 13.2
DS_ROOT ?= /opt/nvidia/deepstream/deepstream-$(NVDS_VERSION)
CUDA_ROOT ?= /usr/local/cuda-$(CUDA_VER)
ROOT_DIR := $(abspath ../../../..)
PKGS := gstreamer-1.0 gstreamer-app-1.0
PLATFORM_CPPFLAGS :=
ifneq ($(strip $(AARCH64_IS_SBSA)),)
PLATFORM_CPPFLAGS += -DAARCH64_IS_SBSA
endif
BATCH_BENCH := .build/benchmark_batch
MAX_SLOWDOWN ?= 1.20
FRAMES ?= 600
TRIALS ?= 3

export GST_PLUGIN_PATH := $(abspath $(PLUGIN_DIR)):$(DS_ROOT)/lib/gst-plugins
export LD_LIBRARY_PATH := $(DS_ROOT)/lib:$(CUDA_ROOT)/lib64:$(LD_LIBRARY_PATH)
export NVVIDEO_PLUGIN_SO := $(DS_ROOT)/lib/gst-plugins/libgstnvvideoconvert.so
export DSX_BATCH_BENCH := $(abspath $(BATCH_BENCH))

.PHONY: benchmark clean

benchmark: $(BATCH_BENCH)
	python3 benchmark.py --frames $(FRAMES) --trials $(TRIALS) \
		--max-slowdown $(MAX_SLOWDOWN)

$(BATCH_BENCH): benchmark_batch.cpp
	mkdir -p .build
	$(CXX) -std=c++17 -Wall -Wextra -Werror \
		$(PLATFORM_CPPFLAGS) \
		-I$(ROOT_DIR)/includes -I$(CUDA_ROOT)/include \
		$(shell pkg-config --cflags $(PKGS)) -o $@ $< \
		-L$(DS_ROOT)/lib -Wl,-rpath,$(DS_ROOT)/lib \
		-L$(CUDA_ROOT)/lib64 $(shell pkg-config --libs $(PKGS)) \
		-lnvbufsurface -lnvdsgst_helper -lcudart

clean:
	rm -rf .build
