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
#
# Publishing helpers for the local Ubuntu 26.04 compatibility deb.
# The DeepStream source build itself is driven by build/build.sh, not by this
# Makefile; see build/BUILD.md.

SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c

REPO_ROOT := $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))
COMPAT_DEB_SCRIPT := $(REPO_ROOT)/scripts/build_deepstream_ubuntu26_compat_deb.sh
BUILD_NUMBER_FILE := $(REPO_ROOT)/build/deb-build-number

# User component of the deb version; the script sanitizes it for dpkg.
DEB_USER ?= $(shell id -un)
# Extra flags forwarded to the compat deb script (e.g. COMPAT_DEB_FLAGS=--force).
COMPAT_DEB_FLAGS ?=

.DEFAULT_GOAL := help
.PHONY: help deb publish

help:
	@echo "Targets:"
	@echo "  deb      Build the Ubuntu 26.04 compatibility deb into the repo root"
	@echo "           (reuses the current build number; no git side effects)"
	@echo "  publish  Increment the build number, build the deb into the repo root,"
	@echo "           then commit and push $(notdir $(BUILD_NUMBER_FILE))"
	@echo ""
	@echo "Variables:"
	@echo "  DEB_USER=$(DEB_USER)            user component of the deb version"
	@echo "  COMPAT_DEB_FLAGS=               extra flags for the build script"
	@echo ""
	@echo "Current build number: $$(cat '$(BUILD_NUMBER_FILE)' 2>/dev/null || echo 'unset')"

deb:
	@DEB_USER='$(DEB_USER)' bash '$(COMPAT_DEB_SCRIPT)' \
	    --output-dir '$(REPO_ROOT)' $(COMPAT_DEB_FLAGS)

# The deb is built before the build number is recorded, so a failed build leaves
# the tracked number untouched and nothing is committed or pushed.
publish:
	@current=$$(cat '$(BUILD_NUMBER_FILE)' 2>/dev/null || echo 0); \
	if [[ ! "$$current" =~ ^[0-9]+$$ ]]; then \
	  echo "error: $(BUILD_NUMBER_FILE) does not hold a build number: '$$current'" >&2; \
	  exit 1; \
	fi; \
	next=$$((current + 1)); \
	branch=$$(git -C '$(REPO_ROOT)' rev-parse --abbrev-ref HEAD); \
	if [[ "$$branch" == HEAD ]]; then \
	  echo "error: HEAD is detached; check out a branch before publishing" >&2; \
	  exit 1; \
	fi; \
	remote=$$(git -C '$(REPO_ROOT)' config --get "branch.$$branch.remote" || echo origin); \
	echo "==> publishing build $(DEB_USER)-$$next to $$remote/$$branch"; \
	DEB_USER='$(DEB_USER)' bash '$(COMPAT_DEB_SCRIPT)' \
	    --build-number "$$next" --output-dir '$(REPO_ROOT)' $(COMPAT_DEB_FLAGS); \
	echo "$$next" >'$(BUILD_NUMBER_FILE)'; \
	git -C '$(REPO_ROOT)' add -- '$(BUILD_NUMBER_FILE)'; \
	git -C '$(REPO_ROOT)' commit -q \
	    -m "build: compat deb build number $(DEB_USER)-$$next" \
	    -- '$(BUILD_NUMBER_FILE)'; \
	git -C '$(REPO_ROOT)' push "$$remote" "HEAD:refs/heads/$$branch"; \
	echo "==> published build $(DEB_USER)-$$next"
