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

### Package Installation Fix (Dec 2025)

**Problem**: Pacman provider prompts (e.g., "choose ttf-font provider") hang when output is captured or redirected, causing batch installs to fail silently.

**Solution**: Use `yes "" |` to auto-accept default providers, output to logfile (not captured):
```bash
yes "" | sudo pacman -S --noconfirm --needed --overwrite '*' "${packages[@]}" >>"$LOGFILE" 2>&1
```

**Final verification**: Don't verify packages mid-install. Check once at the end before summary:
```bash
verify_final_state() {
    for pkg in "${attempted_packages[@]}"; do
        if pacman -Qi "$pkg" >/dev/null 2>&1 || yay -Q "$pkg" >/dev/null 2>&1; then
            successful_installs+=("$pkg")
        else
            failed_installs+=("$pkg")
        fi
    done
}
```

**Key points**:
- `yes "" |` feeds empty lines to accept default provider choices
- Don't use `$()` subshell capture — breaks the pipe
- Track attempts in `attempted_packages` array
- Verify filesystem state at end, not during install

### Dracula.sh (GNOME)
- **blur-my-shell**: Enable LAST with 5-second delay (crashes otherwise)
- **AUR validation**: `yay -Q` for AUR, `pacman -Qi` for pacman
- **UFW**: Needs `systemctl enable ufw` (not just `ufw --force enable`)
- **Autostart cleanup**: Delete files BEFORE logout (race condition)

### Mokka.sh (KDE)

