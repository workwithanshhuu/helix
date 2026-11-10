# Snapshot format (meta/wal/snapshot.go)

A snapshot is the full state machine at Raft index *i* plus the term of *i*. It bounds WAL size and recovery time, and is sent to lagging followers with `InstallSnapshot`.

## 1. File

`<data_dir>/snap/<last_included_index 20 digits>-<term 20 digits>.snap`

```
+-----------+---------+------------------------+--------------------------+------------+
| magic u32 | ver u16 | last_included_index u64| last_included_term u64   | len u64    |
+-----------+---------+------------------------+--------------------------+------------+
| state-machine bytes (len bytes, protobuf `StateSnapshot`, tables with sorted keys)    |
+---------------------------------------------------------------------------------------+
| crc32c u32 over everything above                                                      |
+---------------------------------------------------------------------------------------+
```

`magic` = `0x534E4C48` ("HLNS"), `ver` = 1.

## 2. Writing safely

1. Serialize with sorted keys (determinism: two replicas at the same index produce identical bytes).
2. Write to `<name>.tmp`, `fsync` the file.
3. `rename` to the final name (atomic), `fsync` the `snap/` directory.
4. Write a `SnapshotMarker` WAL record, fsync, then delete covered segments and older snapshots (keep the previous one as a fallback).

A crash at any step leaves either the old snapshot or the new one valid; recovery ignores `.tmp` files.

## 3. Loading

Pick the newest file whose CRC verifies; fall back to the previous one if not. `Restore()` replaces all tables and rebuilds secondary indexes.

## 4. InstallSnapshot

Sent when a follower's `nextIndex` ≤ the leader's `last_included_index`. Single message up to 4 MiB; chunked above that (stretch). The follower keeps log entries after the snapshot only if they match.
