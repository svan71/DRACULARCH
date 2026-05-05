# CLAUDE.md

Guidance for Claude Code working with DRACULARCH repository.

## Steve's Preferences - READ FIRST
- **Bash with ble.sh** - Fish-like UX, POSIX compatible
- Simple and effective, no over-engineering
- Ask questions one at a time
- Hates typing - keep commands short
- Script output must be themed - use color variables
- **NEVER put .sh scripts in the repo** - scripts live on USB/Synology only
- **Verify before "improving"** - before suggesting a change that depends on a file path, tool, or flag existing, confirm it (`ls`, `which`, `--help`). Don't apply a textbook "better" pattern without checking the actual artifact matches the assumption. A 2-second check beats a wasted edit + revert.

## Repository Overview

**DRACULARCH** - Automated Arch Linux setup scripts with desktop theming.

| Script | Desktop | Theme | Shell |
|--------|---------|-------|-------|
| Dracula.sh | GNOME | Dracula | Bash + ble.sh |
| Mokka.sh | KDE Plasma 6 | Catppuccin Mocha | Bash + ble.sh |

**GitHub:** github.com/svan71/DRACULARCH
**Local repo:** ~/Dracularch/
**USB:** `ARCH_YYYYMM` (label changes monthly, e.g., ARCH_202601)
- Linux: `/run/media/steve/ARCH_YYYYMM/`
- macOS: `/Volumes/ARCH_YYYYMM/`

## Repo Structure
```
DRACULARCH/
├── Claude/           # CLAUDE.md + settings.json only; memory stays private on Synology
├── Shared/           # Cachyos-Kernel.tar.xz, Cachyos-Headers.tar.xz
├── Dracula/
│   ├── configs/      # bashrc, blerc, zoxide
│   ├── themes/       # GTK themes
│   ├── icons/        # Icon themes
│   ├── wallpapers/
│   └── assets/       # 10 tar.xz archives downloaded by script
├── Mokka/
│   ├── configs/      # plasma, terminal, gtk, sddm, samba
│   ├── themes/       # Kvantum, color-schemes, sddm, kate
│   ├── icons/        # FireDragon icons
│   └── wallpapers/
├── macOS/
│   └── Bash/         # macOS terminal configs (bashrc, ghostty, fastfetch, etc.)
└── Archive/          # Deprecated Fish configs
```

**Dracula/assets/ contents:**
- Dracula-GTK.tar.xz, Dracula-Cursors.tar.xz, Dracula-Icons.tar.xz
- Dracula-Wallpaper.tar.xz, Dracula-Plymouth.tar.xz
- Dracula-Gedit.tar.xz, Dracula-GnomeTerminal.tar.xz
- Extensions.tar.xz, Nautilus-TypeAhead.tar.xz, TomboyNotes.tar.xz

## File Locations & Sync

| Location | Purpose |
|----------|---------|
| `~/CLAUDE.md` | Active instructions (live) |
| `~/.claude/settings.json` | Permissions (live) |
| `~/Dracularch/Claude/` | Repo copy → git push |
| `/run/media/steve/ARCH_YYYYMM/` (Linux) | USB (scripts + configs) |
| `/Volumes/ARCH_YYYYMM/` (macOS) | USB (scripts + configs) |
| `/mnt/synology/WEB Scripts/Arch/Claude/USB Files/` | Synology (previous backups) |

**"sync" means:** Copy public files to repo → git push. USB is a separate explicit snapshot/update step, not part of normal sync.

## CLAUDE.md / settings.json — Symlinked to Repo

To keep all machines in sync without manual copying, the live Claude config files are **symlinks into the cloned DRACULARCH repo**:

- `~/CLAUDE.md` → `~/Dracularch/Claude/CLAUDE.md`
- `~/.claude/CLAUDE.md` → `~/Dracularch/Claude/CLAUDE.md`
- `~/.claude/settings.json` → `~/Dracularch/Claude/settings.json`

(macOS uses `~/Dracularch/Claude/macOS/CLAUDE.md` as the symlink target instead — Linux MD and macOS MD are different files in the repo.)

