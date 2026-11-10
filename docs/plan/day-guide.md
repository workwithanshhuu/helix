# Day guide: all 45 days

Every one of the 45 days, step by step: what to learn, what to build in which order, which files to create, how to test it, what will go wrong, and how you know you're done. The five sub-tabs follow the phases; the tracker ([tracker.md](tracker.md)) is where you track progress.

## How each day is laid out

| Part | What it tells you |
| --- | --- |
| Goal | The one outcome of the day |
| Why it matters | Where this piece sits in Helix and in interviews |
| Learn (\~60 min) | Exact readings and the concepts to pull out of them |
| Build (\~180 min) | Ordered steps with rough time boxes |
| Files | Paths you create or change |
| Tests | What to write before you call it done |
| Pitfalls | The mistakes most people make on this step |
| Done when | Objective checks; all must pass |
| Self-check | Questions to answer out loud without notes |

## Daily routine (4 hours)

1. **10 min:** re-read the day, open yesterday's notes, run the full test suite to confirm a green start.
2. **50 min:** the Learn block. Write 5 bullet notes in `notes/day-NN.md` in your own words.
3. **2 h 50 min:** the Build block. Commit at least every hour; push before stopping.
4. **10 min:** tick the tracker, write what's left for tomorrow, tick the day in [tracker.md](tracker.md).

## Rules that apply every day

- **Green before new work.** Never start a step with a failing test.
- **Time-box.** If a step overruns by 50%, write down where you're stuck, take the simplest path that passes "Done when", and file an issue for the better version.
- **Measure, don't guess.** Every performance claim gets a benchmark, and the number goes in the notes.
- **Write while it's fresh.** Bugs worth more than 30 minutes go into `docs/postmortems/` the same day.
- **Behind schedule?** Use the next buffer day (18, 28, 38). Past two buffers, drop days 36–37 first.

## Phases

| Days | Phase | Release |
| --- | --- | --- |
| 1–11 | Setup and M1: memory, lock-free, scheduler | v0.1 |
| 12–18 | M2: io\_uring data plane | v0.2 |
| 19–28 | M3: Raft control plane | v0.3 |
| 29–38 | M4: execution, object store, recovery | v0.4 |
| 39–45 | M5: observability, benchmarks, release | v0.5 |


## Days 1–11 · Setup and M1 low-level core

By day 11 you have a single-node C++ runtime: your own allocator, lock-free queues and a work-stealing scheduler running a tiled matrix-multiply DAG, tagged v0.1.

### Day 1 · Environment, repo skeleton, CI

**Goal:** an empty but real Helix repo that builds C++ and Go and runs sanitizers in CI.

**Why it matters:** every later day assumes `make test` and `make tsan` work. Fixing tooling on day 12 costs far more than today.

**Learn (60 min):** read [ARCHITECTURE.md](../../ARCHITECTURE.md), [SPEC.md](../../SPEC.md) §1 (Conventions). Write down, in your own words, what each of the five components owns.

**Build (180 min):**

1. *(40 min)* Install OrbStack; create an Ubuntu 24.04 arm64 machine `helix` with 8 cores and 14 GB. Inside it: `sudo apt install -y build-essential clang lld cmake ninja-build git liburing-dev libnuma-dev libopenblas-dev protobuf-compiler libgrpc++-dev protobuf-compiler-grpc bpftrace linux-tools-generic golang-go`. Check `go version` is 1.23+; if apt's is older, install Go from go.dev.
2. *(20 min)* Smoke tests: `uname -r` (want 6.1+), `getconf PAGESIZE`, `getconf LEVEL1_DCACHE_LINESIZE`, `nproc`, `lscpu`. Write all values into `notes/day-01.md`.
3. *(40 min)* Create the repo with the layout from Spec §1. Add a root `CMakeLists.txt` with a `helix_core` library holding one function, a GoogleTest test for it (via `FetchContent`), and `go.mod` with one package and one test.
4. *(30 min)* `Makefile` targets: `build`, `test`, `asan`, `tsan`, `ubsan`, `race`, `lint`. Sanitizer builds use separate build directories (`build-asan/` etc.).
5. *(30 min)* GitHub Actions: Ubuntu runners (x86 and `ubuntu-24.04-arm`), jobs for build + test, ASan, TSan, UBSan, Go race. Add `.clang-format`, `.clang-tidy`, `.golangci.yml`.
6. *(20 min)* `README.md` with a one-paragraph pitch and "status: day 1"; Apache-2.0 `LICENSE`; push to GitHub.

**Files:** `CMakeLists.txt`, `Makefile`, `core/{CMakeLists.txt,include/helix/base/version.h,src/version.cc,test/version_test.cc}`, `meta/version.go`, `meta/version_test.go`, `.github/workflows/ci.yml`, lint configs, `README.md`, `LICENSE`, `notes/day-01.md`.

**Tests:** one trivial test per language; deliberately add a data race in a scratch branch and confirm the TSan job fails, then delete it.

**Pitfalls:** building inside the macOS-mounted folder is slow; keep the repo in the Linux machine's home and edit it over the mount. TSan and ASan can't be combined in one build. Some ARM kernels use 16 KB pages; note it if yours does.

**Done when:**

- [ ] `make build test asan tsan race` all pass locally
- [ ] CI is green on both architectures
- [ ] The deliberate race made CI red

**Self-check:** Why does TSan need its own build? What does `-fsanitize=address` do to each memory access?

### Day 2 · Benchmark harness, kernel checks, accounts, first ADRs

**Goal:** you can write and run a microbenchmark in one minute, and the two biggest early decisions are written down.

**Why it matters:** every M1 claim needs a number. ADRs are what makes the repo read like an infrastructure project.

**Learn (60 min):** Foundations → Hardware and OS basics: the latency table, caches, coherence. Then Drepper §3 (CPU caches) for depth. Do the pointer-chasing experiment from the Foundations tab.

**Build (180 min):**

1. *(40 min)* Add Google Benchmark via `FetchContent`; `core/bench/` with a pointer-chasing benchmark over 16 KB → 256 MB working sets. `make bench` writes JSON to `bench/results/<date>/`.
2. *(30 min)* `bench/plot/plot.py` (matplotlib) that turns benchmark JSON into a PNG. Plot the cache-size steps; save it in `docs/benchmarks/day02-cache-steps.png`.
3. *(20 min)* `bench/env.sh` that prints kernel, CPU, cores, memory, page size, compiler version and git commit (Spec §10).
4. *(25 min)* Kernel feature checks as tests: a tiny io\_uring program (`io_uring_queue_init`, one NOP, reap it) and `bpftrace -e 'BEGIN { exit(); }'`. If either fails in OrbStack, switch to a UTM VM now, not later.
5. *(25 min)* Write `docs/adr/0001-build-system.md` (CMake + FetchContent vs Bazel) and `0002-grpc-for-control-plane.md` (gRPC for control messages, custom transport only for tensor bytes). Use the template: Title, Status, Context, Decision, Consequences, Alternatives.
6. *(20 min)* Create Kaggle and Google Cloud accounts. On GCP, create a $5 budget alert and start nothing. Note the GCP trial end date (sign-up + 90 days).
7. *(20 min)* `docs/design/` folder with an RFC template (Goals, Non-goals, Design, Alternatives, Failure modes, Test plan, Metrics).

**Pitfalls:** benchmarks the compiler optimizes away (use `benchmark::DoNotOptimize`); measuring in a Debug build; forgetting to record the environment.

**Done when:**

- [ ] `make bench` runs in CI (short mode) and locally (full)
- [ ] The cache-steps chart shows visible L1/L2/L3/DRAM steps, and your notes explain them
- [ ] io\_uring NOP and bpftrace both work
- [ ] ADR-0001 and ADR-0002 merged

**Self-check:** At what working-set size did latency jump, and which cache does that match? Why gRPC for the control plane but not for tensors?

### Day 3 · SPSC ring buffer

**Goal:** a wait-free single-producer single-consumer ring that moves 100 M+ items/s between two pinned cores.

**Why it matters:** it's the building block for the scheduler's injection queue and the shared-memory transport, and the simplest place to learn acquire/release properly.

**Learn (60 min):** Foundations → Memory ordering and Concurrency basics. Williams, *C++ Concurrency in Action* ch. 5 (5.2–5.3). Preshing, "Acquire and Release Semantics". Run the message-passing litmus test on your Mac.

**Build (180 min):**

1. *(20 min)* `core/include/helix/base/`: `kCacheLine = 128`, `HELIX_CHECK`, `Status`/`Result<T>` (Spec §1 code rules).
2. *(30 min)* Baseline: `MutexQueue<T>` = `std::mutex` + `std::deque`. This is your reference model and benchmark baseline.
3. *(60 min)* `SpscRing<T, N>`: array of N slots (N a power of two, index with `& (N-1)`); producer-owned `tail_` and consumer-owned `head_` as `std::atomic<size_t>`, each in its own 128-byte-aligned struct; producer keeps `cached_head_`, consumer keeps `cached_tail_`.
   - `try_push`: if `tail - cached_head == N`, reload `cached_head = head_.load(acquire)`; if still full return false; write the slot; `tail_.store(tail + 1, release)`.
   - `try_pop`: mirror image with `tail_.load(acquire)` and `head_.store(head + 1, release)`.
4. *(35 min)* Tests: single-threaded fill/drain/wrap-around; two-thread stress pushing 0..10 M and checking the consumer sees exactly that sequence; run under TSan; run 100 times.
5. *(35 min)* Benchmark B1: ring vs mutex queue, producer and consumer pinned to different cores; then a variant without the cached indices. Record all three numbers.

**Files:** `core/include/helix/base/{config.h,check.h,status.h}`, `core/include/helix/sync/spsc_ring.h`, `core/test/spsc_ring_test.cc`, `core/bench/spsc_ring_bench.cc`.

**Pitfalls:** `size_t` indices that wrap are fine as long as you only compare differences; putting `head_` and `tail_` in one struct (false sharing); using `seq_cst` everywhere and calling it done (correct but you learn nothing; measure the difference).

**Done when:**

- [ ] Stress test passes 100 runs under TSan and on ARM
- [ ] Ring ≥ 5× the mutex queue; cached-index version measurably faster than uncached
- [ ] Each atomic has a comment naming its pair

**Self-check:** Which load must be acquire and why? What exactly does the cached index save?

### Day 4 · Slab allocator, part 1: pages and size classes

**Goal:** a correct (not yet fast) allocator: page source, size classes, and central free lists.

**Why it matters:** tensors, task objects and message buffers all come from here; owning the allocator lets you control NUMA placement, alignment and registration with io\_uring later.

**Learn (60 min):** Bonwick, "The Slab Allocator" (USENIX 1994), sections 1–4. Foundations → Virtual memory. Skim the TCMalloc design doc's "overview" and "size classes".

**Build (180 min):**

