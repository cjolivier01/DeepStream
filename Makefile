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
# Packaging entry points for the local Ubuntu 26.04 compatibility deb.
# The DeepStream source build itself is driven by build/build.sh, not from
# here; see build/BUILD.md.

TOPDIR := $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))
COMPAT_DEB_SCRIPT := $(TOPDIR)/scripts/build_deepstream_ubuntu26_compat_deb.sh

NVDS_VERSION ?= 9.2.0
NVDS_MAJOR_MINOR := $(shell printf '%s' '$(NVDS_VERSION)' | cut -d. -f1,2)
PKG_NAME := deepstream-$(NVDS_MAJOR_MINOR)

# The compatibility deb lands in the repository root; override to relocate it.
DEB_OUTPUT_DIR ?= $(TOPDIR)
BUILD_NUMBER_FILE ?= $(TOPDIR)/build/deb-build-number
DEB_USER ?= $(shell id -un)
DEB_USER_TAG := $(shell printf '%s' '$(DEB_USER)' | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9')
PACKAGE_VERSION ?=
INSTALL_ROOT ?=
FORCE ?=

COMPAT_DEB_ENV = NVDS_VERSION='$(NVDS_VERSION)' BUILD_NUMBER_FILE='$(BUILD_NUMBER_FILE)'
COMPAT_DEB_ARGS = --output-dir='$(DEB_OUTPUT_DIR)' --user='$(DEB_USER)' \
	$(if $(PACKAGE_VERSION),--version='$(PACKAGE_VERSION)',) \
	$(if $(INSTALL_ROOT),--install-root='$(INSTALL_ROOT)',) \
	$(if $(FORCE),--force,)

# Only locally built compatibility debs carry a -<user>-<build-number> tag, so
# neither glob can match NVIDIA's own deepstream-9.2_9.2.0-1_amd64.deb (one
# hyphen in its version field, these need two).
USER_DEB_GLOB := $(DEB_OUTPUT_DIR)/$(PKG_NAME)_*-$(DEB_USER_TAG)-*_*.deb
ALL_DEB_GLOB := $(DEB_OUTPUT_DIR)/$(PKG_NAME)_*-*-*_*.deb

all: print_targets

.PHONY: all print_targets deb publish publish-dry-run install clean distclean expunge

deb:
	@echo "Compatibility deb output directory: $(DEB_OUTPUT_DIR)"
	$(COMPAT_DEB_ENV) bash '$(COMPAT_DEB_SCRIPT)' $(COMPAT_DEB_ARGS)

# The deb is built before the new number is recorded, so a failed build leaves
# the tracked number untouched and nothing is committed or pushed. The commit is
# limited to the build number file, so unrelated working-tree and staged changes
# are left alone.
publish:
	@set -e; \
	current=$$(cat '$(BUILD_NUMBER_FILE)' 2>/dev/null || echo 0); \
	case "$$current" in \
		''|*[!0-9]*) \
			echo "ERROR: $(BUILD_NUMBER_FILE) does not hold a build number: '$$current'" >&2; \
			exit 2 ;; \
	esac; \
	next=$$((current + 1)); \
	branch=$$(git -C '$(TOPDIR)' rev-parse --abbrev-ref HEAD); \
	if [ "$$branch" = HEAD ]; then \
		echo 'ERROR: HEAD is detached; check out a branch before publishing' >&2; \
		exit 2; \
	fi; \
	remote=$$(git -C '$(TOPDIR)' config --get "branch.$$branch.remote" || echo origin); \
	echo "==> publishing build $(DEB_USER_TAG)-$$next to $$remote/$$branch"; \
	$(COMPAT_DEB_ENV) bash '$(COMPAT_DEB_SCRIPT)' $(COMPAT_DEB_ARGS) --build-number "$$next"; \
	echo "$$next" >'$(BUILD_NUMBER_FILE)'; \
	git -C '$(TOPDIR)' add -- '$(BUILD_NUMBER_FILE)'; \
	git -C '$(TOPDIR)' commit -q \
		-m "build: compat deb build number $(DEB_USER_TAG)-$$next" \
		-- '$(BUILD_NUMBER_FILE)'; \
	git -C '$(TOPDIR)' push "$$remote" "HEAD:refs/heads/$$branch"; \
	echo "==> published build $(DEB_USER_TAG)-$$next"

