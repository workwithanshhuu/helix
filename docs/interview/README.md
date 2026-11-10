# Interview preparation

Helix exists to be defended in senior/staff systems and AI-infrastructure interviews. This folder turns the build into interview material.

| Doc | Use it for |
| --- | --- |
| [talking-points-by-company.md](talking-points-by-company.md) | What NVIDIA, Anthropic/OpenAI, Google and VMware/Nutanix probe, and which part of Helix to lead with |
| [elevator-pitch.md](elevator-pitch.md) | 30-second, 2-minute and 5-minute versions of the project story |
| [deep-dive-stories.md](deep-dive-stories.md) | STAR-format stories from real bugs and decisions; **appended to every day** (CLAUDE.md §6) |
| [engineering-traps.md](engineering-traps.md) | The four traps you will hit, how to prove and fix them — your best stories once you hit them |
| [question-bank.md](question-bank.md) | Questions by area with model answers pointing to Helix code |
| [system-design-prompts.md](system-design-prompts.md) | Practice design prompts with reference answers |

## How to prepare (weekly, ~30 min)
1. Re-read the week's day logs' "Explain it back" sections; answer aloud without looking.
2. Pick 5 questions from the question bank in the area you built this week.
3. Update the pitch with the newest measured number.
4. Before an interview: read the company section, rehearse the matching 5-minute deep dive, have the repo, one flame graph and one Perfetto trace ready to share.

## Ground rules
- Only quote numbers that are in `bench/results/` or a day log. Say "on a 4-vCPU cloud VM" etc. — context makes numbers credible.
- Say what you would do differently and where the baseline (gRPC, Ray) wins; it reads as senior judgement.
- Code was written with Claude Code: be upfront if asked, and show you own it — you can explain every invariant, you designed the tests, you debugged the failures (the day logs are your evidence).