1. *(50 min)* `PageSource`: reserve a large region with `mmap(PROT_NONE, MAP_PRIVATE|MAP_ANONYMOUS|MAP_NORESERVE)`; `commit()` hands out 2 MB chunks by `mprotect` to read/write and `madvise(MADV_HUGEPAGE)`; optional `mbind` to a NUMA node (no-op when libnuma reports one node).
2. *(30 min)* Size classes: 64, 80, 96, 128, then roughly ×1.25 steps up to 256 KB (about 40 classes). A lookup table maps a request size to its class in O(1).
3. *(50 min)* Spans: each 2 MB chunk is cut into objects of one class; an intrusive free list threads through free objects. `CentralFreeList` per class protected by a mutex for now.
4. *(20 min)* Large allocations (> 256 KB) go straight to `PageSource` with a header recording the size.
5. *(30 min)* Tests: allocate/free random sizes against a reference (`malloc`) checking alignment, no overlap (write a pattern, verify it before freeing), and reuse.

**Files:** `core/include/helix/mem/{page_source.h,size_class.h,slab.h}`, `core/src/mem/*.cc`, `core/test/slab_test.cc`.

**Pitfalls:** ASan can't see bugs inside your own slabs. Add a `HELIX_MALLOC_PASSTHROUGH` build option that forwards to `malloc`, and run ASan in that mode. Freeing with the wrong size class; returning memory that isn't 64-byte aligned.

**Done when:**

- [ ] Randomized test with 1 M operations passes, in normal and passthrough-ASan modes
- [ ] Every class returns 64-byte-aligned memory
- [ ] `stats()` reports bytes in use per class correctly

**Self-check:** Why reserve with `PROT_NONE` and commit later? What is internal fragmentation, and what does the 1.25× step cost you?

### Day 5 · Slab allocator, part 2: per-thread caches

**Goal:** make the common allocate/free path touch no shared state, and get within 1.5× of mimalloc.

**Why it matters:** with 8+ threads allocating, a shared lock becomes the bottleneck; this is the same design as tcmalloc and mimalloc.

**Learn (60 min):** Leijen et al., "Mimalloc: Free List Sharding in Action" (2019), sections 1–3. The TCMalloc design doc's "per-CPU/per-thread caches" and "transfer cache".

**Build (180 min):**

1. *(60 min)* `ThreadCache` (`thread_local`): one small free list per class, max length L (e.g. 64). Allocate pops locally; when empty, fetch a batch of L/2 from the central list. Free pushes locally; when over L, return a batch.
2. *(30 min)* Cross-thread frees (allocated on A, freed on B) simply go to B's cache; that's correct because classes are global. Note the cost in your notes.
3. *(30 min)* `std::pmr::memory_resource` adapter so `std::pmr::vector` can use the allocator.
4. *(60 min)* Benchmark B2: alloc/free pairs for 64 B, 1 KB, 64 KB with 1, 4 and 8 threads, against glibc `malloc` and mimalloc (`apt install libmimalloc-dev` and link it in the benchmark only). Plot it.

**Files:** `core/include/helix/mem/thread_cache.h`, `core/src/mem/thread_cache.cc`, `core/include/helix/mem/pmr.h`, `core/bench/alloc_bench.cc`, `docs/benchmarks/b2-allocator.md`.

**Pitfalls:** thread exit leaking a full cache (flush it in the `thread_local` destructor); benchmark loops that free in the same order they allocated (unrealistically friendly); comparing a Debug build to a Release mimalloc.

**Done when:**

- [ ] Within 1.5× of mimalloc on the 64 B and 1 KB single-thread cases; scaling 1→8 threads near linear
- [ ] TSan clean with 8 threads doing mixed cross-thread frees for 30 s
- [ ] B2 chart and a short write-up committed

**Self-check:** Why batch transfers instead of moving one object at a time? Where does your allocator lose to mimalloc, and why?

### Day 6 · Chase–Lev work-stealing deque

**Goal:** a correct, TSan-clean Chase–Lev deque: the owner pushes and pops at the bottom; any thread steals from the top.

**Why it matters:** it's the heart of the scheduler and the most-asked lock-free structure in infrastructure interviews.

**Learn (60 min):** Chase & Lev, "Dynamic Circular Work-Stealing Deque" (SPAA 2005). Lê, Pop, Cohen, Zappa Nardelli, "Correct and Efficient Work-Stealing for Weak Memory Models" (PPoPP 2013), Figure 1 (the C11 code). Copy that figure into your notes and annotate each memory order.

**Build (180 min):**

1. *(70 min)* `WsDeque<T*>` with a **fixed** capacity (power of two; e.g. 8192) to avoid reclaiming resized arrays. Slots are `std::atomic<T*>` (relaxed) so TSan understands them. `top_` and `bottom_` as `std::atomic<int64_t>`, each 128-byte aligned.
   - `push(x)`: `b = bottom.load(relaxed)`, `t = top.load(acquire)`; if full return false (caller runs the task inline); `slot[b].store(x, relaxed)`; `atomic_thread_fence(release)`; `bottom.store(b+1, relaxed)`.
   - `pop()`: `b = bottom.load(relaxed) - 1`; `bottom.store(b, relaxed)`; `atomic_thread_fence(seq_cst)`; `t = top.load(relaxed)`. If `t <= b`: take `slot[b]`; if `t == b` (last element), CAS `top` from t to t+1 (seq\_cst); if the CAS fails the thief won, return empty; either way restore `bottom = b+1`. If `t > b`: empty, restore `bottom = b+1`.
   - `steal()`: `t = top.load(acquire)`; `atomic_thread_fence(seq_cst)`; `b = bottom.load(acquire)`; if `t < b`: read `slot[t]`, CAS `top` t→t+1; success returns the item, failure returns `ABORT` (retry elsewhere). Else `EMPTY`.
2. *(60 min)* Tests: single-thread LIFO behaviour; owner pushes 0..N−1 and pops while 3 thieves steal; collect everything taken by everyone into per-thread vectors; at the end assert each value appears exactly once. 100 M operations, 100 repetitions, under TSan, and on the Mac.
3. *(30 min)* Mutation testing: change the seq\_cst fence in `pop` to release, run the stress test on ARM until it fails, note the failure, revert. Repeat for `steal`.
4. *(20 min)* Write `docs/design/m1-scheduler.md` section "Deque": the orderings and why each is needed.

**Files:** `core/include/helix/sync/ws_deque.h`, `core/test/ws_deque_test.cc`, `docs/design/m1-scheduler.md`.

**Pitfalls:** using `size_t` (the algorithm needs signed comparison when `bottom` dips below `top`); forgetting to restore `bottom` on the empty path; non-atomic slot array (TSan will flag it, correctly).

**Done when:**

- [ ] Exactly-once stress test passes 100 runs under TSan and on ARM
- [ ] You can explain the last-element race from memory
- [ ] Mutation test showed at least one failure when an ordering was weakened

**Self-check:** Why does `pop` need a full fence between writing `bottom` and reading `top`? What does `ABORT` mean and what should the thief do?

### Day 7 · Thread pool with work stealing

**Goal:** a pinned, NUMA-aware work-stealing pool that runs fork-join workloads ≥ 10× faster than `std::async`.

**Why it matters:** this pool executes every task in Helix; its parking logic decides both latency and CPU use.

**Learn (60 min):** Herlihy & Shavit ch. 16 (work stealing). Foundations → Threads, scheduling and futex. Skim the oneTBB or Go runtime scheduler description for how they park idle threads.

**Build (180 min):**

1. *(40 min)* `ThreadPool(PoolConfig)`: one thread per core, pinned with `pthread_setaffinity_np`; workers grouped by NUMA node (one group on the Mac). Each worker owns a `WsDeque`; an `MpscInjection` queue (mutex-protected is fine for now) takes tasks from non-worker threads.
2. *(40 min)* Worker loop: pop local → take from injection queue → steal (first from a random same-node victim, then any node; up to 2× workers attempts) → spin for `spin_before_park_us` with `pause`/`yield` → park.
3. *(40 min)* Parking with an eventcount: an atomic epoch counter plus a futex. A worker reads the epoch, re-checks for work, then `FUTEX_WAIT` on that epoch value. `spawn` increments the epoch and wakes one sleeper only if someone is sleeping (a `sleepers` counter). This avoids lost wakeups and avoids a syscall on every spawn.
4. *(30 min)* Benchmarks B3: recursive `fib(30)` with spawn at each level (cut off below n=15), and 10 M empty tasks; compare with `std::async` and a mutex-queue pool. Record steals, parks and tasks per second.
5. *(30 min)* Tests: all tasks run exactly once; `wait_idle` returns only when everything finished; shutdown with tasks in flight doesn't hang (run 100 times).

**Files:** `core/include/helix/sched/{thread_pool.h,eventcount.h,task.h}`, `core/src/sched/thread_pool.cc`, tests and benches.

