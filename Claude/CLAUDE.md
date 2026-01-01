# CLAUDE.md

Guidance for Claude Code working with DRACULARCH repository.

## Steve's Preferences - READ FIRST
- **"check notes" = read this CLAUDE.md file**
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
**USB:** /run/media/steve/ARCH_202512

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
├── macOS/            # Mac-related files (future)
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
| `~/.claude.json` | Claude Code prefs (theme, notifications) |
| `~/Dracularch/Claude/` | Repo copy → git push |
| `/run/media/steve/ARCH_202512/` | USB (scripts + configs) |
| `/mnt/synology/WEB Scripts/Arch/Claude/USB Files/` | Synology (previous backups) |

**USB mount:** If `/run/media/steve/ARCH_202512/` not mounted, run: `udisksctl mount -b /dev/sda1`

**"sync" means:** Copy to repo → git push → copy to USB

## Fresh Install - Repo Setup

**Script:** `/mnt/synology/WEB Scripts/Scripts/Setup Repo/setup-repo.sh`

Restores SSH keys, configures git, sets up repo with SSH remote.

```bash
# 1. Copy SSH backup to Documents
cp -r "/mnt/synology/WEB Scripts/Scripts/Setup Repo/ssh-backup" ~/Documents/

# 2. Run setup (restores keys, configures git, clones/updates repo)
bash "/mnt/synology/WEB Scripts/Scripts/Setup Repo/setup-repo.sh" setup

# 3. If repo already cloned via HTTPS, switch to SSH
cd ~/Dracularch && git remote set-url origin git@github.com:svan71/DRACULARCH.git
```

**Other commands:** `setup-repo.sh push`, `setup-repo.sh pull`, `setup-repo.sh status`

## Critical Knowledge - Don't Break These

### Package Installation Verification (FIXED Dec 2025)
**Problem**: False positives — gdm/gnome-shell showing as "failed" when actually installed.

**Root cause**: Trusting pacman's exit code instead of verifying actual state. Pacman returns non-zero for many reasons that aren't failures (package already installed with `--needed`, warnings, etc.). The backgrounded batch install made this worse.

**Solution**: Ignore exit codes entirely. Verify with `pacman -Qi` (is_package_installed) after install:
```bash
# OLD (broken) - trusts exit code
if sudo pacman -S --noconfirm --needed "$package" >/dev/null 2>&1; then
    successful_installs+=("$package")
else
    failed_installs+=("$package")  # FALSE POSITIVE - package may actually be installed
fi

# NEW (fixed) - verify actual state
sudo pacman -S --noconfirm --needed "$package" >/dev/null 2>&1 || true
if is_package_installed "$package"; then
    successful_installs+=("$package")
else
    failed_installs+=("$package")  # Only fails if genuinely not installed
fi
```

**Batch install fix** (install_packages function):
- Removed backgrounding `( ... ) &` — caused exit code issues
- Run batch with `|| true` — ignore exit code
- After batch completes, verify each package with `is_package_installed`
- Only retry packages that are genuinely missing

**Key principle**: The filesystem state is the truth, not the exit code. Always verify with `pacman -Qi`.

### Dracula.sh (GNOME)
- **blur-my-shell**: Enable LAST with 5-second delay (crashes otherwise)
- **AUR validation**: `yay -Q` for AUR, `pacman -Qi` for pacman
- **UFW**: Needs `systemctl enable ufw` (not just `ufw --force enable`)
- **Autostart cleanup**: Delete files BEFORE logout (race condition)

### Mokka.sh (KDE)
- **TahoeLauncher**: Path = `/usr/share/plasma/plasmoids/TahoeLauncher/`
- **Dolphin state**: Plasma 6 uses `~/.local/state/dolphinstaterc`
- **Display scaling**: Remove `ScreenScaleFactors=` from kdeglobals/plasmashellrc, use `kwinoutputconfig.json` (not kscreen-doctor)
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

