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
**USB:** `/run/media/steve/ARCH_*` (name changes monthly)

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
│   └── assets/       # 10 tar.xz archives
├── Mokka/
│   ├── configs/      # plasma, terminal, gtk, sddm, samba
│   ├── packages/     # kwin-effects-forceblur package
│   ├── themes/       # Kvantum, color-schemes, sddm, kate
│   ├── icons/        # Custom icons
│   └── wallpapers/
├── macOS/            # Mac-related files
└── Archive/          # Deprecated configs
```

## File Locations & Sync

| Location | Purpose |
|----------|---------|
| `~/CLAUDE.md` | Active instructions (live) |
| `~/.claude/settings.json` | Permissions (live) |
| `~/Dracularch/Claude/` | Repo copy → git push |
| `/run/media/steve/ARCH_*/` | USB (scripts) |
| `/mnt/synology/WEB Scripts/Arch/` | Synology backups |

**USB detection & mount:**
```bash
USB_PATH=$(find /run/media/steve -maxdepth 1 -name "ARCH_*" -type d 2>/dev/null | head -1)

# If not found (common on Plasma), mount manually:
udisksctl mount -b /dev/sda1
# Or click the drive in Dolphin
```

**"sync" means:** Copy to repo → git push → copy to USB

## Fresh Install

**Setup repo with SSH:**
```bash
cp -r "/mnt/synology/WEB Scripts/Scripts/Setup Repo/ssh-backup" ~/Documents/
bash "/mnt/synology/WEB Scripts/Scripts/Setup Repo/setup-repo.sh" setup
```

## Critical Knowledge - Don't Break These

### Package Installation (All Scripts)
```bash
# Use yes "" to auto-accept provider prompts, don't capture output
yes "" | sudo pacman -S --noconfirm --needed --overwrite '*' "${packages[@]}" >>"$LOGFILE" 2>&1
```
- `yes "" |` feeds empty lines for default provider choices
- Don't use `$()` subshell capture - breaks the pipe
- Verify packages at END, not during install

### Dracula.sh (GNOME)
- **blur-my-shell**: Enable LAST with 5-second delay (crashes otherwise)
- **UFW**: Needs `systemctl enable ufw` (not just `ufw --force enable`)

### Mokka.sh (KDE)

**Sacred 14 Plasma Configs** - only restore these:
1. `plasma-org.kde.plasma.desktop-appletsrc` - Panel/widget layout
2. `plasmashellrc` - Plasma shell settings
3. `kdeglobals` - Global KDE settings
4. `kwinrc` - Window manager, effects
5. `kded5rc` / `kded6rc` - KDE daemons
6. `kcminputrc` - Input settings
7. `kscreenlockerrc` - Lock screen
8. `baloofilerc` - File indexing
9. `plasmanotifyrc` - Notifications
10. `konsolerc` - Terminal
11. `dolphinrc` - File manager
12. `arkrc` - Archive manager
13. `kwinoutputconfig.json` - Display resolution/scaling (4K 200%)

**Forceblur** (working blur solution):
- Package: `Mokka/packages/kwin-effects-forceblur-1.5.0-1.9-x86_64.pkg.tar.zst`
- Mokka.sh downloads from GitHub raw URL during install
- kwinrc: `blurEnabled=false` + `forceblurEnabled=true`
- Config section is `[Effect-blurplus]` (not `[Effect-forceblur]`)
- **Critical**: `NoiseStrength=0` for clean logout screen

**Display scaling**: Use `kwinoutputconfig.json`, not kscreen-doctor

**Dolphin state**: Plasma 6 uses `~/.local/state/dolphinstaterc`

## System Info

### Hardware
- **AMD**: 7950X3D, 64GB RAM, Gigabyte B650 Aorus Elite AX
- **Intel**: 14900K, 32GB RAM, Gigabyte Z790 Aorus Master
- **Monitor**: Samsung Odyssey G8 4K 240Hz
- **Display**: 4K at 200% scaling, fonts at 11pt

## Firefox/FireDragon Restore

```bash
# List backups
ls "/mnt/synology/WEB Scripts/Scripts/Fire Backup/fire-backups/"

# Restore (need exact name, not glob)
echo "y" | bash "/mnt/synology/WEB Scripts/Scripts/Fire Backup/fire-backup.sh" restore firefox-backup-2025-12-22_07-12-23 -b firefox
```

## Hackintosh Notes

Both systems: OpenCore 1.0.6, MacPro7,1, NootRX for AMD GPUs
- **AMD** (7950X3D): AppleIntelI210Ethernet for I225-V 2.5GbE
- **Intel** (14900K): CPUID as Comet Lake, CpuTopologyRebuild, LucyRTL8125Ethernet

**SMB speed:** ~285 MB/s via `/etc/nsmb.conf` multichannel

## COSMIC Desktop (Future)

- Theme: Custom black/blue/white (NOT Dracula), consider Catppuccin Mocha base
- Uses `.ron` files for theming (not GTK/dconf)
- ~60% of Dracula.sh transfers directly (packages, services, CLI tools, shell setup)

## Quick Reference

**Synology mount:**
```bash
//192.168.1.101/Media /mnt/synology cifs credentials=/home/$USER/.smb_credentials,uid=1000,gid=1000,iocharset=utf8 0 0
```

**Copy kernel build script:**
```bash
cp "/mnt/synology/WEB Scripts/Scripts/CachyOS Kernel/build3.sh" ~/Documents/
```
