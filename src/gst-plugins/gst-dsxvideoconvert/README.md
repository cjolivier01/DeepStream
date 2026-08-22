<!--
SPDX-FileCopyrightText: Copyright (c) 2026 NVIDIA CORPORATION & AFFILIATES. All rights reserved.
SPDX-License-Identifier: Apache-2.0
-->

# Gst-dsxvideoconvert

`dsxvideoconvert` is a source-available, differently named GStreamer video
converter for DeepStream. It implements the documented `nvvideoconvert`
GStreamer contract without replacing or shadowing the NVIDIA plugin:

- element: `dsxvideoconvert`
- plugin: `dsxvideoconvert`
- library: `libgstdsxvideoconvert.so`

The implementation is a clean-room `GstBaseTransform` wrapper built from the
public DeepStream headers and documented APIs. It uses
`NvBufSurfTransform` for conversion, scaling, crop, interpolation, and
orientation, and `GstNvDsBufferPool` for NVMM output. It does not contain
copied NVIDIA plugin implementation code.

This is not a source replacement for the low-level conversion runtime. The
plugin still dynamically links to the binary-only `libnvbufsurface.so`,
`libnvbufsurftransform.so`, and DeepStream buffer-pool/metadata libraries.

## Features

- RAW to RAW, RAW to NVMM, NVMM to RAW, and NVMM to NVMM operation
- DeepStream batched `NvBufSurface` buffers
- documented dGPU and Jetson caps, including 10-bit, 12-bit, and 16-bit paths
- source and destination crop, scaling, all flip/rotation modes, and every
  documented interpolation method
- GPU, memory-type, output-pool, contiguous-allocation, and Jetson
  block-linear controls
- DeepStream batch metadata propagation and OSD coordinate scaling
- same documented property names, defaults, ranges, enum values, and mutable
  states as `nvvideoconvert`
- padded and custom-stride RAW buffers described by `GstVideoMeta`
- concatenated RAW output for multi-frame NVMM batches

The plugin deliberately does not export the original library's unnamespaced
helper symbols. Those functions have no public DeepStream header, and defining
them again would make the original and replacement unsafe to load in one
process. The GStreamer-facing API is the compatibility boundary.

## Build and install

From this directory:

```bash
make CUDA_VER=13.2
sudo make CUDA_VER=13.2 install
```

The repository's top-level `build/build.sh` discovers this Makefile and builds
and installs the plugin as part of the normal `gst-plugins` stage.

For an uninstalled build:

```bash
export GST_PLUGIN_PATH="$PWD/.build:/opt/nvidia/deepstream/deepstream-9.1/lib/gst-plugins"
export LD_LIBRARY_PATH="/opt/nvidia/deepstream/deepstream-9.1/lib:/usr/local/cuda-13.2/lib64"
gst-inspect-1.0 dsxvideoconvert
```

Example:

```bash
gst-launch-1.0 videotestsrc num-buffers=30 ! \
  'video/x-raw,format=RGBA,width=1920,height=1080' ! \
  dsxvideoconvert interpolation-method=1 ! \
  'video/x-raw(memory:NVMM),format=NV12,width=1280,height=720' ! fakesink
```

## Validation

The parity suite requires the installed NVIDIA `nvvideoconvert` as a black-box
oracle and runs each candidate in a fresh process:

```bash
make CUDA_VER=13.2 check
```

It checks pad and negotiated caps, properties, the exact namespaced ELF ABI,
dynamic dependencies, RAW and NVMM paths, the documented format set, odd
dimensions in every RAW format, crop backgrounds across YUV formats, flips,
interpolation, metadata orientation, nonzero batched content, custom RAW
plane mappings and strides, signed caps-only batch sizing, output-pool depth,
allocation/layout controls, malformed NVMM descriptors, undersized-stride
rejection, stale layout-meta filtering, and unsupported BGRA64 conversion.
Probe processes have explicit timeouts.

The benchmark suite uses direct RAW and NVMM generators and GStreamer's
per-element latency tracer, so source generation is outside the converter
measurement. A dedicated appsrc harness measures two-surface batched NVMM
conversion and subtracts an identity baseline. The suite balances both run
orders, warms each path, covers RAW-to-RAW, RAW-to-NVMM, NVMM-to-NVMM,
NVMM-to-RAW, crop/flip, and batched workloads, uses median trial results, and
fails if the replacement exceeds the configured slowdown ceiling:

```bash
make CUDA_VER=13.2 benchmark
make CUDA_VER=13.2 benchmark MAX_SLOWDOWN=1.20 FRAMES=600 TRIALS=3
```

Benchmark results are intentionally not checked into the repository.

## References

- [DeepStream Gst-nvvideoconvert documentation](https://docs.nvidia.com/metropolis/deepstream/dev-guide/text/DS_plugin_gst-nvvideoconvert.html)
- [`NvBufSurfTransform` public API](../../../includes/nvbufsurftransform.h)
- [`NvBufSurface` public API](../../../includes/nvbufsurface.h)
