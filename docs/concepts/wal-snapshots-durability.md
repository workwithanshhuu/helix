# Write-ahead logs, snapshots and durability

## 1. The idea

**Durability** means an acknowledged write survives a crash. RAM does not survive; the page cache does not survive power loss; only data the storage device has acknowledged after a **flush** does. A **write-ahead log (WAL)** records each change sequentially *before* acknowledging it; after a crash, replaying the log rebuilds the state. **Snapshots** capture the state at some point so the log before it can be deleted.

## 2. The durability chain

```
write() → page cache (RAM, kernel)  ── fsync/fdatasync ──►  device cache ── FUA/flush ──► media
          lost on power loss / kernel crash                  device must honour flush
```

- `write` returning means only "copied to the page cache".
- `fsync(fd)` flushes data + metadata; `fdatasync` skips metadata not needed to read the data (cheaper; fine for preallocated/appended files when size changes are covered — appends change size, which `fdatasync` *does* flush).
- **New files and renames** live in the *directory*: fsync the directory too, or the file may vanish after a crash.
- **fsync failure is not retryable** ("fsyncgate", PostgreSQL 2018): after an error the kernel may have dropped the dirty pages and marked them clean; a retry can "succeed" without the data. Correct response: crash and recover from the log.

## 3. Torn writes and checksums
A crash mid-write can leave a partially written record (a **torn write**). Each record carries a length and a CRC32C; recovery stops at the first bad record. A bad record at the *tail of the last segment* is an incomplete write → truncate. A bad record anywhere else is corruption → refuse to start (silently skipping would lose committed data).

## 4. Group commit
fsync costs 0.05–10 ms depending on device. Doing one per entry caps throughput at 100–20,000 entries/s. **Group commit** batches entries arriving within a short window (Helix: up to 256 entries or 500 µs) into one write + one fsync. Latency cost: ≤ the window; throughput gain: up to batch size×.

## 5. Snapshots
- Taken every 10,000 entries (`raft.snapshot_every_entries`).
- Pattern: write `x.tmp` → fsync file → `rename(x.tmp, x)` (atomic replace) → fsync directory.
- Must be **consistent**: Helix's state machine is small, so it serializes under the apply lock (copy-on-write or fork-based snapshots are the scalable alternatives — Redis uses `fork`).
- Deterministic serialization (sorted keys) lets tests compare replicas byte-for-byte.

Formats: [docs/db/wal-format.md](../db/wal-format.md), [docs/db/snapshot-format.md](../db/snapshot-format.md).

## 6. Related storage engines (context for interviews)

| Engine | Write path | Read path | Used by |
| --- | --- | --- | --- |
| WAL + in-memory state | Append + fsync | RAM | Helix meta, etcd (bbolt for state), ZooKeeper |
| B-tree | In-place page updates + WAL | O(log n) pages | PostgreSQL, InnoDB, bbolt |
| LSM-tree | WAL + memtable → sorted runs (SSTables) → compaction | Memtable + levels + Bloom filters | RocksDB, LevelDB, Cassandra |

Trade-offs: write amplification, read amplification, space amplification (RUM conjecture). LSM state machine is a Helix stretch goal.

## 7. Pitfalls

| Problem | Consequence | Fix |
| --- | --- | --- |
| Ack before fsync | Lost committed entries after power loss → Raft safety broken | Persist before reply (Raft Figure 2) |
| Forgetting directory fsync | New segment/snapshot disappears | fsync dir after create/rename |
| Retrying fsync | Silent data loss | Crash on fsync error |
| Skipping bad records mid-log | Silent loss | Only truncate the tail |
| One fsync per entry | Throughput collapse | Group commit |
| macOS `fsync` | Does not flush device cache (`F_FULLFSYNC` needed) | Helix runs on Linux |

## 8. Try it
- `fio --name=fsync --rw=write --bs=4k --size=64m --fdatasync=1` in the dev VM and on the cloud box; note the latency (day 23).
- Fault test: truncate the last segment at every byte offset and assert recovery yields a prefix of the entries.

## 9. Check yourself
1. *Why fsync the directory?* — The directory entry that names a new or renamed file is directory metadata.
2. *What is a torn write and how is it detected?* — A partially persisted record; length bound + CRC.
3. *Why not retry fsync?* — The kernel may have already discarded the dirty pages; the retry proves nothing.
4. *How does group commit trade latency for throughput?* — Entries wait up to the batch window, then one fsync covers them all.
5. *Why is rename used for snapshots?* — POSIX rename atomically replaces the target: readers see old or new, never partial.

## 10. Read more
- Kleppmann, *DDIA*, ch. 3 and 7.
- Pillai et al., "All File Systems Are Not Created Equal" (OSDI 2014) — crash consistency.
- "PostgreSQL's fsync() surprise" (LWN, 2018).
- O'Neil et al., "The Log-Structured Merge-Tree" (1996); RocksDB wiki.

## Field notes
_(added by day logs)_
