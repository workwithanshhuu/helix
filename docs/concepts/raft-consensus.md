# Raft consensus

## 1. The idea

A set of servers (3 or 5) keeps **identical copies of a log of commands**. If each applies the same commands in the same order to a deterministic state machine, they all hold the same state (**replicated state machine**). Raft makes them agree on that log as long as a **majority** is up and can talk, and it never lets two servers apply different commands at the same index — even with crashes, message loss, reordering and partitions.

Three sub-problems: **leader election**, **log replication**, **safety**. Plus practical extensions: snapshots, PreVote, CheckQuorum, ReadIndex, membership changes.

## 2. Core rules (Raft paper Figure 2 is the spec; implement it literally)

**State per server**: persistent `currentTerm`, `votedFor`, `log[]` (fsynced before replying); volatile `commitIndex`, `lastApplied`; leader-only `nextIndex[]`, `matchIndex[]`.

**Terms** are logical clocks. Any message with a higher term → adopt it, become follower. Messages with lower terms are rejected.

**Election**: follower times out (randomized; Helix default `raft.election_timeout_ms` = 150–300, raised to 500–1000 on slow cloud disks — SPEC §7) → candidate: term++, vote self, `RequestVote` to all. A server grants at most one vote per term, and only if the candidate's log is **at least as up-to-date** (compare last term, then last index). Majority → leader; sends heartbeats (empty `AppendEntries`).

**Replication**: leader appends a command, sends `AppendEntries(prevLogIndex, prevLogTerm, entries, leaderCommit)`. Follower rejects if it lacks a matching `prevLog` entry (**log matching**); leader decrements `nextIndex` (or uses the conflict-term hint) and retries. Conflicting follower entries are truncated.

**Commit**: an entry is committed when stored on a majority **and** it is from the leader's current term (older-term entries commit indirectly). This is the Figure 8 subtlety: never count replicas for an older-term entry.

**Safety properties**: Election Safety (≤ 1 leader per term), Leader Append-Only, Log Matching, Leader Completeness (a committed entry is in every future leader's log), State Machine Safety.

## 3. Extensions Helix implements

| Extension | Problem solved | How |
| --- | --- | --- |
| **PreVote** | A partitioned node keeps bumping its term and disrupts the cluster when it returns | Ask "would you vote for me?" without incrementing term; only start a real election if a majority says yes |
| **CheckQuorum** | A leader cut off from the majority keeps believing it is leader | Leader steps down if it hasn't heard from a majority within an election timeout |
| **ReadIndex** | Linearizable reads without writing to the log | Record commitIndex, confirm leadership with a heartbeat round, wait until applied ≥ that index, then read |
| **Snapshots + InstallSnapshot** | Unbounded log | Snapshot the state machine, truncate the log ([wal-snapshots-durability.md](wal-snapshots-durability.md)) |
| **Batching + pipelining** | Throughput | Group commit; send next AppendEntries without waiting for the previous reply |
| Leader leases for reads | Avoid the heartbeat round | **Not used** (depends on bounded clock drift) |
| Membership change (joint consensus / single-server) | Add/remove servers | Stretch goal |

## 4. Helix specifics
- Go, from scratch, in `meta/raft`. Transport: gRPC (`Raft` service, port 7100) in production, **simulated network** (`meta/sim`) in tests with a seeded RNG for drops, delays, duplicates, partitions → deterministic, reproducible failures.
- The Raft index doubles as identity: `JobID` and `FencingToken` are Raft indices (unique and monotonic).
- `Apply` is deterministic (no clocks/randomness/maps-order) so replicas stay byte-identical.

## 5. Pitfalls (classic 6.824 bugs)

| Bug | Consequence |
| --- | --- |
| Not persisting `votedFor`/`term` before replying | Two votes in one term after restart → two leaders |
| Resetting the election timer on every message (not just valid leader/vote grant) | Livelock / no leader |
| Committing older-term entries by counting | Committed entry later overwritten (Figure 8) |
| Truncating the log on any AppendEntries (not only on conflict) | Losing entries when RPCs are reordered |
| Holding a lock while sending RPCs | Deadlock |
| Applying on a goroutine without order | Out-of-order apply |
| Stale reply processing (old term) | Wrong `matchIndex` |
| Reads served by a deposed leader | Stale reads → non-linearizable |

## 6. Testing
- Port MIT 6.5840-style tests: initial election, re-election, agreement, fail-no-agree, rejoin, backup (fast log catch-up), persist, figure 8 unreliable, snapshots.
- Every test runs with many seeds (`-count=200`), under `-race`.
- Porcupine linearizability check on client histories ([linearizability-and-testing.md](linearizability-and-testing.md)).

## 7. Try it
- raft.github.io visualization: kill the leader, partition, watch terms.
- Day 19: write the election with the sim network; run 1,000 seeds; print the seed of any failure and replay it.

## 8. Check yourself
1. *Why a majority?* — Any two majorities intersect, so a new leader's voters include someone with every committed entry.
2. *Why randomized timeouts?* — Break symmetry to avoid repeated split votes.
3. *Why can't a leader commit an old-term entry by counting replicas?* — A future leader without it could still win and overwrite it (Figure 8).
4. *What does PreVote prevent?* — Term inflation from a rejoining partitioned node forcing needless elections.
5. *How does ReadIndex give linearizable reads?* — It proves the leader was still leader after the read started and waits for the state to include everything committed before it.
6. *What does Raft not handle?* — Byzantine faults; liveness without a stable majority.

## 9. Read more
- Ongaro & Ousterhout, "In Search of an Understandable Consensus Algorithm" (2014) — Figure 2.
- Ongaro's thesis, ch. 3, 4, 6 (reads), 9 (PreVote, CheckQuorum).
- "Students' Guide to Raft" (thesquareplanet.com); MIT 6.5840 labs.
- etcd/raft source as a production reference (read *after* writing your own).

## Field notes
_(added by day logs)_
