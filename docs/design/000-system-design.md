# Design doc 000: Helix system design

| Field | Value |
| --- | --- |
| Status | **Accepted** (day 1); revised at each milestone end |
| Author | Helix maintainers |
| Created | 2026-11-10 |
| Scope | Whole system; milestone details in m1–m5 docs |
| Related | [SPEC.md](../../SPEC.md), [ARCHITECTURE.md](../../ARCHITECTURE.md), [ADRs](../adr/) |

## 1. Summary

Helix executes DAGs of tensor tasks across a small cluster. A Raft-replicated Go control plane owns all metadata and decides placement; C++ workers own all compute and tensor bytes and move them peer-to-peer with zero-copy io_uring transport. Fault tolerance comes from leases with fencing tokens plus lineage-based recomputation. The project's purpose is to demonstrate, with measurements, mastery of four systems areas at once: low-level concurrency and memory management, consensus and replication, a runtime scheduler, and memory-mapped storage.

## 2. Goals

| # | Goal | Measured by | Target (45-day scope) |
| --- | --- | --- | --- |
| G1 | Fast single-node execution | Empty-task throughput; fork-join speed-up | ≥ 10× `std::async` on fib(30); near-linear 1→8 threads on tiled matmul |
| G2 | Zero-copy data plane | `perf` flame graph; GB/s | No `memcpy` in Helix frames; ≥ 90% of loopback/NIC bandwidth |
| G3 | Low tail latency for small RPCs | p99 / p99.9 at fixed load, open-loop | p99 lower than gRPC C++ async at equal load |
| G4 | Linearizable, durable metadata | Porcupine over randomized histories with partitions and crashes | 50 seeds × 1,000 ops, all linearizable; leader failover < 1 s |
| G5 | Jobs survive worker failure | `kill -9` / `SIGSTOP` during jobs | 20/20 chaos runs complete with correct checksums |
| G6 | Balanced under skew | max/mean queue depth | < 1.3 within 2 s with spillback |
| G7 | Observable and reproducible | Metrics, traces, `make bench` artefacts | Every published number reproducible from raw data |

## 3. Non-goals

- Training, autograd or gradient communication (inference/forward DAGs only).
- Competitive hand-written GEMM: one learning kernel per ISA, then OpenBLAS/cuBLAS for real runs.
- Multi-tenancy, authentication, authorization, encryption, Kubernetes integration.
- Byzantine fault tolerance; geo-distribution.
- Dynamic Raft membership changes, LSM state machine, RDMA, shared-memory transport, CUDA executor backend: **stretch goals after day 45** ([plan](../plan/45-day-plan.md)).

## 4. Background and prior art

| System | What Helix borrows | What Helix does differently |
| --- | --- | --- |
| Ray (OSDI 2018), Ray ownership (NSDI 2021) | Two-level scheduling; immutable object store; lineage recovery | Metadata in its own Raft group instead of a GCS on Redis; C++ end to end on the data path |
| Plasma (Arrow) | Sealed, refcounted shared-memory objects | Objects addressed by producer identity (lineage implicit in the ID) |
| Borg (EuroSys 2015), Sparrow (SOSP 2013) | Feasibility + scoring; power-of-two choices; late binding / spillback | Tiny scale; locality-first scoring |
| Raft (ATC 2014), etcd/raft | Consensus, PreVote, ReadIndex, snapshots | Written from scratch for learning; tested with a deterministic simulator and Porcupine |
| eRPC (NSDI 2019), Seastar | Thread-per-core I/O, no locks on the hot path | io_uring with registered buffers and `send_zc` instead of DPDK |
| tcmalloc, mimalloc | Size classes, per-thread caches, batch transfer | NUMA-aware page source sized for tensors |

## 5. Architecture

See [ARCHITECTURE.md](../../ARCHITECTURE.md) for the component picture and request lifecycle. The rest of this section records the **key design decisions** and their alternatives.

### 5.1 Split control plane and data plane

**Decision.** Metadata (who runs what, where objects live) goes through a Raft-replicated Go service; tensor bytes go worker-to-worker and never through the control plane.

**Why.** Control traffic is small, needs strong consistency and benefits from Go's productivity and gRPC. Data traffic is large, needs zero copies and tight memory control, which C++ gives. Mixing them would make the consensus log carry gigabytes or make the data path pay for consensus.

**Alternatives.** (a) Single binary, single language: simpler deployment, but either Go on the data path (GC pauses, no registered buffers) or C++ Raft (slower to build, less learning breadth). (b) Gossip-based metadata (eventual consistency): cannot give exactly-one-winner semantics for task completion.

### 5.2 Two-level scheduling

**Decision.** The leader assigns tasks to nodes (global placement); each node's work-stealing pool decides order and core (local scheduling). Overloaded nodes refuse leases (spillback).

**Why.** A central scheduler that also picks cores would put the control plane on the per-task hot path (≈ millions of decisions/s). Local work stealing is provably efficient and keeps caches warm.

**Alternatives.** Fully decentralized (Sparrow-style) placement: lower latency, but no global view for locality and lineage. Fully centralized (per-core): simplest reasoning, does not scale.

### 5.3 Leases with fencing tokens

**Decision.** A task is owned through a lease that expires after `lease.ttl_ms`; the lease carries a fencing token equal to the Raft index of its `GrantLease` command. Completions and object seals carry the token; anything older than the current token is rejected.

**Why.** Timeouts alone cannot prevent split brain: a paused worker resumes believing it still owns the task. Fencing makes stale writers harmless without trusting clocks.

