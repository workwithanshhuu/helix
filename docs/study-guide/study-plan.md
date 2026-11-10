# Week-by-week study plan

Aligned with [docs/plan/45-day-plan.md](../plan/45-day-plan.md). ★ items are in [reading-list.md](reading-list.md).

| Week | Days | Build | Master these concept docs | Read (★ first) | Self-check |
| --- | --- | --- | --- | --- | --- |
| 1 | 1–7 | Environment, CI, benchmark harness, SPSC ring, slab allocator (2 days), Chase–Lev deque, thread pool | [build-and-sanitizers](../concepts/build-and-sanitizers.md), [hardware-and-caches](../concepts/hardware-and-caches.md), [memory-ordering](../concepts/memory-ordering-and-atomics.md), [lock-free](../concepts/lock-free-structures.md) | ★ Drepper §3–6; ★ Williams ch. 5; Preshing acquire/release; Chase–Lev + Lê et al. | Derive SPSC push/pop orderings on paper |
| 2 | 8–14 | DAG executor + Tensor, SGEMM, tiled matmul DAG, profiling + v0.1; io_uring echo + frame header, codec + fuzzing, registered buffers | [allocators](../concepts/virtual-memory-and-allocators.md), [work-stealing](../concepts/work-stealing-scheduling.md), [io_uring](../concepts/io-uring-and-zero-copy.md) | ★ Mimalloc paper; Blumofe & Leiserson; Goto & van de Geijn; ★ Axboe io_uring | Explain T₁/P + O(T∞); explain `send_zc` lifetime |
| 3 | 15–21 | `send_zc` + credits, client API + epoll fallback, gRPC benchmark + v0.2, buffer day; Raft election, simulated network, log replication | [raft](../concepts/raft-consensus.md) | ★ eRPC; ★ Raft paper; ★ Students' Guide to Raft | Draw Figure 8 from memory |
| 4 | 22–28 | Hard replication cases, WAL, snapshots, PreVote/CheckQuorum + state machine, Porcupine, helix-meta service, buffer + v0.3 | [WAL](../concepts/wal-snapshots-durability.md), [linearizability](../concepts/linearizability-and-testing.md) | ★ Ongaro thesis ch. 6, 9; ★ DDIA ch. 3, 5, 8, 9; Porcupine post | Explain ReadIndex; explain why fsync errors aren't retried |
| 5 | 29–35 | helixd, object store, remote fetch + directory, global scheduler, spillback, leases/fencing/lineage, chaos harness | [leases](../concepts/leases-and-fencing.md), [scheduling](../concepts/scheduling-and-placement.md) | ★ Ray OSDI'18 + Ownership NSDI'21; ★ Borg; Sparrow; Kleppmann on locks | Walk through kill -9 timeline |
| 6 | 36–42 | CUDA SGEMM on Kaggle (droppable), batching queue (droppable), buffer + v0.4; metrics, tracing, load generator + eBPF, cloud benchmarks (NUMA, RPC) | [observability](../concepts/observability-and-tail-latency.md) | ★ Tail at Scale; ★ How NOT to Measure Latency; Dapper; Gregg BPF | Explain coordinated omission with numbers |
| 7 | 43–45 | Helix vs Ray benchmark, documentation pass, v0.5 | [system-design-primer](../concepts/system-design-primer.md) | DDIA re-read of ch. 8–9 | Two full mock design interviews |

## Weekends (30–60 min)
One system design prompt from [system-design-prompts.md](../interview/system-design-prompts.md), aloud, timed; 10 questions from the [question bank](../interview/question-bank.md).

## CS 6210 (AOS) tie-ins
| AOS topic | Helix connection |
| --- | --- |
| Synchronization (spinlocks, barriers, MCS) | Lock-free rings/deques, parking strategy |
| Scheduling (affinity, fixed processor) | Pinned workers, NUMA-aware stealing |
| Memory systems, virtualization | Allocators, mmap store, huge pages |
| RPC (LRPC, lightweight RPC) | helix-rpc design |
| Distributed systems (Lamport clocks, consistency) | Raft terms, linearizability |
| Failures and recovery (LRVM, RioVista) | WAL, snapshots, durability |
| Giant-scale services | Scheduling, tail latency |

Never publish solutions to course projects (CLAUDE.md §8).
