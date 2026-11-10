# ADR-0002: gRPC for the control plane, a custom io_uring transport for the data plane

| Field | Value |
| --- | --- |
| Status | Accepted |
| Date | 2026-11-10 |
| Day | 1 (design); implemented days 12–17 (data plane), 25–27 (gRPC) |
| Related | [SPEC §3](../../SPEC.md#3-wire-format-helix-rpc-data-plane), [rpc-wire-protocol.md](../api/rpc-wire-protocol.md), [meta-grpc-api.md](../api/meta-grpc-api.md), [design 000 §5.5](../design/000-system-design.md) |

## Context
Two kinds of traffic: **control** (submit, leases, heartbeats, Raft; small messages; needs schemas, deadlines, evolution, good Go support) and **data** (tensor transfers of KiBs to hundreds of MiBs, plus small latency-critical requests worker↔worker; needs zero copies, tight memory control). Owning a high-performance transport is also a core learning and interview goal.

## Options considered
### A. gRPC everywhere
- Pros: one stack, schemas, tooling, streaming, deadlines.
- Cons: HTTP/2 framing + flow control over TCP, protobuf encode/decode, copies into gRPC slices on the data path; little control over buffers; no registered buffers or `send_zc`.
### B. Custom transport everywhere (including Raft and clients)
- Pros: maximum control; one transport.
- Cons: re-implementing schemas/evolution/client tooling for Go; no learning value beyond the data plane; slower to build.
### C. gRPC for control, custom for data (chosen)
- Pros: each plane uses the right tool; data plane can be zero-copy; gRPC baseline makes the comparison concrete.
- Cons: two transports to maintain and observe; trace context must be propagated across both.
### D. Existing fast RPC (eRPC, Seastar RPC, Cap'n Proto RPC)
- Pros: proven performance.
- Cons: eRPC targets DPDK/RDMA; Seastar is a whole framework; less learning; harder to explain every line.

## Decision
**Option C.** Data plane: 32-byte fixed header + raw payload over TCP, io_uring with registered buffers, multishot receive, `send_zc` above a threshold (64 KiB default), credit-based flow control, deadlines, thread-per-core. An `EpollTransport` with the same interface is the fallback and a baseline. Control plane and Raft: gRPC (Go) with protobuf.

## Consequences
- Positive: zero-copy tensor path; direct, measurable comparison vs gRPC on the same messages (day 17).
- Negative: own framing, versioning and fuzzing burden (fuzz target for the frame parser required); two metrics/tracing integrations.
- The comparison must be honest: report where gRPC is competitive (large messages over loopback, operational features).

## How we would know it was wrong
If the day-17 benchmark shows < 20% improvement over a tuned gRPC async server at small and large sizes, the data plane complexity is not justified → keep the code as a learning artefact but document gRPC as the recommended path.
