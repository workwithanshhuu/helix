# Design doc M3: helix-meta control plane

| Field | Value |
| --- | --- |
| Status | **Draft** (finalize on day 28) |
| Days | 19–28 · release v0.3 |
| Related | SPEC §2 (meta), §4, §5.1–5.2, §6, §7; [meta-grpc-api.md](../api/meta-grpc-api.md); [docs/db/](../db/); concepts: [Raft](../concepts/raft-consensus.md), [linearizability](../concepts/linearizability-and-testing.md), [leases](../concepts/leases-and-fencing.md), [WAL](../concepts/wal-snapshots-durability.md) |

## 1. Summary
A 3-replica Raft group written from scratch in Go, with a segmented WAL, snapshots, PreVote and CheckQuorum, ReadIndex reads, and a deterministic state machine holding Helix's metadata. Verified with a seeded network simulator and Porcupine.

## 2. Goals
| Goal | Measure | Target |
| --- | --- | --- |
| Safety | election/replication/persistence/snapshot tests, 200 runs with -race; 500–1000 seeds nightly | all pass |
| Linearizability | Porcupine, 5 clients × 1,000 ops, random partitions/crashes | 50/50 seeds pass |
| Availability | leader kill in compose | new leader < 1 s |
| Throughput | commit latency, writes/s with group commit (B8) | recorded; batching measurably helps |

## 3. Design
- **Raft core**: one mutex over state; RPCs never sent while holding it; ticker goroutine for elections (150–300 ms randomized) and heartbeats (50 ms); per-follower `nextIndex`/`matchIndex`; fast backtracking (XTerm/XIndex/XLen); pipelined batches of ≤ 256 entries; commit only current-term entries by counting.
- **Persistence**: WAL segments of 64 MiB with `[len][crc32c][type][payload]` records; `HardState{term,votedFor,commit}` persisted before any reply that depends on it; group commit window 500 µs / 256 entries; fsync failure stops the node.
- **Snapshots**: every 10,000 entries; tmp → fsync → rename → fsync dir; `InstallSnapshot` for lagging followers.
- **Leadership safety**: PreVote, CheckQuorum, ReadIndex for linearizable reads.
- **State machine**: Go maps per table, protobuf commands, deterministic snapshot encoding (sorted keys); fencing token = Raft index of `GrantLease`.
- **Service**: gRPC on 7000 (clients/workers), 7100 (Raft), `/metrics` on 9100; heartbeats in leader memory only.

## 4. Alternatives
etcd/raft or hashicorp/raft (production-ready, but no learning); LSM/bbolt state store (stretch); joint consensus membership (stretch).

## 5. Results
_To be filled on day 28: seed counts, Porcupine runs, failover time, commit latency with/without batching._
