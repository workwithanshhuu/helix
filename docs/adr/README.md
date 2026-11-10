# Architecture decision records

An ADR records **one** decision with a real alternative: the context, the options considered, the choice, and its consequences. ADRs are immutable once accepted; to change a decision, write a new ADR that **supersedes** the old one and update the old one's status.

| # | Title | Status | Date |
| --- | --- | --- | --- |
| [0001](0001-build-system-cmake-fetchcontent.md) | C++ build: CMake + FetchContent pinned by commit SHA | Accepted | 2026-11-10 |
| [0002](0002-grpc-for-control-plane-custom-data-plane.md) | gRPC for the control plane, custom io_uring transport for the data plane | Accepted | 2026-11-10 |
| [0003](0003-two-languages-go-and-cpp.md) | Go for the control plane, C++20 for workers | Accepted | 2026-11-10 |
| [0004](0004-dev-environment-orbstack-arm64.md) | Develop in OrbStack Ubuntu 24.04 arm64; benchmark on rented x86 | Accepted | 2026-11-10 |
| [0005](0005-raft-from-scratch.md) | Write Raft from scratch instead of using etcd/raft or hashicorp/raft | Accepted | 2026-11-10 |

Expected upcoming ADRs (written on the day the decision is made): Google Benchmark (day 2), status/error type (day 3), huge-page policy (day 4), deque memory reclamation (day 6), parking strategy (day 7), BLAS dependency (day 9), liburing version (day 12), Porcupine (day 26), protobuf/gRPC versions (day 27), object-store eviction policy (day 30), lease TTL (day 34).

How to write one: copy [0000-template.md](0000-template.md), take the next number, or run `/adr <title>` in Claude Code.
