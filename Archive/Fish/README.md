# Fish Shell Configs (Archived)

## Status
**Archived:** Session 20 (Dec 2024)
**Reason:** Switched to Bash + ble.sh for POSIX compatibility

## What This Was
Fish shell configurations used in both Dracula.sh and Mokka.sh scripts before the switch to Bash.

## Why Archived
- ble.sh provides Fish-like UX (autosuggestions, syntax highlighting)
- Bash is POSIX compatible - scripts from anywhere just work
- One shell to maintain across both scripts
- Starship handles prompt styling (works with both)

## Contents

### dracula-config/
- `fish_history` - Command history (not useful)

### mokka-config/
- `config.fish` - Main Fish configuration
- `fish_variables` - Fish universal variables
- `conf.d/done.fish` - Notification on long command completion
- `functions/fish_title.fish` - Terminal title function
- `themes/` - Fish color themes

## Key Settings If Revisited
- Catppuccin Mocha colors were configured
- `done.fish` plugin for command completion notifications
- Custom prompt (now handled by Starship)
- zoxide, thefuck, eza aliases configured

## To Restore
If Fish is ever needed again:
1. Copy config from `mokka-config/` to `~/.config/fish/`
2. Install Fish: `sudo pacman -S fish`
3. Update script to set Fish as default shell
4. May need updates for newer Fish versions
