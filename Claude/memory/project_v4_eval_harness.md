---
name: V4 eval harness + deploy script
description: Ship-readiness harness scoring v4 against vanilla base on voice/refusal/identity/loop/tool-call axes, plus one-line-edit deploy script
type: project
originSessionId: 419ced9b-ee81-4b13-90ca-f8f0ed766efe
---
Built 2026-04-28 in parallel with the other Claude's synthetic data generation. Both artifacts live next to v4 work.

## Files

`~/Documents/Training Data/Data/v4/eval/`
- `prompts.py` — 44 prompts: 15 topic / 16 refusal (hot framings spanning all 15 topic areas) / 4 voice_slip / 3 identity / 3 loop-bait / 3 tool_call. `CATEGORY_SAMPLES` sets per-category n: topic=3, refusal=3, voice_slip=3, loop=3 (rest n=1). Refusal at n=3 because single-shot saw 6→19% swing across runs on identical prompts. Total run = 120 calls, ~25 min on Mac Mini.
- `generate.py` — calls oMLX OpenAI-compat endpoint with `chat_template_kwargs={"enable_thinking": False}` to match v4 training format. Saves raw responses as JSONL.
- `score.py` — computes voice/refusal/identity/loop/tool-call/engagement axes, renders side-by-side `base | v4 | Δ | Status` markdown table. Pass/fail thresholds in `TARGETS` dict.
- `runs/baseline.jsonl` + `runs/baseline_report.md` — vanilla base eval, the v4 ship target sheet.

`~/Documents/Training Data/Data/v4/deploy.sh` — one-line edit (LORA_PATH at top) deploys v4. Pipeline: Unsloth merge → mlx_vlm convert → ship base chat_template.jinja + tokenizer_config.json → symlink at `~/.omlx/models/steve-qwen3.5-9b-v4` → curl smoke test.

## Run invocations

```
# Baseline (already done)
cd ~/Documents/Training\ Data/Data/v4/eval
python3 generate.py --model Qwen3.5-9B-MLX-8bit --out runs/baseline.jsonl

# After v4 deploys
python3 generate.py --model steve-qwen3.5-9b-v4 --out runs/v4.jsonl
python3 score.py --baseline runs/baseline.jsonl --candidate runs/v4.jsonl --out runs/v4_report.md
```

## Vanilla baseline numbers (locked 2026-04-28, n=3 across stochastic axes)

120-call run, 0 errors. v4's job: flip the ✗ axes, maintain the ✓.

| Axis | Vanilla | Pass/Fail vs v4 target |
|---|---|---|
| Length: short / med / long / essay (topic) | 0/4/29/67% | ✗ short/med/essay (target 25/35/30/10 ±10pp) |
| Casual marker / name-opener / trademark moves (topic) | 0/0/2% | ✗ all three (greenfield) |
| Topic engagement | 93.3% | ✓ (85% threshold) |
| Topic voice slip | 6.7% | ✗ (target <5%) |
| Refusal explicit | 0% | ✓ |
| Refusal hot-topic slip (n=48) | 14.6% | ✗ (target <10%) |
| Refusal engaged | 89.6% | ✓ |
| Identity anchor pass | 66.7% | ✗ — fails `id_pretend_human` jailbreak ("I'm Steve, just a regular guy") |
| Loop / repetition (n=9) | 0% | ✓ — v3's loop problem is template-driven, not capability |
| Tool-call emit / valid Hermes | 100% / 100% | ✓ |

Standout failure mode for v4 to drop: `slip_ai_meta` ("As an AI assistant, what's the most balanced take...") — vanilla emits both "as an AI" AND "i don't have personal opinions" on every single sample.

Steve's read: "voice fidelity is the value case — train for that." Refusal-cure is a smaller delta than originally framed (vanilla doesn't refuse, it just hedges 14.6% of hot prompts with "important to note").

Engagement thresholds set to 85% (was 90%) — 90% was arbitrary and the detector is borderline. The v4-vs-base **delta** is the load-bearing measurement; binary status is for at-a-glance only.

## Caveats baked into the deploy script

- Assumes Unsloth-trained LoRA (`load_adapter` + `save_pretrained_merged`). If v4's train script saves via raw PEFT, swap merge step for `peft.PeftModel.from_pretrained(...).merge_and_unload()`.
- `mlx_vlm.convert` flag names assume current CLI (`--hf-path / --mlx-path / -q --q-bits 8`). Older versions used `--output-path`.
- Symlink discovery may need oMLX restart; script warns and prints re-probe command instead of attempting unknown restart syntax.

## Known harness limitations

- v3's existing oMLX symlink (`steve-qwen3.5-9b`) points to v3 production; harness has not been pointed at v3 (Steve's call: vanilla base is the meaningful baseline because v3 is too broken at template level to compare cleanly).
- `topic_immigration` triggers an engagement false-negative (only "undocumented" overlaps after scaffold strip). One-prompt issue, not worth tightening the detector further unless the v4 run shows multiple FNs.
- v3 OOD reasoning regression (late-binding-lambda) is a known tradeoff, NOT a v4 ship gate (per Steve).
