# CLAUDE.md

This file provides guidance to Claude Code when working with this repository.

## Current Session Status
**Session 20 - Fresh Mokka install + Firefox theming**

### Completed this session:
- **Fresh Mokka.sh install** verified working
- **Notification timeout** changed from 3000ms to 2000ms (plasmanotifyrc)
- **Firefox/FireDragon selection color** - mauve (#cba6f7) via userContent.css
- **CanvasBlocker settings** updated with recommendations (protectNavigator, protectWindow, WebGL spoofing, storePersistentRnd)
- **Dark Reader settings** converted from Dracula to Catppuccin Mocha colors

## Steve's Preferences - READ FIRST
- **Bash with ble.sh** - provides Fish-like experience (autosuggestions, syntax highlighting)
- POSIX compatible - scripts from anywhere just work
- Simple and effective, no over-engineering
- Ask questions one at a time
- Results matter, keep solutions simple
- Hates typing - keep commands short
- Script output must be themed - use color variables, no ugly raw output
- **NEVER put .sh scripts in the repo** - scripts live on USB/Synology only, not GitHub

## Repository Overview

**DRACULARCH** - Automated Arch Linux setup scripts with desktop theming.

| Script | Desktop | Theme | Shell |
|--------|---------|-------|-------|
| Dracula.sh | GNOME | Dracula | Bash + ble.sh |
| Mokka.sh | KDE Plasma 6 | Catppuccin Mocha | Bash + ble.sh |

**GitHub:** github.com/svan71/DRACULARCH
**Local repo:** ~/Dracularch/
**USB:** /run/media/steve/ARCH_202512

**Important:** Scripts run from USB during install. Repo holds backups/configs that sync to GitHub.

## File Locations & Sync Rules

| Location | Purpose |
|----------|---------|
| `~/CLAUDE.md` | Active instructions (live) |
| `~/.claude/settings.json` | Permissions (live) |
| `~/Dracularch/Claude/` | Repo (CLAUDE.md + settings.json only) |
| `/run/media/steve/ARCH_202512/` | USB (current scripts + config backups) |
| `/mnt/synology/WEB Scripts/Arch/Claude/USB Files/` | Synology (previous working backups) |

**"sync" means:**
```
~/CLAUDE.md → ~/Dracularch/Claude/CLAUDE.md → git push
~/.claude/settings.json → ~/Dracularch/Claude/settings.json → git push
Then copy both to USB: /run/media/steve/ARCH_202512/
```

**Script backups (.sh files):**
- USB = current working version
- Synology = previous working version (only update when explicitly asked)

## CachyOS Kernel
Optional at install (choice 2). Script downloads tar.xz files from GitHub repo root:
- `Cachyos Optimized Kernel.tar.xz`
- `Cachyos Optimized Headers.tar.xz`

Package names changed from `linux-cachyos-lto` to `linux-cachyos` (LTO is now default).

**Kernel requirements:**
- CONFIG_TCP_CONG_BBR
- CONFIG_NET_SCH_CAKE
- CONFIG_IP_NF_FILTER / CONFIG_IP_NF_IPTABLES (for UFW)
- CONFIG_CIFS (for direct SMB mounts)

## Hardware Context
- Intel 14900K, 32GB RAM, Samsung Odyssey G8 4K@240Hz
- AMD 9950X3D, 64GB RAM
- Mac M4 Pro, 24GB RAM
- All NVMe storage, Bash with ble.sh

## Structure
```
DRACULARCH/
├── Dracula.sh                          # GNOME + Dracula theme installer
├── Mokka.sh                            # KDE Plasma + Catppuccin Mocha installer
├── Cachyos Optimized Kernel.tar.xz     # CachyOS kernel (downloaded by script)
├── Cachyos Optimized Headers.tar.xz    # CachyOS headers (downloaded by script)
├── CLAUDE.md                           # This file (copied to ~/ during install)
├── settings.json                       # Claude permissions (copied to ~/.claude/)
├── Dracula/                            # Dracula backup configs
│   ├── configs/
│   │   ├── terminal/
│   │   │   └── bash/   # bashrc, blerc, bash_history
│   │   └── zoxide/
│   ├── themes/
│   ├── icons/
│   └── wallpapers/
└── Mokka/              # Mokka backup configs
    ├── configs/
    │   ├── plasma/     # 22 config files (appletsrc, plasmashellrc, kwinrc, etc.)
    │   ├── state/      # dolphinstaterc (Plasma 6 panel state)
    │   ├── dolphin-layout/
    │   ├── terminal/   # bash, starship, fastfetch, ghostty
    │   ├── gtk-3.0/
    │   ├── gtk-4.0/
    │   ├── samba/
    │   └── sddm/
    ├── themes/
    │   ├── Mokka-lookandfeel/
    │   ├── CatppuccinMocha-Classic/
    │   ├── Kvantum-Mokka/
    │   ├── color-schemes/
    │   ├── desktoptheme-Mokka/
    │   ├── sddm-Catppuccin-Mocha-Mauve/
    │   └── kate/Mokka.theme
    ├── icons/hicolor/  # FireDragon custom icons
    ├── firedragon-branding/
    ├── wallpapers/garuda-mokka/
    └── panel-colorizer-presets/
```

## Why Bash + ble.sh
- ble.sh provides Fish-like UX (autosuggestions, syntax highlighting)
- POSIX compatible - copy any bash snippet, it just works
- One shell to maintain across both scripts
- Starship handles the prompt styling

## Critical Knowledge - Don't Break These

### Dracula.sh (GNOME)
- **blur-my-shell**: Must enable LAST with 5-second delay (causes crash otherwise)
- **AUR validation**: Use `yay -Q` for AUR packages, `pacman -Qi` for pacman
- **UFW**: Needs `systemctl enable ufw` (not just `ufw --force enable`)
- **Autostart cleanup**: Delete files BEFORE logout to avoid race condition

### Mokka.sh (KDE)
- **TahoeLauncher**: Path must be `/usr/share/plasma/plasmoids/TahoeLauncher/`
- **Dolphin state**: Plasma 6 uses `~/.local/state/dolphinstaterc`
- **Display scaling**: Remove `ScreenScaleFactors=`, use `kscreen-doctor output.1.scale.1.9`
- **Terminal**: Ghostty only (Konsole removed)
- **Shell**: Bash + ble.sh (Fish completely removed)

### Both Scripts
- **Printer**: Use `dnssd://` URIs, mDNS discovery, no hardcoded IPs
- **AMD GPP0 fix**: Auto-creates systemd service to disable GPP0 wakeup (prevents immediate wake after suspend)
- **Packages**: bash-completion, thefuck, tldr included
- **Carapace**: Configured for Bash with `bash-ble` mode (not `bash`)
- **Ghostty**: shell-integration = bash, command = /usr/bin/bash

## SMB/CIFS Direct Mount Setup

### Why Direct Mount?
- **GVFS (smb://)**: ~193 MB/s write, ~157 MB/s read
- **Direct CIFS mount**: ~230 MB/s write, ~260 MB/s read (+20-65% faster)

### Implementation
**Credentials file:** `~/.smbcredentials` (chmod 600)
```
username=steve
password=<synology_password>
```

**fstab entries:**
```
//synology.local/external /mnt/synology cifs credentials=/home/steve/.smbcredentials,vers=3.1.1,multichannel,max_channels=4,rsize=4194304,wsize=4194304,uid=1000,gid=1000,_netdev,nofail 0 0
//synology.local/plex /mnt/plex cifs credentials=/home/steve/.smbcredentials,vers=3.1.1,multichannel,max_channels=4,rsize=4194304,wsize=4194304,uid=1000,gid=1000,_netdev,nofail 0 0
```

## Unified Bookmarks (Both Scripts)

| # | Bookmark | Path |
|---|----------|------|
| 1 | Arch | `/mnt/synology/WEB Scripts/Arch` |
| 2 | Documents | `~/Documents` |
| 3 | Downloads | `~/Downloads` |
| 4 | Pictures | `~/Pictures` |
| 5 | Plex | `/mnt/plex` |
| 6 | Music | `~/Music` |
| 7 | Videos | `~/Videos` |
| 8 | Synology | `smb://synology.local/` |
| 9 | Web Scripts | `/mnt/synology/WEB Scripts` |

## SSH Workflow for Claude Code (Fresh Installs)

Claude Code requires browser OAuth. Use SSH from Mac for copy/paste:

```bash
# On Arch TTY after archinstall
sudo pacman -S openssh
sudo systemctl start sshd
ip addr | grep 192
```

```bash
# From Mac Terminal
ssh steve@192.168.x.x
export TERM=xterm-256color  # Fix Ghostty terminal type
curl -fsSL https://claude.ai/install.sh | bash
export PATH="$HOME/.local/bin:$PATH"
claude
```

Select subscription → Copy OAuth URL → Paste in Mac browser → Get code → Paste back.
Auth stored in `~/.claude/` until next reinstall. Under 2 minutes.

**Tip**: Add `openssh` to archinstall package selection so it's ready immediately.

## Common Debugging Commands
```bash
# Check autostart cleanup worked
ls -la ~/.config/autostart/consolidated-setup.desktop ~/.config/scripts/consolidated-autostart.sh 2>&1

# Check UFW
sudo ufw status verbose
systemctl is-enabled ufw

# Check GNOME extensions
gnome-extensions list --enabled

# Check printer
lpstat -v

# Check active icon theme (Mokka)
kreadconfig6 --group Icons --key Theme

# Check ble.sh (use bash -c, not raw [[)
bash -c '[[ -f /usr/share/blesh/ble.sh ]] && echo "OK" || echo "Missing"'
```

## Claude Code Notes
- **ble.sh check**: Use `bash -c '[[ ... ]]'` not raw `[[ ]]` in Bash tool (runs in sh by default)
- **"setup repo"**: Copy ssh-backup from Synology to ~/Documents, then run setup-repo.sh:
  ```bash
  cp -r "/mnt/synology/WEB Scripts/Scripts/Setup Repo/ssh-backup" ~/Documents/
  bash "/mnt/synology/WEB Scripts/Scripts/Setup Repo/setup-repo.sh" setup
  ```

## Printer Setup
- Uses `dnssd://` URIs for GNOME integration (avoids dual printer display)
- Name printer to match mDNS discovery name
- Canon TR8600: `cnijfilter2` AUR package for scanning support
- UFW allows port 631 for CUPS

## Reminders
- **Windows 11 install**: Run [RemoveWindowsAI](https://github.com/zoicware/RemoveWindowsAI) to strip Copilot, Recall, and AI bloat. Use backup mode. PowerShell 5.1 only.

## Session History
- Session 20: Fresh Mokka install, Firefox/FireDragon theming (selection color, Dark Reader, CanvasBlocker)
- Session 19: Mokka.sh Fish → Bash + ble.sh, Konsole removed
- Session 18: Dracula.sh fresh install verified ✅ (all optimizations working)
- Session 17: CIFS kernel verified + Plex mount + unified bookmarks
- Session 16: UFW activation fix + CIFS module added to modprobed-combined.db
- Session 15: CachyOS kernel naming change + AMD GPP0 fix
- Session 14: Carapace bash-ble fix for ble.sh compatibility
