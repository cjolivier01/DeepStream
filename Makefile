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
# Packaging entry points for the DeepStream Debian package.
# The source build itself is driven by build/build.sh, not from here; these
# targets package the install tree that build leaves at
# /opt/nvidia/deepstream/deepstream-<version>.  See build/BUILD.md.

TOPDIR := $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))
PACKAGE_SCRIPT := $(TOPDIR)/build/package.sh

NVDS_VERSION ?= 9.2.0
NVDS_MAJOR_MINOR := $(shell printf '%s' '$(NVDS_VERSION)' | cut -d. -f1,2)
PKG_NAME := deepstream-$(NVDS_MAJOR_MINOR)

# The package lands in the repository root; override to relocate it.
DEB_OUTPUT_DIR ?= $(TOPDIR)
BUILD_NUMBER_FILE ?= $(TOPDIR)/build/deb-build-number
NEXT_BUILD_NUMBER = $(shell echo $$(( $$(cat '$(BUILD_NUMBER_FILE)' 2>/dev/null || echo 0) + 1 )))
DEB_USER ?= $(shell id -un)
DEB_USER_TAG := $(shell printf '%s' '$(DEB_USER)' | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9')
PACKAGE_VERSION ?=
# Distribution the deb is built for, e.g. ubuntu24.04.  Empty lets package.sh
# detect it from /etc/os-release; it names the release in the filename only,
# never in the version dpkg compares.
DISTRO_TAG ?=

# package.sh reads the version it stamps from the environment.  A local build
# is tagged so it can be told apart from, and sorts above, NVIDIA's own
# deepstream-9.2_9.2.0-1_amd64.deb.
PACKAGE_ENV = NVDS_VERSION='$(NVDS_VERSION)' \
	$(if $(PACKAGE_VERSION),PKG_VERSION='$(PACKAGE_VERSION)',) \
	$(if $(DISTRO_TAG),DISTRO_TAG='$(DISTRO_TAG)',)
PACKAGE_ARGS = --format=deb --output-dir='$(DEB_OUTPUT_DIR)'

# Ask package.sh for the exact filename rather than rebuilding its naming
# rules here.  $(1) is the revision to stamp.
deb_name = $(shell $(PACKAGE_ENV) PKG_REVISION='$(1)' \
	bash '$(PACKAGE_SCRIPT)' --print-deb-name 2>/dev/null)

# Only locally built debs carry a +<user>-<build-number> tag, so neither glob
# can match an untagged upstream or build.sh package.
USER_DEB_GLOB := $(DEB_OUTPUT_DIR)/$(PKG_NAME)_*+$(DEB_USER_TAG)-*_*.deb
ALL_DEB_GLOB := $(DEB_OUTPUT_DIR)/$(PKG_NAME)_*+*-*_*.deb

all: print_targets

.PHONY: all print_targets deb publish publish-dry-run install clean distclean expunge

# Packages whatever build/build.sh installed, untagged, exactly as that build
# would have produced it.  Use publish to stamp a local build number.
deb:
	@echo "Package output directory: $(DEB_OUTPUT_DIR)"
	$(PACKAGE_ENV) bash '$(PACKAGE_SCRIPT)' $(PACKAGE_ARGS)

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
	$(PACKAGE_ENV) PKG_REVISION="1+$(DEB_USER_TAG)-$$next" \
		bash '$(PACKAGE_SCRIPT)' $(PACKAGE_ARGS); \
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
	echo "Would package : $$($(PACKAGE_ENV) PKG_REVISION="1+$(DEB_USER_TAG)-$$next" \
		bash '$(PACKAGE_SCRIPT)' --print-deb-name)"; \
	echo "Output dir   : $(DEB_OUTPUT_DIR)"; \
	echo "Number file  : $$current -> $$next in $(BUILD_NUMBER_FILE)"; \
	echo "Commit, push : $$remote/$$branch"; \
	echo '(dry run - nothing built, committed or pushed)'

install: deb
	@set -e; \
	deb=$$(ls -t $(USER_DEB_GLOB) 2>/dev/null | head -1); \
	if [ -z "$$deb" ]; then \
		echo 'ERROR: no locally tagged deb found; run make publish first' >&2; \
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
		'This Makefile packages the DeepStream install tree that build/build.sh leaves' \
		'at /opt/nvidia/deepstream/deepstream-$(NVDS_MAJOR_MINOR) into a real .deb. It does not' \
		'build DeepStream; run build/build.sh first. See build/BUILD.md.' \
		'' \
		'Build Outputs' \
		'-------------' \
		'deb            Package the installed tree into $(DEB_OUTPUT_DIR), untagged' \
		'               (override DEB_OUTPUT_DIR). No git side effects.' \
		'install        Build the deb, then apt install it (prompts for sudo).' \
		'' \
		'Publishing' \
		'----------' \
		'publish        Increment the build number, package the installed tree tagged' \
		'               +$(DEB_USER_TAG)-<n>, then commit and push $(BUILD_NUMBER_FILE).' \
		'               Nothing is committed if the packaging fails.' \
		'publish-dry-run Show the next version, output path and push target without' \
		'               building, committing or pushing.' \
		'' \
		'Maintenance & Cleanup' \
		'---------------------' \
		'clean          Remove $(DEB_USER_TAG)-tagged debs from $(DEB_OUTPUT_DIR).' \
		'distclean      Remove every locally tagged deb there (any user).' \
		'expunge        Same as distclean.' \
		'' \
		'Variables' \
		'---------' \
		'DEB_USER=$(DEB_USER)   User component of the version tag.' \
		'DEB_OUTPUT_DIR=$(DEB_OUTPUT_DIR)' \
		'NVDS_VERSION=$(NVDS_VERSION)      Selects the package name $(PKG_NAME).' \
		'PACKAGE_VERSION=       Upstream version override (default: $(NVDS_VERSION)).' \
		'DISTRO_TAG=            Distribution named in the deb filename (default:' \
		'                       auto-detected). It is not part of the version.' \
		'' \
		'Next publish version: $(NVDS_VERSION)-1+$(DEB_USER_TAG)-$(NEXT_BUILD_NUMBER)' \
		'Next publish file   : $(call deb_name,1+$(DEB_USER_TAG)-$(NEXT_BUILD_NUMBER))' \
		'' \
		'Meta' \
		'----' \
		'print_targets  Shows this help text.'
