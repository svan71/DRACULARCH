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
├── macOS/
│   └── Bash/         # macOS terminal configs (bashrc, ghostty, fastfetch, etc.)
└── Archive/          # Deprecated Fish configs
```

## File Locations & Sync

| Location | Purpose |
|----------|---------|
| `~/CLAUDE.md` | Active instructions (live) |
| `~/.claude/settings.json` | Permissions (live) |
| `~/Dracularch/Claude/` | Repo copy → git push |
| `/run/media/steve/ARCH_202512/` | USB (scripts + configs) |

**"sync" means:** Copy to repo → git push → copy to USB

## Critical Knowledge - Don't Break These

### Package Installation Verification (FIXED Dec 2025)
**Problem**: False positives for gdm/gnome-shell showing as "failed" when actually installed.

**Root cause**: Race condition - script ran `pacman -S`, slept 0.1s, then checked `pacman -Qi`. The sleep was too short after batch install failures.

**Solution**: Trust pacman exit code directly instead of secondary verification:
```bash
# OLD (broken) - race condition
sudo pacman -S --noconfirm --needed "$package" >/dev/null 2>&1
sleep 0.1
if pacman -Qi "$package" >/dev/null 2>&1; then  # can fail due to race

# NEW (fixed) - trust exit code
if sudo pacman -S --noconfirm --needed "$package" >/dev/null 2>&1; then
```

### Dracula.sh (GNOME)
- **blur-my-shell**: Enable LAST with 5-second delay (crashes otherwise)
- **AUR validation**: `yay -Q` for AUR, `pacman -Qi` for pacman
- **UFW**: Needs `systemctl enable ufw` (not just `ufw --force enable`)
- **Autostart cleanup**: Delete files BEFORE logout (race condition)

### Mokka.sh (KDE)
- **TahoeLauncher**: Path = `/usr/share/plasma/plasmoids/TahoeLauncher/`
- **Dolphin state**: Plasma 6 uses `~/.local/state/dolphinstaterc`
- **Display scaling**: Remove `ScreenScaleFactors=`, use `kscreen-doctor output.1.scale.2`
- **Logging functions**: Guard with `[[ -n "$LOGFILE" && -f "$LOGFILE" ]]` before tee
- **Digital Clock**: Noto Sans Black 14pt, weight 900 (widgets render thinner)
- **Panel Colorizer**: `widgets.shadow.foreground.enabled=true` (size: 5)

### Both Scripts
- **Printer**: Use `dnssd://` URIs, mDNS discovery, no hardcoded IPs
- **AMD GPP0 fix**: Systemd service disables GPP0 wakeup (prevents wake after suspend)
- **Carapace**: Use `bash-ble` mode (not `bash`), install `carapace-bin` (prebuilt)
- **Ghostty/Starship**: In `extra` repo (prebuilt), use `install_packages` not AUR
- **ScreenScaleFactors**: Remove from both `plasmashellrc` AND `kdeglobals`

## SMB/CIFS Direct Mount

**Why:** GVFS ~175 MB/s vs Direct CIFS ~245 MB/s (+40% faster)

**fstab:**
```
//synology.local/external /mnt/synology cifs credentials=/home/steve/.smbcredentials,vers=3.1.1,multichannel,max_channels=4,rsize=4194304,wsize=4194304,uid=1000,gid=1000,_netdev,nofail 0 0
```

## time.py - Automated Installer

Pre-configured archinstall automation on USB. Tested with archinstall 3.0.14.

```bash
python3 time.py    # prompts for password, drive selection
usb                # post-reboot: mounts USB, cd's into it
./dracula.sh       # or ./mokka.sh
```

## SSH Workflow (Fresh Installs)

```bash
# Arch TTY: ip addr | grep 192
# Mac: ssh steve@192.168.x.x
export TERM=xterm-256color
curl -fsSL https://claude.ai/install.sh | bash && export PATH="$HOME/.local/bin:$PATH" && claude
```

## Hardware
- Intel 14900K, 32GB, Samsung Odyssey G8 4K@240Hz
- AMD 9950X3D, 64GB
- Mac M4 Pro, 24GB

## 14900K Tuning (Gigabyte Z790 Aorus Master)

**Results:** 5.5GHz all-core, 6.2GHz boost, R23: 40,742, temps max 87°C

| Setting | Value |
|---------|-------|
| Intel Default Profile | High (not Extreme) |
| IA AC/DC Loadline | 55 |
| IA VR Voltage Limit | 1400 (1.4V cap - critical) |
| P-core Ratio | 62 (6.2GHz) |
| E-core Ratio | 46 (4.6GHz) |

**Key principle:** 1.4V hard cap prevents degradation. Kernel compile with FullLTO + AVX-512 is hardest stability test.

## macOS Terminal Setup (bash.sh)

Script on USB/Synology installs: Homebrew, Bash 5.x + ble.sh, Ghostty (Catppuccin Mocha), Starship, modern CLI tools, Claude Code.

**SMB speed:** ~285 MB/s writes (better than Linux!) via `/etc/nsmb.conf` multichannel config.

## Hackintosh EFI Notes

### AMD System (9950X3D)
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

Auto-detects Synology when mounted, falls back to `~/Documents/fire-backups`. One backup each for Firefox and FireDragon.

**Restore commands** (Firefox must be installed first):
```bash
# Firefox
echo "y" | bash "/mnt/synology/WEB Scripts/Scripts/Fire Backup/fire-backup.sh" restore firefox-backup-* -b firefox

# FireDragon
echo "y" | bash "/mnt/synology/WEB Scripts/Scripts/Fire Backup/fire-backup.sh" restore firedragon-backup-* -b firedragon
```

**What's restored:** bookmarks, extensions, settings, passwords (encrypted), history, cookies, userChrome.css, containers.

## Quick Commands

**"copy build 3 to documents":**
```bash
cp "/mnt/synology/WEB Scripts/Scripts/CachyOS Kernel/build3.sh" "/mnt/synology/WEB Scripts/Scripts/CachyOS Kernel/modprobed-combined.db" ~/Documents/
```

## Reminders
- **COSMIC Desktop**: Considering Cosmic.sh script. Dracula theme exists on cosmic-themes.org
- **Mokka symbolic icons**: Consider overlaying Dracula white icons onto Catppuccin

## Session Notes
- **Session 36**: Fixed package verification false positives + fire-backup.sh fixes. Pacman race condition fixed by trusting exit code. fire-backup.sh: added Synology auto-detect, fixed glob with spaces in path.
- **Session 35**: bash.sh - Claude Code install, repo setup, Finder symlinks
- **Session 34**: macOS Tahoe terminal setup, SMB ~285 MB/s
- **Session 33**: Firefox userChrome.css Dracula theme
- **Session 22**: macOS.sh brought to Dracula.sh parity (Fish → Bash + ble.sh)
- **Session 21**: Major repo reorganization (Dracula/assets/, Shared/, macOS/)
