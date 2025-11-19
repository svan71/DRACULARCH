# shell: fish

## Set values
set fish_greeting
set VIRTUAL_ENV_DISABLE_PROMPT "1"
set -x SHELL /usr/bin/fish

# Fastfetch greeting with Ghostty delay
function fish_greeting
    if test "$TERM" = "xterm-ghostty"
        sleep 0.1
    end

    if type -q fastfetch
        fastfetch --config ~/.config/fastfetch/config.jsonc
    end
end

# Enhanced bash compatibility settings
set -gx fish_features stderr-nocaret qmark-noglob regex-easyesc ampersand-nobg-in-token

# Use bat for man pages
set -xU MANPAGER "sh -c 'col -bx | bat -l man -p'"
set -xU MANROFFOPT "-c"

# Hint to exit PKGBUILD review in Paru
set -x PARU_PAGER "less -P \"Press 'q' to exit the PKGBUILD review.\""

# Set settings for https://github.com/franciscolourenco/done
set -U __done_min_cmd_duration 10000
set -U __done_notification_urgency_level low

# History & environment
set -gx fish_history_max 10000
set -gx fish_history_ignore_duplicates true
set -gx BASH_ENV ~/.bashrc

# FZF Catppuccin Mocha colors
set -gx FZF_DEFAULT_OPTS "\
--color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8 \
--color=fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc \
--color=marker:#f5e0dc,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8"

## Environment setup
if test -f ~/.fish_profile
  source ~/.fish_profile
end

# Add ~/.local/bin to PATH
if test -d ~/.local/bin
    if not contains -- ~/.local/bin $PATH
        set -p PATH ~/.local/bin
    end
end

# Add depot_tools to PATH
if test -d ~/Applications/depot_tools
    if not contains -- ~/Applications/depot_tools $PATH
        set -p PATH ~/Applications/depot_tools
    end
end

## Starship prompt
if status --is-interactive
   source ("/usr/bin/starship" init fish --print-full-init | psub)
end

## Functions
function __history_previous_command
  switch (commandline -t)
  case "!"
    commandline -t $history[1]; commandline -f repaint
  case "*"
    commandline -i !
  end
end

function __history_previous_command_arguments
  switch (commandline -t)
  case "!"
    commandline -t ""
    commandline -f history-token-search-backward
  case "*"
    commandline -i '$'
  end
end

if [ "$fish_key_bindings" = fish_vi_key_bindings ];
  bind -Minsert ! __history_previous_command
  bind -Minsert '$' __history_previous_command_arguments
else
  bind ! __history_previous_command
  bind '$' __history_previous_command_arguments
end

# Fish command history with timestamps
function history
    builtin history --show-time='%F %T '
end

function backup --argument filename
    cp $filename $filename.bak
end

function copy
    set count (count $argv | tr -d \n)
    if test "$count" = 2; and test -d "$argv[1]"
        set from (echo $argv[1] | string trim --right --chars=/)
        set to (echo $argv[2])
        command cp -r $from $to
    else
        command cp $argv
    end
end

function cleanup
    while pacman -Qdtq
        sudo pacman -R (pacman -Qdtq)
        if test "$status" -eq 1
           break
        end
    end
end

function quick --description 'Show quick Fish command reference'
    echo ""
    echo "Quick Commands"
    echo "───────────────────"
    echo ""
    echo "script name.txt # Record terminal session"
    echo "zi (Documents)  # Jump to directory"
    echo "zi              # Browse recent dirs"
    echo "Ctrl+R          # Search history"
    echo "Ctrl+U          # Clear line"
    echo "Ctrl+K          # Delete to end"
    echo "Ctrl+A/E        # Start/End of line"
    echo "ll              # Detailed list with icons"
    echo "la              # Show hidden files"
    echo ""
end

function sync_backup --description 'Backup dir with rsync'
    rsync -avhP $argv[1] $argv[2]
end

function tmux_session
    if tmux ls >/dev/null 2>&1
        tmux attach
    else
        tmux new -s main
    end
end

