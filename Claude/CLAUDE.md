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
├── Claude/           # CLAUDE.md + settings.json
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

**"sync" means:** Copy to repo → git push → copy to USB

## Critical Knowledge - Don't Break These

### Dracula.sh (GNOME)
- **blur-my-shell**: Enable LAST with 5-second delay (crashes otherwise)
- **AUR validation**: `yay -Q` for AUR, `pacman -Qi` for pacman
- **UFW**: Needs `systemctl enable ufw` (not just `ufw --force enable`)
- **Autostart cleanup**: Delete files BEFORE logout (race condition)

### Mokka.sh (KDE)
- **TahoeLauncher**: Path = `/usr/share/plasma/plasmoids/TahoeLauncher/`
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

## time.py - Automated Installer

Pre-configured archinstall automation script on USB. Tested with archinstall 3.0.14.

**Usage:**
```bash
python3 time.py
```

**What it does:**
- Prompts for password (hashed, not stored)
- Shows drives with mount warnings, double-confirms selection
- Auto-updates archinstall, warns if version changed
- Configures: linux-zen, Grub (removable), 512MB /boot + 50GB / + remainder /home (ext4)
- Creates user `steve` with sudo, enables sshd, creates `/mnt/usb` and `/usr/local/bin/usb` helper

**Post-reboot workflow:**
```bash
# Login as steve
usb                      # mounts USB, cd's into it
./mokka.sh               # or ./dracula.sh
```

**Version tracking:** Update `TESTED_ARCHINSTALL_VERSION` in script when archinstall changes.

## SSH Workflow (Fresh Installs)

Claude Code needs browser OAuth. SSH from Mac (sshd already enabled by time.py):

```bash
# Arch TTY: ip addr | grep 192
# Mac: ssh steve@192.168.x.x
export TERM=xterm-256color
curl -fsSL https://claude.ai/install.sh | bash && export PATH="$HOME/.local/bin:$PATH" && claude
```

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

## 14900K Tuning (Gigabyte Z790 Aorus Master)

**Results:** 5.5GHz all-core, 6.2GHz boost, R23: 40,742, temps max 87°C

**BIOS Settings:**
| Setting | Value |
|---------|-------|
| Intel Default Profile | High (not Extreme) |
| IA AC/DC Loadline | 55 |
| IA VR Voltage Limit | 1400 (1.4V cap - critical) |
| IA VR Current Limit | 0 (unlimited) |
| Package Power Limit 1 & 2 | 4095 |
| Core Current Limit | 512A |
| P-core Ratio | 62 (6.2GHz) |
| E-core Ratio | 46 (4.6GHz) |
| Vcore LLC | High |
| VF Offset Mode | Selective |

**V/F Curve (Selective mode):**
| Point | Ratio | Offset |
|-------|-------|--------|
| 1-5 | 8-43x | -0.090V |
| 6 | 51x | -0.070V |
| 7 | 56x | -0.060V |
| 8 | 58x | -0.050V |
| 9 | 60x | +0.100V |
| 10-11 | - | Auto |

**Key principles:** 1.4V hard cap prevents degradation, undervolt at low frequencies for efficiency, full voltage only at boost. Kernel compile with FullLTO + AVX-512 is the hardest stability test.

## Firefox userChrome.css - Dracula Theme

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

## Dark Reader Config - PENDING CHANGES

**File:** `/mnt/synology/WEB Scripts/Google/Dark-Reader-Settings.json`

Steve will restore from backup. Then apply these changes:

### 1. Replace ALL Dracula selection colors with Catppuccin Mocha Mauve
```
Find:    "selectionColor": "#6272A4",
Replace: "selectionColor": "#cba6f7",
```

### 2. Replace claude.ai config block entirely
Find the claude.ai entry and replace with:
```json
{
    "theme": {
        "mode": 1,
        "brightness": 115,
        "contrast": 95,
        "grayscale": 0,
        "sepia": 0,
        "useFont": false,
        "fontFamily": "Open Sans",
        "textStroke": 0,
        "engine": "dynamicTheme",
        "stylesheet": "",
        "darkSchemeBackgroundColor": "#11111b",
        "darkSchemeTextColor": "#ffffff",
        "lightSchemeBackgroundColor": "#dcdad7",
        "lightSchemeTextColor": "#181a1b",
        "scrollbarColor": "auto",
        "selectionColor": "#c29df1",
        "styleSystemControls": false,
        "lightColorScheme": "Default",
        "darkColorScheme": "Catppuccin",
        "immediateModify": false
    },
    "url": [
        "claude.ai"
    ]
}
```

