# Hardware, caches and NUMA

## 1. The idea

A CPU core executes billions of instructions per second but main memory answers in ~100 ns. Everything between them — caches, prefetchers, TLBs, coherence — exists to hide that gap. Fast systems code is mostly about **keeping data close to the core that uses it and not making cores fight over cache lines**.

Mental model: memory is not a big array; it is a set of **64-byte (x86) or 128-byte (Apple Silicon) cache lines** that move between cores like library books. Reading a book everyone reads is cheap (copies are shared). Writing one forces every other copy to be thrown away (invalidated), and the next reader has to fetch it from you.

## 2. Numbers to know (orders of magnitude)

| Operation | Cost |
| --- | --- |
| L1 hit | ~1 ns (4–5 cycles) |
| L2 hit | ~4 ns |
| L3 hit | ~10–40 ns |
| DRAM (local NUMA node) | ~80–100 ns |
| DRAM (remote NUMA node) | ~130–200 ns |
| Cache line transfer core→core (same socket) | ~40–100 ns |
| Uncontended atomic RMW (lock add, CAS) | ~5–20 ns |
| Contended atomic on a bouncing line | 100+ ns each |
| Syscall (trivial) | ~100 ns–1 µs |
| Context switch | ~2–5 µs |
| Page fault (minor) | ~1 µs; major (disk) ms |
| TLB miss with page walk | ~10–100 ns |

## 3. Details that matter

**Coherence (MESI).** Each line is Modified, Exclusive, Shared or Invalid per core. A write needs the line in M/E, which invalidates other copies. Two cores alternately writing the same line "ping-pong" it: each write costs a cross-core transfer.

**False sharing.** Two *different* variables on the *same* line written by different threads bounce the line even though no data is shared. Example: SPSC ring `head_` (consumer writes) and `tail_` (producer writes) adjacent in a struct. Fix: `alignas(helix::kCacheLine)` (128 B — on x86 the adjacent-line prefetcher pairs 64-B lines, so 128 B is the safe padding).

**Prefetching and locality.** Hardware prefetchers detect sequential/strided access. Arrays beat linked lists; tiles that fit L1/L2 make matmul fast (day 10).

**TLB and huge pages.** Each 4 KiB page needs a TLB entry; a 1 GiB working set needs 262,144 entries, far more than the TLB holds. 2 MiB huge pages cut that 512×. Helix's slab carves from huge-page regions (`madvise(MADV_HUGEPAGE)` or `MAP_HUGETLB`).

**NUMA.** Multi-socket machines have memory attached to each socket. Accessing the other socket's memory costs ~1.5–2×. Linux allocates on **first touch**: the page goes to the node of the thread that first writes it. Helix pins threads per node and allocates per node; stealing prefers same-node victims.

**Memory ordering hardware.** x86 is TSO: stores are not reordered with other stores, loads not with loads; only store→load reordering is visible. ARM is weakly ordered: almost anything can be reordered without barriers. Code that "works on x86" may be broken on ARM — which is why Helix develops on arm64.

## 4. How Helix uses it

| Concept | Helix | File (day) |
| --- | --- | --- |
| Cache-line padding | `kCacheLine = 128`; ring indices, deque top/bottom, per-thread stats | `core/include/helix/base/config.h` (3) |
| Cached remote index | SPSC producer caches consumer's `head_` to avoid reading a bouncing line every push | `spsc_ring.h` (3) |
| Thread-local stats | Per-thread histograms/counters aggregated on scrape | `metrics` (39) |
| Huge pages | Slab page source (`PageSource`) | `core/include/helix/mem/` (4–5) |
| NUMA pinning | One worker per core, grouped by node | `sched/thread_pool.h` (7) |
| Tiling | SGEMM blocks for L1/L2 | `kernels/` sgemm (9) |

## 5. Pitfalls and how to prove them

- **Scaling collapse at N threads** → false sharing. Prove with `perf c2c record/report` (needs real hardware counters: rented x86 box, day 42) showing HITM on one cache line; or by padding and re-measuring.
- **Remote-NUMA slowdown** → check `numastat -p <pid>`; run with `numactl --cpunodebind=0 --membind=1` to measure the penalty.
- **TLB-bound workload** → `perf stat -e dTLB-load-misses`.

## 6. Try it

1. `lscpu` and `getconf LEVEL1_DCACHE_LINESIZE` (Apple Silicon VM may report 64 or 0; hardware is 128).
2. Day 2 microbenchmark: two threads incrementing two counters in one struct vs padded struct. Expect several× difference.
3. Pointer-chasing vs sequential scan over 1 MiB / 64 MiB arrays: watch latency jump at cache-size boundaries.

## 7. Check yourself

1. *Why 128-byte padding on x86 whose line is 64 B?* — The spatial (adjacent-line) prefetcher fetches pairs, so neighbours on the same 128-B pair still interfere.
2. *What is first-touch?* — Linux places a page on the NUMA node of the CPU that first faults it; initialize memory on the thread that will use it.
3. *Why is an atomic increment by 32 threads on one counter slow?* — Every increment needs exclusive ownership of the line; throughput is bounded by line transfers, not by the add.
4. *What does TSO forbid that ARM allows?* — Load→load, store→store and load→store reordering.

## 8. Read more
- Drepper, *What Every Programmer Should Know About Memory*, §3–6.
- Bryant & O'Hallaron, *CS:APP*, ch. 6 and 9.
- McKenney, *Is Parallel Programming Hard…*, ch. 3 ("Hardware and its habits").

## Field notes
_(added by day logs)_
