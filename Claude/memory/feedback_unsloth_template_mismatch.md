---
name: Unsloth chat-template mismatch is a unified root cause
description: Three apparent bugs in Unsloth-trained Qwen3.5-VL deployments (vision crash, thinking loops, tool-call extraction failure) are one underlying mismatch — Unsloth's adapter exports an old text-only chat template that doesn't match what the Qwen3.5 base expects. Fix at training time, not inference.
type: feedback
originSessionId: 8e4a1d1b-0dbf-4021-89db-9921ef64b83e
---
When debugging an Unsloth-trained Qwen3.5-VL (or similar modern VLM) LoRA in oMLX, do NOT treat the following as separate bugs — they are one root cause:

1. **"Image attachments crash with 500: can only concatenate str (not 'list') to str"** — adapter's chat template lacks the `render_content` macro that handles multimodal content arrays.
2. **"Model loops in unbounded 'Thinking' generation"** — adapter's chat template lacks thinking-mode logic (`<think>...</think>` parsing on assistant messages, `<think>\n` opener at `add_generation_prompt`, `enable_thinking` gate). Modern Qwen3.5 base expects these markers; without them in the prompt grammar, the model opens internal reasoning with no formal end-of-thought signal and runs away.
3. **"Tool calls don't get extracted by oMLX even though the model emits them"** — base template uses Qwen3-Coder XML; adapter template + your training data use Hermes JSON. Wholesale-copying the base template makes the model emit Hermes (training wins) but oMLX's auto-selected parser switches to qwen3_coder, so the calls don't get parsed.

**Why:** Unsloth's `save_pretrained_merged()` (and adapter export by default) ships a generic text-only Qwen template. It predates multimodal content arrays, predates Qwen3.5's thinking-mode protocol, and hardcodes a tool format that may not match the base. All three mismatches surface only at inference time, in different surfaces.

**How to apply:**

**Option A — patch at inference (cheap, accumulates):** Build a hybrid chat_template.jinja per `feedback_vlm_local_remerge.md` (vanilla's `render_content` macro + adapter's Hermes-JSON tool section), then ALSO graft in the thinking-mode block from vanilla (`<think>\n` opener at `add_generation_prompt`, optional `enable_thinking=false → <think>\n\n</think>\n\n`, plus the `<think>...</think>` parsing in assistant-message rendering). Every future base-model feature update means another patch. This is the road v3 is on.

**Option B — fix at training time (clean, one-and-done):** In `build_dataset.py`, format every training example through the base's native chat_template.jinja (`~/.omlx/models/Qwen3.5-9B-MLX-8bit/chat_template.jinja` or equivalent) BEFORE the trainer sees it. The LoRA learns in the same grammar the base uses. At inference, ship the base template unchanged. Vision + thinking + tools all "just work" with no hybrid, no patches, no backups. **This is what Unsloth should have done by default.** For v4 this is the recommended approach — bundle it with the OOD reasoning fix (more rigorous-reasoning examples) into one training pass.

The trap is treating each surface as its own bug and chaining patches. They're symptoms of one wrong template at training time. If a session is debugging Unsloth-VLM weirdness, ask first: "Is this the chat-template mismatch?" before reaching for new patches.
