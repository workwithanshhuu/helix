
# Foundations refresher

Re-learn the OS, concurrency, networking, distributed-systems, storage and system-design basics that Helix depends on, each tied to the exact Helix component that uses it.

## How to use this refresher

Read each section in the Learn block of the day before its phase starts; each takes 30–45 minutes. Every concept is written the same way: what it is, why Helix needs it, and a command or experiment that proves it on your machine.

| Section | Read on | Used heavily in |
| --- | --- | --- |
| Hardware and OS basics | Day 1–2 Learn blocks | M1 (allocator, rings, scheduler), M2 (io\_uring), M4 (object store) |
| Concurrency and lock-free basics | Day 2 and day 3 Learn blocks | M1 days 3–8 |
| Networking basics | Day 11 evening or day 12 Learn block | M2 days 12–18 |
| Distributed systems basics | Day 18 (buffer day) | M3 days 19–28, M4 recovery |
| Storage basics | Day 22 Learn block | M3 WAL and snapshots, M4 object store |
| System design fundamentals | Weekends, 30 min each, from week 2 | Interviews; M4 design; days 44–45 write-ups |
| Self-check bank | Every buffer day | Revision before interviews |

**The rule for rusty basics:** don't just read. For each concept, run the experiment listed with it, write the number you got in `notes/foundations.md`, and explain the result in two sentences. If you can't explain the number, re-read that part.

Numbers in this tab are rough orders of magnitude for a modern laptop or server CPU. Your machine will differ; the experiments exist so you replace them with your own.

## Hardware and OS basics

Most Helix performance problems are memory problems: where data lives, which core owns its cache line, and how often you cross into the kernel.

### Latency numbers to know by heart

| Operation | Rough cost | What it means for Helix |
| --- | --- | --- |
| L1 cache hit | \~1 ns (4–5 cycles) | Hot loop data in a matmul tile |
| L2 hit | \~3–5 ns | Per-thread allocator cache |
| L3 hit | \~10–20 ns | Data shared by cores on one socket |
| DRAM access | \~80–120 ns | A cache miss on a tensor you didn't prefetch |
| Remote NUMA DRAM | \~1.5–2× local | Stealing a task whose data lives on the other socket |
| Cache line moved between cores | \~40–100 ns, more across sockets | Every CAS on a contended atomic |
| Uncontended mutex lock/unlock | \~15–25 ns | Why a mutex queue loses to a lock-free ring |
| System call | \~100 ns–1 µs | Why io\_uring batches requests |
| Context switch | \~1–5 µs plus cache pollution | Why workers spin briefly before sleeping |
| Same-host TCP round trip | \~10–30 µs | Baseline for Helix RPC on loopback |
| Same-datacenter round trip | \~100–500 µs | Cross-node fetch and Raft heartbeats |
| SSD fsync | \~0.1–5 ms | Raft commit latency floor |

### Caches and cache lines

- **What:** the CPU moves memory in fixed blocks called cache lines. x86 lines are 64 bytes; Apple Silicon reports 128 bytes. Each core has private L1/L2 caches; L3 is shared per socket.
- **Locality:** sequential access is fast because the hardware prefetcher fetches the next lines; random pointer chasing pays full DRAM latency each hop.
- **Why Helix cares:** matrix tiles must fit in L1/L2 (day 9); hot fields written by different threads must sit on different lines (days 3, 6, 10).
- **Prove it:** `getconf LEVEL1_DCACHE_LINESIZE` and `lscpu` in the Linux VM; write a pointer-chasing loop over arrays of 16 KB, 256 KB, 8 MB and 256 MB and plot ns per access. You'll see a step at each cache size.

### Cache coherence and false sharing

- **What:** coherence protocols (MESI and variants) keep every core's view of a line consistent. A line is Modified, Exclusive, Shared or Invalid in each cache. Writing a line forces every other copy to Invalid, so the next reader elsewhere misses.
- **False sharing:** two threads write *different* variables that share one line. The line ping-pongs between cores even though no data is shared.
- **Why Helix cares:** ring-buffer head and tail, deque top and bottom, and per-worker counters are classic victims.
- **Prove it:** two threads each increment their own counter 100 M times, once with counters adjacent and once with `alignas(128)`. Expect a 3–10× difference. On the x86 cloud box, `perf c2c` names the exact line.

