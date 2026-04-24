---
name: DRACULARCH Project
description: Core facts about the DRACULARCH repo and its structure
type: project
originSessionId: d9459482-389f-4ebb-a2df-80c37a8e046d
---
Automated Arch Linux setup scripts with desktop theming.

- GitHub: github.com/svan71/DRACULARCH
- Local repo: ~/Dracularch/
- USB label: ARCH_YYYYMM (changes monthly, e.g. ARCH_202604)
  - Linux: /run/media/steve/ARCH_YYYYMM/
  - macOS: /Volumes/ARCH_YYYYMM/
- Synology: /mnt/synology/WEB Scripts/Arch/

**Scripts:**
- Dracula.sh → GNOME + Dracula theme + Bash/ble.sh
- Mokka.sh → KDE Plasma 6 + Catppuccin Mocha + Bash/ble.sh

**"sync" means:** Copy to repo → git push → copy to USB

**Why:** Steve needs repeatable, themed Arch installs for multiple machines. Scripts must be idempotent.
**How to apply:** When suggesting changes, consider impact on fresh-install flow and idempotency.
