# Virtual memory, mmap and allocators

## 1. The idea

Every process sees a private **virtual address space**; the MMU translates virtual pages to physical frames through page tables, cached in the TLB. Memory is handed out **lazily**: `mmap` reserves addresses; physical pages appear only when touched (a page fault). An **allocator** sits between the program and the kernel, turning a few big `mmap` regions into many small objects quickly, without a syscall per allocation.

## 2. Virtual memory details that matter

| Concept | What to know | Helix use |
| --- | --- | --- |
| Page size | 4 KiB base; 2 MiB / 1 GiB huge pages (on arm64 the base can also be 16 KiB/64 KiB) | Slab pages, store alignment |
| Demand paging | First touch → minor fault (~1 µs) → zeroed page | Pre-fault store and buffers at startup |
| `mmap` flags | `MAP_PRIVATE` vs `MAP_SHARED`; `MAP_ANONYMOUS`; `MAP_POPULATE` (pre-fault); `MAP_HUGETLB` | Store = `MAP_SHARED` over `memfd` |
| `madvise` | `MADV_HUGEPAGE`, `MADV_DONTNEED` (drop pages), `MADV_FREE` | Slab returns memory |
| `mlock` | Pin pages in RAM (no swap); limits via `ulimit -l` | io_uring registered buffers are pinned |
| THP | Transparent huge pages: `always`/`madvise`/`never`; `khugepaged` compaction causes latency spikes | Use `madvise` mode |
| `memfd_create` | Anonymous file in RAM; can be mapped by several processes, passed over a socket | Object store region |
| Overcommit | `mmap` usually succeeds even if RAM is short; OOM killer later | Store capacity is explicit and pre-faulted |

## 3. Allocator design space

| Design | Idea | Strength | Weakness |
| --- | --- | --- | --- |
| Bump / arena | Pointer increment; free all at once | Fastest; great per request/task | No individual free |
| Free list per size class (slab) | Fixed-size objects carved from pages | O(1), no fragmentation within a class | Internal fragmentation (rounding up) |
| Buddy | Power-of-two blocks split/merged | Simple coalescing | Up to 2× internal fragmentation |
| Best-fit extents | Ordered free map | Good for big variable blocks | O(log n), external fragmentation |
| Thread caches (tcmalloc/mimalloc/jemalloc) | Per-thread/per-CPU free lists in front of a central heap | No lock on the fast path | Memory held in caches; cross-thread frees |

## 4. Helix's slab allocator (days 4–5) — `core/include/helix/mem/`

```
size classes: ~40 classes, 64 B ... 256 KiB in ×1.25 steps (≤ 25% rounding waste); one class per 2 MiB span, intrusive free lists   > 256 KiB → PageSource directly
per-thread cache: per class, a small LIFO array of free objects (no atomics)
central per-class lists: per NUMA node, mutex-protected, batch transfer (e.g. 32 objects)
PageSource: reserves a large region, commits 2 MiB at a time, MADV_HUGEPAGE, bound to a NUMA node
Arena: bump allocator with reset(), for per-task scratch
```

- Day 4 builds PageSource + size classes + central lists; day 5 adds per-thread caches.
- **Fast path**: pop from the thread's cache — a few instructions, no atomics.
- **Refill/flush**: move a batch to/from the central list under a lock (amortized).
- **Cross-thread free**: object goes to the freeing thread's cache (simple) — mimalloc-style per-page remote-free lists are a stretch.
- **Debug/sanitizer mode**: `HELIX_ALLOCATOR_PASSTHROUGH` forwards to `malloc` so ASan/TSan see real lifetimes.
- **Metrics**: bytes per class, cache hit rate, central lock contention.

## 5. Object-store extent allocator (day 30)
Large tensors need variable-size, page-aligned blocks: a best-fit free map with coalescing over the `memfd` region ([docs/db/object-store-layout.md](../db/object-store-layout.md)).

## 6. Pitfalls

| Problem | Symptom | Fix |
| --- | --- | --- |
| First-touch page faults on hot path | Latency spikes on first use | Pre-fault (`MAP_POPULATE`), `mlock` |
| THP compaction | Periodic ms stalls | THP = `madvise`; pre-allocate |
| Allocator lock contention | Scaling stops; `perf` shows futex | Thread caches, batching |
| Producer/consumer frees | Memory piles up in the consumer's cache | Bounded caches flush to central |
| Memory recycled under ASan | Use-after-free not detected | Passthrough mode |
| Remote NUMA memory | ~1.5× slower kernels | Allocate on the thread's node |

## 7. Try it
1. `mmap` 1 GiB anonymous, touch every 4 KiB, time it (≈ 262k faults) vs with `MAP_POPULATE` vs `MADV_HUGEPAGE`.
2. `cat /proc/<pid>/smaps_rollup`; `grep AnonHugePages /proc/meminfo`.
3. Day 4–5 bench: slab vs `malloc` vs mimalloc for 64 B–256 KiB, 1 and 8 threads, including the producer/consumer free pattern.

## 8. Check yourself
1. *What happens on the first write to a fresh anonymous mapping?* — Page fault; kernel allocates and zeroes a frame, installs the PTE.
2. *Why do huge pages help?* — Fewer TLB entries/misses and shorter page walks for large working sets.
3. *Internal vs external fragmentation?* — Wasted space inside an allocated block (rounding) vs free space split into pieces too small to use.
4. *Why does tcmalloc have per-CPU caches?* — Avoid locks and cache-line sharing on the fast path.
5. *Why memfd for the object store?* — Shareable across processes, sealable, and mappable with `MAP_SHARED` for zero-copy I/O.

## 9. Read more
- Bonwick, "The Slab Allocator" (1994); Leijen et al., "Mimalloc" (2019); TCMalloc design doc.
- *CS:APP* ch. 9 (virtual memory, malloc lab).
- `man 2 mmap`, `man 2 madvise`, `man 2 memfd_create`; kernel docs on THP.

## Field notes
_(added by day logs)_
