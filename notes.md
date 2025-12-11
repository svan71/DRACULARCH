# Claude Context for DRACULARCH
Last updated: 2025-12-10 (session 17 - CIFS kernel verified + Plex mount + bookmarks)

## CURRENT SESSION STATUS
**Session 17 - CIFS kernel working + Plex CIFS mount + unified bookmarks**

### What was changed:

#### 1. CachyOS Kernel Rebuild - VERIFIED WORKING
CIFS module now loads correctly after kernel rebuild with `cifs` in modprobed-combined.db.

```bash
lsmod | grep cifs  # Shows cifs module loaded with 3 connections
```

#### 2. Added Plex CIFS Mount
Added second CIFS mount for fast movie transfers (~230MB/s vs ~157MB/s GVFS).

**fstab entry added:**
```
//synology.local/plex /mnt/plex cifs credentials=/home/steve/.smbcredentials,vers=3.1.1,multichannel,max_channels=4,rsize=4194304,wsize=4194304,uid=1000,gid=1000,_netdev,nofail 0 0
```

#### 3. Unified Bookmarks (Nautilus + Dolphin)
Both file managers now use same bookmark order with CIFS paths:

| Bookmark | Type | Path |
|----------|------|------|
| Arch | CIFS | `/mnt/synology/WEB Scripts/Arch` |
| Documents | Local | `~/Documents` |
| Downloads | Local | `~/Downloads` |
| Pictures | Local | `~/Pictures` |
| Plex | CIFS | `/mnt/plex` |
| Music | Local | `~/Music` |
| Videos | Local | `~/Videos` |
| Synology | GVFS | `smb://synology.local/` (browse all shares) |
| Web Scripts | CIFS | `/mnt/synology/WEB Scripts` |

**Files updated:**
- [x] `/etc/fstab` - Added plex mount
- [x] `~/.config/gtk-3.0/bookmarks` - Nautilus bookmarks
- [x] `~/Dracularch/Mokka/configs/dolphin/user-places.xbel` - Dolphin bookmarks

### Tested:
- [x] CIFS module loading
- [x] `/mnt/synology` mount working
- [x] `/mnt/plex` mount working
- [x] Nautilus bookmarks updated

### Previous sessions summary:
- Session 16: UFW activation fix + CIFS module added to modprobed-combined.db
- Session 15: CachyOS kernel naming change + AMD GPP0 fix
- Session 14: Carapace bash-ble fix for ble.sh compatibility

### Next steps:
1. Test Dracula.sh on fresh install (UFW fix)
2. Update Mokka.sh with carapace bash-ble fix (still TODO)
3. Update Mokka.sh to use Bash+ble.sh (currently Fish)
4. Add CIFS mount setup to both scripts (fstab + credentials)

## File Sync Rules

| Location | Files | When to update |
|----------|-------|----------------|
| `~/CLAUDE.md` | CLAUDE.md | Always current |
| `~/Dracularch/Claude/` | CLAUDE.md | Sync with ~ |
| USB `/run/media/steve/ARCH_202512/` | CLAUDE.md, notes.md | Always current |
| Synology `.../Arch/Claude/USB Files/` | CLAUDE.md, notes.md | Only on "update synology" |

**Script locations** (Dracula.sh, Mokka.sh):
1. Check USB first: `/run/media/steve/ARCH_202512/`
2. Fallback: `/mnt/synology/WEB Scripts/Arch/Claude/USB Files/`

## Steve's Preferences
- Bash with ble.sh (switched from Fish - session 8)
- Simple and effective, no over-engineering
- Ask questions one at a time
- Results matter, how we get there should be simple if able
- Hates typing - keep commands short unless he can copy and paste
- Script output must be themed - use color variables, no ugly raw output in his babies

## Hardware
- **Intel system**: 14900K, 32GB RAM, Samsung Odyssey G8 4K@240Hz
- **AMD system**: 9950X3D, 64GB RAM
- **Mac**: M4 Pro, 24GB RAM (MacBook Pro 16-inch)
- All use Bash with ble.sh, NVMe storage

## GitHub Repository
- **URL**: github.com/svan71/DRACULARCH
- **Clone**: `git@github.com:svan71/DRACULARCH.git`
- **Local path**: `~/Dracularch/`

