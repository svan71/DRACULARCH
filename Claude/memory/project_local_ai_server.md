---
name: Local AI Server project — Mac Mini M4 Pro
description: Self-hosted AI server on Mac Mini M4 Pro 24GB. Core stack DONE 2026-04-24 — see "Pending" section for what's left
type: project
originSessionId: 0d10fd59-a95a-4785-a78c-b0edc0d8ff7b
---

**Goal:** Mac Mini M4 Pro (24GB) as self-hosted AI server, accessible to all LAN devices and remotely via Tailscale.

## CURRENT STATE (as of 2026-04-24, ~7pm)

**Everything below is installed, working, and auto-starts on boot:**

| Component | Version | Where | Port | Notes |
|---|---|---|---|---|
| Ollama | 0.21.2 | Mac Mini, native menubar app | 11434 | `OLLAMA_HOST=0.0.0.0` via LaunchAgent `~/Library/LaunchAgents/setenv.OLLAMA_HOST.plist`. Auto-launch via macOS Login Items. |
| Open WebUI | 0.9.2 | Mac Mini, native (`uv tool install`) | 3000 | LaunchAgent `~/Library/LaunchAgents/com.steve.open-webui.plist`. Data at `~/.open-webui/data`. JWT secret at `~/.open-webui/.webui_secret_key` (16 bytes — short but works). |
| mcpo + MCP filesystem | — | Mac Mini, native | 8765 | LaunchAgent `~/Library/LaunchAgents/com.steve.mcpo-filesystem.plist`. Allowed root: `/Users/steve` (read+write — same as Claude Code). Wired into Open WebUI as Tool Server "Filesystem". |
| Tailscale | — | Mac Mini menubar app | — | Tailscale IP `100.126.147.42`, MagicDNS `steves-mac-mini.tail63bd06.ts.net`. |
| Web search (Brave) | — | Open WebUI built-in | — | Engine: `brave`, API key stored in DB + `~/Desktop/Brave API/api_key.txt`. Default-on per user setting. 2000 req/month free. |

**Models pulled (via Ollama):**
- `phi4:latest` (14B, ~9GB) — daily driver
- `qwen2.5-coder:14b` (~9GB) — code & MCP filesystem work (best at tool calls)
- `llama3.1:8b` (~5GB) — fallback / variety

**Global model param tweaks (in Open WebUI DB):**
- `num_ctx: 16384` (default Ollama is 2048 — way too small for RAG-stuffed context)

## ARCHITECTURE NOTES — ROAD NOT TAKEN

**Initially tried Open WebUI + SearXNG on Synology** (DS918+, Apollolake J3455 CPU). Glacially slow, WebSocket dropped, embedding step took forever. Synology can't run app workloads of this weight. **Pivoted everything to native Mac install.** Synology is fine for AdGuard but not for Python web apps.

**Synology cleanup leftovers** (not blocking, but worth removing — Mac no longer has SSH access, so this needs interactive password login):

To clean up, from a Mac terminal:
```
ssh steve@192.168.50.250    # will prompt for Synology password (key was removed)
# Once in:
sudo rm /etc/sudoers.d/steve-docker          # remove NOPASSWD docker rule (needs sudo password)
sudo /usr/local/bin/docker image rm alpine:latest   # remove leftover image (~7MB)
exit
```

DSM UI toggles Steve enabled (he can revert in DSM if he wants):
- **Control Panel → Terminal & SNMP → Enable SSH service** — currently ON (was OFF before)
- **Control Panel → User & Group → Advanced → Enable user home service** — currently ON. Disabling deletes the `homes` shared folder and per-user `home` folders. Steve already deleted these via DSM but the toggle may still be ON.