publish-dry-run:
	@set -e; \
	current=$$(cat '$(BUILD_NUMBER_FILE)' 2>/dev/null || echo 0); \
	case "$$current" in \
		''|*[!0-9]*) \
			echo "ERROR: $(BUILD_NUMBER_FILE) does not hold a build number: '$$current'" >&2; \
			exit 2 ;; \
	esac; \
	next=$$((current + 1)); \
	branch=$$(git -C '$(TOPDIR)' rev-parse --abbrev-ref HEAD); \
	remote=$$(git -C '$(TOPDIR)' config --get "branch.$$branch.remote" || echo origin); \
	$(COMPAT_DEB_ENV) bash '$(COMPAT_DEB_SCRIPT)' $(COMPAT_DEB_ARGS) --build-number "$$next" --dry-run; \
	echo "Number file  : $$current -> $$next in $(BUILD_NUMBER_FILE)"; \
	echo "Commit, push : $$remote/$$branch"; \
	echo '(dry run - nothing built, committed or pushed)'

install: deb
	@set -e; \
	deb=$$(ls -t $(USER_DEB_GLOB) 2>/dev/null | head -1); \
	if [ -z "$$deb" ]; then \
		echo 'ERROR: no compatibility deb found; run make deb first' >&2; \
		exit 2; \
	fi; \
	echo "==> installing $$deb"; \
	sudo apt install "$$deb"

clean:
	rm -f $(USER_DEB_GLOB)

distclean expunge:
	rm -f $(ALL_DEB_GLOB)

print_targets:
	@printf '%s\n' \
		"Available make targets (run 'make <target>'):" \
		'' \
		'This Makefile only packages the Ubuntu 26.04 compatibility deb, a metadata-only' \
		'registration package for a DeepStream tree already installed by build/build.sh.' \
		'Run the source build itself with build/build.sh; see build/BUILD.md.' \
		'' \
		'Build Outputs' \
		'-------------' \
		'deb            Build the compatibility deb at the current build number into' \
		'               $(DEB_OUTPUT_DIR) (override DEB_OUTPUT_DIR). No git side effects.' \
		'install        Build the deb, then apt install it (prompts for sudo).' \
		'' \
		'Publishing' \
		'----------' \
		'publish        Increment the build number, build the deb, then commit and push' \
		'               $(BUILD_NUMBER_FILE). Nothing is committed if the build fails.' \
		'publish-dry-run Show the next version, output path and push target without' \
		'               building, committing or pushing.' \
		'' \
		'Maintenance & Cleanup' \
		'---------------------' \
		'clean          Remove $(DEB_USER_TAG) compatibility debs from $(DEB_OUTPUT_DIR).' \
		'distclean      Remove every locally built compatibility deb there (any user).' \
		'expunge        Same as distclean.' \
		'' \
		'Variables' \
		'---------' \
		'DEB_USER=$(DEB_USER)   User component of the version tag.' \
		'DEB_OUTPUT_DIR=$(DEB_OUTPUT_DIR)' \
		'NVDS_VERSION=$(NVDS_VERSION)      Selects the package name $(PKG_NAME).' \
		'PACKAGE_VERSION=       Full Debian version override (skips the build tag).' \
		'INSTALL_ROOT=          DeepStream install root to register.' \
		'FORCE=1                Build on a host that is not Ubuntu 26.04/resolute.' \
		'' \
		'Current version: $(NVDS_VERSION)-<revision>-$(DEB_USER_TAG)-'"$$(cat '$(BUILD_NUMBER_FILE)' 2>/dev/null || echo '?')" \
		'' \
		'Meta' \
		'----' \
		'print_targets  Shows this help text.'
