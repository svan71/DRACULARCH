---
name: Use FastVisionModel on VLM bases
description: Unsloth has two loaders. FastLanguageModel drops the vision tower at load time on a VLM base; the resulting merged checkpoint will not have vision. Always use FastVisionModel on a VLM base, even if training data is text-only.
type: feedback
originSessionId: 417f5d68-c76c-4515-ac08-60f78f59f188
---
When fine-tuning a vision-language model (VLM) base via Unsloth, **always use `FastVisionModel.from_pretrained()`**, not `FastLanguageModel.from_pretrained()`.

**Why:** `FastLanguageModel` only loads the language side of a VLM — vision encoder + projector are silently dropped. When you save the merged checkpoint, the vision tower is gone. The output will load as a plain LLM, not a VLM.

**How to apply:** Check the base model's HuggingFace card or oMLX `type:` tag. If it's `vlm` (e.g., Qwen3.5-9B-MLX-8bit, Qwen2.5-VL, Llama-3.2-Vision), use `FastVisionModel`. Even if training data is text-only — pass `finetune_vision_layers=False` so the vision tower stays frozen but is preserved through the merge.

**How to verify after merge:** in oMLX (or any inference server that introspects HF config), the loaded model should report `type: vlm, engine: vlm`. If it says `llm`, the vision tower didn't make it into the merged checkpoint.

**Cost of getting this wrong:** the v2 fine-tune (2026-04-27) trained for ~5 hours and ~$12 on Steve's project, and the resulting model lost the entire vision capability — which was the #1 reason that base was chosen.

**Bigger gotcha discovered with v3 (2026-04-27 evening):** Even using `FastVisionModel.from_pretrained()` correctly, **Unsloth's `model.save_pretrained_merged()` STILL drops the frozen vision tower** when `finetune_vision_layers=False`. v3 trained cleanly with FastVisionModel, but the merged-bf16 checkpoint had only `language_model.*` keys (zero vision keys). Same `type: llm` regression as v2.

**Workaround:** do NOT rely on Unsloth's merge. Save only the LoRA adapter from training, then merge locally with `peft`'s `merge_and_unload()` after loading the base via `transformers.AutoModelForImageTextToText.from_pretrained()` (or equivalent VLM-aware class). This preserves the vision tower through merge. Verify by counting `visual.*`/`vision.*` keys in the resulting `model.safetensors.index.json` — must be > 0.