**Alternatives.** Distributed locks without fencing (unsafe); idempotent tasks without ownership (wastes work, still needs a single committed result).

### 5.4 Lineage instead of checkpointing

**Decision.** Object IDs encode their producer (job, task, output index). A lost object is rebuilt by re-running its producer, recursively.

**Why.** Inference DAG tasks are deterministic and cheap relative to the cost of synchronously replicating every intermediate tensor.

**Alternatives.** Replicating objects (RF=2): doubles network and memory; checkpointing to disk: adds latency to every task. Both are revisited if tasks become expensive or non-deterministic.

### 5.5 Custom data-plane transport

**Decision.** A 32-byte framed protocol over io_uring TCP with registered buffers, multishot receive, `send_zc` and credit-based flow control ([ADR-0002](../adr/0002-grpc-for-control-plane-custom-data-plane.md)).

**Why.** gRPC/HTTP2 adds framing, protobuf encoding and copies that dominate for large tensors and small latency-critical messages; owning the transport is also a core learning goal.

### 5.6 Durable metadata: WAL + snapshots

**Decision.** Raft's log is a segmented WAL with CRC32C records and group commit; the state machine is snapshotted every 10,000 entries with the tmp → fsync → rename pattern.

**Alternatives.** LSM-tree state machine (stretch goal); bbolt B-tree. Both add a second storage layer the 45-day scope does not need.

## 6. Data model

All authoritative state is in the meta state machine: tables `nodes`, `jobs`, `tasks`, `leases`, `objects`, `dedup` ([docs/db/metadata-schema.md](../db/metadata-schema.md)). Workers hold only leases and bytes. IDs: `JobId` = Raft index of `SubmitJob`; `ObjectId` = (JobId, task index, output index); `FencingToken` = Raft index of `GrantLease`.

## 7. Consistency model

| Data | Guarantee | How |
| --- | --- | --- |
| Metadata writes | Linearizable | Raft commit before reply |
| Metadata reads | Linearizable | ReadIndex (leader confirms leadership, waits for apply) |
| Task completion | Exactly one committed result per task | Fencing token check inside `Apply` |
| Objects | Immutable after seal; any replica is equivalent | Seal + producer identity in ID |
| Job submission | Exactly once per `request_id` | Dedup table in the state machine |

During a partition the minority side cannot commit (consistency over availability).

## 8. Failure model and handling

Crash-recovery nodes, omission-faulty network (loss, delay, duplication, reordering, partitions), process pauses. Not Byzantine. Every scenario, its detection, recovery and test is listed in [SPEC.md §6](../../SPEC.md#6-failure-scenarios).

## 9. Performance model (back of the envelope)

- **Scheduler**: control-plane cost per task ≈ one Raft entry (~200 B) batched 256 per fsync. At 1 ms per fsync on the Mac VM, ~256k task state changes/s upper bound before batching limits; real target ~10k–100k tasks/s cluster-wide, with local work stealing handling sub-task parallelism.
- **Data plane**: a 4096×4096 f32 matrix is 64 MiB; at 10 Gbit/s ≈ 54 ms to move. Locality-aware placement exists because moving tensors costs as much as computing on them.
- **Single node**: an SPSC handoff costs a cache-line transfer (~40–100 ns) when the ring is not batched; Helix batches via cached indices.

(These are planning estimates; measured numbers replace them in the milestone docs.)

## 10. Observability

Per-thread HDR histograms and counters (no shared atomics on hot paths), Prometheus endpoints, trace context propagated through gRPC metadata, leases and frame headers, and a per-thread flight recorder dumped as Perfetto JSON. Catalog: [SPEC.md §8](../../SPEC.md#8-metrics-and-tracing-catalog).

## 11. Testing strategy

Unit → randomized vs reference model → TSan stress (also on arm64) → ASan/UBSan → fuzzing → deterministic Raft simulation → Porcupine linearizability → docker-compose integration → chaos with checksums → benchmark regression. Details: [SPEC.md §9](../../SPEC.md#9-testing-strategy).

## 12. Security

None by design beyond input validation and fuzzing; see [SECURITY.md](../../SECURITY.md).

## 13. Risks

| Risk | Likelihood | Mitigation |
| --- | --- | --- |
| Schedule slip (180 h budget) | High | Buffer days 18/28/38; days 36–37 droppable; scope table in the plan |
| Raft correctness bugs | High | Simulator with seeds, Porcupine, 200-run repetitions |
| Lock-free bugs hidden on x86 | Medium | arm64 dev machine and CI; mutation tests on orderings |
| io_uring/eBPF restricted in OrbStack kernel | Medium | Day-2 smoke test; fall back to UTM with stock kernel |
| Benchmarks not representative in a VM | High | Publish only cloud numbers (days 42–43) |

## 14. Milestones

| Milestone | Days | Design doc |
| --- | --- | --- |
| M1 low-level core | 3–11 | [m1-core.md](m1-core.md) |
| M2 data plane | 12–18 | [m2-rpc.md](m2-rpc.md) |
| M3 control plane | 19–28 | [m3-control-plane.md](m3-control-plane.md) |
| M4 execution | 29–38 | [m4-execution.md](m4-execution.md) |
| M5 observability & benchmarks | 39–45 | [m5-observability.md](m5-observability.md) |

## 15. Open questions

1. Lease TTL 5 s vs faster recovery: revisit after measuring false expiries on day 34.
2. Whether the object directory should move out of Raft (too many writes?) once measured on day 32.
3. Whether to shard the scheduler by job for the stretch roadmap.
