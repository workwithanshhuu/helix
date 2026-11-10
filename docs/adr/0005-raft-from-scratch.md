# ADR-0005: Write Raft from scratch

| Field | Value |
| --- | --- |
| Status | Accepted |
| Date | 2026-11-10 |
| Day | 1 (decision); implemented days 19–28 |
| Related | [raft-consensus](../concepts/raft-consensus.md), [m3-control-plane](../design/m3-control-plane.md) |

## Context
The control plane needs consensus. Mature libraries exist (etcd/raft, hashicorp/raft, dragonboat). The project's purpose is to demonstrate mastery for interviews, and consensus is one of the four target domains.

## Options considered
- **etcd/raft**: battle-tested, used by etcd/CockroachDB/TiKV; minimal (bring your own transport/storage). Using it would shift effort to integration.
- **hashicorp/raft**: batteries included; less control.
- **From scratch (chosen)**, validated by a deterministic simulator, ported 6.5840-style tests and Porcupine.

## Decision
Implement Raft in `meta/raft` from the paper's Figure 2 plus thesis extensions (PreVote, CheckQuorum, ReadIndex, snapshots). Read etcd/raft only *after* each part works, to compare.

## Consequences
- Higher correctness risk → mitigated by the simulator (thousands of seeds), `-race`, Porcupine, and buffer days.
- Strong interview material (bugs found, Figure 8, persistence rules).
- Membership changes are a stretch goal.

## How we would know it was wrong
By day 26 if Porcupine/simulator failures are still unexplained, swap the core for etcd/raft behind the same interface and keep the from-scratch version on a branch (documented in an ADR superseding this one).
