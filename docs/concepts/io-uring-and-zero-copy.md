# io_uring, zero-copy networking and RPC design

## 1. The idea

Classic sockets cost a syscall per `read`/`write` and copy every byte between user and kernel buffers. **io_uring** shares two ring buffers between the process and the kernel: you write requests into the **submission queue (SQ)**, the kernel posts results into the **completion queue (CQ)**. Many operations go in with one `io_uring_enter` (or none, with SQPOLL). **Zero-copy** goes further: the kernel DMA's straight from/to your memory instead of copying.

```
user space:   SQ ring ──► [SQE SQE SQE]          [CQE CQE] ◄── CQ ring
                         io_uring_enter()           ▲
kernel:       consume SQEs → perform I/O → post CQEs ┘
```

## 2. Features Helix uses (helix-rpc, days 12–17)

| Feature | What it does | Why Helix uses it |
| --- | --- | --- |
| Batched submission | Many SQEs per syscall | Amortize syscall cost |
| Registered files | Pre-registered fd table | Skip fd refcounting per op |
| Registered (fixed) buffers | Buffers pinned and mapped once | No per-I/O page pinning; required for fast zero-copy |
| Provided buffer rings | Kernel picks a buffer for each receive | Multishot recv without pre-posting a buffer per socket |
| Multishot accept/recv | One SQE → many CQEs | Fewer SQEs on hot sockets |
| `IORING_OP_SEND_ZC` | Zero-copy send; **two CQEs**: result, then a notification when the kernel no longer needs the buffer | Large tensor sends from store extents |
| Linked SQEs, timeouts | Ordering and deadlines | Request deadlines |

**The `send_zc` rule**: the buffer must stay untouched until the *notification* CQE (`IORING_CQE_F_NOTIF`) arrives — that is why the fetch server holds an object-store reference until then. For small messages (< ~64 KiB) zero-copy is slower than copying (page pinning and notification overhead), hence a threshold.

**Receive side**: true zero-copy receive is hard on TCP (needs device header split / `io_uring` zcrx on very new kernels). Helix receives into registered buffers and the **payload lands directly in the destination store extent** by posting the receive into that extent after the header is parsed — no copy in Helix code.

## 3. Helix framing and protocol

32-byte fixed header (magic, version, type, flags, stream id, payload length, trace id, credits…), then raw payload — no protobuf parse on the data path. Spec: [docs/api/rpc-wire-protocol.md](../api/rpc-wire-protocol.md).

- **Thread-per-core**: each I/O thread owns its ring and its connections (Seastar-style); no locks on the I/O path.
- **Flow control**: credit-based per connection — the receiver grants bytes/messages; the sender never sends beyond credits. Prevents a fast sender from exhausting the receiver's buffers (backpressure instead of unbounded queues).
- **Deadlines and cancellation**: every request carries a deadline; expired requests are dropped on both sides.
- **TCP_NODELAY**: avoid Nagle + delayed-ACK 40 ms stalls.
- **Fallback**: `EpollTransport` with the same interface, for kernels without io_uring and as a benchmark baseline.

## 4. Why not just gRPC?
gRPC (HTTP/2 + protobuf) is excellent for the control plane: schemas, deadlines, tooling. On the data path it costs: HTTP/2 framing and flow control layered on TCP, protobuf encode/decode, and copies into gRPC slices. Helix measures this (day 17) rather than asserting it. See [ADR-0002](../adr/0002-grpc-for-control-plane-custom-data-plane.md).

## 5. Pitfalls

| Problem | Symptom | Fix |
| --- | --- | --- |
| CQ overflow | Lost completions (older kernels) / `-EBUSY` | Size CQ ≥ 2× SQ; reap promptly |
| Reusing a buffer before `send_zc` notif | Corrupted data on the wire, rarely | Refcount until notification |
| Short reads/writes | Partial frames | Framing state machine; loop |
| Nagle | 40 ms latency spikes | `TCP_NODELAY` |
| `RLIMIT_MEMLOCK` | Buffer registration fails | Raise limit; document in runbook |
| io_uring disabled (`kernel.io_uring_disabled`) or old kernel | `ENOSYS`/`EPERM` | Day-2 smoke test; epoll fallback |
| Coordinated omission | Benchmarks hide tail latency | Open-loop load generator ([observability-and-tail-latency.md](observability-and-tail-latency.md)) |

## 6. Try it
- `liburing` examples: `io_uring-test`, `send-zerocopy` (in the liburing repo's `examples/`).
- Day 2 smoke test: submit a NOP and a read, check kernel features with `io_uring_get_probe`.
- Day 17: ping-pong latency 64 B–4 MiB: epoll vs io_uring vs gRPC.

## 7. Check yourself
1. *Why two CQEs for `send_zc`?* — The first reports bytes queued; the second says the kernel has released the pages, so the buffer may be reused.
2. *What does registering buffers save?* — Per-I/O `get_user_pages` pinning and mapping.
3. *What is SQPOLL?* — A kernel thread polls the SQ so submission needs no syscall; costs a core.
4. *What is backpressure and how does Helix implement it?* — Slowing producers when consumers fall behind; credits granted by the receiver.
5. *Why thread-per-core?* — No shared state on the I/O path, cache locality, no locks.

## 8. Read more
- Axboe, "Efficient IO with io_uring"; "Lord of the io_uring"; `man io_uring_prep_send_zc`.
- Kernel `Documentation/networking/msg_zerocopy.rst`.
- Kalia et al., "Datacenter RPCs can be General and Fast" (eRPC, NSDI 2019).
- Seastar docs: shared-nothing design.

## Field notes
_(added by day logs)_
