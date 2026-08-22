# SPDX-FileCopyrightText: Copyright (c) 2026 NVIDIA CORPORATION & AFFILIATES. All rights reserved.
# SPDX-License-Identifier: Apache-2.0

include ../Rules.mk

CUDA_VER ?=
ifeq ($(strip $(CUDA_VER)),)
  ifneq ($(MAKECMDGOALS),clean)
    $(error "CUDA_VER is not set")
  endif
endif

CXX ?= g++
CUDA_ROOT ?= /usr/local/cuda-$(CUDA_VER)
DS_LIB_DIR ?= /opt/nvidia/deepstream/deepstream-$(NVDS_VERSION)/lib

PKGS := gstreamer-1.0 gstreamer-base-1.0 gstreamer-video-1.0
SRCS := gstdsxvideoconvert.cpp dsxvideoconvert_backend.cpp
OBJS := $(SRCS:%.cpp=$(OBJ_DIR)/%.o)
PLUGIN := $(OBJ_DIR)/libgstdsxvideoconvert.so

CPPFLAGS += -I$(SOURCE_DIR)/includes -I$(CUDA_ROOT)/include \
	$(shell pkg-config --cflags $(PKGS))
ifneq ($(strip $(AARCH64_IS_SBSA)),)
CPPFLAGS += -DAARCH64_IS_SBSA
endif
CXXFLAGS += -fPIC -fvisibility=hidden -std=c++17 -Wall -Wextra -Werror \
	-DDS_VERSION=\"$(NVDS_VERSION).0\"
LDFLAGS += -shared -Wl,-no-undefined -Wl,--version-script=exports.map \
	-L$(DS_LIB_DIR) \
	-L$(CUDA_ROOT)/lib64 -Wl,-rpath,$(DS_LIB_DIR) \
	-Wl,-rpath,$(CUDA_ROOT)/lib64
LDLIBS += $(shell pkg-config --libs $(PKGS)) -lnvbufsurface \
	-lnvbufsurftransform -lnvdsbufferpool -lnvdsgst_helper \
	-lnvdsgst_meta -lnvds_meta -lcudart -ldl -lpthread

.PHONY: all install clean check test benchmark

all: $(PLUGIN)

$(OBJ_DIR):
	mkdir -p $@

$(OBJ_DIR)/%.o: %.cpp $(wildcard *.h) Makefile | $(OBJ_DIR)
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) -c -o $@ $<

$(PLUGIN): $(OBJS) exports.map
	$(CXX) $(LDFLAGS) -o $@ $(OBJS) $(LDLIBS)

install: $(PLUGIN)
	install -D -m 0755 $< "$(LIB_DIR)/libgstdsxvideoconvert.so"

check test: $(PLUGIN)
	$(MAKE) -C tests PLUGIN_DIR=$(OBJ_DIR) NVDS_VERSION=$(NVDS_VERSION) \
		CUDA_VER=$(CUDA_VER) AARCH64_IS_SBSA=$(AARCH64_IS_SBSA) check

benchmark: $(PLUGIN)
	$(MAKE) -C benchmarks PLUGIN_DIR=$(OBJ_DIR) NVDS_VERSION=$(NVDS_VERSION) \
		CUDA_VER=$(CUDA_VER) AARCH64_IS_SBSA=$(AARCH64_IS_SBSA) benchmark

clean:
	$(MAKE) -C tests clean
	$(MAKE) -C benchmarks clean
	rm -rf $(OBJ_DIR)
