# Reading list

Study just-in-time: read the starred items in the week before each milestone, and keep the rest as reference. Roughly 25% of each week goes to reading, 75% to building.

### Foundations (week 0, ongoing)

| Resource | Type | What to take from it |
| --- | --- | --- |
| ★ *Computer Systems: A Programmer's Perspective* (Bryant & O'Hallaron), ch. 6, 9 | Book | Cache hierarchy, virtual memory, TLBs |
| ★ Ulrich Drepper, *What Every Programmer Should Know About Memory* | Paper | NUMA, cache lines, prefetching, TLB costs |
| ★ Brendan Gregg, *Systems Performance* (2nd ed.) | Book | USE method, `perf`, flame graphs, off-CPU analysis |
| Denis Bakhvalov, *Performance Analysis and Tuning on Modern CPUs* | Book (free) | Top-down microarchitecture analysis, PMU counters |
| Agner Fog, optimization manuals + instruction tables | Reference | Instruction latencies, SIMD costs |
| Your CS-6210 AOS material | Course | Scheduling, synchronization, distributed systems papers |

### Milestone 1 — memory, lock-free, scheduling

| Resource | Type | What to take from it |
| --- | --- | --- |
| ★ Herlihy & Shavit, *The Art of Multiprocessor Programming* (2nd ed.), ch. 3, 7, 10, 16 | Book | Linearizability, spin locks, queues, work stealing |
| ★ Anthony Williams, *C++ Concurrency in Action* (2nd ed.), ch. 5–7 | Book | C++ memory model, acquire/release, lock-free design |
| ★ Paul McKenney, *Is Parallel Programming Hard, And, If So, What Can You Do About It?* | Book (free) | Memory barriers, RCU, per-CPU counters |
| Jeff Preshing's blog (preshing.com): acquire/release, lock-free series | Blog | Intuition for memory ordering |
| Dmitry Vyukov, 1024cores.net: bounded MPMC queue | Blog | Optional upgrade for the pool's injection queue; classic interview design |
| Chase & Lev, "Dynamic Circular Work-Stealing Deque" (SPAA 2005) | Paper | The deque |
| Lê, Pop, Cohen, Zappa Nardelli, "Correct and Efficient Work-Stealing for Weak Memory Models" (PPoPP 2013) | Paper | The correct C11 orderings for Chase–Lev |
| Blumofe & Leiserson, "Scheduling Multithreaded Computations by Work Stealing" (1999) | Paper | Why work stealing is provably good |
| ★ Leijen et al., "Mimalloc: Free List Sharding in Action" (2019) | Paper | Modern allocator design |
| TCMalloc design doc (google.github.io/tcmalloc) | Docs | Per-CPU caches, size classes, transfer caches |
| Bonwick, "The Slab Allocator" (USENIX 1994) | Paper | Slab caches, object coloring |
| Fraser, "Practical Lock-Freedom" (PhD thesis, ch. 5) / Michael, "Hazard Pointers" (2004) | Paper | Safe memory reclamation |
| Codebases: `folly` (MPMCQueue, ProducerConsumerQueue), `moodycamel::ConcurrentQueue`, oneTBB scheduler, `taskflow` | Code | Production versions to compare against |
| Goto & van de Geijn, "Anatomy of High-Performance Matrix Multiplication" (2008) | Paper | Blocking for your SGEMM kernel |

### Milestone 2 — networking, io\_uring, serialization

| Resource | Type | What to take from it |
| --- | --- | --- |
| ★ Jens Axboe, "Efficient IO with io\_uring" (kernel.dk/io\_uring.pdf) | Paper | SQ/CQ design, registered buffers, SQPOLL |
| ★ Lord of the io\_uring (unixism.net/loti) + `liburing` examples and man pages | Tutorial | Practical API; multishot recv, buffer rings, `send_zc` |
| W. Richard Stevens, *UNIX Network Programming* vol. 1 | Book | Sockets, Nagle, TCP\_NODELAY, backpressure |
| Kernel docs: `Documentation/networking/msg_zerocopy.rst` | Docs | Zero-copy send semantics and completion |
| ★ Kalia, Kaminsky, Andersen, "Datacenter RPCs can be General and Fast" (eRPC, NSDI 2019) | Paper | How fast RPC is designed |
| Ousterhout et al., "The Case for RAMCloud" / Homa transport papers | Paper | Tail latency in datacenter RPC |
| FlatBuffers and Cap'n Proto docs ("encoding" pages) | Docs | Zero-parse serialization |
| gRPC C++ async + HTTP/2 flow-control docs | Docs | What you are benchmarking against |
| Seastar framework (seastar.io) and its tutorial | Code | Shared-nothing, thread-per-core networking |
| rdma-core + SoftRoCE (`rxe`) docs (stretch) | Docs | RDMA verbs without hardware |

