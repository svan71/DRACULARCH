# CLAUDE.md

Guidance for Claude Code working with DRACULARCH repository.

## Steve's Preferences - READ FIRST
- **Bash with ble.sh** - Fish-like UX, POSIX compatible
- Simple and effective, no over-engineering
- Ask questions one at a time
- Hates typing - keep commands short
- Script output must be themed - use color variables
- **NEVER put .sh scripts in the repo** - scripts live on USB/Synology only

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

## Public Repo Privacy Rules

DRACULARCH is public. It must never track keys, auth files, `.env`, Claude memory, shell histories, zoxide DBs, KDE activity databases/logs, or other local state dumps. Those restore conveniences belong on Synology/USB private backup locations, not GitHub.

As of 2026-05-04, `.gitignore` blocks the common leak paths, and these files were removed from tracking while left on local disk for convenience:
- `*history*`
- `db.zo`
- `Mokka/configs/activities/kactivitymanagerd/resources/`
- `Claude/memory/`

Fresh installs should restore private material from Synology/USB, not the public repo.

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
- **Ghostty**: In `extra` repo (prebuilt), shell-integration = bash
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
cp ~/.claude/projects/-home-steve/memory/*.md ~/Dracularch/Claude/memory/
cd ~/Dracularch && git add Claude/memory/ && git commit -m "Update Claude memory" && git push
```

**Restore is automatic** — Dracula.sh, Mokka.sh, and bash.sh all pull memory from the repo during install.

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

## WAITING FOR FIX: Double Prompt Bug (Ghostty 1.3.1 + ble.sh)

**Status:** Upstream issue filed — waiting for ble.sh fix. Do NOT attempt local workarounds.

**Issue:** Prompt renders twice on session start in Ghostty 1.3.1. Confirmed on both macOS and Linux (CachyOS).
Started after Ghostty updated to 1.3.1 (macOS: 2026-01-06, Linux: confirmed 2026-03-18).

**Root cause:** ble.sh + Ghostty 1.3.1 shell integration conflict. Disabling ble.sh eliminates double prompt. Ghostty changed bash shell integration between 1.3.0→1.3.1 (two specific commits identified by ble.sh maintainer). Not starship-specific — other user reproduces without starship.

### Upstream tracking:
- **Active issue:** github.com/akinomyoga/ble.sh/issues/684 (opened 2026-03-17, OPEN)
  - Another user (Dominiquini) reported same bug on EndeavourOS, Ghostty 1.3.1, ble.sh 0.4.0-devel4
  - ble.sh maintainer (akinomyoga) identified two Ghostty commits between 1.3.0→1.3.1 as culprits
  - Waiting on Ghostty team (@jparise) to investigate
- **Previous fixes (now insufficient):**
  - Issue #543: Fixed with commit `430a174` (deferred ble-attach for Ghostty) — closed Jan 2025
  - Issue #557: Fixed with commit `4338bbf` (updated workaround after Ghostty changed integration) — closed Feb 2025
  - Both fixes are in our installed ble.sh but Ghostty 1.3.1 broke it again

### Linux versions (as of 2026-03-18):
- Ghostty 1.3.1-arch1 (GTK runtime, io_uring)
- ble.sh 0.4.0_devel4.r2302.2f564e63 (built 2025-12-31, installed via blesh-git AUR)
- Starship 1.24.2
- Bash (CachyOS kernel 6.19.3)

### All macOS workaround attempts (ALL FAILED):
1. `bleopt prompt_command_changes_layout=1` - no effect
2. `bleopt internal_suppress_bash_output=1` - no effect
3. `shell-integration = none` - killed prompt entirely (blinking cursor)
4. Hide BLE_VERSION during starship init (force PROMPT_COMMAND over blehook) - no effect
5. Removed PROMPT_COMMAND title-setter line - no effect
6. `shell-integration-features = no-cursor,no-title` - no effect
7. `shell-integration = none` + BLE_VERSION hide combined - STILL double prompts
8. Both bleopt options together + `shell-integration = none` - STILL double prompts
9. Downgrade Ghostty - not possible (private repo, no old binaries)

### When fix lands:
- Update ble.sh: `yay -S blesh-git` (Linux) or `ble-update` (macOS)
- On macOS also update ble.sh: `cd ~/.local/share/blesh && git pull && make`
- Restart shell, verify single prompt

### Config state (both platforms, reverted to clean):
- Ghostty config: `shell-integration = bash`
- `.bashrc`: original (no workaround lines)
- `.blerc`: clean (no workaround bleopt lines)

## Reminders
- **Mokka symbolic icons**: Consider overlaying Dracula's white symbolic icons onto Catppuccin theme for panel/Dolphin. Source: `/usr/share/icons/Dracula/symbolic/` (1,564 SVGs). Copy to `~/.local/share/icons/[theme]/symbolic/`
