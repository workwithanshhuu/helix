# Helix 45-day tracker

Claude Code ticks a box at the end of each day (CLAUDE.md §4) after every *Done when* check in the day guide passes, and links the day log in `docs/progress/`.

Tick a box when the day's *Done when* checks (in the linked day guide) all pass. 4 hours a day: ~1 h Learn, ~3 h Build. Buffer days: 18, 28, 38. Behind by two buffers → drop days 36–37 first.

Started on: ____  ·  Target v0.5 date: ____

## Setup · days 1–2

- [ ] **Day 1** (Setup) — OrbStack + Ubuntu arm64, toolchain, repo skeleton (CMake, Go module), GitHub Actions with ASan/TSan/UBSan
    - Learn: README, ARCHITECTURE.md, SPEC.md §1
    - Done when: CI green for C++ and Go
    - Full steps: [day-guide.md](day-guide.md) (search "Day N ·")
    - Notes: repo work done and verified (see [docs/progress/day-01.md](../progress/day-01.md)); tick after the owner steps there (OrbStack setup, push, CI green).
- [ ] **Day 2** (Setup) — GoogleTest + Google Benchmark harness; io\_uring and bpftrace smoke tests; Kaggle and GCP accounts; ADRs for build system and gRPC-for-control
    - Learn: Drepper §3 (CPU caches)
    - Done when: First microbenchmark runs in CI
    - Full steps: [day-guide.md](day-guide.md) (search "Day N ·")
    - Notes: 

## M1 Low-level core · days 3–11 → v0.1

- [ ] **Day 3** (M1 Core) — SPSC ring with cached indices and 128 B padding
    - Learn: Williams ch. 5; Preshing on acquire/release
    - Done when: TSan stress clean; ops/s recorded
    - Full steps: [day-guide.md](day-guide.md) (search "Day N ·")
    - Notes: 
- [ ] **Day 4** (M1 Core) — PageSource (mmap, huge pages), size classes, central free lists
    - Learn: Bonwick, slab allocator
    - Done when: Alloc/free tests pass under ASan
    - Full steps: [day-guide.md](day-guide.md) (search "Day N ·")
    - Notes: 
- [ ] **Day 5** (M1 Core) — Per-thread caches, batch transfer, `std::pmr` adapter
    - Learn: Mimalloc paper
    - Done when: Within 1.5× of mimalloc on size-class bench
    - Full steps: [day-guide.md](day-guide.md) (search "Day N ·")
    - Notes: 
- [ ] **Day 6** (M1 Core) — Chase–Lev deque with C11 orderings
    - Learn: Chase–Lev 2005; Lê et al. 2013
    - Done when: 100 M ops, owner + 3 thieves, nothing lost or duplicated
    - Full steps: [day-guide.md](day-guide.md) (search "Day N ·")
    - Notes: 
- [ ] **Day 7** (M1 Core) — Thread pool: pinned workers, random-victim stealing, spin-then-futex parking
    - Learn: Herlihy & Shavit ch. 16
    - Done when: Fork-join fib ≥10× faster than `std::async`
    - Full steps: [day-guide.md](day-guide.md) (search "Day N ·")
    - Notes: 
- [ ] **Day 8** (M1 Core) — DAG executor with atomic dependency counters; Tensor type on the allocator
    - Learn: Blumofe & Leiserson (skim)
    - Done when: Random 10k-node DAG runs correctly
    - Full steps: [day-guide.md](day-guide.md) (search "Day N ·")
    - Notes: 
- [ ] **Day 9** (M1 Core) — SGEMM: naive, cache-blocked, NEON microkernel
    - Learn: Goto & van de Geijn
    - Done when: GFLOP/s chart vs OpenBLAS
    - Full steps: [day-guide.md](day-guide.md) (search "Day N ·")
    - Notes: 
- [ ] **Day 10** (M1 Core) — Tiled matmul as a DAG on the pool; padded per-worker counters
    - Learn: Gregg, *Systems Performance* ch. 6
    - Done when: Scaling chart, 1 to 8 threads
    - Full steps: [day-guide.md](day-guide.md) (search "Day N ·")
    - Notes: 
- [ ] **Day 11** (M1 Core) — Profile, fix one contention hotspot, write M1 design doc
    - Learn: Gregg on flame graphs
    - Done when: Tag v0.1
    - Full steps: [day-guide.md](day-guide.md) (search "Day N ·")
    - Notes: 

## M2 Network data plane · days 12–18 → v0.2

- [ ] **Day 12** (M2 Network) — liburing echo server/client; 32 B frame header + CRC32C
    - Learn: Axboe, "Efficient IO with io\_uring"
    - Done when: 64 B round trip measured
    - Full steps: [day-guide.md](day-guide.md) (search "Day N ·")
    - Notes: 
- [ ] **Day 13** (M2 Network) — Codec, request-id multiplexing, partial reads; libFuzzer target
    - Learn: Lord of the io\_uring: SQ/CQ, linked ops
    - Done when: Fuzzer 30 min clean
    - Full steps: [day-guide.md](day-guide.md) (search "Day N ·")
    - Notes: 
