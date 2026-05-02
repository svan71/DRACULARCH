---
name: Fine-tune Project
description: Steve's voice fine-tunes — Qwen3.5-9B + Qwen3-30B-A3B via MLX-LM on Mac Mini M4 Pro, Jan-only deploy
type: project
originSessionId: 8ed50aed-4cfc-4621-8dab-0457ff79136c
---
**Path:** **RunPod CUDA + Unsloth** (decided 2026-04-29). Train on RunPod with torch/Unsloth using bf16 HF bases (`Qwen/Qwen3.5-9B`, `Qwen/Qwen3-30B-A3B`) → rsync merged HF safetensors back to Mac → `mlx_lm.convert --quantize --q-bits 8` locally → drop in `~/Models/finetunes/<base-name>/` → Import in Jan. RunPod is CUDA-only so MLX can't run there; conversion happens locally as the last step.

**V4 status (2026-04-29):** Phase 2 done (1,000/1,000 synthetic, 30 batches). Phase 3 step 1 done — `train.jsonl` + `valid.jsonl` assembled at `~/Documents/Training Data/Data/v4/` (2,335 train / 122 valid). Phase 3 step 2 done — `train_9b.py` (FastLanguageModel) and `train_30b.py` (FastModel + UNSLOTH_COMPILE_DISABLE=1 for MoE) written and verified against current Unsloth/TRL APIs. Both use full-sequence SFT (not `train_on_responses_only` — broken on Qwen3 per Unsloth issue #2771). No system prompt during training. Next: rent pod, scp files, run. Resume context: `~/Documents/Training Data/Data/v4/HANDOFF.md`.

**Storage layout (locked 2026-04-29):**
- `~/Models/bases/` is empty — local MLX bases deleted 2026-04-29 (~25G freed). RunPod pulls bf16 HF bases on the pod itself; Mac never sees a base copy.
- Fine-tune outputs (post-conversion MLX): `~/Models/finetunes/Qwen3.5-9B-MLX-8bit/`, `~/Models/finetunes/Qwen3-30B-A3B-MLX-4bit/` — names match the original mlx-community repo names, no `steve-` prefix. Steve renames in Jan if he wants.
- Old `~/.omlx/models/` location and all v3 fine-tunes (~58G) deleted earlier 2026-04-29 — clean slate.

**Deploy target: Jan ONLY.** oMLX dropped as host 2026-04-29. Jan's MLX provider loads MLX 8bit dirs via Settings → MLX → Import. No symlinks, no GGUF needed. oMLX.app at `/Applications/oMLX.app` retained as a model-download utility only — `~/.omlx/` config dir was deleted and will be auto-recreated empty on next launch.

**Why Jan-only:** Steve confirmed he uses Jan as the runtime, not oMLX. Same MLX artifact works in both, but committing to Jan removes the symlink dance and lets us drop the chat_template.jinja side-copy step.

**Why MLX as deploy format (not GGUF):** Jan has a native MLX provider — same MLX 8bit dir works in oMLX too. Training itself happens on CUDA via Unsloth (RunPod), THEN we convert HF → MLX locally. The "no CUDA pod needed" assumption was wrong — Steve picked RunPod (CUDA), so the local-MLX-LM training path is dropped.

**Pod specs (RunPod):**
- 9B: A100 80GB or A6000 48GB, 100GB disk, template `runpod/pytorch:2.8.0-py3.11-cuda12.8.1-cudnn-devel-ubuntu22.04` (verified current 2026-04). Est. 1–3 hr, ~$1.50–2/hr.
- 30B-A3B: H100 80GB or A100 80GB, 200GB disk. Est. 4–8 hr, ~$2–4/hr.
- Pod setup: `pip install unsloth transformers peft trl accelerate datasets bitsandbytes huggingface_hub wandb`.

**Live training monitoring:** Steve wants visibility while the pod trains. Wire **wandb** into the training script (`report_to="wandb"` in SFTConfig + `WANDB_API_KEY` and `WANDB_PROJECT="steve-voice-v4"` env vars). Watch loss curves / GPU util / ETA at wandb.ai from his Mac browser. Backup: SSH `tail -f` for tqdm progress.

**wandb key location:** `~/.config/wandb/key.env` (chmod 600, same pattern as Steve's Deep key). Source locally or copy values into RunPod's environment-variables UI when launching the pod.

**HF base sources:**
- For RunPod training (bf16 HF): `Qwen/Qwen3.5-9B`, `Qwen/Qwen3-30B-A3B`. Pulled fresh on the pod. Mac never holds a base copy.
- Local MLX bases (`mlx-community/Qwen3.5-9B-MLX-8bit`, `mlx-community/Qwen3-30B-A3B-4bit`) were deleted 2026-04-29 — not needed for the conversion step. `mlx_lm.convert` produces MLX directly from the trained HF safetensors that come back from the pod.

**Dropped paths:**
- ROCm on RX 6950 XT — bnb has no gfx1030 kernels (verified 2026-04).
- Qwen2.5-14B-Instruct-4bit + GGUF + Ollama (`steve-qwen:14b`) — old v3 path, 14B GGUF deleted.
- All `final_training_set.json` / per-category `train_*.json` files in `Documents/Training Data/Data/` — they're claude_export (Claude's voice, NOT Steve's). Do NOT use in v4. Real organic source is `nextdoor_training.jsonl`.

**Open Phase 3 questions:** loss masking (full sequence vs assistant-only), system prompt during training (none vs minimal "You are Steve").
