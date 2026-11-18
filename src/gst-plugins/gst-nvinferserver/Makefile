# SPDX-FileCopyrightText: Copyright (c) 2026 NVIDIA CORPORATION & AFFILIATES. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

TRITON_GRPC_CLIENT ?= /opt/tritonclient
PROTOBUF_BIN_DIR ?= /opt/proto/bin

LIB := libnvdsgst_inferserver.so
NVDS_VERSION := 9.2

CUDA_VER?=
# Require CUDA_VER for every goal except a clean-only invocation.
# A bare `make` has empty MAKECMDGOALS and still checks.
ifneq ($(filter-out clean,$(MAKECMDGOALS)),)
  _DS_NEED_CUDA_VER := 1
else ifeq ($(MAKECMDGOALS),)
  _DS_NEED_CUDA_VER := 1
endif
ifeq ($(_DS_NEED_CUDA_VER),1)
ifeq ($(CUDA_VER),)
  $(error "CUDA_VER is not set")
endif
endif

CXX := g++

SRCS := \
    gstnvinferserver_meta_utils.cpp \
    gstnvinferserver.cpp \
    gstnvinferserver_impl.cpp \
    $(NULL)

ifeq ($(shell uname -m), aarch64)
SRCS +=   \
     ../../utils/nvdsinferserver/infer_utils.cpp \
     nvdsinferserver_config.pb.cc \
     nvdsinferserver_plugin.pb.cc \
     nvdsinferserver_common.pb.cc
endif


INCS += $(wildcard *.h)

CFLAGS+= \
    -O3 \
    -DNDEBUG \
    -fPIC \
    -std=c++17 \
    -DDS_VERSION=\"9.2.0\" \
    -DFOR_PRIVATE \
    $(NULL)

INC_PATHS := \
    $(TRITON_GRPC_CLIENT)/include \
    /usr/local/cuda-$(CUDA_VER)/include \
    ../../../includes \
    ../../../includes/nvdsinferserver \
    ../../utils/nvdsinferserver \
    ../gst-nvdspreprocess/include \
    . \
    $(NULL)

CFLAGS += $(addprefix -I, $(INC_PATHS))

GST_INSTALL_DIR ?= /opt/nvidia/deepstream/deepstream-$(NVDS_VERSION)/lib/gst-plugins/
LIB_INSTALL_DIR ?= /opt/nvidia/deepstream/deepstream-$(NVDS_VERSION)/lib/

LDFLAGS := \
    -shared \
    -Wl,-no-undefined \
    $(NULL)

LIBS := \
    -L$(TRITON_GRPC_CLIENT)/lib \
    -l:libprotobuf.a \
    -L$(LIB_INSTALL_DIR) \
    -lnvdsgst_helper \
    -lnvdsgst_meta \
    -lnvds_meta \
    -lnvds_infer_server \
    -lnvbufsurface \
    -lnvbufsurftransform \
    -L/usr/local/cuda-$(CUDA_VER)/lib64/ \
    -lcudart \
    -ldl \
    -lpthread \
    -Wl,-rpath,$(LIB_INSTALL_DIR) \
    -lnvdsgst_customhelper \
    $(NULL)

ifeq ($(shell uname -m), aarch64)
# ARM64/Jetson specific libraries
CFLAGS += -DIS_TEGRA
LIBS += -L/usr/lib/aarch64-linux-gnu/nvidia -lcuda
endif

OBJS := $(SRCS:.cpp=.o)
OBJS := $(OBJS:.cc=.o)

PKGS := gstreamer-1.0 gstreamer-base-1.0 gstreamer-video-1.0
CFLAGS += $(shell pkg-config --cflags $(PKGS))
LIBS += $(shell pkg-config --libs $(PKGS))

INFERSERVER_PROTOS := $(wildcard ../../../includes/*.proto)

ALL_PROTOS := $(INFERSERVER_PROTOS)
ALL_PROTOS_PBCC := $(notdir $(ALL_PROTOS:.proto=.pb.cc))
ALL_PROTOS_PBH := $(notdir $(ALL_PROTOS:.proto=.pb.h))

.PRECIOUS:  $(ALL_PROTOS_PBCC)
.PRECIOUS:  $(ALL_PROTOS_PBH)


INCS += \
    $(INFERSERVER_PROTOS) \
    $(NULL)

# The generated protobuf sources are deliberately kept out of INCS. INCS is a
# prerequisite of the %.o pattern rules below, and GNU Make 4.4 no longer lets a
# pattern rule match when one of its prerequisites neither exists nor is built
# by an explicit rule -- these are produced by the %.pb.h %.pb.cc pattern rule
# at the bottom of this file. Make then quietly falls through to its built-in
# %.o: %.cpp recipe, which carries none of the flags set here, and the first
# #include fails with "gst/gst.h: No such file or directory". Make 4.3 and
# earlier accepted the pattern rule, so this only shows up on newer distros
# (Ubuntu 26.04 ships Make 4.4.1), and only on a tree where the generated files
# are absent -- any previous build leaves them behind and hides it.
#
# The ordering they provided still matters, so require them explicitly below --
# after the default goal, since the first target in the file wins that role.


all: $(LIB)

$(OBJS): $(ALL_PROTOS_PBH)

%.o: %.cc $(INCS) Makefile
	$(CXX) -c -o $@ $(CFLAGS) $<

%.o: %.cpp $(INCS) Makefile
	$(CXX) -c -o $@ $(CFLAGS) $<

$(LIB): $(OBJS) $(INCS) $(DEP) Makefile
	$(CXX) -o $@ $(LDFLAGS) $(OBJS) $(LIBS)

install: $(LIB)
	cp -rv $(LIB) $(GST_INSTALL_DIR)

clean:
	rm -rf $(OBJS) $(LIB) $(ALL_PROTOS_PBH)  $(ALL_PROTOS_PBCC)


%.pb.h %.pb.cc: ../../../includes/%.proto $(INFERSERVER_PROTOS) Makefile
	@mkdir -p $(dir $@)
	$(PROTOBUF_BIN_DIR)/protoc --proto_path=../../../includes --cpp_out=. $<