## Repository Structure
```
DRACULARCH/
├── Dracula.sh          # GNOME + Dracula theme installer
├── Mokka.sh            # KDE Plasma + Catppuccin Mocha installer
├── Claude/             # Claude Code context files (repo backup)
│   ├── CLAUDE.md       # Project instructions
│   └── notes.md        # Session notes and context
├── Dracula/            # Dracula backup configs
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

## USB vs Repository

**USB** (`/run/media/steve/ARCH_202512`) - Working scripts that run during install:
- `Dracula.sh` - GNOME with Dracula theme
- `Mokka.sh` - KDE Plasma with Catppuccin Mocha

**GitHub Repo** (`~/Dracularch/`) - Backup configs, themes, and resources:
- `Dracula/` and `Mokka/` folders with configs
- `Cachyos Optimized Kernel.tar.xz` - CachyOS kernel package
- `Cachyos Optimized Headers.tar.xz` - CachyOS headers package

Scripts on USB sync to repo, repo pushes to GitHub.

## CachyOS Kernel (Optional)

Script prompts for kernel choice:
1. **Optimize existing Linux Zen** (default) - Just applies sysctl tuning
2. **Install Linux CachyOS** - Downloads and installs from GitHub

The kernel/headers tar.xz files at repo root are downloaded by Dracula.sh when option 2 is selected:
```
https://raw.githubusercontent.com/svan71/DRACULARCH/refs/heads/main/Cachyos%20Optimized%20Kernel.tar.xz
https://raw.githubusercontent.com/svan71/DRACULARCH/refs/heads/main/Cachyos%20Optimized%20Headers.tar.xz
```

**Note:** The `Cachyos Optimized Kernel/` folder is redundant - script uses tar.xz files only.

## Critical Fixes - VERIFIED WORKING (2025-12-08)

### Both Scripts
- **Claude Code integration**: Installs during Phase 5 (Applications) - only for user "steve"
- **Printer auto-detection**: Uses dnssd:// URIs, mDNS discovery, no hardcoded IPs
- **UFW persistence**: `systemctl enable ufw` (not just `ufw --force enable`) ✅ VERIFIED
- **UFW ports**: SSH, 5353/udp (mDNS), 631 (CUPS from local network)
- **Network optimizations**: 2.5Gb settings (26MB buffers, tcp_rmem/wmem)
- **Removed packages**: tmux, strace, nmap, mtr, pv, irqbalance, ananicy-cpp, preload
- **Removed dead code**: irqbalance service check (package not installed)

### Dracula.sh (GNOME) Specific - ALL VERIFIED
- **blur-my-shell crash**: Enable LAST with 5-second delay in autostart ✅ VERIFIED
- **False AUR errors**: Uses `yay -Q` for AUR, `pacman -Qi` for pacman ✅ VERIFIED
- **GDM scaling**: Plymouth + multiple connector entries working ✅ VERIFIED
- **nmb.service**: Enabled for network browsing ✅ VERIFIED
- **Autostart cleanup**: Deletes files BEFORE logout (no race condition) ✅ VERIFIED
- **Nautilus notifications**: Disabled via gsettings ✅ VERIFIED

### Mokka.sh (KDE Plasma) Specific
- **TahoeLauncher**: Directory must be `/usr/share/plasma/plasmoids/TahoeLauncher/` (matches plugin ID)
- **Dolphin panels**: State stored in `~/.local/state/dolphinstaterc` (Plasma 6), not ~/.local/share
- **Display scaling**: Remove `ScreenScaleFactors=` from plasmashellrc, use `kscreen-doctor output.1.scale.1.9`
- **Shell**: Still uses Fish (TODO: switch to Bash like Dracula.sh)
- **Kvantum/Plasma themes**: Applied via autostart script, not during install
- **Inter font removal**: Garuda uses Noto Sans, not Inter
- **Cursor theme fallback**: Creates `~/.icons/default/index.theme`
- **btop theme**: Downloads from GitHub to `~/.config/btop/themes/`
- **zoxide**: Config path is `Mokka/configs/zoxide/db.zo`

## SSH Workflow for TTY Claude Code Auth

Claude Code requires browser OAuth - can't be bypassed with API keys alone. Use SSH from Mac for copy/paste capability.

### After archinstall, before running Mokka/Dracula:

```bash
# On Arch TTY - install and start SSH
sudo pacman -S openssh
sudo systemctl start sshd
ip addr | grep 192
```

### From Mac Terminal:

```zsh
ssh steve@192.168.x.x
```

### In SSH session:

```bash
# Fix terminal if needed
export TERM=xterm-256color

