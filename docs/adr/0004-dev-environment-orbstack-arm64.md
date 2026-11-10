# ADR-0004: Develop in OrbStack Ubuntu 24.04 arm64; benchmark on rented x86

| Field | Value |
| --- | --- |
| Status | Accepted |
| Date | 2026-11-10 |
| Day | 1 |
| Related | [runbooks/dev-environment.md](../runbooks/dev-environment.md), [plan](../plan/45-day-plan.md) |

## Context
Hardware: MacBook Air M5, 24 GB RAM. Helix needs Linux (io_uring, `perf`, eBPF, NUMA syscalls, sanitizers with Linux runtimes). Budget: free, up to ~₹1–2k for cloud. Real NUMA, hardware performance counters and GPUs are not available on the laptop.

## Options considered
- **VirtualBox**: Apple Silicon support is limited/slow; poor fit.
- **UTM (QEMU/Apple Virtualization)**: free, stock Ubuntu kernel; more manual networking and file sharing; good fallback if OrbStack's kernel lacks a feature.
- **OrbStack Linux machine (chosen)**: lightweight, fast file sharing, near-native arm64 performance, free for personal use; custom kernel (must verify io_uring/eBPF features on day 2).
- **Cloud dev box full time**: x86 and real counters, but costs money every day and adds latency to the loop.
- **Docker Desktop containers**: fine for builds, awkward for kernel features and long-lived dev.

## Decision
Develop and test daily in an **OrbStack Ubuntu 24.04 arm64** machine named `helix`. ARM's weak memory model is a deliberate advantage for lock-free testing. Run CUDA on a free Kaggle GPU (day 36) and hardware-sensitive measurements (perf counters, `perf c2c`, NUMA, published benchmarks) on short-lived rented machines on days 42–43, destroyed after each session. CI covers x86-64 and arm64.

## Consequences
- No published performance numbers from the laptop VM.
- Day 2 includes a kernel feature smoke test (io_uring ops, `send_zc`, bpftrace); fallback to UTM with a stock kernel if anything is missing.
- TSan needs `vm.mmap_rnd_bits=28` persisted in the VM.

## How we would know it was wrong
io_uring `send_zc`, provided buffer rings or bpftrace unavailable in OrbStack's kernel → switch to UTM (documented in the runbook).
