# Linearizability and testing distributed systems

## 1. The idea

**Linearizability**: every operation appears to take effect atomically at some instant between its invocation and its response, and the resulting order is consistent with a sequential specification. To the client the system behaves like a single copy updated one operation at a time, respecting real time: if A returns before B starts, A is ordered before B.

Compare:
| Model | Guarantee |
| --- | --- |
| Linearizable | Single copy, real-time order |
| Sequential consistency | Single total order consistent with each process's program order; may ignore real time |
| Serializable | Transactions equivalent to some serial order (no real-time requirement) |
| Strict serializable | Serializable + real time |
| Eventual | Replicas converge eventually |

## 2. Checking it: Porcupine

Record a **history**: for each client op, (client id, input, output, call time, return time). A checker searches for a linearization (Wing & Gong / Lowe's algorithm with memoization; NP-complete in general but fast for partitioned keys). **Porcupine** (Go, Anish Athalye) does this given a model: `Init`, `Step(state, input, output) → (ok, newState)`, and optional `Partition` by key. It renders an HTML visualization of a failing history.

Helix model (day 26): a key-value view of job state or a register per task: `Submit(req) → JobID` (idempotent), `Complete(task, token) → ok/stale`, `Get(job) → state`.

## 3. Deterministic simulation

Real networks make failures irreproducible. Helix's `meta/sim` replaces the transport with an in-memory network driven by a **seeded RNG**: it delays, drops, duplicates and reorders messages, partitions sets of nodes, crashes and restarts them (keeping only fsynced state). Same seed → same run. Any failure prints `HELIX_SEED=…` for exact replay. (Inspired by FoundationDB's simulation testing and TigerBeetle's VOPR.)

## 4. Test pyramid for Helix's control plane

1. Unit tests: state machine commands, WAL encode/decode.
2. Raft tests with the sim network (elections, replication, persistence, figure 8, snapshots).
3. Randomized "nemesis" tests: client ops + random faults, then Porcupine. 50 seeds × 1,000 ops minimum (SPEC G4).
4. Real processes in docker-compose (day 27): `kill -9`, `iptables` partitions, `SIGSTOP`.
5. Chaos with end-to-end checksums (day 35).

## 5. Pitfalls
- **Recording time wrong**: call time must be taken before sending, return time after receiving, from one clock.
- **Ambiguous outcomes**: a timed-out write may or may not have happened. Model it as an op with unknown output whose return time is infinity (Porcupine supports this by leaving it pending).
- **Too-small histories** miss bugs; too large make checking slow — partition by key.
- **Retries without idempotency** look like duplicates → why Submit carries `request_id`.

## 6. Check yourself
1. *Linearizable vs serializable?* — Linearizability is about single objects and real time; serializability is about multi-object transactions and allows any serial order.
2. *Why is a timed-out request hard to model?* — Its effect may or may not be applied, at any time after invocation.
3. *Why deterministic simulation?* — Reproducibility: a failing seed can be replayed and debugged.
4. *Is reading from a follower linearizable?* — Not by default; needs ReadIndex through the leader (or a follower read protocol that does the same).

## 7. Read more
- Herlihy & Wing, "Linearizability: A Correctness Condition for Concurrent Objects" (1990).
- Kleppmann, *DDIA*, ch. 9.
- Porcupine README and blog post "Testing Distributed Systems for Linearizability" (Athalye).
- Kingsbury, Jepsen analyses (jepsen.io) — how real systems failed these checks.
- FoundationDB simulation testing talk (Will Wilson, Strange Loop 2014).

## Field notes
_(added by day logs)_
