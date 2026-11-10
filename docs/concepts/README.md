# Concepts

The theory behind every Helix component, written for someone whose basics are rusty. Each concept doc has the same shape:

1. **The idea** in plain words, with a mental model.
2. **How Helix uses it**: the exact files and the design choice it drives.
3. **Details that matter**: the parts interviewers probe.
4. **Pitfalls**: what goes wrong, how it shows up, how to prove it.
5. **Try it**: a small experiment on your machine.
6. **Check yourself**: questions with short answers.
7. **Read more**: the 2–4 sources worth the time.

Concept docs are **living**: CLAUDE.md §6 requires each day to add what was actually learned (pitfalls hit, numbers measured) to the matching file under a "Field notes" heading.

## Reading order

| # | Doc | Read before | Used in |
| --- | --- | --- | --- |
| 0 | [foundations-refresher.md](foundations-refresher.md) | Day 1 (skim), then section by section | Everything |
| 1 | [hardware-and-caches.md](hardware-and-caches.md) | Day 2 | M1, M2 |
| 2 | [memory-ordering-and-atomics.md](memory-ordering-and-atomics.md) | Day 3 | M1 (every lock-free structure) |
| 3 | [lock-free-structures.md](lock-free-structures.md) | Day 3, again day 6 | SPSC ring, injection queue, Chase–Lev deque |
| 4 | [virtual-memory-and-allocators.md](virtual-memory-and-allocators.md) | Day 4 | Slab allocator, object store |
| 5 | [work-stealing-scheduling.md](work-stealing-scheduling.md) | Day 7 | Thread pool, DAG executor |
| 6 | [io-uring-and-zero-copy.md](io-uring-and-zero-copy.md) | Day 12 | helix-rpc |
| 7 | [raft-consensus.md](raft-consensus.md) | Day 19 | helix-meta |
| 8 | [linearizability-and-testing.md](linearizability-and-testing.md) | Day 26 | Porcupine, simulator |
| 9 | [wal-snapshots-durability.md](wal-snapshots-durability.md) | Day 23 | WAL, snapshots |
| 10 | [leases-and-fencing.md](leases-and-fencing.md) | Day 34 | Leases, recovery |
| 11 | [scheduling-and-placement.md](scheduling-and-placement.md) | Day 32 | Global scheduler |
| 12 | [observability-and-tail-latency.md](observability-and-tail-latency.md) | Day 39 | Metrics, benchmarks |
| 13 | [system-design-primer.md](system-design-primer.md) | Weekends | Interviews |
| 14 | [build-and-sanitizers.md](build-and-sanitizers.md) | Day 1 | Build system, CI |
