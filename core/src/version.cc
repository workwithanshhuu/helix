// Copyright 2026 The Helix Authors. SPDX-License-Identifier: Apache-2.0

#include "helix/base/version.h"

// These macros are injected by core/CMakeLists.txt. The fallbacks keep the file
// compilable by tools (clang-tidy, editors) that do not see the CMake flags.
#ifndef HELIX_VERSION_STRING
#define HELIX_VERSION_STRING "0.0.0-unknown"
#endif
#ifndef HELIX_BUILD_TYPE_STRING
#define HELIX_BUILD_TYPE_STRING "unknown"
#endif
#ifndef HELIX_SANITIZER_STRING
#define HELIX_SANITIZER_STRING "unknown"
#endif
#ifndef HELIX_COMPILER_STRING
#define HELIX_COMPILER_STRING "unknown"
#endif

namespace helix {

std::string_view version() noexcept {
  return HELIX_VERSION_STRING;
}

BuildInfo build_info() noexcept {
  return BuildInfo{
      .version = HELIX_VERSION_STRING,
      .compiler = HELIX_COMPILER_STRING,
      .build_type = HELIX_BUILD_TYPE_STRING,
      .sanitizer = HELIX_SANITIZER_STRING,
  };
}

}  // namespace helix