### Key Catppuccin Mocha colors for reference:
- `#11111b` - Crust (darkest, used for claude.ai background)
- `#1e1e2e` - Base (standard background)
- `#cdd6f4` - Text
- `#cba6f7` - Mauve (selection color for most sites)
- `#c29df1` - Lighter mauve variant (used for claude.ai selection)

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

## macOS Finder Favorites (Synology Shares)

After fresh macOS install, recreate Synology shares in Finder Favorites:

1. **Connect to Synology**: Finder → Go → Connect to Server → `smb://synology.local`
2. **Mount each share**: Select and mount `Apple`, `External`, `Plex` individually
3. **Drag to Favorites**: Once they appear in Locations (sidebar), drag each one up to the Favorites section

They'll have eject icons (▲) indicating mounted network volumes. macOS remembers Favorites across reboots.

**Auto-mount on login** (optional): System Settings → General → Login Items → add each mounted share under "Open at Login"

**Note**: Top-level SMB shares mount to `/Volumes/` and can be dragged directly to Favorites. For subfolders within shares (like WEB Scripts inside External), you'd need symlinks - but that's not needed here since Apple, External, and Plex are all top-level shares.

## macOS Power Management (M4 Pro)

Prevent unwanted wake events:
```bash
sudo pmset -a powernap 0       # Disable Power Nap (biggest offender)
sudo pmset -a womp 0           # Disable Wake on LAN
sudo pmset -a proximitywake 0  # Disable iPhone/Watch proximity wake
sudo pmset -a tcpkeepalive 0   # Disable network connection wakes
sudo pmset schedule cancelall  # Clear scheduled wakes (Calendar, Focus, Analytics)
```

| Setting | Purpose |
|---------|---------|
| `powernap 0` | Stops mDNSResponder, dasd, NotificationCenter wakes |
| `womp 0` | Disables Wake on LAN |
| `proximitywake 0` | Stops iPhone/Watch proximity wake |
| `tcpkeepalive 0` | Stops apps maintaining network connections during sleep |
| `schedule cancelall` | Clears Calendar travel, Focus mode, Analytics wakes |

**Tradeoffs of tcpkeepalive 0:**
- Find My won't update location during sleep
- iCloud/Mail won't sync during sleep
- Push notifications won't wake Mac

