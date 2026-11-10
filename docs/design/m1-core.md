# Design doc M1: libhelix-core

| Field | Value |
| --- | --- |
| Status | **Draft** (finalize on day 11 with measured results) |
| Days | 3–11 · release v0.1 |
| Related | SPEC §1–2, [core-api.md](../api/core-api.md), concepts: [ordering](../concepts/memory-ordering-and-atomics.md), [lock-free](../concepts/lock-free-structures.md), [allocators](../concepts/virtual-memory-and-allocators.md), [work stealing](../concepts/work-stealing-scheduling.md) |

## 1. Summary
A single-node runtime that executes DAGs of tensor tasks on a pinned, NUMA-aware work-stealing pool, with tensors and task objects allocated from a custom slab allocator. The core design choice: **no shared mutable state on the common path** — per-thread allocator caches, per-thread deques, per-thread counters.

## 2. Goals
| Goal | Measure | Target |
| --- | --- | --- |
| Fast handoff | SPSC ring ops/s (B1) | ≥ 5× mutex queue; cached indices measurably better |
| Allocator speed | ns per alloc/free by size class (B2) | within 1.5× of mimalloc at 64 B and 1 KB |
| Scheduling efficiency | fib(30) vs `std::async`; 10 M empty tasks (B3) | ≥ 10× faster |
| Scaling | tiled matmul 4096² 1→8 threads (B5) | ≥ 6× at 8 threads |
| Correctness | TSan stress ×100, arm64 runs | zero reports |

## 3. Design
### 3.1 Memory
- `PageSource`: reserve with `mmap(PROT_NONE, MAP_NORESERVE)`, commit 2 MiB chunks with `mprotect` + `madvise(MADV_HUGEPAGE)`, optional `mbind`.
- `SlabAllocator`: ~40 size classes (64 B … 256 KiB, ×1.25 steps), spans of one class per 2 MiB chunk, intrusive free lists; `CentralFreeList` per class (mutex, day 4) behind per-thread `ThreadCache`s (day 5) that move batches of L/2.
- Large (> 256 KiB) allocations go straight to `PageSource` with a size header.
- `HELIX_MALLOC_PASSTHROUGH` build option routes to `malloc` so ASan can see heap bugs.

### 3.2 Lock-free primitives
- `SpscRing<T,N>`: producer-owned `tail_`, consumer-owned `head_`, each on its own 128-byte line, plus cached copies of the other index. Release on publish, acquire on observe.
- `WsDeque<T*>`: Chase–Lev with the C11 orderings of Lê et al. (PPoPP 2013); fixed capacity (8192) to avoid reclaiming resized arrays; signed 64-bit indices.

### 3.3 Scheduler
- One worker per core, pinned; deques per worker; injection queue for external spawns.
- Loop: local pop → injection → steal (same NUMA node first, random victims, ≤ 2×workers attempts) → spin `spin_before_park_us` → park on an eventcount (epoch + futex, wake one only if sleepers > 0).
- `TaskGraph`: atomic pending-parent counters (acq_rel decrement); the thread that zeroes a child runs it inline (continuation, bounded depth) and spawns the rest.

### 3.4 Kernels
naive → loop-reordered → cache-blocked + packed → NEON 8×8 micro-kernel; OpenBLAS backend for real runs; AVX2 on x86 day 42.

## 4. Alternatives
| Choice | Alternative | Why not (for now) |
| --- | --- | --- |
| Fixed-capacity deque | Growable deque + epoch reclamation | Reclamation adds complexity; overflow runs the task inline |
| Eventcount + futex | Condition variable per worker | Thundering herd / extra syscalls; harder to avoid lost wake-ups cheaply |
| Own allocator | mimalloc | Learning goal; control of NUMA placement and io_uring registration |

## 5. Failure modes
Lost wake-up (stall), ABA on free lists (corruption), false sharing (slowdown), deque last-element race (duplicate/lost task). Each has a targeted test (see day guide days 3–8).

## 6. Test plan
Single-threaded unit tests; reference-model comparison (mutex + `std::deque`, `malloc`); multi-threaded exactly-once stress ×100 under TSan and on arm64; mutation tests that weaken orderings must fail on ARM.

## 7. Results
_To be filled on day 11: B1–B5 numbers, flame graph, profiler-driven fix._

## 8. Open questions
- Batch size for depot transfers (start L/2 = 32).
- Whether to steal half the victim's deque instead of one task.
