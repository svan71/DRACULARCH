---
name: AI delegation routing (Claude as brain)
description: For the Claude Code delegation flow, use Claude (Opus) + DeepSeek + GPT-5.5-pro. Qwen retired from delegation 2026-04-30.
type: feedback
originSessionId: a2c641ce-9e93-4080-a28c-d4e770cb43b1
---
For the Claude Code delegation flow (saving Steve's Max usage by having Opus orchestrate cheap-model executors):

- **Claude Code (Opus)** — the brain. Planning, review, integration, anything with sensitive content (credentials, banking, real names/email/etc).
- **DeepSeek v4 Pro** — primary executor. Heavy code generation, refactors. Direct DeepSeek API → `ask-deep` wrapper in `~/.local/bin` → streams natively.
- **OpenAI GPT-5.5-pro** — installed 2026-04-30 via OpenRouter → `ask-gpt` wrapper → settings at `~/.config/mg-gpt/claude-gpt-settings.json`. **Pay-per-token via OpenRouter is too expensive for routine use** (~$7 for one 1153-line bash script + one detailed review). Steve's stance: if he were going to lean on GPT regularly, he'd buy a ChatGPT plan instead of burning OpenRouter credit. So **don't reach for `ask-gpt` for casual delegation** — only suggest it for genuinely high-stakes one-off tasks (architecture review of critical scripts, hard reasoning, etc.) where the per-call cost is justified. For everything else, route to DeepSeek.
- **Qwen 3.6 Plus (OpenRouter)** — RETIRED for this delegation flow on 2026-04-30.

Why Qwen retired:
- OpenRouter's Anthropic-compat layer buffers Qwen's full response and emits it as one chunk at the end. So "watch window" UX is mostly spinner + lump output — not real streaming.
- In a chunked-rebuild experiment, Qwen repeatedly ignored explicit instructions: wrapped output in markdown fences despite "no fences", printed `ok` after `warn` despite "no false ok", and the third response truncated mid-stream once input got large.
- DeepSeek on the same prompts streamed reliably and followed instructions.

How to apply:
- Default to `ask-deep` / `delegate-watch deep` for delegation.
- Use `ask-gpt` / `delegate-watch gpt` when you want a different model's take, or when DeepSeek's output style isn't a fit.
- The `ask-qwen` and `delegate-watch qwen` wrappers still exist in `~/.local/bin`; not removed in case Steve wants them for ad-hoc uses.
- This decision is scoped to the delegation flow only — it doesn't say anything about the standalone `qwen` Claude Code alias or `openqwen` in OpenCode, which Steve may still use directly.
