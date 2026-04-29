# AGENTS.md (macOS — OpenCode)

Guidance for OpenCode on Steve's Macs (M4 Pro + two Hackintoshes).

## Preferences — READ FIRST
- **Bash with ble.sh** on all platforms. POSIX compatible.
- Simple and effective, no over-engineering.
- Ask questions one at a time.
- Hates typing — keep commands short, keep responses tight.
- Script output must be themed — use color variables.
- **NEVER put .sh scripts in the DRACULARCH repo** — scripts live on USB/Synology only.
- No unnecessary bullets and headers for simple answers. Match energy.

## Hardware
- Intel 14900K, 32GB, Samsung Odyssey G8 4K@240Hz (Hackintosh + Windows + Arch)
- AMD 9950X3D, 64GB (Hackintosh + Arch)
- Mac M4 Pro, 24GB

## Repo + Sync Conventions

**DRACULARCH** = github.com/svan71/DRACULARCH. Local clone at `~/Dracularch/`.

**"sync" means:** copy to repo → git push → copy to USB.

**USB label format:** `ARCH_YYYYMM` (changes monthly). macOS path: `/Volumes/ARCH_YYYYMM/`.

**Synology (macOS):** `/Volumes/external/WEB Scripts/Scripts/`.

---

## macOS Scripts

### bash.sh (macOS installer)
Lives on USB/Synology, NEVER in repo. Idempotent — safe to re-run.

Key patterns used in this script:
- `set -euo pipefail` — fail fast
- `request_sudo()` keepalive + `trap release_sudo EXIT`
- `download_to()` atomic helper: `curl -fsSL "$url" -o "$tmp" && mv "$tmp" "$dest" || { rm -f "$tmp"; return 1; }`
- Parallel downloads: `download_to ... & pids+=($!)` + `wait` loop with error checking
- Single `brew install "${packages[@]}"` call — not one package per line
- Fonts installed with `--cask` flag: e.g. `brew install --cask font-jetbrains-mono-nerd-font`
- Always verify with `brew info <formula>` before assuming tap/formula vs cask

### Arch Scripts (Dracula.sh / Mokka.sh)
Live in `~/Dracularch/` (repo) and USB. These target Arch Linux.

**Optimization patterns already applied to Mokka.sh (KDE/Catppuccin):**
- Package list cache: `~/.local/share/mokka/installed_packages` — skip pacman if cache present
- AUR packages batched: `yay -S "${aur_pkgs[@]}" --noconfirm` — one call, not a loop
- Theme file copies parallelized: `cp ... & cp ... & wait`

**When analyzing Dracula.sh (GNOME/Dracula) or any other Arch script:**
- Read the entire script before suggesting changes
- Look for: redundant package checks, sequential installs that can batch, repeated loops over static lists, missing idempotency guards, hardcoded paths that should be variables
- Do NOT assume optimizations are safe — verify each one doesn't break intentional ordering or dependencies
- Flag anything that looks like it was there for a reason even if it looks redundant
- Prefer `pacman -Qq <pkg>` for installed checks, `command -v` for binary checks

---

## Privacy Relay Workflow

Use when Steve pastes a script with personal info.

Steve will say **"sanitize this"** or **"this has personal info"** — when that happens:
1. Identify all personal values: IPs, hostnames, usernames, email, SSH paths, Synology paths, real names in paths
2. Build a substitution map (real → dummy)
3. Use realistic-looking dummies — NOT obvious placeholders like `FAKE_USER`. Examples: `johndoe`, `john@example.com`, `192.168.1.50`, `/Volumes/nas/backup`
4. Return the sanitized version
5. Keep the map so you can restore on request ("restore" or "put it back")

---

## Jan Config (context)

Jan is Steve's local AI frontend. Config lives at:
- `~/Library/Application Support/jan/data/assistants/` — assistant definitions
- `~/Library/Application Support/jan/data/mcp_config.json` — MCP + Tavily key
- `~/Library/WebKit/jan.ai.app/...LocalStorage/localstorage.sqlite3` — engine settings (SQLite, UTF-16LE)

Backup location: `/Volumes/External/WEB Scripts/Scripts/Jan Backup/`

Assistants configured: **DeepSeek** (deepseek-v4-pro via DeepSeek API) and **Big Pickle** (big-pickle via OpenCode Zen).

---

## Hackintosh

Two machines, both running **Official Acidanthera OpenCore 1.0.7**, SMBIOS `MacPro7,1`, macOS Tahoe 26.x.

### Shared gotchas
- NO_ACPI variant is NOT required. SSDTs use `_OSI("Darwin")` wrapping.
- OCAT may strip unrecognized keys — use ProperTree or text editor for config edits.
- PickerVariant uses forward slash: `BlackOSX/BsxM1` (NOT backslash).
- Theme requires populated `Resources/Font/` and `Resources/Label/`.
- Run `ocvalidate` before installing. Clean EFI metadata: `dot_clean /Volumes/EFI/EFI`.

### Intel (14900K, Z790 Aorus Master, RX 6950 XT)
- Ethernet: LucyRTL8125Ethernet for RTL8125B
- CPUID spoof: Raptor Lake → Comet Lake
- iGPU disabled via DeviceProperties
- Boot args: `npci=0x2000`

### AMD (9950X3D, RX 6600)
- Kexts: AMDRyzenCPUPowerManagement, AppleMCEReporterDisabler, AMFIPass
- 16 AMD Vanilla kernel patches. `MaxKernel: 25.99.99`
- Ethernet: AppleIntelI210Ethernet 2.3.1 for Intel I225-V

---

## Active Bugs (do not attempt workarounds)

### Ghostty + ble.sh double-prompt
Upstream bug: ble.sh issue #684. All local workarounds exhausted — do not suggest new ones.
Fix when landed: `cd ~/.local/share/blesh && git pull && make` → restart shell.

### oh-my-opencode (OpenCode plugin)
Crashes OpenCode 1.4.x with "ralph loop unknown error". Removed. No ETA on fix.
Do not suggest re-enabling or workarounds.
