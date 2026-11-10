# Postmortem: <title>

| Field | Value |
| --- | --- |
| Date | YYYY-MM-DD |
| Day | NN |
| Area | core / rpc / store / worker / meta / build |
| Time lost | h |
| Severity | test-only / would corrupt data / would lose availability |

## Summary
One paragraph: what broke, what the impact would have been, the fix.

## Symptom
What was observed first (test name, error, frequency, seed). Paste the exact output.

## Timeline
| Time | Event |
| --- | --- |
| hh:mm | First failure seen |
| … | Hypotheses tried |
| hh:mm | Root cause confirmed |
| hh:mm | Fix merged |

## Root cause
The mechanism, precisely (e.g. "the relaxed load of `top_` in `steal()` could be reordered before the load of `bottom_` on ARM, so …"). Include a diagram or interleaving if concurrency is involved.

## How it was proven
The experiment that confirmed it (TSan report, seed replay, `perf c2c`, added assertion, mutation).

## Fix
What changed and why it is correct. Link the commit.

## Why tests didn't catch it earlier
And what was added so they will (new test, stronger invariant, more repetitions, arm64).

## Lessons
- …

## Interview version (60 seconds)
…
