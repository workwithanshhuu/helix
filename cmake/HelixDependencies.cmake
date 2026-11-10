# Third-party dependencies fetched at configure time (ADR-0001).
#
# Rules:
#  * Pin every dependency to an exact git commit SHA (a content hash), with the
#    release tag in a comment, so builds are reproducible and a moved tag or a
#    tampered mirror cannot change what we compile.
#  * System libraries (liburing, libnuma, OpenBLAS, gRPC/protobuf) come from apt,
#    not from here; see scripts/bootstrap-dev.sh.
#  * Adding a dependency requires an ADR or an entry in an existing one.

include(FetchContent)

if(HELIX_BUILD_TESTS)
  FetchContent_Declare(
    googletest
    GIT_REPOSITORY https://github.com/google/googletest.git
    GIT_TAG        b514bdc898e2951020cbdca1304b75f5950d1f59  # v1.15.2
    GIT_SHALLOW    FALSE  # shallow clones cannot check out an arbitrary SHA
    GIT_PROGRESS   FALSE)
  set(INSTALL_GTEST OFF CACHE BOOL "" FORCE)
  set(BUILD_GMOCK ON CACHE BOOL "" FORCE)
  FetchContent_MakeAvailable(googletest)
  include(GoogleTest)
endif()

# Day 2: Google Benchmark (pinned the same way) when HELIX_BUILD_BENCHMARKS=ON.
