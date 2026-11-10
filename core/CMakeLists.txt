# libhelix-core: memory, synchronization, scheduling, tensors and kernels.
#
# Day 1 contents: build/version information only. Each later day adds sources
# under src/<area>/ and headers under include/helix/<area>/ — see SPEC.md §2.

add_library(helix_core
  src/version.cc)
add_library(helix::core ALIAS helix_core)

target_include_directories(helix_core PUBLIC
  $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>)
target_compile_features(helix_core PUBLIC cxx_std_20)
target_compile_definitions(helix_core PRIVATE
  HELIX_VERSION_STRING="${PROJECT_VERSION}"
  HELIX_BUILD_TYPE_STRING="${CMAKE_BUILD_TYPE}"
  HELIX_SANITIZER_STRING="${HELIX_SANITIZER_NAME}"
  HELIX_COMPILER_STRING="${CMAKE_CXX_COMPILER_ID}-${CMAKE_CXX_COMPILER_VERSION}")
helix_set_warnings(helix_core)

# ---- Tools ----------------------------------------------------------------
add_executable(helix_version tools/helix_version.cc)
target_link_libraries(helix_version PRIVATE helix::core)
helix_set_warnings(helix_version)

# ---- Tests ----------------------------------------------------------------
if(HELIX_BUILD_TESTS)
  add_executable(helix_core_tests
    test/version_test.cc)
  target_link_libraries(helix_core_tests PRIVATE helix::core GTest::gtest_main GTest::gmock)
  target_compile_definitions(helix_core_tests PRIVATE
    HELIX_EXPECTED_VERSION="${PROJECT_VERSION}")
  helix_set_warnings(helix_core_tests)
  gtest_discover_tests(helix_core_tests DISCOVERY_TIMEOUT 60)
endif()
