# CLAUDE.md

This file provides guidance to Claude Code when working with this repository.

## Steve's Preferences - READ FIRST
- **Bash with ble.sh** - provides Fish-like experience (autosuggestions, syntax highlighting)
- POSIX compatible - scripts from anywhere just work
- Simple and effective, no over-engineering
- Ask questions one at a time
- Results matter, keep solutions simple
- Hates typing - keep commands short
- Script output must be themed - use color variables, no ugly raw output

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

## CachyOS LTO Kernel
Optional at install (choice 2). Script downloads tar.xz files from GitHub repo root:
- `Cachyos Optimized Kernel.tar.xz`
- `Cachyos Optimized Headers.tar.xz`

The `Cachyos Optimized Kernel/` folder is redundant - delete it.

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
├── Cachyos Optimized Kernel.tar.xz     # CachyOS LTO kernel (downloaded by script)
├── Cachyos Optimized Headers.tar.xz    # CachyOS LTO headers (downloaded by script)
├── Dracula/                            # Dracula backup configs
│   ├── configs/
│   │   ├── terminal/
│   │   │   ├── bash/   # bash_history (curated)
│   │   │   └── fish/   # fish_history (legacy)
│   │   └── zoxide/
│   ├── themes/
│   ├── icons/
│   └── wallpapers/
└── Mokka/              # Mokka backup configs
    ├── configs/
    │   ├── plasma/     # 23 config files (appletsrc, plasmashellrc, kwinrc, etc.)
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

### Both Scripts
- **Printer**: Use `dnssd://` URIs, mDNS discovery, no hardcoded IPs
- **CachyOS kernel needs**: CONFIG_TCP_CONG_BBR, CONFIG_NET_SCH_CAKE, CONFIG_IP_NF_FILTER
- **Packages**: bash-completion, thefuck, tldr included
- **Carapace**: Configured for Bash
- **Ghostty**: shell-integration set to "detect"

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

## Common Tasks

### Check autostart cleanup worked
```bash
ls -la ~/.config/autostart/consolidated-setup.desktop ~/.config/scripts/consolidated-autostart.sh 2>&1
```

### Check UFW
```bash
sudo ufw status verbose
systemctl is-enabled ufw
```

### Check GNOME extensions
```bash
gnome-extensions list --enabled
```

### Check printer
```bash
lpstat -v
```

## Notes File
For full details, history, and context: `notes.md`

**When user says "read notes":**
1. Try USB first: `/run/media/steve/ARCH_202512/notes.md`
2. If not found, fall back to Synology: `/mnt/synology/WEB Scripts/Arch/USB Files/notes.md`

Do NOT check the repo (`~/Dracularch/`) - notes.md lives on USB/Synology only.
