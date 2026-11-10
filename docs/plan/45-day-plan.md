# The 45-day plan

Helix reaches v0.5 on day 45 at 4 hours a day (180 hours), still covering all four domains, for ₹0 of cloud spend on free credits or about ₹1,000–1,300 if you have to pay. Section 3 stays as the full-scope reference; this section decides what actually gets built.

### Scope: what's in, what waits

| Area | In the 45 days | Stretch, after day 45 |
| --- | --- | --- |
| Memory and lock-free (C++) | Slab allocator with per-thread caches and huge pages; SPSC ring; Chase–Lev deque; work-stealing pool; DAG executor | Vyukov MPMC queue, epoch reclamation, model checking |
| Network | io\_uring TCP data plane: registered buffers, `send_zc`, flow control, fuzzed framing. Control traffic uses gRPC | Shared-memory transport, RDMA, Go port of Helix RPC |
| Control plane (Go) | Raft from scratch: election, replication, WAL, snapshots, PreVote; Porcupine tests; leases with fencing tokens | LSM-tree state machine, ReadIndex, membership changes, SWIM |
| Execution | Global scheduler with locality scoring; spillback balancing; mmap object store with remote fetch; kill -9 recovery via re-execution and lineage | Peer-to-peer stealing, NVMe spill, paged KV cache, pipeline-parallel LLM |
| GPU | Tiled CUDA SGEMM vs cuBLAS on Kaggle's free T4 | CUDA executor backend inside Helix |
| Observability | Per-thread HDR histograms, Prometheus, Perfetto traces, open-loop load generator, benchmarks vs gRPC and Ray | Redis and etcd comparisons |

The biggest time saver: control-plane messages use gRPC, and the custom io\_uring transport carries only tensor bytes, where zero-copy actually matters. That removes the Go port of Helix RPC, about 5 days.

### Budget

| Item | Where | Cost |
| --- | --- | --- |
| Daily development, 5-node cluster | Mac + OrbStack | Free |
| CUDA learning and SGEMM benchmark (day 36) | Kaggle notebooks (free weekly GPU quota); Google Colab as backup | Free |
| Benchmark machines, \~8 h on days 42–43 | GCP free trial: $300 credit for 90 days | Free. The trial blocks GPUs and quota increases; if the 2-socket VM exceeds the trial's vCPU cap, upgrade to a paid account, which keeps the credit |
| Fallback for benchmarks | AWS spot: one 2-socket x86 VM \~4 h + three small VMs \~6 h; new AWS accounts also get $100–200 credit | About $12–15 (₹1,000–1,300) |
| Fallback GPU | RunPod L4 at $0.59/hr, \~5 h | About $3 (₹250) |

