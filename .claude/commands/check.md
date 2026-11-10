---
description: Run the Definition-of-Done gate and explain any failure
---

Run `make check`. If it passes, report the summary (tests passed per suite, sanitizers clean). If it fails, identify the first real failure, explain the root cause in plain language, fix it properly (never by weakening or skipping a test), and re-run until green.
