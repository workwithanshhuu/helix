# Helix — root CMake build.
#
# Day 1 builds one library (helix_core), its unit tests and one tool.
# Later milestones add rpc/, store/ and worker/ with add_subdirectory().
#
# Usual entry point is the Makefile (`make build`, `make test`, `make tsan`, ...),
# which calls CMake with the right build directory and options.

cmake_minimum_required(VERSION 3.25)

# Single source of truth for the version: the VERSION file at the repo root
# (also read by the Go code's tests).
file(READ "${CMAKE_CURRENT_SOURCE_DIR}/VERSION" HELIX_VERSION_RAW)
string(STRIP "${HELIX_VERSION_RAW}" HELIX_VERSION)

project(helix
  VERSION ${HELIX_VERSION}
  DESCRIPTION "Hardware-aware distributed tensor execution runtime"
  LANGUAGES CXX)

# ---- Language and toolchain -------------------------------------------------
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)  # used by clang-tidy and editors

if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
  set(CMAKE_BUILD_TYPE RelWithDebInfo CACHE STRING "Build type" FORCE)
endif()

# ---- Options ----------------------------------------------------------------
option(HELIX_BUILD_TESTS "Build unit tests" ON)
option(HELIX_BUILD_BENCHMARKS "Build microbenchmarks (Google Benchmark, from day 2)" OFF)
option(HELIX_WARNINGS_AS_ERRORS "Treat compiler warnings as errors" ON)
set(HELIX_SANITIZER "" CACHE STRING "Sanitizer: address | thread | undefined | (empty)")
set_property(CACHE HELIX_SANITIZER PROPERTY STRINGS "" address thread undefined)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")
include(HelixWarnings)
include(HelixSanitizers)
include(HelixDependencies)

if(HELIX_BUILD_TESTS)
  enable_testing()
endif()

# ---- Components ---------------------------------------------------------------
add_subdirectory(core)
# Day 12+: add_subdirectory(rpc)
# Day 30+: add_subdirectory(store)
# Day 29+: add_subdirectory(worker)

message(STATUS "helix ${PROJECT_VERSION}: build=${CMAKE_BUILD_TYPE} "
               "compiler=${CMAKE_CXX_COMPILER_ID}-${CMAKE_CXX_COMPILER_VERSION} "
               "sanitizer='${HELIX_SANITIZER}' tests=${HELIX_BUILD_TESTS}")
