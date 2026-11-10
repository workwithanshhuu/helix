# ADR-0003: Go for the control plane, C++20 for workers

| Field | Value |
| --- | --- |
| Status | Accepted |
| Date | 2026-11-10 |
| Day | 1 |
| Related | [design 000 §5.1](../design/000-system-design.md) |

## Context
The owner has production proficiency in Go and C++. The control plane is network- and logic-heavy with modest throughput; the worker is compute- and memory-heavy with nanosecond-level hot paths.

## Options considered
- **All C++**: one toolchain; Raft in C++ is slower to write and test; fewer interview signals for distributed-systems roles that use Go (etcd, Kubernetes, CockroachDB).
- **All Go**: fast to build; GC pauses and lack of control over memory layout, atomics orderings and io_uring registered buffers undermine the data-plane goals.
- **All Rust**: strong for both; owner is not yet proficient → schedule risk.
- **Go control + C++ workers (chosen)**.

## Decision
Go 1.23+ for `meta/` (Raft, WAL, state machine, scheduler, gRPC API, CLI). C++20 for `core/`, `rpc/`, `store/`, `worker/`. The boundary is gRPC/protobuf.

## Consequences
- Two build systems (CMake, Go modules) behind one Makefile; two sanitizer stories (TSan/ASan/UBSan and `-race`).
- Worker needs a C++ gRPC client (apt `libgrpc++-dev`), decided with versions on day 25 (ADR then).
- Each language is used where its strengths are visible in interviews.

## How we would know it was wrong
Go GC pauses showing in control-plane p99 that matter for scheduling latency (measured day 39–40) → tune `GOGC`/`GOMEMLIMIT`, reduce allocations; only revisit the language if that fails.
