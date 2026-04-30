# CLAUDE.md (macOS)

Guidance for Claude Code on Steve's Macs (M4 Pro + two Hackintoshes).

## Preferences — READ FIRST
- **Bash with ble.sh** on all platforms. UX, POSIX compatible.
- Simple and effective, no over-engineering.
- Ask questions one at a time.
- Hates typing — keep commands short when possible.
- Arch Scripts output must be themed — use color variables.
- **NEVER put .sh scripts in the DRACULARCH repo** — scripts live on USB/Synology only.

## AI Tools — Current Setup

Five AI tools configured and backed up. All restored by bash.sh on fresh installs.

### Claude Code (`claude`)
- Installed via `curl -fsSL https://claude.ai/install.sh | bash`
- Config: `~/.claude/CLAUDE.md` (this file) + `~/.claude/settings.json` — both in DRACULARCH repo under `Claude/`
- Memory: `~/.claude/projects/-Users-steve/memory/` — backed up to `~/Dracularch/Claude/memory/`

### Deep (`deep` alias)
DeepSeek routed through Claude Code using DeepSeek's Anthropic-compatible API.
- Alias in `~/.bashrc`: `alias deep='source ~/.config/mg-deepseek/key.env && claude --bare --settings ~/.config/mg-deepseek/claude-deepseek-settings.json --model deepseek-v4-pro'`
- Settings file: `~/.config/mg-deepseek/claude-deepseek-settings.json` — sets `ANTHROPIC_BASE_URL=https://api.deepseek.com/anthropic`
- Key file: `~/.config/mg-deepseek/key.env` — not in repo (contains API key)
- Use for: script analysis, code review, optimization — use Privacy Relay for scripts with personal info
- Backed up to Synology: `/Volumes/External/WEB Scripts/Scripts/Jan Backup/mg-deepseek-settings.json` + `mg-deepseek-key.env`. bash.sh's `install_deepseek_config()` restores them on fresh install.
- **"save deepseek files"** = copy `~/.config/mg-deepseek/claude-deepseek-settings.json` and `key.env` to that Synology path (renamed with `mg-deepseek-` prefix).

### Qwen (`qwen` alias)
Qwen 3.6 Plus (`qwen/qwen3.6-plus`) routed through Claude Code via OpenRouter's Anthropic-compatible API.
- Alias in `~/.bashrc`: `alias qwen='claude --bare --settings ~/.config/mg-qwen/claude-qwen-settings.json'`
- Settings file: `~/.config/mg-qwen/claude-qwen-settings.json` — sets `ANTHROPIC_BASE_URL=https://openrouter.ai/api`, model `qwen/qwen3.6-plus`, fast model `qwen/qwen3.6-flash`
- API key in settings file (not separate key.env)
- **"save qwen files"** = copy `~/.config/mg-qwen/claude-qwen-settings.json` to `/Volumes/External/WEB Scripts/Scripts/Jan Backup/` (renamed `mg-qwen-settings.json`).

### Flash (`flash` alias)
Stepfun Step-3.5 Flash (`stepfun/step-3.5-flash`) routed through Claude Code via OpenRouter's Anthropic-compatible API.
- Alias in `~/.bashrc`: `alias flash='claude --bare --settings ~/.config/mg-flash/claude-flash-settings.json'`
- Settings file: `~/.config/mg-flash/claude-flash-settings.json` — sets `ANTHROPIC_BASE_URL=https://openrouter.ai/api`, model `stepfun/step-3.5-flash` for all slots
- API key in settings file (shared OpenRouter key with `qwen`)
- **"save flash files"** = copy `~/.config/mg-flash/claude-flash-settings.json` to `/Volumes/External/WEB Scripts/Scripts/Jan Backup/` (renamed `mg-flash-settings.json`).

### Jan (GUI — `jan`)
Local AI frontend with two assistants and Tavily web search.
- **DeepSeek assistant** — deepseek-v4-pro via DeepSeek API
- **Big Pickle assistant** — big-pickle via OpenCode Zen (free)
- Both have Tavily search enabled via MCP
- Backed up to Synology (see Jan Backup section below)

### OpenCode (`opencode`)
Terminal AI tool. Big Pickle removed 2026-04-30 (too slow under agent workload — works fine in Jan, sluggish in OpenCode TUI due to large per-turn payload). Now routes through OpenRouter + DeepSeek.
- Config: `~/.config/opencode/AGENTS.md` — in DRACULARCH repo under `Claude/opencode/`
- TUI config: `~/.config/opencode/tui.json` — theme `claude-mocha`, `mouse: false` (so Ghostty native selection + right-click paste work)
- Model declarations: `~/.config/opencode/opencode.json` declares `stepfun/step-3.5-flash` and `qwen/qwen3.6-plus` under `provider.openrouter.models` so they show in the picker
- Auth: `~/.local/share/opencode/auth.json` — `openrouter` (shared key with Claude Code `qwen`/`flash` aliases) + `deepseek` providers
- **Model aliases in `~/.bashrc`**:
  - `opendeep` → `opencode --model deepseek/deepseek-v4-pro`
  - `openqwen` → `opencode --model openrouter/qwen/qwen3.6-plus`
  - `openflash` → `opencode --model openrouter/stepfun/step-3.5-flash`
