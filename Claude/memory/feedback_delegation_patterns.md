---
name: AI delegation patterns (chunking, peer-review, watch-window)
description: How to delegate code generation to cheap models effectively — when to chunk vs monolithic, when to use frontier peer-review, watch-window quirks. Learned during the bash.sh experiment 2026-04-30 / 2026-05-01.
type: feedback
originSessionId: a2c641ce-9e93-4080-a28c-d4e770cb43b1
---
## When to chunk vs send a monolithic spec

For multi-hundred-line generations:

- **Monolithic works** when the executor streams reliably (DeepSeek, GPT-5.5-pro direct) AND can comfortably hold the input. DeepSeek streamed 700+ lines on a 1200-token prompt with no truncation. GPT-5.5-pro produced 1153 polished lines on the same input.
- **Chunked is better** when (a) you want verify-as-you-go ("foundation → verify → next chunk"), or (b) the executor truncates on big outputs.
- **When chunking, do NOT re-bundle the previous chunks into the next prompt.** That bloats input and can cause mid-stream truncation (Qwen via OpenRouter cut off chunk 4 because chunk 3 + the chunk 4 spec was too much). Instead, ask the executor to produce ONLY the new chunk as a standalone snippet, and splice it in yourself.

## Frontier-model peer-review trick

Pattern that paid off: have the more expensive frontier model (GPT-5.5-pro) **review** what a cheaper model produced — including a list of proposed improvements I'd already identified — and ask it to agree/disagree on each AND surface ones I missed. The review:
- Caught a real reasoning error in my proposals (claimed bug already fixed in the original).
- Found 5 bugs I'd missed that all three other models had also missed in their from-scratch generations.
- Cost ~$7 but identified critical bugs (data-loss risk, skipped restores) in the production script.

Worth using for high-stakes scripts. Don't use for routine work.

## Verify model-specific claims before applying them

LLMs hallucinated several specifics across this experiment:
- Ghostty `+list-terminfo` / `+show-terminfo` actions (don't exist).
- A GitHub URL for Ghostty's terminfo file (404 — see `reference_ghostty_terminfo.md`).
- ble.sh Makefile claim that PREFIX wouldn't be honored (it is honored).
- ccstatusline custom-widget field name `command` (actual: `commandPath`).

When a model recommends something that depends on a specific URL/flag/path/action existing, **verify it before applying**. A 2-second `curl -I` or `--help` beats a wasted edit + revert.

## Watch-window mechanics (Terminal.app via osascript)

- `open -na Ghostty.app --args -e <cmd>` opens a **new Ghostty instance** each time, which causes macOS to re-prompt for permissions per launch. Avoid.
- `open -a Ghostty.app --args -e <cmd>` brings existing Ghostty to focus but **doesn't run the command**. Ghostty on macOS has no reliable "spawn new window with command" CLI when an instance is running.
- The working pattern is `osascript -e 'tell app "Terminal" to do script "<cmd>"'` followed by `activate`. **Order matters**: `do script` first, `activate` second — reversing them opens an empty default window before the real one (results in 2 windows).
- Spinners written to stdout leak ANSI escapes into any `tee`'d output file. Write spinner output to `/dev/tty` instead so it stays on the terminal but never enters the pipe.
- A shared status file (`/tmp/ai-delegate.status`) gets clobbered by concurrent ask-* invocations. Each call's `trap … EXIT` deletes the file even if another call is still running. Acceptable for current single-call usage; would need per-call status files if running multiple delegated calls in parallel.
