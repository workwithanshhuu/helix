# rpc — helix-rpc data plane (C++20), days 12–17

Moves tensor bytes between workers. Control-plane messages use gRPC instead ([ADR-0002](../docs/adr/0002-grpc-for-control-plane-custom-data-plane.md)).

- **Transport**: io_uring (one ring per I/O thread), `EpollTransport` fallback behind the same interface.
- **Framing**: 32-byte header (magic, version, type, flags, request id, stream id, meta/payload lengths, header CRC32C) — [SPEC.md §3](../SPEC.md#3-wire-format-helix-rpc-data-plane), [docs/api/rpc-wire-protocol.md](../docs/api/rpc-wire-protocol.md).
- **Zero copy**: payloads received straight into registered buffers / object-store extents; `send_zc` above 64 KiB.
- **Flow control**: per-connection credits; bounded memory with slow receivers.
- **Robustness**: parser fuzzed with libFuzzer; deadlines and cancellation.

Planned layout: `include/helix/rpc/{uring_loop,frame,crc32c,connection,buffer_pool,sink,flow_control,client,server,future,transport}.h`, `src/`, `test/`, `fuzz/`, `bench/`, `tools/`.

Design: [docs/design/m2-rpc.md](../docs/design/m2-rpc.md) · Concepts: [io_uring and zero copy](../docs/concepts/io-uring-and-zero-copy.md).