# Install Claude Code
curl -fsSL https://claude.ai/install.sh | bash
export PATH="$HOME/.local/bin:$PATH"

# Run and authenticate
claude
```

Select "Claude.ai account with subscription" → Copy OAuth URL → Paste in Mac browser → Get code → Paste back.

### Benefits:
- Full copy/paste (no typing 30-char codes at TTY)
- Auth stored in `~/.claude/` until next reinstall
- Under 2 minutes total

### Note:
Consider adding `openssh` to archinstall package selection so it's ready immediately after first boot.

## Mokka Autostart Script Phases
1. Apply Kvantum theme
2. Apply Plasma look-and-feel
3. Fix display scaling (remove ScreenScaleFactors, kscreen-doctor 1.9)
4. Reconfigure KWin
5. Set default browser
6. Apply wallpaper
7. Apply color scheme
8. Clean up autostart files

## Dracula Autostart Script Phases
1. Initialize logging
2. Set non-shell themes (gtk, icons, cursors)
3. Enable extensions (blur-my-shell LAST with delay)
4. Set app grid layout
5. Apply shell theme
6. Cleanup and auto-logout

## Printer Setup (Both Scripts)
- Uses `dnssd://` URIs for GNOME integration (avoids dual printer display)
- Name printer to match mDNS discovery name
- Canon TR8600: `cnijfilter2` AUR package for scanning support
- Falls back to IPP Everywhere for non-Canon printers
- UFW allows port 631 for CUPS

## Unified Bookmarks (Both Scripts)
Same order for Nautilus (GNOME) and Dolphin (KDE):

| # | Bookmark | Type | Path |
|---|----------|------|------|
| 1 | Arch | CIFS | `/mnt/synology/WEB Scripts/Arch` |
| 2 | Documents | Local | `~/Documents` |
| 3 | Downloads | Local | `~/Downloads` |
| 4 | Pictures | Local | `~/Pictures` |
| 5 | Plex | CIFS | `/mnt/plex` |
| 6 | Music | Local | `~/Music` |
| 7 | Videos | Local | `~/Videos` |
| 8 | Synology | GVFS | `smb://synology.local/` (browse all shares) |
| 9 | Web Scripts | CIFS | `/mnt/synology/WEB Scripts` |

## CachyOS Kernel Requirements
- CONFIG_TCP_CONG_BBR
- CONFIG_NET_SCH_CAKE
- CONFIG_IP_NF_FILTER / CONFIG_IP_NF_IPTABLES (for UFW)
- CONFIG_CIFS (for direct SMB mounts - added session 5)

## SMB/CIFS Direct Mount Setup (Session 5)

