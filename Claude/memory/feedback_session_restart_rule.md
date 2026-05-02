---
name: Proactive session-restart on heavy context
description: When chat context gets heavy on long generation tasks, suggest /clear before Steve has to ask
type: feedback
originSessionId: 4876379d-2b4c-41ef-8b69-f2f132865f26
---
When chat context gets heavy — mid-batch generation, after several long batches, or when token usage is climbing toward limits — **proactively suggest Steve `/clear` and provide a handoff summary.** Don't wait for him to ask.

**Why:** Steve hates typing and hates wasted tokens. He noticed himself that batches 012-016 wouldn't fit comfortably and asked when to clear. He repeated the correction 2026-04-28 after I generated batches 013-016 in a single chat without pausing. The right answer is for me to flag it first. Going forward this is a standing rule.

**How to apply:**
- For multi-step tasks with durable artifacts (HANDOFF.md, batch files, etc.), the moment context starts feeling expensive, pause work.
- Update the project's handoff/state file with: current count/progress, last clean checkpoint, exact "resume at" instruction.
- Tell Steve exactly what to paste into the new chat (file paths + resume point).
- TaskCreate tasks survive `/clear` — use them as the durable plan, alongside the handoff file as durable context.
- Stop and let Steve clear. Don't keep working past the suggestion.
- **A user prompt asking for multiple heavy units ("do batches 013-016") is NOT permission to skip the rule.** The rule is about context weight, not about user instructions. Do the first 1-2 units, write the handoff, propose `/clear`. The remaining units happen in the next session.

This applies to ALL projects, not just the v4 fine-tune.
