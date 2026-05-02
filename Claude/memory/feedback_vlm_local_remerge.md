---
name: VLM LoRA local re-merge — three non-obvious pitfalls
description: When merging an Unsloth-trained vision-LoRA onto a Qwen-VL base locally for MLX deployment, three things will trip you up. Captured from v3 recovery 2026-04-27.
type: feedback
originSessionId: 8e4a1d1b-0dbf-4021-89db-9921ef64b83e
---
When re-merging a LoRA adapter onto a Qwen3.5-VL (or similar HF VLM) base locally and quantizing to MLX-8bit for oMLX, three traps to avoid:

**1. Use `mlx_vlm.convert`, NOT `mlx_lm.convert`.**
The plan-doc said `mlx_lm.convert` — wrong for VLMs. `mlx_lm.convert` silently strips the vision tower at quantize time (same regression as Unsloth's bug). `mlx_vlm.convert` (`python -m mlx_vlm convert ...`) preserves all 333 vision keys.

**Why:** mlx_lm only knows about LM architecture; it doesn't carry vision shards through quantization.
**How to apply:** any time the base has `vision_config` in its `config.json`, use mlx_vlm.

**2. Patch `vision_config.model_type` from `qwen3_5_vision` → `qwen3_5` before mlx_vlm.convert.**
The HF base ships `vision_config.model_type: "qwen3_5_vision"`. mlx_vlm 0.4.4's accepted set is `["qwen3_vl", "qwen3_5", "qwen3_5_moe"]` — it raises `ValueError: Unsupported model type: qwen3_5_vision`. The mlx-community pre-quantized models work because they've been re-tagged to `qwen3_5`.

**Why:** transformers and mlx-community use different conventions for the vision-config model_type field.
**How to apply:** before calling mlx_vlm.convert, edit `merged-bf16/config.json` and set `vision_config.model_type = "qwen3_5"` (or whatever the parent's top-level model_type is). One-line python json patch.

**3. Build a HYBRID chat_template.jinja — vanilla VLM's `render_content` macro grafted onto the adapter's tool-call format.**
Unsloth saves a TEXT-ONLY chat template in the adapter dir (`'<|im_start|>' + message.role + '\n' + message.content + ...`). When oMLX gets a multimodal request (`content: [{image_url}, {text}]`), the template hits `str + list` and the server returns 500 `can only concatenate str (not "list") to str`. Symptom in client: image attachments silently do nothing.

The naive fix (just copy vanilla MLX-8bit's template wholesale) **breaks tool calling** because the two templates use *different* tool-call formats:
- Adapter / training: Hermes JSON `<tool_call>\n{"name": "...", "arguments": {...}}\n</tool_call>`
- Vanilla VLM: Qwen3-Coder XML `<tool_call>\n<function=...>\n<parameter=...>value</parameter>\n</function>\n</tool_call>`

oMLX's tool-call parser auto-detects from the template (`parser=json_tools` for Hermes, `parser=qwen3_coder` for XML). If the model was trained on Hermes JSON but the template tells it to emit XML, the model still emits Hermes (training wins) but oMLX's parser is set to qwen3_coder and **fails to extract the tool call**. Symptom: model confidently fabricates current-events answers (sports schedules, prices) instead of calling brave-search, even with the system prompt instructing tool use.

**Why:** Unsloth's adapter export is LM-flavored (no vision token rendering); but the vanilla VLM template uses the wrong tool format for an Unsloth-trained adapter.
**How to apply:** build a hybrid — keep the adapter's full body (system prompt + Hermes tools section + per-message rendering + tool_response handling), but prepend vanilla's `render_content` macro and substitute every raw `message.content` reference with `render_content(message.content, true)` (or `false, true` for system messages). Keep a `.bak` of the adapter version. After deploy, oMLX log should show `parser=json_tools` (NOT `qwen3_coder`).

**Bonus reproducibility notes:**
- macOS Homebrew Python needs `--user --break-system-packages` for pip installs (PEP 668). Steve's transformers/torch already live in `~/Library/Python/3.12/lib/python/site-packages` — install peft etc. there.
- `AutoProcessor.from_pretrained` on a Qwen3.5-VL needs torchvision installed (`Qwen3VLVideoProcessor requires the Torchvision library`). If you're not actually using the processor in your script, skip it and copy the JSON files manually.
- Restarting oMLX requires killing BOTH the GUI (`osascript -e 'tell application "oMLX" to quit'`) AND the server (`pkill -f "omlx.cli serve"`). Quitting the GUI alone leaves the server running with stale config.