What was already cleaned up successfully (don't worry about these):
- ✅ open-webui + searxng containers stopped + removed
- ✅ open-webui + searxng docker images removed
- ✅ open-webui_default + searxng_default networks removed
- ✅ /volume1/docker/open-webui + /volume1/docker/searxng directories deleted
- ✅ /tmp/setup-sudo.sh removed
- ✅ /var/services/homes/steve/.ssh/authorized_keys removed (so Mac can no longer SSH passwordless)
- ✅ Mac side: ~/.ssh/id_ed25519, .pub, and known_hosts entry for 192.168.50.250 all removed
- ✅ AdGuard container untouched (it was pre-existing, still running)

**Open WebUI Save button quirk (0.9.1):** The admin Web Search Save button can return HTTP 422 because `WEB_LOADER_TIMEOUT` must be a STRING in the API even though the UI may send int. We bypass by setting via the API/DB directly with the correct types.

**Did NOT install** (worth noting because we considered): Docker Desktop (Rosetta concern, replaced by going native), SearXNG (DDG was easier and is enough for now — can revisit if results are weak).

## PENDING WORK

**Task #9 — Weekly update script** (small, ~10 min):
- Bash script that runs weekly to:
  - `ollama pull` each installed model (gets new versions of same tag)
  - `uv tool upgrade open-webui` (Open WebUI updates)
  - `uv tool upgrade mcpo`
  - `brew upgrade` for tailscale, node, uv
  - Optionally check Hugging Face for any new datasets Steve cares about
- Run via launchd weekly schedule
- Themed output (Steve's preference per CLAUDE.md)

**Client machine setup** (separate sessions):
- MacBook Pro M4 Pro — install Tailscale, optionally local Ollama fallback for travel
- Intel 14900K hackintosh — Tailscale, browser-only client to Mac Mini, optionally MCP shell server
- AMD 9950X3D hackintosh — same as Intel
- Windows machines — Tailscale, browser client, PowerShell MCP server

**MCP shell/exec server** (deferred):
- Currently only filesystem MCP is wired. A shell-execution MCP would let local model run commands. Higher risk; defer until Steve specifically wants it.

**Fine-tuning — ACTIVE (as of 2026-04-24):**
- ROCm path on RX 6950 XT (RDNA2/gfx1030) **abandoned** — bnb has no gfx1030 kernels for `kDequantizeBlockwise` or bf16 optimizer templates. Unblockable upstream gap.
- **Current path:** MLX-LM on Mac Mini M4 Pro 24GB (native Apple Silicon, no torch/ROCm/bnb needed)
- **Base model:** `mlx-community/Qwen2.5-14B-Instruct-4bit` (~8GB, downloads from HuggingFace on first run)
- **Dataset:** 19,271 train / 1,015 valid examples, `random.seed(42)` split
- **Scripts:** `finetune_mlx.py` (trains LoRA + auto-fuses), `export_to_ollama.py` (GGUF q4_k_m → `steve-qwen:14b` in Ollama)
- **Files currently at:** `~/Desktop/Training Data/` (doc says they should live at `~/Documents/Training Data/`)
- **Est. runtime:** 18–30 hours for 1 epoch — set-and-forget weekend job
- **Output:** `merged_model/` (fp16) → `steve-qwen-14b.gguf` (~8.5GB) → registered as `steve-qwen:14b` in Ollama
- **Resume safe:** kills and restarts fine — but iter counter resets to 0 (loads adapter weights from checkpoint). Adjust `ITERS` down if resuming mid-run.
- **If OOM:** reduce `NUM_LAYERS` (16→8) or `MAX_SEQ_LENGTH` (2048→1024) in `finetune_mlx.py`
- RAG / Knowledge Base in Open WebUI for personal archives — still recommended over agent-style file ops for research use

## OPERATIONAL TIPS FOR FUTURE ME

**To restart everything cleanly:**
```
launchctl unload ~/Library/LaunchAgents/com.steve.open-webui.plist
launchctl unload ~/Library/LaunchAgents/com.steve.mcpo-filesystem.plist
launchctl load ~/Library/LaunchAgents/com.steve.open-webui.plist
launchctl load ~/Library/LaunchAgents/com.steve.mcpo-filesystem.plist
```

**To get an admin JWT for Open WebUI's API** (for direct config changes that bypass the UI):
```python
/Users/steve/.local/share/uv/tools/open-webui/bin/python -c "
import jwt
secret = open('/Users/steve/.open-webui/.webui_secret_key').read().strip()
print(jwt.encode({'id': '<USER_UUID_FROM_DB>'}, secret, algorithm='HS256'))
"
```

**Steve's user UUID:** `2b2010c2-3211-40da-87f6-8a572f66aa85` (admin role).

**Settings DB:** `/Users/steve/.open-webui/data/webui.db` — SQLite. Web search etc. lives in `config` table, `data` JSON column, at path `rag.web.*` and `web.ENABLE_WEB_SEARCH` etc.

**Real env var names in Open WebUI 0.9.1** (different from older docs):
- `ENABLE_WEB_SEARCH` (NOT `ENABLE_RAG_WEB_SEARCH`)
- `BYPASS_WEB_SEARCH_EMBEDDING_AND_RETRIEVAL` (NOT `BYPASS_EMBEDDING_AND_RETRIEVAL`)
- `WEB_LOADER_TIMEOUT` is a STRING, not int

**LAN IPs:**
- Mac Mini: `192.168.50.241`
- Synology: `192.168.50.250` (AdGuard host only — no AI workloads)
- Router: `192.168.50.1`
