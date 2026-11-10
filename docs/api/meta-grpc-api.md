# helix-meta gRPC API

Status: 🛠 specified; implemented days 25–29 in `proto/meta.proto` and `meta/api/`. Ports: 7000 (clients and workers), 7100 (replica-to-replica Raft, see §5).

## 1. General rules

- Every RPC carries a deadline (clients default 5 s).
- Followers reply `FAILED_PRECONDITION` with metadata `helix-leader: <host:port>` (the `NOT_LEADER` case); clients retry there. If the leader is unknown (election in progress), clients back off 50–200 ms with jitter.
- Mutating calls are idempotent through `request_id` (Submit) or fencing tokens (Complete/Fail), so retries after timeouts are safe.
- Reads are linearizable (ReadIndex) unless marked "stale OK".

## 2. Error mapping

| Helix status | gRPC code | Meaning / client action |
| --- | --- | --- |
| NOT_LEADER | `FAILED_PRECONDITION` + `helix-leader` metadata | Retry at the named leader |
| STALE_TOKEN | `ABORTED` | Lease was superseded; drop local outputs |
| NOT_FOUND | `NOT_FOUND` | Unknown job/task/object |
| INVALID | `INVALID_ARGUMENT` | Malformed DAG or request |
| RESOURCE_EXHAUSTED | `RESOURCE_EXHAUSTED` | Back off |
| DEADLINE_EXCEEDED | `DEADLINE_EXCEEDED` | Retry with the same idempotency key |
| INTERNAL | `INTERNAL` | Bug; report |

## 3. Services (proto sketch)

```protobuf
syntax = "proto3";
package helix.meta.v1;

service Cluster {
  rpc RegisterNode(RegisterNodeRequest) returns (RegisterNodeResponse);     // Raft write
  rpc Heartbeat(HeartbeatRequest) returns (HeartbeatResponse);              // leader memory only
  rpc WatchLeases(WatchLeasesRequest) returns (stream Lease);               // leader pushes leases
}
service Jobs {
  rpc Submit(SubmitRequest) returns (SubmitResponse);                       // Raft write, dedup by request_id
  rpc Get(GetJobRequest) returns (Job);                                     // linearizable read
  rpc Cancel(CancelRequest) returns (CancelResponse);                        // Raft write
}
service Tasks {
  rpc Complete(CompleteRequest) returns (CompleteResponse);                 // Raft write, token-checked
  rpc Fail(FailRequest) returns (FailResponse);                             // Raft write, token-checked
}
service Objects {
  rpc Locate(LocateRequest) returns (LocateResponse);                       // stale OK (cached by workers)
  rpc AddLocations(AddLocationsRequest) returns (AddLocationsResponse);     // batched Raft write
}

message RegisterNodeRequest { string address = 1; uint32 data_port = 2; uint32 cores = 3;
                              uint32 numa_nodes = 4; uint64 memory_bytes = 5; uint64 store_capacity = 6; }
message RegisterNodeResponse { uint32 node_id = 1; uint32 lease_ttl_ms = 2; uint32 renew_every_ms = 3; }

message HeartbeatRequest { uint32 node_id = 1; repeated TaskRef running = 2;
                           uint32 queue_depth = 3; uint64 free_store_bytes = 4; }
message HeartbeatResponse { repeated TaskRef revoked = 1; }   // tasks the worker must cancel

message TaskRef { uint64 job_id = 1; uint32 index = 2; uint32 attempt = 3; uint64 fencing_token = 4; }
message Lease { TaskRef task = 1; string kernel = 2; bytes params = 3;
                repeated ObjectId inputs = 4; uint32 outputs = 5; bytes trace_context = 6; }
message ObjectId { uint64 job_id = 1; uint32 task_index = 2; uint32 output_index = 3; }

message SubmitRequest { bytes request_id = 1; Dag dag = 2; }          // request_id: 16 random bytes
message SubmitResponse { uint64 job_id = 1; }
message Dag { repeated TaskSpec tasks = 1; }
message TaskSpec { string kernel = 1; bytes params = 2; repeated InputRef inputs = 3; uint32 outputs = 4; }
message InputRef { oneof src { TaskOutput task_output = 1; ObjectId existing = 2; } }
message TaskOutput { uint32 task_index = 1; uint32 output_index = 2; }

message CompleteRequest { TaskRef task = 1; repeated uint64 output_sizes = 2; uint32 node_id = 3; }
message CompleteResponse {}
message FailRequest { TaskRef task = 1; string reason = 2; bool retryable = 3; }
message FailResponse {}

message GetJobRequest { uint64 job_id = 1; }
message Job { uint64 job_id = 1; JobState state = 2; uint32 tasks_total = 3; uint32 tasks_done = 4; string error = 5; }
enum JobState { JOB_STATE_UNSPECIFIED = 0; SUBMITTED = 1; RUNNING = 2; SUCCEEDED = 3; FAILED = 4; CANCELLED = 5; }
message CancelRequest { uint64 job_id = 1; }
message CancelResponse {}

message LocateRequest { repeated ObjectId ids = 1; }
message LocateResponse { repeated ObjectLocations objects = 1; }
message ObjectLocations { ObjectId id = 1; uint64 size_bytes = 2; repeated NodeAddr nodes = 3; }
message NodeAddr { uint32 node_id = 1; string address = 2; uint32 data_port = 3; }
message AddLocationsRequest { uint32 node_id = 1; repeated ObjectId ids = 2; }
message AddLocationsResponse {}
```

## 4. Call sequences

**Submit:** client → any replica → (`NOT_LEADER` redirect) → leader validates DAG → proposes `SubmitJob` → waits for commit + apply → returns `job_id` (same id for a retried `request_id`).

**Worker lifecycle:** `RegisterNode` → open `WatchLeases` stream → `Heartbeat` every `renew_every_ms` (lists running tasks; response may revoke) → per lease: fetch inputs → run → `Complete`/`Fail` with the lease's `TaskRef`.

**Leader change:** streams break; workers reconnect to the new leader (found via `NOT_LEADER` metadata) and keep running tasks; the new leader grants all existing leases a fresh TTL (SPEC §5.2 step 6).

## 5. Internal Raft service (port 7100)

```protobuf
service Raft {
  rpc PreVote(VoteRequest) returns (VoteResponse);
  rpc RequestVote(VoteRequest) returns (VoteResponse);
  rpc AppendEntries(AppendEntriesRequest) returns (AppendEntriesResponse);
  rpc InstallSnapshot(InstallSnapshotRequest) returns (InstallSnapshotResponse);
}
message VoteRequest { uint64 term = 1; uint32 candidate_id = 2; uint64 last_log_index = 3; uint64 last_log_term = 4; }
message VoteResponse { uint64 term = 1; bool granted = 2; }
message Entry { uint64 index = 1; uint64 term = 2; bytes command = 3; }
message AppendEntriesRequest { uint64 term = 1; uint32 leader_id = 2; uint64 prev_log_index = 3;
                               uint64 prev_log_term = 4; repeated Entry entries = 5; uint64 leader_commit = 6; }
message AppendEntriesResponse { uint64 term = 1; bool success = 2;
                                uint64 conflict_term = 3; uint64 conflict_index = 4; uint64 log_len = 5; }  // fast backtracking
message InstallSnapshotRequest { uint64 term = 1; uint32 leader_id = 2; uint64 last_included_index = 3;
                                 uint64 last_included_term = 4; bytes data = 5; }
message InstallSnapshotResponse { uint64 term = 1; }
```
