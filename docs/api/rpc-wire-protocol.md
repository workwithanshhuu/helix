# helix-rpc wire protocol

Authoritative definition: [SPEC.md §3](../../SPEC.md#3-wire-format-helix-rpc-data-plane). This page adds worked examples, flows and implementation notes. Status: 🛠 specified, implemented days 12–17.

## 1. Frame layout

```
 0               4   5   6       8                               16
 +---------------+---+---+-------+-------------------------------+
 |   magic u32   |ver|typ| flags |          request_id u64       |
 +---------------+---+---+-------+---------------+---------------+
 16              20              24              28              32
 +---------------+---------------+---------------+---------------+
 | stream_id u32 |  meta_len u32 |payload_len u32| header_crc u32|
 +---------------+---------------+---------------+---------------+
 | metadata (meta_len bytes, fixed-layout struct per type)         |
 +-----------------------------------------------------------------+
 | payload (payload_len bytes, raw)  [+ 4-byte CRC32C if flag 1]   |
 +-----------------------------------------------------------------+
```

All integers little-endian. `magic` = `0x31584C48` ("HLX1" in memory). `header_crc` = CRC32C over bytes 0–27.

## 2. Worked example: a 64-byte echo request

| Bytes (hex) | Field | Value |
| --- | --- | --- |
| `48 4c 58 31` | magic | "HLX1" |
| `01` | version | 1 |
| `10` | type | REQUEST |
| `00 00` | flags | none |
| `07 00 00 00 00 00 00 00` | request_id | 7 |
| `00 00 00 00` | stream_id | 0 (unary) |
| `02 00 00 00` | meta_len | 2 (method u16) |
| `40 00 00 00` | payload_len | 64 |
| `xx xx xx xx` | header_crc | CRC32C(bytes 0..27) |
| `01 00` | meta: method | 1 = Echo |
| 64 bytes | payload | echo body |

The response echoes `request_id = 7` with `type = 0x11 RESPONSE` and meta `status u16 = 0`.

## 3. Flows

### Connection setup
```
client                                   server
  | -- HELLO(node_id, features) -------->  |
  | <-- HELLO_ACK(node_id, initial_credit) |   credit default 16 MiB
```

### Object fetch (chunked, flow-controlled)
```
consumer                                       producer
  | -- FETCH_OBJECT(id, offset=0, len=all) -->  |  pin object (refcount++)
  | <-- OBJECT_DATA(id, off=0, total) [4 MiB] --|  send_zc from mmap extent
  | <-- OBJECT_DATA(id, off=4Mi)      [4 MiB] --|
  | -- CREDIT(+8 MiB) ------------------------> |  consumer consumed chunks
  | <-- OBJECT_DATA(..., END_STREAM)  [rest] ---|  unpin after notification CQE
```
If the producer no longer has the object: `OBJECT_NOT_FOUND(id)`; the consumer aborts its partial extent and tries another location (SPEC §5.4).

### Cancellation and deadlines
`DEADLINE` flag: metadata begins with remaining time in ns (u64); the receiver converts it to its own monotonic clock. `CANCEL(request_id)` asks the peer to stop work; a late response to a cancelled call is dropped by the client.

## 4. Receiver state machine

```
READ_HEADER --(32 bytes, magic/version/crc ok, lengths within limits)--> READ_META
READ_META   --(meta_len bytes)--> READ_PAYLOAD (or DISPATCH if payload_len == 0)
READ_PAYLOAD --(payload_len bytes into Sink buffer)--> DISPATCH --> READ_HEADER
any state --(bad magic/version/crc, oversize length, EOF mid-frame)--> send ERROR(INVALID), close
```

Frames may be split across many receives, and several frames may arrive in one receive; the state machine must handle both.

## 5. Implementation notes and pitfalls

- Validate **before** allocating: never allocate `payload_len` bytes until the header CRC and limits pass.
- One in-flight send per connection keeps frames from interleaving; use `sendmsg` with iovecs (header, meta, payload).
- A short send completion means "resubmit the remainder", not an error.
- With `send_zc`, the buffer may be reused only after the **notification** CQE (`IORING_CQE_F_NOTIF`), not the first completion.
- Credits are never needed to *read*; otherwise two peers waiting for credit deadlock.

## 6. Limits

| Limit | Value | On violation |
| --- | --- | --- |
| `meta_len` | ≤ 64 KiB | `ERROR(INVALID)`, close |
| `payload_len` | ≤ 1 GiB per frame | `ERROR(INVALID)`, close |
| `version` | ≤ 1 | `ERROR(UNSUPPORTED)`, close |
| unknown `type` | — | `ERROR(UNSUPPORTED)` |
| unknown flag bits | — | ignored |
