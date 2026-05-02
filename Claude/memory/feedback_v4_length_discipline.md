---
name: V4 synthetic batch length discipline
description: When generating Steve-voice synthetic training entries, write tighter than the bucket cap on first pass. The natural Steve voice + my drafting tendency lands ~1.3-1.5x over each bucket without explicit shortening discipline.
type: feedback
originSessionId: 744f1ffc-88e5-4010-9ed7-c19c79b61cf9
---
When generating v4 synthetic batches (`~/Documents/Training Data/Data/v4/synthetic_batch_NNN.jsonl`), aim for these targets on first write — NOT the bucket caps:

- short: aim **200–240 chars** (cap 249) — single move, one paragraph
- medium: aim **400–560 chars** (cap 600) — two paragraphs max, tight
- long: aim **850–1150 chars** (cap 1200) — three paragraphs max, no fifth section
- essay: aim **1500–2400 chars** (floor 1200) — four to six paragraphs, no rambling close

**Why:** In batches 008 and 009, my first-pass writes systematically overshot. ~80% of medium and long entries blew the cap, requiring 28-25 cleanup edits per batch. Steve voice is dense (specific receipts, hammer sentences, no filler), but I draft with academic-essay rhythm (multi-paragraph buildup, restatement, concluding paragraph, second concluding paragraph). The Steve cadence allows fewer paragraphs than my default.

**How to apply:**
- Hard rule: longs get max 3 body paragraphs + 1 closing line. Mediums get max 2 paragraphs. No "and finally..." restatement.
- When drafting, count paragraphs before writing. If long has 4+ paragraphs, cut the structural one before the closing.
- Drop "in practice" / "the activist coalition" / "the structural reading" phrases — they accumulate. Use them once per entry max.
- Closing stinger should be ONE LINE (per style profile §2 step 5), not a paragraph. "Same standard. Different president." level brevity.
- Writing tight on first pass saves 5–8 cleanup edits per batch. The cleanup loop is the expensive part of the workflow.

## Build-script pattern (validated batch 019, zero trims)

For batches 020+, use a Python builder script instead of editing JSONL directly:

```python
# /tmp/build_batch_NNN.py
ENTRIES = []
def add(user, asst, topic, bucket, move):
    ENTRIES.append({"messages": [...], "topic": topic, "length_bucket": bucket, "argument_move": move})

add("...neighbor claim...", "Name, ...reply...", "immigration", "short", "unique_move_slug")
# ...all 35 entries...

# Then assert distribution + write JSONL + print per-entry length report with cap-violation flags.
```

**Why this beat the in-place pattern:** Batch 018 (in-place edit + trim cycle) had 20 cap violations on first pass. Batch 019 (builder + length-report assert) had 0. The builder forces you to see the length number for each entry as you draft, which gives a tighter feedback loop than scanning a JSONL file after the fact. Re-validate with `validate_batch.py` after writing — same as before.

**Length-aim points sharpened from batch 019:**
- medium: target **430–470** (not 400–560). Two short paragraphs, no third-paragraph reform/coalition close.
- long: target **1000–1150** (not 850–1150). Three paragraphs of ~330 chars each works cleanly.
- short: target **180–230**. The 200–240 band still applies but I land ~190 most of the time.
- essay: 1500–2400 still right; batch 019 essays landed 1882, 2016, 2373.

## Short-bucket closer rule (batch 022 lesson)

Batch 022 had 4 short-bucket cap violations (250-259 chars), all caused by tail "hammer sentence" closers added after the substantive content already landed at 220-240. Closers like "Read your state's PTET statute", "Sue and they fold", "Future cases will test it directly", "Pre-clearance or post-clearance — pick one and own it" each pushed entries over by single-digit chars.

**Rule:** For shorts, the *substantive content* must land at **≤220 chars** so a 1-clause closer fits inside 249. If first-pass body lands at 230+, drop the closer entirely — the body itself is already a Steve-voice complete reply. Don't add a closer "for rhythm" on top of substantive content. Mediums and longs have the headroom; shorts don't.
