// Copyright 2026 The Helix Authors. SPDX-License-Identifier: Apache-2.0
//
// DELIBERATELY BROKEN. Two threads increment a plain (non-atomic) int without
// synchronization: a textbook data race and undefined behaviour in C++.
// Not part of the build; used only by scripts/verify-sanitizers-catch-races.sh
// to prove ThreadSanitizer is wired up correctly.

#include <cstdio>
#include <thread>

namespace {
int counter = 0;  // NOLINT: intentionally racy global
}  // namespace

int main() {
  auto bump = [] {
    for (int i = 0; i < 100000; ++i) {
      ++counter;  // data race: unsynchronized read-modify-write from two threads
    }
  };
  std::thread a(bump);
  std::thread b(bump);
  a.join();
  b.join();
  std::printf("counter=%d (expected 200000 if there were no race)\n", counter);
  return 0;
}
