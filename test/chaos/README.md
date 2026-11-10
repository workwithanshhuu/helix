# test/chaos — fault injection (day 35)

Runs a workload against the compose cluster while randomly killing, pausing (`SIGSTOP`) and partitioning (`tc netem`, `iptables`) containers, then checks: every succeeded job's checksum is correct, no job is stuck > 60 s after faults heal, and the metadata history is linearizable (Porcupine).

Covers the rows of [SPEC.md §6](../../SPEC.md#6-failure-scenarios). Always heals faults in a `finally` block.
