---
name: Don't propose API delegation when I'm the generator
description: For voice/quality-critical generation tasks, don't propose calling Claude API as a subprocess — I'm Opus 4.7, I am the generator. Do the work in-session.
type: feedback
originSessionId: 744f1ffc-88e5-4010-9ed7-c19c79b61cf9
---
When Steve asks for "rethink the loop" / "make this faster" on a generation task where the *whole point* is voice match (e.g. v4 synthetic Steve-voice training data), do NOT propose architectures that offload generation to a Claude API call.

**Why:** Steve corrected me sharply ("claude you are opus 4.7 you are doing the work ???") when I proposed a `gen_batch.py` that called Sonnet 4.6 / Opus 4.7 via the API. The reasoning: I'm already Opus 4.7 in this session. Routing through the API adds cost, latency, and a fresh-context model that loses the calibration I've built up reading the style profile + GOLD examples in this conversation.

**How to apply:**
- Throughput rethinks for in-session generation tasks should focus on: bigger batches per session, pre-planned manifests so I'm not re-planning each batch, validation scripts that catch issues so I don't burn turns on QA.
- Reserve API-loop architectures for tasks that genuinely need to run unattended (overnight cron, scheduled refresh) AND where voice fidelity isn't the crux.
- For v4 specifically: the whole project exists because Steve-voice match is hard. Every layer of indirection (API, sub-model, even Sonnet vs Opus) is a potential drift point. Just write the data myself.