**The Sacred 14 Plasma Configs** - ONLY these config files should be restored:
1. `plasma-org.kde.plasma.desktop-appletsrc` - Panel/widget layout
2. `plasmashellrc` - Plasma shell settings
3. `kdeglobals` - Global KDE settings, colors
4. `kwinrc` - Window manager, effects, compositing
5. `kded5rc` - KDE daemon (legacy)
6. `kded6rc` - KDE daemon (Plasma 6)
7. `kcminputrc` - Input device settings
8. `kscreenlockerrc` - Lock screen settings
9. `baloofilerc` - File indexing
10. `plasmanotifyrc` - Notifications
11. `konsolerc` - Terminal settings
12. `dolphinrc` - File manager settings
13. `arkrc` - Archive manager
14. `kwinoutputconfig.json` - Display resolution/scaling (fixes 4K 200% issue)

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
  InactiveOutlineThickness=0       # No inactive border
  InactiveOutlineUsePalette=true
  InactiveOutlineAlpha=204
  InactiveShadowSize=30
  ```
- **Force Blur**:
  - KWin script path: `~/.local/share/kwin/scripts/forceblur/` (not effects)
  - Package: `kwin-scripts-forceblur` (not effects)
  - Blur whitelist in `kwinrc`: `[Script-forceblur]` section `blurMatching` key
- **Forceblur (RECOMMENDED)** - Garuda's working blur:
  - Package archived from chaotic-aur Nov 2025, saved to repo
  - **Install on Arch**: `sudo pacman -U ~/Dracularch/Shared/kwin-effects-forceblur-1.5.0-1.9-x86_64.pkg.tar.zst`
  - kwinrc settings:
    ```
    [Plugins]
    blurEnabled=false              # Stock blur OFF
    forceblurEnabled=true          # Forceblur ON

    [Effect-blurplus]              # Yes, section is "blurplus" not "forceblur"
    BlurDecorations=true
    BlurMatching=false
    BlurNonMatching=true
    BottomCornerRadius=20
    DockCornerRadius=20
    MenuCornerRadius=20
    NoiseStrength=0                # Critical for clean logout!
    PaintAsTranslucent=true
    TopCornerRadius=20
    WindowClasses=xwaylandvideobridge
    ```
  - After install: `qdbus org.kde.KWin /KWin reconfigure`
- **Better Blur DX** (alternative, AUR):
  - Package: `kwin-effects-better-blur-dx`
  - kwinrc settings (**note: section uses HYPHENS not underscores**):
    ```
    [Plugins]
    blurEnabled=false              # Stock blur OFF
    better-blur-dxEnabled=true     # Better blur ON (HYPHENS!)

    [Effect-better-blur-dx]        # HYPHENS not underscores!
    BlurStrength=10                # Default 15 is too strong
    NoiseStrength=0                # Default 5 - causes grainy logout
    Brightness=100                 # Neutral
    Saturation=100                 # Default 150 causes brownish tint!
    Contrast=100                   # Neutral
    BlurDecorations=true
    BlurMatching=false
    BlurNonMatching=true
    BlurMenus=true
    BlurDocks=true
    CornerRadius=20
    ```
  - **Critical defaults that break logout**: Saturation=150 (brownish), NoiseStrength=5 (grainy)

### macOS.sh
- Same structure as Dracula.sh but with macOS Tahoe theme
- Blue/White/Gray color scheme
- Uses same package installation pattern

## Session-Specific Notes

### ble.sh Completions
- **SSH tab completion**: `source "$HOME/.ble-complete-ssh"` in ~/.bashrc after ble.sh attach
- ble.sh reads bash_completion but SSH host completion needs extra hook

### EFI Partition
- Script uses `efibootmgr` to set label
- EFI labels: "Arch", "archOS" (macOS.sh)

### Synology SMB Mount
Standard mount in scripts:
```bash
# /etc/fstab entry
//192.168.1.101/Media /mnt/synology cifs credentials=/home/$USER/.smb_credentials,uid=1000,gid=1000,iocharset=utf8 0 0
```

### Carapace Completions (Bash + ble.sh)
```bash
# In ~/.bashrc
source <(carapace _carapace bash)
```

## System Info

### Hardware
- **AMD**: 7950X3D, 64GB RAM, Gigabyte B650 Aorus Elite AX
- **Intel**: 14900K, 32GB RAM, Gigabyte Z790 Aorus Master
- **Monitor**: Samsung Odyssey G8 4K 240Hz (3840x2160)
- **Network**: 2.5GbE to Synology DS1821+

### Display Scaling
- 4K at 200% scaling (2x)
- Fonts: all at 11pt (Interface, Document, Monospace, Titlebar)

## macOS/Hackintosh Notes

**SMB speed:** ~285 MB/s writes via `/etc/nsmb.conf` multichannel config.

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
- Session 58: Blur finally working! Logout screen perfect. Updates:
  - Moved forceblur package from `Shared/` to `Mokka/packages/` (Mokka-only, not shared)
  - Updated Mokka.sh: install forceblur from repo via `pacman -U` instead of dead AUR package
  - Removed old kscreen-doctor scaling code from Mokka.sh (kwinoutputconfig.json handles it)
  - Added "Sacred 14 Plasma Configs" list to CLAUDE.md with kwinoutputconfig.json as #14
- Session 57: Grabbed `kwin-effects-forceblur-1.5.0-1.9-x86_64.pkg.tar.zst` from Garuda and saved to `Shared/`. This is the working blur package - archived from chaotic-aur but still functional. Install with `sudo pacman -U`. Updated CLAUDE.md with install instructions.
- Session 56: Investigated Garuda Mokka blur setup. Key findings:
  - Garuda Mokka also has NO custom logout folder - falls back to Breeze like Arch
  - Uses `kwin-effects-forceblur` (chaotic-aur) NOT `better-blur-dx`
  - Plugin enabled as `forceblurEnabled=true` but config section is `[Effect-blurplus]`
  - `NoiseStrength=0` is critical for clean logout
- Session 55: Applied hyphenated blur config fix to kwinrc. Changed `[Effect-better_blur_dx]` → `[Effect-better-blur-dx]` and `better_blur_dxEnabled` → `better-blur-dxEnabled`. KWin reloaded, effect active. Still need to update Mokka.sh and repo configs.
- Session 54: Garuda blur investigation complete. Findings:
  - Garuda uses `kwin-effects-forceblur` from **chaotic-aur** (not standard AUR)
  - Package was **archived Nov 20, 2025** - no longer maintained
  - `kwin-effects-better-blur-dx` is the continuation/fork (standard AUR)
  - **KEY DISCOVERY**: Config section uses HYPHENS: `[Effect-better-blur-dx]` not underscores!
  - Previous attempts may have failed due to wrong section name `[Effect-better_blur_dx]`
  - Plugin enable key also uses hyphens: `better-blur-dxEnabled=true`
- Session 53: BLUR STILL NOT FIXED. Need to boot into Garuda (working reference) and extract EXACT settings.
- Session 52: Logout still brownish after better_blur_dx install. Found default Saturation=150 was the culprit. Set BlurStrength=10, Saturation=100, Brightness=100, Contrast=100. These settings need to go in mokka.sh and repo kwinrc.
- Session 51: Root cause of blur issues found - "blurplus" package never existed! Old configs referenced `blurplusEnabled=true` but no such effect was installed. Installed `kwin-effects-better-blur-dx` (AUR) which provides proper blur replacement. Settings: `blurEnabled=false` + `better_blur_dxEnabled=true` + `NoiseStrength=0`. Need to update mokka.sh to install this package and update repo kwinrc configs. Testing logout now.
- Session 50: No blur at all (everything transparent). Opposite of Session 49 - `blurplusEnabled=true` was missing from kwinrc Plugins section. Added it via kwriteconfig6. Correct state: `blurEnabled=false` (stock blur off) + `blurplusEnabled=true` (blurplus on) + `NoiseStrength=0` (logout fix).
- Session 49: Logout screen blur broken again (overblurred/brownish). Found `blurEnabled=true` in kwinrc Plugins section - should be `false`. Regular blur effect was running ON TOP of blurplus causing double-blur. Repo has correct `blurEnabled=false`. Something enabled it after fresh install - investigating what triggered this. Testing if logout/login applies fix.
- Session 48: Fixed package installation failures caused by pacman provider prompts. `$()` subshell capture breaks `yes` pipe. Solution: `yes "" | sudo pacman ... >>"$LOGFILE" 2>&1`. Applied to all three scripts.
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
- Session 28: Major Mokka plasma config update from Garuda
- Session 27: Updated Mokka repo configs from Garuda testing
- Session 26: Garuda clock/Colorizer settings + full terminal/Dolphin setup
- Session 25: Weather widget deep dive on Garuda Linux
- Session 24: Weather widget fix + Flameshot screenshot tool
- Session 23: time.py archinstall automation script
- Session 22: macOS.sh brought to Dracula.sh parity
- Session 21: Major repo reorganization
