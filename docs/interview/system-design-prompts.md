# System design practice prompts

Each prompt: the requirements to clarify, a reference design outline, the deep dives an interviewer will push on, and where Helix gives you first-hand material. Practise one per weekend, 45 minutes aloud, using the method in [system-design-primer.md](../concepts/system-design-primer.md).

---

## 1. Distributed task execution system (Ray-like) — *Helix itself*
- **Clarify**: task size/duration, data size between tasks, failure rate, latency vs throughput, Python or not, multi-tenant?
- **Design**: control plane with replicated metadata (Raft) + scheduler; workers with local schedulers and object stores; peer-to-peer data transfer; leases + fencing; lineage recovery.
- **Deep dives**: object directory scaling; scheduling latency; recovery of a lost object deep in a DAG; hot objects (broadcast).
- **Helix material**: all of it; quote measured numbers.

## 2. GPU cluster scheduler for training and inference jobs
- **Clarify**: job types (gang-scheduled training vs elastic inference), GPU types, topology (NVLink, IB), priorities and quotas, preemption.
- **Design**: inventory service; queue per priority; gang scheduling (all-or-nothing); topology-aware packing; preemption with checkpoint signal; fairness (DRF / quotas); health checking of nodes and GPUs (ECC errors, XID).
- **Deep dives**: fragmentation and bin packing; failures mid-training (checkpoint/restart); straggler detection.
- **Helix material**: scoring + spillback, leases, failure detection, two-level scheduling.

## 3. LLM inference serving system
- **Clarify**: models, QPS, latency SLO (time to first token, tokens/s), context length, multi-model.
- **Design**: router → per-model replica pools; continuous batching; KV-cache memory management (paged); autoscaling on queue depth; prefix caching; streaming responses.
- **Deep dives**: batching vs tail latency; KV-cache eviction; cold starts (weight loading via mmap); multi-GPU (tensor/pipeline parallel).
- **Helix material**: batching queues, allocator design, mmap store, tail-latency measurement.

## 4. Distributed key-value store (etcd/Dynamo-like)
- **Clarify**: consistency needed? size, read/write ratio, multi-region?
- **Design (strong)**: Raft groups per shard (multi-Raft), range partitioning, leader leases/ReadIndex for reads, WAL + LSM storage, rebalancing by splitting ranges.
- **Design (available)**: consistent hashing, N/R/W quorums, hinted handoff, anti-entropy (Merkle trees).
- **Deep dives**: shard split/move with Raft membership changes; hot keys; compaction stalls.
- **Helix material**: Raft, WAL, snapshots, Porcupine.

## 5. Distributed lock / coordination service (Chubby/ZooKeeper)
- **Design**: Raft-replicated state; sessions with leases; sequencers (fencing tokens); watches; ephemeral nodes.
- **Deep dives**: client pauses and fencing; session failover; thundering herd on watch triggers.
- **Helix material**: leases + fencing tokens exactly.

## 6. High-throughput message queue / log (Kafka-like)
- **Design**: partitioned append-only logs; leader per partition with ISR replication; consumer groups and offsets; zero-copy `sendfile`; batching and compression.
- **Deep dives**: exactly-once (idempotent producers, transactions); retention and compaction; rebalancing consumers.
- **Helix material**: WAL design, group commit, zero-copy sends, backpressure.

## 7. Object/blob storage service (S3-like) or hyper-converged storage (Nutanix-like)
- **Design**: metadata service (sharded, strongly consistent) + data nodes; erasure coding vs replication; placement for locality; background scrubbing and repair.
- **Deep dives**: metadata scaling; small-object overhead; data locality for VMs; rebuild bandwidth after disk failure.
- **Helix material**: object store layout, locality-aware placement, Raft metadata tier.

## 8. Metrics/monitoring system (Prometheus/Monarch-like)
- **Design**: agents → collectors; time-series storage (compression, downsampling); query layer; alerting.
- **Deep dives**: cardinality explosion; histogram merging; retention tiers.
- **Helix material**: per-thread histograms, Prometheus export, percentile merging.

---

## Scoring yourself
| Area | 1 (weak) | 3 (solid) | 5 (staff) |
| --- | --- | --- | --- |
| Requirements | Jumped to boxes | Asked and wrote numbers | Drove scope trade-offs |
| Estimates | None | Rough QPS/storage | Used numbers to make decisions |
| Design | Generic | Coherent data flow | Clear ownership and consistency boundaries |
| Deep dives | Hand-wavy | Correct mechanisms | Failure modes, measurements, alternatives |
| Wrap-up | — | Bottlenecks named | Evolution plan, operability |
