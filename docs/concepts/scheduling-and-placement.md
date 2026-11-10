# Cluster scheduling and placement

## 1. The idea

A cluster scheduler decides **which machine runs which task**. Good decisions keep data movement low (locality), spread load (balance), respect capacity (feasibility) and react quickly when things change — while the scheduler itself does not become the bottleneck.

## 2. Classic designs

| Design | Example | Idea | Weakness |
| --- | --- | --- | --- |
| Monolithic centralized | Borg, Kubernetes scheduler | One scheduler, global view, feasibility then scoring | Throughput limit at very large scale |
| Two-level | Mesos, Helix | Global decides the node, local decides core/order | Global lacks fine-grained info |
| Shared-state optimistic | Omega | Several schedulers, optimistic commits on shared state | Conflicts at high utilization |
| Distributed sampling | Sparrow | Probe d random workers, place on least loaded; late binding | No global view (locality, fairness) |
| Bottom-up/decentralized | Ray (local first, spill to others) | Local scheduler handles what it can | Harder global policies |

**Power of two choices**: pick 2 random candidates, choose the less loaded. Max load drops from Θ(log n / log log n) (random) to Θ(log log n) — exponentially better, for almost no cost.

## 3. Helix's scheduler (days 32–33) — `meta/sched` (leader only)

For each READY task:
1. **Feasibility**: node ALIVE, enough free store bytes for outputs, not draining.
2. **Candidates**: nodes holding the most input bytes (locality), plus 2 random feasible nodes (power of two).
3. **Score**: `w_loc · local_input_bytes/total_input_bytes − w_q · queue_depth/max_q − w_mem · (1 − free_store/capacity)`; weights in config.
4. **Commit**: batch `GrantLease` commands into one Raft proposal (≤ 256).
5. **Spillback**: a worker whose queue is above a threshold refuses a lease; the task returns to READY with that node excluded briefly (no attempt increment).

Load information (queue depth, free store) comes from heartbeats — slightly stale, which is why spillback exists (late correction).

## 4. Measuring it
- **Skew test** (day 33): all inputs on one node; measure max/mean queue depth over time; target < 1.3 within 2 s with spillback (SPEC G6).
- **Locality**: bytes fetched over the network per job, with and without locality weight.
- **Scheduler throughput**: tasks placed per second; Raft batch sizes.

## 5. Pitfalls
- **Herding**: all decisions use the same stale load → everyone picks the same "least loaded" node. Fix: power of two choices (randomness) + spillback.
- **Locality starvation**: always waiting for the "best" node. Fix: delay scheduling with a bound (Spark), or just score.
- **Scheduler on the hot path**: per-core decisions centrally → bottleneck. Two-level keeps that local.
- **Leases without capacity accounting** → oversubscription.

## 6. Check yourself
1. *Why two-level?* — Global placement needs consensus and a global view; core-level decisions need nanoseconds.
2. *Why does power of two choices work?* — Comparing two samples avoids the worst nodes with high probability.
3. *What is spillback?* — The worker rejecting work it cannot handle soon, returning it for re-placement.
4. *What breaks at 10,000 nodes?* — Single leader scheduling throughput and the object directory in Raft; shard by job/hash, move the directory to an owner-based design (Ray ownership).

## 7. Read more
- Verma et al., "Large-scale cluster management at Google with Borg" (EuroSys 2015).
- Ousterhout et al., "Sparrow" (SOSP 2013); Mitzenmacher, "The Power of Two Choices in Randomized Load Balancing".
- Schwarzkopf et al., "Omega" (EuroSys 2013); Hindman et al., "Mesos" (NSDI 2011).
- Zaharia et al., "Delay Scheduling" (EuroSys 2010).

## Field notes
_(added by day logs)_
