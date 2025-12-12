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
| `~/Dracularch/Claude/` | Repo copy → git push |
| `/run/media/steve/ARCH_202512/` | USB (scripts + configs) |
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
- **Display scaling**: Remove `ScreenScaleFactors=`, use `kscreen-doctor output.1.scale.1.9`
- **Logging functions**: Guard with `[[ -n "$LOGFILE" && -f "$LOGFILE" ]]` before tee

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

## SSH Workflow (Fresh Installs)

Claude Code needs browser OAuth. SSH from Mac:

```bash
# Arch TTY: sudo pacman -S openssh && sudo systemctl start sshd && ip addr | grep 192
# Mac: ssh steve@192.168.x.x
export TERM=xterm-256color
curl -fsSL https://claude.ai/install.sh | bash && export PATH="$HOME/.local/bin:$PATH" && claude
```

**Tip:** Add `openssh` to archinstall packages.

## Claude Code Notes
- **USB check**: Use full path `ls /run/media/steve/ARCH_202512/` (parent dir fails)
- **ble.sh check**: Use `bash -c '[[ ... ]]'` (Bash tool runs sh)
- **Setup repo**: `cp -r "/mnt/synology/WEB Scripts/Scripts/Setup Repo/ssh-backup" ~/Documents/ && bash "/mnt/synology/WEB Scripts/Scripts/Setup Repo/setup-repo.sh" setup`

## Hardware
- Intel 14900K, 32GB, Samsung Odyssey G8 4K@240Hz
- AMD 9950X3D, 64GB
- Mac M4 Pro, 24GB

## Reminders
- **Windows 11**: Run [RemoveWindowsAI](https://github.com/zoicware/RemoveWindowsAI) - strips Copilot, Recall. Use backup mode, PowerShell 5.1.

## Session History
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
