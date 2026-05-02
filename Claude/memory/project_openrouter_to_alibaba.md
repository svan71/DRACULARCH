---
name: OpenRouter → Alibaba Model Studio switch (planned)
description: When OpenRouter credit runs out, drop OpenRouter (Qwen + GPT-5.5-pro) and switch Qwen to Alibaba Cloud Model Studio (international, NOT DashScope-China)
type: project
originSessionId: 8f766b8c-2514-46c3-9abe-0950bf14e9de
---
Steve has ~$20 OpenRouter credit remaining (as of 2026-04-30). When it runs out, he'll move off OpenRouter entirely.

**Current OpenRouter usage (2026-04-30):**
- `qwen` alias / `ask-qwen` (Qwen 3.6 Plus) — retired from delegation flow but config still around
- `ask-gpt` / `delegate-watch gpt` (OpenAI GPT-5.5-pro) — added 2026-04-30 as delegation executor
- `flash` alias (Stepfun Step-3.5 Flash) — minor use

**Plan when credit runs out:**
- Drop OpenRouter as a route entirely.
- For Qwen: switch to **Alibaba Cloud Model Studio** (international product, endpoint `dashscope-intl.aliyuncs.com`), NOT DashScope-China (`dashscope.aliyuncs.com`). Update `~/.config/mg-qwen/claude-qwen-settings.json` accordingly.
- For GPT-5.5-pro: Alibaba does NOT host OpenAI models. Either: (a) point `ask-gpt` directly at OpenAI's API (separate billing), or (b) drop the GPT executor and rely on DeepSeek alone.
- For Stepfun flash: verify if available on Alibaba; otherwise drop or keep paid OpenRouter for that one.
- DeepSeek stays on its own direct API (api.deepseek.com) — already cheapest source, unaffected.

**Why:** OpenRouter takes ~18% markup on Qwen ($0.325/M in vs Alibaba's $0.276/M in). Direct = cheaper. GPT-5.5-pro is more nuanced — OpenAI direct may not be cheaper than OpenRouter, so that decision is open.

**How to apply:**
- Don't pre-emptively migrate; wait until Steve says credit is out.
- When the time comes, ask Steve which path for GPT (OpenAI direct vs drop) before reconfiguring.
