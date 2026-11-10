# Leases, fencing tokens and lineage recovery

## 1. The idea

A **lease** is a lock with an expiry: "worker 3 owns task T for the next 5 s, unless it renews". If the worker dies, the lease runs out and someone else can take over — no human intervention. But timeouts cannot tell *dead* from *slow*: a worker paused by GC, a VM stall or `SIGSTOP` can wake up after its lease expired and still think it owns the task. **Fencing tokens** make that harmless: each new lease gets a strictly larger number, and every write carries it; the resource rejects writes with a token older than the newest it has seen.

```
t=0   worker A gets lease, token 42     t=6 lease expired → worker B gets token 57
t=7   A wakes up, sends Complete(42)  → REJECTED: current token is 57
```

## 2. Helix's design (SPEC §5.2)

1. Scheduler proposes `GrantLease(task, node)`; when committed, **token = Raft index of that entry** — unique and monotonic without a separate counter.
2. Leader pushes the lease over `WatchLeases`; the worker runs the task.
3. Worker renews every `ttl/3` via heartbeat (leader memory only — not a Raft write).
4. No renewal for `ttl` → leader proposes `ExpireLease`; task goes back to READY (attempt+1) or FAILED.
5. `CompleteTask(task, token)` is checked **inside `Apply`** (deterministic, on every replica): stale token → rejected.
6. The object store `seal(id, token)` also rejects older tokens.
7. Worker side: if it cannot reach the leader for `ttl`, it cancels its own tasks (its results would be rejected anyway).
8. Leader failover: the new leader gives every lease a fresh TTL (it has no liveness history).

**Why tokens are checked in Apply, not in the API handler**: the handler runs on one node at one time; Apply runs in log order on every replica, so the check is serialized with every other state change — no race between "check" and "commit".

## 3. Lineage recovery (SPEC §5.4)

Objects are immutable and identified by their producer: `ObjectID = (job, task, output)`. When a node dies, its objects are removed from the directory. If a still-needed object has no location left, it becomes LOST and its producer task goes back to READY; if the producer's inputs are also lost, recursion walks up the DAG. Requirement: **tasks are deterministic** (same inputs → same bytes), which is checked by end-to-end checksums in chaos tests.

Lineage vs replication vs checkpointing: lineage costs nothing on the happy path but recovery time grows with the DAG depth to the nearest surviving ancestor; replication costs bandwidth/memory always; checkpointing costs disk I/O always. Ray uses lineage (plus ownership); Spark uses lineage (RDDs) with optional checkpoints.

## 4. Failure walkthroughs
| Scenario | What happens |
| --- | --- |
| Worker `kill -9` | Heartbeats stop → lease expiry (5 s) → re-lease elsewhere; node marked DEAD at 10 s → its objects removed → lineage rebuilds the lost ones |
| Worker `SIGSTOP` 8 s then `SIGCONT` | Lease expired and re-granted (new token); the resumed worker's `Complete` → STALE_TOKEN; its seal on a peer store rejected |
| Network partition worker↔meta | Same as pause from meta's view; worker self-cancels |
| Duplicate `Complete` (retry) | Same token, task already SUCCEEDED → idempotent OK |

## 5. Pitfalls
- **Clock-based reasoning on the worker**: worker and leader clocks differ; Helix's safety never depends on clocks — only liveness does.
- **Token from a counter not in the log**: two leaders could hand out the same number; using the Raft index avoids that.
- **Forgetting to fence the store**: a stale worker could overwrite an object a new attempt sealed.
- **Non-deterministic kernels** (e.g. parallel float reductions in a different order) break lineage checksums → fix reduction order.

## 6. Check yourself
1. *Why can't timeouts alone give mutual exclusion?* — A process can be paused arbitrarily long and cannot know it was paused.
2. *Who checks the token?* — The state machine's `Apply` (and the object store on seal) — the resource, not the client.
3. *Why use the Raft index as the token?* — It is unique, totally ordered and assigned by the consensus log.
4. *What does lineage require of tasks?* — Determinism and immutable inputs.
5. *What happens to leases when the meta leader changes?* — They are renewed with a fresh TTL by the new leader.

## 7. Read more
- Kleppmann, "How to do distributed locking" (2016) and *DDIA* ch. 8 ("The truth is defined by the majority", fencing tokens).
- Gray & Cheriton, "Leases" (SOSP 1989).
- Burrows, "The Chubby lock service" (OSDI 2006) — sequencers.
- Moritz et al., "Ray" (OSDI 2018); Wang et al., "Ownership" (NSDI 2021); Zaharia et al., "RDDs" (NSDI 2012).

## Field notes
_(added by day logs)_
