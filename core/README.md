# core — libhelix-core (C++20)

The single-node runtime: memory, lock-free queues, the work-stealing scheduler, the DAG executor, tensors and compute kernels. Everything else in the worker is built on it.

| Area | Header(s) | Day | What it provides | Key invariant |
| --- | --- | --- | --- | --- |
| base | `helix/base/version.h` | 1 ✅ | Version and build info | Static, immutable data; thread-safe |
| base | `helix/base/{config,check,status}.h` | 3 | `kCacheLine`, `HELIX_CHECK`, `Status`, `Result<T>` | No exceptions on hot paths |
| sync | `helix/sync/spsc_ring.h` | 3 | Wait-free SPSC ring with cached indices | Exactly one producer thread and one consumer thread |
| mem | `helix/mem/{page_source,size_class,slab}.h` | 4 | Page reservation, size classes, central free lists | 64-byte alignment; memory returned to the class it came from |
| mem | `helix/mem/{thread_cache,pmr}.h` | 5 | Per-thread caches, `std::pmr` adapter | Common path touches no shared state |
| sync | `helix/sync/ws_deque.h` | 6 | Chase–Lev work-stealing deque | Owner pushes/pops bottom; thieves CAS top |
| sched | `helix/sched/{thread_pool,eventcount,task}.h` | 7 | Pinned work-stealing pool, futex parking | No lost wake-ups |
| sched, tensor | `helix/sched/task_graph.h`, `helix/tensor/tensor.h` | 8 | DAG executor, Tensor type | Dependency decrement is acq_rel |
| kernels | `helix/kernels/sgemm.h`, `tiled_matmul.h` | 9–10 | naive / blocked / NEON / BLAS SGEMM, tiled DAG matmul | Results `allclose` to naive |

Layout: `include/helix/<area>/*.h` (public), `src/<area>/*.cc`, `test/*_test.cc`, `bench/*_bench.cc` (day 2+), `tools/`.

Design: [docs/design/m1-core.md](../docs/design/m1-core.md) · API: [docs/api/core-api.md](../docs/api/core-api.md) · Concepts: [memory ordering](../docs/concepts/memory-ordering-and-atomics.md), [lock-free structures](../docs/concepts/lock-free-structures.md), [work stealing](../docs/concepts/work-stealing-scheduling.md), [allocators](../docs/concepts/virtual-memory-and-allocators.md).

Build and test: `make test-cpp`, `make tsan`, `ctest --test-dir build -R <Name>`.
