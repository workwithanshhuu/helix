# Write-ahead log format (meta/wal)

The Raft log **is** the WAL. Each helix-meta replica appends every Raft entry and every hard-state change to segment files before acknowledging anything that depends on them.

## 1. Directory layout

```
<data_dir>/
├── wal/
│   ├── 00000000000000000001.seg    # name = first Raft index in the segment (20 digits, zero-padded)
│   ├── 00000000000000052113.seg
│   └── ...
└── snap/                           # see snapshot-format.md
```

Segments roll at `wal.segment_bytes` (64 MiB). A new segment is created, then the file **and the directory** are fsynced before it is used.

## 2. Record format

```
+-----------+-----------+---------+------------------+
| len u32   | crc32c u32| type u8 | payload (len B)  |
+-----------+-----------+---------+------------------+
```

- `len`: payload length in bytes (little-endian). Maximum 16 MiB; larger is treated as corruption.
- `crc32c`: Castagnoli CRC over `type` + `payload`.
- Record types:

| Type | Name | Payload |
| --- | --- | --- |
| 1 | `Entry` | `index u64, term u64, command bytes` |
| 2 | `HardState` | `term u64, voted_for u32 (0 = none), commit u64` |
| 3 | `SnapshotMarker` | `last_included_index u64, last_included_term u64` |
| 4 | `Truncate` | `from_index u64` (follower deleted conflicting entries ≥ this index) |

## 3. Write path and durability rule

1. Raft collects proposals/votes for up to `raft.max_batch_wait_us` (500 µs) or `raft.max_batch_entries` (256).
2. Records are appended with one `write`/`writev`; then one `fdatasync` covers the whole batch (**group commit**).
3. Only after `fdatasync` returns: reply to `RequestVote` (vote granted), acknowledge `AppendEntries`, or count the leader's own entry toward commit.
4. If `fdatasync` fails, the node **stops** (marks itself unhealthy, rejects proposals). Retrying fsync is unsafe: the kernel may already have dropped the dirty pages.

## 4. Recovery

1. Load the newest valid snapshot (if any).
2. Read segments in name order; for each record verify `len` bounds and CRC.
3. On the first invalid record: it is a **torn tail** if it is in the last segment → truncate the file at that offset and continue; anywhere else → corruption, refuse to start.
4. Replay: rebuild `currentTerm`, `votedFor`, `commit` from the last `HardState`; rebuild the in-memory log from `Entry` records after the snapshot, applying `Truncate` records.

## 5. Compaction

After a snapshot at index *i* is durable, delete every segment whose entries are all ≤ *i*. Deletion order: snapshot fsynced → marker record written and fsynced → segments deleted.

## 6. Tests (day 23)

Torn tail at every byte offset of the last record; fsync failure via fault-injecting file; restart preserves term and vote; crash/restart during churn; recovery time for 100k entries.
