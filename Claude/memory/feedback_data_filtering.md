---
name: Don't filter training data on "claude" prefix or counter-questions
description: Two false-positive patterns to avoid when filtering Steve's training data
type: feedback
originSessionId: 1c698e5a-7e10-4826-b0cd-0c4418ae8e4e
---
When filtering Steve's fine-tuning datasets for quality, these heuristics produce false positives — they hit real, valuable training data, not garbage:

1. **User prompts starting with "claude X"** — Steve routinely addresses his AI as "claude" because he uses Claude Code daily. "claude what file saves Dolphin context menu settings?" is a real technical question with a real technical answer below it, not a meta-prompt to filter.

2. **Assistant responses with multiple `?` marks (3+) under ~300 chars** — Steve's debate/Nextdoor style is Socratic counter-questioning ("Bigoted against what exactly? Bad writing? Empty ratings?"). That rhetoric is exactly what we want the model to learn, not noise.

**Why:** initial filter run dropped 71 examples — 57 "meta_prompt" by rule #1 and 14 "clarification_loop" by rule #2. Manual review showed both rules were wrong: dropped examples were valid debate-style and tech Q&A. Steve confirmed: train on the full dataset.

**How to apply:** when filtering Steve's data, only filter on objective garbage signals (very short user, very short assistant, clearly-pleasantry-only assistant under N chars). Don't filter based on user phrasing or assistant question density.
