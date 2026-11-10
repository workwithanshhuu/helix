// Copyright 2026 The Helix Authors. SPDX-License-Identifier: Apache-2.0
//
// helix/base/version.h — version and build information for libhelix-core.
//
// Why this exists on day 1: it is the smallest real piece of the library, so it
// proves the build, the test runner, the sanitizers and CI end to end before any
// concurrency code is written. Later, `helix_version` and the metrics endpoint
// (day 39) report this information so every benchmark result can be tied to the
// exact build that produced it (SPEC.md §10, rule 2).
//
// Thread safety: all functions are thread-safe and allocation-free; they return
// views of string literals with static storage duration.

#ifndef HELIX_BASE_VERSION_H_
#define HELIX_BASE_VERSION_H_

#include <string_view>

namespace helix {

// Compile-time facts about the running build.
struct BuildInfo {
  std::string_view version;     // Semantic version from the VERSION file, e.g. "0.0.1".
  std::string_view compiler;    // e.g. "Clang-18.1.3".
  std::string_view build_type;  // CMake build type, e.g. "RelWithDebInfo".
  std::string_view sanitizer;   // "none", "address", "thread" or "undefined".
};

// Returns the semantic version string, e.g. "0.0.1".
[[nodiscard]] std::string_view version() noexcept;

// Returns the full build information.
[[nodiscard]] BuildInfo build_info() noexcept;

}  // namespace helix

#endif  // HELIX_BASE_VERSION_H_
