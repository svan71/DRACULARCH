function fish_title
    set -l command_name (status current-command)
    set -l current_folder (prompt_pwd)
    echo "$current_folder: $command_name — Ghostty"
end