Sign up for GCP on day 2 but start nothing until day 42: the 90-day clock starts at sign-up, and set a budget alert at $5 either way. Sources: [GCP free trial](https://docs.cloud.google.com/free/docs/free-cloud-features), [AWS free tier credits](https://aws.amazon.com/blogs/aws/aws-free-tier-update-new-customers-can-get-started-and-explore-aws-with-up-to-200-in-credits), [RunPod pricing](https://www.runpod.io/gpu-cloud/pricing).

### Day by day

Each day: about 1 hour on the Learn column, 3 hours building, then commit and set the Status. Buffer days 18, 28 and 38 absorb slips. If you burn two buffers, drop days 36–37 (GPU and batching) first; never drop the day 42–43 benchmarks.

This table is the tracker. The step-by-step instructions for each day (readings, ordered build steps, files, tests, pitfalls, done-when checks and self-check questions) are in the [Day guide](day-guide.md).

| Day | Phase | Learn (\~1 h) | Build (\~3 h) | Done when | Status |
| --- | --- | --- | --- | --- | --- |
| 1 | Setup | Sections 1–3 of this doc | OrbStack + Ubuntu arm64, toolchain, repo skeleton (CMake, Go module), GitHub Actions with ASan/TSan/UBSan | CI green for C++ and Go | Not started |
| 2 | Setup | Drepper §3 (CPU caches) | GoogleTest + Google Benchmark harness; io\_uring and bpftrace smoke tests; Kaggle and GCP accounts; ADRs for build system and gRPC-for-control | First microbenchmark runs in CI | Not started |
| 3 | M1 Core | Williams ch. 5; Preshing on acquire/release | SPSC ring with cached indices and 128 B padding | TSan stress clean; ops/s recorded | Not started |
| 4 | M1 Core | Bonwick, slab allocator | PageSource (mmap, huge pages), size classes, central free lists | Alloc/free tests pass under ASan | Not started |
| 5 | M1 Core | Mimalloc paper | Per-thread caches, batch transfer, `std::pmr` adapter | Within 1.5× of mimalloc on size-class bench | Not started |
| 6 | M1 Core | Chase–Lev 2005; Lê et al. 2013 | Chase–Lev deque with C11 orderings | 100 M ops, owner + 3 thieves, nothing lost or duplicated | Not started |
| 7 | M1 Core | Herlihy & Shavit ch. 16 | Thread pool: pinned workers, random-victim stealing, spin-then-futex parking | Fork-join fib ≥10× faster than `std::async` | Not started |
| 8 | M1 Core | Blumofe & Leiserson (skim) | DAG executor with atomic dependency counters; Tensor type on the allocator | Random 10k-node DAG runs correctly | Not started |
| 9 | M1 Core | Goto & van de Geijn | SGEMM: naive, cache-blocked, NEON microkernel | GFLOP/s chart vs OpenBLAS | Not started |
| 10 | M1 Core | Gregg, *Systems Performance* ch. 6 | Tiled matmul as a DAG on the pool; padded per-worker counters | Scaling chart, 1 to 8 threads | Not started |
| 11 | M1 Core | Gregg on flame graphs | Profile, fix one contention hotspot, write M1 design doc | Tag v0.1 | Not started |
| 12 | M2 Network | Axboe, "Efficient IO with io\_uring" | liburing echo server/client; 32 B frame header + CRC32C | 64 B round trip measured | Not started |
| 13 | M2 Network | Lord of the io\_uring: SQ/CQ, linked ops | Codec, request-id multiplexing, partial reads; libFuzzer target | Fuzzer 30 min clean | Not started |
| 14 | M2 Network | Registered buffers, buffer rings, multishot recv | Receive payloads straight into registered slab buffers | 1 GB loopback transfer, no memcpy in perf | Not started |
| 15 | M2 Network | Kernel msg\_zerocopy docs | `send_zc` above 64 KB with completion handling; credit-based flow control | Throughput vs payload-size chart | Not started |
| 16 | M2 Network | eRPC paper (skim) | Async client API with futures and deadlines; epoll fallback | Two processes exchange tensors via the API | Not started |
| 17 | M2 Network | Gil Tene on coordinated omission | Benchmark vs gRPC C++: 64 B unary, 1 MB streaming, open-loop | Latency CDF chart; tag v0.2 | Not started |
| 18 | Buffer | — | Catch up; ADR on io\_uring vs epoll; draft blog post 1 | Nothing open from M1–M2 | Not started |
| 19 | M3 Raft | Raft paper, in full | Raft state, gRPC messages, election with randomized timeouts | Leader elected in a 3-node in-process test | Not started |
| 20 | M3 Raft | Students' Guide to Raft | Simulated network (drop, delay, partition); port election tests | Election tests pass 100 runs | Not started |
| 21 | M3 Raft | Raft §5.3–5.4 again | Log replication, commit index, apply channel | Basic agreement tests pass | Not started |
| 22 | M3 Raft | 6.5840 notes on fast backup | Conflicting logs, lagging followers, fast log backtracking | Replication tests pass 200 runs with `-race` | Not started |
| 23 | M3 Raft | DDIA ch. 3 (logs) | WAL with CRC, fsync batching, crash recovery | Persistence tests pass | Not started |
| 24 | M3 Raft | Ongaro thesis ch. 5 | Snapshots, InstallSnapshot, log compaction | Snapshot tests pass | Not started |
| 25 | M3 Raft | Thesis §9.6 (PreVote) | PreVote + CheckQuorum; metadata state machine with leases and fencing tokens | Partitioned leader steps down | Not started |
| 26 | M3 Raft | Porcupine README; DDIA ch. 8–9 | Linearizability checks under random partitions | 50 runs × 1,000 ops, all linearizable | Not started |
| 27 | M3 Raft | Phi-accrual paper (skim) | helix-meta binary, worker registration and heartbeats, helixctl, 3 replicas in docker compose | Kill the leader: new leader in < 1 s | Not started |
| 28 | Buffer | — | M3 design doc; ADR on Raft from scratch with WAL + snapshots instead of LSM | Tag v0.3 | Not started |
| 29 | M4 Execution | Ray paper §4 | helixd worker: registers, takes task leases, runs them on the M1 pool | CLI-submitted task returns a result | Not started |
| 30 | M4 Execution | Plasma / Ray object store design | mmap object store: extents, put/seal/get, refcounts, LRU eviction | Store tests + put/get benchmark | Not started |
| 31 | M4 Execution | — | Remote fetch over M2 straight into store extents; object directory in helix-meta | Node B consumes an object made on node A | Not started |
| 32 | M4 Execution | Borg paper §3; power of two choices | Global scheduler: DAG submission, locality + load scoring | Tiled matmul DAG runs across 3 workers | Not started |
| 33 | M4 Execution | Sparrow paper (skim) | Spillback when a worker's queue passes a threshold | Imbalance chart, before vs after | Not started |
| 34 | M4 Execution | RDD paper, lineage section | Lease expiry, fencing check on seal, re-execution, lineage rebuild | kill -9 mid-job, job still completes | Not started |
| 35 | M4 Execution | One Jepsen analysis | Chaos script: random kills and `tc netem` partitions; checksum results | 20 chaos runs, all correct | Not started |
| 36 | M4 GPU | PMPP ch. 2–5 | Kaggle notebook: naive and tiled CUDA SGEMM vs cuBLAS on T4 | GFLOP/s chart in `docs/benchmarks` | Not started |
| 37 | M4 Execution | Orca paper (skim) | Request-batching queue in front of a transformer-block DAG (matmul, softmax, layernorm) | Throughput vs batch-size chart | Not started |
| 38 | Buffer | — | M4 design doc; ADRs on lineage vs checkpointing and two-level scheduling | Tag v0.4 | Not started |
| 39 | M5 Observability | "The Tail at Scale" | Per-thread HDR histograms and counters; Prometheus endpoints | Live metrics in Prometheus via compose | Not started |
| 40 | M5 Observability | Dapper paper (skim) | Trace ids in frame headers; flight recorder to Perfetto JSON | kill -9 recovery visible in Perfetto | Not started |
| 41 | M5 Observability | wrk2 README; bpftrace one-liners | Open-loop load generator; runqlat and offcputime scripts | Latency vs throughput curve | Not started |
| 42 | M5 Benchmarks | Hoefler & Belli (skim) | Cloud day 1: NUMA run of M1 with perf c2c; Helix RPC vs gRPC across 2 VMs | Raw CSVs saved; VMs destroyed | Not started |
| 43 | M5 Benchmarks | — | Cloud day 2: Helix vs Ray task throughput and DAG latency | Charts generated by script; VMs destroyed | Not started |
| 44 | M5 Docs | — | README (diagram + 3 charts), ARCHITECTURE.md, benchmark report, 2 postmortems | A stranger can run the quickstart | Not started |
| 45 | Release | — | Tag v0.5; 3-minute kill -9 demo video; blog post; resume bullets; file stretch issues | v0.5 public | Not started |
