---
name: Jan → Cherry Studio migration (in progress)
description: Steve switched from Jan to Cherry Studio on 2026-05-01. Multiple Jan-specific configs/scripts/memories need cleanup.
type: project
originSessionId: a2c641ce-9e93-4080-a28c-d4e770cb43b1
---
Steve switched from Jan to Cherry Studio for his local AI GUI client. Effective 2026-05-01.

**Things still referencing Jan that need review/cleanup:**

- `~/.claude/CLAUDE.md` (global) — entire "Jan (GUI — `jan`)" section, plus the "save jan files / update jan backup" workflow, plus the Synology Jan Backup path references scattered through DeepSeek/OpenCode/Tavily MCP sections.
- `~/Desktop/bash.sh` — `install_jan` function, the Jan restore steps, and the dependent restore paths (assistant.json, mcp_config.json, localStorage.sqlite3 to a hardcoded WebKit hash).
- Synology backup directory `/Volumes/external/WEB Scripts/Scripts/Jan Backup/` — historically held Jan configs, but ALSO holds many non-Jan files (mg-deepseek-settings.json, mg-deepseek-key.env, opencode_auth.json, mcp_config.json with Tavily key). The directory name is now misleading; consider renaming or just leave it as historical naming.
- Memory files that mention Jan: `feedback_ai_delegation_routing.md`, `project_openrouter_to_alibaba.md`.
- Tavily key currently extracted from `Jan Backup/mcp_config.json` — that file may or may not still be the source of truth depending on whether Cherry uses a similar export.

**What we don't yet know about Cherry Studio (to ask in next chat):**

- Where Cherry stores its assistants / MCP config / API keys on macOS.
- Whether Cherry has an export/import workflow Steve wants to back up.
- Which models Cherry talks to (DeepSeek direct? OpenRouter? Alibaba? Local Ollama?). This intersects with the OpenRouter-drop decision in `project_openrouter_to_alibaba.md`.

**Don't pre-emptively rip out Jan references** until Steve walks through what's actually changed in the next session. He intentionally wanted a fresh chat to go over it.
