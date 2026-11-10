# Lock-free data structures: SPSC ring, injection/MPMC queue, Chase–Lev deque

## 1. The idea

A **lock-free** structure guarantees that some thread always makes progress, even if others are paused mid-operation (no thread can block all others by holding a lock). **Wait-free** is stronger: every thread finishes in a bounded number of its own steps. Lock-free is not automatically faster than a good mutex; it wins when contention is high, critical sections are tiny, or a thread being descheduled while holding a lock is unacceptable (I/O threads, schedulers).

Progress guarantees, weakest to strongest: blocking → obstruction-free → lock-free → wait-free.

## 2. The three structures Helix builds

### 2.1 SPSC ring (day 3) — `core/include/helix/sync/spsc_ring.h`

One producer, one consumer, fixed capacity `N` as a template parameter (`SpscRing<T, N>`, N a power of two, so `index & mask` replaces `%`). API per SPEC §2: `try_push(T&&)`, `try_pop() → std::optional<T>`.

```
producer owns tail_ (writes), reads head_       consumer owns head_ (writes), reads tail_
slots: [ . . X X X X . . ]   head_=2  tail_=6   empty when head_==tail_, full when tail_-head_==cap
```

- Indices are **monotonic 64-bit counters** (never wrap in practice), so full/empty are unambiguous without a wasted slot.
- `push`: read own `tail_` relaxed; check space against **cached** `head_`; only if full, reload `head_` with acquire (pairs with consumer's release store of `head_`, guaranteeing the slot is free to overwrite); write slot; `tail_.store(release)`.
- `pop`: symmetric with a cached `tail_`.
- `head_`, `tail_`, and the two caches each sit on their own 128-B line.
- Wait-free for both sides. Batch APIs (`push_n`, `pop_n`) amortize the index publish.

### 2.2 The pool's injection queue (day 7) and Vyukov's bounded MPMC design

Day 7 starts with a mutex-protected `MpscInjection` queue for tasks submitted from non-worker threads (correct first; it is off the hot path). If profiling on day 11 shows contention, the upgrade is Dmitry Vyukov's bounded MPMC queue: each slot has a **sequence number**. A producer claims position `p` by CAS on `enqueue_pos_` when `slot[p].seq == p`; writes the value; stores `seq = p + 1` (release). A consumer claims `p` when `slot[p].seq == p + 1`; reads; stores `seq = p + cap` (release) so the slot is ready for the next lap. No ABA: the sequence encodes the lap. Lock-free (not wait-free: a CAS can fail repeatedly). Know it for interviews even if Helix keeps the mutex version.

### 2.3 Chase–Lev work-stealing deque (day 6) — `core/include/helix/sync/ws_deque.h`

The owner pushes/pops at the **bottom** (LIFO — cache-hot, depth-first); thieves steal from the **top** (FIFO — oldest, usually biggest tasks).

```
top (thieves CAS here) →  [ t0 t1 t2 t3 ]  ← bottom (owner only)
```

- `push`: write `buf[b]`; `bottom.store(b+1, release)` (publishes the slot to thieves).
- `take` (owner): `b = bottom-1; bottom.store(b, relaxed); fence(seq_cst); t = top.load(relaxed)`. If `t < b` → got it without contention. If `t == b` → last element: race thieves with `CAS(top, t, t+1)`; restore `bottom`.
- `steal`: `t = top.load(acquire); fence(seq_cst); b = bottom.load(acquire)`; if `t < b` read `buf[t]` then `CAS(top, t, t+1, seq_cst)`; on failure return "retry/abort".
- The `seq_cst` fences prevent the store→load reordering where owner and thief both believe they got the last element.
- Growth: when full, allocate a bigger circular array, copy, publish the new pointer; the old array cannot be freed immediately (a thief may be reading it) → keep retired arrays until shutdown, or use epochs.
- Correct orderings: Lê et al., PPoPP 2013. Use them verbatim and cite them in comments.

## 3. Hard problems

**ABA.** A CAS compares values, not history: a pointer A is freed, a new node is allocated at the same address, CAS succeeds wrongly. Defences: sequence numbers (Vyukov), tagged pointers (counter in spare bits), or avoiding pointer CAS on recycled nodes (Chase–Lev CASes an *index*).

**Safe memory reclamation.** In lock-free linked structures you cannot `delete` a node another thread may still be reading. Options: **hazard pointers** (readers announce what they hold), **epoch-based reclamation** (free after all threads pass a quiescent point), RCU, or "never free until shutdown". Helix's array-based designs mostly sidestep this; the deque's grown arrays are retired, not freed.

**Linearizability.** Each operation must appear to take effect at a single instant (its *linearization point*) between its call and return. For SPSC push it is the release store of `tail_`. Being able to name the linearization point of every operation is an interview staple.

## 4. Testing strategy (CLAUDE.md §5)

1. Single-threaded unit tests vs a `std::deque` reference model with random operation sequences.
2. Multi-threaded stress: e.g. producer pushes 0..N, consumer asserts strictly increasing and sum matches; for the deque, every pushed task is executed **exactly once** (counter per task).
3. Run under TSan 100× (`--gtest_repeat=100`) on arm64.
4. **Mutation test**: weaken one memory order on purpose and confirm the stress test fails on arm64 within a time budget. If it doesn't, the test is too weak.
5. Optional: model-check small configurations (Relacy/GenMC/CDSChecker).

## 5. Pitfalls

| Bug | Symptom |
| --- | --- |
| `head_`/`tail_` on one line | Throughput collapses with 2 threads on different cores |
| Not caching the remote index | Every op reads a line the other side is writing |
| Non-power-of-two capacity with `&` | Wrong slot, silent corruption |
| Missing `seq_cst` fence in deque | Same task executed twice (or lost) once in millions |
| Reading the slot *after* a successful CAS in steal | Owner may already have overwritten it |
| `int` indices | Overflow after 2^31 operations |

## 6. Try it
- Benchmark SPSC vs `std::mutex`+`std::queue` and vs `boost::lockfree::spsc_queue`/folly `ProducerConsumerQueue` with 1 KiB items; report ops/s and ns/op (day 3 bench).
- Remove the cached index and measure the difference.

## 7. Check yourself
1. *Why is the deque LIFO for the owner and FIFO for thieves?* — Owner keeps cache-hot recent work and goes depth-first (bounded memory); thieves take old tasks, which in divide-and-conquer are the biggest, so steals are rare.
2. *Where is the linearization point of `steal`?* — The successful CAS on `top`.
3. *Why monotonic indices instead of wrapped ones?* — Full vs empty distinguishable without a spare slot; with 64-bit they never overflow in practice.
4. *Lock-free vs wait-free for MPMC?* — Vyukov's queue is lock-free: a CAS can lose forever in theory.
5. *How does Vyukov's queue avoid ABA?* — Per-slot sequence numbers encode the lap.

## 8. Read more
- Herlihy & Shavit, *The Art of Multiprocessor Programming*, ch. 3, 10, 16.
- Chase & Lev, SPAA 2005; Lê, Pop, Cohen, Zappa Nardelli, PPoPP 2013.
- Vyukov, 1024cores.net "Bounded MPMC queue".
- Rigtorp's `SPSCQueue` and `MPMCQueue` (readable reference implementations).

## Field notes
_(added by day logs)_