### Memory ordering

- **What:** both the compiler and the CPU reorder loads and stores when a single thread can't tell. x86 is fairly strict (TSO: only a later load may pass an earlier store). ARM, including your Mac, may reorder almost anything.
- **C++ tools:** `std::atomic` with `memory_order_relaxed` (no ordering, just atomicity), `release` on a store (earlier writes become visible before it), `acquire` on a load (later reads happen after it), `acq_rel` for read-modify-write, `seq_cst` (one global order; the default and slowest).
- **The pattern you'll use most:** the producer writes the data, then stores `ready` with release; the consumer loads `ready` with acquire, then reads the data. Release/acquire on the same variable creates a happens-before edge.
- **Why Helix cares:** every lock-free structure in M1 is correct or broken depending on these choices; ARM exposes bugs x86 hides.
- **Prove it:** the message-passing litmus test. Thread A writes `data = 1` then `flag = 1` (both relaxed); thread B reads `flag` then `data`. On ARM, run it 10 M times and count `flag == 1 && data == 0`. Then switch to release/acquire and the count drops to zero.

### Virtual memory and pages

- **What:** every process sees virtual addresses; page tables map them to physical frames in pages (usually 4 KB; check yours with `getconf PAGESIZE`, because some ARM kernels use 16 KB). The TLB caches translations; a TLB miss costs a page-table walk.
- **Page faults:** the first touch of a fresh `mmap` page faults into the kernel (a minor fault, \~0.5–2 µs). Reading a page from disk is a major fault (much slower).
- **Huge pages:** 2 MB pages cut TLB misses for large tensors. `MAP_HUGETLB` needs pages reserved in advance; `madvise(MADV_HUGEPAGE)` asks transparent huge pages to try.
- **Useful calls:** `mmap(MAP_PRIVATE|MAP_ANONYMOUS|MAP_NORESERVE)` to reserve address space, `MAP_SHARED` with a file or `memfd` to share memory between processes, `madvise`, `mlock` to pin pages in RAM, `munmap`.
- **Why Helix cares:** the allocator's PageSource (day 4), the object store's mmap region (day 30), and pre-faulting buffers so tail latency doesn't include page faults (trap 2).
- **Prove it:** `perf stat -e page-faults,dTLB-load-misses` (software events work in the VM) on a program that touches 1 GB with 4 KB pages vs. with `MADV_HUGEPAGE`.

### System calls and context switches

- **What:** a syscall switches to kernel mode and back; a context switch saves one thread's state and loads another's, and the new thread then runs on cold caches.
- **Why Helix cares:** one syscall per message caps throughput at roughly 1–2 M messages/s per core. io\_uring submits and reaps many operations per syscall, or none with SQPOLL.
- **Prove it:** `strace -c` and `perf trace -s` on the day 12 echo server, before and after batching.

### Threads, scheduling and futex

