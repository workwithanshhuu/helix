# Question bank

Questions interviewers ask about systems like Helix, grouped by area, with short model answers and a pointer to where Helix demonstrates it. Answer aloud first, then check. Add questions you were actually asked (mark them ★ with the company).

## A. CPU, memory and OS
1. **What is false sharing and how do you detect it?** Two threads writing different variables on one cache line make the line bounce between cores. Detect with `perf c2c` (HITM on the line) or by padding and re-measuring. Helix: 128-B padding of ring indices and deque top/bottom. → [hardware](../concepts/hardware-and-caches.md)
2. **Walk through what happens on a page fault.** MMU finds no valid PTE → trap → kernel finds the VMA, allocates/zeros a frame (or reads from file/swap), installs PTE, returns; the instruction retries. Minor vs major. → [vm](../concepts/virtual-memory-and-allocators.md)
3. **Why huge pages?** Fewer TLB misses; but THP compaction can cause latency spikes.
4. **What does NUMA first-touch mean for an allocator?** Pages land on the node of the first writer; allocate and initialize on the consuming thread's node.
5. **Cost of a syscall vs a context switch vs a cache miss?** ~100 ns–1 µs; ~2–5 µs; ~100 ns DRAM.
6. **How do `mmap` `MAP_SHARED` and `MAP_PRIVATE` differ?** Shared writes are visible to other mappings/the file; private is copy-on-write.
7. **How would you design an allocator for many small objects across threads?** Size classes, per-thread caches, batched transfer to central lists, page source with huge pages; handle cross-thread frees. → Helix slab.

## B. Concurrency and lock-free
8. **Explain acquire/release with an example.** Producer writes data, release-stores index; consumer acquire-loads index and then reads data safely. → [memory ordering](../concepts/memory-ordering-and-atomics.md)
9. **When is `seq_cst` needed?** To forbid store→load reordering, e.g. Dekker-style mutual exclusion and Chase–Lev's take/steal race on the last element.
10. **Lock-free vs wait-free?** System-wide progress vs per-thread bounded progress.
11. **What's ABA and how do you prevent it?** CAS succeeding on a recycled value; sequence numbers, tagged pointers, hazard pointers/epochs.
12. **Design a bounded SPSC queue. Then MPMC.** Monotonic indices + cached remote index + padding; Vyukov per-slot sequence numbers.
13. **How does work stealing work and why is it efficient?** Per-thread deques, steal from the top; T₁/P + O(T∞).
14. **How do you test a lock-free structure?** Reference model, stress with invariants, TSan many repetitions, ARM, mutation tests, model checking.
15. **Mutex vs spinlock?** Spin only when the hold time < cost of sleeping/waking and the holder is running; otherwise futex-based mutex.
16. **What is priority inversion / convoying?** Low-priority holder blocks high-priority waiter; threads queue behind a descheduled lock holder.

## C. Networking and RPC
17. **How does io_uring differ from epoll?** epoll tells you readiness and you still syscall per read/write; io_uring submits operations and returns completions via shared rings, batched. → [io_uring](../concepts/io-uring-and-zero-copy.md)
18. **What makes zero-copy send tricky?** Buffer lifetime until the kernel's notification; pinning overhead makes it slower for small messages.
19. **What's Nagle's algorithm and why disable it?** Coalesces small writes until ACK; with delayed ACK causes ~40 ms stalls for request/response.
20. **How do you implement backpressure?** Credits/windows from the receiver; bounded queues; reject or slow the sender.
21. **Why might your RPC beat gRPC and when should you still use gRPC?** No HTTP/2 or protobuf on the hot path, registered buffers, thread-per-core; gRPC wins on interoperability, tooling, schema evolution, security.
22. **What happens in a TCP handshake / close; what is TIME_WAIT?** SYN, SYN-ACK, ACK; FIN/ACK each side; TIME_WAIT 2×MSL to absorb stray segments.

## D. Distributed systems and consensus
23. **Explain Raft leader election and why it's safe.** Terms, one vote per term, up-to-date log check, majority intersection. → [raft](../concepts/raft-consensus.md)
24. **Why can't a Raft leader commit entries from previous terms by counting replicas?** Figure 8: a later leader could overwrite them.
25. **What are PreVote and CheckQuorum?** Avoid term inflation by rejoining nodes; depose leaders cut off from the majority.
26. **How do you serve linearizable reads?** Through the log, ReadIndex, or leader leases (clock assumptions).
27. **What is linearizability; how did you test it?** Real-time single-copy semantics; Porcupine over recorded histories with a seeded simulator. → [linearizability](../concepts/linearizability-and-testing.md)
28. **Why do you need fencing tokens if you have leases?** Pauses: an expired holder may still act; the resource rejects older tokens. → [leases](../concepts/leases-and-fencing.md)
29. **CAP/PACELC: where is Helix?** CP for metadata; data plane objects are recomputable.
30. **What's exactly-once and how close can you get?** At-least-once delivery + idempotent processing (request ids, token checks) = effectively once.
31. **How does a WAL guarantee durability? What is group commit?** fsync before ack; batch fsyncs. → [WAL](../concepts/wal-snapshots-durability.md)
32. **What breaks in Helix at 10,000 nodes?** Leader scheduling throughput, object directory write rate in Raft, heartbeat fan-in; shard scheduler by job, ownership-based directory, hierarchical heartbeats.

## E. Scheduling and runtime
33. **Design a cluster scheduler for GPU jobs.** Feasibility (GPU type, memory, topology/NVLink), scoring (locality, packing vs spreading), gang scheduling, preemption, fairness (DRF), failure handling. → [scheduling](../concepts/scheduling-and-placement.md)
34. **What is power of two choices?** Sample two, pick the less loaded; exponentially better max load than random.
35. **How does Ray recover lost objects?** Lineage reconstruction by the owner; Helix does the same with producer-identity object IDs.
36. **Lineage vs checkpointing?** Free on the happy path vs bounded recovery time.

## F. Performance and observability
37. **How do you find where time goes in a C++ service?** `perf record -g` + flame graphs (on-CPU), off-CPU analysis (bpftrace), USE method, top-down microarchitecture.
38. **What is coordinated omission?** Closed-loop generators hide stalls; use open-loop with intended send times. → [observability](../concepts/observability-and-tail-latency.md)
39. **Why do p99s matter more than averages?** Fan-out amplifies tail; users feel it.
40. **How do you make a benchmark trustworthy?** Fixed environment, warm-up, repetitions, open-loop, raw data, tuned baselines.

## G. Behavioural (systems flavoured)
41. Tell me about a hard bug. → [deep-dive-stories.md](deep-dive-stories.md)
42. A design decision you'd reverse. → ADRs and postmortems.
43. How did you decide what to cut? → plan's scope table and buffer days.
44. How did you use AI tools, and how do you make sure the code is right? → Tests-first gates, sanitizers, simulator, the "Explain it back" discipline.

## ★ Asked in real interviews
_(add here: question · company · date · how it went)_