### Why Direct Mount?
- **GVFS (smb://)**: ~193 MB/s write, ~157 MB/s read
- **Direct CIFS mount**: ~230 MB/s write, ~260 MB/s read (+20-65% faster)
- Multichannel support (multiple TCP streams)
- Lower CPU overhead

### Current Implementation
Uses fstab with credentials file for automatic mounting at boot.

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

**Mount points:**
- `/mnt/synology` → external share (Arch, Web Scripts)
- `/mnt/plex` → plex share (movie transfers)

**Bookmarks:** Point to `/mnt/synology/...` and `/mnt/plex` instead of `smb://...`

### REVERT TO GVFS (if needed)

**Step 1: Remove fstab entry**
```bash
sudo sed -i '/synology.local/d' /etc/fstab
sudo umount /mnt/synology
```

**Step 2: Restore GVFS bookmarks**

For Nautilus (GNOME):
```bash
cat > ~/.config/gtk-3.0/bookmarks << 'EOF'
smb://synology.local/external/WEB%20Scripts/Arch Arch
file:///home/steve/Documents Documents
file:///home/steve/Music Music
file:///home/steve/Pictures Pictures
file:///home/steve/Videos Videos
file:///home/steve/Downloads Downloads
smb://synology.local/ Synology
smb://synology.local/external/WEB%20Scripts WEB Scripts
EOF
```

For Dolphin (KDE): Restore `~/.local/share/user-places.xbel` from mokka backup.

**Step 3: Remove credentials file (optional)**
```bash
rm ~/.smbcredentials
```

### Synology Settings (Optimized)
- SMB multichannel: ENABLED
- Max protocol: SMB3
- Async I/O read: ENABLED
- Min protocol: SMB2

## xdg-desktop-portal Config (Mokka)
Must set KDE as default portal for ScreenCast and Screenshot.

## Common Debugging Commands
```bash
# Check active icon theme (Mokka)
kreadconfig6 --group Icons --key Theme

# Check GNOME extensions
gnome-extensions list --enabled

# Check printer setup
lpstat -v
lpinfo -v | grep -i canon
lpstat -p -d

# Check UFW status
sudo ufw status verbose

# Check systemd service
systemctl status <service>
journalctl -u <service> -b

# Check autostart cleanup worked
ls -la ~/.config/autostart/consolidated-setup.desktop ~/.config/scripts/consolidated-autostart.sh 2>&1
```

## Claude Code Settings
**Location:** `~/.claude/settings.json`
**Pointer file:** `~/.claude/notes.md` (points to USB locations for notes.md and CLAUDE.md)
**Backup:** Synology `WEB Scripts/Arch/USB Files/` - sync with `sync` command

**Recommended permissions (minimal prompts):**
```json
{
  "permissions": {
    "allow": [
      "Read(**)",
      "Edit(**)",
      "Write(**)",
      "Bash(*)",
      "WebSearch",
      "WebFetch"
    ]
  }
}
```

**Or launch with:** `claude --dangerously-skip-permissions`

## Workflow: Fresh Install
1. Boot Arch ISO, install with archinstall (include `openssh` in packages)
2. Reboot, start SSH: `sudo systemctl start sshd && ip addr`
3. SSH from Mac: `ssh steve@<ip>`
4. Install Claude Code, complete OAuth via copy/paste
5. Mount USB: `sudo mount /dev/sdb1 /mnt/usb && cd /mnt/usb`
6. Run `./Mokka.sh` or `./Dracula.sh`
7. Reboot into desktop - Claude Code already authenticated

## macOS-Style Fonts (Optional for Dracula)
Apple San Francisco fonts with macOS-style rendering.

**Fonts installed:**
- **SF Pro Display** - UI/interface font
- **SF Pro Text** - document font
- **SFMono Nerd Font** - terminal (AUR: `nerd-fonts-sf-mono`)

**Source files:** `smb://synology.local/external/WEB Scripts/Arch/Tahoe/San Francisco Pro Fonts/`

**Files to backup to repo:**
- `~/.local/share/fonts/SF-Pro/` → `dracula/configs/fonts/SF-Pro/`
- `~/.config/fontconfig/fonts.conf` → `dracula/configs/fontconfig/fonts.conf`
- `~/.config/ghostty/config` → `dracula/configs/terminal/ghostty/config`

**GNOME font settings (gsettings):**
```bash
gsettings set org.gnome.desktop.interface font-name 'SF Pro Display 11'
gsettings set org.gnome.desktop.interface document-font-name 'SF Pro Text 11'
gsettings set org.gnome.desktop.interface monospace-font-name 'SFMono Nerd Font 10'
gsettings set org.gnome.desktop.wm.preferences titlebar-font 'SF Pro Display Bold 11'
```

**fontconfig (macOS-style rendering):**
- `hintstyle: hintslight` (closest to macOS no-hinting)
- `lcdfilter: lcdlight` (smoother than lcddefault)
- `rgba: rgb` (subpixel for LCD)
- `autohint: false`

**To add to Dracula.sh later:**
1. Copy SF-Pro fonts from repo to `~/.local/share/fonts/`
2. Install `nerd-fonts-sf-mono` from AUR
3. Copy fontconfig/fonts.conf
4. Apply gsettings for fonts
5. Update Ghostty config with SFMono Nerd Font