### Milestone 3 — consensus, storage engine

| Resource | Type | What to take from it |
| --- | --- | --- |
| ★ Ongaro & Ousterhout, "In Search of an Understandable Consensus Algorithm" (Raft, 2014) | Paper | The algorithm; Figure 2 is your spec |
| ★ Diego Ongaro's PhD thesis, ch. 3, 4, 6, 9 | Thesis | Membership change, PreVote, ReadIndex, leases |
| ★ MIT 6.5840 (formerly 6.824) Distributed Systems — labs 3 & 4 + student's guide to Raft | Course | Tests to port; common bugs |
| raft.github.io visualization | Tool | Build intuition for elections |
| ★ Martin Kleppmann, *Designing Data-Intensive Applications*, ch. 3, 5, 8, 9 | Book | LSM vs B-tree, replication, fencing tokens, linearizability |
| Codebases: `etcd-io/raft`, `hashicorp/raft`, TiKV raft-rs | Code | How production Raft batches and pipelines |
| O'Neil et al., "The Log-Structured Merge-Tree" (1996) | Paper | The original LSM |
| ★ Alex Petrov, *Database Internals*, part I (storage) + part II (distributed) | Book | SSTables, compaction, WAL, failure detectors |
| RocksDB wiki (compaction, Bloom filters) + Pebble source | Docs/Code | Leveled compaction, write amplification |
| Hayashibara et al., "The φ Accrual Failure Detector" (2004) | Paper | Failure detection |
| Das et al., "SWIM" (2002) + `hashicorp/memberlist` | Paper/Code | Gossip membership |
| Aphyr's Jepsen analyses (jepsen.io) + `anishathalye/porcupine` | Blog/Tool | Linearizability testing |
| Alagappan et al., "Protocol-Aware Recovery for Consensus-Based Storage" (FAST 2018) | Paper | What happens when Raft's disk lies |

### Milestone 4 — scheduling, object store, inference

| Resource | Type | What to take from it |
| --- | --- | --- |
| ★ Moritz et al., "Ray: A Distributed Framework for Emerging AI Applications" (OSDI 2018) | Paper | Two-level scheduling, object store, lineage |
| Wang et al., "Ownership: A Distributed Futures System for Fine-Grained Tasks" (NSDI 2021) | Paper | Ray's revised fault-tolerance model |
| ★ Verma et al., "Large-scale cluster management at Google with Borg" (EuroSys 2015) | Paper | Placement scoring, priorities, cells |
| Ousterhout et al., "Sparrow" (SOSP 2013); Mitzenmacher, "The Power of Two Choices" | Paper | Low-latency distributed scheduling |
| Zaharia et al., "Resilient Distributed Datasets" (NSDI 2012) | Paper | Lineage-based recovery |
| Apache Arrow Plasma docs / Ray object store source (`src/ray/object_manager`) | Code | Shared-memory immutable object store |
| ★ Kwon et al., "Efficient Memory Management for LLM Serving with PagedAttention" (vLLM, SOSP 2023) | Paper | KV-cache paging, continuous batching |
| Yu et al., "Orca: A Distributed Serving System for Transformer-Based Generative Models" (OSDI 2022) | Paper | Iteration-level scheduling |
| Huang et al., "GPipe" and Narayanan et al., "PipeDream" | Paper | Pipeline parallelism, bubbles |
| Shoeybi et al., "Megatron-LM" | Paper | Tensor parallelism (stretch) |
| Karpathy, `llm.c` / `llama2.c` | Code | A minimal transformer forward pass to distribute |
| NVIDIA CUDA C++ Programming Guide: streams, events, pinned memory, unified memory | Docs | Optional GPU backend |
| Kirk & Hwu, *Programming Massively Parallel Processors* (4th ed.) | Book | GPU execution model |

### Milestone 5 — observability, benchmarking

| Resource | Type | What to take from it |
| --- | --- | --- |
| ★ Dean & Barroso, "The Tail at Scale" (CACM 2013) | Paper | Why p99 dominates; hedged requests |
| ★ Gil Tene, "How NOT to Measure Latency" (talk) + HdrHistogram + wrk2 README | Talk/Tool | Coordinated omission, open-loop load |
| Sigelman et al., "Dapper" (2010) | Paper | Distributed tracing design |
| Brendan Gregg, *BPF Performance Tools* + bpftrace reference | Book | eBPF tracing for run-queue and off-CPU |
| Perfetto trace format docs | Docs | Flight-recorder output format |
| Google Benchmark + `perf stat`/`perf c2c` docs | Tool | Microbenchmarks and false-sharing detection |
| Hoefler & Belli, "Scientific Benchmarking of Parallel Computing Systems" (SC 2015) | Paper | Reporting benchmarks you can defend |