## Aliases + abbreviations
alias ls 'eza -al --color=always --group-directories-first --icons'
alias lsz 'eza -al --color=always --total-size --group-directories-first --icons'
alias la 'eza -a --color=always --group-directories-first --icons'
alias ll 'eza -l --color=always --group-directories-first --icons'
alias lt 'eza -aT --color=always --group-directories-first --icons'
alias l. 'eza -ald --color=always --group-directories-first --icons .*'

abbr cat 'bat --style header,snip,changes'
if not test -x /usr/bin/yay; and test -x /usr/bin/paru
    alias yay 'paru'
end

type -q rg && abbr --add grep 'rg --color=auto'
type -q fd && abbr --add find 'fd'
type -q btop && abbr --add top 'btop'
type -q dust && abbr --add du 'dust'
type -q procs && abbr --add ps 'procs'
type -q duf && abbr --add df 'duf'
type -q lazygit && abbr --add lg 'lazygit'
type -q wl-copy && abbr --add copy 'wl-copy'
type -q wl-paste && abbr --add paste 'wl-paste'
type -q lsof && abbr --add ports 'lsof -i -P -n'
type -q strace && abbr --add trace 'strace -f'
type -q mtr && abbr --add net 'mtr'
type -q nmap && abbr --add nmapscan 'nmap -sP'
type -q pv && abbr --add pvmon 'pv --width 80'
type -q bc && abbr --add calc 'bc -l'
type -q jq && abbr --add json 'jq .'
type -q source-highlight && abbr --add src 'source-highlight -f esc256'
type -q expac && abbr --add exp 'expac "%n %v"'
type -q powertop && abbr --add power 'powertop'

alias bash_source='bash -c "source"'
alias bash_exec='bash -c'
alias run_bash='bash'
alias source_bash='bash'
alias export='set -gx'

alias .. 'cd ..'
alias ... 'cd ../..'
alias .... 'cd ../../..'
alias ..... 'cd ../../../..'
alias ...... 'cd ../../../../..'
alias big 'expac -H M "%m\t%n" | sort -h | nl'
alias dir 'dir --color=auto'
alias fixpacman 'sudo rm /var/lib/pacman/db.lck'
alias gitpkg 'pacman -Q | grep -i "\-git" | wc -l'
alias egrep 'ugrep -E --color=auto'
alias fgrep 'ugrep -F --color=auto'
alias grubup 'sudo update-grub'
alias hw 'hwinfo --short'
alias ip 'ip -color'
alias psmem 'ps auxf | sort -nr -k 4'
alias psmem10 'ps auxf | sort -nr -k 4 | head -10'
alias rmpkg 'sudo pacman -Rdd'
alias tarnow 'tar -acf '
alias untar 'tar -zxvf '
alias upd '/usr/bin/garuda-update'
alias vdir 'vdir --color=auto'
alias wget 'wget -c '

alias mirror 'sudo reflector -f 30 -l 30 --number 10 --verbose --save /etc/pacman.d/mirrorlist'
alias mirrora 'sudo reflector --latest 50 --number 20 --sort age --save /etc/pacman.d/mirrorlist'
alias mirrord 'sudo reflector --latest 50 --number 20 --sort delay --save /etc/pacman.d/mirrorlist'
alias mirrors 'sudo reflector --latest 50 --number 20 --sort score --save /etc/pacman.d/mirrorlist'

alias apt 'man pacman'
alias apt-get 'man pacman'
alias please 'sudo'
alias tb 'nc termbin.com 9999'
alias helpme 'echo "To print basic information about a command use tldr <command>"'
alias pacdiff 'sudo -H DIFFPROG=meld pacdiff'

alias jctl 'journalctl -p 3 -xb'
alias rip 'expac --timefmt="%Y-%m-%d %T" "%l\t%n %v" | sort | tail -200 | nl'

## Tool integrations
if test -f /usr/share/fish/vendor_functions.d/fzf_key_bindings.fish
    source /usr/share/fish/vendor_functions.d/fzf_key_bindings.fish
end

type -q zoxide && zoxide init fish | source
type -q carapace && carapace _carapace | source