**Note:** `disksleep 0` warning is cosmetic - SSDs don't spin down anyway.

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
- **AdGuard + Chrome + Twitter/X**: There's an issue with AdGuard extension on Chrome breaking Twitter/X. Needs investigation. Config files in `~/Downloads/` and `/mnt/synology/WEB Scripts/AdGaurd/`
- **Windows 11**: Run [RemoveWindowsAI](https://github.com/zoicware/RemoveWindowsAI) - strips Copilot, Recall. Use backup mode, PowerShell 5.1.
- **Mokka symbolic icons**: Consider overlaying Dracula's white symbolic icons onto Catppuccin theme for panel/Dolphin. Source: `/usr/share/icons/Dracula/symbolic/` (1,564 SVGs). Copy to `~/.local/share/icons/[theme]/symbolic/`
- **COSMIC Desktop**: Considering Cosmic.sh script. Dracula theme exists on cosmic-themes.org. Config in `~/.config/cosmic/`, uses `.ron` files. Install Arch + COSMIC to explore.

## Session History
- Session 39: Switch from forceblur to better-blur-dx
  - Mokka.sh now installs `kwin-effects-better-blur-dx` from AUR (not forceblur)
  - Updated repo kwinrc: `forceblurEnabled=true` → `better_blur_dxEnabled=true`
  - Deleted `Mokka/packages/kwin-effects-forceblur-*.pkg.tar.zst` from repo
  - Updated Mokka.sh: removed forceblur download, added better-blur-dx to AUR packages
  - Panel Colorizer presets confirmed up to date (version 6.4.0, Mokka presets bundled upstream)
  - Checked Intel system wake config - no custom fixes needed (Garuda uses kernel defaults)
  - AMD GPP0 fix only applies to AMD systems (PCIe wake bug)
- Session 38: Fresh Garuda blur issue redux
  - Garuda now ships `kwin-effects-better-blur-dx` via `garuda-mokka` package
  - `kwin-effects-forceblur` conflicts with `garuda-mokka`
  - Fix for Garuda: Reset kwinrc to skeleton (`cp /etc/skel/.config/kwinrc ~/.config/kwinrc`)
- Session 37: Blur fix completed + repo/USB sync
  - Updated repo kwinrc: `[Effect-blurplus]` → `[Effect-better-blur-dx]`
  - Applied all repo plasma configs to current Garuda
- Session 36: Logout screen blur fix (Garuda Mokka)
  - Issue: Logout screen showing muddy brownish color instead of blurred background
  - Cause: Old `blurplus` + `forceblur` plugins incompatible with new `better-blur-dx`
  - Solution: Custom `Logout.qml` with QML-based FastBlur (independent of compositor)
  - Created `Mokka/themes/Mokka-lookandfeel/` with custom logout screen
- Session 35: bash.sh enhancements - Claude Code, repo setup, Finder symlinks
  - Added Claude Code install to bash.sh (pulls CLAUDE.md + settings.json from GitHub)
  - Added setup_repo() - restores SSH keys from Synology, clones Dracularch via SSH

## Hackintosh EFI Notes (AMD System)

### System Configuration
- **CPU**: AMD Ryzen 9 7950X3D (AM5)
- **GPU**: AMD Radeon RX 6600 (8GB)
- **SMBIOS**: MacPro7,1
- **macOS**: 26.2 (Tahoe) Build 25C56
- **OpenCore**: 1.0.6 (Official Acidanthera)

### EFI Location
`/Volumes/EFI/EFI/OC/`

### Changes Made (Dec 22, 2025 - Updated)

**1. SSDT Darwin Wrapper Fixes**
- **SSDT-EC**: Wrapped USBX `_DSM` kUSB* properties in `_OSI("Darwin")` check
- **SSDT-PLUG-ALT**: Wrapped C000 `_DSM` plugin-type in `_OSI("Darwin")` check
- Both SSDTs previously relied only on `_STA` to hide devices from Linux
- Now have explicit `_OSI("Darwin")` checks in `_DSM` methods for defense-in-depth
- All other SSDTs (ANS, ARPT, GIGE, HDEF, SBUS) already had proper wrapping

**2. Switched to Official OpenCore 1.0.6**
- Migrated from NO_ACPI 1.0.7 to Official Acidanthera 1.0.6
- Config rebuilt from official `Sample.plist` with settings migrated
- Config passes `ocvalidate` with zero errors
- NO_ACPI binaries were never actually required for this setup

**3. Previous: Updated OpenCore to 1.0.7 (NO_ACPI)**
- Replaced BOOTx64.efi, OpenCore.efi
- Updated drivers: OpenCanopy, OpenRuntime, OpenLinuxBoot, ResetNvramEntry
- Replaced Resources folder (retained BlackOSX theme)

**4. AllowSetDefault Enabled**
- `Misc → Security → AllowSetDefault` = true
- Use **Ctrl+Enter** in boot picker to set default boot drive

**5. Theme Configuration**
- `Misc → Boot → PickerMode` = External
- `Misc → Boot → PickerVariant` = `BlackOSX/BsxM1` (use forward slash, not backslash)
- Theme files at: `Resources/Image/BlackOSX/BsxM1/`

**6. Previous Changes (Dec 22, 2024)**
- Cleaned 211 `._*` metadata files from EFI
- Enabled Resizable BAR (`ResizeGpuBars: 0`)
- Updated NootRX to Dec 15, 2024 nightly

### Kexts Installed
| Kext | Version |
|------|---------|
| Lilu | 1.7.2 |
| VirtualSMC | 1.3.8 |
| NootRX | 1.0.0 (Dec 2024) |
| AppleALC | 1.9.7 |
| AMDRyzenCPUPowerManagement | 0.7.2 |
| AppleMCEReporterDisabler | 1.2 |
| AMFIPass | 1.4.1 |
| BlueToolFixup | 2.6.9 |
| AppleIntelI210Ethernet | 2.3.1 |
| RestrictEvents | 1.1.7 |

### AMD Kernel Patches
16 kernel patches from AMD Vanilla (verified current as of Dec 2025):
- Core AMD patches (cpuid, commpage, mtrr, etc.)
- CaseySJ IOPCIFamily patches for AM5 (both enabled)
- Visual non-monotonic time patches
- Algrey/Zormeister PAT fix for 15.0+
- MaxKernel: 25.99.99 (covers Tahoe kernel 25.x)

### ACPI SSDTs
All SSDTs use proper `_OSI("Darwin")` wrapping for macOS-only execution:

| SSDT | Protection Method |
|------|------------------|
| SSDT-ANS | `_OSI("Darwin")` wraps entire file (3 NVMe devices) |
| SSDT-ARPT | `_OSI("Darwin")` in `_DSM` methods |
| SSDT-GIGE | `_OSI("Darwin")` in `_DSM` methods |
| SSDT-HDEF | `_OSI("Darwin")` in `_DSM` method |
| SSDT-SBUS | `_OSI("Darwin")` in `_DSM` method |
| SSDT-EC | `_OSI("Darwin")` in `_DSM` + `_STA` (fixed Dec 2025) |
| SSDT-PLUG-ALT | `_OSI("Darwin")` in `_DSM` + `_STA` (fixed Dec 2025) |
| SSDT-XHCI | `_OSI("Darwin")` in `_STA` methods |
| SSDT-HPET | `_OSI("Darwin")` in methods |
| SSDT-XOSI | `_OSI("Darwin")` in method |

### Important Notes

**Official OpenCore**
This EFI uses **official Acidanthera OpenCore** binaries. NO_ACPI method not needed because:
- All SSDTs have proper `_OSI("Darwin")` conditional wrapping
- Config.plist uses only standard schema keys
- Config passes official `ocvalidate` validation

**Ethernet**
- Using AppleIntelI210Ethernet for Intel I225-V (2.5Gbps working)
- AppleIGC not compatible with macOS Tahoe on AMD (SDK mismatch + no VT-d)

**Resizable BAR**
- Config enabled (`ResizeGpuBars: 0`) but GPU shows 256MB BAR
- Likely BIOS or NootRX driver limitation

**OCAT Compatibility Warning**
- OCAT may lag behind OpenCore releases
- Opening config in OCAT may strip unrecognized keys
- Use ProperTree or text editor for manual config edits

### OpenCore Update Workflow
1. Download new release from https://github.com/acidanthera/OpenCorePkg/releases
2. Extract to `~/Desktop/OpenCore_OFFICIAL_XXX/`
3. Start with new `Docs/Sample.plist`, rename to `config.plist`
4. Migrate your settings using the migration script or manually
5. Replace binaries: `EFI/BOOT/BOOTx64.efi`, `EFI/OC/OpenCore.efi`
6. Replace drivers: `EFI/OC/Drivers/*.efi`
7. **Keep**: `ACPI/*.aml`, `Kexts/`, `Resources/`
8. Validate with `ocvalidate` before installing
9. Backup old EFI before replacing

### OpenCanopy Theme Requirements
For themes to work, these folders must contain files:
- `Resources/Font/` - Font_1x.bin, Font_1x.png, Font_2x.bin, Font_2x.png
- `Resources/Label/` - .lbl and .l2x files for boot entry labels
- `Resources/Image/<ThemeName>/` - theme icons

If theme fails to load, check that Font and Label folders are not empty.

### Useful Commands
```bash
# Mount EFI
sudo diskutil mount disk0s1

# Check GPU
system_profiler SPDisplaysDataType

# Check Ethernet
system_profiler SPEthernetDataType

# Clean EFI metadata
dot_clean /Volumes/EFI/EFI

# Validate config with official ocvalidate
~/Desktop/OpenCore_OFFICIAL_106/Utilities/ocvalidate/ocvalidate /Volumes/EFI/EFI/OC/config.plist

# Update NootRX
curl -L -o /tmp/NootRX.zip "https://nightly.link/ChefKissInc/NootRX/workflows/main/master/Artifacts.zip"

# Check AMD Vanilla patches (latest)
curl -sL "https://raw.githubusercontent.com/AMD-OSX/AMD_Vanilla/master/patches.plist" -o /tmp/amd_vanilla_latest.plist

# Check SSDT Darwin wrappers (decompile and search)
cd /Volumes/EFI/EFI/OC/ACPI && for f in *.aml; do iasl -d "$f" 2>/dev/null; done
grep -rn "_OSI.*Darwin" *.dsl
rm *.dsl
```

### Backup Locations
- `~/Desktop/EFI_BACKUP_NO_ACPI_107/` - Previous NO_ACPI 1.0.7 EFI
- `~/Desktop/OpenCore_OFFICIAL_106/` - Official OC 1.0.6 package
- `~/Desktop/EFI_OFFICIAL_106/` - New official EFI (ready to install)

### Resources
- OpenCore: https://github.com/acidanthera/OpenCorePkg/releases
- OpenCore Guide: https://dortania.github.io/OpenCore-Install-Guide/
- AMD Vanilla: https://github.com/AMD-OSX/AMD_Vanilla
- NootRX: https://chefkiss.dev/applehax/nootrx/
- AppleIGC: https://github.com/SongXiaoXi/AppleIGC

## Hackintosh EFI Notes (Intel System)

### System Configuration
- **CPU**: Intel Core i9-14900K (LGA1700)
- **Motherboard**: Gigabyte Z790 Aorus Master
- **GPU**: AMD Radeon RX 6950 XT
- **Ethernet**: Realtek RTL8125B 2.5GbE
- **WiFi/BT**: BCM94360NG (native)
- **Audio**: Realtek ALC1220-VB
- **SMBIOS**: MacPro7,1
- **OpenCore**: 1.0.6 (Official Acidanthera)

### EFI Location
`/Volumes/EFI/EFI/OC/`

### Changes Made (Dec 30, 2025)

**1. Fixed Windows Boot Logo Alignment**
- Gigabyte logo was misaligned when booting Windows through OpenCore
- Cause: `UEFI → Output → Resolution` was set to `Max`, forcing GOP resolution change before Windows handoff
- Fix: Set `Resolution` to empty string (firmware default)
- Also reverted `UIScale` from 2 back to 1 (UIScale 2 caused oversized boot picker icons)

### Changes Made (Dec 22, 2025)

**1. Migrated to Official OpenCore 1.0.6**
- Migrated from NO_ACPI version to Official Acidanthera 1.0.6
- Config rebuilt from official `Sample.plist` with settings migrated
- Fixed PickerVariant: `BlackOSX\BsxM1` → `BlackOSX/BsxM1` (forward slash)
- Config passes `ocvalidate` with zero errors

**2. SSDT Darwin Wrapper Fix**
- **SSDT-XHCI**: Added `If (!_OSI ("Darwin")) { Return (Zero) }` guard to `_DSM` method
- `_DSM` was returning macOS properties (model, device-id, port-count) unconditionally
- Now properly protected - only returns properties on macOS

### Kexts Installed
| Kext | Version | Purpose |
|------|---------|---------|
| Lilu | 1.7.2 | Core patching kext |
| VirtualSMC | 1.3.8 | SMC emulation |
| NootRX | 1.0.0 | RX 6950 XT graphics |
| AppleALC | 1.9.7 | ALC1220-VB audio |
| CpuTopologyRebuild | 2.0.2 | i9-14900K core topology |
| CPUFriend | 1.3.1 | CPU power management |
| CPUFriendDataProvider | 1.0.0 | CPUFriend data |
| BlueToolFixup | 2.6.9 | BCM94360NG Bluetooth |
| XHCI-unsupported | 0.9.2 | Z790 USB support |
| LucyRTL8125Ethernet | 1.2.2 | RTL8125B 2.5GbE |
| RestrictEvents | 1.1.7 | Memory warnings fix |

### ACPI SSDTs (13 total)
| SSDT | Protection Method | Purpose |
|------|-------------------|---------|
| SSDT-EC-USBX | `_STA` returns Zero for non-Darwin | Fake EC + USB power |
| SSDT-PLUG-ALT | `_STA` returns Zero for non-Darwin | CPU power management |
| SSDT-AWAC-DISABLE | `If (_OSI ("Darwin"))` in \_INI | RTC compatibility |
| SSDT-SBUS | `If (_OSI ("Darwin"))` wraps file | SMBus fix |
| SSDT-PPMC | `If (_OSI ("Darwin"))` wraps file | Power Management Controller |
| SSDT-XHCI | `_STA` + `_DSM` Darwin checks (fixed) | USB port map |
| SSDT-IMEI | `If (_OSI ("Darwin"))` in Scope | Intel MEI fix |
| SSDT-SATA | `If (_OSI ("Darwin"))` wraps file | SATA controller |
| SSDT-XSPI | `If (_OSI ("Darwin"))` wraps file | SPI controller |
| SSDT-HDEF | `If (_OSI ("Darwin"))` wraps file | Audio device |
| SSDT-ARPT | `If (_OSI ("Darwin"))` wraps file | WiFi device |
| SSDT-ANS | `If (_OSI ("Darwin"))` wraps file | 3x NVMe devices |
| SSDT-FWHD | `_STA` returns Zero for non-Darwin | Firmware Hub |

### Config Notes
- **CPUID Spoof**: Raptor Lake spoofed as Comet Lake for macOS compatibility
- **iGPU Disabled**: DeviceProperties `disable-gpu` on PciRoot(0x0)/Pci(0x2,0x0)
- **Boot Args**: `npci=0x2000`
- **Resizable BAR**: Enabled (`ResizeGpuBars: 0`)

### Backup Locations
- `~/Desktop/EFI_INTEL_BACKUP/` - Previous NO_ACPI EFI
- `~/Desktop/OpenCore_OFFICIAL_106_INTEL/` - Official OC 1.0.6 package
- `~/Desktop/EFI_INTEL_OFFICIAL_106/` - New official EFI (ready to install)
