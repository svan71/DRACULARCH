---
name: mlx_lm.server gotchas (Jan-as-client setup)
description: Serving MLX fine-tunes via mlx_lm.server + Jan as remote OpenAI-compat client — known quirks
type: feedback
originSessionId: 11d5ba06-da3a-491d-943a-d3dc8bc4162c
---
When serving an MLX fine-tune locally via `mlx_lm.server` and pointing Jan at it as a remote OpenAI-compat provider:

1. **`frequency_penalty` and `presence_penalty` are SILENTLY IGNORED** by mlx_lm.server (≥0.31.3). The mlx-native parameter is **`repetition_penalty`** (default 1.0, set to 1.10–1.20 to break loops). If a fine-tune is producing verbatim repetition loops, freq/presence penalties from Jan won't help — push `repetition_penalty` via the assistant's `parameters` dict and hope Jan forwards non-standard fields.

2. **Jan v0.7.9's bundled MLX engine is broken** — the `.metallib` Metal shader file isn't shipped with the app, so the in-app MLX provider fails with `MLX_PROCESS_ERROR: Failed to load the default metallib`. Workaround: run `mlx_lm.server` standalone, add as a "Custom" remote OpenAI-compat provider in Jan, enable Local API Server toggle in Jan settings to allow connections to localhost.

3. **`mlx_lm.server` lists ALL detected model IDs** (including the HF base name pulled from config.json's `model_name`). For our fine-tune, both `Qwen/Qwen3.5-9B` (would auto-download bf16 base, OOMs on 24GB Mac Mini) and `/Users/steve/Models/finetunes/Qwen3.5-9B-MLX-8bit` (the actual fine-tune) appear. **Always pick the local-path ID in Jan's model dropdown**, not the HF name.

4. **Qwen3.5 thinking mode survives fine-tuning.** The base model's thinking-mode bias is strong enough that even after our 2,335-example LoRA fine-tune, the model defaults to producing "Thinking Process: 1. Analyze the Request..." preamble unless the chat template explicitly emits the closed-think marker before the assistant turn. Fix: edit `chat_template.jinja` to unconditionally emit `<|im_start|>assistant\n<think>\n\n</think>\n\n` — bakes "thinking off" into every render, no `chat_template_kwargs` needed (Jan can't pass them anyway).

5. **Tool-calling capability is degraded by Steve-voice fine-tune.** Training data was 100% reply text, no tool-call examples. The fine-tuned model can't reliably emit MCP tool calls even when the system prompt asks it to search. Use DeepSeek for queries that need verification; use Qwen-fine-tune for voice/drafting only.

6. **Names hallucinated.** Training data assistant turns all start with `Name, ...` (real or synthetic neighbor name). When inference prompt has no name, the model picks one from training pool ("Miki", "Lila", "Owen"). Tell users: include the target name in the prompt if you want a specific one; otherwise treat the leading name as a placeholder to delete.

**Why:** Spent hours on 2026-04-29 chasing a "training failed" diagnosis when it was actually all serving-layer config. Save the lessons.

**How to apply:** Any time we serve an MLX fine-tune via mlx_lm.server with Jan or another OpenAI-compat client, walk through this list before re-training or doubting the model.
