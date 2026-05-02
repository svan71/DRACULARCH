---
name: Ghostty terminfo location
description: Ghostty's terminfo lives only inside the .app bundle, generated from Zig source. Every LLM hallucinates a GitHub URL for it; that URL 404s.
type: reference
originSessionId: a2c641ce-9e93-4080-a28c-d4e770cb43b1
---
Ghostty's terminfo is generated at build time from Zig source (`src/terminfo/ghostty.zig` in `ghostty-org/ghostty`) and shipped only inside the macOS app bundle. There is **no static `ghostty.terminfo` file in the repo** to fetch.

The actual install path on macOS:
```
/Applications/Ghostty.app/Contents/Resources/terminfo/
```
Containing precompiled subdirectories like `67/` and `78/` (single-hex-char-prefixed) for the various terminal entry names.

**When restoring/installing terminfo to `~/.terminfo`**, copy from the .app bundle:
```bash
cp -R /Applications/Ghostty.app/Contents/Resources/terminfo/* ~/.terminfo/
```

Steve's `~/Desktop/bash.sh` already does this correctly (in `install_ghostty_terminfo`).

**Hallucinations to ignore** (every LLM tried at least one of these during the bash.sh experiment):
- `https://raw.githubusercontent.com/ghostty-org/ghostty/main/term/ghostty.terminfo` → 404
- `ghostty +list-terminfo` → "invalid action" (doesn't exist)
- `ghostty +show-terminfo` → "invalid action" (doesn't exist)

`+list-actions` IS a real Ghostty CLI action (lists keybinding actions, not terminfo).
