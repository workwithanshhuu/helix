#!/usr/bin/env bash
# verify-sanitizers-catch-races.sh — proves the race detectors actually work.
#
# Day 1 requires showing that a deliberate data race turns the build red. Rather
# than pushing a throwaway branch, this script compiles two tiny racy programs
# that live outside the normal build (scripts/race-demo/) and asserts that:
#   1. ThreadSanitizer reports "WARNING: ThreadSanitizer: data race" for the C++ one;
#   2. the Go race detector reports "DATA RACE" for the Go one.
# It exits 0 only if BOTH races are detected. CI runs it as the
# "sanitizer-canary" job, so a broken sanitizer setup can never go unnoticed.
#
# Usage: scripts/verify-sanitizers-catch-races.sh

set -euo pipefail
cd "$(dirname "$0")/.."

CXX_BIN="${CXX:-$(command -v clang++ || command -v g++)}"
GO_BIN="${GO:-go}"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

status=0

echo "==> C++: compiling scripts/race-demo/cpp/race.cc with -fsanitize=thread ($CXX_BIN)"
"$CXX_BIN" -std=c++20 -g -O1 -fsanitize=thread -pthread scripts/race-demo/cpp/race.cc -o "$tmp/race"
if TSAN_OPTIONS=halt_on_error=0 "$tmp/race" >"$tmp/tsan.log" 2>&1; then :; fi
if grep -q "WARNING: ThreadSanitizer: data race" "$tmp/tsan.log"; then
  echo "    OK: ThreadSanitizer detected the deliberate race"
else
  echo "    FAIL: ThreadSanitizer did NOT report the race. Output:"
  sed 's/^/      /' "$tmp/tsan.log"
  echo "    Hint: on kernels with vm.mmap_rnd_bits=32 run: sudo sysctl vm.mmap_rnd_bits=28"
  status=1
fi

echo "==> Go: running scripts/race-demo/go with -race"
if "$GO_BIN" run -race -tags racedemo ./scripts/race-demo/go >"$tmp/go.log" 2>&1; then :; fi
if grep -q "DATA RACE" "$tmp/go.log"; then
  echo "    OK: Go race detector detected the deliberate race"
else
  echo "    FAIL: Go race detector did NOT report the race. Output:"
  sed 's/^/      /' "$tmp/go.log"
  status=1
fi

exit "$status"
