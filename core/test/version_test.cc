// Copyright 2026 The Helix Authors. SPDX-License-Identifier: Apache-2.0
//
// Day-1 tests. They are deliberately small: their job is to prove that the test
// runner, sanitizer builds and CI all work, and to pin the version contract.

#include "helix/base/version.h"

#include <gmock/gmock.h>
#include <gtest/gtest.h>

#include <string>
#include <thread>
#include <vector>

namespace helix {
namespace {

using ::testing::AnyOf;
using ::testing::MatchesRegex;
using ::testing::Not;
using ::testing::StrEq;

TEST(VersionTest, IsSemanticVersion) {
  EXPECT_THAT(std::string(version()), MatchesRegex("[0-9]+\\.[0-9]+\\.[0-9]+"));
}

TEST(VersionTest, MatchesVersionFile) {
  // HELIX_EXPECTED_VERSION comes from the VERSION file via CMake, so this test
  // fails if the library was built from a stale configuration.
  EXPECT_EQ(version(), HELIX_EXPECTED_VERSION);
}

TEST(VersionTest, BuildInfoIsConsistent) {
  const BuildInfo info = build_info();
  EXPECT_EQ(info.version, version());
  EXPECT_FALSE(info.compiler.empty());
  EXPECT_FALSE(info.build_type.empty());
  EXPECT_THAT(std::string(info.sanitizer),
              AnyOf(StrEq("none"), StrEq("address"), StrEq("thread"), StrEq("undefined")));
  EXPECT_THAT(std::string(info.compiler), Not(StrEq("unknown")));
}

TEST(VersionTest, SafeToCallConcurrently) {
  // Exercised under TSan in CI: many threads reading the build info at once
  // must not report a race (the data is static and immutable).
  constexpr int kThreads = 8;
  constexpr int kIterations = 10'000;
  std::vector<std::thread> threads;
  threads.reserve(kThreads);
  for (int t = 0; t < kThreads; ++t) {
    threads.emplace_back([] {
      for (int i = 0; i < kIterations; ++i) {
        const BuildInfo info = build_info();
        ASSERT_EQ(info.version, version());
      }
    });
  }
  for (auto& th : threads) {
    th.join();
  }
}

}  // namespace
}  // namespace helix