**Pitfalls:** lost wakeup (re-check for work after announcing you'll sleep); thundering herd (wake one, not all); spawn from a non-worker thread pushing into some worker's deque (only the owner may push).

**Done when:**

- [ ] fib(30) ≥ 10× faster than `std::async`; empty-task rate recorded
- [ ] Idle pool uses \~0% CPU after `spin_before_park_us`
- [ ] Shutdown and exactly-once tests pass 100 runs under TSan

**Self-check:** Why steal from the top but pop from the bottom? Walk through how the eventcount prevents a lost wakeup.

### Day 8 · DAG executor and Tensor type

**Goal:** run an arbitrary task DAG on the pool, with tensors allocated from your allocator.

**Why it matters:** a Helix job is a DAG; this is the single-node version of what M4 distributes.

**Learn (60 min):** Blumofe & Leiserson, "Scheduling Multithreaded Computations by Work Stealing" (skim: the T₁/P + T∞ bound and why it holds). Skim the `taskflow` README for API ideas.

**Build (180 min):**

1. *(40 min)* `Tensor`: dtype (f32, f16, i32), shape (up to 4 dims), row-major strides, 64-byte-aligned data from the slab or `PageSource`, an intrusive refcount. Helpers `zeros`, `random`, `allclose`.
2. *(60 min)* `TaskGraph`: nodes hold a function, a list of children and `std::atomic<int> pending` = number of parents. `run()` pushes all zero-pending nodes; when a node finishes it decrements each child's `pending` (acq\_rel) and, for the one that reaches zero, runs it directly on the same thread (continuation) and spawns the rest. Cycle detection at build time.
3. *(20 min)* Error handling: a failing node marks the graph failed; remaining nodes are skipped; `run()` returns the first error.
4. *(40 min)* Tests: random DAGs of 10k nodes where each node writes `f(parents)` into an array, compared with a serial topological execution; DAG with one failing node; empty graph.
5. *(20 min)* Update `docs/design/m1-scheduler.md` with the DAG section and a small diagram.

**Files:** `core/include/helix/tensor/tensor.h`, `core/include/helix/sched/task_graph.h`, sources, tests.

**Pitfalls:** decrementing with relaxed order (the child may then read stale parent outputs: use acq\_rel); recursion depth when running continuations inline (bound it, spawn past the bound).

**Done when:**

- [ ] 10k-node random DAGs match the serial result 100 times under TSan
- [ ] Failure propagation test passes

**Self-check:** Why must the dependency decrement be acq\_rel? What are T₁ and T∞ for a 64×64 tiled matmul DAG?

### Day 9 · SGEMM kernels: naive, blocked, NEON

**Goal:** three matrix-multiply kernels and a chart showing how each approaches the hardware limit, next to OpenBLAS.

**Why it matters:** it teaches the memory hierarchy through the most important AI kernel, and gives the executor real work to schedule.

**Learn (60 min):** Goto & van de Geijn, "Anatomy of High-Performance Matrix Multiplication" (sections 1–4). Look up the roofline model: performance is capped by min(peak FLOP/s, bandwidth × arithmetic intensity).

**Build (180 min):**

1. *(20 min)* Naive triple loop `C[i][j] += A[i][k] * B[k][j]`; then reorder to i-k-j so the inner loop streams through rows (often 5–10× faster on its own).
2. *(50 min)* Cache-blocked: loop over tiles of `MC×KC` of A and `KC×NC` of B sized to fit L2/L1 (start with 64×256×256 and tune); copy (pack) tiles into contiguous buffers.
3. *(60 min)* NEON micro-kernel: compute a 4×4 or 8×8 block of C in registers with `vfmaq_f32` (`#include <arm_neon.h>`), loading packed A and B. Keep a scalar fallback under `#ifdef` for x86 (AVX2 comes on the cloud box).
4. *(20 min)* `sgemm()` dispatches by backend: `naive | blocked | neon | blas` (OpenBLAS `cblas_sgemm`).
5. *(30 min)* Benchmark B4 for N = 256, 512, 1024, 2048: GFLOP/s = 2N³ / time. Plot all four. Test every backend against naive with `allclose(rtol=1e-4)`.

**Files:** `core/include/helix/kernels/sgemm.h`, `core/src/kernels/{sgemm_naive,sgemm_blocked,sgemm_neon,sgemm_blas}.cc`, tests, `docs/benchmarks/b4-sgemm.md`.

**Pitfalls:** comparing with exact equality (floating-point order differs); tiles that don't divide N (handle edges); forgetting `-O3 -mcpu=native`.

**Done when:**

- [ ] All backends pass correctness tests including odd sizes (e.g. 1000)
- [ ] B4 chart: naive < blocked < NEON ≤ OpenBLAS, with your notes explaining each gap

**Self-check:** What's the arithmetic intensity of an N×N matmul, and why does blocking raise the achieved intensity? Why pack tiles?

### Day 10 · Tiled matmul as a DAG; scaling

**Goal:** a large matmul split into tile tasks, run on the pool, scaling close to linearly from 1 to 8 threads.

**Why it matters:** this is the exact workload M4 will distribute across machines; today you learn its single-node limits.

**Learn (60 min):** Gregg, *Systems Performance* ch. 6 (CPUs): run-queue latency, utilization vs saturation, the USE method.

**Build (180 min):**

1. *(60 min)* `tiled_matmul(A, B, C, tile)`: one task per C tile computing `sum_k A[i,k] × B[k,j]` with the BLAS or NEON kernel per block; build it as a `TaskGraph` (independent tiles, or a reduction tree over k if you split k).
2. *(30 min)* Per-worker counters (tasks run, steals, parks, idle time) in padded per-thread structs, read by `stats()`.
3. *(60 min)* Benchmark B5: 4096×4096 with tile sizes 256 and 512, threads 1, 2, 4, 8; plot speed-up vs ideal and against a single multithreaded OpenBLAS call (`OPENBLAS_NUM_THREADS`).
4. *(30 min)* False-sharing experiment: temporarily put the counters in one unpadded array; measure; restore. Record both numbers.

**Files:** `core/include/helix/kernels/tiled_matmul.h`, source, `core/bench/tiled_matmul_bench.cc`, `docs/benchmarks/b5-scaling.md`.

**Pitfalls:** OpenBLAS spawning its own threads inside your tasks (set `OPENBLAS_NUM_THREADS=1` for per-tile calls); tiles too small (scheduling overhead dominates) or too big (not enough parallelism).

**Done when:**

- [ ] Speed-up ≥ 6× at 8 threads for 4096² (or a written explanation of the bottleneck)
- [ ] False-sharing experiment recorded with numbers

**Self-check:** How did you choose the tile size? What limits scaling at 8 threads on your Mac?

### Day 11 · Profile, fix, design doc, v0.1

**Goal:** ship v0.1 with one profiler-driven fix and a design doc you could defend in an interview.

**Why it matters:** a tagged release with a design doc and benchmarks is the first proof the project is real.

**Learn (60 min):** Gregg's flame-graph page and `perf` examples. Learn `perf record -g`, `perf report`, and how to make a flame graph with `inferno` or FlameGraph scripts.

**Build (180 min):**

1. *(45 min)* Profile B3 and B5 with `perf record -g` (software events work in the VM). Make flame graphs; identify the biggest non-kernel cost.
2. *(45 min)* Fix one thing the profile shows (common: steal attempts on empty deques → add a quick emptiness check; or task allocation → allocate tasks from the slab). Re-measure; record before/after.
3. *(45 min)* Finish `docs/design/m1-core.md`: goals, allocator design, ring, deque, pool, DAG, measured results, known limits, what's next.
4. *(25 min)* README: what v0.1 does, how to build, three headline numbers (ring ops/s, fib speed-up, matmul scaling).
5. *(20 min)* Tag `v0.1`, write release notes, close finished issues, file issues for anything deferred.

**Done when:**

- [ ] Flame graph and before/after numbers in `docs/benchmarks/`
- [ ] `m1-core.md` complete; README updated
- [ ] `v0.1` tagged with CI green

**Self-check:** Explain M1 in 3 minutes as if to an interviewer: what you built, one hard bug, one number you're proud of.


## Days 12–18 · M2 network data plane

By day 18 two Helix processes move tensors over io\_uring TCP with no copies in your code, beating gRPC on small-message tail latency, tagged v0.2.

### Day 12 · io\_uring echo and the frame header

**Goal:** an io\_uring TCP echo server and client, and a validated 32-byte frame header.

**Why it matters:** every later M2 day builds on this event loop; getting the submission/completion model right now avoids subtle bugs later.

**Learn (60 min):** Foundations → Networking basics. Jens Axboe, "Efficient IO with io\_uring" (kernel.dk/io\_uring.pdf), sections 1–5. *Lord of the io\_uring* (unixism.net/loti): "io\_uring by example" chapters.

**Build (180 min):**

1. *(70 min)* `UringLoop`: owns one `io_uring` (256 entries). API: `submit_accept`, `submit_recv`, `submit_send`, each storing a small `Op` struct pointer in `user_data`; `run()` waits for completions and dispatches by op type. Re-arm accept and recv after each completion.
2. *(30 min)* Echo server on port 7200 and a client that sends N messages of size S and measures round-trip time with `CLOCK_MONOTONIC`. Set `TCP_NODELAY` on every socket.
3. *(40 min)* `FrameHeader` exactly as Spec §3, with `encode()`/`decode()` and CRC32C (use the ARM CRC instructions via `__crc32cd` or a small table-driven version; hardware later).
4. *(40 min)* Tests: header round-trip; corrupted magic/version/CRC rejected; lengths over the limits rejected. Measure 64 B echo RTT on loopback (p50 and p99 over 100k messages).

**Files:** `rpc/include/helix/rpc/{uring_loop.h,frame.h,crc32c.h}`, `rpc/src/*.cc`, `rpc/tools/echo_{server,client}.cc`, `rpc/test/frame_test.cc`.

**Pitfalls:** the `Op` struct freed before its completion arrives (lifetime must outlive the CQE); `-ECANCELED`/`-EAGAIN` results ignored; short sends (a send completion may report fewer bytes than requested: resubmit the rest).

**Done when:**

- [ ] Echo runs 10 minutes with 64 connections without errors or leaks (ASan)
- [ ] Frame tests pass; 64 B RTT p50/p99 recorded

**Self-check:** What is `user_data` for? What happens if you never call `io_uring_cqe_seen`?

### Day 13 · Codec, multiplexing and fuzzing

**Goal:** a connection that parses a byte stream into frames, matches responses to requests, and survives hostile input.

**Why it matters:** TCP delivers bytes, not messages; this layer is where most RPC bugs and security holes live.

**Learn (60 min):** LoTI chapters on linked operations and fixed files. Read the libFuzzer tutorial (llvm.org/docs/LibFuzzer.html), "Getting started".

**Build (180 min):**

1. *(60 min)* `Connection` read state machine: `READ_HEADER` (accumulate 32 bytes) → validate → `READ_META` → `READ_PAYLOAD` → dispatch → back to `READ_HEADER`. Handles frames split across recvs and several frames in one recv.
2. *(40 min)* Request multiplexing: a per-connection map `request_id → pending call` (callback or promise). Responses complete the matching call; unknown ids are counted and dropped.
3. *(30 min)* Write queue: frames queued per connection; one in-flight send at a time per connection keeps order; vectored send (`sendmsg` with iovecs: header, meta, payload) avoids gluing buffers.
4. *(50 min)* libFuzzer target feeding random bytes into the read state machine; build with `-fsanitize=fuzzer,address`; seed corpus of valid frames. Run 30 minutes; fix every crash; save crashing inputs as regression tests.

**Files:** `rpc/include/helix/rpc/connection.h`, `rpc/src/connection.cc`, `rpc/fuzz/frame_fuzz.cc`, `rpc/fuzz/corpus/`.

**Pitfalls:** allocating `payload_len` bytes before validating it (memory exhaustion); interleaving two frames' bytes when two sends are in flight on one socket.

**Done when:**

- [ ] Tests for split frames, coalesced frames and out-of-order responses pass
- [ ] Fuzzer runs 30 min clean; corpus committed

**Self-check:** Why only one in-flight send per connection? What stops a malicious peer from making you allocate 4 GB?

### Day 14 · Registered buffers and zero-copy receive

**Goal:** a 1 GB payload lands directly in its final buffer with no `memcpy` in Helix code.

**Why it matters:** this is the "zero-copy" claim on your resume; today you make it true and provable.

**Learn (60 min):** LoTI on registered buffers and provided buffer rings; the `io_uring_register_buffers`, `io_uring_prep_read_fixed` and `io_uring_setup_buf_ring` man pages. Foundations → Zero-copy, precisely.

**Build (180 min):**

1. *(40 min)* Register a pool of buffers carved from `PageSource` (page-aligned, e.g. 64 × 4 MiB) with the ring at startup.
2. *(60 min)* Payload receive path: once the header says `payload_len = P`, ask a `Sink` for a destination buffer of P bytes (for now a plain allocation; on day 31 it becomes an object-store extent) and post `recv` straight into it, chunk by chunk, until P bytes arrive. Header and metadata use a small per-connection buffer.
3. *(30 min)* Small-message path: provided buffer ring + multishot recv for headers and small frames, to avoid one SQE per message.
4. *(50 min)* Bulk benchmark: send 1 GB as 4 MiB frames over loopback; measure GB/s; `perf record -g` and confirm no `memcpy` under Helix frames (kernel copies are expected without `send_zc`).

**Files:** `rpc/include/helix/rpc/{buffer_pool.h,sink.h}`, `rpc/src/buffer_pool.cc`, `rpc/bench/bulk_bench.cc`.

**Pitfalls:** buffer reuse before the kernel finished with it; registering more memory than `RLIMIT_MEMLOCK` allows (raise it or reduce the pool); provided-buffer-ring exhaustion (`-ENOBUFS`) under load.

**Done when:**

- [ ] 1 GB transfer verified byte-for-byte (checksum)
- [ ] Flame graph shows no `memcpy` in Helix frames; GB/s recorded

**Self-check:** Which copies remain in the path today, and which one does `send_zc` remove tomorrow?

### Day 15 · send\_zc and credit-based flow control

**Goal:** large sends skip the user-to-kernel copy, and a slow receiver can never make a sender buffer without limit.

**Why it matters:** both are needed for the object-transfer path in M4 and are favourite interview follow-ups ("what if the consumer is slow?").

**Learn (60 min):** kernel `Documentation/networking/msg_zerocopy.rst`; the `io_uring_prep_send_zc` man page (note the two completions and `IORING_CQE_F_NOTIF`). Foundations → Flow control and backpressure.

**Build (180 min):**

1. *(60 min)* Send path: payloads ≥ `send_zc_min_bytes` use `io_uring_prep_send_zc`; keep the buffer alive (refcount) until the notification CQE arrives, then release it. Smaller ones use normal send.
2. *(60 min)* Credits per connection (Spec §3, §5.4): `HELLO_ACK` grants `initial_credit_bytes`; the sender subtracts payload bytes and queues frames when credit is zero; the receiver sends `CREDIT` after consuming each chunk. Count stalls in `helix_rpc_credit_stalls_total`.
3. *(60 min)* Benchmark B7: throughput vs payload size (4 KB → 64 MB), with and without `send_zc`; find the crossover size and set the default from it. Slow-consumer test: receiver sleeps 1 ms per chunk; sender's memory must stay below `initial_credit + one chunk`.

**Files:** `rpc/src/send_path.cc`, `rpc/include/helix/rpc/flow_control.h`, tests, `docs/benchmarks/b7-bulk.md`.

**Pitfalls:** reusing a `send_zc` buffer after the first CQE but before the notification (silent data corruption); deadlock when both sides wait for credit and neither reads (credits must never be needed to read).

**Done when:**

- [ ] Crossover size measured and set as the default
- [ ] Slow-consumer test proves bounded memory
- [ ] Corruption test (checksummed payloads under load) passes

**Self-check:** Why does `send_zc` produce two completions? What happens when credit hits zero?

### Day 16 · Client API, deadlines, epoll fallback

**Goal:** a clean async API that the worker will use, with deadlines and cancellation, and a fallback transport for kernels without io\_uring.

**Why it matters:** M4 code should never touch SQEs; it calls `client.fetch()` and gets a future.

**Learn (60 min):** Kalia et al., "Datacenter RPCs can be General and Fast" (eRPC, NSDI 2019), sections 1–4 (skim). Foundations → RPC semantics.

**Build (180 min):**

1. *(60 min)* `Client::call()` and `Client::fetch()` returning a small `Future<T>` (promise/future pair with a callback, completed on the I/O thread). Calls from other threads are handed to the I/O thread through an MPSC queue plus an `eventfd` wake-up registered with the ring.
2. *(30 min)* Deadlines: the `DEADLINE` flag (Spec §3); the client times out pending calls with a timer wheel or `IORING_OP_TIMEOUT`; the server drops expired requests. `CANCEL` frames cancel server-side work.
3. *(60 min)* `EpollTransport` implementing the same `Transport` interface (readiness loop with nonblocking sockets). Select by config. Run the whole rpc test suite against both.
4. *(30 min)* Demo: process A creates a 256 MB tensor; process B calls `fetch()` and verifies the checksum.

**Files:** `rpc/include/helix/rpc/{client.h,server.h,future.h,transport.h}`, `rpc/src/epoll_transport.cc`, `rpc/tools/tensor_demo.cc`.

**Pitfalls:** completing a future on the I/O thread and running heavy work in its callback (blocks the loop: hand off to the pool); deadline clocks differing between hosts (send remaining time, not absolute wall time).

**Done when:**

- [ ] All rpc tests pass on both transports
- [ ] Deadline and cancel tests pass; tensor demo works across two processes

**Self-check:** Why must callbacks not block? How does the server know a request expired?

### Day 17 · Benchmark against gRPC; v0.2

**Goal:** a fair, reproducible latency comparison against gRPC C++, then tag v0.2.

**Why it matters:** it's your first headline comparison with an industry standard.

**Learn (60 min):** Gil Tene, "How NOT to Measure Latency" (talk, \~45 min) and the wrk2 README on coordinated omission. Spec §10 (benchmark rules).

**Build (180 min):**

1. *(50 min)* gRPC baseline in `bench/baselines/grpc/`: async C++ server with a completion queue, unary `Echo(bytes)` and a server-streaming `Fetch` that sends 1 MB chunks.
2. *(50 min)* Open-loop load generator (`bench/loadgen/`, C++ or Go): fixed request rate with Poisson gaps, latency measured from the *scheduled* send time, HdrHistogram output. Reused for every later benchmark.
3. *(50 min)* Benchmark B6 on the Mac VM (regression numbers only): 64 B echo at 10k, 50k, 100k, 200k req/s for Helix and gRPC; p50/p99/p99.9; 1 MB streaming throughput. Plot latency vs load.
4. *(30 min)* `docs/design/m2-rpc.md`; README update; tag `v0.2`.

**Pitfalls:** closed-loop clients hiding tail latency; giving gRPC fewer threads than Helix; benchmarking a Debug build of either.

**Done when:**

- [ ] Latency-vs-load chart and table committed with environment info
- [ ] Design doc explains *why* the numbers differ (with perf evidence)
- [ ] `v0.2` tagged

**Self-check:** What is coordinated omission, and how does your load generator avoid it? Where does gRPC spend time that Helix doesn't?

### Day 18 · Buffer day

**Goal:** nothing from M1–M2 left open, and the distributed-systems basics loaded before Raft.

**Use it for, in this order:**

1. Any unfinished "Done when" item from days 1–17.
2. `docs/adr/0003-io-uring-with-epoll-fallback.md`.
3. Read Foundations → Distributed systems basics and Storage basics; answer self-check questions 17–26 out loud.
4. Draft blog post 1 ("Finding false sharing in a work-stealing pool" or "Zero-copy receive with io\_uring") from your notes and postmortems.
5. Weekend system-design practice: "design a distributed lock service" (45 minutes, timed).

**Done when:**

- [ ] Every day 1–17 Status is Done (or moved to an issue with a reason)
- [ ] ADR-0003 merged; blog draft exists


## Days 19–28 · M3 Raft control plane

By day 28 a 3-replica Go metadata service, built on your own Raft, survives leader crashes and partitions with linearizable results, tagged v0.3.

### Day 19 · Raft state and leader election

**Goal:** three in-process Raft nodes elect exactly one leader and re-elect after it stops.

**Why it matters:** election is where most Raft bugs start; a clean state struct and event loop make every later day easier.

**Learn (60 min):** Ongaro & Ousterhout, "In Search of an Understandable Consensus Algorithm" (Raft), the whole paper, with Figure 2 printed beside you. Watch an election in the raft.github.io visualization.

**Build (180 min):**

1. *(40 min)* `meta/raft`: `type Raft struct` with persistent state (`currentTerm`, `votedFor`, `log []Entry`) and volatile state (`commitIndex`, `lastApplied`, role, leader id). One mutex guards it; all RPC handlers and timers take it.
2. *(30 min)* A `Transport` interface (`RequestVote`, `AppendEntries`, later `InstallSnapshot`) so tests can use a simulated network and production can use gRPC.
3. *(70 min)* Election: a ticker goroutine checks `time.Since(lastHeard) > electionTimeout` (randomized 150–300 ms, re-randomized each time). Candidate: term++, vote for self, send `RequestVote` in parallel, become leader on a majority, step down on any reply with a higher term. Voter rules exactly as Figure 2, including the up-to-date log check.
4. *(20 min)* Leader sends empty `AppendEntries` heartbeats every 50 ms.
5. *(20 min)* First test with a trivial in-memory transport: one leader within 1 s; stop the leader; a new one within 1 s; never two leaders in the same term (check every 10 ms).

**Files:** `meta/raft/{raft.go,state.go,election.go,transport.go}`, `meta/raft/election_test.go`.

**Pitfalls:** holding the mutex while making an RPC (deadlock); not resetting the election timer when granting a vote; counting votes from an older term.

**Done when:**

- [ ] Election test passes 100 runs with `-race`
- [ ] At most one leader per term, checked continuously

**Self-check:** Why randomize timeouts? When exactly does a follower reset its election timer?

### Day 20 · Simulated network and election tests

**Goal:** a deterministic test network that can drop, delay, reorder and partition messages, and the election tests running on it.

**Why it matters:** you can't test consensus without controlling the network. This harness finds bugs for the rest of M3.

**Learn (60 min):** "Students' Guide to Raft" (thesquareplanet.com blog, by Jon Gjengset). Note every bug it lists; you'll check yourself against them.

**Build (180 min):**

1. *(90 min)* `meta/sim`: a `Network` that implements `Transport` for N nodes; per-link settings for drop probability, delay range and reordering; `Partition(groups...)`, `Heal()`, `Disconnect(node)`; a seeded RNG so a failing seed replays.
2. *(30 min)* `Cluster` helper: start N nodes, `CheckOneLeader()`, `CheckNoLeader()`, `CheckTerms()`, crash/restart a node (state in memory for now).
3. *(60 min)* Tests (porting the spirit of MIT 6.5840's election tests): initial election; re-election after leader disconnect; no leader without a majority; many elections with nodes flapping; unreliable network (10% drop).

**Files:** `meta/sim/{network.go,cluster.go}`, `meta/raft/election_test.go` (expanded).

**Pitfalls:** tests relying on real sleeps that are too short on a loaded CI machine (use generous bounds and poll); nondeterminism from Go map iteration in the simulator.

**Done when:**

- [ ] All election tests pass 100 runs with `-race`, plus 500 seeds in a nightly job
- [ ] A failing seed can be replayed with `HELIX_SEED`

**Self-check:** Which of the Students' Guide bugs did you have? How does your sim make a failure reproducible?

### Day 21 · Log replication and commit

**Goal:** the leader replicates commands; every node applies the same commands in the same order.

**Why it matters:** this is the core of the replicated metadata service.

**Learn (60 min):** Raft paper §5.3 (log replication) and §5.4 (safety), again, slowly. Foundations → Consensus and Raft.

**Build (180 min):**

1. *(30 min)* `Propose(cmd)`: leader appends `{term, index, cmd}` and returns (index, term). Followers return `ErrNotLeader`.
2. *(70 min)* Replication: per-follower `nextIndex`/`matchIndex`; `AppendEntries(prevIndex, prevTerm, entries, leaderCommit)`; follower checks the prev entry, deletes conflicting entries, appends, updates `commitIndex = min(leaderCommit, last new index)`.
3. *(40 min)* Commit rule: leader advances `commitIndex` to the highest N replicated on a majority **with `log[N].term == currentTerm`**.
4. *(20 min)* Applier goroutine sends `ApplyMsg` for `lastApplied+1..commitIndex` on `ApplyCh`, in order, without holding the mutex while sending.
5. *(20 min)* Tests: basic agreement; agreement despite a disconnected follower; no agreement without a majority; rejoin of a partitioned leader.

**Files:** `meta/raft/{replicate.go,apply.go}`, `meta/raft/replication_test.go`.

**Pitfalls:** sending on `ApplyCh` while holding the lock (deadlock with the consumer); truncating the log when entries merely *match* (only truncate on a conflict); committing old-term entries by counting.

**Done when:**

- [ ] Basic replication tests pass 100 runs with `-race`

**Self-check:** Why can't the leader commit an entry from an earlier term by counting replicas? (Figure 8 of the paper.)

### Day 22 · Hard replication cases and fast backtracking

**Goal:** replication survives conflicting logs, lagging followers and an unreliable network, quickly.

**Why it matters:** these are the cases that break naive implementations and the ones interviewers probe.

**Learn (60 min):** the 6.5840 Raft lab notes on the "accelerated log backtracking" optimization (XTerm, XIndex, XLen). Foundations → Storage basics (prepares tomorrow).

**Build (180 min):**

1. *(60 min)* Fast backtracking: on rejection, the follower returns the conflicting term and the first index of that term (or its log length); the leader jumps `nextIndex` accordingly instead of decrementing by one.
2. *(40 min)* Pipelining and batching: send up to 256 entries per `AppendEntries`; don't wait for one reply before sending the next batch to the same follower (but cap in-flight batches).
3. *(80 min)* Tests: figure-8 scenario; leader backs up quickly over many divergent entries (e.g. 50 conflicting entries in < 10 RPCs); unreliable network with churn (random crashes, partitions, 25% drop) for 30 s with a final consistency check across all applied logs.

**Files:** `meta/raft/replicate.go` (extended), `meta/raft/churn_test.go`.

**Pitfalls:** out-of-order replies when pipelining (ignore replies that refer to a stale `nextIndex` or term); applying the same index twice after a reconnect.

**Done when:**

- [ ] All replication and churn tests pass 200 runs with `-race`
- [ ] Backtracking test shows the RPC count dropping vs one-at-a-time

**Self-check:** Walk through the figure-8 scenario. How does the leader handle a reply that arrives after it already moved `nextIndex`?

### Day 23 · WAL and crash recovery

**Goal:** Raft's persistent state survives `kill -9` at any moment, and torn writes are handled.

**Why it matters:** without durable state Raft's safety argument doesn't hold; a node that forgets its vote can elect two leaders.

**Learn (60 min):** *Designing Data-Intensive Applications* ch. 3 ("Data structures that power your database", the log parts). Foundations → Storage basics: the write path and WAL sections.

**Build (180 min):**

1. *(70 min)* `meta/wal`: segmented log files (64 MiB), records `[len u32][crc32c u32][type u8][payload]`; record types: `Entry`, `HardState{term, votedFor, commit}`, `SnapshotMarker`. `Append(records...)` writes; `Sync()` calls `fdatasync`. New segment: create, fsync the file and the directory.
2. *(40 min)* Group commit: proposals and votes collect for up to `max_batch_wait_us` or `max_batch_entries`, one `Sync()` covers them, then replies go out. Rule: persist before replying to any RPC that depends on the state (vote granted, entries accepted).
3. *(40 min)* Recovery: read segments in order; stop at the first bad length or CRC, truncate the file there; rebuild `currentTerm`, `votedFor` and the log.
4. *(30 min)* Fault-injecting file interface for tests: fail writes, fail `fsync`, crash after N bytes. Tests: torn tail, failing `fsync` stops the node rather than replying, restart preserves term and vote, and the 6.5840-style persistence tests (crash and restart nodes during churn).

**Files:** `meta/wal/{wal.go,segment.go,record.go,recover.go,faultfs.go}`, tests.

**Pitfalls:** replying "vote granted" before the vote is on disk; forgetting to fsync the directory after creating a segment; treating an fsync error as retryable (the kernel may have dropped the dirty pages; stop the node instead).

**Done when:**

- [ ] Persistence tests pass 200 runs with `-race`
- [ ] Torn-tail and fsync-failure tests pass
- [ ] Commit latency with and without batching recorded

**Self-check:** Which three fields must be durable before Raft replies, and why each?

### Day 24 · Snapshots and log compaction

**Goal:** the log stays bounded; a far-behind follower catches up from a snapshot.

**Why it matters:** without compaction the WAL grows forever and restarts replay everything.

**Learn (60 min):** Ongaro's PhD thesis, chapter 5 (log compaction). Foundations → Snapshots.

**Build (180 min):**

1. *(50 min)* `Snapshot(index, data)`: the state machine calls it every `snapshot_every_entries`; Raft writes the snapshot file with the tmp → fsync → rename → fsync-dir pattern, records `lastIncludedIndex/Term`, drops in-memory entries ≤ index, deletes WAL segments fully covered.
2. *(60 min)* `InstallSnapshot` RPC (single message is fine at this size; chunk if > 4 MiB): leader sends it when `nextIndex` ≤ `lastIncludedIndex`; follower replaces its state, keeps any log entries after the snapshot that match, and sends the snapshot to the state machine via `ApplyCh`.
3. *(20 min)* Restart path: load latest snapshot, restore the state machine, then replay WAL entries after it.
4. *(50 min)* Tests: snapshot under churn; a follower disconnected for 5,000 entries catches up via snapshot; crash during snapshot write (old snapshot still valid); index arithmetic with offsets (all log access goes through helper functions).

**Files:** `meta/raft/snapshot.go`, `meta/wal/snapshot.go`, tests.

**Pitfalls:** off-by-one errors converting between log positions and Raft indexes after compaction (centralize them); applying a snapshot older than what the state machine already has.

**Done when:**

- [ ] Snapshot tests pass 200 runs; WAL size stays bounded in a 10-minute churn run

**Self-check:** What happens if the leader has already discarded the entries a follower needs?

### Day 25 · PreVote, CheckQuorum, and the metadata state machine

**Goal:** a robust leader, plus the Helix state machine (nodes, jobs, tasks, objects, leases) running on Raft.

**Why it matters:** this is where Raft becomes Helix's control plane, and where fencing tokens are born.

**Learn (60 min):** Ongaro thesis §9.6 (PreVote) and the CheckQuorum discussion. Foundations → Leases and fencing tokens. Spec §4 (data model) end to end.

**Build (180 min):**

1. *(40 min)* PreVote: before an election, send `PreVote(term+1, lastLogIndex, lastLogTerm)`; only if a majority would vote does the node increment its term. CheckQuorum: a leader that hasn't heard from a majority within an election timeout steps down.
2. *(80 min)* `meta/sm`: tables from Spec §4 in Go maps; commands as protobuf messages (`proto/meta.proto`); `Apply` switch per command implementing the task-lifecycle transitions exactly as the Spec table; `Snapshot()`/`Restore()` with deterministic encoding (sort keys).
3. *(20 min)* Fencing: `GrantLease` stores the entry's Raft index as the token; `CompleteTask` with any other token returns `STALE_TOKEN`; `SubmitJob` deduplicates by request id.
4. *(40 min)* Tests: one per row of the task-lifecycle table; determinism test (apply the same commands to two machines, compare snapshots byte for byte); partitioned leader steps down (CheckQuorum); a rejoining node doesn't disrupt the cluster (PreVote).

**Files:** `meta/raft/prevote.go`, `meta/sm/{sm.go,tables.go,apply.go,snapshot.go}`, `proto/meta.proto`, tests.

**Pitfalls:** reading the clock or doing I/O inside `Apply` (replicas diverge); iterating Go maps when encoding snapshots (random order breaks byte comparison).

**Done when:**

- [ ] Every lifecycle transition has a passing test
- [ ] Determinism test passes; PreVote and CheckQuorum tests pass 100 runs

**Self-check:** Why must `Apply` be deterministic? Where exactly does the fencing token come from, and why is it monotonic?

### Day 26 · Linearizability checking with Porcupine

**Goal:** mechanical proof, over thousands of random histories, that helix-meta's API is linearizable under partitions and crashes.

**Why it matters:** "my tests pass" isn't evidence for a distributed system; a checked history is. This is a strong interview story.

**Learn (60 min):** the Porcupine README and its example models (github.com/anishathalye/porcupine). *DDIA* ch. 9, "Linearizability". Foundations → Linearizability.

**Build (180 min):**

1. *(40 min)* Linearizable reads: `ReadBarrier()` = the leader records `commitIndex`, confirms it is still leader with one heartbeat round to a majority (ReadIndex), waits until `lastApplied ≥` that index, then serves the read.
2. *(50 min)* A small client API over the state machine for testing: `Submit`, `GetJob`, `CompleteTask`. Clients retry on `NOT_LEADER` and timeouts with the same request id.
3. *(50 min)* History recorder: each client operation logs (client, input, output, start time, end time). Porcupine model for a job table: `Submit` is idempotent by request id, `GetJob` returns the latest state.
4. *(40 min)* Test: 5 clients, 1,000 operations, random partitions every 200 ms, random crashes; check the history. Run 50 seeds; visualize any failure with Porcupine's HTML output.

**Files:** `meta/raft/read.go`, `meta/sm/client.go`, `meta/test/linearizability_test.go`.

**Pitfalls:** serving reads from a deposed leader (exactly what ReadIndex prevents); counting a timed-out operation as "did not happen" (it may have happened: model it as possibly completed, with an open end time).

**Done when:**

- [ ] 50 seeds × 1,000 operations all linearizable
- [ ] Disabling ReadIndex produces a Porcupine failure you can explain

**Self-check:** Why can a leader that believes it's leader still serve a stale read? How do you model a request whose response was lost?

### Day 27 · helix-meta as a real service

**Goal:** three helix-meta replicas in docker compose, reachable over gRPC, with worker registration and heartbeats, and leader failover under 1 s.

**Why it matters:** this is the control plane M4 workers will talk to.

**Learn (60 min):** Hayashibara et al., "The φ Accrual Failure Detector" (skim). gRPC Go basics: server streaming, deadlines, `status` codes.

**Build (180 min):**

1. *(50 min)* gRPC transport for Raft between replicas (`proto/raft.proto`, port 7100), implementing the same `Transport` interface the simulator uses.
2. *(50 min)* `cmd/helix-meta`: config file + flags (Spec §7), WAL directory, gRPC API on 7000 (`Cluster`, `Jobs`, `Tasks`, `Objects` services from Spec §2), `NOT_LEADER` redirects, `/metrics` on 9100 with the `helix_raft_*` metrics.
3. *(30 min)* Node registration and heartbeats: `RegisterNode` goes through Raft; heartbeats update leader memory only; a background loop marks nodes `SUSPECT`/`DEAD` via Raft commands (Spec §4).
4. *(20 min)* `cmd/helixctl`: `status`, `nodes`, `submit <dag.json>`, `job <id>`, `leader`.
5. *(30 min)* `deploy/docker-compose.yml` with 3 replicas; `make cluster-up`. Failover drill: `docker kill` the leader while `helixctl` submits in a loop; measure the gap.

**Files:** `meta/raft/grpc_transport.go`, `meta/api/*.go`, `meta/cmd/helix-meta/main.go`, `meta/cmd/helixctl/main.go`, `proto/{raft,meta}.proto`, `deploy/docker-compose.yml`, `deploy/Dockerfile.meta`.

**Pitfalls:** gRPC calls without deadlines hanging forever during partitions; containers sharing one WAL volume; heartbeats through Raft (it works but floods the log).

**Done when:**

- [ ] Kill the leader: a new leader in < 1 s; `helixctl submit` resumes; no acknowledged job is lost
- [ ] Restart all three replicas: state is intact

**Self-check:** Why aren't heartbeats Raft writes? What happens to a worker's leases while the leader changes?

### Day 28 · Buffer day; M3 design doc; v0.3

**Goal:** M3 finished, documented and tagged.

**Use it for, in this order:**

1. Unfinished "Done when" items from days 19–27.
2. `docs/design/m3-control-plane.md`: Raft design, persistence, snapshots, PreVote/CheckQuorum, ReadIndex, state machine, test results (seed counts, Porcupine runs, failover time).
3. `docs/adr/0004-raft-from-scratch-wal-snapshots.md` (why not etcd/raft; why WAL + snapshot instead of an LSM for now).
4. One postmortem of the hardest Raft bug you hit (symptom, how the simulator found it, root cause, fix).
5. Tag `v0.3`; update the README.
6. Weekend system-design practice: "design a metadata service for a distributed file system".

**Done when:**

- [ ] Design doc, ADR and postmortem merged
- [ ] `v0.3` tagged with nightly chaos/seed jobs green


## Days 29–38 · M4 scheduler and execution

By day 38 Helix runs DAGs across 3 workers, balances load, and finishes jobs even when you kill a worker mid-run, tagged v0.4.

### Day 29 · helixd worker: register, lease, run

**Goal:** a C++ worker daemon that registers with helix-meta, receives a lease, runs the task on the M1 pool and reports completion.

**Why it matters:** it joins the C++ runtime (M1, M2) to the Go control plane (M3) for the first time.

**Learn (60 min):** Moritz et al., "Ray: A Distributed Framework for Emerging AI Applications" (OSDI 2018), §4 (architecture: global control store, bottom-up scheduling, object store). Spec §5.2–5.3 (lease and execution protocols).

**Build (180 min):**

1. *(50 min)* `MetaClient` (gRPC C++): `RegisterNode` (cores, memory, store capacity, data port), a `WatchLeases` stream reader thread, `Heartbeat` every `renew_every_ms` listing running tasks, `Complete`/`Fail`. Handles `NOT_LEADER` by reconnecting to the named leader.
2. *(40 min)* `Executor`: a kernel registry (`"matmul_tile"`, `"add"`, `"softmax"`, `"noop"`) mapping names to functions; a lease becomes a task on the pool; outputs go into plain buffers today (the store arrives tomorrow).
3. *(30 min)* `LeaseManager`: tracks running leases; cancels tasks whose lease it can't renew for `lease_ttl` (Spec §5.2 step 7).
4. *(20 min)* Leader side: a minimal scheduler that assigns each `READY` task to a random `ALIVE` node via `GrantLease` (the real scoring comes on day 32).
5. *(40 min)* Compose: add 3 `helixd` containers. Test: `helixctl submit` a one-task job (`noop`) and a 10-task independent job; all complete; `helixctl job` shows `SUCCEEDED`.

**Files:** `worker/src/{main.cc,meta_client.cc,executor.cc,lease_manager.cc}`, `worker/include/helix/worker/*.h`, `meta/sched/random.go`, `deploy/Dockerfile.worker`.

**Pitfalls:** the gRPC stream thread calling into the pool and blocking it; forgetting to resend the fencing token with `Complete`; worker clocks used to decide expiry (only the leader decides).

**Done when:**

- [ ] Jobs complete end to end in compose
- [ ] Restarting a worker re-registers it with a new NodeId

**Self-check:** Which component decides that a lease expired, and why not the worker?

### Day 30 · Object store: mmap extents, seal, refcounts, eviction

**Goal:** a per-node object store where tensors are written once, sealed, read by reference, and evicted when unused.

**Why it matters:** it's the bridge between tasks, and the memory-mapped storage domain of the project.

**Learn (60 min):** Apache Arrow Plasma design notes or Ray's object store docs ("object store memory", immutability, pinning). Foundations → mmap. Spec §2 (helix-store API).

**Build (180 min):**

1. *(50 min)* Region: `memfd_create` + `ftruncate(capacity)` + `mmap(MAP_SHARED)`; an extent allocator with 4 KiB alignment (a free list of ranges, best-fit, coalescing on free). A `memfd` lets another process map the same memory later (stretch: shared-memory transport).
2. *(50 min)* Object table: `ObjectId → {offset, size, state, refcount, last_used}` under a mutex (fine at task granularity). `create` → `CREATING`; `seal(id, token)` → `SEALED` (rejects a lower token than any previously sealed for that id); `get` returns an RAII `ObjectRef` that increments/decrements the refcount; `abort` frees a `CREATING` object.
3. *(30 min)* Eviction: when `create` can't find space, evict `SEALED` objects with refcount 0 in LRU order until it fits; otherwise return `RESOURCE_EXHAUSTED`.
4. *(20 min)* Executor writes outputs straight into `create()` buffers and seals them before `Complete`.
5. *(30 min)* Tests: create/seal/get lifecycle; get before seal fails; eviction under pressure never evicts a referenced object; stale token rejected; 8-thread stress under TSan. Benchmark put/get latency and fragmentation after 1 M random-size operations.

**Files:** `store/include/helix/store/{object_store.h,extent_allocator.h,object_id.h}`, `store/src/*.cc`, tests, bench.

**Pitfalls:** evicting an object a fetch is currently streaming (the server must hold a reference while sending); fragmentation making large creates fail even with enough total free space (record it; compaction is a stretch).

**Done when:**

- [ ] All store tests pass under TSan and ASan
- [ ] Worker uses the store for every task output

**Self-check:** Why are objects immutable after sealing? What prevents an object being evicted while in use?

### Day 31 · Remote fetch and the object directory

**Goal:** a task on node B consumes an object produced on node A, transferred zero-copy into B's store.

**Why it matters:** this connects M2's transport to M4's store: the full data path.

**Learn (60 min):** Spec §5.4 (object fetch) end to end; re-read your `m2-rpc.md` design doc.

**Build (180 min):**

1. *(50 min)* `DataServer` on each worker (port 7200): handles `FETCH_OBJECT` by pinning the object and streaming `OBJECT_DATA` chunks from its mmap extent (`send_zc` for large chunks), within the client's credit.
2. *(50 min)* `Fetcher`: `Objects.Locate` (cached), pick a location, `client.fetch(id, sink)` where the sink is a `store.create()` extent, seal on `END_STREAM`, then report `AddObjectLocation` (batched every 100 ms).
3. *(30 min)* Meta side: `CompleteTask` records the producer as the first location; `AddObjectLocation` adds replicas; `Locate` returns all locations.
4. *(20 min)* Executor: before running, ensure all inputs are local (fetch missing ones in parallel), pin them, run, unpin.
5. *(30 min)* Test in compose: a 2-task DAG (`produce 256 MB` on A → `checksum` forced onto B); fetch interrupted by killing A mid-transfer falls back correctly (to a replica if any, else lineage on day 34).

**Files:** `worker/src/{data_server.cc,fetcher.cc}`, `meta/sm/objects.go`, tests.

**Pitfalls:** sealing a partially received object on connection loss (abort it); fetching the same object twice concurrently on one node (deduplicate in-flight fetches).

**Done when:**

- [ ] Cross-node DAG passes with checksum verification
- [ ] Concurrent requests for one object trigger a single fetch

**Self-check:** Trace every buffer the 256 MB object passes through from A's store to B's store.

### Day 32 · Global scheduler with locality scoring

**Goal:** DAGs run across 3 workers, with each task placed where most of its input bytes already are.

**Why it matters:** placement is the main lever for performance in a distributed runtime and a classic system-design topic.

**Learn (60 min):** Verma et al., "Large-scale cluster management at Google with Borg" (EuroSys 2015), §3 (scheduling: feasibility and scoring). Mitzenmacher, "The Power of Two Choices in Randomized Load Balancing" (abstract and intro). Spec §5.6.

**Build (180 min):**

1. *(30 min)* DAG submission format (`dag.json`): tasks with kernel, params, inputs (task index + output index, or an existing ObjectId); validation in the leader (acyclic, references valid).
2. *(60 min)* `meta/sched`: every `tick_ms`, collect `READY` tasks; for each, compute locality per node from the object directory; score the best-locality node plus 2 random `ALIVE` nodes with Spec §5.6's formula using reported queue depth and free store; propose `GrantLease` commands in one batch.
3. *(30 min)* Workers report queue depth and free store bytes in each heartbeat; the leader keeps them in memory.
4. *(40 min)* Tiled matmul DAG generator in `helixctl` (`helixctl matmul --n 4096 --tile 1024`): load tiles, multiply-accumulate tasks, a final gather. Run it across 3 workers; verify against a single-node result.
5. *(20 min)* Metrics: `helix_sched_decision_duration_seconds`, `helix_sched_tasks_ready`; record bytes fetched with locality on vs off.

**Files:** `meta/sched/{scheduler.go,score.go,dag.go}`, `meta/cmd/helixctl/matmul.go`, tests.

**Pitfalls:** a slow scheduler loop holding the state-machine lock; scoring stale data (heartbeat older than 2 intervals → treat the node as unknown); granting more leases than a worker can run.

**Done when:**

- [ ] Distributed matmul matches the single-node result
- [ ] Locality on reduces bytes fetched (number recorded)

**Self-check:** Why score only 3 candidates instead of all nodes? What's the risk of always picking the best-locality node?

### Day 33 · Load balancing with spillback

**Goal:** under a skewed workload, no worker drowns while others idle.

**Why it matters:** locality and balance pull in opposite directions; showing you handled the trade-off with data is a strong signal.

**Learn (60 min):** Ousterhout et al., "Sparrow: Distributed, Low Latency Scheduling" (SOSP 2013), sections 1–4 (skim): batch sampling and late binding.

**Build (180 min):**

1. *(50 min)* Worker spillback: when the local queue exceeds `spillback_threshold`, reject new leases with `RESOURCE_EXHAUSTED`; the leader expires the lease immediately without counting an attempt and re-places the task excluding that node for 1 s.
2. *(30 min)* Weight tuning: make score weights configurable and log every decision's components at debug level.
3. *(70 min)* Skew benchmark: one worker holds all input objects (worst case for locality); run 1,000 tasks; measure max/mean queue depth over time and total job time with spillback off and on, and with two weight settings. Plot it.
4. *(30 min)* Write the trade-off up in `docs/benchmarks/skew.md`.

**Files:** `worker/src/lease_manager.cc` (spillback), `meta/sched/score.go`, `bench/skew/`.

**Pitfalls:** spillback ping-pong between two overloaded nodes (the exclusion window prevents it); measuring imbalance only at the end instead of over time.

**Done when:**

- [ ] Imbalance (max/mean queue depth) < 1.3 within 2 s with spillback on
- [ ] Chart and write-up committed

**Self-check:** When is it better to move the data to the compute, and when the compute to the data?

### Day 34 · Fault tolerance: leases, fencing, lineage

**Goal:** `kill -9` a worker mid-job and the job still completes with the correct result.

**Why it matters:** this is the headline demo and the core of the AI-infrastructure story.

**Learn (60 min):** Zaharia et al., "Resilient Distributed Datasets" (NSDI 2012), the lineage and fault-recovery sections. Spec §5.5 and §6.

**Build (180 min):**

1. *(40 min)* Dead-node handling on the leader: `MarkNodeState(DEAD)` → `ExpireLease` for its leases and `RemoveObjectLocation` for its objects, in one batch.
2. *(60 min)* Lineage: when a needed object has zero locations, mark it `LOST`; set its producer task back to `READY` (attempt++); recursively do the same for the producer's own lost inputs. Dependents wait in `PENDING` until it's sealed again.
3. *(30 min)* Worker side: `STALE_TOKEN` on `Complete` → abort local outputs; store `seal` rejects lower tokens.
4. *(50 min)* Tests: kill a worker holding intermediate results of the matmul DAG → job completes and matches; `SIGSTOP` a worker for 15 s then `SIGCONT` → its late completions are rejected; kill two of three workers sequentially. Record recovery time (B9) from the Perfetto trace later; for now from logs.

**Files:** `meta/sm/recovery.go`, `meta/sched/lineage.go`, `worker/src/executor.cc`, `test/chaos/{kill_worker.sh,pause_worker.sh}`.

**Pitfalls:** infinite reconstruction loops when an input was a client-provided object (can't be recomputed: fail the job with a clear error); double-counting attempts on spillback.

**Done when:**

- [ ] kill -9 test passes 20 times in a row with correct checksums
- [ ] Pause test proves stale completions are rejected

**Self-check:** Walk through, step by step, what happens in the 15 seconds after `kill -9`.

### Day 35 · Chaos harness

**Goal:** an automated chaos run that randomly kills, pauses and partitions nodes and checks every result.

**Why it matters:** it turns "I think recovery works" into evidence, and runs nightly from now on.

**Learn (60 min):** read one Jepsen analysis (jepsen.io/analyses, e.g. etcd or a database you know) for how faults and checks are structured.

**Build (180 min):**

1. *(60 min)* `test/chaos/run.py` (or Go): loops for N minutes; every 5–20 s picks a fault: `docker kill` a worker, `docker pause`/`unpause`, `tc netem` loss/delay on a container, an `iptables` partition between a worker and meta, kill the meta leader. Heals each fault after a random duration.
2. *(40 min)* Workload: continuously submit matmul and random DAGs with known expected checksums; record job outcomes.
3. *(40 min)* Checker: every succeeded job's result matches; no job stuck longer than 60 s after faults heal; metadata history from helix-meta passes Porcupine.
4. *(40 min)* Run 20 chaos runs of 10 minutes; fix what breaks; add a nightly CI job (shorter runs).

**Files:** `test/chaos/{run.py,faults.py,checker.py}`, `.github/workflows/nightly.yml`.

**Pitfalls:** faults left in place after a run (always heal in a `finally`); `tc` needing `NET_ADMIN` capability in the container.

**Done when:**

- [ ] 20 chaos runs, all jobs correct, none stuck
- [ ] Nightly chaos job green

**Self-check:** What does your checker not check? What fault would you add next?

### Day 36 · CUDA SGEMM on Kaggle (droppable)

**Goal:** naive and shared-memory-tiled CUDA matrix multiplies benchmarked against cuBLAS on a free T4.

**Why it matters:** it gives the NVIDIA story real GPU numbers and mirrors your CPU work from day 9.

**Learn (60 min):** Hwu, Kirk & El Hajj, *Programming Massively Parallel Processors* (4th ed.), ch. 2–5 (skim 2–3, read 4–5): threads, blocks, warps, global vs shared memory, coalescing, tiling.

**Build (180 min, in a Kaggle notebook with GPU enabled):**

1. *(20 min)* Notebook setup: `!nvidia-smi`, `!nvcc --version`; write `.cu` files with `%%writefile`, compile with `nvcc -O3 -arch=sm_75`.
2. *(40 min)* Naive kernel: one thread per C element.
3. *(60 min)* Tiled kernel: 16×16 or 32×32 tiles staged in `__shared__` memory with `__syncthreads()`; then 2×2 or 4×4 outputs per thread (register blocking).
4. *(30 min)* cuBLAS `cublasSgemm` baseline; time all three with CUDA events for N = 1024, 2048, 4096; check results against cuBLAS.
5. *(30 min)* Plot GFLOP/s; copy the notebook, CSV and chart into `docs/benchmarks/b-cuda/`; note the T4's FP32 peak (look it up on NVIDIA's T4 datasheet) and what fraction you reached.

**Pitfalls:** row-major vs cuBLAS's column-major (compute Cᵀ = BᵀAᵀ or set the transpose flags); timing the first (warm-up) launch; Kaggle sessions timing out (save often).

**Done when:**

- [ ] Correct results for all kernels; chart committed

**Self-check:** Why does shared-memory tiling help? What is memory coalescing?

### Day 37 · Request batching queue (droppable)

**Goal:** a batching queue in front of a transformer-block DAG that trades a little latency for much more throughput.

**Why it matters:** batching is the core idea of LLM serving systems (Orca, vLLM) and a frequent AI-infrastructure design question.

**Learn (60 min):** Yu et al., "Orca" (OSDI 2022), sections 1–3 (iteration-level scheduling). Skim the vLLM paper's introduction (PagedAttention as paging for the KV cache).

**Build (180 min):**

1. *(50 min)* Kernels: `layernorm`, `softmax`, `gelu`, and a simplified attention block built from your matmul (`Q·Kᵀ → softmax → ·V`), all on f32 tensors.
2. *(60 min)* `BatchingQueue` in helixd: requests (one input row each) collect until `max_batch` rows or `max_wait_us`, then one batched DAG runs and results are split back to the waiting callers.
3. *(70 min)* Benchmark: open-loop requests at increasing rates; plot throughput and p99 latency for `max_batch` = 1, 8, 32 and two wait times.

**Files:** `core/src/kernels/{layernorm,softmax,attention}.cc`, `worker/src/batching_queue.cc`, `bench/batching/`.

**Pitfalls:** a batch timer that only fires when a new request arrives (requests strand under light load); mixing sequence lengths without padding or masking.

**Done when:**

- [ ] Throughput vs batch-size chart committed with the latency trade-off explained

**Self-check:** What does continuous (iteration-level) batching improve over static batching?

### Day 38 · Buffer day; M4 design doc; v0.4

**Goal:** M4 finished, documented and tagged; every row of Spec §6 has a passing test.

**Use it for, in this order:**

1. Unfinished "Done when" items from days 29–35 (36–37 are droppable).
2. Check Spec §6: each failure row has a named, passing test; add missing ones.
3. `docs/design/m4-execution.md`: worker, store, fetch, scheduler, spillback, recovery, measured results.
4. ADRs: `0005-lineage-over-checkpointing.md`, `0006-two-level-scheduling.md`.
5. Postmortem of the hardest recovery bug.
6. Tag `v0.4`; README update with the kill -9 demo steps.
7. Weekend system-design practice: "design a distributed task scheduler for ML jobs" (compare with the Foundations case study).

**Done when:**

- [ ] Design doc, 2 ADRs, postmortem merged
- [ ] `v0.4` tagged; nightly chaos green


## Days 39–45 · M5 observability, benchmarks, release

By day 45 Helix is public as v0.5, with measured comparisons against gRPC and Ray, a recovery demo video and documentation a stranger can follow.

### Day 39 · Metrics: per-thread histograms and Prometheus

**Goal:** every metric in Spec §8 exported from helixd and helix-meta, visible in Prometheus and Grafana via compose.

**Why it matters:** you'll use these numbers in every remaining day, and "how did you observe it?" is a standard interview follow-up.

**Learn (60 min):** Dean & Barroso, "The Tail at Scale" (CACM 2013). The Prometheus exposition format docs and "histograms and summaries" page.

**Build (180 min):**

1. *(60 min)* C++ telemetry library: per-thread counters and HdrHistograms registered in a global registry; a collector thread merges them every second into snapshots (no shared atomics on the hot path). Text exposition on `/metrics` (port 9200) via a tiny HTTP responder on its own thread.
2. *(40 min)* Wire the metrics: core (tasks, steals, parks, queue depth), rpc (frames, bytes, request duration, credit stalls), store (bytes, evictions, fetch duration), worker (task duration, queue wait, spillbacks).
3. *(30 min)* Go side: `client_golang` histograms and gauges for `helix_raft_*`, `helix_sched_*`, `helix_job_*`, `helix_lease_*` on port 9100.
4. *(30 min)* Compose: add Prometheus (scrape all containers every 2 s) and Grafana with one provisioned dashboard: task throughput, p99 task latency, queue depth per worker, Raft commit p99, leader, lease expirations.
5. *(20 min)* Overhead check: run B3 with metrics on and off; overhead must be < 3%.

**Files:** `core/include/helix/telemetry/{registry.h,histogram.h,exporter.h}`, `meta/metrics/*.go`, `deploy/{prometheus.yml,grafana/}`.

**Pitfalls:** labels with unbounded values; histogram buckets that hide the tail (HdrHistogram avoids this; when exporting Prometheus buckets, include 1µs–10s log-spaced bounds).

**Done when:**

- [ ] Grafana dashboard shows live data during a matmul job
- [ ] Metrics overhead < 3% (measured)

**Self-check:** Why per-thread histograms instead of one shared one? Why does p99 matter more than the mean for a fan-out job?

### Day 40 · Tracing and the flight recorder

**Goal:** one job's life (submit → place → fetch → run → complete), including a recovery, visible on one timeline.

**Why it matters:** the Perfetto timeline of a `kill -9` recovery is your best demo artefact.

**Learn (60 min):** Sigelman et al., "Dapper" (2010), sections 1–3 (skim). The Perfetto docs on the JSON trace-event format (`ph`, `ts`, `dur`, `pid`, `tid`).

**Build (180 min):**

1. *(50 min)* Trace context: 16-byte trace id + 8-byte span id; carried in gRPC metadata (meta ↔ worker), in leases, and in helix-rpc frames behind the `TRACE` flag (Spec §3).
2. *(60 min)* Flight recorder: per-thread ring of 64k fixed-size events `{ts_ns, type, arg0, arg1}`; spans from Spec §8 write begin/end events; dumped as Perfetto JSON on `SIGUSR1` or crash, and by `helixctl trace <job>` which collects from all nodes.
3. *(40 min)* Go side: spans for `job.submit`, `sched.place`, `raft.commit` written in the same JSON format.
4. *(30 min)* Record the kill -9 scenario; open it in ui.perfetto.dev; screenshot it for the README; measure recovery time B9 from the trace.

**Files:** `core/include/helix/telemetry/{trace.h,flight_recorder.h}`, `meta/trace/*.go`, `meta/cmd/helixctl/trace.go`.

**Pitfalls:** clock differences between containers (they share the host clock in compose; on real machines note the skew); writing traces from a signal handler with non-async-signal-safe functions (have the handler set a flag; a thread does the dump).

**Done when:**

- [ ] Perfetto timeline of a recovery committed as a PNG; B9 recorded

**Self-check:** How does the trace id get from the client's submit to the worker that runs the task?

### Day 41 · Open-loop load generator and eBPF scripts

**Goal:** a load generator for jobs (not just RPCs) and kernel-level tools to explain tail latency.

**Why it matters:** days 42–43 depend on it; you won't have time to build tools on rented machines.

**Learn (60 min):** the wrk2 README (coordinated omission again, applied to jobs). Brendan Gregg's bpftrace one-liners tutorial; read `runqlat.bt` and `offcputime.bt`.

**Build (180 min):**

1. *(70 min)* `bench/loadgen` job mode: submits DAGs (single-task no-op, 10-task fan-out, small matmul) at a fixed rate with Poisson gaps, measures submit-to-result latency from scheduled time, writes HdrHistogram logs and CSV.
2. *(40 min)* `tools/bpf/`: `runqlat` for helixd threads, `offcputime` with stacks, TCP retransmits for Helix ports; a README for each.
3. *(40 min)* Latency-vs-throughput sweep on the Mac VM for single-task jobs; find the saturation point; use `runqlat` to explain the knee.
4. *(30 min)* `bench/run_all.sh`: runs B6, B7, B10, B11 in sequence with env capture, writes everything under `bench/results/<date>-<host>/`; a dry run on the Mac so day 42 is just "run the script".

**Files:** `bench/loadgen/*`, `tools/bpf/*.bt`, `bench/run_all.sh`.

**Pitfalls:** the load generator itself becoming the bottleneck (check its CPU; run it on a separate machine on day 42); bpftrace needing root and kernel headers in the VM.

**Done when:**

- [ ] Sweep chart committed; `run_all.sh` completes end to end on the Mac
- [ ] Terraform for the cloud machines (`deploy/terraform/`) plans successfully

**Self-check:** Where is the knee of your curve, and what resource saturates first?

### Before day 42 · Cloud prerequisites (do these by day 35)

- [ ] GCP: upgrade the trial to a paid account if needed (credit carries over) and request a CPU quota large enough for one \~80-vCPU VM plus two 8-vCPU VMs in one region. Trial accounts can't request quota increases.
- [ ] AWS fallback: request a Spot vCPU quota increase for standard instances (new accounts start low); approval can take days.
- [ ] `deploy/terraform/` creates: 1 large 2-socket VM (NUMA + RPC server), 2 small VMs (load generator, Ray/gRPC clients), same zone; startup script installs the toolchain and clones the repo at a tag.
- [ ] Budget alerts at $5 and $15.

### Day 42 · Cloud benchmarks, part 1: NUMA and RPC

**Goal:** NUMA and network numbers measured on real x86 hardware, raw data saved, machines destroyed the same day.

**Why it matters:** these are the numbers you'll publish and quote; the Mac VM can't produce them.

**Learn (60 min, before starting the machines):** Hoefler & Belli, "Scientific Benchmarking of Parallel Computing Systems" (SC 2015), the 12 rules (skim). Spec §10 again.

**Build (\~4 h of machine time):**

1. *(20 min)* `terraform apply`; on the large VM check `numactl --hardware` shows 2 nodes (if not, destroy and pick a larger or metal shape) and `lscpu`; run `bench/env.sh`.
2. *(20 min)* Build in Release with `-march=native`; add the AVX2 SGEMM path if time allows, else use OpenBLAS.
3. *(60 min)* NUMA (B11): the work-stealing pool with local-first stealing vs random stealing, data first-touched on node 0, threads on both nodes; `perf stat` IPC and `perf c2c` on the counter false-sharing experiment (now with real hardware counters). Re-run B3 and B5 at full core count.
4. *(60 min)* RPC across VMs (B6, B7): Helix vs gRPC, server on the large VM, load generator on a small VM; 64 B latency sweep and bulk throughput vs payload size, 5 runs each.
5. *(20 min)* Copy `bench/results/` back (scp or a bucket), verify the files, **`terraform destroy`**, check the console shows nothing running.

**Pitfalls:** forgetting to destroy (set a phone alarm); the load generator on the same VM as the server; comparing runs from different instance types.

**Done when:**

- [ ] Raw CSVs and env info for B3, B5, B6, B7, B11 saved in the repo
- [ ] All cloud resources destroyed

**Self-check:** How much did local-first stealing help on 2 sockets, and why?

### Day 43 · Cloud benchmarks, part 2: Helix vs Ray

**Goal:** a fair Helix vs Ray comparison on the same machines.

**Why it matters:** Ray is the industry reference for this kind of runtime; an honest comparison (including where Ray wins) is a strong portfolio piece.

**Learn (30 min):** Ray docs: "Ray Core" quick start (tasks, objects, `ray.get`); note how to start a multi-node Ray cluster manually (`ray start --head`, `ray start --address`).

**Build (\~4 h of machine time):**

1. *(20 min)* Recreate the machines; start a 3-node Helix cluster (meta on the small VMs and one on the large; workers on all) and a 3-node Ray cluster on the same hosts, not at the same time.
2. *(40 min)* Equivalent workloads in Python for Ray: (a) 100k no-op tasks; (b) fan-out 1→1000→1 with 1 MB objects; (c) the tiled matmul DAG using NumPy per tile.
3. *(80 min)* B10: throughput (tasks/s) and job latency (p50/p99) for each workload, 5 runs each, both systems; then the kill -9 recovery run for Helix (and the equivalent node-failure run in Ray if time allows).
4. *(20 min)* Generate charts with `bench/plot/` from the raw CSVs; save everything; **destroy the machines**.
5. *(20 min)* Notes: where Helix wins and why (no Python, zero-copy, simpler scheduler), where Ray wins and why (maturity, features, scaling, its object spilling), what was not comparable.

**Pitfalls:** comparing Helix C++ kernels to Ray Python tasks without saying so (state it plainly, and include a no-op test where the language matters less); Ray's first-call warm-up.

**Done when:**

- [ ] B10 charts and an honest comparison write-up committed
- [ ] All cloud resources destroyed; spend recorded in notes

**Self-check:** What would it take for Helix to beat Ray on the workload where it lost?

### Day 44 · Documentation a stranger can follow

**Goal:** a repo that reads like an open-source infrastructure project.

**Why it matters:** reviewers spend about 60 seconds on the README; this is what they see.

**Learn (30 min):** skim the READMEs of etcd, TiKV and Ray for structure. [full-proposal.md](full-proposal.md) §8 (GitHub presentation).

**Build (3.5 h):**

1. *(60 min)* README: one-line pitch, badges, the architecture diagram, 3 headline charts (RPC p99 vs gRPC, task throughput vs Ray, kill -9 recovery timeline), 5-command quickstart (`make cluster-up`, `helixctl matmul`, …), honest limitations, links.
2. *(45 min)* `ARCHITECTURE.md`: component walkthrough and request lifecycle (adapted from [full-proposal.md](full-proposal.md) §2 and SPEC §5).
3. *(45 min)* `docs/benchmarks/README.md`: every benchmark B1–B11 with setup, result, explanation and raw-data link (Spec §10 template).
4. *(30 min)* Two postmortems polished (the best interview stories): one concurrency bug, one distributed-systems bug.
5. *(30 min)* Fresh-clone test: clone into a new directory or a new OrbStack machine and follow the README exactly; fix every step that fails.

**Done when:**

- [ ] Fresh-clone quickstart works without any knowledge not in the README
- [ ] All design docs, ADRs (6+), postmortems and benchmark reports linked from the README

**Self-check:** Could someone who has never met you run the demo in 10 minutes?

### Day 45 · Release v0.5

**Goal:** Helix v0.5 public, with a demo video and the material you'll use in interviews.

**Build (4 h):**

1. *(30 min)* Final checks: CI, nightly chaos and sanitizer jobs green; no open "Done when" items except dropped ones (recorded as issues).
2. *(30 min)* Tag `v0.5` with release notes summarizing all five milestones and their numbers.
3. *(60 min)* 3-minute demo video: cluster up → submit matmul → Grafana live → `kill -9` a worker → job completes → Perfetto timeline of the recovery. Link it in the README.
4. *(45 min)* Blog post 1 published (from the day 18 draft), linked from the README.
5. *(30 min)* Resume bullets with your measured numbers, e.g. "Built a distributed tensor runtime in C++/Go: Raft control plane verified with Porcupine; io\_uring zero-copy data plane with p99 latency N× lower than gRPC; lineage-based recovery from worker loss in N s."
6. *(25 min)* File issues for the stretch roadmap ([45-day-plan.md](45-day-plan.md) "Stretch" column) so the project visibly continues.

**Done when:**

- [ ] `v0.5` public; video and blog linked
- [ ] Resume bullets use only numbers you measured

**Self-check:** Give the 3-minute walkthrough out loud: what Helix is, the hardest bug, the number you're proudest of, and what you'd build next.
