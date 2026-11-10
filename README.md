# Helix

**A hardware-aware distributed runtime that schedules tensor-task DAGs across a cluster of C++ workers, moves tensors between them with zero-copy io_uring transport, and keeps all cluster metadata in its own Raft-replicated control plane.**

[![ci](https://github.com/workwithanshhuu/helix/actions/workflows/ci.yml/badge.svg)](https://github.com/workwithanshhuu/helix/actions/workflows/ci.yml)
![status](https://img.shields.io/badge/status-day%201%20of%2045-blue)
![license](https://img.shields.io/badge/license-Apache--2.0-green)
![c++](https://img.shields.io/badge/C%2B%2B-20-informational)
![go](https://img.shields.io/badge/Go-1.23%2B-informational)

> **Status: day 1 of a 45-day build.** The repository skeleton, build system, sanitizer CI and the full design documentation exist; the runtime components land milestone by milestone (see [Roadmap](#roadmap)). Everything below that is not marked *(today)* describes the design that the code is being built against.

---

## What Helix is

A client submits a job: a DAG of tasks such as `matmul`, `softmax` or a transformer block. The **control plane** (Go, `helix-meta`) records the job through its own Raft log, picks workers by data locality, queue depth and memory headroom, and hands out **leases** protected by **fencing tokens**. Each **worker** (C++, `helixd`) runs tasks on a NUMA-pinned **work-stealing scheduler** over lock-free deques, allocates tensors from a **custom slab allocator**, and stores results in a **memory-mapped object store**. Downstream tasks on other nodes pull those tensors over **io_uring TCP with registered buffers and `send_zc`**, landing directly in their own store with no copies in Helix code. When a worker dies, lost results are **recomputed from lineage**.

It is the small, honest cousin of Ray + Plasma, built from the allocator up, and measured against gRPC and Ray.

```
                 clients: helixctl, load generator
                              │ submit DAGs (gRPC)
          ┌───────────────────▼────────────────────┐
          │  helix-meta (Go) × 3, Raft-replicated   │  jobs, tasks, leases,
          │  scheduler · Raft · WAL+snapshots ·     │  object directory
          │  membership                             │
          └──────┬───────────────────────┬──────────┘
     leases, heartbeats (gRPC)    leases, heartbeats (gRPC)
          ┌──────▼──────────┐     ┌──────▼──────────┐
          │ helixd (C++)    │◀───▶│ helixd (C++)    │   tensor bytes:
          │ work-stealing   │fetch│ work-stealing   │   io_uring TCP,
          │ executor, slab  │     │ executor, slab  │   zero-copy
          │ mmap obj store  │     │ mmap obj store  │
          └─────────────────┘     └─────────────────┘
```

Full picture: [ARCHITECTURE.md](ARCHITECTURE.md) · Contract: [SPEC.md](SPEC.md) · System design: [docs/design/000-system-design.md](docs/design/000-system-design.md)

## Quickstart (today)

Development happens in an **Ubuntu 24.04 Linux machine** (OrbStack on macOS, any Ubuntu VM, or a cloud box), because io_uring, `perf`, NUMA and the sanitizers need Linux. Full walkthrough: [docs/runbooks/dev-environment.md](docs/runbooks/dev-environment.md).

```bash
# inside the Linux machine
git clone git@github.com:workwithanshhuu/helix.git && cd helix
scripts/bootstrap-dev.sh     # installs clang, cmake, ninja, Go, liburing, ...
make check                   # lint + unit tests + ASan + TSan + UBSan + Go race detector
make verify-sanitizers       # proves TSan and the Go race detector catch a deliberate race
make env                     # prints machine/toolchain facts for docs/progress/
build/core/helix_version     # prints build information
```

`make help` lists every target.

## Repository map

| Path | What lives there | Arrives |
| --- | --- | --- |
| [`core/`](core/) | `libhelix-core` (C++20): allocator, lock-free queues, work-stealing pool, DAG executor, tensors, kernels | day 1 (skeleton) → day 11 |
| [`rpc/`](rpc/) | `helix-rpc`: io_uring data plane, framing, flow control | days 12–17 |
| [`store/`](store/) | `helix-store`: mmap object store | day 30 |
| [`worker/`](worker/) | `helixd` worker daemon | days 29–37 |
| [`meta/`](meta/) | `helix-meta` (Go): Raft, WAL, state machine, scheduler, gRPC API, `helixctl` | day 1 (skeleton) → day 34 |
| [`proto/`](proto/) | gRPC/protobuf definitions | days 25–27 |
| [`bench/`](bench/) | load generator, baselines (gRPC, Ray), results, plotting | days 2, 17, 41–43 |
| [`test/chaos/`](test/chaos/) | fault injection + result checker | day 35 |
| [`deploy/`](deploy/) | docker compose, Dockerfiles, Terraform | days 27, 41 |
| [`tools/bpf/`](tools/bpf/) | bpftrace scripts | day 41 |
| [`scripts/`](scripts/) | bootstrap, environment report, sanitizer canary | day 1 |
| [`docs/`](docs/) | design, API, data model, concepts, ADRs, runbooks, interview prep, plan | day 1 → |

## Documentation

| Read this | When |
| --- | --- |
| [docs/README.md](docs/README.md) | Map of every document |
| [SPEC.md](SPEC.md) | The binding technical contract: conventions, APIs, wire format, data model, protocols, failure matrix, config, metrics, testing, benchmarks |
| [ARCHITECTURE.md](ARCHITECTURE.md) | Components, request lifecycle, threading model |
| [docs/design/](docs/design/) | System design doc and one design doc per milestone |
| [docs/api/](docs/api/) | C++ API, wire protocol, gRPC API, CLI |
| [docs/db/](docs/db/) | Metadata schema, WAL and snapshot formats, object-store layout |
| [docs/concepts/](docs/concepts/) | The theory behind every component, from caches to Raft |
| [docs/adr/](docs/adr/) | Architecture decision records |
| [docs/plan/](docs/plan/) | 45-day plan and the step-by-step day guide |
| [docs/progress/](docs/progress/) | What was done each day, with evidence |
| [docs/interview/](docs/interview/) | Talking points, question bank, design prompts |
| [docs/study-guide/](docs/study-guide/) | Reading list and glossary |
| [CLAUDE.md](CLAUDE.md) | How AI coding sessions must work in this repo |

## Roadmap

| Release | Day | Milestone | Headline result |
| --- | --- | --- | --- |
| v0.1 | 11 | M1 low-level core | Lock-free ring and deque, slab allocator, work-stealing pool, tiled matmul DAG |
| v0.2 | 17 | M2 data plane | io_uring zero-copy transport; latency vs gRPC |
| v0.3 | 28 | M3 control plane | Raft with WAL, snapshots, PreVote; Porcupine-verified linearizability |
| v0.4 | 38 | M4 execution | Distributed DAGs, locality scheduling, `kill -9` recovery via lineage |
| v0.5 | 45 | M5 observability | Metrics, Perfetto traces, benchmarks vs gRPC and Ray |

## Benchmarks

None yet: numbers are published only when measured, with the setup and raw data, following [SPEC.md §10](SPEC.md#10-benchmark-methodology). See [docs/benchmarks/](docs/benchmarks/).

## Limitations (by design)

Inference/forward DAGs only (no training or autograd); not a production scheduler (no multi-tenancy, auth or Kubernetes); crash-recovery fault model, not Byzantine. See [docs/design/000-system-design.md](docs/design/000-system-design.md#3-non-goals).

## License

[Apache-2.0](LICENSE)
