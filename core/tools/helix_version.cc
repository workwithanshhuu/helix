// Copyright 2026 The Helix Authors. SPDX-License-Identifier: Apache-2.0
//
// helix_version — prints build information. Used by scripts/check-env.sh and by
// benchmark scripts to record exactly which build produced a result.

#include <cstdio>

#include "helix/base/version.h"

int main() {
  const helix::BuildInfo info = helix::build_info();
  std::printf("helix %.*s\ncompiler   %.*s\nbuild_type %.*s\nsanitizer  %.*s\n",
              static_cast<int>(info.version.size()), info.version.data(),
              static_cast<int>(info.compiler.size()), info.compiler.data(),
              static_cast<int>(info.build_type.size()), info.build_type.data(),
              static_cast<int>(info.sanitizer.size()), info.sanitizer.data());
  return 0;
}
