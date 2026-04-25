---
name: Fine-tune Project
description: Qwen 2.5 14B fine-tune via MLX-LM on Mac Mini M4 Pro — ACTIVE as of 2026-04-24
type: project
originSessionId: 8ed50aed-4cfc-4621-8dab-0457ff79136c
---
**Current path:** MLX-LM on Mac Mini M4 Pro 24GB (native Apple Silicon, no torch/ROCm needed)

**Why:** ROCm path on RX 6950 XT (RDNA2/gfx1030) abandoned — bnb has no gfx1030 kernels. Unblockable upstream gap.

**Base model:** `mlx-community/Qwen2.5-14B-Instruct-4bit` (~8GB, downloads from HuggingFace on first run)

**Dataset location:** `~/Documents/Training Data/Data/` — 8 JSON files:
- `final_training_set.json` (2.9MB, copy of train_combined.json — use this for training)
- `train_combined.json`, `train_linux.json`, `train_debate.json`, `train_apologetics.json`, `train_general.json`, `train_homelab.json`, `train_windows.json`
- 19,271 train / 1,015 valid examples, `random.seed(42)` split

**Scripts:** `finetune_mlx.py` (trains LoRA + auto-fuses), `export_to_ollama.py` (GGUF q4_k_m → `steve-qwen:14b` in Ollama)

**Est. runtime:** 18–30 hours for 1 epoch — set-and-forget weekend job

**Output:** `merged_model/` (fp16) → `steve-qwen-14b.gguf` (~8.5GB) → registered as `steve-qwen:14b` in Ollama

**If OOM:** reduce `NUM_LAYERS` (16→8) or `MAX_SEQ_LENGTH` (2048→1024) in `finetune_mlx.py`
