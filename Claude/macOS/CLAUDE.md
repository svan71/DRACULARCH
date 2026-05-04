# CLAUDE.md (macOS)

Guidance for Claude Code on Steve's Macs (M4 Pro + two Hackintoshes).

## Preferences — READ FIRST
- **Bash with ble.sh** on all platforms. UX, POSIX compatible.
- Simple and effective, no over-engineering.
- Ask questions one at a time.
- Hates typing — keep commands short when possible.
- Arch Scripts output must be themed — use color variables.
- **NEVER put .sh scripts in the DRACULARCH repo** — scripts live on USB/Synology only.
- **Verify before "improving"** — before suggesting a change that depends on a file path, tool, or flag existing, confirm it (`ls`, `which`, `--help`). Don't apply a textbook "better" pattern without checking the actual artifact matches the assumption. A 2-second check beats a wasted edit + revert.

## AI Tools — Current Setup

Three tools active. All restored by bash.sh on fresh installs.

### Claude Code (`claude`)
- Installed via `curl -fsSL https://claude.ai/install.sh | bash`
- Config: `~/.claude/CLAUDE.md` (this file) + `~/.claude/settings.json` — both in DRACULARCH repo under `Claude/`
- Memory: `~/.claude/projects/-Users-steve/memory/` — backed up to Synology `Scripts/Claude/memory/`

### Deep (`deep` alias)
DeepSeek routed through Claude Code using DeepSeek's Anthropic-compatible API. Same Claude Code harness, full tool access — deep behaves as an autonomous agent thanks to the coaching system prompt.
- Alias in `~/.bashrc`: `alias deep='source ~/.config/mg-deepseek/key.env && claude --bare --settings ~/.config/mg-deepseek/claude-deepseek-settings.json --model deepseek-v4-pro --append-system-prompt-file ~/.config/mg-deepseek/coaching.md'`
- Settings file: `~/.config/mg-deepseek/claude-deepseek-settings.json` — sets `ANTHROPIC_BASE_URL=https://api.deepseek.com/anthropic`
- Key file: `~/.config/mg-deepseek/key.env` — not in repo (contains API key)
- Coaching file: `~/.config/mg-deepseek/coaching.md` — system-prompt coaching that makes deep act autonomous, terse, BSD-aware, output-disciplined. Edit when behavior needs adjusting.
- Use for: script analysis, code review, optimization — use Privacy Relay for scripts with personal info
- Backed up to Synology: `Scripts/Notes/mg-deepseek-settings.json` + `mg-deepseek-key.env` + `mg-deepseek-coaching.md`. bash.sh's `install_deepseek_config()` restores all three on fresh install.
- **"save deepseek files"** = copy `~/.config/mg-deepseek/claude-deepseek-settings.json`, `key.env`, and `coaching.md` to `Scripts/Notes/` (renamed with `mg-deepseek-` prefix).

### Cherry Studio (`cherry`)
Local AI GUI. Replaced Jan on 2026-05-01.
- Backed up to Synology `Scripts/Notes/`: `cherry-config.json`, `cherry-agents.db`, `cherry-preferences`
- **"save cherry files"** = copy those three files from `~/Library/Application Support/CherryStudio/` to `Scripts/Notes/`

### Codex (`Codex.app` desktop)
OpenAI's coding agent desktop app. Installed via `brew install --cask codex-app`.
- Config dir: `~/.codex/` — `AGENTS.md` (prompt customization, equivalent to CLAUDE.md), `config.toml`, `auth.json` (OAuth tokens — private), `memories/`, `rules/default.rules` (allowlist)
- Backed up to Synology `Scripts/Notes/codex/`: `AGENTS.md`, `config.toml`, `auth.json`, `memories/*.md`, `rules/default.rules`. **Auto-mirrored on every Claude session-stop via the Stop hook in `settings.json`** — no manual action needed for the backup itself. bash.sh's `install_codex_config()` restores them on fresh install. Ephemeral state (sqlite logs, plugin caches, sessions) is NOT backed up.
- **"save codex files"** = copy `AGENTS.md`, `config.toml`, `auth.json`, `memories/`, `rules/default.rules` from `~/.codex/` to `Scripts/Notes/codex/`. Run after editing AGENTS.md, allow rules, or tweaking config.

