# Increment the version by updating PACKAGE_VERSION,
# then run "make publish" to update package.json and
# the version string in src/your_package/config.py

PACKAGE_VERSION := v0.1.0
PKG := your_package

DEVICE ?= u0

SRC_DIR := src
TEST_DIR := tests
BUILD_DIR := build
DIST_DIR := dist

MICROPY_ROOT := external/micropython
MPY_CROSS := $(MICROPY_ROOT)/mpy-cross/build/mpy-cross
MICROPYTHON := $(MICROPY_ROOT)/ports/unix/build-standard/micropython

RUNTIME_DIR := runtime
TEST_RUNTIME := runtime-test

PY_FILES := $(shell find $(SRC_DIR)/$(PKG) -type f -name "*.py")
NON_INIT_PY := $(filter-out %__init__.py,$(PY_FILES))

MPY_TARGETS = $(patsubst $(SRC_DIR)/%.py,$(BUILD_DIR)/%.mpy,$(NON_INIT_PY))
INIT_TARGETS = $(patsubst $(SRC_DIR)/%.py,$(BUILD_DIR)/%.py,$(filter %__init__.py,$(PY_FILES)))

.PHONY: all
all: clean toolchain static-checkers unit-test build test-unix deploy

# ================================================
# Build
# ================================================

# -----------------------------
# Toolchain
# -----------------------------

.PHONY: toolchain
toolchain:
	git submodule update --init
	git -C $(MICROPY_ROOT) submodule update --init
	$(MAKE) -C $(MICROPY_ROOT)/mpy-cross clean
	$(MAKE) -C $(MICROPY_ROOT)/ports/unix clean
	$(MAKE) -C $(MICROPY_ROOT)/mpy-cross
	$(MAKE) -C $(MICROPY_ROOT)/ports/unix

# -----------------------------
# Build package
# -----------------------------
.PHONY: build
build: $(MPY_TARGETS) $(INIT_TARGETS)
	@mkdir -p $(BUILD_DIR)
	@if [ -d assets ]; then \
		echo "Copying assets/ -> $(BUILD_DIR)"; \
		cp -r assets $(BUILD_DIR)/${PKG}/; \
	fi

# Compile .py -> .mpy
$(BUILD_DIR)/%.mpy: $(SRC_DIR)/%.py
	@mkdir -p $(dir $@)
	@echo "Compiling $< -> $@"
	@$(MPY_CROSS) $< -o $@

# Copy __init__.py
$(BUILD_DIR)/%.py: $(SRC_DIR)/%.py
	@mkdir -p $(dir $@)
	@echo "Copying $< -> $@"
	@cp $< $@

# -----------------------------
# Deploy build output to device
# -----------------------------
.PHONY: deploy
deploy:
	@echo "Uploading build/$(PKG) to device $(DEVICE)"
	@mpremote $(DEVICE) soft-reset
	@mpremote $(DEVICE) mkdir :/lib  || true
	@find $(BUILD_DIR)/$(PKG) | while read source; do \
		rel=$${source#$(BUILD_DIR)/}; \
		remote="/lib/$${rel}"; \
		if [ -d "$$source" ]; then \
			mpremote $(DEVICE) mkdir "$$remote" || true; \
		elif [ -f "$$source" ]; then \
			echo "Uploading $$remote"; \
			mpremote $(DEVICE) rm ":$$remote" || true; \
			mpremote $(DEVICE) cp "$$source" ":$$remote"; \
		fi; \
		sleep 1; \
	done
	@mpremote $(DEVICE) reset


# -----------------------------
# Full redeploy
# -----------------------------
.PHONY: redeploy
redeploy: clean build clean-device deploy


# -----------------------------
# Connect to device through REPL
# -----------------------------
.PHONY: run-device
run-device:
	@mpremote $(DEVICE) reset repl


# ================================================
# Rules for release
# ================================================

# -----------------------------
# Prepare distribution
# -----------------------------
.PHONY: publish
publish:
	@sed -E -i.bak 's/(PACKAGE_VERSION[[:space:]]*=[[:space:]]*)"[^"]*"/\1"$(PACKAGE_VERSION)"/' \
		$(SRC_DIR)/$(PKG)/config.py \
		&& rm -f $(SRC_DIR)/$(PKG)/config.py.bak
	$(MAKE) clean
	$(MAKE) build BUILD_DIR=$(DIST_DIR)
	scripts/update_package.bash $(DIST_DIR) package.json $(PACKAGE_VERSION)


# ================================================
# Unit tests, static checkers
# ================================================

# -----------------------------
# Pylint
# -----------------------------
.PHONY: pylint
pylint:
	@echo "Running Pylint in $(SRC_DIR)/"
	@python3 -m pylint $(SRC_DIR)
	@echo "Running Pylint in $(TEST_DIR)/"
	@python3 -m pylint --rc-file=$(TEST_DIR)/.pylintrc $(TEST_DIR)


# -----------------------------
# Black formatter
# -----------------------------
.PHONY: black
black:
	@echo "Running black formatter"
	@python3 -m black --check $(SRC_DIR) $(TEST_DIR)

# -----------------------------
# Run unit tests
# -----------------------------
.PHONY: unit-test
unit-test:
	@echo "Running unit tests"
	@python3 -m unittest -v

# -----------------------------
# Run all static checkers
# -----------------------------
.PHONY: static-checkers
static-checkers: pylint black


# ================================================
# Functional tests
# ================================================

# -----------------------------
# Prepare functional tests
# -----------------------------
.PHONY: stage-test
stage-test:
	@rm -rf $(TEST_RUNTIME)
	@mkdir -p $(TEST_RUNTIME)/lib

	@cp -r build/$(PKG) $(TEST_RUNTIME)/lib
	@cp tests/functional/*.py $(TEST_RUNTIME)/

# -----------------------------
# Run functional tests on unix port
# -----------------------------
.PHONY: test-unix
test-unix: stage-test
	@cd $(TEST_RUNTIME); \
	for test in test_*.py; do \
		echo "\n==================================="; \
		echo "Running $$test"; \
		echo "==================================="; \
		MICROPYPATH=":.frozen:lib" ../$(MICROPYTHON) $$(basename $$test) || exit 1; \
	done


# ================================================
# Cleanup
# ================================================

# -----------------------------
# Clean local build
# -----------------------------
.PHONY: clean-build
clean-build:
	rm -rf $(BUILD_DIR)

# -----------------------------
# Clean staging
# -----------------------------

.PHONY: clean-runtime
clean-runtime:
	rm -rf $(RUNTIME_DIR) $(TEST_RUNTIME)

# -----------------------------
# Clean all
# -----------------------------
.PHONY: clean
clean: clean-build clean-runtime

# -----------------------------
# Clean package on device
# -----------------------------
.PHONY: clean-device
clean-device:
	@mpremote $(DEVICE) soft-reset
	mpremote $(DEVICE) run scripts/clean_device.py
	@mpremote $(DEVICE) reset