- **What:** Linux schedules threads (tasks) onto cores. `pthread_setaffinity_np` pins a thread to chosen cores. A futex is a kernel wait queue keyed by a user-space address: `FUTEX_WAIT` sleeps only if the value still equals what you expected, and `FUTEX_WAKE` wakes waiters.
- **Lost wakeup:** a thread checks "no work", then a producer adds work and signals, then the thread sleeps forever. Futex avoids it because WAIT rechecks the value atomically.
- **Spin, then park:** spin for a few microseconds (cheap if work arrives soon), then sleep on a futex (cheap if it doesn't).
- **Why Helix cares:** the worker parking logic on day 7.
- **Prove it:** measure wake-up latency from a futex wake to the woken thread running (typically 5–50 µs), and compare with a spinning consumer.

### NUMA

- **What:** on multi-socket servers each socket has its own memory. Local access is faster than remote. Linux places a page on the node of the thread that first touches it (first-touch policy).
- **Tools:** `numactl --hardware` (topology), `numactl --cpunodebind=0 --membind=0` (pin a run), `libnuma`, `mbind`, `move_pages`.
- **Why Helix cares:** NUMA-local stealing and per-node allocator depots (days 5–7); measured on the rented box (day 42).
- **Prove it:** on the cloud box, run the same memory-bandwidth loop with memory on node 0 and threads on node 0, then on node 1, and compare.

## Concurrency and lock-free basics

Lock-free code trades the simplicity of a mutex for progress guarantees and lower contention, and it is only worth it on paths you have measured as hot.

### Vocabulary

| Term | Meaning | Where it shows up in Helix |
| --- | --- | --- |
| Race condition | Outcome depends on thread timing | Anything shared without a lock or atomic |
| Data race (C++) | Two threads access the same non-atomic location, one writes, no happens-before: undefined behaviour | What TSan reports |
| Atomic | Indivisible read/write/RMW on one location | Ring indices, deque `top`/`bottom`, refcounts |
| CAS | Compare-and-swap: write new value only if current equals expected | Thieves claiming a task; refcount updates |
| Blocking | A stalled thread can stop others (a lock holder preempted) | Mutex baseline |
| Lock-free | Some thread always makes progress | Chase–Lev steal, MPMC queue |
| Wait-free | Every thread finishes in bounded steps | SPSC ring push/pop |
| Linearizable | Every operation appears to take effect at one instant between its call and return | The correctness definition for every queue and for Raft reads |
| ABA | A value changes A→B→A, so a CAS succeeds on stale assumptions | Free-list pops in the allocator |
| Safe memory reclamation | Freeing a node only when no thread can still read it | Hazard pointers or epochs (stretch) |

### The structures you'll build, in one line each

- **SPSC ring (day 3):** one producer, one consumer, power-of-two array, `head` written only by the consumer and `tail` only by the producer. Each side keeps a cached copy of the other's index and refreshes it only when the ring looks full or empty, which removes most cross-core traffic.
- **Slab allocator (days 4–5):** fixed size classes; each thread keeps a small free list per class with no atomics; when it runs dry or overflows it moves a batch (e.g. 32 objects) to or from a shared depot under a short lock or lock-free stack.
- **Chase–Lev deque (day 6):** the owner pushes and pops at the bottom with no CAS in the common case; thieves steal from the top with a CAS. The only tricky case is the last element, where owner and thief race and both use CAS on `top`. It needs a sequentially consistent fence between the owner's write of `bottom` and its read of `top`.
- **Work-stealing pool (day 7):** each worker owns a deque; spawned tasks go to the local bottom (cache-hot, LIFO); idle workers steal from a random victim's top (oldest, usually largest work). Provably good: expected time is T₁/P + O(T∞).
- **DAG executor (day 8):** each task holds an atomic count of unfinished parents. When a parent finishes it decrements each child's count; whoever brings it to zero schedules the child.

### Rules that keep you out of trouble

1. Start with a mutex version and a test. Replace it only when a benchmark shows the lock matters.
2. Write the memory order next to every atomic operation, with a comment saying which operation it pairs with.
3. Run every structure under TSan, then under a stress test with more threads than cores, then on ARM.
4. A lock-free structure needs a linearizability check, not just "the sum came out right". At minimum: record each operation with timestamps and check that no value is lost or duplicated.
5. Never free memory another thread may still read. If you can't prove it, leak it in tests and reclaim it in a later version.

### Prove it

- Implement a mutex-protected queue and your SPSC ring; push 100 M integers through each with one producer and one consumer pinned to different cores. Expect the ring to be 5–20× faster.
- Delete the cached-index optimization and measure again; the difference is the cost of cross-core cache traffic.
- Remove one `acquire` and run the stress test on the Mac until it fails. Seeing the failure once teaches more than reading about it.

## Networking basics

A fast data plane is mostly about doing less per byte: fewer syscalls, fewer copies, fewer allocations, and never letting a slow receiver make the sender buffer without limit.

### TCP in five facts

1. **A byte stream, not messages.** One `send` of 1 MB can arrive as many `recv`s of any size, and two small sends can arrive as one. You must frame messages yourself (a length-prefixed header).
2. **Reliable and ordered per connection,** via sequence numbers, ACKs and retransmission. A lost packet stalls everything behind it (head-of-line blocking).
3. **Flow control** (the receiver's window) stops a sender from overrunning the receiver's kernel buffer; **congestion control** (cwnd) stops it from overrunning the network.
4. **Nagle's algorithm** delays small sends to coalesce them; combined with delayed ACKs it can add \~40 ms. Set `TCP_NODELAY` on every Helix socket.
5. **Buffers:** the kernel holds data in socket send/receive buffers (`SO_SNDBUF`, `SO_RCVBUF`). `send` returning means "copied into the kernel", not "delivered".

### From blocking sockets to io\_uring

| Model | How it works | Cost |
| --- | --- | --- |
| Blocking, thread per connection | Each thread blocks in `recv` | Simple; thousands of threads and context switches |
| `epoll` (readiness) | Ask the kernel which sockets are ready, then call `recv`/`send` on each | One syscall per ready check plus one per I/O |
| io\_uring (completion) | Put requests in a shared submission queue (SQ); the kernel posts results to a completion queue (CQ) | One `io_uring_enter` for many operations; zero with SQPOLL |

- **io\_uring pieces you'll use:** `io_uring_queue_init`, `io_uring_get_sqe`, `io_uring_prep_recv` / `prep_send`, `io_uring_submit`, `io_uring_wait_cqe` / `peek_cqe`, `io_uring_cqe_seen`, `user_data` to match a completion to its request.
- **Registered buffers** (`io_uring_register_buffers`): the kernel pins and maps them once, so each I/O skips the page lookup.
- **Provided buffer rings + multishot recv:** you hand the kernel a pool of buffers; one recv request keeps producing completions, each naming the buffer it filled.
- **`send_zc`:** the kernel sends directly from your pages instead of copying them. You get two completions: "queued" and later "you may reuse the buffer". Worth it above roughly 10–64 KB; below that the bookkeeping costs more than the copy.

### Zero-copy, precisely

Copies happen at three places: your code (serialization, `memcpy` into a send buffer), the kernel boundary (user↔kernel), and the NIC (DMA, unavoidable). "Zero-copy in Helix" means no copy in your code, the receive landing straight in the tensor's final buffer, and `send_zc` removing the user-to-kernel copy on large sends. Verify with `perf record` and a flame graph: `memcpy` should not appear under Helix frames.

### Framing and serialization

- **Framing:** a fixed-size header (magic, version, type, flags, ids, lengths, checksum) followed by the payload. Read the header first, validate it, then read exactly `payload_len` bytes.
- **Serialization choices:** Protobuf (parse step, copies), FlatBuffers / Cap'n Proto (read fields in place, no parse), raw bytes (tensors). Helix uses gRPC/Protobuf on the control path, where convenience wins, and raw bytes on the data path.
- **Validate everything:** a length field from the network is untrusted. Cap it, and fuzz the parser.

### Flow control and backpressure

If the producer is faster than the consumer, something must give: drop, block, or buffer without limit (which ends in out-of-memory). Helix uses **credits**: the receiver grants N bytes; the sender spends them and stops at zero until more arrive. This is the same idea as TCP's window and HTTP/2's stream windows, applied per stream.

### RPC semantics

- **Deadlines** travel with the request; a server drops work whose deadline has passed.
- **Cancellation** propagates to downstream calls.
- **At-most-once vs at-least-once:** retries can duplicate work, so make operations idempotent (keyed by request id) or deduplicate on the server.

### Prove it

- `ss -tni` shows a live connection's congestion window, RTT and retransmits.
- Toggle `TCP_NODELAY` on a request-response benchmark and watch p99 change.
- Compare one echo server written with `epoll` and one with io\_uring at 64 B and 64 KB messages: syscalls per second (`perf stat -e 'syscalls:*'` or `strace -c`) and throughput.

## Distributed systems basics

Distributed systems are hard because you can't tell a slow node from a dead one, and every design choice is about what you do while you're unsure.

### Failure models

| Model | What can happen | Helix assumes |
| --- | --- | --- |
| Crash-stop | A node halts and never returns | No: nodes restart |
| Crash-recovery | A node halts, restarts, and recovers from its disk | **Yes**, for meta replicas and workers |
| Omission | Messages are lost, delayed, duplicated or reordered | **Yes**: the simulated network on day 20 does all four |
| Byzantine | Nodes lie or act maliciously | No (non-goal) |

Also assume **pauses**: a garbage-collection stall, a VM freeze or `SIGSTOP` can freeze a node for seconds; when it resumes, it believes no time has passed.

### Time and ordering

- **Wall clocks drift and jump** (NTP corrections), so never use them for correctness, only for timeouts and logs. Use a monotonic clock (`CLOCK_MONOTONIC`, Go's `time.Since`) for durations.
- **Logical order** comes from protocol state: Raft's (term, index) pairs totally order every committed change.

### Consensus and Raft

- **The problem:** several replicas must agree on one sequence of commands even if a minority crashes. With 2f+1 replicas Raft tolerates f failures: 3 replicas survive 1, 5 survive 2.
- **Roles:** follower, candidate, leader. Time is divided into **terms**; each term has at most one leader.
- **Election:** a follower that hears nothing for a randomized timeout (e.g. 150–300 ms) becomes a candidate, increments its term, votes for itself and asks for votes. A node grants at most one vote per term, and only to a candidate whose log is at least as up to date as its own (the election restriction).
- **Replication:** the leader appends client commands to its log and sends `AppendEntries` with the previous entry's (index, term). A follower rejects if it doesn't have that entry; the leader backs up and retries. An entry is **committed** once stored on a majority and from the leader's current term; then each replica applies it to its state machine.
- **Safety in one sentence:** any two majorities overlap, so a committed entry is on at least one voter of every future election, and the election restriction ensures only a node holding it can win.
- **PreVote:** before starting a real election, ask "would you vote for me?" so a node returning from a partition doesn't bump everyone's term and depose a healthy leader.
- **Snapshots:** compact the log by saving the state machine and discarding entries up to that point; send `InstallSnapshot` to followers that are too far behind.

### Linearizability

Every operation appears to happen at one instant between its start and its end, and all clients agree on the order. For Helix metadata, a read after a successful write must see that write, even from a different client. Reading from a follower, or from a leader that was deposed without knowing it, can break this. Porcupine checks it mechanically from a log of operations with start and end times.

### Leases and fencing tokens

- **Lease:** a right that expires on its own, e.g. "worker 7 owns task 42 until t+10 s". It avoids waiting forever on a dead holder.
- **The trap:** a paused worker wakes up after its lease expired and still writes.
- **Fencing token:** a number that increases each time the lease is reassigned. Every write carries it; the storage side remembers the highest token seen and rejects anything lower. In Helix the token is derived from the Raft index at which the lease was granted, so it's unique and monotonic.

### Failure detection

A fixed timeout either reacts too slowly or flags healthy-but-slow nodes. The phi-accrual detector estimates the distribution of heartbeat gaps and outputs a suspicion level; you choose the threshold. For 45 days a fixed timeout with jitter is acceptable; record the choice in an ADR.

### CAP and PACELC, briefly

During a network partition you choose consistency (refuse some requests) or availability (answer with possibly stale data). Else, in normal operation, you trade latency against consistency. Helix's metadata chooses consistency: a minority partition stops accepting writes.

### Prove it

- Run Raft with 3 nodes, partition the leader away, and log terms: the majority elects a new leader within one or two timeouts, and the old leader steps down when the partition heals.
- Turn off the election restriction and run the replication tests until one fails; read the failing history.

## Storage basics

Data is durable only after it has reached stable storage and you have proof; everything before that is a promise the kernel may break on power loss.

### The write path

1. `write()` copies your bytes into the kernel **page cache** and returns. Nothing is on disk yet.
2. The kernel writes dirty pages back later (seconds).
3. `fsync(fd)` forces the file's data *and* metadata to the device and waits; `fdatasync` skips metadata that isn't needed to read the data back (e.g. mtime), so it's usually cheaper.
4. A **new file** also needs `fsync` on its directory, or the file name may vanish after a crash.
5. **Renames** are atomic: write `snapshot.tmp`, fsync it, `rename` to `snapshot`, fsync the directory. This is how you replace a file safely.

### Write-ahead log (WAL)

- **Idea:** before changing state, append a record describing the change to a log and make it durable. After a crash, replay the log to rebuild state.
- **Record format:** `[length u32][crc32c u32][type u8][payload]`. On recovery, read records until the length is impossible or the CRC fails: that's a torn write at the tail, so truncate there.
- **Group commit:** many writers append, one `fdatasync` covers them all. This turns a \~1 ms fsync into a cost shared by every request in the batch.
- **Segments:** roll to a new file every N MB so old segments can be deleted after a snapshot.
- **In Helix:** the Raft log *is* the WAL for metadata (day 23).

### Snapshots

A snapshot is the full state machine at log index i plus the term of i. Write it with the tmp-fsync-rename pattern, then delete log segments whose entries are all ≤ i. Recovery loads the latest snapshot and replays only the log after it.

### mmap

- `mmap` maps a file (or `memfd`) into your address space; loads and stores go straight to the page cache.
- **Good for:** sharing memory between processes (the object store), zero-copy reads, large regions you touch sparsely.
- **Watch out:** page faults on first touch, `msync` needed for durability ordering, I/O errors arrive as `SIGBUS`, and you can't control write-back order. Databases that need strict ordering usually avoid mmap for writes; Helix's object store is a cache, not a database, so mmap is a good fit.

### LSM-tree vs B-tree (stretch, but asked in interviews)

|  | LSM-tree | B-tree |
| --- | --- | --- |
| Writes | Append to memtable + WAL; flush sorted files; merge in background | Update pages in place |
| Reads | Check memtable, then several levels (Bloom filters skip most) | One root-to-leaf path |
| Strength | High write throughput, sequential I/O | Predictable reads, simpler |
| Cost | Write amplification from compaction; read amplification | Random writes, page splits |
| Examples | RocksDB, Pebble, Cassandra | bbolt, InnoDB, PostgreSQL |

Helix uses WAL + snapshots for 45 days; the LSM state machine is the first stretch goal after it.

### Prove it

- Time 10,000 appends of 100 B: with no fsync, with fsync after each, and with one fsync per 100. The gap is your Raft batching budget.
- Write half a record, kill the process, and confirm your recovery code truncates the torn tail instead of crashing.

## System design fundamentals

A system design interview is graded on how you reason about requirements, numbers and trade-offs, not on reaching one right diagram. Helix gives you a system you know end to end to practise that reasoning on.

### The 45-minute framework

1. **Requirements (5 min).** Functional: what operations exist. Non-functional: scale (users, QPS, data size), latency targets (p50/p99), availability, consistency, durability. Write them down and confirm them.
2. **API (3 min).** The 3–5 calls clients make, with inputs and outputs.
3. **Estimates (5 min).** QPS, bandwidth, storage, memory, number of machines. Round hard; show the arithmetic.
4. **High-level design (10 min).** Boxes and arrows: clients, entry point, services, storage, async paths. Walk one request through it.
5. **Deep dives (15 min).** The 2–3 hardest parts: data model and partitioning, consistency, the hot path, failure handling.
6. **Bottlenecks and evolution (5 min).** What breaks at 10×, what you'd monitor, what you'd change.
7. **Trade-offs throughout.** Every choice gets "because…, at the cost of…".

### Back-of-envelope arithmetic

- 1 day ≈ 86,400 s ≈ 10⁵ s. 1 M requests/day ≈ 12 QPS average; plan for peak ≈ 2–5× average.
- Powers of two: 2¹⁰ ≈ 1 thousand (KB), 2²⁰ ≈ 1 million (MB), 2³⁰ ≈ 1 billion (GB), 2⁴⁰ ≈ 1 trillion (TB).
- One server: roughly 10k–100k simple requests/s, 64–512 GB RAM, 10–100 Gbit/s network, a few GB/s from NVMe.
- 1 Gbit/s ≈ 125 MB/s. Moving 1 GB over 10 Gbit/s takes about 1 s.
- Use the latency table in the hardware section for per-operation costs.

**Worked example:** 10,000 inference requests/s, each 2 KB in and 8 KB out → 20 MB/s in, 80 MB/s out (\~0.7 Gbit/s): one 10 Gbit NIC is plenty; the bottleneck is GPU compute, not network.

### Building blocks and when to use them

| Block | Use it for | Key trade-off |
| --- | --- | --- |
| Load balancer (L4/L7) | Spreading requests over stateless servers | Stickiness vs even spread; health checks |
| Cache (in-process, Redis) | Hot reads, expensive computations | Staleness and invalidation; cache stampede |
| Message queue / log (Kafka-style) | Decoupling producers and consumers; absorbing bursts | Added latency; ordering only per partition; at-least-once delivery |
| Relational DB | Transactions, flexible queries | Harder to scale writes |
| Key-value / wide-column store | Huge scale, simple access patterns | Limited queries; tunable consistency |
| Object store (S3-style) | Large immutable blobs | High per-request latency |
| Consensus store (etcd/ZooKeeper) | Small, critical metadata; leader election; locks | Low write throughput; keep it small |
| CDN | Static content near users | Invalidation delay |

### Patterns you'll be asked about

- **Partitioning (sharding):** by hash (even spread, no range scans) or by range (range scans, hot spots). Consistent hashing moves only \~1/N of keys when a node joins.
- **Replication:** leader-follower (simple; failover needed), multi-leader (conflicts), leaderless quorums (R + W > N for read-your-writes).
- **Consistency levels:** linearizable > sequential > causal > eventual. Stronger costs latency and availability.
- **Idempotency:** client-supplied request ids so retries don't double-apply.
- **Backpressure, timeouts, retries with jittered exponential backoff, circuit breakers:** keep one slow dependency from taking down everything.
- **Tail latency:** with fan-out to 100 servers, p99 of each becomes the median of the whole. Hedged requests, request deadlines and limiting fan-out help.
- **Rate limiting:** token bucket (allows bursts) or sliding window.
- **Batching:** trades a little latency for much higher throughput (Raft group commit, GPU request batching).

### Worked case study: "Design a distributed task scheduler for ML jobs"

This is a common prompt, and Helix is a full answer to it.

1. **Requirements:** users submit DAGs of tasks; up to 1 M tasks/s cluster-wide; scheduling latency p99 < 10 ms; tasks survive worker failures; metadata never lost; 1,000 workers.
2. **API:** `SubmitJob(dag) → job_id`, `GetStatus(job_id)`, `GetResult(object_id)`, `Cancel(job_id)`.
3. **Estimates:** 1 M tasks/s × \~200 B of metadata = 200 MB/s of state changes, too much for one Raft group. So: batch tasks into groups, or shard the scheduler by job.
4. **High level:** clients → replicated control plane (Raft) holding jobs, leases and the object directory → per-node local schedulers → executors → per-node object stores, with peer-to-peer data transfer.
5. **Deep dives:** two-level scheduling (global placement + local work stealing) to keep the control plane off the hot path; leases + fencing tokens for exactly-one-winner semantics; lineage re-execution instead of checkpointing; locality-aware placement to avoid moving tensors.
6. **Bottlenecks:** the object directory and global scheduler at 10k nodes → shard by job id; Raft write throughput → batch and pipeline; stragglers → speculative execution.

### Other prompts where Helix gives you the answer

| Prompt | Helix part to reuse |
| --- | --- |
| Design a key-value store / metadata service | helix-meta: Raft, WAL, snapshots, linearizable reads |
| Design a distributed lock service | Leases + fencing tokens |
| Design an LLM inference serving system | Batching queue, KV-cache paging idea, placement by memory headroom |
| Design a job queue / workflow engine | DAG executor, retries, idempotent tasks |
| Design a distributed cache / blob store | Object store: immutable objects, refcounts, LRU, locality |
| Design a metrics or tracing pipeline | M5 telemetry: per-thread histograms, aggregation, sampling |
| Why is this service slow at p99? | Trap 2 debugging playbook |

### Practice plan (fits in weekends)

One prompt every weekend from week 2, 45 minutes, out loud, with a timer. Draw on paper, then compare against *Designing Data-Intensive Applications* and the Ray, Borg and Raft papers. Good free practice sources: the "System Design Primer" repository on GitHub and the Gossip Glomers distributed-systems challenges.

## Self-check question bank

Answer each out loud in under two minutes without notes; any you can't answer goes on the next buffer day's list. The section to re-read is in brackets.

### Hardware and OS

1. Why can adding threads make a counter benchmark slower? Name the mechanism and the tool that proves it. \[Hardware: coherence\]
2. What does a release store guarantee, and to whom? What breaks if the consumer uses a relaxed load instead of acquire? \[Memory ordering\]
3. What happens, step by step, on the first write to a freshly `mmap`ed anonymous page? \[Virtual memory\]
4. When do huge pages help, and when do they hurt? \[Virtual memory\]
5. Explain the lost-wakeup problem and how a futex avoids it. \[Threads\]
6. A thread on socket 0 allocated a buffer; a thread on socket 1 reads it in a hot loop. What do you expect, and how would you fix it? \[NUMA\]

### Concurrency

7. Lock-free vs wait-free: give one Helix structure of each kind. \[Vocabulary\]
8. Why does the SPSC ring cache the other side's index? What does it save? \[Structures\]
9. Describe the race on the last element of a Chase–Lev deque and how it's resolved. \[Structures\]
10. What is ABA? Give a concrete sequence that corrupts a lock-free stack. \[Vocabulary\]
11. Why does work stealing take from the top of the victim's deque but run from the bottom of your own? \[Structures\]

### Networking

12. Why can't you assume one `recv` returns one message? How does Helix frame messages? \[TCP\]
13. epoll vs io\_uring: which syscalls does each need to read 1,000 messages from 100 sockets? \[io\_uring\]
14. When is `send_zc` slower than a normal send, and why? \[io\_uring\]
15. What is backpressure, and what happens in Helix when a receiver stops reading? \[Flow control\]
16. Where can copies happen between a tensor in one process and a tensor in another machine's process? Which does Helix remove? \[Zero-copy\]

### Distributed systems

17. Why does Raft need a majority, and why are 4 replicas no better than 3? \[Raft\]
18. Walk through what happens when the leader crashes after replicating an entry to one follower out of four. \[Raft\]
19. Why can't a leader commit an entry from a previous term just by counting replicas? \[Raft\]
20. What does PreVote prevent? \[Raft\]
21. A worker pauses for 30 s, its lease expires, the task is rerun elsewhere, and then the paused worker resumes and tries to write. Walk through what stops it. \[Leases\]
22. Define linearizability. Give an example history that is not linearizable. \[Linearizability\]

### Storage

23. You wrote and fsynced a new file, then the machine lost power, and the file is gone. Why? \[Write path\]
24. How does recovery find the end of a WAL with a torn last record? \[WAL\]
25. Why does group commit raise throughput without lowering durability? \[WAL\]
26. When would you choose an LSM-tree over a B-tree? \[LSM\]

### System design

27. Estimate the network bandwidth for 50k requests/s of 4 KB each. Is one machine enough? \[Arithmetic\]
28. Fan-out to 100 servers, each with p99 = 10 ms: what's the probability a request sees at least one 10 ms response? \[Patterns: tail latency\] (Answer: 1 − 0.99¹⁰⁰ ≈ 63%.)
29. Design a distributed lock service in 10 minutes, including what happens when a client pauses. \[Case study\]
30. Your scheduler's control plane becomes the bottleneck at 10k nodes. Give three ways to scale it and the trade-off of each. \[Case study\]