### "save files" / "save all" — full backup sweep
Run all three save-X commands AND mirror Claude memory in one shot:
1. `save deepseek files` — `~/.config/mg-deepseek/{settings,key,coaching}` → `Scripts/Notes/mg-deepseek-*`
2. `save cherry files` — `~/Library/Application Support/CherryStudio/{config,agents.db,preferences}` → `Scripts/Notes/cherry-*`
3. `save codex files` — `~/.codex/{AGENTS.md,config.toml,auth.json,memories/,rules/default.rules}` → `Scripts/Notes/codex/`
4. Mirror Claude memory: `rsync -a --delete ~/.claude/projects/-Users-steve/memory/ /Volumes/external/WEB\ Scripts/Scripts/Claude/memory/`

(Claude's own `~/.claude/CLAUDE.md` and `settings.json` are auto-mirrored on every Claude session-stop via the Stop hook in `settings.json`. The Codex files in step 3 are also auto-mirrored by the same hook — manual `save codex files` is still useful for an immediate push. The repo copies of CLAUDE.md / bashrc / settings.json need a manual `git push` separately — call them out if dirty during a save sweep.)

### Cross-tool sync with Codex
Codex (`~/.codex/AGENTS.md`) is Steve's other AI coding tool. The two configs share invariants (preferences, hardware, repos, AI stack) but each has tool-specific sections (Codex has Steve-debate tone + Search rules + allow rules; Claude has Skill cheat sheet + plugin details).

- **"update codex"** = open `~/.codex/AGENTS.md` and add/update sections to reflect work just done in this Claude session that's relevant to Codex (new tools installed, new aliases, new conventions, project state changes). Don't duplicate Claude-specific content. Keep Codex-specific sections intact. After editing, also run "save codex files" to mirror to Synology.
- **"update from codex"** = read `~/.codex/AGENTS.md`, look for things not yet in CLAUDE.md, ask before merging.
- For ad-hoc context: read `~/.codex/AGENTS.md` anytime to see what Steve has told Codex about a topic.
- Symmetric: when Steve is in Codex, the equivalent phrase **"update claude"** tells Codex to edit CLAUDE.md the same way.

**Audit trail (REQUIRED on every sync update):** at the bottom of the file you just edited, append a one-line entry to the `## Cross-tool sync log` section in this format:
`- YYYY-MM-DD (from claude|codex): <one-line summary of what was added/changed>`
This way each file's tail shows the timeline of cross-tool updates and which tool authored each change. Update the log in the **file you edited**, not the file you're running in.

### bash.sh — Key patterns in place
- `set -euo pipefail` + `request_sudo()` keepalive + `trap release_sudo EXIT`
- `download_to()` atomic helper (curl → .tmp → mv, cleans up on failure)
- Parallel downloads with `& pids+=($!)` + `wait` error checking
- Single `brew install "${packages[@]}"` call; fonts use `--cask`
- Installs and restores: Claude Code, DeepSeek config, Groq key — all idempotent
- Public Claude configs can restore from mounted `ARCH_*` USB by label, falling back to DRACULARCH raw GitHub
- Claude memory restores from Synology `Scripts/Claude/memory/`, never from DRACULARCH

---

## Repo + Sync Conventions

**DRACULARCH** = github.com/svan71/DRACULARCH. Local clone at `~/Dracularch/`. **PUBLIC repo — no keys, no private data, no memory files ever.**

**"sync" means:** copy to repo → git push. **USB is NOT part of `sync`.** USB is a static reference snapshot that's only refreshed on explicit **"update USB"** command (see below).

**Files kept in sync** (live ↔ repo) — non-sensitive only:
- `CLAUDE.md` — Arch (`Claude/CLAUDE.md`) + macOS (`Claude/macOS/CLAUDE.md`) + Windows (Synology only)
- `settings.json` — unified across all OSes (`Claude/settings.json`) — no keys embedded
- `bashrc` — macOS (`macOS/Bash/bashrc`)
- `bash_profile` — macOS (`macOS/Bash/bash_profile`)
- `.gitignore` — blocks secrets, auth, Claude memory, histories, zoxide DBs, and KDE activity DBs from re-entering the public repo

**"update USB"** = refresh the static reference copy on USB (`/Volumes/ARCH_YYYYMM/Claude/`). Only the 4 public config files Steve cares about as a record:
- `CLAUDE.md` → `/Volumes/ARCH_*/Claude/macOS/CLAUDE.md`
- Claude `settings.json` → `/Volumes/ARCH_*/Claude/settings.json`
- Codex `AGENTS.md` → `/Volumes/ARCH_*/Claude/codex/AGENTS.md`
- Codex `config.toml` → `/Volumes/ARCH_*/Claude/codex/config.toml`

After copying, run `dot_clean /Volumes/ARCH_*/Claude` to strip macOS metadata files. **Never put auth/keys/cherry/deepseek/codex-auth on USB** — those stay Synology-only.

Installers should discover USB by label, not a fixed mount path. On macOS, use the first matching `/Volumes/ARCH_*`; on Linux scripts also check `/run/media/$USER/ARCH_*`, `/media/$USER/ARCH_*`, and `/mnt/ARCH_*`. The monthly label is stable even when the actual device/path changes.

`bash.sh` uses USB only as an optional public Claude config source and restores Claude memory from Synology `Scripts/Claude/memory/`, never DRACULARCH.

`Dracula.sh`, `Mokka.sh`, and `macOS.sh` now use `SCRIPT_DIR`/`find_private_restore_dir()` for private convenience restores. They restore shell histories, zoxide `db.zo`, and Mokka KDE activity data from the script/USB/Synology private snapshot when present, and skip cleanly when absent. They no longer pull those local-state files from GitHub.

**Everything private → Synology only** (never repo, never USB):
- All API keys and `.env` files
- `settings.local.json` (MCP permissions)
- Claude memory files (`Claude/memory/*.md`)
- Cherry config and agents.db
- Ghostty config
- Any file containing personal info, IPs, credentials

**Low-risk convenience snapshots → USB/Synology only** (never repo): shell histories, zoxide `db.zo`, KDE activity database/logs.

**USB label format:** `ARCH_YYYYMM` (changes monthly). macOS path: `/Volumes/ARCH_YYYYMM/`.

**Synology (macOS):** `/Volumes/External/WEB Scripts/Scripts/`.
- Private backup: `Scripts/Notes/` (keys, settings.local.json, Cherry, Ghostty, DeepSeek, Alpaca, Codex, plists)
- Memory backup: `Scripts/Claude/memory/`

## Hardware
- Intel 14900K, 32GB, Samsung Odyssey G8 4K@240Hz (Hackintosh + Windows + Arch)
- AMD 7950X3D, 64GB (Hackintosh + Arch)
- Mac mini M4 Pro, 24GB

## Arch work from Mac
For any Arch / Dracula.sh / Mokka.sh / macOS.sh / Linux-specific guidance, read `~/Dracularch/Claude/CLAUDE.md`. Do not duplicate that content here.

---

## macOS

### sudo / admin commands — always prompt Steve, never punt
Claude Code can't read a sudo password from a TTY, but Steve doesn't want admin tasks bounced back as "run this yourself." When a command needs root, wrap it in osascript so macOS pops a GUI auth dialog Steve can fill in, then continue the work in-session:

```
osascript -e 'do shell script "<absolute-path command>" with administrator privileges'
```

Use absolute paths (e.g. `/usr/sbin/diskutil`, `/bin/cp`) since GUI-spawned shells have a minimal PATH. If a `sudo …` Bash call returns "a terminal is required to read the password", retry once via osascript instead of asking Steve to run it. Steve fills the prompt, Claude does the thing.

### bash.sh (installer)
Lives on USB/Synology, NEVER in repo. Idempotent — safe to re-run. Read the script directly when working on it; don't rely on remembered behavior.

### Power Management (M4 Pro — prevent unwanted wakes)
```bash
sudo pmset -a powernap 0        # biggest offender (mDNSResponder, dasd, NotificationCenter)
sudo pmset -a womp 0            # Wake on LAN
sudo pmset -a proximitywake 0   # iPhone/Watch proximity
sudo pmset -a tcpkeepalive 0    # apps holding connections (breaks Find My during sleep)
sudo pmset schedule cancelall   # Calendar/Focus/Analytics wakes
```

### SMB optimization
`/etc/nsmb.conf`: `signing_required=no`, `validate_neg_off=yes`, `smb_read/write=4194304`, `mc_on=yes`, `mc_prefer_wired=yes`, `dir_cache_max_cnt=0`. Result: ~285 MB/s to Synology.

### Firefox userChrome (macOS)
Enable via `toolkit.legacyUserProfileCustomizations.stylesheets = true` in `user.js` (Betterfox v144 base). Colors/spacing live in the CSS file itself — read it.

### createinstallmedia EFI bug (Tahoe+)
Sometimes creates USB with EFI partition present in GPT but not formatted FAT32 → `diskutil mount` silently fails. Fixes:
- Post-fix: `sudo newfs_msdos -F 32 -v EFI /dev/diskNs1` then mount
- Pre-fix: erase USB fully as GPT/JHFS+ before running createinstallmedia

---

## Hackintosh

Two machines, both running **Official Acidanthera OpenCore 1.0.7**, SMBIOS `MacPro7,1`, macOS Tahoe 26.x.

### Shared gotchas (both)
- **NO_ACPI variant is NOT required.** All SSDTs use `_OSI("Darwin")` wrapping + config uses only standard schema keys. Official OC validates clean.
- **OCAT warning**: may strip unrecognized keys from newer OC. Use ProperTree or a text editor for config edits.
- **PickerVariant uses forward slash**: `BlackOSX/BsxM1` (NOT backslash).
- **Theme requires populated `Resources/Font/` and `Resources/Label/`** — missing files = silent theme fail.
- **ocvalidate** before installing: `~/Desktop/OpenCore_OFFICIAL_107/Utilities/ocvalidate/ocvalidate /Volumes/EFI/EFI/OC/config.plist`
- **Clean EFI metadata before zipping/copying**: `dot_clean /Volumes/EFI/EFI`

### Intel (14900K, Z790 Aorus Master, RX 6950 XT)
- Ethernet: **LucyRTL8125Ethernet** for RTL8125B.
- CPUID spoof: Raptor Lake → Comet Lake (required for macOS P-state tables).
- iGPU disabled via DeviceProperties (`disable-gpu` on PciRoot(0x0)/Pci(0x2,0x0)).
- Boot args: `npci=0x2000`.
- `UEFI:Output:Resolution` = `Max`, `UIScale` = `0` (auto). Works; don't "fix" based on stale notes.
- Performance verified: XCPM active, 5.5GHz all-core, 6.2GHz single. Don't tweak CPUFriend — already hits BIOS ceiling.

### AMD (7950X3D, RX 6600)
- AMD-specific kexts: `AMDRyzenCPUPowerManagement`, `AppleMCEReporterDisabler`, `AMFIPass`.
- 16 AMD Vanilla kernel patches (CaseySJ IOPCIFamily AM5, Algrey/Zormeister PAT fix 15.0+). `MaxKernel: 25.99.99`.
- Ethernet: `AppleIntelI210Ethernet` 2.3.1 for Intel I225-V.
- Resizable BAR enabled but GPU reports 256MB (BIOS or NootRX limitation).
- SSDT-ANS has 4 NVMe entries incl. Predator GM7000 on RP09 (spoofed Samsung `pci144d,a806`).

### EFI update workflow
1. Download from github.com/acidanthera/OpenCorePkg/releases
2. Start with new `Docs/Sample.plist`, rename to `config.plist`, migrate settings
3. Replace: `BOOTx64.efi`, `OpenCore.efi`, `Drivers/*.efi`
4. Keep: `ACPI/*.aml`, `Kexts/`, `Resources/`
5. Validate with `ocvalidate`, backup old EFI before replacing

### Useful commands
```bash
sudo diskutil mount disk0s1          # mount EFI
system_profiler SPDisplaysDataType   # check GPU
system_profiler SPEthernetDataType   # check Ethernet
```

---

## Cross-Platform

### Cherry Backup

Cherry config backed up to Synology at `Scripts/Notes/`:
- `cherry-config.json` — main app config
- `cherry-agents.db` — assistants, API keys, MCP configs
- `cherry-preferences` — app preferences

**"save cherry files"** = copy those three files from `~/Library/Application Support/CherryStudio/` to `Scripts/Notes/`.

---

### Codex Backup

Codex config backed up to Synology at `Scripts/Notes/codex/`:
- `AGENTS.md` — prompt customization (Codex equivalent of CLAUDE.md)
- `config.toml` — settings (model, plugins, project trust list)
- `auth.json` — OAuth tokens (private)
- `memories/*.md` — accumulated session memories
- `rules/default.rules` — bash allowlist (avoids re-allowing every command)

**"save codex files"** = copy `AGENTS.md`, `config.toml`, `auth.json`, `memories/`, `rules/default.rules` from `~/.codex/` to `Scripts/Notes/codex/`. Auto-runs on every Claude session-stop via the Stop hook — manual command is still useful for an immediate push without ending the session.

bash.sh's `install_codex_config()` restores all of this + installs the app via `brew install --cask codex-app`.

---

### Privacy Relay (Deep workflow)

Use when working on scripts with personal info before handing off to `deep`.

1. You copy the file to a working location and say **"sanitize for deep: /path/to/copy"**
2. Claude reads the copy, builds a substitution map, edits the copy in place (real → placeholder)
3. You open the copy in Deep and do the work
4. When done, say **"restore from deep"** — Claude edits the copy back (placeholder → real)

Common personal info to catch: IPs, hostnames, usernames, email, SSH key paths, Synology share paths, paths containing real names.

Use realistic-looking dummy values — not obvious placeholders like FAKE_USER. Examples: `johndoe`, `john@example.com`, `192.168.1.50`, `/Volumes/nas/backup`. Keep the map so restore is exact.

---

### Ghostty + ble.sh double-prompt (RESOLVED via tip build)
Fix merged in Ghostty PR #11644, not yet in stable. Running `ghostty@tip` (1.3.2-main-+4dcb09ada) since 2026-05-02.
- Installed via: `brew uninstall --cask ghostty && brew install --cask ghostty@tip`
- Fix is in `/Applications/Ghostty.app/Contents/Resources/ghostty/shell-integration/bash/ghostty.bash` — checks `BLE_VERSION`, emits `OSC 133;P` instead of `OSC 133;A`.
- When stable 1.3.2 releases: `brew uninstall --cask ghostty@tip && brew install --cask ghostty`

---

## Advisor pattern — Opus brain, Sonnet hands
Main session is pinned to Opus (`"model": "opus"` in settings.json). When spawning subagents via the Agent tool, **default to `model: "sonnet"`** — Opus stays in the main thread doing the thinking; Sonnet does the legwork (Explore, general-purpose, Plan, code-reviewer, code-simplifier, etc.). Only escalate a subagent to Opus if the task itself needs deep judgment in isolation (e.g. an independent design review). Haiku is rarely needed — skip it unless the task is high-volume mechanical work where latency/cost dominate.

## Skill reach-for cheat sheet

Plugins are installed for a reason. Match generously — if a task even loosely fits one of these, invoke the skill BEFORE doing the work. Skills are cheap; missing them is the failure mode.

**Process / methodology (superpowers plugin):**
- "let's build / add / design X", new feature, open-ended creative ask → `superpowers:brainstorming` (first, before writing any code)
- Implementing a feature or non-trivial fix → `superpowers:test-driven-development`
- Bug, test failure, "this isn't working", unexpected behavior → `superpowers:systematic-debugging`
- Spec or multi-step task → `superpowers:writing-plans`, then `superpowers:executing-plans`
- 2+ independent tasks → `superpowers:dispatching-parallel-agents`
- Need isolated workspace → `superpowers:using-git-worktrees`
- About to claim "done" / "fixed" / "passing" → `superpowers:verification-before-completion`
- Received code review feedback → `superpowers:receiving-code-review`
- Want this work reviewed → `superpowers:requesting-code-review`
- Implementation complete, deciding how to integrate → `superpowers:finishing-a-development-branch`

**Code quality:**
- Big change, want a reuse/quality pass → `/simplify`
- Review pending changes → `/review`
- Security-sensitive changes → `/security-review`

**CLAUDE.md / config / settings:**
- Audit any CLAUDE.md file → `claude-md-management:claude-md-improver`
- Update CLAUDE.md with session learnings → `claude-md-management:revise-claude-md`
- Add a hook, env var, permission, automation ("from now on...", "whenever X") → `update-config`
- Customize keybindings → `keybindings-help`
- Cut down permission prompts → `fewer-permission-prompts`

**Recurring / scheduled:**
- "Run this every X", "poll until Y", routine reports → `loop` (interactive) or `schedule` (cloud agent)

**Hugging Face / ML** (only when actually relevant):
- "What's the best model for X", model recommendations → `huggingface-skills:huggingface-best`
- Local LLM via GGUF / llama.cpp → `huggingface-skills:huggingface-local-models`
- Train / fine-tune via HF Jobs (LLM) → `huggingface-skills:huggingface-llm-trainer`
- Train / fine-tune vision (DETR, SAM, ViT, etc.) → `huggingface-skills:huggingface-vision-trainer`
- Track training experiments → `huggingface-skills:huggingface-trackio`
- HF Hub CLI ops (download/upload/repo/jobs) → `huggingface-skills:hf-cli`
- AI/ML paper lookup or analysis → `huggingface-skills:huggingface-papers`
- Build a Gradio UI → `huggingface-skills:huggingface-gradio`
- ML in JS/TS (browser/Node) → `huggingface-skills:transformers-js`
- Datasets API workflows → `huggingface-skills:huggingface-datasets`

**Claude API / Anthropic SDK code:**
- Code importing `anthropic` SDK, prompt caching tuning, model version migration → `claude-api`

**Default rule:** if a skill might apply, invoke it. The skill content tells you whether it actually fits — far better than skipping it and guessing.

---

## Cross-tool sync log
Append one line per `update claude` / `update codex` run. Format: `- YYYY-MM-DD (from claude|codex): <summary>`. Newest at the bottom.

- 2026-05-02 (from claude): initial cross-tool sync setup — added "save files" sweep, "update codex"/"update claude" phrases, this audit-trail log
- 2026-05-02 (from claude): redefined "sync" to exclude USB; added "update USB" workflow phrase (refreshes 4 public files: CLAUDE.md, claude settings.json, AGENTS.md, codex config.toml — never auth/keys)
- 2026-05-02 (from claude): SESSION CHECKPOINT — Mac Mini AI server decommissioned (ollama removed, mlx/mlx-c autoremoved); bash.sh now installs codex-app cask + restores codex configs; deep coaching.md baked into the alias for autonomous behavior; memory pruned (13 stale deleted, 4 evergreens indexed); full vocabulary live: sync / update USB / save files / save {deepseek,cherry,codex} files / update {claude,codex} / update from {claude,codex}
- 2026-05-03 (from claude): added "sudo / admin commands" rule under macOS — when a Bash sudo errors with "terminal is required", wrap the command in `osascript -e 'do shell script "..." with administrator privileges'` to throw Steve a GUI password prompt and continue in-session. Mirrored to Codex AGENTS.md.
- 2026-05-04 (from claude): extended Claude Stop hook in `~/.claude/settings.json` to also auto-mirror Codex files (`~/.codex/{AGENTS.md,config.toml,auth.json,memories/,rules/default.rules}` → `Scripts/Notes/codex/`); memories use `rsync -a --exclude=.git` to skip Codex's internal git tracking. Manual `save codex files` still works for immediate pushes; updated CLAUDE.md notes accordingly.

@RTK.md
- 2026-05-04 (from codex): cleaned DRACULARCH tracking for local state (histories, zoxide DBs, KDE activity DBs), added privacy .gitignore, updated Synology bash.sh to find ARCH_* USB by label for public Claude configs and restore Claude memory from Synology only.
- 2026-05-04 (from codex): updated Dracula.sh, Mokka.sh, and macOS.sh on USB/Synology so private convenience restores (Claude memory when locally present, shell histories, zoxide DBs, Mokka KDE activity data) use local private snapshots or skip cleanly instead of pulling removed local state from DRACULARCH.