- [ ] **Day 14** (M2 Network) — Receive payloads straight into registered slab buffers
    - Learn: Registered buffers, buffer rings, multishot recv
    - Done when: 1 GB loopback transfer, no memcpy in perf
    - Full steps: [day-guide.md](day-guide.md) (search "Day N ·")
    - Notes: 
- [ ] **Day 15** (M2 Network) — `send_zc` above 64 KB with completion handling; credit-based flow control
    - Learn: Kernel msg\_zerocopy docs
    - Done when: Throughput vs payload-size chart
    - Full steps: [day-guide.md](day-guide.md) (search "Day N ·")
    - Notes: 
- [ ] **Day 16** (M2 Network) — Async client API with futures and deadlines; epoll fallback
    - Learn: eRPC paper (skim)
    - Done when: Two processes exchange tensors via the API
    - Full steps: [day-guide.md](day-guide.md) (search "Day N ·")
    - Notes: 
- [ ] **Day 17** (M2 Network) — Benchmark vs gRPC C++: 64 B unary, 1 MB streaming, open-loop
    - Learn: Gil Tene on coordinated omission
    - Done when: Latency CDF chart; tag v0.2
    - Full steps: [day-guide.md](day-guide.md) (search "Day N ·")
    - Notes: 
- [ ] **Day 18** (Buffer) — Catch up; ADR on io\_uring vs epoll; draft blog post 1
    - Learn: —
    - Done when: Nothing open from M1–M2
    - Full steps: [day-guide.md](day-guide.md) (search "Day N ·")
    - Notes: 

## M3 Raft control plane · days 19–28 → v0.3

- [ ] **Day 19** (M3 Raft) — Raft state, gRPC messages, election with randomized timeouts
    - Learn: Raft paper, in full
    - Done when: Leader elected in a 3-node in-process test
    - Full steps: [day-guide.md](day-guide.md) (search "Day N ·")
    - Notes: 
- [ ] **Day 20** (M3 Raft) — Simulated network (drop, delay, partition); port election tests
    - Learn: Students' Guide to Raft
    - Done when: Election tests pass 100 runs
    - Full steps: [day-guide.md](day-guide.md) (search "Day N ·")
    - Notes: 
- [ ] **Day 21** (M3 Raft) — Log replication, commit index, apply channel
    - Learn: Raft §5.3–5.4 again
    - Done when: Basic agreement tests pass
    - Full steps: [day-guide.md](day-guide.md) (search "Day N ·")
    - Notes: 
- [ ] **Day 22** (M3 Raft) — Conflicting logs, lagging followers, fast log backtracking
    - Learn: 6.5840 notes on fast backup
    - Done when: Replication tests pass 200 runs with `-race`
    - Full steps: [day-guide.md](day-guide.md) (search "Day N ·")
    - Notes: 
- [ ] **Day 23** (M3 Raft) — WAL with CRC, fsync batching, crash recovery
    - Learn: DDIA ch. 3 (logs)
    - Done when: Persistence tests pass
    - Full steps: [day-guide.md](day-guide.md) (search "Day N ·")
    - Notes: 
- [ ] **Day 24** (M3 Raft) — Snapshots, InstallSnapshot, log compaction
    - Learn: Ongaro thesis ch. 5
    - Done when: Snapshot tests pass
    - Full steps: [day-guide.md](day-guide.md) (search "Day N ·")
    - Notes: 
- [ ] **Day 25** (M3 Raft) — PreVote + CheckQuorum; metadata state machine with leases and fencing tokens
    - Learn: Thesis §9.6 (PreVote)
    - Done when: Partitioned leader steps down
    - Full steps: [day-guide.md](day-guide.md) (search "Day N ·")
    - Notes: 
- [ ] **Day 26** (M3 Raft) — Linearizability checks under random partitions
    - Learn: Porcupine README; DDIA ch. 8–9
    - Done when: 50 runs × 1,000 ops, all linearizable
    - Full steps: [day-guide.md](day-guide.md) (search "Day N ·")
    - Notes: 
- [ ] **Day 27** (M3 Raft) — helix-meta binary, worker registration and heartbeats, helixctl, 3 replicas in docker compose
    - Learn: Phi-accrual paper (skim)
    - Done when: Kill the leader: new leader in < 1 s
    - Full steps: [day-guide.md](day-guide.md) (search "Day N ·")
    - Notes: 
- [ ] **Day 28** (Buffer) — M3 design doc; ADR on Raft from scratch with WAL + snapshots instead of LSM
    - Learn: —
    - Done when: Tag v0.3
    - Full steps: [day-guide.md](day-guide.md) (search "Day N ·")
    - Notes: 

## M4 Scheduler and execution · days 29–38 → v0.4

- [ ] **Day 29** (M4 Execution) — helixd worker: registers, takes task leases, runs them on the M1 pool
    - Learn: Ray paper §4
    - Done when: CLI-submitted task returns a result
    - Full steps: [day-guide.md](day-guide.md) (search "Day N ·")
    - Notes: 
