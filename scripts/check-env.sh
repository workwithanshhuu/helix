#!/usr/bin/env bash
# check-env.sh — prints the machine and toolchain facts every benchmark and
# day log must record (SPEC.md §10, rule 2), and checks Helix's kernel needs.
#
# Usage:
#   scripts/check-env.sh            # print a Markdown report to stdout
#   scripts/check-env.sh > docs/progress/env-$(hostname).md
#
# Exit status is non-zero if a hard requirement is missing (Linux kernel < 6.1,
# no C++20 compiler, no Go). Soft requirements (io_uring headers, bpftrace,
# NUMA) only produce warnings, because they are needed later, not on day 1.

set -uo pipefail
cd "$(dirname "$0")/.."

fail=0
warn() { echo "- WARNING: $*"; }
bad()  { echo "- MISSING: $*"; fail=1; }
have() { command -v "$1" >/dev/null 2>&1; }

kernel="$(uname -r)"
echo "# Helix environment report"
echo
echo "Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)  ·  Commit: $(git rev-parse --short HEAD 2>/dev/null || echo n/a)"
echo
echo "## Machine"
echo
echo "| Fact | Value |"
echo "| --- | --- |"
echo "| OS | $(uname -s) $(. /etc/os-release 2>/dev/null && echo "$PRETTY_NAME") |"
echo "| Kernel | $kernel |"
echo "| Architecture | $(uname -m) |"
echo "| Logical CPUs | $(nproc 2>/dev/null || echo ?) |"
echo "| Memory | $(awk '/MemTotal/ {printf "%.1f GiB", $2/1048576}' /proc/meminfo 2>/dev/null || echo ?) |"
echo "| Page size | $(getconf PAGESIZE 2>/dev/null || echo ?) bytes |"
echo "| L1d cache line | $(getconf LEVEL1_DCACHE_LINESIZE 2>/dev/null || echo ?) bytes (0 = not reported by the VM) |"
echo "| NUMA nodes | $( (ls -d /sys/devices/system/node/node* 2>/dev/null || true) | wc -l) |"
echo "| THP mode | $(cat /sys/kernel/mm/transparent_hugepage/enabled 2>/dev/null || echo n/a) |"
echo "| mmap_rnd_bits | $(cat /proc/sys/vm/mmap_rnd_bits 2>/dev/null || echo n/a) (TSan needs <= 30 on some kernels) |"
echo
echo "## Toolchain"
echo
echo "| Tool | Version |"
echo "| --- | --- |"
for t in clang++ g++ cmake ninja go clang-format clang-tidy bpftrace; do
  if have "$t"; then
    v="$("$t" --version 2>/dev/null | head -1)"
    [ "$t" = go ] && v="$(go version)"
    echo "| $t | $v |"
  else
    echo "| $t | not installed |"
  fi
done
if [ -x build/core/helix_version ]; then
  echo
  echo "## helix_version"
  echo
  echo '```'
  build/core/helix_version
  echo '```'
fi
echo
echo "## Checks"
echo
[ "$(uname -s)" = Linux ] || bad "Linux is required for io_uring/perf/NUMA (use the OrbStack machine)."
major="${kernel%%.*}"; rest="${kernel#*.}"; minor="${rest%%.*}"
if [ "$(uname -s)" = Linux ] && { [ "$major" -lt 6 ] || { [ "$major" -eq 6 ] && [ "$minor" -lt 1 ]; }; }; then
  bad "kernel $kernel < 6.1 (send_zc and newer io_uring features need 6.0+)."
fi
have clang++ || have g++ || bad "no C++ compiler"
have cmake || bad "cmake"
have go || bad "go"
have ninja || warn "ninja not installed (make falls back to Unix Makefiles)"
[ -f /usr/include/liburing.h ] || warn "liburing headers not found (needed from day 2/12): sudo apt install liburing-dev"
[ -f /usr/include/numa.h ] || warn "libnuma headers not found (needed from day 4): sudo apt install libnuma-dev"
have bpftrace || warn "bpftrace not installed (needed from day 2/41)"
[ "$fail" -eq 0 ] && echo "- All hard requirements met."
exit "$fail"
