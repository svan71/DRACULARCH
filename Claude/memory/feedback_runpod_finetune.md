---
name: RunPod fine-tune lessons (Unsloth + flash-attn)
description: Hard-won lessons from the 2026-04-29 9B run — torch pinning, flash-attn build pitfalls, breakeven discipline
type: feedback
originSessionId: 11d5ba06-da3a-491d-943a-d3dc8bc4162c
---
When setting up a fresh RunPod CUDA pod for Unsloth fine-tuning, do these BEFORE any pip install:

1. **Pin `torch` to whatever the base image ships.** RunPod's `runpod/pytorch:*` images come with FA2 prebuilt against a specific torch (e.g. torch 2.8 + cu128). If `pip install unsloth` is allowed to bump torch (it pulled torch 2.10), the prebuilt FA2's ABI breaks and you'll be forced into a from-source rebuild. Use `pip install unsloth ... torch==<image_torch_version>` or `--upgrade-strategy only-if-needed`.

2. **If FA2 must be built from source, set both:**
   - `TORCH_CUDA_ARCH_LIST="9.0"` (or whatever your GPU is — H100=9.0, A100=8.0). Default builds for ALL arches (sm_80/90/100/120) — 4× the work.
   - `MAX_JOBS=8` (or however many cores). Default is single-threaded.
   - With both set, build drops from 30-45 min to ~5-8 min.

3. **Don't pursue "risky win" optimizations without checking for prebuilt wheels first.** Before recommending `pip install flash-attn`, run `pip index versions flash-attn` or check the github releases — if no wheel exists for your exact torch+cuda+python combo, source build is guaranteed and you should price it at 30-45 min, not 10 min.

4. **Be honest about breakeven.** "Saves 10 min, might cost more if it fails" is sloppy when the realistic from-source build time alone exceeds the savings. Compute the realistic worst case first; only greenlight if savings comfortably exceed worst-case cost.

**Why:** On 2026-04-29 the 9B run lost ~38 min of H100 time (~$3) on an FA2 source build that was triggered by an unnoticed torch 2.8→2.10 bump from the unsloth install. The build was building for 4 GPU arches single-threaded — fixable in advance with two env vars. Steve was rightly furious.

**How to apply:** Any time you spin up a fresh fine-tune pod (RunPod, Lambda, etc.) — pin torch, set arch+jobs env vars before any source build, and price every "optimization" against the realistic worst-case cost, not best-case.
