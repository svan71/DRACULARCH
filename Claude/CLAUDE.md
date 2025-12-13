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

## Reminders
- **Windows 11**: Run [RemoveWindowsAI](https://github.com/zoicware/RemoveWindowsAI) - strips Copilot, Recall. Use backup mode, PowerShell 5.1.

## Session History
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