### Both Scripts
- **Printer**: Use `dnssd://` URIs, mDNS discovery, no hardcoded IPs. Canon TR8600 needs `cnijfilter2` AUR
- **AMD GPP0 fix**: Systemd service disables GPP0 wakeup (prevents wake after suspend)
- **Carapace**: Use `bash-ble` mode (not `bash`), install `carapace-bin` (prebuilt)
- **Ghostty**: In `extra` repo (prebuilt), shell-integration = bash
- **Starship**: In `extra` repo (prebuilt), use `install_packages` not AUR
- **ScreenScaleFactors**: Remove from both `plasmashellrc` AND `kdeglobals`

## CachyOS Kernel
Optional at install. Package name: `linux-cachyos` (LTO now default).

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
- **USB check**: Use full path `ls /run/media/steve/ARCH_202512/` (parent dir fails)
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

## macOS Terminal Setup (bash.sh)

Script on USB/Synology installs: Homebrew, Bash 5.x + ble.sh, Ghostty (Catppuccin Mocha), Starship, modern CLI tools, Claude Code.

**SMB speed:** ~285 MB/s writes (better than Linux!) via `/etc/nsmb.conf` multichannel config.

## Hackintosh EFI Notes

### AMD System (7950X3D)
- OpenCore 1.0.6 Official, MacPro7,1, NootRX for RX 6600
- All SSDTs use `_OSI("Darwin")` wrapping
- AppleIntelI210Ethernet for Intel I225-V 2.5GbE

### Intel System (14900K)
- OpenCore 1.0.6 Official, MacPro7,1, NootRX for RX 6950 XT
- CPUID spoofed as Comet Lake, CpuTopologyRebuild for hybrid cores
- LucyRTL8125Ethernet for RTL8125B 2.5GbE

**Common fixes applied:**
- PickerVariant: use forward slash `BlackOSX/BsxM1` not backslash
- AllowSetDefault: Ctrl+Enter to set default boot drive
- SSDT `_DSM` methods: wrap in `_OSI("Darwin")` checks

## Firefox/FireDragon Restore

**Script:** `/mnt/synology/WEB Scripts/Scripts/Fire Backup/fire-backup.sh`

Backups stored in `/mnt/synology/WEB Scripts/Scripts/Fire Backup/fire-backups/`

