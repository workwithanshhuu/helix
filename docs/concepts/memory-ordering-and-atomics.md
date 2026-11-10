# Memory ordering and atomics (C++ and Go)

## 1. The idea

Compilers and CPUs reorder memory operations to go faster. In one thread you never notice. Across threads you do: thread B may see thread A's "flag = true" **before** it sees the data A wrote just before. The **memory model** is the contract that says which orderings you can rely on, and **atomics with memory orders** are how you ask for them.

Mental model: **release = "publish", acquire = "subscribe"**. A release store says "everything I wrote before this is done". An acquire load that **reads the value written by** that release store guarantees "I see everything they wrote before it". That pair creates a *synchronizes-with* edge, and *happens-before* follows from it.

## 2. The orders, from weakest to strongest

| Order | Guarantees | Typical use | Cost on ARM / x86 |
| --- | --- | --- | --- |
| `relaxed` | Atomicity only; per-variable total order (modification order) | Statistics counters, the owner's own index reads | Plain load/store / same |
| `acquire` (loads) | Later reads/writes in this thread cannot move before it | Consumer reading the producer's index | `ldar` / free |
| `release` (stores) | Earlier reads/writes cannot move after it | Producer publishing an index | `stlr` / free |
| `acq_rel` (RMW) | Both | CAS that both consumes and publishes | `ldaxr/stlxr` / `lock cmpxchg` |
| `seq_cst` | Acquire/release + a single global order of all seq_cst ops | Chase–Lev's store-load fence; default when unsure | Extra barrier / `mfence` or `xchg` for stores |

The **store→load** reordering is the one even x86 allows; it is the one that needs `seq_cst` (Dekker's/Peterson's algorithm, and Chase–Lev's `take()` vs `steal()` race).

## 3. Canonical example: SPSC publish

```cpp
// Producer                                    // Consumer
slots_[t & mask_] = item;                      size_t t = tail_.load(std::memory_order_acquire);
tail_.store(t + 1, std::memory_order_release); //  ^ pairs with release store of tail_
                                               if (h != t) item = slots_[h & mask_];  // safe
```

If the store were `relaxed`, the consumer could see the new `tail_` but a stale slot — a real bug on ARM, invisible on x86 (where it would still be a compiler-reordering bug, and a C++ data race = UB).

## 4. Rules Helix follows (CLAUDE.md §5)

1. Every atomic op names its order explicitly; never rely on the default.
2. Every non-relaxed op has a comment naming the operation it **pairs with** and **what it publishes**.
3. Prefer orderings on operations over standalone `atomic_thread_fence` (clearer; better TSan support), except where the algorithm needs a fence (Chase–Lev).
4. Index reads by the owning thread may be `relaxed` (no one else writes them).
5. When unsure, start with `seq_cst`, prove correctness with tests, then weaken one operation at a time with a justification — and keep a **mutation test**: weaken an order on purpose and check the stress test catches it on arm64.

## 5. Go

Go's memory model (2022 revision) says `sync/atomic` operations behave like **sequentially consistent** atomics, and channel send/receive and mutex unlock/lock create happens-before. There are no relaxed atomics in Go. Helix's Go side uses mutexes and channels almost everywhere; atomics only for counters and flags. `go test -race` is the detector.

## 6. Pitfalls

| Bug | How it looks | Proof |
| --- | --- | --- |
| Missing release/acquire | Consumer reads garbage, only on ARM, rarely | Stress on arm64 under TSan; model checker |
| `volatile` used for sync | Works in tests, is UB | `volatile` gives no inter-thread ordering in C++ |
| Non-atomic flag | Compiler hoists the load out of a loop → infinite spin | TSan flags the race |
| Fence in the wrong thread | Fence pairs must exist on both sides | Re-derive happens-before on paper |
| Over-strong orders everywhere | Correct but slow (extra `dmb` on ARM) | Benchmark; weaken with justification |

## 7. Try it

1. Message-passing litmus test: thread A writes `data=42; flag.store(1, relaxed)`; thread B spins on `flag` relaxed then reads `data`. Run millions of iterations on the arm64 VM; count `data != 42`. Then make it release/acquire and count again.
2. Store-buffer litmus (x=y=0; A: x=1; r1=y; B: y=1; r2=x). With acquire/release, `r1==r2==0` is allowed and observable even on x86. With `seq_cst`, it is forbidden.

## 8. Check yourself

1. *Does acquire/release give a global order of all operations?* — No; only pairwise happens-before. `seq_cst` adds a single total order of seq_cst operations.
2. *Why is a relaxed counter fine for statistics?* — Only atomicity is needed; nobody infers other memory state from its value.
3. *What is "synchronizes-with"?* — A release operation and an acquire operation that reads the value it wrote (or a later value in its release sequence).
4. *Why can x86 still need `seq_cst`?* — Its store buffer allows a later load to complete before an earlier store becomes visible (store→load reordering).
5. *What is a release sequence?* — The release store plus later RMWs on the same atomic; an acquire reading any of them synchronizes with the release.

## 9. Read more
- Williams, *C++ Concurrency in Action* 2e, ch. 5.
- Preshing: "Acquire and Release Semantics", "The Synchronizes-With Relation".
- Boehm & Adve, "Foundations of the C++ Concurrency Memory Model" (PLDI 2008).
- Russ Cox, "Memory Models" series (research.swtch.com/mm) — hardware, programming-language and Go models.

## Field notes
_(added by day logs)_