- [ ] **Day 30** (M4 Execution) — mmap object store: extents, put/seal/get, refcounts, LRU eviction
    - Learn: Plasma / Ray object store design
    - Done when: Store tests + put/get benchmark
    - Full steps: [day-guide.md](day-guide.md) (search "Day N ·")
    - Notes: 
- [ ] **Day 31** (M4 Execution) — Remote fetch over M2 straight into store extents; object directory in helix-meta
    - Learn: —
    - Done when: Node B consumes an object made on node A
    - Full steps: [day-guide.md](day-guide.md) (search "Day N ·")
    - Notes: 
- [ ] **Day 32** (M4 Execution) — Global scheduler: DAG submission, locality + load scoring
    - Learn: Borg paper §3; power of two choices
    - Done when: Tiled matmul DAG runs across 3 workers
    - Full steps: [day-guide.md](day-guide.md) (search "Day N ·")
    - Notes: 
- [ ] **Day 33** (M4 Execution) — Spillback when a worker's queue passes a threshold
    - Learn: Sparrow paper (skim)
    - Done when: Imbalance chart, before vs after
    - Full steps: [day-guide.md](day-guide.md) (search "Day N ·")
    - Notes: 
- [ ] **Day 34** (M4 Execution) — Lease expiry, fencing check on seal, re-execution, lineage rebuild
    - Learn: RDD paper, lineage section
    - Done when: kill -9 mid-job, job still completes
    - Full steps: [day-guide.md](day-guide.md) (search "Day N ·")
    - Notes: 
- [ ] **Day 35** (M4 Execution) — Chaos script: random kills and `tc netem` partitions; checksum results
    - Learn: One Jepsen analysis
    - Done when: 20 chaos runs, all correct
    - Full steps: [day-guide.md](day-guide.md) (search "Day N ·")
    - Notes: 
- [ ] **Day 36** (M4 GPU) — Kaggle notebook: naive and tiled CUDA SGEMM vs cuBLAS on T4
    - Learn: PMPP ch. 2–5
    - Done when: GFLOP/s chart in `docs/benchmarks`
    - Full steps: [day-guide.md](day-guide.md) (search "Day N ·")
    - Notes: 
- [ ] **Day 37** (M4 Execution) — Request-batching queue in front of a transformer-block DAG (matmul, softmax, layernorm)
    - Learn: Orca paper (skim)
    - Done when: Throughput vs batch-size chart
    - Full steps: [day-guide.md](day-guide.md) (search "Day N ·")
    - Notes: 
- [ ] **Day 38** (Buffer) — M4 design doc; ADRs on lineage vs checkpointing and two-level scheduling
    - Learn: —
    - Done when: Tag v0.4
    - Full steps: [day-guide.md](day-guide.md) (search "Day N ·")
    - Notes: 

## M5 Observability and benchmarks · days 39–45 → v0.5

- [ ] **Day 39** (M5 Observability) — Per-thread HDR histograms and counters; Prometheus endpoints
    - Learn: "The Tail at Scale"
    - Done when: Live metrics in Prometheus via compose
    - Full steps: [day-guide.md](day-guide.md) (search "Day N ·")
    - Notes: 
- [ ] **Day 40** (M5 Observability) — Trace ids in frame headers; flight recorder to Perfetto JSON
    - Learn: Dapper paper (skim)
    - Done when: kill -9 recovery visible in Perfetto
    - Full steps: [day-guide.md](day-guide.md) (search "Day N ·")
    - Notes: 
- [ ] **Day 41** (M5 Observability) — Open-loop load generator; runqlat and offcputime scripts
    - Learn: wrk2 README; bpftrace one-liners
    - Done when: Latency vs throughput curve
    - Full steps: [day-guide.md](day-guide.md) (search "Day N ·")
    - Notes: 
- [ ] **Day 42** (M5 Benchmarks) — Cloud day 1: NUMA run of M1 with perf c2c; Helix RPC vs gRPC across 2 VMs
    - Learn: Hoefler & Belli (skim)
    - Done when: Raw CSVs saved; VMs destroyed
    - Full steps: [day-guide.md](day-guide.md) (search "Day N ·")
    - Notes: 
- [ ] **Day 43** (M5 Benchmarks) — Cloud day 2: Helix vs Ray task throughput and DAG latency
    - Learn: —
    - Done when: Charts generated by script; VMs destroyed
    - Full steps: [day-guide.md](day-guide.md) (search "Day N ·")
    - Notes: 
- [ ] **Day 44** (M5 Docs) — README (diagram + 3 charts), ARCHITECTURE.md, benchmark report, 2 postmortems
    - Learn: —
    - Done when: A stranger can run the quickstart
    - Full steps: [day-guide.md](day-guide.md) (search "Day N ·")
    - Notes: 
- [ ] **Day 45** (Release) — Tag v0.5; 3-minute kill -9 demo video; blog post; resume bullets; file stretch issues
    - Learn: —
    - Done when: v0.5 public
    - Full steps: [day-guide.md](day-guide.md) (search "Day N ·")
    - Notes:
