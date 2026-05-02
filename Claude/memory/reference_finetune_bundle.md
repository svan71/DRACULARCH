---
name: Fine-tune playbook bundle
description: Local bundle with reproduction instructions, scripts, and LoRA adapter from the 2026-04-26 Qwen3-30B-A3B fine-tune
type: reference
originSessionId: 1c698e5a-7e10-4826-b0cd-0c4418ae8e4e
---
`/Users/steve/Documents/Training Data/Data/finetune-bundle/` contains everything needed to repeat or rebuild the Qwen3-30B-A3B fine-tune without me:

- `SETUP.md` — full step-by-step playbook: pod specs, pip install pins, both required patches (config.json + mlx-omni-server local-path), data conversion, training, conversion, transfer
- `train.py` — Unsloth training script (run on RunPod pod)
- `convert.py` — converts source JSON/JSONL → chat-format JSONL with system prompt baked in
- `filter.py` — quality filter (was NOT used in final run — false-positive-prone on Steve's debate style)
- `train.log` / `convert.log` — original run output for diff/comparison
- `lora-adapter/` — saved LoRA weights from the original training (~3.7GB). Can be re-fused onto a fresh base in case the merged fp16 needs to be reconstructed without retraining.

**When to consult this:** any time you need to re-train, re-quantize, debug the model setup, or set up a similar fine-tune pipeline.
