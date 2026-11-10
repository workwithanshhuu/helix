# Helix — single entry point for building, testing and checking.
#
#   make help        list targets
#   make check       everything required by the Definition of Done (SPEC.md §1)
#
# Each C++ configuration has its own build directory, so switching between
# release and sanitizer builds never forces a full rebuild:
#   build/  build-asan/  build-tsan/  build-ubsan/

SHELL       := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c

# Prefer clang (matches CI and the sanitizer docs) unless CC/CXX are set in the
# environment or on the command line; fall back to the system compiler.
ifeq ($(origin CC),default)
CC  := $(shell command -v clang   >/dev/null 2>&1 && echo clang   || echo cc)
endif
ifeq ($(origin CXX),default)
CXX := $(shell command -v clang++ >/dev/null 2>&1 && echo clang++ || echo c++)
endif
export CC CXX

BUILD_TYPE ?= RelWithDebInfo
GENERATOR  ?= $(shell command -v ninja >/dev/null 2>&1 && echo Ninja || echo "Unix Makefiles")
JOBS       ?= $(shell nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)
GO         ?= go
CTEST_ARGS ?= --output-on-failure
# Extra CMake arguments, e.g. offline builds:
#   make test CMAKE_ARGS=-DFETCHCONTENT_SOURCE_DIR_GOOGLETEST=$$HOME/src/googletest-1.15.2
CMAKE_ARGS ?=

CPP_SOURCES = $(shell git ls-files '*.h' '*.cc' 2>/dev/null | grep -v '^scripts/race-demo/' || true)
GO_PACKAGES = ./...

# configure(dir, extra cmake args)
define configure
	cmake -S . -B $(1) -G "$(GENERATOR)" -DCMAKE_BUILD_TYPE=$(BUILD_TYPE) $(CMAKE_ARGS) $(2) >/dev/null
endef

.DEFAULT_GOAL := help

.PHONY: help
help: ## Show this help
	@grep -hE '^[a-zA-Z0-9_-]+:.*## ' $(MAKEFILE_LIST) | sort | \
	  awk 'BEGIN {FS = ":.*## "}; {printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}'

# ---- Build ------------------------------------------------------------------
.PHONY: build build-cpp build-go
build: build-cpp build-go ## Release build of C++ and Go

build-cpp:
	$(call configure,build,)
	cmake --build build -j $(JOBS)

build-go:
	$(GO) build $(GO_PACKAGES)

# ---- Test -------------------------------------------------------------------
.PHONY: test test-cpp test-go
test: test-cpp test-go ## Unit tests (C++ via ctest, Go via go test)

test-cpp: build-cpp
	ctest --test-dir build -j $(JOBS) $(CTEST_ARGS)

test-go:
	$(GO) test $(GO_PACKAGES)

# ---- Sanitizers ---------------------------------------------------------------
.PHONY: asan tsan ubsan race
asan: ## C++ tests under AddressSanitizer
	$(call configure,build-asan,-DHELIX_SANITIZER=address)
	cmake --build build-asan -j $(JOBS)
	ASAN_OPTIONS=detect_leaks=1:abort_on_error=1 ctest --test-dir build-asan -j $(JOBS) $(CTEST_ARGS)

tsan: ## C++ tests under ThreadSanitizer
	$(call configure,build-tsan,-DHELIX_SANITIZER=thread)
	cmake --build build-tsan -j $(JOBS)
	TSAN_OPTIONS=halt_on_error=1:second_deadlock_stack=1 ctest --test-dir build-tsan -j $(JOBS) $(CTEST_ARGS)

ubsan: ## C++ tests under UndefinedBehaviorSanitizer
	$(call configure,build-ubsan,-DHELIX_SANITIZER=undefined)
	cmake --build build-ubsan -j $(JOBS)
	UBSAN_OPTIONS=print_stacktrace=1:halt_on_error=1 ctest --test-dir build-ubsan -j $(JOBS) $(CTEST_ARGS)

race: ## Go tests under the race detector
	$(GO) test -race -count=1 $(GO_PACKAGES)

.PHONY: verify-sanitizers
verify-sanitizers: ## Prove TSan and the Go race detector catch a deliberate race
	scripts/verify-sanitizers-catch-races.sh

# ---- Lint and format -----------------------------------------------------------
.PHONY: lint format format-check tidy vet
lint: format-check vet tidy ## All static checks

format: ## Rewrite C++ and Go sources in place
	@if [ -n "$(CPP_SOURCES)" ]; then clang-format -i $(CPP_SOURCES); fi
	gofmt -w $$(git ls-files '*.go')

format-check: ## Fail if any file is not formatted
	@if [ -n "$(CPP_SOURCES)" ]; then clang-format --dry-run --Werror $(CPP_SOURCES); fi
	@unformatted=$$(gofmt -l $$(git ls-files '*.go')); \
	  if [ -n "$$unformatted" ]; then echo "gofmt needed: $$unformatted"; exit 1; fi

vet: ## go vet
	$(GO) vet $(GO_PACKAGES)

tidy: build-cpp ## clang-tidy over C++ sources (uses build/compile_commands.json)
	@files=$$(git ls-files 'core/*.cc' 'rpc/*.cc' 'store/*.cc' 'worker/*.cc' 2>/dev/null); \
	  if [ -n "$$files" ]; then clang-tidy -p build --quiet $$files; fi

# ---- Aggregate ------------------------------------------------------------------
.PHONY: check
check: lint test asan tsan ubsan race ## Definition of Done: lint + tests + all sanitizers

# ---- Environment ----------------------------------------------------------------
.PHONY: env
env: build-cpp ## Print machine and toolchain facts (record them in docs/progress)
	scripts/check-env.sh

# ---- Later milestones (placeholders so the targets exist from day 1) -------------
.PHONY: bench cluster-up cluster-down chaos
bench: ## Microbenchmarks (arrives day 2)
	@echo "make bench: arrives on day 2 (Google Benchmark harness)"; exit 1
cluster-up: ## Start 3 meta + 3 workers in docker compose (arrives day 27)
	@echo "make cluster-up: arrives on day 27"; exit 1
cluster-down: ## Stop the compose cluster (arrives day 27)
	@echo "make cluster-down: arrives on day 27"; exit 1
chaos: ## Chaos run against the cluster (arrives day 35)
	@echo "make chaos: arrives on day 35"; exit 1

# ---- Housekeeping ---------------------------------------------------------------
.PHONY: clean
clean: ## Remove all build directories
	rm -rf build build-asan build-tsan build-ubsan
	$(GO) clean -testcache