**Trigger phrase: "pull the latest" or "pull the latest md"** — Claude runs `cd ~/Dracularch && git pull`. Symlinks make the new content live instantly. No copy step needed.

**First-time setup on a fresh machine** (Mokka, new macOS install, etc.): trigger phrase **"set up CLAUDE.md symlinks"** — Claude clones/pulls the repo if needed, removes the standalone `~/CLAUDE.md`, `~/.claude/CLAUDE.md`, `~/.claude/settings.json`, and replaces each with a symlink per the table above. Use the macOS repo path on macOS.

The existing Stop hook continues to push backups to USB/Synology because `cp` follows symlinks (it copies the target's contents). No hook changes required.

## Public Repo Privacy Rules

DRACULARCH is public. It must never track keys, auth files, `.env`, Claude memory, shell histories, zoxide DBs, KDE activity databases/logs, or other local state dumps. Those restore conveniences belong on Synology/USB private backup locations, not GitHub.

As of 2026-05-04, `.gitignore` blocks the common leak paths, and these files were removed from tracking while left on local disk for convenience:
- `*history*`
- `db.zo`
- `Mokka/configs/activities/kactivitymanagerd/resources/`
- `Claude/memory/`

Fresh installs should restore private material from Synology/USB, not the public repo. As of 2026-05-04, `Dracula.sh`, `Mokka.sh`, and `macOS.sh` use `SCRIPT_DIR`/`find_private_restore_dir()` for shell histories, zoxide `db.zo`, Mokka KDE activity data, and optional Claude memory; missing private snapshots are skipped without failing the install.


## Arch Install Project

Project note lives outside the public repo:
- Local Codex project: `~/Documents/Codex/Website/Projects/Arch Install/README.md`
- Synology backup: `Scripts/Notes/Projects/Arch Install/README.md`

Plan: keep official Arch ISO and `archinstall` for safe disk selection, but streamline Steve's repeated choices with a thin wrapper.

Interactive questions:
- target disk
- hostname
- username
- password
- post-install choice: Dracula GNOME, Mokka KDE, or macOS-style GNOME

Fixed defaults:
- ext4
- GRUB
- pipewire
- NetworkManager
- `en_US.UTF-8`
- `us`
- `America/New_York`
- United States mirrors
- user has sudo/root permission
- minimal/base profile; GPU handling stays inside `Dracula.sh`, `Mokka.sh`, and `macOS.sh`

Two-stage design:
- `install.sh` runs from Arch ISO/USB, wraps `archinstall`, handles disk/user/defaults, and writes a first-boot marker.
- `first-boot.sh`/`gpt-setup` runs after reboot, finds `ARCH_*` USB/Synology, then launches the chosen theme script and restores private files from Synology/local private snapshots.

Safety requirements: disk picker must show device path, size, model, serial when available, existing OS/partitions when detectable, warn on the `ARCH_*` boot USB, and require typing the exact target disk before wipe.

## Critical Knowledge - Don't Break These

### Dracula.sh (GNOME)
- **blur-my-shell**: Enable LAST with 5-second delay (crashes otherwise)
- **AUR validation**: `yay -Q` for AUR, `pacman -Qi` for pacman
- **UFW**: Needs `systemctl enable ufw` (not just `ufw --force enable`)
- **Autostart cleanup**: Delete files BEFORE logout (race condition)

### Mokka.sh (KDE)
- **Dolphin state**: Plasma 6 uses `~/.local/state/dolphinstaterc`
- **Display scaling**: Remove `ScreenScaleFactors=`, use `kscreen-doctor output.1.scale.2` (200% is sharper than fractional)
- **Logging functions**: Guard with `[[ -n "$LOGFILE" && -f "$LOGFILE" ]]` before tee
- **Digital Clock Widget**:
  ```ini
  [Configuration][Appearance]
  autoFontAndSize=false
  boldText=true
  customDateFormat=dddd, MMM d
  dateDisplayFormat=BesideTime
  dateFormat=custom
  fontFamily=Noto Sans Black
  fontSize=14
  fontStyleName=Black
  fontWeight=900
  showWeekNumbers=true
  ```
  Note: Plasma widgets render fonts thinner than Qt apps - use Black/900 for proper weight
- **Panel Colorizer** (`luisbocanegra.panel.colorizer`):
  - `widgets.enabled=true`
  - `widgets.shadow.foreground.enabled=true` (size: 5) - adds text shadow
  - `unfiedBackground["org.kde.plasma.digitalclock"]=0` - clock tracked separately
- **Window borders**: KWin Round-Corners effect in `~/.config/kwinrc`:
  ```
  [Round-Corners]
  Size=20                          # Corner radius
  OutlineThickness=4.5             # Active border thickness
  ActiveOutlineUsePalette=true     # Uses theme accent color
  ActiveOutlineAlpha=253
  InactiveOutlineThickness=3.5     # Inactive border thickness
  InactiveOutlinePalette=19        # Palette color index
  InactiveOutlineUsePalette=true
  InactiveOutlineAlpha=255
  ```
- **Blur effect**: `kwin-effects-better-blur-dx` from AUR
  - Config section: `[Effect-better-blur-dx]` in kwinrc
  - Plugin: `better_blur_dxEnabled=true` in `[Plugins]`
  - Mokka.sh installs from AUR (not forceblur - that's deprecated)
  - Garuda bundles it via `garuda-mokka` (forceblur conflicts with garuda-mokka)
- **Logout screen blur**: Custom `Logout.qml` in Mokka-lookandfeel theme
  - Problem: Plasma logout screen relies on kwin compositor blur, which broke with old plugins
  - Solution: QML-based blur independent of compositor - loads wallpaper + applies Qt FastBlur
  - Location: `Mokka/themes/Mokka-lookandfeel/contents/logout/Logout.qml`
  - Key code:
    ```qml
    Image {
        id: wallpaperImage
        source: "file:///usr/share/wallpapers/garuda-mokka/Mokka-tree.jpg"
        visible: false  // Hidden - source for blur
    }
    FastBlur {
        source: wallpaperImage
        radius: 50
    }
    Rectangle {
        color: "black"
        opacity: 0.3  // Darken overlay
    }
    ```
  - Works regardless of which kwin blur plugin is installed

### Both Scripts
- **Printer**: Use `dnssd://` URIs, mDNS discovery, no hardcoded IPs. Canon TR8600 needs `cnijfilter2` AUR
- **AMD GPP0 fix**: Systemd service disables GPP0 wakeup (prevents wake after suspend)
- **Carapace**: Use `bash-ble` mode (not `bash`), install `carapace-bin` (prebuilt)
- **Ghostty**: In `extra` repo (prebuilt), shell-integration = none (see double-prompt fix section)
- **Starship**: In `extra` repo (prebuilt), use `install_packages` not AUR
- **ScreenScaleFactors**: Remove from both `plasmashellrc` AND `kdeglobals`

## Updating Dracula GTK Theme

1. Download latest from https://github.com/dracula/gtk/releases to `~/Downloads/Dracula`
2. Copy custom icon: `cp ~/.themes/Dracula/gnome-shell/assets/view-app-grid.svg ~/Downloads/Dracula/gnome-shell/assets/`
3. Append custom CSS to `~/Downloads/Dracula/gnome-shell/gnome-shell.css` (show-apps icon + hover effects)
4. Trash old, copy new: `gio trash ~/.themes/Dracula && cp -r ~/Downloads/Dracula ~/.themes/`
5. GTK4 fix: `cp ~/.themes/Dracula/gtk-4.0/*.css ~/.config/gtk-4.0/`
6. GTK4 assets: `cp -r ~/.themes/Dracula/assets ~/.config/`
7. Test GTK3 and GTK4 apps
8. Package: `cd ~/.themes && tar -cJf Dracula-GTK.tar.xz Dracula`
9. Sync: Copy to repo, git push, copy to USB

**Custom CSS to append** (end of `gnome-shell/gnome-shell.css`):
```css
/* Show Apps Icon - Custom themed icon */
.show-apps .show-apps-icon {
  color: transparent !important;
  background-image: url("assets/view-app-grid.svg");
  background-size: contain;
}

.show-apps .overview-icon,
.show-apps .show-apps-icon {
  color: transparent !important;
}

/* Show Apps Hover Effect - Dracula Purple */
#panel .panel-button.show-apps:hover {
  box-shadow: inset 0 0 0 100px rgba(189, 147, 249, 0.5);
  color: white;
  transition-duration: 200ms;
}

#panel .panel-button.show-apps:active,
#panel .panel-button.show-apps:focus,
#panel .panel-button.show-apps:checked {
  box-shadow: inset 0 0 0 100px rgba(189, 147, 249, 0.7);
  color: white;
  transition-duration: 200ms;
}

/* Dash Show Apps Hover (if in dash) */
#dash .show-apps:hover .overview-icon {
  background-color: rgba(189, 147, 249, 0.3);
}

#dash .show-apps:active .overview-icon,
#dash .show-apps:checked .overview-icon {
  background-color: rgba(189, 147, 249, 0.5);
}
```

## CachyOS Kernel
Optional at install. Package name: `linux-cachyos` (LTO now default).

**Builds:** `~/Documents/compiled-kernels/` (timestamped subdirs)
**Repo only:** Kernel/headers tar.xz go to `Shared/` in repo + git push. Never copied to USB.

**Required configs:** CONFIG_TCP_CONG_BBR, CONFIG_NET_SCH_CAKE, CONFIG_IP_NF_IPTABLES (UFW), CONFIG_CIFS (SMB)

## SMB/CIFS Direct Mount

**Why:** GVFS ~175 MB/s vs Direct CIFS ~245 MB/s (+40% faster)

**Credentials:** `~/.smbcredentials` (chmod 600)
```
username=steve
password=<synology_password>
```

**fstab:**
```
//synology.local/external /mnt/synology cifs credentials=/home/steve/.smbcredentials,vers=3.1.1,multichannel,max_channels=4,rsize=4194304,wsize=4194304,uid=1000,gid=1000,_netdev,nofail 0 0
//synology.local/plex /mnt/plex cifs credentials=/home/steve/.smbcredentials,vers=3.1.1,multichannel,max_channels=4,rsize=4194304,wsize=4194304,uid=1000,gid=1000,_netdev,nofail 0 0
```

## SSH Workflow (Fresh Installs)

Claude Code needs browser OAuth. SSH from Mac:

```bash
# Arch TTY: ip addr | grep 192
# Mac: ssh steve@192.168.x.x
export TERM=xterm-256color
curl -fsSL https://claude.ai/install.sh | bash && export PATH="$HOME/.local/bin:$PATH" && claude
```

## Claude Memory System

Claude builds persistent memory across sessions in `~/.claude/projects/<path>/memory/`.

**Memory paths per platform:**
| Platform | Path |
|----------|------|
| Arch Linux | `~/.claude/projects/-home-steve/memory/` |
| macOS | `~/.claude/projects/-Users-steve/memory/` |
| Windows | `%USERPROFILE%\.claude\projects\C--Users-Steve\memory\` |

**Backup memory before reinstall:**
```bash
cp ~/.claude/projects/-home-steve/memory/*.md "/Volumes/External/WEB Scripts/Scripts/Claude/memory/"
```

**Restore rule:** Claude memory is private. It stays on Synology/private local media, never in DRACULARCH. `bash.sh` restores it from Synology. `Dracula.sh`, `Mokka.sh`, and `macOS.sh` restore it only if a local private snapshot is present, otherwise they skip cleanly.

**Windows:** Memory is NOT restored on reinstall — Windows builds its own context independently.

## Claude Code Notes
- **USB check**: Use full path (parent dir fails). Label = `ARCH_` + YYYYMM (changes monthly)
  - Linux: `ls /run/media/steve/ARCH_YYYYMM/`
  - macOS: `ls /Volumes/ARCH_YYYYMM/`
- **ble.sh check**: Use `bash -c '[[ ... ]]'` (Bash tool runs sh)
- **Setup repo**: `cp -r "/mnt/synology/WEB Scripts/Scripts/Setup Repo/ssh-backup" ~/Documents/ && bash "/mnt/synology/WEB Scripts/Scripts/Setup Repo/setup-repo.sh" setup`

## Hardware
- Intel 14900K, 32GB, Samsung Odyssey G8 4K@240Hz
- AMD 9950X3D, 64GB
- Mac M4 Pro, 24GB

## Firefox userChrome.css - Dracula Theme (Linux)

Full Dracula theming for Firefox URL bar and dropdown.

**Location:** `~/.mozilla/firefox/<profile>/chrome/userChrome.css`

**Key colors:**
- `#2d2f3d` - URL bar (closed) - slightly lighter than page background
- `#21222c` - URL bar + dropdown (open) - darker, seamless together
- `#bd93f9` - Purple border on focus
- `#44475a` - Hover/selection background (current-line)
- `#f8f8f2` - Text (foreground)

**Features:**
- Dracula window control buttons (close/min/max) from GTK theme
- URL bar dropdown with purple border and proper Dracula colors
- Bookmark bar spacing to match Brave/Chrome
- Font weight fixes for high-DPI displays
- Bookmark star turns purple when starred

**Bookmark spacing (2K @ 125%):**
```css
#PlacesToolbarItems > .bookmark-item {
  padding-inline: 0px !important;
  margin-inline: 6px !important;
  font-size: 108% !important;
}
#PersonalToolbar {
  padding-block: 2px !important;
}
```

**Note:** Toolbar icons (back, forward, home, reload, downloads, extensions) use Firefox defaults - no custom styling needed. Previous filter-based approaches caused color issues.

## Firefox userChrome.css - macOS Dark Theme

Full macOS dark theming for Firefox URL bar and dropdown — pure black backgrounds, macOS system blue accent.

**Location:** `~/Library/Application Support/Firefox/Profiles/<profile>/chrome/userChrome.css`

**Enable:** `about:config` → `toolkit.legacyUserProfileCustomizations.stylesheets = true` (set in `user.js` via Betterfox)

**Key colors:**
- `#000000` - URL bar + dropdown background (pure black, seamless with macOS dark)
- `#0a84ff` - macOS system blue (border on focus, selected row)
- `#3a3a3c` - Hover background (macOS tertiary)
- `#f5f5f7` - Text (macOS label primary)
- `#8e8e93` - Secondary text (URL, actions, separators)
- `#ffd60a` - macOS yellow (unused currently, defined for star states)

**Features:**
- URL bar with 2px macOS blue border on focus
- Dropdown seamlessly connects to URL bar (no top border, rounded bottom corners only)
- Font weight fixes for high-DPI (tabs 700, urlbar/bookmarks 550)
- Bookmark bar spacing to match Brave/Chrome (`padding-inline: 0`, `margin-inline: 6px`, `font-size: 115%`)
- Zoom button hidden from URL bar
- Star button turns blue when starred

**Bookmark spacing (macOS):**
```css
#PlacesToolbarItems > .bookmark-item {
  padding-inline: 0px !important;
  margin-inline: 6px !important;
  font-size: 115% !important;
}
#PersonalToolbar {
  padding-block: 2px !important;
}
```

**Companion `user.js`:** Customized Betterfox v144 at same profile path. Key customizations:
- 2GB memory cache (32GB RAM system)
- Search suggestions + speculative loading kept enabled
- DRM + PDF scripting enabled
- Built-in password manager kept
- GPU acceleration forced (Metal on Hackintosh RX 6950 XT)
- Telemetry/experiments/crash reports disabled
- Homepage + new tab → google.com

## macOS Terminal Setup (bash.sh)

**Script locations:**
- `~/Documents/bash.sh` (working copy)
- `/Volumes/external/WEB Scripts/Scripts/bash.sh` (Synology backup)
- USB drive (for fresh installs)

**Configs in repo:** `macOS/Bash/` (pulled from GitHub - NOT the script itself)

### What it installs:
- Homebrew (if needed)
- Bash 5.x + ble.sh (fish-like autosuggestions)
- Ghostty terminal (Catppuccin Mocha, Mantle background #181825)
- Starship prompt with Apple icon
- Fastfetch with kitty logo (mokka-fastfetch.png)
- Modern CLI tools: eza, bat, zoxide, fzf, btop, carapace
- JetBrainsMono Nerd Font
- Claude Code with CLAUDE.md + settings.json from repo
- Dracularch repo (clones via SSH if Synology mounted)

### Configs pulled from GitHub:
- `bashrc`, `bash_profile`, `blerc`
- `ghostty/config` (102x26, Mantle bg, JetBrainsMono Bold 13pt)
- `fastfetch/config.jsonc` + `mokka-fastfetch.png`
- `starship.toml`, `bat/config`, `btop/btop.conf`
- `bash_history` (common macOS commands)

### Re-run behavior (idempotent):
- **Homebrew packages**: Skips if installed, upgrades if outdated
- **ble.sh**: Updates via git pull + make
- **Claude Code**: Skips install if exists, always updates configs
- **Configs**: Prompts - download from GitHub / backup to repo / skip
- **Dracularch repo**: Skips clone if exists, does git pull instead

### Repo Setup (requires Synology):
If Synology mounted, script will:
1. Copy SSH keys from `/Volumes/external/WEB Scripts/Scripts/Setup Repo/ssh-backup/`
2. Configure git (user.name, user.email)
3. Clone Dracularch via SSH to `~/Dracularch`

### SMB Optimization:
Creates `/etc/nsmb.conf` with:
```ini
[default]
signing_required=no
validate_neg_off=yes
smb_read=4194304
smb_write=4194304
mc_on=yes
mc_prefer_wired=yes
dir_cache_max_cnt=0
```
**Result:** ~285 MB/s writes to Synology (better than Linux!)

Mounts on demand via Finder - click Network → Synology → pick share. No clutter, no login scripts.

### Usage:
```bash
# Fresh install (mount Synology first for full setup):
bash ~/Documents/bash.sh

# Update packages + pull latest configs:
bash ~/Documents/bash.sh
# Choose option 1 (download from GitHub) or 3 (skip) at config prompt
```

### Notes:
- Script is idempotent (safe to re-run)
- ble.sh built from git (not Homebrew)
- Fastfetch path auto-fixed for current user's $HOME
- Creates ~/.hushlogin to suppress login message
- **Script lives on USB/Synology only - NEVER in repo**

## Ghostty 1.3.1 + ble.sh double-prompt — FIXED (2026-05-05)

**Status:** Working fix confirmed on Linux (14900K / Ghostty 1.3.1-arch2, ble.sh r2319). All other systems still have the double-prompt until configs are updated.

**Root cause:** Ghostty auto-injects its bash shell integration, which conflicts with ble.sh initialization. The fix is to disable Ghostty's auto-injection and manually source the integration script before ble.sh instead.

### The fix (apply to all systems)

**1. Ghostty config** — set `shell-integration = none` (prevents auto-injection):
```
shell-integration = none
```

**2. `.bashrc`** — manually source Ghostty integration BEFORE ble.sh:
```bash
# Ghostty shell integration (sourced manually before ble.sh for correct ordering)
[[ -n "$GHOSTTY_RESOURCES_DIR" && -f "$GHOSTTY_RESOURCES_DIR/shell-integration/bash/ghostty.bash" ]] && \
    source "$GHOSTTY_RESOURCES_DIR/shell-integration/bash/ghostty.bash"

# ble.sh
[[ -f /usr/share/blesh/ble.sh ]] && source /usr/share/blesh/ble.sh --attach=prompt
```

Key: `--attach=prompt` on the ble.sh source line. The manual Ghostty source must come first.

### Why earlier `shell-integration = none` attempts failed
Those were tried alone on macOS without the manual source line. Without it, Ghostty features (cursor tracking, title, etc.) are lost entirely — blinking cursor. The manual source restores them; `none` just stops Ghostty from doing it automatically at the wrong moment.

### When Ghostty 1.3.2 lands
Test whether the fix is still needed:
1. Change Ghostty config back to `shell-integration = bash`
2. Remove the manual Ghostty source line from `.bashrc`
3. Open a new shell — if single prompt, revert is clean and done
4. If double-prompt returns, put the fix back

If 1.3.2 fixes the auto-injection timing, the manual workaround can be dropped. If not, keep it — it works regardless of Ghostty version.

### Upstream tracking
- github.com/akinomyoga/ble.sh/issues/684 (opened 2026-03-17)
- Root cause: Ghostty changed bash shell integration between 1.3.0→1.3.1

## AI Tools — Linux

### Claude Code (`claude`)
Main agent. Config files (`CLAUDE.md`, `settings.json`) are symlinks into the DRACULARCH repo (see "CLAUDE.md / settings.json — Symlinked to Repo" above).

### DeepSeek (`deep` alias)
DeepSeek routed through Claude Code using DeepSeek's Anthropic-compatible API. Same Claude Code harness, full tool access — `deep` behaves as an autonomous agent thanks to the coaching system prompt.
- Alias in `~/.bashrc`: `alias deep='source ~/.config/mg-deepseek/key.env && claude --bare --settings ~/.config/mg-deepseek/claude-deepseek-settings.json --model deepseek-v4-pro --append-system-prompt-file ~/.config/mg-deepseek/coaching.md'`
- Files in `~/.config/mg-deepseek/`: `claude-deepseek-settings.json`, `key.env` (chmod 600), `coaching.md`
- Restored from Synology `Scripts/Notes/mg-deepseek-{settings.json,key.env,coaching.md}` on fresh install
- Use for: script analysis, code review, optimization. **Use Privacy Relay for scripts with personal info** (see below).

### Advisor pattern — Opus brain, Sonnet hands
Main session is pinned to Opus (`"model": "opus"` in `settings.json`). When spawning subagents via the Agent tool, **default to `model: "sonnet"`** — Opus stays in the main thread doing the thinking; Sonnet does the legwork (Explore, general-purpose, Plan, code-reviewer, code-simplifier, etc.). Only escalate a subagent to Opus if the task itself needs deep judgment in isolation. Haiku is rarely needed.

### Skill reach-for cheat sheet
The 6 plugins enabled in `settings.json` (context7, superpowers, claude-md-management, huggingface-skills, code-simplifier, watch@claude-video) are installed for a reason. Match generously — if a task even loosely fits one of these, invoke the skill BEFORE doing the work.

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

**Hugging Face / ML** (only when actually relevant): see huggingface-skills plugin for model recommendations, local LLM via GGUF, training (LLM/vision), trackio, hf-cli, papers, gradio, transformers-js, datasets.

**Claude API / Anthropic SDK code:** code importing `anthropic` SDK, prompt caching tuning, model version migration → `claude-api`.

**Default rule:** if a skill might apply, invoke it. The skill content tells you whether it actually fits.

### Privacy Relay (Deep workflow)

Use when working on scripts with personal info before handing off to `deep`.

1. Copy the file to a working location and say **"sanitize for deep: /path/to/copy"**
2. Claude reads the copy, builds a substitution map, edits the copy in place (real → placeholder)
3. Open the copy in Deep and do the work
4. When done, say **"restore from deep"** — Claude edits the copy back (placeholder → real)

Common personal info to catch: IPs, hostnames, usernames, email, SSH key paths, Synology share paths, paths containing real names.

Use realistic-looking dummy values — not obvious placeholders like FAKE_USER. Examples: `johndoe`, `john@example.com`, `192.168.1.50`, `/mnt/nas/backup`. Keep the map so restore is exact.

---

## Reminders
- **Mokka symbolic icons**: Consider overlaying Dracula's white symbolic icons onto Catppuccin theme for panel/Dolphin. Source: `/usr/share/icons/Dracula/symbolic/` (1,564 SVGs). Copy to `~/.local/share/icons/[theme]/symbolic/`
