# Design doc M2: helix-rpc data plane

| Field | Value |
| --- | --- |
| Status | **Draft** (finalize on day 17) |
| Days | 12–18 · release v0.2 |
| Related | SPEC §3, §5.4, §7; [rpc-wire-protocol.md](../api/rpc-wire-protocol.md); [ADR-0002](../adr/0002-grpc-for-control-plane-custom-data-plane.md); [io_uring concept](../concepts/io-uring-and-zero-copy.md) |

## 1. Summary
A framed request/response and bulk-transfer protocol over TCP using io_uring, built so that tensor payloads are never copied by Helix code: receives land directly in their final buffer and large sends use `send_zc`. Control messages use gRPC instead.

## 2. Goals
| Goal | Measure | Target |
| --- | --- | --- |
| Small-message latency | 64 B echo p50/p99/p99.9 vs offered load, open-loop (B6) | p99 below gRPC C++ async |
| Bulk throughput | GB/s vs payload size (B7) | ≥ 90% of link/loopback bandwidth |
| Zero copy | flame graph | no `memcpy` under Helix frames |
| Bounded memory | slow-consumer test | sender memory ≤ credit + one chunk |
| Robustness | libFuzzer on the parser | 30 min clean |

## 3. Design
- **Threading**: N I/O threads (default 2), each with its own ring (256 SQEs) and its own connections. Cross-thread calls are queued to the owning I/O thread via an MPSC queue + `eventfd`.
- **Read path**: state machine `READ_HEADER → READ_META → READ_PAYLOAD → dispatch`; headers via provided buffer ring + multishot recv; payloads via a `Sink` that returns the destination buffer (store extent from day 31).
- **Write path**: per-connection queue, one in-flight send (ordering), `sendmsg` iovecs (header, meta, payload); `send_zc` above `rpc.send_zc_min_bytes` with buffer release on the notification CQE.
- **Flow control**: `HELLO_ACK` grants initial credit; `CREDIT` frames refill; a sender queues payload frames at zero credit; reading never needs credit (no deadlock).
- **Deadlines/cancel**: `DEADLINE` flag carries remaining time; server drops expired work; `CANCEL` frames.
- **Fallback**: `EpollTransport` implements the same `Transport` interface.

## 4. Alternatives
gRPC for everything (simpler, but copies and HTTP/2 overhead on tensors); FlatBuffers metadata (not needed for fixed structs); RDMA (stretch; needs hardware or SoftRoCE); shared-memory transport for same-host peers (stretch).

## 5. Failure modes
Short sends/recvs, peer reset mid-frame, buffer reused before `send_zc` notification, `-ENOBUFS` on buffer ring exhaustion, malicious lengths. Each has a test.

## 6. Results
_To be filled on day 17._