- **Per-model picker filtering**: NOT supported in OpenCode today (open issues sst/opencode#3411, #9203). Aliases are the workaround.
- **oh-my-opencode plugin**: DISABLED — crashes OpenCode 1.4.x, no ETA on fix
- **Custom themes**: DISABLED — crashes on load, don't add theme files to `~/.config/opencode/themes/`

### bash.sh — Key patterns in place
- `set -euo pipefail` + `request_sudo()` keepalive + `trap release_sudo EXIT`
- `download_to()` atomic helper (curl → .tmp → mv, cleans up on failure)
- Parallel downloads with `& pids+=($!)` + `wait` error checking
- Single `brew install "${packages[@]}"` call; fonts use `--cask`
- Installs and restores: Claude Code, OpenCode, Jan — all idempotent

---

## Repo + Sync Conventions

**DRACULARCH** = github.com/svan71/DRACULARCH. Local clone at `~/Dracularch/`.

**"sync" means:** copy to repo → git push → copy to USB.

**Files kept in sync** (live ↔ repo ↔ USB):
- `CLAUDE.md` — Arch (`Claude/CLAUDE.md`) + macOS (`Claude/macOS/CLAUDE.md`) + Windows (Synology only)
- `AGENTS.md` — OpenCode global (`Claude/opencode/AGENTS.md`)
- `settings.json` — unified across all OSes (`Claude/settings.json`)
- `bashrc` — macOS (`macOS/Bash/bashrc`)

**USB label format:** `ARCH_YYYYMM` (changes monthly). macOS path: `/Volumes/ARCH_YYYYMM/`.

**Synology (macOS):** `/Volumes/external/WEB Scripts/Scripts/`.

## Hardware
- Intel 14900K, 32GB, Samsung Odyssey G8 4K@240Hz (Hackintosh + Windows + Arch)
- AMD 7950X3D, 64GB (Hackintosh + Arch)
- Mac mini M4 Pro, 24GB

## Arch work from Mac
For any Arch / Dracula.sh / Mokka.sh / macOS.sh / Linux-specific guidance, read `~/Dracularch/Claude/CLAUDE.md`. Do not duplicate that content here.

---

## macOS

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

### OpenCode Backup

OpenCode config backed up to:
- `~/.config/opencode/AGENTS.md` → DRACULARCH repo: `Claude/opencode/AGENTS.md`
- `~/.local/share/opencode/auth.json` → Synology: `/Volumes/External/WEB Scripts/Scripts/Jan Backup/opencode_auth.json`
- `~/.config/opencode/tui.json` → Synology: `.../Jan Backup/opencode_tui.json` (theme + mouse setting)
- `~/.config/opencode/opencode.json` → Synology: `.../Jan Backup/opencode_config.json` (model declarations)

**"save opencode files"** = copy auth.json, tui.json, opencode.json to Synology + push AGENTS.md via repo.

### Jan Backup

Jan config is backed up to Synology at `/Volumes/External/WEB Scripts/Scripts/Jan Backup/`:
- `assistant.json` — DeepSeek assistant config + system prompt
- `mcp_config.json` — MCP servers + Tavily API key
- `localstorage.sqlite3` — Jan engine settings + DeepSeek API key

**"save jan files" / "update jan backup"** = copy all three files from their live locations to that Synology path:
- `~/Library/Application Support/jan/data/assistants/deepseek/assistant.json`
- `~/Library/Application Support/jan/data/mcp_config.json`
- `~/Library/WebKit/jan.ai.app/WebsiteData/Default/cVX73oUEz5Ky30V8E-8XF4dbF5fwsr3ebL34bPtfrrQ/cVX73oUEz5Ky30V8E-8XF4dbF5fwsr3ebL34bPtfrrQ/LocalStorage/localstorage.sqlite3`

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

### Ghostty + ble.sh double-prompt (ACTIVE BUG)
Started with Ghostty 1.3.1. Confirmed on macOS + CachyOS. Upstream: [ble.sh issue #684](https://github.com/akinomyoga/ble.sh/issues/684). All local workarounds tried and failed. **Do not attempt new ones.** When fix lands: `cd ~/.local/share/blesh && git pull && make` → restart shell.

