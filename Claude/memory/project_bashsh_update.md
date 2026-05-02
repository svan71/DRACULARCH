---
name: bash.sh update in progress
description: Pending changes to ~/Desktop/bash.sh for fresh macOS install cleanup
type: project
originSessionId: cb946a99-d082-4467-95af-7a7fb87b11c0
---
bash.sh is at ~/Desktop/bash.sh. Copied to Synology at `/Volumes/External/WEB Scripts/Scripts/All Scripts/bash.sh`.

**Completed 2026-05-01:**
1. ✅ Removed `install_jan()` and its call + status line
2. ✅ Created `Notes/` folder on Synology (`/Volumes/External/WEB Scripts/Scripts/Notes/`) with: `mg-deepseek-key.env`, `mg-deepseek-settings.json`, `tavily_key.txt`, `groq_key.env`
3. ✅ Updated `install_tavily_mcp()` to read from `Notes/tavily_key.txt`
4. ✅ Added `install_groq_config()` — restores Groq key to `~/.config/api-keys.env` and `~/.config/watch/.env`
5. ✅ Removed `install_opencode()` and its call + status line
6. ✅ Updated `install_deepseek_config()` path from `Jan Backup` → `Notes`

**Still pending:**
- **Delete `Jan Backup/` on Synology** — the folder still exists. Safe to delete once confirmed nothing else reads from it. Contents: assistant.json, bigpickle_assistant.json, localstorage.sqlite3, mcp_config.json, mg-openai-key.env, opencode_auth.json, opencode_config.json, opencode_tui.json (all obsolete)
- **Remove OpenRouter aliases from repo bashrc** — `qwen` and `flash` aliases live in the DRACULARCH repo at `macOS/Bash/bashrc`. Need to edit there and push.
- **Update CLAUDE.md** — remove Jan section, Jan Backup section, update DeepSeek backup path from "Jan Backup" to "Notes", remove OpenRouter/qwen/flash/OpenCode sections. File: `~/.claude/CLAUDE.md` (and sync to `~/Dracularch/Claude/macOS/CLAUDE.md`)

**Why:** Simplifying AI stack — Jan removed (switched to Cherry), OpenCode removed (redundant with `deep` alias), OpenRouter removed (qwen/flash not needed).