**Restore workflow** (globs don't work - need exact backup name):
```bash
# 1. List available backups
ls "/mnt/synology/WEB Scripts/Scripts/Fire Backup/fire-backups/"

# 2. Restore with exact name (Firefox must be installed first)
echo "y" | bash "/mnt/synology/WEB Scripts/Scripts/Fire Backup/fire-backup.sh" restore firefox-backup-2025-12-22_07-12-23 -b firefox

# FireDragon
echo "y" | bash "/mnt/synology/WEB Scripts/Scripts/Fire Backup/fire-backup.sh" restore firedragon-backup-2025-12-22_07-12-28 -b firedragon
```

**What's restored:** bookmarks, extensions, settings, passwords (encrypted), history, cookies, userChrome.css, containers.

## Quick Commands

**"copy build 3 to documents":**
```bash
cp "/mnt/synology/WEB Scripts/Scripts/CachyOS Kernel/build3.sh" "/mnt/synology/WEB Scripts/Scripts/CachyOS Kernel/modprobed-combined.db" ~/Documents/
```

## Reminders
- **Windows 11**: Run [RemoveWindowsAI](https://github.com/zoicware/RemoveWindowsAI) - strips Copilot, Recall. Use backup mode, PowerShell 5.1.
- **COSMIC Desktop**: Considering Cosmic.sh script. Dracula theme exists on cosmic-themes.org
- **Mokka symbolic icons**: Consider overlaying Dracula white icons onto Catppuccin

## Session History
- Session 28: Major Mokka plasma config update from Garuda
  - Updated 9 plasma configs in repo from current Garuda system:
    - kdeglobals (fonts 11pt, removed ScreenScaleFactors)
    - kwinrc (blur/effects, Round-Corners)
    - plasmashellrc (panel thickness 82)
    - plasma-org.kde.plasma.desktop-appletsrc (Colorizer, clock, weather)
    - kscreenlockerrc (fixed wallpaper path for Arch)
    - kcminputrc, plasmanotifyrc, konsolerc (fixed profile to Default.profile)
  - **NEW**: Added `kwinoutputconfig.json` for display scaling (replaces kscreen-doctor)
    - Handles resolution/scale/refresh for Samsung G8 regardless of DP/HDMI port
    - Uses edidIdentifier to match monitor, not connector name
  - Updated Mokka.sh on USB:
    - Added kwinoutputconfig.json to restore list
    - Removed kscreen-doctor call (json file handles scaling)
  - Updated TahoeLauncher favorites (kactivitymanagerd database)
  - Fixed SDDM login screen cat icon (was showing Garuda default)
  - Restored Dolphin settings on Garuda from repo
- Session 47: Fresh Mokka install fixes + script improvements
  - Fixed `kwin-effects-forceblur` → `kwin-scripts-forceblur` in mokka.sh (package removed from AUR)
  - Fixed display scale not applying: added `kwinoutputconfig.json` to `plasma_configs` array
  - Fixed fire-backup.sh paths with spaces bug (unquoted glob in `select_backup_for_restore`)
  - Added `read_password()` function to all 3 scripts - shows `*` asterisks as you type
  - Reordered browsers in mokka.sh and dracula.sh: Chrome, Firefox, Brave, Firedragon, Edge
- Session 46: Logout blur fix corrected. The fix is `Effect-blurplus` NoiseStrength=0, not Effect-logout BlurStrength.
- Session 45: Weather widget fix complete. Added Phase 12 to `mokka-first-login.sh` that dynamically finds weather widget applet ID and configures all settings (Vincentown NJ, fahrenheit, inHg, mph) via kwriteconfig6 on first login.
- Session 44: Weather widget location not restoring (shows Vancouver instead of Vincentown). Found repo appletsrc missing `[Configuration][Location]` section with `firstRun=false`. Added it + fixed pressureType to inHg. Also backed up Panel Colorizer presets to repo (`Mokka/configs/panel-colorizer/`).
- Session 43: Mokka install review. Only failure: `kwin-effects-forceblur` (removed from AUR). Replaced with `kwin-scripts-forceblur`. Installed manually, KWin reloaded.
- Session 42: Fixed Firefox restore docs (need exact backup name, not glob). Added Fresh Install - Repo Setup section (SSH keys + setup-repo.sh). USB path on Dracula is `/run/media/steve/ARCH_202512/`.
- Session 41: PROPERLY fixed package verification false positives. Previous "fix" (Session 36) was backwards — trusting exit codes was the problem, not the solution. Correct approach: ignore exit codes, verify with `is_package_installed` (`pacman -Qi`). Removed backgrounding from batch install. Also cleaned up verbose printer output.
- Session 27: Updated Mokka repo configs from Garuda testing
  - Clock widget: Noto Sans Black, size 14, weight 900 (widgets render thinner than Qt apps)
  - Weather widget: `org.kde.weatherWidget-3` → `weather.widget.plus`
  - kdeglobals: font size 11 → 10, removed ScreenScaleFactors
  - Pushed to GitHub - next Mokka install will use these settings
- Session 26: Garuda clock/Colorizer settings + full terminal/Dolphin setup
  - Digital clock: Noto Sans Bold 13pt, date beside time (`dddd, MMM d`), week numbers
  - Panel Colorizer: foreground shadow enabled (size 5), tracks clock widget
  - Installed: Ghostty, btop, zoxide, blesh-git, carapace-bin (via paru)
  - Copied: bashrc, blerc, bat, btop, fastfetch, starship, Ghostty configs
  - Set up SMB mounts (/mnt/synology, /mnt/plex) with fstab
  - Restored zoxide db and bash history
  - Note: Garuda uses `paru` not `yay`
- Session 25: Weather widget deep dive on Garuda Linux (first Claude Code on Garuda)
  - Explored weather widget options:
    - **Weather Widget Plus** (`weather.widget.plus`) - fork with more customization, buggy compact mode
    - **Chaac.Complete.Weather** - edited QML (removed °F suffix, adjusted spacing/icon), still frustrating
    - **Default KDE** (`org.kde.plasma.weather`) - wettercom only provider shown, wettercom is DEAD
  - **Solution**: Use NOAA provider with **Mount Holly, NJ** (close to Vincentown, has NWS office)
  - Weather providers on system: `bbcukmet`, `dwd`, `envcan`, `noaa`, `wettercom` (in `/usr/lib/qt6/plugins/plasma/weather_ions/`)
  - Applied Mokka fonts to Garuda kdeglobals (Noto Sans Bold 10pt everywhere)
  - Tried separating system tray widgets into individual panel widgets:
    - **What you get**: Control over order, direct click (no tray expand)
    - **What you DON'T get**: Icon appearance control (icon theme), widget width control (widget design)
    - System tray items can be reordered and set to "shown" anyway
  - **Conclusion**: Stick with system tray layout, use NOAA provider for weather
- Session 24: Weather widget fix + Flameshot screenshot tool
  - Removed broken `org.kde.plasma.weather` (wettercom provider dead)
  - Removed `kweather` package entirely (question mark icon issue)
  - Installed `plasma6-applets-weather-widget-3-git` (Weather Widget Plus)
  - Weather Widget 3 config: metno provider, Vincentown NJ, Noto Sans Bold font
  - Installed `plasma6-applets-plasmusic-toolbar` (media controls for panel)
  - Installed `flameshot` for screenshots (tray icon, GNOME-like workflow)
  - Print Screen key mapped to Flameshot
  - Added `Mokka/configs/flameshot/flameshot.ini` to repo
  - Updated plasma config: removed all kweather/old weather refs
- Session 23: time.py archinstall automation script
  - Updated config format for archinstall 3.0.14
  - Added password prompt (hashed with SHA512, not stored)
  - Improved drive selection: shows mounts, double-confirm, CAUTION warnings
  - Added version detection: warns if archinstall version changes
  - Config: linux-zen, Grub (removable for OpenCore), 512MB /boot + 50GB / + remainder /home
  - Enables multilib repo, pipewire, bluetooth, NetworkManager
  - custom_commands: mkdir /mnt/usb, systemctl enable sshd, creates /usr/local/bin/usb helper
  - Post-reboot: `usb` command mounts USB and cd's into it
- Session 22: macOS.sh brought to Dracula.sh parity
  - Replaced Fish with Bash + ble.sh
  - Fixed logging functions with tee guards (LOGFILE existence check)
  - Fixed setup_kernel URLs → `Shared/Cachyos-*.tar.xz`
  - Fixed install_aur_packages: `pacman -Qi` → `yay -Q`
  - Fixed restore_gnome_extensions URL → `Dracula/assets/Extensions.tar.xz`
  - Added full 2.5Gb network optimizations (sysctl settings)
  - Fixed setup_grub: removed LTO kernel references
  - Fixed Plymouth: added animation service, deferred mkinitcpio
  - Added SMB credential collection and setup_smb_and_portals
  - Fixed UFW with proper systemctl enable
  - Added AMD GPP0 wake fix
  - Replaced printer setup with dnssd auto-detect
  - Updated carapace to bash-ble mode
  - Fixed EFI label to "archOS"
  - Reordered browsers: Firefox, Firedragon, Chrome, Brave, Edge (both scripts)
  - Fixed default apps (audio: mpv → smplayer)
- Session 21: Major repo reorganization
  - Created Dracula/assets/ (moved 10 archives from root)
  - Created Shared/ (CachyOS kernel files, renamed without spaces)
  - Created macOS/ (moved 4 Mac files)
  - Created Archive/ (deprecated Fish configs)
  - Converted Dracula-Plymouth.zip and Dracula-Wallpaper.zip to .tar.xz
  - Updated Dracula.sh: 10 GitHub URLs to new paths
  - Updated Mokka.sh: 4 GitHub URLs to new paths
- Session 20: Fresh Mokka verified, script fixes (thefuck, ScreenScaleFactors in kdeglobals, starship → extra)
- Session 19: Mokka.sh Fish → Bash + ble.sh, Konsole removed
- Session 18: Dracula.sh fresh install verified
