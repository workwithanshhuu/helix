# meta — helix-meta control plane (Go)

The Raft-replicated source of truth for nodes, jobs, tasks, leases and object locations, plus the leader-only global scheduler and the `helixctl` CLI.

| Package | Day | Purpose |
| --- | --- | --- |
| `meta` | 1 ✅ | Version/build info |
| `meta/raft` | 19–26 | Election (PreVote, CheckQuorum), replication, fast backtracking, ReadIndex, snapshots |
| `meta/sim` | 20 | Deterministic simulated network (drop, delay, reorder, partition) |
| `meta/wal` | 23–24 | Segmented WAL, CRC32C records, group commit, snapshots |
| `meta/sm` | 25 | Deterministic state machine (tables in SPEC §4) |
| `meta/api` | 27 | gRPC services: Cluster, Jobs, Tasks, Objects |
| `meta/sched` | 29–34 | Placement, spillback, lease expiry, lineage reconstruction |
| `meta/cmd/helix-meta`, `meta/cmd/helixctl` | 27 | Binaries |

Rules: `sm.Apply` is deterministic; no RPC while holding the Raft mutex; never send on `ApplyCh` while holding a lock; every goroutine has an owner.

Design: [docs/design/m3-control-plane.md](../docs/design/m3-control-plane.md) · API: [docs/api/meta-grpc-api.md](../docs/api/meta-grpc-api.md) · Data: [docs/db/](../docs/db/) · Concepts: [Raft](../docs/concepts/raft-consensus.md), [linearizability](../docs/concepts/linearizability-and-testing.md), [leases](../docs/concepts/leases-and-fencing.md).
