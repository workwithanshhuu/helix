# Work-stealing scheduling and DAG execution

## 1. The idea

Give every worker thread its own deque of tasks. A thread pushes the tasks it spawns onto its own deque and pops from it (no contention). When its deque is empty, it becomes a **thief** and steals from a random victim's other end. Work flows to idle threads automatically, and most of the time nobody touches shared state.

Why it is good (Blumofe & Leiserson): for a computation with total work **T₁** and critical-path length (span) **T∞**, a work-stealing scheduler on P processors runs in expected time **T₁/P + O(T∞)**, with O(P·T∞) steals in expectation. When parallelism T₁/T∞ ≫ P, that is near-linear speed-up and steals are rare.

## 2. Pieces of Helix's pool (day 7) — `core/include/helix/sched/{thread_pool.h,eventcount.h,task.h}`

| Piece | Design |
| --- | --- |
| Workers | One thread per (physical) core, pinned; ids grouped by NUMA node |
| Local deque | Chase–Lev per worker ([lock-free-structures.md](lock-free-structures.md)) |
| External submission | `MpscInjection` queue (mutex-protected first) for tasks from non-worker threads — only a deque's owner may push to it |
| Victim selection | Random, **same NUMA node first**, then any node; up to 2× workers attempts before spinning |
| Idle strategy | Spin for `spin_before_park_us` (`pause`/`yield`) → park on an **eventcount** (atomic epoch + futex): read epoch, re-check for work, `FUTEX_WAIT` on that epoch; `spawn` bumps the epoch and wakes one sleeper only if `sleepers > 0` (no lost wake-ups, no syscall per spawn) |
| Task type | Small-buffer-optimized callable allocated from the slab; no `std::function` heap churn |
| Join | `TaskGroup` / counter + "help while waiting" (a waiting thread executes other tasks instead of blocking) |
| Stats | Per-worker executed, stolen, steal attempts, parked time (thread-local) |

## 3. DAG executor (day 8) — `TaskGraph`

A job is a DAG: nodes are tasks, edges are data dependencies. Executor:
1. Each node has an atomic `pending_deps` counter initialised to its in-degree.
2. Push all zero-in-degree nodes.
3. When a node finishes, for each child `fetch_sub(1, acq_rel)`; the thread that brings it to 0 schedules the child (exactly one thread wins). `acq_rel` makes the parent's outputs visible to the child.
4. Errors cancel the remaining graph (`cancelled` flag checked before running).
5. Topological validation (cycle detection, Kahn's algorithm) happens before execution.

Optimisation: run one ready child inline (continuation stealing-lite) and push the rest — avoids a deque round-trip.

## 4. Two-level scheduling in the full system
- **Global** (meta leader, Go): which *node* runs a task — locality, load, memory ([scheduling-and-placement.md](scheduling-and-placement.md)).
- **Local** (this pool, C++): which *core* and in what order. The control plane never makes per-core decisions.

## 5. Pitfalls

| Problem | Symptom | Fix |
| --- | --- | --- |
| Steal storms | High CPU, little progress when work is scarce | Back off; batch-steal; park |
| Lost wake-up | Tasks sit in a queue while all workers sleep | Check queue after announcing idle; epoch counter |
| Too-fine tasks | Overhead dominates (tens of ns per task) | Grain size / cutoff (e.g. fib < 20 runs serially) |
| Blocking inside a task | Worker stuck, pool starves | Never block in tasks; I/O goes to I/O threads |
| Deque top/bottom false sharing | Poor scaling | 128-B padding |
| Unbounded recursion depth | Memory blow-up with FIFO local order | LIFO owner order keeps it bounded |

## 6. Try it
- Day 7 bench (B3): fib(30) with spawn per level (cut off below n=15) and 10 M empty tasks vs `std::async` and a mutex-queue pool; record steals, parks, tasks/s.
- Tiled matmul DAG (day 10): measure scaling 1→N threads and plot.

## 7. Check yourself
1. *What are work and span?* — T₁: total operations; T∞: longest dependency chain. Parallelism = T₁/T∞.
2. *Why steal from the top?* — Oldest tasks are typically largest (closest to the root), so one steal transfers lots of work.
3. *Why random victims?* — Simple, provably good, avoids coordinated hot spots.
4. *How does a waiting join avoid deadlock?* — The waiting thread keeps executing tasks ("help while waiting") instead of blocking.
5. *What makes the DAG child scheduling exactly-once?* — The atomic decrement: only the thread that observes the transition to 0 schedules it.

## 8. Read more
- Blumofe & Leiserson, "Scheduling Multithreaded Computations by Work Stealing" (JACM 1999).
- Frigo, Leiserson, Randall, "The Implementation of the Cilk-5 Multithreaded Language" (PLDI 1998) — the work-first principle.
- oneTBB scheduler docs; Taskflow paper (IEEE TPDS 2022).
- Herlihy & Shavit ch. 16.

## Field notes
_(added by day logs)_
