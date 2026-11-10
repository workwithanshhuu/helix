# System design primer (through the lens of Helix)

For an owner whose system design is rusty: the vocabulary, a repeatable interview method, and how each idea appears in Helix. Pair with [foundations-refresher.md §System design fundamentals](foundations-refresher.md#system-design-fundamentals) and [docs/interview/system-design-prompts.md](../interview/system-design-prompts.md).

## 1. A repeatable method (45-minute interview)

| Step | Minutes | What to do | Helix example |
| --- | --- | --- | --- |
| 1. Requirements | 5 | Functional (what it does) and non-functional (scale, latency, durability, consistency, availability). Ask; write numbers down | "Run DAGs of tensor tasks; ~10k tasks/s; survive a worker dying; metadata must not be lost" |
| 2. Estimates | 5 | QPS, data size, bandwidth, storage per day | 64 MiB tensors × 1,000/s = 64 GB/s → data must not go through the control plane |
| 3. API | 5 | Main calls with inputs/outputs | `SubmitJob(dag, request_id) → job_id`, `Complete(task, token)` |
| 4. Data model | 5 | Entities, keys, access patterns | jobs, tasks, leases, objects ([db docs](../db/metadata-schema.md)) |
| 5. High-level design | 10 | Boxes and arrows; data flow for the main request | control plane / workers / data plane |
| 6. Deep dives | 10 | 2–3 hardest parts: consistency, failure, hot spots | fencing tokens; lineage; zero-copy |
| 7. Wrap-up | 5 | Bottlenecks, what breaks at 10×/100×, monitoring | single leader scheduler; directory in Raft |

## 2. Core vocabulary

**Scalability**: vertical (bigger box) vs horizontal (more boxes). Stateless tiers scale by adding replicas behind a load balancer; state is the hard part.

**Partitioning (sharding)**: split data by key — hash (even, no range scans), range (scans, hot spots), consistent hashing (minimal movement on resize; virtual nodes). Hot keys need splitting or caching.

**Replication**:
| Kind | Write path | Trade-off |
| --- | --- | --- |
| Single-leader (Raft, primary/backup) | Leader orders writes | Simple, consistent; leader is a bottleneck/failover |
| Multi-leader | Writes anywhere, merge | Conflicts (CRDTs, LWW) |
| Leaderless (Dynamo) | Quorums R + W > N | Tunable; anti-entropy, read repair |
Synchronous vs asynchronous replication: durability vs latency.

**Consistency models**: linearizable > sequential > causal > read-your-writes > eventual. CAP: during a Partition choose Consistency or Availability. PACELC: Else (no partition) choose Latency or Consistency. Helix meta is CP (minority cannot write).

**Consensus**: Raft/Paxos for agreement on an ordered log; majority quorums; used for metadata, locks, configuration — not for bulk data.

**Caching**: cache-aside, write-through, write-back; invalidation; TTLs; thundering herd (request coalescing); hit-rate math.

**Queues and streams**: decouple producers/consumers; at-most/at-least/effectively-once; idempotency keys (Helix `request_id`); backpressure (Helix credits); dead-letter queues.

**Load balancing**: round robin, least connections, power of two choices, consistent hashing for affinity. L4 vs L7.

**Failure handling**: timeouts, retries with exponential backoff + jitter, circuit breakers, bulkheads, idempotency, leases + fencing, health checks, graceful degradation.

**Storage choices**: relational (transactions, joins), KV (scale, simple access), wide-column (write-heavy), document, object storage (blobs), time-series, search index. B-tree vs LSM.

**Observability**: metrics, logs, traces; SLIs/SLOs/error budgets; RED/USE.

## 3. Numbers for estimates
- 1 day ≈ 86,400 s ≈ 10^5 s. 1M requests/day ≈ 12/s.
- Memory 100 ns; SSD random read ~100 µs; disk seek ~10 ms; same-DC RTT ~0.5 ms; cross-continent ~100 ms.
- 1 Gbit/s ≈ 125 MB/s; 10 Gbit/s ≈ 1.25 GB/s; 100 Gbit/s ≈ 12.5 GB/s.
- A modern server: 32–128 cores, 256 GB–2 TB RAM, NVMe 1–7 GB/s.
- fsync: ~0.05–1 ms on NVMe with power-loss protection, up to 10 ms on cloud volumes.

## 4. How Helix maps to classic patterns

| Pattern | Helix |
| --- | --- |
| Control plane / data plane split | helix-meta vs helixd-to-helixd |
| Replicated state machine | Raft + deterministic `Apply` |
| Leader election | Raft with PreVote/CheckQuorum |
| Leases and fencing | Task ownership |
| Idempotency keys | `request_id` dedup table |
| Backpressure | Credits; spillback |
| Two-level scheduling | Global placement + work stealing |
| Immutable data + lineage | Object store and recovery |
| Write-ahead log + snapshots | Meta durability |
| Sharding (future) | Scheduler/object directory by job |

## 5. Practice
Work through [system-design-prompts.md](../interview/system-design-prompts.md): each prompt lists the expected requirements, a reference design and where Helix experience applies. Do one per weekend, aloud, with a timer.

## 6. Read more
- Kleppmann, *Designing Data-Intensive Applications* (the single best book for this).
- Alex Xu, *System Design Interview* vol. 1–2 (interview format).
- Google SRE book, ch. 4 (SLOs), 21–22 (overload, cascading failure).
- Papers: Dynamo (2007), Bigtable (2006), Spanner (2012), Borg (2015), Kafka (2011).
