# Glossary

Alphabetical. Links point to the concept doc where the term is explained in depth.

| Term | Meaning |
| --- | --- |
| ABA problem | A CAS succeeds because a value changed A→B→A; the object behind it is different. [lock-free](../concepts/lock-free-structures.md) |
| Acquire / release | Memory orders that publish (release) and subscribe to (acquire) prior writes. [ordering](../concepts/memory-ordering-and-atomics.md) |
| ADR | Architecture Decision Record: one decision, its context, alternatives and consequences. [docs/adr](../adr/) |
| AppendEntries | Raft RPC that replicates log entries and acts as heartbeat. [raft](../concepts/raft-consensus.md) |
| ASan | AddressSanitizer: detects memory errors. [build](../concepts/build-and-sanitizers.md) |
| Attempt | Count of leases granted to a task (starts at 1). |
| Backpressure | Slowing a producer when the consumer cannot keep up (Helix: credits, spillback). |
| Cache line | Unit of coherence and transfer: 64 B x86, 128 B Apple Silicon. [hardware](../concepts/hardware-and-caches.md) |
| CAS | Compare-and-swap: atomically replace a value if it equals an expected one. |
| Chase–Lev deque | Lock-free work-stealing deque: owner at bottom, thieves at top. |
| CheckQuorum | Raft leader steps down if it hasn't heard from a majority recently. |
| Commit index | Highest Raft log index known to be replicated on a majority (from the current term). |
| Coordinated omission | Load-generator flaw that hides latency during stalls. [observability](../concepts/observability-and-tail-latency.md) |
| CQE / SQE | io_uring completion / submission queue entry. [io_uring](../concepts/io-uring-and-zero-copy.md) |
| Credits | Receiver-granted permission to send N bytes/messages (flow control). |
| DAG | Directed acyclic graph of tasks and data dependencies. |
| Data race | Unsynchronized conflicting accesses, at least one a write; UB in C++. |
| Deterministic simulation | Test harness where a seeded RNG drives all nondeterminism. [testing](../concepts/linearizability-and-testing.md) |
| Extent | Contiguous byte range in the object store region. |
| False sharing | Different variables on one cache line causing coherence traffic. |
| fdatasync / fsync | Flush file data (and needed metadata) / data and all metadata to stable storage. [WAL](../concepts/wal-snapshots-durability.md) |
| Fencing token | Monotonic number attached to a lease; resources reject older ones. [leases](../concepts/leases-and-fencing.md) |
| FetchContent | CMake module that downloads dependencies at configure time. |
| First touch | Linux NUMA policy: page placed on the node of the first writer. |
| Group commit | One fsync covering a batch of log records. |
| Happens-before | Partial order of operations guaranteeing visibility. |
| HDR histogram | Log-linear bucketed histogram with bounded relative error. |
| HITM | "Hit modified": load served from another core's modified line (false-sharing signal in `perf c2c`). |
| Huge page | 2 MiB/1 GiB page reducing TLB pressure. |
| Idempotent | Applying twice equals applying once (Helix Submit with `request_id`). |
| InstallSnapshot | Raft RPC sending a snapshot to a lagging follower. |
| io_uring | Linux async I/O interface with shared submission/completion rings. |
| Lease | Time-bounded ownership that must be renewed. |
| Lineage | The record of which task produced which object; used to recompute lost objects. |
| Linearizability | Operations appear atomic at a point between call and return, respecting real time. |
| Linearization point | The instant an operation takes effect. |
| Little's law | L = λW. |
| Lock-free / wait-free | Some thread always progresses / every thread progresses in bounded steps. |
| LSM-tree | Log-structured merge tree: memtable + sorted runs + compaction. |
| memfd | Anonymous in-memory file (`memfd_create`). |
| MESI | Cache coherence states Modified/Exclusive/Shared/Invalid. |
| MPMC / SPSC | Multi-producer multi-consumer / single-producer single-consumer queue. |
| Multishot | io_uring request producing many completions (accept, recv). |
| Nagle's algorithm | TCP coalescing of small writes; disabled with `TCP_NODELAY`. |
| NUMA | Non-uniform memory access: memory attached per socket. |
| Open-loop load | Requests sent on a schedule regardless of responses. |
| Perfetto | Trace viewer/format used for Helix flight-recorder dumps. |
| Porcupine | Go linearizability checker. |
| Power of two choices | Sample two candidates, choose the better one. |
| PreVote | Raft pre-election round that avoids disruptive term increments. |
| Raft | Leader-based consensus algorithm. [raft](../concepts/raft-consensus.md) |
| ReadIndex | Raft linearizable read without a log write. |
| Registered buffers | Memory pre-registered with io_uring to avoid per-I/O pinning. |
| Relaxed | Memory order with atomicity only. |
| `send_zc` | io_uring zero-copy send with a release notification. |
| seq_cst | Sequentially consistent: single total order of such operations. |
| Slab allocator | Fixed-size object caches carved from pages. [allocators](../concepts/virtual-memory-and-allocators.md) |
| Snapshot | Serialized state machine at a log index. |
| Span (T∞) | Critical-path length of a computation. |
| Spillback | Worker refusing a lease so the task is placed elsewhere. [scheduling](../concepts/scheduling-and-placement.md) |
| Split brain | Two parties both believing they are the owner/leader. |
| State machine (replicated) | Deterministic `Apply` of log commands on every replica. |
| Tail latency | High percentiles (p99, p99.9). |
| Term | Raft logical epoch; at most one leader per term. |
| THP | Transparent huge pages. |
| TLB | Cache of virtual→physical translations. |
| Torn write | Partially persisted record after a crash. |
| TSan | ThreadSanitizer: detects data races. |
| TSO | Total store order (x86 memory model). |
| UBSan | UndefinedBehaviorSanitizer. |
| WAL | Write-ahead log. |
| Work (T₁) | Total operations in a computation. |
| Work stealing | Idle threads take tasks from other threads' deques. [work-stealing](../concepts/work-stealing-scheduling.md) |
| Zero-copy | Moving data without CPU copies between buffers. |
