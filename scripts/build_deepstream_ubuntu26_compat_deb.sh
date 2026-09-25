#!/usr/bin/env bash
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

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/build_deepstream_ubuntu26_compat_deb.sh [OPTIONS]

Build a local Ubuntu 26.04-compatible Debian package named deepstream-9.1.

This is a compatibility registration package. It does not copy the full NVIDIA
DeepStream payload into the deb. It expects DeepStream to have already been
installed by this repository's build scripts under /opt/nvidia/deepstream.

Options:
  --output-dir DIR       Directory for the generated deb
                         default: artifacts/local-debs
  --install-root DIR     Existing DeepStream install root
                         default: /opt/nvidia/deepstream/deepstream-9.1
  --version VERSION      Debian package version
                         default: 9.1.0-1+resolute2
  --force                Build even when the host is not Ubuntu 26.04/resolute
  -h, --help             Show this help

Environment overrides:
  NVDS_VERSION=9.1       DeepStream major.minor version
  DEB_VERSION=9.1.0-1+resolute2
  OUT_DIR=...            Same as --output-dir
  INSTALL_ROOT=...       Same as --install-root
EOF
}

NVDS_VERSION=${NVDS_VERSION:-9.1}
PKG_NAME="deepstream-${NVDS_VERSION}"
DEB_VERSION=${DEB_VERSION:-${NVDS_VERSION}.0-1+resolute2}
INSTALL_ROOT=${INSTALL_ROOT:-/opt/nvidia/deepstream/deepstream-${NVDS_VERSION}}
OUT_DIR=${OUT_DIR:-artifacts/local-debs}
FORCE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --output-dir)
      [[ $# -ge 2 ]] || { echo "error: --output-dir requires a value" >&2; exit 2; }
      OUT_DIR=$2
      shift 2
      ;;
    --install-root)
      [[ $# -ge 2 ]] || { echo "error: --install-root requires a value" >&2; exit 2; }
      INSTALL_ROOT=$2
      shift 2
      ;;
    --version)
      [[ $# -ge 2 ]] || { echo "error: --version requires a value" >&2; exit 2; }
      DEB_VERSION=$2
      shift 2
      ;;
    --force)
      FORCE=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "error: unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
OUT_DIR=$(mkdir -p "$OUT_DIR" && cd "$OUT_DIR" && pwd)
ARCH=$(dpkg --print-architecture)

if [[ "$ARCH" != "amd64" ]]; then
  echo "error: this compatibility package is only defined for amd64; found $ARCH" >&2
  exit 1
fi

if [[ -r /etc/os-release ]]; then
  # shellcheck disable=SC1091
  . /etc/os-release
else
  ID=
  VERSION_ID=
  VERSION_CODENAME=
fi

if [[ "$FORCE" -eq 0 ]]; then
  if [[ "${ID:-}" != "ubuntu" || "${VERSION_ID:-}" != "26.04" || "${VERSION_CODENAME:-}" != "resolute" ]]; then
    echo "error: this script is intended for Ubuntu 26.04/resolute." >&2
    echo "       Use --force if you intentionally want to build it here." >&2
    exit 1
  fi
fi

required_paths=(
  "$INSTALL_ROOT/bin/deepstream-app"
  "$INSTALL_ROOT/lib/libnvds_meta.so"
  "$INSTALL_ROOT/lib/gst-plugins/libnvdsgst_infer.so"
  "$INSTALL_ROOT/samples"
)

missing=()
for path in "${required_paths[@]}"; do
  [[ -e "$path" ]] || missing+=("$path")
done

if [[ ${#missing[@]} -gt 0 ]]; then
  echo "error: DeepStream install root is incomplete: $INSTALL_ROOT" >&2
  printf '       missing: %s\n' "${missing[@]}" >&2
  echo "       Run: CMAKE_POLICY_VERSION_MINIMUM=3.5 bash build/build.sh --resume" >&2
  exit 1
fi

command -v dpkg-deb >/dev/null 2>&1 || {
  echo "error: dpkg-deb is required but was not found" >&2
  exit 1
}

BUILD_PARENT="$REPO_ROOT/build"
mkdir -p "$BUILD_PARENT"
PKG_DIR=$(mktemp -d "$BUILD_PARENT/${PKG_NAME}-ubuntu26-compat.XXXXXX")
trap 'rm -rf "$PKG_DIR"' EXIT

mkdir -p "$PKG_DIR/DEBIAN" "$PKG_DIR/usr/share/doc/$PKG_NAME"

cat >"$PKG_DIR/DEBIAN/control" <<EOF
Package: $PKG_NAME
Version: $DEB_VERSION
Architecture: amd64
Maintainer: Local DeepStream Compatibility <root@localhost>
Source: deepstream-ubuntu26-compat
Section: metapackages
Priority: optional
Depends: cuda-cudart-13-0 | cuda-cudart-13-2,
 cuda-cudart-dev-13-0 | cuda-cudart-dev-13-2,
 libnpp-13-0 | libnpp-13-2,
 libnpp-dev-13-0 | libnpp-dev-13-2,
 libcairo2,
 libglib2.0-0,
 libgstreamer1.0-0,
 libgstreamer1.0-dev,
 libgstreamer-plugins-base1.0-0,
 libgstreamer-plugins-base1.0-dev,
 libnvinfer10,
 libnvinfer-dev,
 libnvonnxparsers10,
 libnvonnxparsers-dev,
 libnvinfer-plugin10,
 libnvinfer-plugin-dev,
 libpangocairo-1.0-0,
 libx11-6,
 libyaml-cpp-dev,
 libgbm1,
 mesa-libgallium | libglapi-mesa,
 libgles2-mesa-dev,
 python3
Description: DeepStream SDK 9.1 local compatibility package for Ubuntu 26.04
 This package records that DeepStream 9.1 is installed on Ubuntu 26.04 systems
 where NVIDIA's Ubuntu 24.04 all-in-one deepstream-9.1 deb cannot satisfy its
 versioned libglapi-mesa dependency.
 .
 It does not ship the full NVIDIA DeepStream payload. The runtime tree must
 already exist at $INSTALL_ROOT, normally produced by this repository's
 build/build.sh and scripts/install.sh flow.
EOF

cat >"$PKG_DIR/DEBIAN/postinst" <<EOF
#!/bin/sh
set -e

install_root="$INSTALL_ROOT"

if [ ! -x "\$install_root/bin/deepstream-app" ]; then
  echo "error: \$install_root/bin/deepstream-app is missing or not executable" >&2
  echo "       Build/install DeepStream from the source repository before installing this package." >&2
  exit 1
fi

conf=/etc/ld.so.conf.d/deepstream.conf
{
  echo "\$install_root/lib"
  echo "\$install_root/lib/gst-plugins"
  if [ -d /opt/tritonclient/lib ]; then
    echo /opt/tritonclient/lib
  fi
} > "\$conf"

ldconfig
exit 0
EOF

cat >"$PKG_DIR/DEBIAN/prerm" <<'EOF'
#!/bin/sh
set -e

# This compatibility package intentionally leaves the source-built DeepStream
# tree, update-alternatives entries, and loader config in place. Those belong to
# the repository install/uninstall scripts, not this metadata package.
exit 0
EOF

chmod 0755 "$PKG_DIR/DEBIAN/postinst" "$PKG_DIR/DEBIAN/prerm"

cat >"$PKG_DIR/usr/share/doc/$PKG_NAME/README.ubuntu26-compat" <<EOF
$PKG_NAME $DEB_VERSION Ubuntu 26.04 compatibility package

This package is a local metadata package for systems where DeepStream 9.1 was
installed from the DeepStream source repository build scripts into:

  $INSTALL_ROOT

It exists to satisfy packages that depend on "deepstream-9.1" while avoiding
the Ubuntu 24.04-specific libglapi-mesa dependency in NVIDIA's all-in-one deb.

It does not contain the full NVIDIA DeepStream payload. Do not redistribute it
as a replacement for NVIDIA's official DeepStream SDK package.
EOF

cat >"$PKG_DIR/usr/share/doc/$PKG_NAME/copyright" <<'EOF'
This local compatibility package contains metadata and maintainer scripts only.
It does not include or redistribute NVIDIA DeepStream payload files.

The script that generated this package is licensed under Apache-2.0.
DeepStream itself is subject to NVIDIA's DeepStream SDK license terms.
EOF

find "$PKG_DIR" -type d -exec chmod 0755 {} +

DEB_PATH="$OUT_DIR/${PKG_NAME}_${DEB_VERSION}_${ARCH}.deb"
dpkg-deb --build --root-owner-group "$PKG_DIR" "$DEB_PATH"

echo "Built: $DEB_PATH"
echo ""
echo "Install with:"
echo "  sudo apt install '$DEB_PATH'"
