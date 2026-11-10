# Metadata schema (helix-meta state machine)

All cluster state is a set of in-memory tables inside `meta/sm`, changed **only** by applying committed Raft commands in log order. Every replica applies the same commands and therefore holds identical tables. Think of it as a tiny replicated database whose "SQL" is the command list in §3.

## 1. Identifier types

| Type | Go type | Definition | Properties |
| --- | --- | --- | --- |
| `NodeID` | `uint32` | Assigned at `RegisterNode` (counter in the state machine) | Never reused; a restarted worker gets a new one |
| `JobID` | `uint64` | Raft index of the `SubmitJob` entry | Unique, increasing with submission order |
| `TaskID` | `struct{Job JobID; Index uint32}` | Position in the submitted DAG | Deterministic |
| `ObjectID` | `struct{Job JobID; Task uint32; Output uint32}` (16 bytes on the wire) | Producer identity | Encodes lineage: the producer is implied |
| `Attempt` | `uint32` | Starts at 1; +1 per re-lease (not on spillback) | Bounded by `task.max_attempts` |
| `FencingToken` | `uint64` | Raft index of the `GrantLease` entry | Strictly increasing per task |
| `RequestID` | `[16]byte` | Client-generated | Idempotency key for Submit |

## 2. Tables

### nodes (key: NodeID)
| Field | Type | Notes |
| --- | --- | --- |
| address | string | host for gRPC |
| data_port | uint32 | helix-rpc port |
| cores, numa_nodes | uint32 | reported at registration |
| memory_bytes, store_capacity | uint64 | |
| state | enum ALIVE, SUSPECT, DEAD, DRAINING | transitions via `MarkNodeState` |

Not replicated (leader memory only): last_heartbeat, queue_depth, free_store_bytes.

### jobs (key: JobID)
| Field | Type | Notes |
| --- | --- | --- |
| request_id | [16]byte | for dedup |
| state | enum SUBMITTED, RUNNING, SUCCEEDED, FAILED, CANCELLED | |
| task_count, tasks_done | uint32 | |
| error | string | first failure reason |

### tasks (key: TaskID)
| Field | Type | Notes |
| --- | --- | --- |
| kernel | string | registry name |
| params | bytes | kernel-specific, opaque to meta |
| inputs | []ObjectID | |
| outputs | uint32 | number of output objects |
| state | enum PENDING, READY, LEASED, RUNNING, SUCCEEDED, FAILED, CANCELLED | see lifecycle |
| attempt | uint32 | |
| max_attempts | uint32 | default 3 |
| pending_inputs | uint32 | inputs not yet SEALED |

### leases (key: TaskID)
| Field | Type | Notes |
| --- | --- | --- |
| node | NodeID | holder |
| token | FencingToken | Raft index of GrantLease |
| ttl_ms | uint32 | expiry tracked in leader memory, not replicated |

### objects (key: ObjectID)
| Field | Type | Notes |
| --- | --- | --- |
| size_bytes | uint64 | |
| locations | sorted set of NodeID | sorted for deterministic snapshots |
| state | enum CREATING, SEALED, LOST, RECONSTRUCTING | CREATING exists only on workers; meta sees SEALED onward |
| pending_consumers | uint32 | consumers not yet finished (for GC) |

### dedup (key: RequestID)
| Field | Type |
| --- | --- |
| job | JobID |

### Secondary indexes (derived, rebuilt on restore)
`ready_queue` (TaskIDs in READY, FIFO by JobID then index) · `tasks_by_node` (NodeID → TaskIDs) · `objects_by_node` (NodeID → ObjectIDs) · `children` (ObjectID → consumer TaskIDs).

## 3. Commands (the only way to change state)

| Command | Fields | Effect | Rejects with |
| --- | --- | --- | --- |
| `RegisterNode` | address, ports, capacity | insert node (ALIVE), return NodeID | — |
| `MarkNodeState` | node, state | update state; on DEAD: remove from all `objects.locations`, expire its leases (same entry) | NOT_FOUND |
| `SubmitJob` | request_id, dag | if dedup hit → return existing JobID; else insert job + tasks (PENDING/READY), dedup row | INVALID (cycle, bad ref, unknown kernel) |
| `GrantLease` | task, node | task READY → LEASED, attempt++, token = entry index, insert lease | stale if task not READY |
| `ExpireLease` | task, reason, count_attempt | remove lease; READY if attempts left else FAILED (job FAILED) | ignored if token mismatch |
| `CompleteTask` | task ref (token), output sizes, node | if token current: SUCCEEDED, insert/update objects SEALED with location = node, decrement children's pending_inputs → READY at 0 | STALE_TOKEN |
| `FailTask` | task ref (token), reason, retryable | like ExpireLease but with the reason | STALE_TOKEN |
| `AddObjectLocation` | node, ids | add node to locations | NOT_FOUND (ignored) |
| `RemoveObjectLocation` | node, ids | remove; if empty and still needed → LOST + producer READY (lineage) | — |
| `CancelJob` | job | all non-final tasks CANCELLED, leases revoked | NOT_FOUND |
| `GcJob` | job | delete finished job's tasks/objects/leases; keep dedup row | — |

**Determinism rules** for `Apply`: no clocks, no random numbers, no I/O, iterate sorted keys only, all inputs come from the command or existing state.

## 4. Invariants (checked by tests in `meta/sm`)

1. A task has a lease row **iff** its state is LEASED or RUNNING.
2. `lease.token` equals the Raft index of the entry that created it, and is greater than any previous token for the task.
3. A task is READY only if `pending_inputs == 0`.
4. Every SEALED object has ≥ 1 location, or it is LOST/RECONSTRUCTING.
5. `jobs.tasks_done` equals the number of the job's SUCCEEDED tasks.
6. Two replicas that applied the same log prefix produce byte-identical snapshots.

## 5. Example: life of a two-task job in commands

```
#41 SubmitJob{req=ab12.., dag=[t0: random → o(41,0,0); t1: checksum(o(41,0,0))]}   job 41: t0 READY, t1 PENDING
#42 GrantLease{task=(41,0), node=2}                                                 t0 LEASED, token 42
#47 CompleteTask{task=(41,0) token=42, sizes=[4194304], node=2}                     o(41,0,0) SEALED @2; t1 READY
#48 GrantLease{task=(41,1), node=3}                                                 t1 LEASED, token 48
#53 CompleteTask{task=(41,1) token=48, ...}                                         job 41 SUCCEEDED
```
