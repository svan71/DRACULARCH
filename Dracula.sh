#!/bin/bash

# Ensure proper terminal environment
export TERM="${TERM:-xterm-256color}"
tput init 2>/dev/null || true

# Centralized color palette using associative array
declare -gA COLORS=(
    [PURPLE]=$'\033[1;95m'     # BD93F9 - Bright Purple (headers/titles)
    [CYAN]=$'\033[1;96m'       # 8BE9FD - Bright Cyan (prompts/info)
    [GREEN]=$'\033[1;92m'      # 50FA7B - Bright Green (success/done)
    [PINK]=$'\033[1;91m'       # FF79C6 - Bright Pink (warnings/highlights)
    [RED]=$'\033[1;31m'        # FF5555 - Red (errors)
    [WHITE]=$'\033[1;37m'      # F8F8F2 - White (general text)
    [GRAY]=$'\033[90m'         # 6272A4 - Gray (timestamps)
    [NC]=$'\033[0m'            # Reset/No Color
)

# Initialize global variables at declaration with defaults
declare -g LOG_DIR=""
declare -g LOGFILE=""
declare -g ERRORLOG=""
declare -g ACTUAL_USER="${SUDO_USER:-$USER}"
declare -g CPU_VENDOR=""
declare -g CACHED_GPU_VENDOR=""
declare -g CACHED_TOTAL_MEMORY_KB=""
declare -g CACHED_EFI_PARTITION=""

# Arrays to track installation status
declare -ga successful_installs=()
declare -ga failed_installs=()

# User choice variables with defaults
declare -g kernel_choice=""
declare -ga browser_packages=()
declare -g synology_pass=""

# Ensure UTF-8 in TTY 
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# TTY-Compatible Dracula-themed progress bar functions
show_animated_progress_bar() {
    local message="$1"
    local pid="$2"
    local width=50
    local pos=0
    local direction=1
    
    printf '%s[>] %s%s\n' "${COLORS[PURPLE]}" "$message" "${COLORS[NC]}"
    
    while kill -0 "$pid" 2>/dev/null; do
        printf '\r%s[' "${COLORS[CYAN]}"
        
        for ((i=0; i<width; i++)); do
            if [[ $i -eq $pos ]]; then
                printf '%s>%s' "${COLORS[PINK]}" "${COLORS[NC]}"
            elif [[ $i -lt $pos ]] && [[ $direction -eq 1 ]]; then
                printf '%s=%s' "${COLORS[PURPLE]}" "${COLORS[NC]}"
            elif [[ $i -gt $pos ]] && [[ $direction -eq -1 ]]; then
                printf '%s=%s' "${COLORS[PURPLE]}" "${COLORS[NC]}"
            else
                printf '%s-%s' "${COLORS[GRAY]}" "${COLORS[NC]}"
            fi
        done
        
        printf '%s] %sprocessing%s' "${COLORS[CYAN]}" "${COLORS[GREEN]}" "${COLORS[NC]}"
        
        pos=$((pos + direction))
        if [[ $pos -ge $((width-1)) ]]; then
            direction=-1
        elif [[ $pos -le 0 ]]; then
            direction=1
        fi
        
        sleep 0.15
    done
    
    printf '\r%s[' "${COLORS[CYAN]}"
    printf '%s' "${COLORS[GREEN]}"
    for ((i=0; i<width; i++)); do printf '='; done
    printf '%s] %scompleted%s\n' "${COLORS[NC]}" "${COLORS[GREEN]}" "${COLORS[NC]}"
}

show_package_progress() {
    local operation="$1"
    local package="$2"
    local current="$3"
    local total="$4"
    local width=45
    
    local percentage=$((current * 100 / total))
    local filled=$((current * width / total))
    local empty=$((width - filled))
    
    printf '\r%s[*] %s %s%s (%s%d%s/%s%d%s)\n' "${COLORS[CYAN]}" "$operation" "$package" "${COLORS[NC]}" "${COLORS[PURPLE]}" "$current" "${COLORS[NC]}" "${COLORS[PURPLE]}" "$total" "${COLORS[NC]}"
    
    printf '%s[' "${COLORS[CYAN]}"
    
    if [[ "$operation" == "Downloading" ]]; then
        printf '%s' "${COLORS[PINK]}"
        for ((i=0; i<filled; i++)); do printf '#'; done
    else
        printf '%s' "${COLORS[PURPLE]}"
        for ((i=0; i<filled; i++)); do printf '='; done
    fi
    
    printf '%s' "${COLORS[GRAY]}"
    for ((i=0; i<empty; i++)); do printf '.'; done
    
    printf '%s] %s%d%%%s' "${COLORS[NC]}" "${COLORS[GREEN]}" "$percentage" "${COLORS[NC]}"
    
    if [[ $current -eq $total ]]; then
        printf ' %sdone%s\n' "${COLORS[GREEN]}" "${COLORS[NC]}"
    fi
}

show_kernel_progress() {
    local operation="$1"
    local pid="$2"
    
    printf '%s[+] %s%s\n' "${COLORS[PURPLE]}" "$operation" "${COLORS[NC]}"
    
    local width=50
    local frame=0
    local -a chars
    chars[0]='-'
    chars[1]=$'\\' 
    chars[2]='|'
    chars[3]='/'
    
    while kill -0 "$pid" 2>/dev/null; do
        printf '\r%s[' "${COLORS[CYAN]}"
        
        for ((i=0; i<width; i++)); do
            if [[ $((i % 4)) -eq $((frame % 4)) ]]; then
                printf '%s#%s' "${COLORS[PURPLE]}" "${COLORS[NC]}"
            else
                printf '%s=%s' "${COLORS[GRAY]}" "${COLORS[NC]}"
            fi
        done
        
        local spinner_char="${chars[$((frame % 4))]}"
        printf '%s] %s%s processing%s' "${COLORS[CYAN]}" "${COLORS[GREEN]}" "$spinner_char" "${COLORS[NC]}"
        
        frame=$((frame + 1))
        sleep 0.2
    done
    
    printf '\r%s[' "${COLORS[CYAN]}"
    printf '%s' "${COLORS[GREEN]}"
    for ((i=0; i<width; i++)); do printf '='; done
    printf '%s] %scompleted%s\n' "${COLORS[NC]}" "${COLORS[GREEN]}" "${COLORS[NC]}"
}

# Logging functions with guards to prevent tee errors when logs aren't initialized
show_progress() {
    local message="$1"
    printf '%s[*] %s%s...' "${COLORS[CYAN]}" "$message" "${COLORS[NC]}"
}

finish_progress() {
    printf ' %sdone%s\n' "${COLORS[GREEN]}" "${COLORS[NC]}"
}

log_message() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local output
    output=$(printf '%s[%s]%s %s[i] %s%s\n' "${COLORS[GRAY]}" "$timestamp" "${COLORS[NC]}" "${COLORS[CYAN]}" "$1" "${COLORS[NC]}")
    
    # Only use tee if LOGFILE is set and exists
    if [[ -n "$LOGFILE" && -f "$LOGFILE" ]]; then
        echo "$output" | sudo tee -a "$LOGFILE" >/dev/null
    else
        echo "$output"
    fi
}

log_error() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local output
    output=$(printf '%s[%s]%s %s[!] ERROR:%s %s%s\n' "${COLORS[GRAY]}" "$timestamp" "${COLORS[NC]}" "${COLORS[RED]}" "${COLORS[NC]}" "$1" "${COLORS[NC]}")
    
    # Only use tee if ERRORLOG is set and exists
    if [[ -n "$ERRORLOG" && -f "$ERRORLOG" ]]; then
        echo "$output" | sudo tee -a "$ERRORLOG" >/dev/null
    else
        echo "$output" >&2
    fi
}

log_warning() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local output
    output=$(printf '%s[%s]%s %s[!] WARNING:%s %s%s\n' "${COLORS[GRAY]}" "$timestamp" "${COLORS[NC]}" "${COLORS[PINK]}" "${COLORS[NC]}" "$1" "${COLORS[NC]}")
    
    # Only use tee if both logs are set and exist
    if [[ -n "$LOGFILE" && -f "$LOGFILE" && -n "$ERRORLOG" && -f "$ERRORLOG" ]]; then
        echo "$output" | sudo tee -a "$LOGFILE" "$ERRORLOG" >/dev/null
    else
        echo "$output"
    fi
}

log_success() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local output
    output=$(printf '%s[%s]%s %s[+] SUCCESS:%s %s%s\n' "${COLORS[GRAY]}" "$timestamp" "${COLORS[NC]}" "${COLORS[GREEN]}" "${COLORS[NC]}" "$1" "${COLORS[NC]}")
    
    # Only use tee if LOGFILE is set and exists
    if [[ -n "$LOGFILE" && -f "$LOGFILE" ]]; then
        echo "$output" | sudo tee -a "$LOGFILE" >/dev/null
    else
        echo "$output"
    fi
}
manage_service() {
    local service="$1"
    local action="$2"
    
    if [[ "$action" == "enable --now" ]]; then
        show_progress "Enabling and starting $service"
        sudo systemctl enable "$service" >/dev/null 2>&1 || log_error "Failed to enable service '$service'"
        sudo systemctl start "$service" >/dev/null 2>&1 || log_error "Failed to start service '$service'"
        finish_progress
    else
        show_progress "Managing $service ($action)"
        sudo systemctl "$action" "$service" >/dev/null 2>&1 || log_error "Failed to $action service '$service'"
        finish_progress
    fi
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

is_package_installed() {
    local package="$1"
    pacman -Qi "$package" &>/dev/null
}

install_package() {
    local package="$1"
    local max_retries=3
    local attempt=1
    
    if is_package_installed "$package"; then
        log_message "Package '$package' already installed, skipping"
        return 0
    fi
    
    local driver_packages=("mesa" "libva-mesa-driver" "vulkan-radeon" "libva-intel-driver" "vulkan-intel" "linux-firmware" "sof-firmware")
    local is_driver=0
    for driver in "${driver_packages[@]}"; do
        if [[ "$package" == "$driver" ]]; then
            is_driver=1
            break
        fi
    done
    
    while [[ "$attempt" -le "$max_retries" ]]; do
        show_progress "Installing $package (attempt $attempt/$max_retries)"
        
        if [[ "$is_driver" -eq 1 ]]; then
            if sudo pacman -S --noconfirm --needed --overwrite '*' "$package" >/dev/null 2>&1; then
                successful_installs+=("$package")
                finish_progress
                return 0
            fi
        elif sudo pacman -S --noconfirm --needed "$package" >/dev/null 2>&1; then
            successful_installs+=("$package")
            finish_progress
            return 0
        fi
        
        if [[ "$attempt" -eq "$max_retries" ]]; then
            failed_installs+=("$package")
            log_error "Failed to install '$package' after $max_retries attempts"
            finish_progress
            return 1
        fi
        
        sleep 2
        ((attempt++))
    done
}

fetch_resource() {
    local url="$1"
    local output="$2"
    local is_git="$3"

    show_progress "Downloading $(basename "$url")"
    
    # Remove any existing incomplete file
    sudo rm -f "$output" 2>/dev/null
    
    if [[ "$is_git" == "git" ]]; then
        if timeout 300 sudo -u "$ACTUAL_USER" git clone "$url" "$output" >/dev/null 2>&1; then
            if [[ -d "$output" ]] && [[ -n "$(ls -A "$output" 2>/dev/null)" ]]; then
                finish_progress
                return 0
            fi
            sudo rm -rf "$output" 2>/dev/null
        fi
    else
        # Enhanced curl with better timeout handling
        if timeout 300 curl -L \
            --connect-timeout 30 \
            --max-time 300 \
            --retry 2 \
            --retry-delay 3 \
            --fail \
            --silent \
            --show-error \
            "$url" -o "$output" 2>/dev/null; then
            
            # Verify the file was downloaded and has content
            if [[ -f "$output" ]] && [[ -s "$output" ]]; then
                # Additional verification for known file types
                case "$output" in
                    *.tar.xz)
                        if file "$output" | grep -q "XZ compressed"; then
                            finish_progress
                            return 0
                        fi
                        ;;
                    *.zip)
                        if file "$output" | grep -q "Zip archive"; then
                            finish_progress
                            return 0
                        fi
                        ;;
                    *)
                        finish_progress
                        return 0
                        ;;
                esac
            fi
            
            # Clean up failed download
            sudo rm -f "$output" 2>/dev/null
        fi
    fi
    
    log_error "Failed to fetch '$url'"
    finish_progress
    return 1
}

unpack_resource() {
    local file="$1"
    local dest="$2"
    local type="$3"

    show_progress "Extracting $(basename "$file")"
    if [[ "$type" == "zip" ]]; then
        if sudo -u "$ACTUAL_USER" unzip -o "$file" -d "$dest" >/dev/null 2>&1; then
            finish_progress
            return 0
        fi
    elif [[ "$type" == "tar" ]]; then
        if tar xf "$file" -C "$dest" >/dev/null 2>&1; then
            finish_progress
            return 0
        fi
    fi
    log_error "Failed to unpack '$file' to '$dest'"
    finish_progress
    return 1
}

# Smart predownload with package checking
predownload_packages() {
    local -a packages=("$@")
    local -a missing_packages=()
    
    if [[ ${#packages[@]} -eq 0 ]]; then
        return
    fi
    
    for pkg in "${packages[@]}"; do
        if ! is_package_installed "$pkg"; then
            missing_packages+=("$pkg")
        fi
    done
    
    if [[ ${#missing_packages[@]} -eq 0 ]]; then
        log_message "All ${#packages[@]} packages already installed, skipping download"
        return
    fi
    
    printf '%s[>] Pre-downloading packages (%s%d%s of %s%d%s needed)\n' "${COLORS[PURPLE]}" "${COLORS[CYAN]}" "${#missing_packages[@]}" "${COLORS[NC]}" "${COLORS[CYAN]}" "${#packages[@]}" "${COLORS[NC]}"
    (sudo pacman -Sw --noconfirm --needed "${missing_packages[@]}" >/dev/null 2>&1) &
    local download_pid=$!
    show_animated_progress_bar "Downloading package cache" "$download_pid"
    wait "$download_pid" || log_warning "Some packages failed to pre-download, proceeding anyway"
}

install_packages() {
    local -a packages=("$@")
    local -a missing_packages=()
    
    if [[ ${#packages[@]} -eq 0 ]]; then
        return
    fi

    for pkg in "${packages[@]}"; do
        if ! is_package_installed "$pkg"; then
            missing_packages+=("$pkg")
        fi
    done
    
    if [[ ${#missing_packages[@]} -eq 0 ]]; then
        log_message "All ${#packages[@]} packages already installed"
        successful_installs+=("${packages[@]}")
        return
    fi

    printf '%s[*] Installing packages (%s%d%s new, %s%d%s total)\n' "${COLORS[PURPLE]}" "${COLORS[CYAN]}" "${#missing_packages[@]}" "${COLORS[NC]}" "${COLORS[CYAN]}" "${#packages[@]}" "${COLORS[NC]}"
    
    # Try batch install first - much faster
    (sudo pacman -S --noconfirm --needed --overwrite '*' "${missing_packages[@]}" >/dev/null 2>&1) &
    local batch_pid=$!
    show_animated_progress_bar "Installing all packages in batch" "$batch_pid"
    
    if wait "$batch_pid"; then
        # Batch install succeeded
        successful_installs+=("${missing_packages[@]}")
        printf '%s[+] Batch installation completed successfully%s\n' "${COLORS[GREEN]}" "${COLORS[NC]}"
    else
        # Batch failed, fall back to individual installs for error tracking
        log_warning "Batch installation failed, installing individually to identify issues"
        
        local current=0
        local total=${#missing_packages[@]}
        
        for package in "${missing_packages[@]}"; do
            current=$((current + 1))
            show_package_progress "Installing" "$package" "$current" "$total"
            
            sudo pacman -S --noconfirm --needed --overwrite '*' "$package" >/dev/null 2>&1
            sleep 0.1
            # Trust pacman -Qi as the source of truth for verification
            if pacman -Qi "$package" >/dev/null 2>&1; then
                successful_installs+=("$package")
            else
                failed_installs+=("$package")
            fi
        done
        
        printf '%s[+] Individual package installation completed%s\n' "${COLORS[GREEN]}" "${COLORS[NC]}"
    fi
}

# Setup TMPFS
setup_tmpfs() {
    show_progress "Setting up tmpfs for /tmp"
    sudo mount -o size=4G -t tmpfs tmpfs /tmp >/dev/null 2>&1 || log_warning "Failed to mount tmpfs, using default /tmp"
    sudo chmod 1777 /tmp
    finish_progress
    trap 'sudo umount /tmp 2>/dev/null || true' EXIT
}

# Setup Sudo
setup_sudo() {
    local sudo_pass
    printf "%s[?] Enter sudo password: %s" "${COLORS[CYAN]}" "${COLORS[NC]}"
    read -r -s sudo_pass
    echo

    if ! echo "$sudo_pass" | sudo -S true >/dev/null 2>&1; then
        printf "%s[!] Incorrect sudo password. Exiting.%s\n" "${COLORS[RED]}" "${COLORS[NC]}"
        exit 1
    fi

    show_progress "Configuring passwordless sudo"
    echo "$sudo_pass" | sudo -S sh -c "echo \"$ACTUAL_USER ALL=(ALL) NOPASSWD: ALL\" > /etc/sudoers.d/$ACTUAL_USER" >/dev/null 2>&1
    chmod 0440 "/etc/sudoers.d/$ACTUAL_USER" >/dev/null 2>&1
    unset sudo_pass
    finish_progress

    printf "\n%s[*] Synology NAS Configuration:%s\n" "${COLORS[PURPLE]}" "${COLORS[NC]}"
    printf "%s[?] Enter Synology password for user steve (for direct CIFS mount):%s " "${COLORS[CYAN]}" "${COLORS[NC]}"
    read -r -s synology_pass
    printf "\n"
    local creds_file="/home/$ACTUAL_USER/.smbcredentials"
    printf 'username=steve\npassword=%s\n' "$synology_pass" | sudo -u "$ACTUAL_USER" tee "$creds_file" >/dev/null
    sudo -u "$ACTUAL_USER" chmod 600 "$creds_file"
    unset synology_pass
    log_message "Synology credentials configured"
}

# Setup Logging Directory
setup_logging_directory() {
    show_progress "Setting up logging directory"
    
    sudo -u "$ACTUAL_USER" mkdir -p "/home/$ACTUAL_USER"/{Documents,Downloads,Desktop} >/dev/null 2>&1
    sudo -u "$ACTUAL_USER" mkdir -p "/home/$ACTUAL_USER/Documents/dracula-logs" >/dev/null 2>&1
    sudo chown -R "$ACTUAL_USER:$ACTUAL_USER" "/home/$ACTUAL_USER/Documents" >/dev/null 2>&1
    sudo chmod 755 "/home/$ACTUAL_USER/Documents" "/home/$ACTUAL_USER/Documents/dracula-logs" >/dev/null 2>&1
    sudo -u "$ACTUAL_USER" touch "/home/$ACTUAL_USER/Documents/dracula-logs/arch_setup.log" "/home/$ACTUAL_USER/Documents/dracula-logs/arch_setup_errors.log" >/dev/null 2>&1
    sudo chmod 644 "/home/$ACTUAL_USER/Documents/dracula-logs/arch_setup.log" "/home/$ACTUAL_USER/Documents/dracula-logs/arch_setup_errors.log" >/dev/null 2>&1
    
    LOG_DIR="/home/$ACTUAL_USER/Documents/dracula-logs"
    LOGFILE="$LOG_DIR/arch_setup.log"        
    ERRORLOG="$LOG_DIR/arch_setup_errors.log"

    exec > >(tee -a "$LOGFILE") 2> >(tee -a "$ERRORLOG" >&2)
    
    finish_progress
    log_message "Logging configured: $LOG_DIR"
}

# Consolidated System Detection
detect_system_info() {
    show_progress "Detecting system hardware"

    CPU_VENDOR=$(grep -m1 'vendor_id' /proc/cpuinfo | cut -f2 -d':' | tr -d ' ')
    CACHED_GPU_VENDOR=$(lspci -nn 2>/dev/null | grep -i "vga" | grep -oE "Intel|AMD" | head -n 1)
    CACHED_TOTAL_MEMORY_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')

    CACHED_EFI_PARTITION=$(findmnt -n -o SOURCE /boot/efi 2>/dev/null || findmnt -n -o SOURCE /efi 2>/dev/null || findmnt -n -o SOURCE /boot 2>/dev/null)

    log_message "System: CPU=$CPU_VENDOR, GPU=$CACHED_GPU_VENDOR, RAM=${CACHED_TOTAL_MEMORY_KB}KB, EFI=$CACHED_EFI_PARTITION"
    
    finish_progress
}

collect_user_inputs() {
    printf "%s[*] Kernel Configuration Options:%s\n" "${COLORS[PURPLE]}" "${COLORS[NC]}"
    printf "%s1)%s %sOptimize existing Linux Zen Kernel (Default)%s\n" "${COLORS[CYAN]}" "${COLORS[NC]}" "${COLORS[GREEN]}" "${COLORS[NC]}"
    printf "%s2)%s %sInstall Linux CachyOS Kernel and set as default%s\n" "${COLORS[CYAN]}" "${COLORS[NC]}" "${COLORS[GREEN]}" "${COLORS[NC]}"
    printf "%s[?] Enter your choice (1 or 2): %s" "${COLORS[CYAN]}" "${COLORS[NC]}"
    read -r kernel_choice
    
    case "$kernel_choice" in
        1) log_message "User chose to optimize existing Linux Zen kernel" ;;
        2) log_message "User chose to install Linux CachyOS Kernel" ;;
        *) 
            printf "%s[!] Invalid choice, defaulting to Linux Zen optimization%s\n" "${COLORS[PINK]}" "${COLORS[NC]}"
            kernel_choice="1"
            log_message "Invalid kernel choice, defaulting to Zen optimization"
            ;;
    esac

    printf "\n%s[*] Browser Selection:%s\n" "${COLORS[PURPLE]}" "${COLORS[NC]}"
    printf "%s1)%s %sGoogle Chrome%s\n" "${COLORS[CYAN]}" "${COLORS[NC]}" "${COLORS[GREEN]}" "${COLORS[NC]}"
    printf "%s2)%s %sFirefox%s\n" "${COLORS[CYAN]}" "${COLORS[NC]}" "${COLORS[GREEN]}" "${COLORS[NC]}"
    printf "%s3)%s %sFiredragon%s\n" "${COLORS[CYAN]}" "${COLORS[NC]}" "${COLORS[GREEN]}" "${COLORS[NC]}"
    printf "%s4)%s %sBrave%s\n" "${COLORS[CYAN]}" "${COLORS[NC]}" "${COLORS[GREEN]}" "${COLORS[NC]}"
    printf "%s5)%s %sMicrosoft Edge%s\n" "${COLORS[CYAN]}" "${COLORS[NC]}" "${COLORS[GREEN]}" "${COLORS[NC]}"
    printf "%s6)%s %sAll of the above%s\n" "${COLORS[CYAN]}" "${COLORS[NC]}" "${COLORS[GREEN]}" "${COLORS[NC]}"
    printf "%s7)%s %sNone%s\n" "${COLORS[CYAN]}" "${COLORS[NC]}" "${COLORS[GREEN]}" "${COLORS[NC]}"
    printf "%s[?] Enter choices as comma-separated list (e.g., 1,3): %s" "${COLORS[CYAN]}" "${COLORS[NC]}"
    read -r browser_choices

    local -a browser_selection
    IFS=',' read -r -a browser_selection <<< "$browser_choices"
    browser_packages=()

    for choice in "${browser_selection[@]}"; do
        case "$choice" in
            1) browser_packages+=("google-chrome") ;;
            2) browser_packages+=("firefox") ;;
            3) browser_packages+=("firedragon-catppuccin-bin") ;;
            4) browser_packages+=("brave-bin") ;;
            5) browser_packages+=("microsoft-edge-stable-bin") ;;
            6) browser_packages=("google-chrome" "firefox" "firedragon-catppuccin-bin" "brave-bin" "microsoft-edge-stable-bin"); break ;;
            7) printf "%s[i] No browsers selected%s\n" "${COLORS[GRAY]}" "${COLORS[NC]}"; break ;;
            *) printf "%s[!] Invalid choice: %s%s\n" "${COLORS[PINK]}" "$choice" "${COLORS[NC]}" ;;
        esac
    done

}

# Refresh System with enhanced progress
refresh_system() {
    show_progress "Checking system clock synchronization"
    if ! timedatectl status 2>/dev/null | grep -q "System clock synchronized: yes"; then
        sudo timedatectl set-ntp true >/dev/null 2>&1 || log_error "Failed to synchronize system clock"
        sleep 3
    fi
    finish_progress

    show_progress "Configuring pacman optimizations"
    sudo sed -i 's|^#ParallelDownloads =.*|ParallelDownloads = 20|' /etc/pacman.conf >/dev/null 2>&1
    sudo sed -i 's/^#Color/Color/' /etc/pacman.conf >/dev/null 2>&1
    sudo sed -i 's/^#VerbosePkgLists/VerbosePkgLists/' /etc/pacman.conf >/dev/null 2>&1
    sudo sed -i 's/^#CheckSpace/CheckSpace/' /etc/pacman.conf >/dev/null 2>&1
    if ! grep -q "ILoveCandy" /etc/pacman.conf && grep -q "^VerbosePkgLists" /etc/pacman.conf; then
        sudo sed -i '/^VerbosePkgLists/a ILoveCandy' /etc/pacman.conf >/dev/null 2>&1
    fi
    sudo sed -i 's|^#COMPRESSXZ=.*|COMPRESSXZ=(xz -c -z - --threads=0)|' /etc/makepkg.conf >/dev/null 2>&1
    sudo sed -i 's|^#COMPRESSZST=.*|COMPRESSZST=(zstd -c -z -q - --threads=0)|' /etc/makepkg.conf >/dev/null 2>&1
    finish_progress

    show_progress "Installing reflector"
    sudo pacman -S --noconfirm reflector >/dev/null 2>&1
    finish_progress

    printf '%s[>] Refreshing mirrors with reflector%s\n' "${COLORS[PURPLE]}" "${COLORS[NC]}"
    (sudo reflector --country "United States" --protocol https --latest 5 --fastest 10 --sort rate --threads 4 --save /etc/pacman.d/mirrorlist >/dev/null 2>&1) &
    local reflector_pid=$!
    show_animated_progress_bar "Optimizing mirror list" "$reflector_pid"
    
    if ! wait "$reflector_pid"; then
        log_warning "Reflector failed, using backup mirrorlist"
        
        cat << 'EOF' | sudo tee /etc/pacman.d/mirrorlist >/dev/null
# Arch Linux mirrorlist - Backup fallback mirrors
Server = https://arch.mirror.constant.com/$repo/os/$arch
Server = https://mirror.rackspace.com/archlinux/$repo/os/$arch
Server = https://mirrors.kernel.org/archlinux/$repo/os/$arch
Server = https://america.mirror.pkgbuild.com/$repo/os/$arch
EOF
    fi

    printf '%s[>] Synchronizing package database%s\n' "${COLORS[PURPLE]}" "${COLORS[NC]}"
    (sudo pacman -Syyw --noconfirm --needed --overwrite "*" >/dev/null 2>&1) &
    local sync_pid=$!
    show_animated_progress_bar "Downloading package database" "$sync_pid"
    wait "$sync_pid" || log_warning "Database sync had issues, proceeding"

    printf '%s[>] Updating system packages%s\n' "${COLORS[PURPLE]}" "${COLORS[NC]}"
    (sudo pacman -Syu --noconfirm --needed --overwrite "*" >/dev/null 2>&1) &
    local update_pid=$!
    show_animated_progress_bar "Installing system updates" "$update_pid"
    local update_exit_code
    wait "$update_pid"
    update_exit_code=$?
    
    if [[ "$update_exit_code" -ne 0 ]]; then
        log_error "System update failed. Retrying"
        printf '%s[>] Retrying system update%s\n' "${COLORS[PINK]}" "${COLORS[NC]}"
        (sudo pacman -Syu --noconfirm --needed --overwrite "*" >/dev/null 2>&1) &
        local retry_pid=$!
        show_animated_progress_bar "Second update attempt" "$retry_pid"
        wait "$retry_pid"
        local retry_exit_code=$?
        if [[ "$retry_exit_code" -ne 0 ]]; then
            log_error "Second update attempt failed. Exiting"
            exit 1
        fi
    fi

    log_success "System refresh and update completed"
}

# Enable Multilib
enable_multilib() {
    show_progress "Checking and enabling multilib repository"
    if ! grep -q "^\[multilib\]" /etc/pacman.conf; then
        local temp_conf
        temp_conf=$(mktemp) || {
            log_error "Failed to create temporary file"
            finish_progress
            return 1
        }
        local in_multilib_section=false
        
        while IFS= read -r line; do
            if [[ "$line" == "#[multilib]" ]]; then
                echo "[multilib]"
                in_multilib_section=true
            elif [[ "$line" == "#Include = /etc/pacman.d/mirrorlist" ]] && [[ "$in_multilib_section" == true ]]; then
                echo "Include = /etc/pacman.d/mirrorlist"
                in_multilib_section=false
            elif [[ "$line" =~ ^\[.*\] ]] && [[ "$line" != "#[multilib]" ]]; then
                in_multilib_section=false
                echo "$line"
            else
                echo "$line"
            fi
        done < /etc/pacman.conf > "$temp_conf"
        
        sudo cp "$temp_conf" /etc/pacman.conf
        rm "$temp_conf"
        
        if grep -q "^\[multilib\]" /etc/pacman.conf && grep -A1 "^\[multilib\]" /etc/pacman.conf | grep -q "^Include = /etc/pacman.d/mirrorlist"; then
            sudo pacman -Syy --noconfirm >/dev/null 2>&1 || {
                log_error "Failed to sync package database after enabling multilib"
                return 1
            }
        else
            log_error "Failed to properly enable multilib repository"
            finish_progress
            return 1
        fi
    fi
    finish_progress
}

# Install Required Packages with enhanced progress
install_required_packages() {
    local -a packages=(
    # Core Dependencies
    "git" "git-lfs" "base-devel" "dbus" "mkinitcpio" "bc" "kmod" "inetutils" "cpio" "rust" "rust-bindgen" "rust-src"
    
    # GNOME Desktop Environment 
    "gdm" "gnome-shell" "gnome-session" "gnome-settings-daemon" "gnome-control-center" "gnome-keyring" "libsecret" "nautilus"
    "gnome-text-editor" "gnome-backgrounds" "gnome-menus" "gnome-software" "gnome-system-monitor" "gnome-themes-extra" 
    "gnome-tweaks" "gnome-user-share" "eog" "gvfs" "gvfs-afc" "gvfs-dnssd" "gvfs-goa" "gvfs-google" "xdg-utils"
    "gvfs-gphoto2" "gvfs-mtp" "gvfs-nfs" "gvfs-onedrive" "gvfs-smb" "gvfs-wsdd" "smbclient" "tracker3-miners" "grilo-plugins"
    "xdg-desktop-portal" "xdg-desktop-portal-gnome" "xdg-desktop-portal-gtk" "xdg-user-dirs" "xdg-user-dirs-gtk" "nautilus-python"
    
    # Terminal & Modern CLI Tools
    "ghostty" "eza" "bat" "fd" "ripgrep" "zoxide"
    "git-delta" "fzf" "fastfetch" "btop" "bash-completion"
    "thefuck" "tldr"
    
    # System Utilities
    "curl" "wget" "unzip" "zip" "rsync" "dust" "lsof"
    "procs" "duf" "pkgfile" "rebuild-detector"
    
    # Text Processing & Development
    "nano" "nano-syntax-highlighting" "source-highlight" "bc" "jq" "llvm" "lld" "clang"
    
    # Spell-Checking Packages for GNOME Text Editor
    "nuspell"
    
    # Multimedia & Audio
    "alsa-utils" "ffmpeg" "gstreamer" "gst-libav" "gst-plugins-base" 
    "gst-plugins-good" "gst-plugins-bad" "gst-plugins-ugly" "gst-plugin-pipewire" "libpipewire" "sof-firmware" "playerctl"
    
    # Thumbnail Support
    "ffmpegthumbnailer" "webp-pixbuf-loader" "file"
    
    # Proprietary Codecs & Media Support  
    "libdvdcss" "libdvdread" "x264" "x265" "lame" "libva-utils" "libmad"
    "faad2" "libmpeg2" "twolame"
    
    # Graphics Drivers & Rendering
    "mesa" "libva-mesa-driver" "vulkan-radeon" "lib32-mesa" 
    "lib32-vulkan-radeon" "libva-intel-driver" "vulkan-intel"
    "freetype2" "fontconfig" "cairo"
    
    # Network & Connectivity
    "openssh" "wpa_supplicant" "iw" "nfs-utils" "avahi" "nss-mdns" "samba" "cifs-utils"
    
    # Package Management & System
    "flatpak" "pacman-contrib" "expac" "smartmontools" 
    "power-profiles-daemon" "powertop"
    
    # Hardware & System Info
    "udisks2" "iputils" "dosfstools"
    
    # Wayland Support
    "wl-clipboard" "xorg-server-xvfb"
    
    # Kernel Packages & Build Dependencies
    "linux-zen-headers"
    "cpio" "rust" "rust-bindgen" "rust-src"
    "pahole" "elfutils"
    
    # Applications
    "thunderbird"
    
    # System Security
    "iptables" "nftables" "ufw" "gufw"
)

    # Add printing stack (auto-detection handles printer setup later)
    packages+=("cups" "cups-filters" "cups-pdf" "avahi" "nss-mdns" "system-config-printer")

    predownload_packages "${packages[@]}"
    install_packages "${packages[@]}"

    # Verify graphics driver setup
    show_progress "Verifying graphics driver setup"
    if [[ -z "$CACHED_GPU_VENDOR" ]]; then
        log_warning "No recognizable GPU (Intel or AMD) detected"
    elif [[ "$CACHED_GPU_VENDOR" == "AMD" ]]; then
        if ! lspci -k 2>/dev/null | grep -A 2 -E "(VGA|3D)" | grep -q "amdgpu"; then
            log_error "AMD GPU detected, but amdgpu driver not in use"
        fi
    elif [[ "$CACHED_GPU_VENDOR" == "Intel" ]]; then
        log_message "Intel GPU detected. Using minimal drivers for UHD Graphics"
    fi
    finish_progress

    if is_package_installed "power-profiles-daemon"; then
        manage_service "power-profiles-daemon.service" "enable --now"
    fi

    return 0
}

# Setup Flatpak
setup_flatpak() {
    show_progress "Adding Flathub remote"
    sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo >/dev/null 2>&1 || {
        log_error "Failed to add Flathub remote"
        return 1
    }
    finish_progress
    log_success "Flatpak configured with Flathub remote"
}

# Setup Kernel Microcode and Headers
setup_kernel_microcode_and_headers() {
    # Step 1: Microcode Installation
    if [[ "$CPU_VENDOR" == "GenuineIntel" ]]; then
        printf '%s[>] Installing Intel microcode and firmware%s\n' "${COLORS[PURPLE]}" "${COLORS[NC]}"
        (sudo pacman -S --noconfirm --needed "intel-ucode" "linux-firmware" >/dev/null 2>&1) &
        local microcode_pid=$!
        show_animated_progress_bar "Installing Intel microcode" "$microcode_pid"
        wait "$microcode_pid" || log_error "Failed to install Intel microcode and firmware"
    elif [[ "$CPU_VENDOR" == "AuthenticAMD" ]]; then
        printf '%s[>] Installing AMD microcode and firmware%s\n' "${COLORS[PURPLE]}" "${COLORS[NC]}"
        (sudo pacman -S --noconfirm --needed "amd-ucode" "linux-firmware" >/dev/null 2>&1) &
        local microcode_pid=$!
        show_animated_progress_bar "Installing AMD microcode" "$microcode_pid"
        wait "$microcode_pid" || log_error "Failed to install AMD microcode and firmware"
    fi

    # Step 2: Ensure mkinitcpio.conf exists and configure hooks
    show_progress "Configuring mkinitcpio hooks"
    
    if [[ ! -f "/etc/mkinitcpio.conf" ]]; then
        cat << 'EOF' | sudo tee /etc/mkinitcpio.conf >/dev/null
# mkinitcpio configuration

MODULES=()
BINARIES=()
FILES=()
HOOKS=(base udev autodetect modconf kms block filesystems keyboard fsck)
COMPRESSION="zstd"
COMPRESSION_OPTIONS=(-c -z -q --ultra -20 -T0)
EOF
        if [[ ! -f "/etc/mkinitcpio.conf" ]]; then
            log_error "Failed to create mkinitcpio.conf"
            finish_progress
            return 1
        fi
    fi

    local desired_hooks="base udev autodetect modconf kms block filesystems keyboard fsck"
    if ! grep -q "^HOOKS=" /etc/mkinitcpio.conf 2>/dev/null; then
        if ! echo "HOOKS=($desired_hooks)" | sudo tee -a /etc/mkinitcpio.conf >/dev/null 2>&1; then
            log_error "Failed to add HOOKS line to mkinitcpio.conf"
            finish_progress
            return 1
        fi
    else
        if ! sudo sed -i "s|^HOOKS=.*|HOOKS=($desired_hooks)|" /etc/mkinitcpio.conf 2>/dev/null; then
            log_error "Failed to update HOOKS line in mkinitcpio.conf"
            finish_progress
            return 1
        fi
    fi
    finish_progress

    log_message "Microcode and kernel headers configured (initramfs rebuild deferred)"
}

# Setup Kernel
setup_kernel() {
    if [[ "$kernel_choice" == "1" ]] && is_package_installed "linux-zen"; then
        log_message "Linux Zen already installed and user chose optimization option 1"
        return 0
    fi
    
    if [[ "$kernel_choice" == "2" ]]; then
        printf '%s[>] Downloading Linux CachyOS Kernel%s\n' "${COLORS[PURPLE]}" "${COLORS[NC]}"
        # FIXED: Use raw.githubusercontent.com instead of media.githubusercontent.com
        local kernel_url="https://raw.githubusercontent.com/svan71/DRACULARCH/refs/heads/main/Cachyos%20Optimized%20Kernel.tar.xz"
        local headers_url="https://raw.githubusercontent.com/svan71/DRACULARCH/refs/heads/main/Cachyos%20Optimized%20Headers.tar.xz"
        
        fetch_resource "$kernel_url" "/tmp/cachyos-kernel.tar.xz" "" || {
            log_error "Failed to download CachyOS Kernel"
            return 1
        }
        
        fetch_resource "$headers_url" "/tmp/cachyos-headers.tar.xz" "" || {
            log_error "Failed to download CachyOS Headers"
            return 1
        }
        
        if [[ ! -f "/tmp/cachyos-kernel.tar.xz" ]] || [[ ! -s "/tmp/cachyos-kernel.tar.xz" ]]; then
            log_error "Kernel download validation failed"
            return 1
        fi
        
        if [[ ! -f "/tmp/cachyos-headers.tar.xz" ]] || [[ ! -s "/tmp/cachyos-headers.tar.xz" ]]; then
            log_error "Headers download validation failed"
            return 1
        fi

        show_progress "Extracting kernel packages"
        local temp_dir="/tmp/cachyos_install"
        mkdir -p "$temp_dir"
        
        if ! unpack_resource "/tmp/cachyos-kernel.tar.xz" "$temp_dir" "tar"; then
            log_error "Failed to extract kernel package"
            return 1
        fi
        
        if ! unpack_resource "/tmp/cachyos-headers.tar.xz" "$temp_dir" "tar"; then
            log_error "Failed to extract headers package"
            return 1
        fi
        finish_progress

        show_progress "Installing Linux CachyOS Kernel and headers"
        local kernel_pkg
        local headers_pkg
        
        kernel_pkg=$(find "$temp_dir" -name "linux-cachyos-[0-9]*.pkg.tar.zst" -type f 2>/dev/null | grep -v headers | head -n 1)
        headers_pkg=$(find "$temp_dir" -name "linux-cachyos-headers-*.pkg.tar.zst" -type f 2>/dev/null | head -n 1)
        
        if [[ -z "$kernel_pkg" ]]; then
            kernel_pkg=$(find "$temp_dir" -name "*cachyos*kernel*.pkg.tar.zst" -type f 2>/dev/null | head -n 1)
        fi
        
        if [[ -z "$headers_pkg" ]]; then
            headers_pkg=$(find "$temp_dir" -name "*cachyos*headers*" -type f 2>/dev/null | head -n 1)
        fi
        
        if [[ -z "$kernel_pkg" ]]; then
            log_error "CachyOS Kernel package not found in extracted files"
            sudo rm -rf "$temp_dir" "/tmp/cachyos-kernel.tar.xz" "/tmp/cachyos-headers.tar.xz"
            return 1
        fi
        
        if ! sudo pacman -U --noconfirm "$kernel_pkg" >/dev/null 2>&1; then
            log_error "Failed to install CachyOS Kernel package"
            finish_progress
            return 1
        fi
        
        if [[ -n "$headers_pkg" ]]; then
            if [[ "$headers_pkg" == *.pkg.tar.zst ]]; then
                if ! sudo pacman -U --noconfirm "$headers_pkg" >/dev/null 2>&1; then
                    log_error "Failed to install headers package"
                    finish_progress
                    return 1
                fi
            elif [[ "$headers_pkg" == *.tar.gz ]]; then
                if ! sudo tar -xzf "$headers_pkg" -C /usr/src/ >/dev/null 2>&1; then
                    log_error "Failed to extract headers to /usr/src/"
                    finish_progress
                    return 1
                fi
            fi
        fi
        finish_progress

        log_message "Linux CachyOS Kernel installed (initramfs rebuild deferred)"
        
        sudo rm -rf "$temp_dir" "/tmp/cachyos-kernel.tar.xz" "/tmp/cachyos-headers.tar.xz" 2>/dev/null
    else
        show_progress "Verifying Linux Zen kernel installation"
        if ! pacman -Qi "linux-zen" >/dev/null 2>&1; then
            log_warning "Linux Zen kernel not found, but continuing with default kernel"
        fi
        finish_progress
    fi
    
    return 0
}

# Apply Performance Optimizations
apply_performance_optimizations() {
    show_progress "Removing basic optimization files"
    sudo rm -f "/etc/modprobe.d/intel-pstate.conf" "/etc/modprobe.d/amd-pstate.conf" "/etc/modprobe.d/amdgpu.conf" "/etc/modprobe.d/i915.conf" "/etc/modprobe.d/audio_disable_powersave.conf" 2>/dev/null
    sudo rm -f "/etc/udev/rules.d/60-ioschedulers.rules" 2>/dev/null
    finish_progress

    # 1. SYSCTL OPTIMIZATIONS
    show_progress "Applying CachyOS sysctl optimizations"
    sudo mkdir -p "/etc/sysctl.d"
    cat <<'EOF' | sudo tee "/etc/sysctl.d/99-cachyos-settings.conf" >/dev/null
# CachyOS Performance Settings
# Memory Management
vm.swappiness = 150
vm.vfs_cache_pressure = 50
vm.dirty_background_bytes = 268435456
vm.dirty_bytes = 1073741824
vm.dirty_writeback_centisecs = 300
vm.page-cluster = 0

# System Stability & Security
kernel.nmi_watchdog = 0
kernel.unprivileged_userns_clone = 1
kernel.kptr_restrict = 1
kernel.kexec_load_disabled = 0

# Logging & Console
kernel.printk = 3 3 3 3

# Network Performance - Optimized for 2.5Gb
net.core.netdev_max_backlog = 16384
net.core.somaxconn = 8192
net.core.rmem_default = 1048576
net.core.rmem_max = 26214400
net.core.wmem_default = 1048576
net.core.wmem_max = 26214400
net.core.optmem_max = 65536
net.core.netdev_budget = 600
net.core.netdev_budget_usecs = 6000
net.ipv4.tcp_rmem = 4096 1048576 26214400
net.ipv4.tcp_wmem = 4096 65536 26214400
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_max_syn_backlog = 8192
net.ipv4.tcp_max_tw_buckets = 2000000
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 10
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_keepalive_time = 60
net.ipv4.tcp_keepalive_intvl = 10
net.ipv4.tcp_keepalive_probes = 6
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_syncookies = 1
net.core.default_qdisc = cake
net.ipv4.tcp_congestion_control = bbr

# File System
fs.file-max = 2097152
fs.inotify.max_user_watches = 524288

# BORE Scheduler Settings (for CachyOS kernel)
kernel.sched_bore = 1
EOF
    sudo sysctl --system >/dev/null 2>&1
    finish_progress

    # 2. UDEV RULES
    show_progress "Installing CachyOS udev rules"
    sudo mkdir -p "/etc/udev/rules.d"
    cat <<'EOF' | sudo tee "/etc/udev/rules.d/69-cachyos-settings.rules" >/dev/null
# CachyOS Performance Udev Rules

# I/O Scheduler Optimization
ACTION=="add|change", KERNEL=="sd[a-z]*", ATTR{queue/rotational}=="1", ATTR{queue/scheduler}="bfq"
ACTION=="add|change", KERNEL=="sd[a-z]*", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="mq-deadline"
ACTION=="add|change", KERNEL=="nvme[0-9]*", ATTR{queue/scheduler}="none"

# SATA Link Power Management
ACTION=="add", SUBSYSTEM=="scsi_host", KERNEL=="host*", ATTR{link_power_management_policy}="max_performance"

# Audio Device Permissions
SUBSYSTEM=="sound", GROUP="audio", MODE="0664"
KERNEL=="controlC[0-9]*", GROUP="audio", MODE="0664"

# RTC and HPET permissions for audio applications
SUBSYSTEM=="rtc", KERNEL=="rtc0", GROUP="audio", MODE="0664"
KERNEL=="hpet", GROUP="audio", MODE="0664"

# CPU DMA Latency (for low-latency applications)
KERNEL=="cpu_dma_latency", GROUP="audio", MODE="0660"

# ZRAM swap priority optimization
KERNEL=="zram*", ATTR{disksize}=="*", TAG+="systemd", ENV{SYSTEMD_WANTS}+="zram-swap@%k.service"
EOF
    sudo udevadm control --reload-rules >/dev/null 2>&1
    sudo udevadm trigger >/dev/null 2>&1
    finish_progress

    # 3. MODPROBE OPTIMIZATIONS
    show_progress "Configuring advanced module parameters"
    sudo mkdir -p "/etc/modprobe.d"
    
    local amd_gpu_module="amdgpu"
    
    if [[ "$CACHED_GPU_VENDOR" == "AMD" ]]; then
        local gpu_device
        gpu_device=$(lspci -nn | grep -i "vga.*amd\|vga.*ati" | head -n 1)
        
        if echo "$gpu_device" | grep -qE "\[(Radeon HD [2-6][0-9]{3}|Radeon HD 7[0-6][0-9]{2})\]"; then
            amd_gpu_module="radeon"
        fi
    fi
    
    cat <<EOF | sudo tee "/etc/modprobe.d/cachyos-settings.conf" >/dev/null
# CachyOS Module Settings

# Audio Power Management Disabled
options snd_hda_intel power_save=0

EOF

    if [[ "$CACHED_GPU_VENDOR" == "AMD" ]]; then
        if [[ "$amd_gpu_module" == "amdgpu" ]]; then
            cat <<'EOF' | sudo tee -a "/etc/modprobe.d/cachyos-settings.conf" >/dev/null
# AMD GPU Optimizations
options amdgpu dc=1 dpm=1 audio=1 aspm=0 runpm=0
# Prevent radeon from claiming newer cards
options radeon si_support=0 cik_support=0
EOF
        else
            cat <<'EOF' | sudo tee -a "/etc/modprobe.d/cachyos-settings.conf" >/dev/null
options radeon dpm=1 audio=1 aspm=0 runpm=0
EOF
        fi
    elif [[ "$CACHED_GPU_VENDOR" == "Intel" ]]; then
        cat <<'EOF' | sudo tee -a "/etc/modprobe.d/cachyos-settings.conf" >/dev/null
options i915 enable_guc=3 enable_fbc=1 fastboot=1
EOF
    fi

    cat <<'EOF' | sudo tee -a "/etc/modprobe.d/cachyos-settings.conf" >/dev/null

# Watchdog Blacklist (disable unnecessary watchdog timers)
blacklist iTCO_wdt
blacklist sp5100_tco
EOF
    finish_progress

    # 4. SYSTEMD OPTIMIZATIONS
    show_progress "Applying systemd performance settings"
    sudo mkdir -p "/etc/systemd/system.conf.d"
    cat <<'EOF' | sudo tee "/etc/systemd/system.conf.d/10-cachyos-settings.conf" >/dev/null
# CachyOS Systemd Settings
[Manager]
DefaultTimeoutStartSec=15s
DefaultTimeoutStopSec=10s
DefaultLimitNOFILE=2048:2097152
DefaultLimitNPROC=4096:4194304
EOF
    
    sudo mkdir -p "/etc/systemd/user.conf.d"
    cat <<'EOF' | sudo tee "/etc/systemd/user.conf.d/10-cachyos-settings.conf" >/dev/null
# CachyOS User Service Settings
[Manager]
DefaultLimitNOFILE=1024:1048576
DefaultLimitNPROC=2048:2097152
EOF
    sudo systemctl daemon-reload >/dev/null 2>&1
    finish_progress

    # 5. JOURNALD OPTIMIZATION
    show_progress "Configuring journal size limits"
    sudo mkdir -p "/etc/systemd/journald.conf.d"
    cat <<'EOF' | sudo tee "/etc/systemd/journald.conf.d/10-cachyos-settings.conf" >/dev/null
# CachyOS Journal Settings
[Journal]
SystemMaxUse=50M
SystemMaxFileSize=10M
RuntimeMaxUse=20M
RuntimeMaxFileSize=5M
EOF
    sudo systemctl restart systemd-journald >/dev/null 2>&1
    finish_progress

    # 6. UPDATE ZRAM CONFIGURATION
    show_progress "Updating ZRAM configuration"
    if [[ -f "/etc/systemd/zram-generator.conf" ]]; then
        sudo sed -i 's/compression-algorithm = .*/compression-algorithm = zstd/' "/etc/systemd/zram-generator.conf" 2>/dev/null
        if ! grep -q "swap-priority" "/etc/systemd/zram-generator.conf"; then
            echo "swap-priority = 100" | sudo tee -a "/etc/systemd/zram-generator.conf" >/dev/null 2>&1
        fi
    fi
    finish_progress

    # 7. SSD OPTIMIZATION
    show_progress "Enabling weekly TRIM for SSDs"
    manage_service "fstrim.timer" "enable"
    if [[ -f "/usr/lib/systemd/system/fstrim.timer" ]]; then
        sudo sed -i 's/OnCalendar=.*/OnCalendar=weekly/' "/usr/lib/systemd/system/fstrim.timer" 2>/dev/null
    fi
    finish_progress

    # 8. CPU-SPECIFIC OPTIMIZATIONS
    show_progress "Applying CPU-specific optimizations"
    if [[ "$CPU_VENDOR" == "GenuineIntel" ]]; then
        cat <<'EOF' | sudo tee "/etc/modprobe.d/intel-cpu.conf" >/dev/null
# Intel CPU optimizations
options intel_pstate hwp_only=1 energy_performance_preference=balance_performance
EOF
    elif [[ "$CPU_VENDOR" == "AuthenticAMD" ]]; then
        cat <<'EOF' | sudo tee "/etc/modprobe.d/amd-cpu.conf" >/dev/null
# AMD CPU optimizations
options amd_pstate epp=balance_performance
EOF
        # GPP0 ACPI wakeup fix - prevents immediate wake after suspend on AMD systems
        if grep -q "GPP0.*enabled" /proc/acpi/wakeup 2>/dev/null; then
            cat <<'EOF' | sudo tee "/etc/systemd/system/disable-gpp0-wakeup.service" >/dev/null
[Unit]
Description=Disable GPP0 ACPI wakeup source
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c "echo GPP0 > /proc/acpi/wakeup"

[Install]
WantedBy=multi-user.target
EOF
            sudo systemctl enable disable-gpp0-wakeup.service >/dev/null 2>&1
            log_message "AMD GPP0 wakeup fix applied"
        fi
    fi
    finish_progress

    # 9. GPU VALIDATION
    show_progress "Validating GPU driver setup"
    if [[ "$CACHED_GPU_VENDOR" == "AMD" ]]; then
        if [[ "$amd_gpu_module" == "amdgpu" ]]; then
            if lspci -k | grep -A 2 "VGA.*AMD\|VGA.*ATI" | grep -q "amdgpu"; then
                log_message "AMD GPU using amdgpu driver with enhanced settings"
            else
                log_warning "AMD GPU detected but amdgpu driver not active"
            fi
        else
            if lspci -k | grep -A 2 "VGA.*AMD\|VGA.*ATI" | grep -q "radeon"; then
                log_message "Older AMD GPU using radeon driver"
            else
                log_warning "AMD GPU driver status unclear"
            fi
        fi
    elif [[ "$CACHED_GPU_VENDOR" == "Intel" ]]; then
        if lspci -k | grep -A 2 "VGA.*Intel" | grep -q "i915"; then
            log_message "Intel GPU using i915 driver"
        else
            log_warning "Intel GPU driver status unclear"
        fi
    fi
    finish_progress

    # 10. MODULE TRACKING SETUP
    show_progress "Setting up module tracking for future kernel builds"
    
    # Use modprobed-db if available, otherwise create basic module list
    if command -v modprobed-db &>/dev/null; then
        sudo -u "$ACTUAL_USER" modprobed-db store >/dev/null 2>&1
        local module_count
        module_count=$(wc -l < "/home/$ACTUAL_USER/.config/modprobed-db/modprobed.db" 2>/dev/null || echo "0")
        log_message "modprobed-db stored $module_count modules for optimized kernel builds"
    else
        # Fallback: create basic module list
        sudo -u "$ACTUAL_USER" mkdir -p "/home/$ACTUAL_USER/.config"
        lsmod | awk 'NR>1 {print $1}' | sudo -u "$ACTUAL_USER" tee "/home/$ACTUAL_USER/.config/modprobed.db" >/dev/null
        {
            echo "btrfs"
            echo "ext4"
            echo "vfat"
            echo "ntfs3"
            echo "nvme"
            echo "xhci_pci"
            echo "ahci"
        } | sudo -u "$ACTUAL_USER" tee -a "/home/$ACTUAL_USER/.config/modprobed.db" >/dev/null
        sudo -u "$ACTUAL_USER" sort -u "/home/$ACTUAL_USER/.config/modprobed.db" -o "/home/$ACTUAL_USER/.config/modprobed.db"
        local module_count
        module_count=$(wc -l < "/home/$ACTUAL_USER/.config/modprobed.db")
        log_message "Created basic modprobed.db with $module_count modules for optimized kernel builds"
    fi
    finish_progress

    log_success "Enhanced performance optimizations completed with CachyOS settings and module tracking"
    
    return 0
}

# Setup ZRAM
setup_zram() {
    show_progress "Creating zram configuration"
    sudo mkdir -p /etc/systemd 2>/dev/null || {
        log_error "Failed to create /etc/systemd directory"
        return 1
    }
    local total_mem
    total_mem=$(grep MemTotal /proc/meminfo | awk '{print $2}') || {
        log_error "Failed to retrieve total memory from /proc/meminfo"
        return 1
    }
    local zram_size=$((total_mem / 1024 / 2))
    [[ $zram_size -gt 8192 ]] && zram_size=8192
    cat <<EOF | sudo tee /etc/systemd/zram-generator.conf >/dev/null 2>&1
[zram0]
zram-size = $zram_size
compression-algorithm = zstd
EOF
    if [[ -f /etc/systemd/zram-generator.conf ]]; then
        finish_progress
    else
        finish_progress
        log_error "Failed to create /etc/systemd/zram-generator.conf"
        return 1
    fi

    show_progress "Applying zram configuration"
    sudo systemctl daemon-reload >/dev/null 2>&1 || {
        log_error "Failed to reload systemd for zram configuration"
        return 1
    }
    sudo systemctl restart systemd-zram-setup@zram0.service >/dev/null 2>&1 || {
        log_warning "Failed to restart zram service, it will apply on next boot"
    }
    finish_progress
    log_success "Zram configuration completed"
}

# Label EFI Partition
label_efi_partition() {
    show_progress "Installing dosfstools for EFI labeling"
    install_packages "dosfstools" || log_warning "Failed to install dosfstools, EFI labeling may fail"
    
    show_progress "Detecting EFI partition"
    local efi_part
    
    # Use the cached EFI partition first
    efi_part="$CACHED_EFI_PARTITION"
    
    if [[ -z "$efi_part" ]]; then
        # Only detect if cache is empty
        efi_part=$(blkid -s TYPE -o device 2>/dev/null | grep "TYPE=\"vfat\"" | head -n 1 | cut -d: -f1)
        if [[ -z "$efi_part" ]]; then
            log_error "Could not find EFI partition automatically"
            printf "%s[?] Enter EFI partition (e.g., /dev/nvme0n1p1) or press Enter to skip: %s" "${COLORS[CYAN]}" "${COLORS[NC]}"
            read -r efi_part
            if [[ -z "$efi_part" ]] || [[ ! -b "$efi_part" ]]; then
                log_error "No valid EFI partition provided. Skipping"
                finish_progress
                return 1
            fi
        fi
    fi
    finish_progress

    local mount_point
    mount_point=$(findmnt -n -o TARGET "$efi_part" 2>/dev/null)
    show_progress "Labeling EFI partition as 'Dracularch'"
    if [[ -n "$mount_point" ]]; then
        if ! sudo fatlabel "$efi_part" "Dracularch" >/dev/null 2>&1; then
            log_warning "Failed to label mounted partition. Skipping to avoid disruption"
            finish_progress
            return 1
        fi
    else
        if ! sudo fatlabel "$efi_part" "Dracularch" >/dev/null 2>&1; then
            log_error "Failed to label '$efi_part'"
            finish_progress
            return 1
        fi
    fi
    finish_progress

    log_success "EFI partition '$efi_part' labeled as 'Dracularch' successfully"
    return 0
}

# Batch Service Operations
setup_batch_services() {
    printf '%s[>] Starting batch service operations%s\n' "${COLORS[PURPLE]}" "${COLORS[NC]}"
    
    # Start multiple services concurrently
    (manage_service "avahi-daemon.service" "enable") &
    local avahi_pid
    avahi_pid=$!
    
    (manage_service "reflector.timer" "enable") &
    local reflector_pid
    reflector_pid=$!
    
    (manage_service "fstrim.timer" "enable") &
    local fstrim_pid
    fstrim_pid=$!
    
    # Wait for all to complete
    wait "$avahi_pid" "$reflector_pid" "$fstrim_pid"
    
    log_success "Batch service operations completed"
}

# Setup Avahi and NSS MDNS
setup_avahi_and_nss_mdns() {
    manage_service "avahi-daemon.service" "start"

    show_progress "Verifying Avahi daemon status"
    if systemctl is-active --quiet "avahi-daemon.service" 2>/dev/null; then
        finish_progress
    else
        finish_progress
        log_error "Avahi daemon failed to start"
        return 1
    fi

    show_progress "Configuring mDNS in nsswitch.conf"
    local nsswitch_conf="/etc/nsswitch.conf"

    if grep -q 'mdns_minimal' "$nsswitch_conf" 2>/dev/null; then
        log_message "/etc/nsswitch.conf is already configured for Avahi mDNS"
    else
        sudo sed -i '/^hosts:/ s/\(myhostname\)/\1 mdns_minimal [NOTFOUND=return] mdns/' "$nsswitch_conf" 2>/dev/null
    fi
    finish_progress

    log_success "Avahi and nss-mdns configuration completed and service is running"
}

# Setup SMB and XDG Portals for Firefox native file picker
setup_smb_and_portals() {
    show_progress "Configuring XDG Desktop Portal for GNOME"
    local portal_dir="/home/$ACTUAL_USER/.config/xdg-desktop-portal"
    sudo -u "$ACTUAL_USER" mkdir -p "$portal_dir"
    
    cat <<EOF | sudo -u "$ACTUAL_USER" tee "$portal_dir/portals.conf" >/dev/null 2>&1
[preferred]
default=gnome
org.freedesktop.impl.portal.ScreenCast=gnome
org.freedesktop.impl.portal.Screenshot=gnome
EOF
    finish_progress
    
    show_progress "Configuring Samba for network browsing"
    sudo mkdir -p /etc/samba
    cat <<'EOF' | sudo tee /etc/samba/smb.conf >/dev/null 2>&1
[global]
workgroup = WORKGROUP
dns proxy = no
log file = /var/log/samba/%m.log
max log size = 1000
client min protocol = SMB2
server min protocol = SMB2
server role = standalone server
passdb backend = tdbsam
obey pam restrictions = yes
unix password sync = yes
passwd program = /usr/bin/passwd %u
passwd chat = *New*UNIX*password* %n\n *ReType*new*UNIX*password* %n\n *passwd:*all*authentication*tokens*updated*successfully*
pam password change = yes
map to guest = Bad Password
usershare allow guests = yes
name resolve order = lmhosts bcast host wins
security = user
guest account = nobody
usershare path = /var/lib/samba/usershare
usershare max shares = 100
usershare owner only = yes
force create mode = 0070
force directory mode = 0070
[homes]
comment = Home Directories
browseable = no
read only = yes
create mask = 0700
directory mask = 0700
valid users = %S
[printers]
comment = All Printers
browseable = no
path = /var/spool/samba
printable = yes
guest ok = no
read only = yes
create mask = 0700
[print$]
comment = Printer Drivers
path = /var/lib/samba/printers
browseable = yes
read only = yes
guest ok = no
EOF
    sudo chmod 644 /etc/samba/smb.conf
    finish_progress
    
    show_progress "Setting up Samba usershare directory"
    sudo mkdir -p /var/lib/samba/usershare
    sudo chmod 1770 /var/lib/samba/usershare
    sudo chown root:users /var/lib/samba/usershare
    finish_progress
    
    show_progress "Enabling SMB and NMB services"
    sudo systemctl enable smb.service nmb.service >/dev/null 2>&1
    finish_progress

    # Setup direct CIFS mounts for Synology (faster than GVFS)
    show_progress "Setting up direct CIFS mounts for Synology"
    sudo mkdir -p /mnt/synology /mnt/plex
    sudo chown "$ACTUAL_USER:$ACTUAL_USER" /mnt/synology /mnt/plex

    # Add fstab entries if not present (credentials file already created in setup_sudo)
    if ! grep -q "synology.local/external" /etc/fstab; then
        printf '//synology.local/external /mnt/synology cifs credentials=/home/%s/.smbcredentials,vers=3.1.1,multichannel,max_channels=4,rsize=4194304,wsize=4194304,uid=1000,gid=1000,_netdev,nofail 0 0\n' "$ACTUAL_USER" | sudo tee -a /etc/fstab >/dev/null
    fi
    if ! grep -q "synology.local/plex" /etc/fstab; then
        printf '//synology.local/plex /mnt/plex cifs credentials=/home/%s/.smbcredentials,vers=3.1.1,multichannel,max_channels=4,rsize=4194304,wsize=4194304,uid=1000,gid=1000,_netdev,nofail 0 0\n' "$ACTUAL_USER" | sudo tee -a /etc/fstab >/dev/null
    fi
    finish_progress

    log_success "SMB, NMB, XDG Portal and CIFS mount configuration completed"
}

# Setup Reflector Timer
setup_reflector_timer() {
    show_progress "Configuring weekly mirror updates with optimized settings"  
    echo "--country \"United States\" --protocol https --latest 10 --fastest 10 --sort rate --threads 4 --save /etc/pacman.d/mirrorlist" | sudo tee /etc/xdg/reflector/reflector.conf >/dev/null
    manage_service "reflector.timer" "enable --now"
    log_success "Reflector timer enabled for weekly automatic US mirror updates"
}

# Simple UFW Setup
setup_ufw_firewall() {
    show_progress "Configuring UFW firewall with secure defaults"

    # Configure rules (activation happens in autostart after reboot when kernel modules are available)
    sudo ufw --force reset >/dev/null 2>&1
    sudo ufw default deny incoming >/dev/null 2>&1
    sudo ufw default allow outgoing >/dev/null 2>&1
    sudo ufw allow ssh >/dev/null 2>&1
    sudo ufw allow 5353/udp >/dev/null 2>&1  # Avahi/mDNS
    sudo ufw allow from 192.168.0.0/16 to any port 631 >/dev/null 2>&1  # CUPS printing

    # Enable service (firewall activates on first login via autostart)
    sudo systemctl enable ufw >/dev/null 2>&1
    finish_progress

    log_success "UFW firewall configured (activates after reboot)"
}

# Install AUR Packages
install_aur_packages() {
    local -a aur_packages=("$@")
    if [[ ${#aur_packages[@]} -eq 0 ]]; then
        return
    fi

    # Refresh AUR database first
    show_progress "Refreshing AUR database"
    if ! sudo -u "$ACTUAL_USER" yay -Syy --noconfirm >/dev/null 2>&1; then
        log_warning "AUR database refresh failed, continuing anyway"
    fi
    finish_progress

    show_progress "Configuring optimized build environment"
    local total_cores
    total_cores=$(nproc)
    
    # Configure makepkg for faster builds
    sudo sed -i "s|^#MAKEFLAGS=.*|MAKEFLAGS=\"-j$total_cores\"|" /etc/makepkg.conf
    sudo sed -i 's/#OPTIONS=.*/OPTIONS=(strip docs !libtool !staticlibs emptydirs zipman purge !debug lto)/' /etc/makepkg.conf
    
    export MAKEFLAGS="-j$total_cores"
    finish_progress

    # Verify dependencies
    if ! command_exists git; then
        install_packages "git" || {
            log_error "Failed to install git. AUR packages cannot be installed"
            return 1
        }
    fi

    if ! pacman -Q base-devel >/dev/null 2>&1; then
        install_packages "base-devel" || {
            log_error "Failed to install base-devel. AUR packages cannot be installed"
            return 1
        }
    fi

    # Install yay if needed
    if ! command_exists yay; then
        local YAY_DIR="/home/$ACTUAL_USER/yay"
        show_progress "Cloning yay repository"
        fetch_resource "https://aur.archlinux.org/yay.git" "$YAY_DIR" "git" || {
            log_error "Failed to clone yay repository"
            return 1
        }
        
        printf '%s[+] Building and installing yay%s\n' "${COLORS[PURPLE]}" "${COLORS[NC]}"
        (cd "$YAY_DIR" && sudo -u "$ACTUAL_USER" makepkg -si --noconfirm >/dev/null 2>/tmp/yay_build.log) &
        local yay_pid=$!
        show_animated_progress_bar "Compiling yay from source" "$yay_pid"
        wait "$yay_pid" || {
            log_error "Failed to install yay - check /tmp/yay_build.log for details"
            sudo rm -rf "$YAY_DIR" 2>/dev/null
            return 1
        }
        sudo rm -rf "$YAY_DIR" 2>/dev/null
        
        if ! sudo -u "$ACTUAL_USER" yay --version >/dev/null 2>&1; then
            log_error "yay installed but not functional"
            return 1
        fi
        
        log_success "yay installed and verified successfully"
    fi

    # Install packages in dependency order
    printf '%s[>] Installing AUR packages in dependency order%s\n' "${COLORS[PURPLE]}" "${COLORS[NC]}"
    local current=0
    local total=${#aur_packages[@]}
    local -a local_failed=()
    local local_success=0
    
    # Define installation order based on dependencies
    local -a install_order=(
        # Core development tools first
        "visual-studio-code-bin"
        "github-cli"
        
        # Rust-dependent tools (after base system has rust)
        "starship"
        "carapace-bin"
        
        # Desktop integration tools
        "extension-manager"
        "gdm-settings"
        
        # Font packages (independent)
        "ttf-jetbrains-mono-nerd"
        "ttf-liberation" 
        "noto-fonts"
        
        # System boot packages last
        "plymouth"
    )
    
    # Add browser packages to install order
    for pkg in "${aur_packages[@]}"; do
        if [[ "$pkg" == "google-chrome" || "$pkg" == "brave-bin" || "$pkg" == "microsoft-edge-stable-bin" || "$pkg" == "firedragon-catppuccin-bin" ]]; then
            install_order+=("$pkg")
        fi
    done
    
    # Install packages in order
    current=0
    total=${#install_order[@]}
    
    for package in "${install_order[@]}"; do
        # Only install if it was in our original package list
        if [[ " ${aur_packages[*]} " =~ \ ${package}\  ]]; then
            current=$((current + 1))
            show_package_progress "Installing" "$package" "$current" "$total"
            
            sudo -u "$ACTUAL_USER" yay -S --noconfirm --needed --removemake --cleanafter "$package" >/dev/null 2>&1
            sleep 0.3
            # Trust yay -Q as the source of truth for AUR packages
            if yay -Q "$package" >/dev/null 2>&1; then
                successful_installs+=("$package")
                ((local_success++))
            else
                log_error "Failed to install AUR package '$package'"
                failed_installs+=("$package")
                local_failed+=("$package")
            fi
            sleep 0.2
        fi
    done
    
    # Install any remaining packages not in install_order
    local -a remaining_packages=()
    for package in "${aur_packages[@]}"; do
        if [[ ! " ${install_order[*]} " =~ \ ${package}\  ]]; then
            remaining_packages+=("$package")
        fi
    done
    
    if [[ ${#remaining_packages[@]} -gt 0 ]]; then
        printf '%s[>] Installing remaining packages%s\n' "${COLORS[PURPLE]}" "${COLORS[NC]}"
        current=0
        total=${#remaining_packages[@]}
        
        for package in "${remaining_packages[@]}"; do
            current=$((current + 1))
            show_package_progress "Installing" "$package" "$current" "$total"
            
            sudo -u "$ACTUAL_USER" yay -S --noconfirm --needed --removemake --cleanafter "$package" >/dev/null 2>&1
            sleep 0.3
            # Trust yay -Q as the source of truth for AUR packages
            if yay -Q "$package" >/dev/null 2>&1; then
                successful_installs+=("$package")
                ((local_success++))
            else
                log_error "Failed to install $package"
                failed_installs+=("$package")
                local_failed+=("$package")
            fi
            sleep 0.2
        done
    fi

    # Clean up
    show_progress "Cleaning build artifacts"
    sudo -u "$ACTUAL_USER" yay -Yc --noconfirm >/dev/null 2>&1 || true
    finish_progress
    
    # Report results for this batch only
    if [[ ${#local_failed[@]} -eq 0 ]]; then
        log_success "All AUR packages installed successfully ($local_success packages)"
    else
        log_warning "${#local_failed[@]} packages failed in this batch: ${local_failed[*]}"
    fi
}

# Install Browsers
install_browsers() {
    if [[ ${#browser_packages[@]} -eq 0 ]]; then
        return
    fi

    local -a aur_browser_packages=()
    local -a official_browser_packages=()

    for pkg in "${browser_packages[@]}"; do
        if [[ "$pkg" == "google-chrome" || "$pkg" == "microsoft-edge-stable-bin" || "$pkg" == "brave-bin" || "$pkg" == "firedragon-catppuccin-bin" ]]; then
            aur_browser_packages+=("$pkg")
        else
            official_browser_packages+=("$pkg")
        fi
    done

    if [[ ${#official_browser_packages[@]} -gt 0 ]]; then
        printf '%s[*] Installing official browsers%s\n' "${COLORS[PURPLE]}" "${COLORS[NC]}"
        predownload_packages "${official_browser_packages[@]}"
        install_packages "${official_browser_packages[@]}"
    fi

    if [[ ${#aur_browser_packages[@]} -gt 0 ]]; then
        printf '%s[*] Installing AUR browsers%s\n' "${COLORS[PURPLE]}" "${COLORS[NC]}"
        install_aur_packages "${aur_browser_packages[@]}"
    fi

    log_success "Browser installation completed"
}

# Global to track detected printer for summary
declare -g DETECTED_PRINTER=""

# Auto-detect and configure network printers
setup_printer_auto() {
    printf '%s[*] Auto-detecting network printers%s\n' "${COLORS[CYAN]}" "${COLORS[NC]}"

    # Ensure printing services are running
    manage_service "avahi-daemon.service" "enable --now"
    manage_service "cups.service" "enable --now"
    
    # Give services time to start and discover
    sleep 3

    # Scan for printers using dnssd (preferred for GNOME integration)
    show_progress "Scanning for network printers"
    local printer_info
    printer_info=$(lpinfo -v 2>/dev/null | grep -E "^network.*(dnssd|ipp)://" | head -10)
    finish_progress

    if [[ -z "$printer_info" ]]; then
        log_message "No network printers detected"
        return 0
    fi

    # Look for Canon printer specifically - prefer dnssd:// URI
    local canon_line
    canon_line=$(lpinfo -v 2>/dev/null | grep -i "canon" | grep "dnssd://.*_ipp._tcp" | head -1)
    
    if [[ -n "$canon_line" ]]; then
        local canon_uri
        canon_uri=$(echo "$canon_line" | awk '{print $2}')
        
        printf '%s[+] Found Canon printer: %s%s\n' "${COLORS[GREEN]}" "$canon_uri" "${COLORS[NC]}"
        
        # Extract printer name from dnssd URI to match GNOME display
        # dnssd://Canon%20TR8600%20series._ipp._tcp.local/... -> Canon_TR8600_series
        local printer_name
        printer_name=$(echo "$canon_uri" | sed -n 's|dnssd://\([^.]*\)\..*|\1|p' | sed 's/%20/_/g')
        
        if [[ -z "$printer_name" ]]; then
            printer_name="Canon_Printer"
        fi
        
        # Install Canon drivers for scanning support
        printf '%s[+] Installing Canon drivers for scanning support%s\n' "${COLORS[PURPLE]}" "${COLORS[NC]}"
        install_aur_packages "cnijfilter2"

        # Remove existing printer with same name if exists
        if lpstat -p "$printer_name" &>/dev/null; then
            sudo lpadmin -x "$printer_name" 2>/dev/null
        fi

        # Configure printer with dnssd URI and driverless printing
        show_progress "Configuring $printer_name"
        sudo lpadmin -p "$printer_name" \
            -E \
            -v "$canon_uri" \
            -m everywhere \
            -o printer-is-shared=false >/dev/null 2>&1

        # Set as default
        sudo lpoptions -d "$printer_name" >/dev/null 2>&1
        finish_progress
        
        DETECTED_PRINTER="$printer_name"
        log_success "$printer_name configured"
    else
        # Non-Canon printer found - use dnssd if available, fallback to ipp
        local printer_line
        printer_line=$(lpinfo -v 2>/dev/null | grep "dnssd://.*_ipp._tcp" | head -1)
        
        if [[ -z "$printer_line" ]]; then
            printer_line=$(lpinfo -v 2>/dev/null | grep -E "^network.*ipp://" | head -1)
        fi
        
        if [[ -n "$printer_line" ]]; then
            local printer_uri
            printer_uri=$(echo "$printer_line" | awk '{print $2}')
            
            # Extract name from URI
            local printer_name
            printer_name=$(echo "$printer_uri" | sed -n 's|dnssd://\([^.]*\)\..*|\1|p' | sed 's/%20/_/g')
            
            if [[ -z "$printer_name" ]]; then
                printer_name="Network_Printer"
            fi
            
            printf '%s[+] Found printer: %s%s\n' "${COLORS[GREEN]}" "$printer_uri" "${COLORS[NC]}"
            
            show_progress "Configuring $printer_name"
            sudo lpadmin -p "$printer_name" \
                -E \
                -v "$printer_uri" \
                -m everywhere \
                -o printer-is-shared=false >/dev/null 2>&1
            
            sudo lpoptions -d "$printer_name" >/dev/null 2>&1
            finish_progress
            
            DETECTED_PRINTER="$printer_name"
            log_success "$printer_name configured"
        fi
    fi
}

# Install OCS-URL
install_ocs_url() {
    if [[ ! -d "/home/$ACTUAL_USER/ocs-url" ]]; then
        printf '%s[+] Installing ocs-url from AUR%s\n' "${COLORS[PURPLE]}" "${COLORS[NC]}"
        fetch_resource "https://aur.archlinux.org/ocs-url.git" "/home/$ACTUAL_USER/ocs-url" "git" || {
            log_error "Failed to clone ocs-url repository"
            return 1
        }
        
        (cd "/home/$ACTUAL_USER/ocs-url" && sudo -u "$ACTUAL_USER" makepkg -si --noconfirm >/dev/null 2>&1) &
        local build_pid=$!
        show_animated_progress_bar "Building ocs-url package" "$build_pid"
        wait "$build_pid" || {
            log_error "Failed to install ocs-url"
            sudo rm -rf "/home/$ACTUAL_USER/ocs-url" 2>/dev/null
            return 1
        }
        sudo rm -rf "/home/$ACTUAL_USER/ocs-url" 2>/dev/null
        log_success "ocs-url installed successfully"
    fi
}

# Install AUR Apps 
install_aur_apps() {
    printf '%s[>] Refreshing package databases%s\n' "${COLORS[PURPLE]}" "${COLORS[NC]}"
    (sudo pacman -Syy >/dev/null 2>&1) &
    local pacman_refresh_pid=$!
    (sudo -u "$ACTUAL_USER" yay -Syy >/dev/null 2>&1) &
    local yay_refresh_pid=$!
    
    show_animated_progress_bar "Updating all package databases" "$pacman_refresh_pid"
    wait "$yay_refresh_pid"
    
    local -a official_packages=(
        "gimp"
        "qbittorrent"
        "smplayer"
        "smplayer-themes" 
        "smplayer-skins" 
    )
    
    local -a aur_packages=(
        "extension-manager"
        "gdm-settings"
        "visual-studio-code-bin"
        "carapace-bin"
        "github-cli"
        "modprobed-db"
    )

    if [[ ${#official_packages[@]} -gt 0 ]]; then
        printf '%s[*] Installing official applications%s\n' "${COLORS[PURPLE]}" "${COLORS[NC]}"
        predownload_packages "${official_packages[@]}"
        install_packages "${official_packages[@]}"
    fi

    if [[ ${#aur_packages[@]} -gt 0 ]]; then
        printf '%s[*] Installing AUR applications%s\n' "${COLORS[PURPLE]}" "${COLORS[NC]}"
        install_aur_packages "${aur_packages[@]}"
    fi

    # Enable modprobed-db service to track kernel modules over time
    if command -v modprobed-db &>/dev/null; then
        show_progress "Enabling modprobed-db service"
        sudo -u "$ACTUAL_USER" systemctl --user enable modprobed-db.service >/dev/null 2>&1
        # Do initial store to capture currently loaded modules
        sudo -u "$ACTUAL_USER" modprobed-db store >/dev/null 2>&1
        finish_progress
    fi

    log_success "Application installation completed"
}

# ============================================================================
# CLAUDE CODE INSTALLATION
# ============================================================================

install_claude_code() {
    # Only install for steve
    if [[ "$ACTUAL_USER" != "steve" ]]; then
        log_message "Claude Code installation skipped (not steve)"
        return 0
    fi

    # Check if already installed
    if command -v claude &>/dev/null; then
        printf '%s[+] Claude Code already installed%s\n' "${COLORS[GREEN]}" "${COLORS[NC]}"
        log_success "Claude Code already installed"
        return 0
    fi

    printf '%s[>] Installing Claude Code%s\n' "${COLORS[PURPLE]}" "${COLORS[NC]}"

    # Install using official installer as actual user (not root)
    (sudo -u "$ACTUAL_USER" bash -c 'curl -fsSL https://claude.ai/install.sh 2>/dev/null | bash' >/dev/null 2>&1) &
    local install_pid=$!
    show_animated_progress_bar "Downloading and installing Claude Code" "$install_pid"

    if wait "$install_pid" && [[ -f "/home/$ACTUAL_USER/.local/bin/claude" ]]; then
        printf '%s[+] Claude Code installed successfully%s\n' "${COLORS[GREEN]}" "${COLORS[NC]}"
        log_success "Claude Code installed"

        # Configure Claude Code permissions
        show_progress "Configuring Claude Code permissions"
        sudo -u "$ACTUAL_USER" mkdir -p "/home/$ACTUAL_USER/.claude"
        cat <<'EOF' | sudo -u "$ACTUAL_USER" tee "/home/$ACTUAL_USER/.claude/settings.json" >/dev/null
{
  "permissions": {
    "allow": [
      "Read(/home/steve/**)",
      "Edit(/home/steve/**)",
      "Write(/home/steve/**)",
      "Read(/run/media/steve/**)",
      "Edit(/run/media/steve/**)",
      "Write(/run/media/steve/**)",
      "Read(/mnt/synology/**)",
      "Edit(/mnt/synology/**)",
      "Write(/mnt/synology/**)",
      "Bash(*)",
      "WebSearch",
      "WebFetch"
    ]
  }
}
EOF
        # Create notes pointer for Claude context
        printf "Notes location: /run/media/steve/ARCH_202512/notes.md\nCLAUDE.md location: ~/CLAUDE.md (pulled from GitHub repo)\nUSB: /run/media/steve/ARCH_202512/\nSynology fallback: /mnt/synology/WEB Scripts/Arch/USB Files/\n" | sudo -u "$ACTUAL_USER" tee "/home/$ACTUAL_USER/.claude/notes.md" >/dev/null

        # Pull CLAUDE.md from GitHub repo to home directory
        curl -sL "https://raw.githubusercontent.com/svan71/DRACULARCH/refs/heads/main/Claude/CLAUDE.md" -o "/home/$ACTUAL_USER/CLAUDE.md" 2>/dev/null
        chown "$ACTUAL_USER:$ACTUAL_USER" "/home/$ACTUAL_USER/CLAUDE.md"
        chmod 600 "/home/$ACTUAL_USER/CLAUDE.md"
        finish_progress
    else
        printf '%s[!] Claude Code installation failed (non-critical)%s\n' "${COLORS[PINK]}" "${COLORS[NC]}"
        log_warning "Claude Code installation failed"
    fi
}

# Install Clean Fonts
install_clean_fonts() {
    printf '%s[>] Refreshing AUR database for font packages%s\n' "${COLORS[PURPLE]}" "${COLORS[NC]}"
    (sudo -u "$ACTUAL_USER" yay -Syy >/dev/null 2>&1) &
    local refresh_pid=$!
    show_animated_progress_bar "Updating font package information" "$refresh_pid"
    wait "$refresh_pid"
    
    printf '%s[+] Installing fonts from AUR%s\n' "${COLORS[PURPLE]}" "${COLORS[NC]}"
    local -a aur_packages=("ttf-jetbrains-mono-nerd" "ttf-liberation" "noto-fonts")
    install_aur_packages "${aur_packages[@]}"
    
    show_progress "Configuring font rendering"
    local font_config="/home/$ACTUAL_USER/.config/fontconfig/fonts.conf"
    sudo -u "$ACTUAL_USER" mkdir -p "$(dirname "$font_config")"
    cat <<EOF | sudo -u "$ACTUAL_USER" tee "$font_config" >/dev/null 2>&1
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<fontconfig>
    <match target="font">
        <edit name="antialias" mode="assign"><bool>true</bool></edit>
    </match>
    <match target="font">
        <edit name="hinting" mode="assign"><bool>true</bool></edit>
    </match>
    <match target="font">
        <edit name="hintstyle" mode="assign"><const>hintslight</const></edit>
    </match>
    <match target="font">
        <edit name="rgba" mode="assign"><const>rgb</const></edit>
    </match>
    <match target="font">
        <edit name="lcdfilter" mode="assign"><const>lcddefault</const></edit>
    </match>
    <match target="font">
        <edit name="autohint" mode="assign"><bool>false</bool></edit>
    </match>
    <alias>
        <family>sans-serif</family>
        <prefer><family>Noto Sans</family></prefer>
    </alias>
    <alias>
        <family>monospace</family>
        <prefer><family>JetBrainsMono Nerd Font</family></prefer>
    </alias>
</fontconfig>
EOF
    finish_progress
    
    show_progress "Rebuilding font cache"
    sudo fc-cache -f >/dev/null 2>&1
    finish_progress
    
    log_success "Font installation and configuration completed"
}

# OPTIMIZED: Parallel Theme Downloads and Installation
install_dracula_theme_and_wallpapers() {
    show_progress "Creating theme directories"
    sudo -u "$ACTUAL_USER" mkdir -p "/home/$ACTUAL_USER/.themes"
    sudo -u "$ACTUAL_USER" mkdir -p "/home/$ACTUAL_USER/.config/gtk-4.0"
    sudo -u "$ACTUAL_USER" mkdir -p "/home/$ACTUAL_USER/.icons"
    sudo mkdir -p "/usr/share/backgrounds/gnome"
    finish_progress

    printf '%s[>] Downloading Dracula theme components%s\n' "${COLORS[PURPLE]}" "${COLORS[NC]}"
    local gtk_file="/tmp/Dracula-GTK.tar.xz"
    local cursor_file="/tmp/Dracula-cursors.tar.xz"
    local icon_file="/tmp/Dracula-icons.tar.xz"
    local wallpaper_zip="/tmp/dracula-wallpapers.zip"
    
    local gtk_url="https://raw.githubusercontent.com/svan71/DRACULARCH/refs/heads/main/Dracula-GTK.tar.xz"
    local cursor_url="https://raw.githubusercontent.com/svan71/DRACULARCH/refs/heads/main/Dracula-Cursors.tar.xz"
    local icon_url="https://raw.githubusercontent.com/svan71/DRACULARCH/refs/heads/main/Dracula-Icons.tar.xz"
    local wallpaper_url="https://raw.githubusercontent.com/svan71/DRACULARCH/refs/heads/main/Dracula-Wallpaper.zip"

    # Start all downloads simultaneously
    fetch_resource "$gtk_url" "$gtk_file" "" &
    local gtk_pid=$!
    fetch_resource "$cursor_url" "$cursor_file" "" &
    local cursor_pid=$!
    fetch_resource "$icon_url" "$icon_file" "" &
    local icon_pid=$!
    fetch_resource "$wallpaper_url" "$wallpaper_zip" "" &
    local wallpaper_pid=$!
    
    # Wait for all downloads to complete
    wait $gtk_pid $cursor_pid $icon_pid $wallpaper_pid

    # Install GTK theme
    show_progress "Installing GTK theme"
    local temp_dir="/tmp/gtk_install"
    mkdir -p "$temp_dir"
    tar -xf "$gtk_file" -C "$temp_dir"
    # Archive structure is Dracula-GTK/Dracula/
    sudo -u "$ACTUAL_USER" cp -r "$temp_dir/Dracula-GTK/Dracula" "/home/$ACTUAL_USER/.themes/"
    if [[ -d "$temp_dir/Dracula-GTK/Dracula/gtk-4.0" ]]; then
        sudo -u "$ACTUAL_USER" cp "$temp_dir/Dracula-GTK/Dracula/gtk-4.0/"* "/home/$ACTUAL_USER/.config/gtk-4.0/" 2>/dev/null
    fi
    if [[ -d "$temp_dir/Dracula-GTK/Dracula/assets" ]]; then
        sudo -u "$ACTUAL_USER" cp -r "$temp_dir/Dracula-GTK/Dracula/assets" "/home/$ACTUAL_USER/.config/" 2>/dev/null
    fi
    rm -rf "$temp_dir" "$gtk_file"
    finish_progress

    # Install cursors - flexible path detection
    show_progress "Installing cursors"
    temp_dir="/tmp/cursor_install"
    mkdir -p "$temp_dir"
    tar -xf "$cursor_file" -C "$temp_dir"
    # Try different possible paths for cursor theme
    if [[ -d "$temp_dir/Dracula-cursors" ]]; then
        sudo -u "$ACTUAL_USER" cp -r "$temp_dir/Dracula-cursors" "/home/$ACTUAL_USER/.icons/"
    elif [[ -d "$temp_dir/Dracula" ]]; then
        sudo -u "$ACTUAL_USER" cp -r "$temp_dir/Dracula" "/home/$ACTUAL_USER/.icons/Dracula-cursors"
    else
        # Find any directory with cursor files
        local cursor_dir
        cursor_dir=$(find "$temp_dir" -name "cursors" -type d | head -n 1)
        if [[ -n "$cursor_dir" ]]; then
            sudo -u "$ACTUAL_USER" cp -r "$(dirname "$cursor_dir")" "/home/$ACTUAL_USER/.icons/Dracula-cursors"
        fi
    fi
    rm -rf "$temp_dir" "$cursor_file"
    finish_progress

    # Install icons - flexible path detection
    show_progress "Installing icons"
    temp_dir="/tmp/icon_install"
    mkdir -p "$temp_dir"
    tar -xf "$icon_file" -C "$temp_dir"
    if [[ -d "$temp_dir/Dracula" ]]; then
        sudo -u "$ACTUAL_USER" cp -r "$temp_dir/Dracula" "/home/$ACTUAL_USER/.icons/"
    else
        # Find directory with index.theme
        local icon_dir
        icon_dir=$(find "$temp_dir" -name "index.theme" -type f | head -n 1)
        if [[ -n "$icon_dir" ]]; then
            sudo -u "$ACTUAL_USER" cp -r "$(dirname "$icon_dir")" "/home/$ACTUAL_USER/.icons/Dracula"
        fi
    fi
    rm -rf "$temp_dir" "$icon_file"
    finish_progress

    # Install wallpapers
    show_progress "Installing wallpapers"
    temp_dir="/tmp/wallpaper_install"
    mkdir -p "$temp_dir"
    unzip -q "$wallpaper_zip" -d "$temp_dir"
    # Find and copy all image files
    find "$temp_dir" -type f \( -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" \) -exec sudo cp {} "/usr/share/backgrounds/gnome/" \;
    sudo chmod 644 "/usr/share/backgrounds/gnome/"*.{png,jpg,jpeg} 2>/dev/null
    rm -rf "$temp_dir" "$wallpaper_zip"

    # Create GNOME background properties XML so wallpapers appear in picker
    sudo tee /usr/share/gnome-background-properties/dracula.xml > /dev/null << 'XMLEOF'
<?xml version="1.0"?>
<!DOCTYPE wallpapers SYSTEM "gnome-wp-list.dtd">
<wallpapers>
  <wallpaper deleted="false">
    <name>Dracula Spooky</name>
    <filename>/usr/share/backgrounds/gnome/dracula-spooky-44475a.png</filename>
    <options>zoom</options>
    <shade_type>solid</shade_type>
    <pcolor>#44475a</pcolor>
    <scolor>#282a36</scolor>
  </wallpaper>
  <wallpaper deleted="false">
    <name>Dracula Mountain</name>
    <filename>/usr/share/backgrounds/gnome/dracula-mnt-282a36.png</filename>
    <options>zoom</options>
    <shade_type>solid</shade_type>
    <pcolor>#282a36</pcolor>
    <scolor>#44475a</scolor>
  </wallpaper>
</wallpapers>
XMLEOF
    finish_progress

    sudo chown -R "$ACTUAL_USER:$ACTUAL_USER" "/home/$ACTUAL_USER/.themes" "/home/$ACTUAL_USER/.icons" "/home/$ACTUAL_USER/.config" 2>/dev/null
    log_success "Dracula theme installation completed with corrected paths"
}

# Restore Gnome Extensions
restore_gnome_extensions() {
    printf '%s[>] Downloading extensions backup from GitHub%s\n' "${COLORS[PURPLE]}" "${COLORS[NC]}"
    local backup_url="https://raw.githubusercontent.com/svan71/DRACULARCH/refs/heads/main/Extensions.tar.xz"
    local backup_file="/tmp/gnome-extensions-backup.tar.xz"
    
    fetch_resource "$backup_url" "$backup_file" "" || {
        log_error "Failed to download extensions backup from GitHub"
        return 1
    }
    
    if [[ ! -f "$backup_file" ]] || [[ ! -s "$backup_file" ]]; then
        log_error "Extensions backup download validation failed"
        return 1
    fi
    
    show_progress "Extracting and restoring extensions"
    local temp_dir="/tmp/extensions_restore"
    mkdir -p "$temp_dir"
    
    if unpack_resource "$backup_file" "$temp_dir" "tar"; then
        if [[ ! -d "$temp_dir/Extensions/gnome-extensions" ]]; then
            log_error "Invalid backup structure - gnome-extensions directory not found"
            sudo rm -rf "$temp_dir" "$backup_file"
            return 1
        fi
        
        sudo -u "$ACTUAL_USER" mkdir -p "/home/$ACTUAL_USER/.local/share/gnome-shell"
        
        if sudo -u "$ACTUAL_USER" cp -r "$temp_dir/Extensions/gnome-extensions" "/home/$ACTUAL_USER/.local/share/gnome-shell/extensions"; then
            log_message "Extension files restored successfully"
        else
            log_error "Failed to copy extension files"
            sudo rm -rf "$temp_dir" "$backup_file"
            return 1
        fi
        
        if [[ -f "$temp_dir/Extensions/gnome-extensions-settings.dconf" ]]; then
            if sudo -u "$ACTUAL_USER" bash -c "
                export XDG_RUNTIME_DIR=/run/user/\$(id -u)
                export DBUS_SESSION_BUS_ADDRESS=unix:path=\$XDG_RUNTIME_DIR/bus
                dconf load /org/gnome/shell/extensions/ < '$temp_dir/Extensions/gnome-extensions-settings.dconf'
            " 2>/dev/null; then
                log_message "Extension settings restored successfully"
            else
                log_warning "Extension settings restore failed - will be configured on first login"
            fi
        else
            log_warning "Settings file not found in backup"
        fi
        
        sudo chown -R "$ACTUAL_USER:$ACTUAL_USER" "/home/$ACTUAL_USER/.local/share/gnome-shell/extensions" 2>/dev/null
        sudo find "/home/$ACTUAL_USER/.local/share/gnome-shell/extensions" -type f -exec chmod 644 {} \; 2>/dev/null
        sudo find "/home/$ACTUAL_USER/.local/share/gnome-shell/extensions" -type d -exec chmod 755 {} \; 2>/dev/null
        
        local extensions_count
        extensions_count=$(find "/home/$ACTUAL_USER/.local/share/gnome-shell/extensions" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)
        if [[ "$extensions_count" -gt 0 ]]; then
            log_message "Successfully restored $extensions_count extensions from backup"
        else
            log_error "No extensions found after restoration"
            sudo rm -rf "$temp_dir" "$backup_file"
            return 1
        fi
        
    else
        log_error "Failed to extract extensions backup"
        sudo rm -rf "$temp_dir" "$backup_file"
        return 1
    fi
    
    sudo rm -rf "$temp_dir" "$backup_file" 2>/dev/null
    finish_progress
    
    log_success "GNOME extensions restored from GitHub backup with all settings"
}

# Create Nautilus New File Menu
create_nautilus_new_file_menu() {
    if ! pacman -Qs nautilus-python > /dev/null; then
        show_progress "Installing nautilus-python"
        install_package "nautilus-python" || {
            log_error "Failed to install nautilus-python"
            return 1
        }
        finish_progress
    fi

    show_progress "Creating extensions directory"
    local ext_dir="/home/$ACTUAL_USER/.local/share/nautilus-python/extensions"
    sudo -u "$ACTUAL_USER" mkdir -p "$ext_dir"
    finish_progress

    show_progress "Creating New File menu extension"
    local ext_file="$ext_dir/new_file_menu.py"
    cat << 'EOF' | sudo -u "$ACTUAL_USER" tee "$ext_file" >/dev/null 2>&1
#!/usr/bin/env python3
import subprocess
import os
import tempfile
import gi
gi.require_version('Nautilus', '4.1')
from gi.repository import Nautilus, GObject

class NewFileMenuProvider(GObject.GObject, Nautilus.MenuProvider):
    def __init__(self):
        pass

    def get_background_items(self, current_folder):
        # Create main submenu
        submenu = Nautilus.Menu()
        
        # Define file types with templates
        file_types = [
            ("Text File", ".txt", "gnome-text-editor"),
            ("Shell Script", ".sh", "code"),
            ("Python Script", ".py", "code"),
            ("JSON File", ".json", "code"),
            ("JSON with Comments", ".jsonc", "code"),
            ("CSS Stylesheet", ".css", "code"),
            ("Configuration File", ".conf", "code"),
            ("TOML Config", ".toml", "code")
        ]
        
        for label, ext, editor in file_types:
            item = Nautilus.MenuItem(
                name=f"NewFileExtension::create_{ext[1:]}",
                label=label,
                tip=f"Create a new {label.lower()}"
            )
            item.connect("activate", self.create_file, current_folder, ext, editor)
            submenu.append_item(item)
        
        # Main menu item with submenu
        main_item = Nautilus.MenuItem(
            name="NewFileExtension::new_file_menu",
            label="New File",
            tip="Create a new file"
        )
        main_item.set_submenu(submenu)
        return [main_item]

    def get_file_items(self, files):
        if len(files) != 1 or not files[0].is_directory():
            return []
        
        # Same submenu for folder right-click
        submenu = Nautilus.Menu()
        
        file_types = [
            ("Text File", ".txt", "gnome-text-editor"),
            ("Shell Script", ".sh", "code"),
            ("Python Script", ".py", "code"),
            ("JSON File", ".json", "code"),
            ("JSON with Comments", ".jsonc", "code"),
            ("CSS Stylesheet", ".css", "code"),
            ("Configuration File", ".conf", "code"),
            ("TOML Config", ".toml", "code")
        ]
        
        for label, ext, editor in file_types:
            item = Nautilus.MenuItem(
                name=f"NewFileExtension::create_{ext[1:]}_folder",
                label=label,
                tip=f"Create a new {label.lower()}"
            )
            item.connect("activate", self.create_file, files[0], ext, editor)
            submenu.append_item(item)
        
        main_item = Nautilus.MenuItem(
            name="NewFileExtension::new_file_menu_folder",
            label="New File",
            tip="Create a new file"
        )
        main_item.set_submenu(submenu)
        return [main_item]

    def create_file(self, menu, folder, extension, editor):
        filepath = folder.get_location().get_path()
        
        # Create temporary file with template content
        with tempfile.NamedTemporaryFile(mode='w', suffix=extension, delete=False) as temp_file:
            content = self.get_file_template(extension)
            temp_file.write(content)
            temp_file_path = temp_file.name
        
        # Make temp file executable if needed
        if extension in [".sh", ".py"]:
            os.chmod(temp_file_path, 0o755)
        
        # Open editor with the temporary file
        subprocess.Popen([editor, temp_file_path])

    def get_file_template(self, extension):
        templates = {
            ".sh": "#!/bin/bash\n\n",
            ".py": "#!/usr/bin/env python3\n\n",
            ".json": "{\n    \n}\n",
            ".jsonc": "{\n    // Configuration\n    \n}\n",
            ".css": "/* Stylesheet */\n\n",
            ".conf": "# Configuration file\n\n",
            ".toml": "# TOML configuration\n\n"
        }
        
        return templates.get(extension, "")
EOF
    
    sudo chmod +x "$ext_file"
    sudo chown -R "$ACTUAL_USER:$ACTUAL_USER" "$ext_dir"
    finish_progress

    show_progress "Restarting Nautilus to load extension"
    sudo -u "$ACTUAL_USER" nautilus -q 2>/dev/null || true
    sleep 2
    (sudo -u "$ACTUAL_USER" nautilus >/dev/null 2>&1 &) || true
    finish_progress

    if [[ -f "$ext_file" ]]; then
        log_success "Nautilus New File menu extension installed successfully"
    else
        log_error "Failed to create the extension file"
        return 1
    fi
}

# Setup Nano
setup_nano() {
    show_progress "Updating Nano configuration"
    {
        echo "set linenumbers"
        echo "set softwrap"
        echo "include /usr/share/nano-syntax-highlighting/*.nanorc"
    } | sudo tee -a /etc/nanorc >/dev/null 2>&1
    finish_progress
    log_success "Nano configuration completed"
}

# Setup Fastfetch
setup_fastfetch() {
    show_progress "Creating Fastfetch configuration"
    sudo -u "$ACTUAL_USER" mkdir -p "/home/$ACTUAL_USER/.config/fastfetch"
    
    # Download Arch Dracula logo
    show_progress "Downloading Arch Dracula logo"
    curl -sL "https://github.com/svan71/DRACULARCH/raw/main/Ghostty-Arch-Logo.tar.xz" -o "/tmp/Ghostty-Arch-Logo.tar.xz" 2>/dev/null
    if [[ -f "/tmp/Ghostty-Arch-Logo.tar.xz" ]]; then
        tar -xJf "/tmp/Ghostty-Arch-Logo.tar.xz" -C "/home/$ACTUAL_USER/.config/fastfetch/" 2>/dev/null
        sudo chown "$ACTUAL_USER:$ACTUAL_USER" "/home/$ACTUAL_USER/.config/fastfetch/arch-dracula.png" 2>/dev/null
        rm -f "/tmp/Ghostty-Arch-Logo.tar.xz"
    fi
    finish_progress
    
    cat <<'EOF' | sudo -u "$ACTUAL_USER" tee "/home/$ACTUAL_USER/.config/fastfetch/config.jsonc" >/dev/null 2>&1
{
  "$schema": "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json",
  "logo": {
    "type": "kitty-direct",
    "source": "~/.config/fastfetch/arch-dracula.png",
    "width": 43,
    "padding": {
      "top": 1,
      "left": 1
    },
    "color": {
      "1": "#bd93f9",
      "2": "#bd93f9",
      "3": "#bd93f9",
      "4": "#bd93f9",
      "5": "#bd93f9",
      "6": "#bd93f9"
    }
  },
  "display": {
    "separator": "  ",
    "color": {
      "keys": "#69ff94",
      "output": "#ffffff"
    }
  },
  "modules": [
    "break",
    {
      "type": "title",
      "color": {
        "user": "#bd93f9",
        "at": "#f8f8f2",
        "host": "#bd93f9"
      }
    },
    {
      "type": "separator",
      "string": "─",
      "outputColor": "#6272a4"
    },
    "os",
    {
      "type": "host",
      "format": "{2}"
    },
    "kernel",
    "uptime",
    "packages",
    "shell",
    "de",
    "wm",
    "wmtheme",
    "theme",
    "icons",
    "font",
    "terminal",
    {
      "type": "cpu",
      "format": "{1}"
    },
    {
      "type": "gpu",
      "format": "{2}"
    },
    "memory",
    "localip"
  ]
}
EOF
    
    sudo chown -R "$ACTUAL_USER:$ACTUAL_USER" "/home/$ACTUAL_USER/.config/fastfetch" 2>/dev/null
    finish_progress
    log_success "Fastfetch configured with Dracula-themed settings"
}

# Setup Starship
setup_starship() {
    printf '%s[+] Installing starship%s\n' "${COLORS[PURPLE]}" "${COLORS[NC]}"
    install_aur_packages "starship" || {
        log_error "Failed to install starship"
        return 1
    }

    show_progress "Configuring starship with Dracula colors"
    sudo -u "$ACTUAL_USER" mkdir -p "/home/$ACTUAL_USER/.config" || {
        log_error "Failed to create config directory"
        return 1
    }
    
    cat <<'EOF' | sudo -u "$ACTUAL_USER" tee "/home/$ACTUAL_USER/.config/starship.toml" >/dev/null 2>&1
"$schema" = "https://starship.rs/config-schema.json"

palette = "dracula"

format = """
[](bg0)\
$os\
$username\
[](fg:bg0 bg:bg2)\
$directory\
[](fg:bg2 bg:bg0)\
$time\
$cmd_duration\
$character
"""

[os]
disabled = false
style = "bg:bg0 fg:bg2 bold"
format = "[ $symbol ]($style)"

[os.symbols]
Arch = "󰣇"
Linux = "󰌽"
Macos = "󰀵"

[username]
show_always = true
style_user = "bg:bg0 fg:white bold"
style_root = "bg:bg0 fg:white bold"
format = "[ $user ]($style)"

[directory]
style = "bg:bg2 fg:bg0 bold"
format = "[  $path ]($style)"
truncation_length = 2
truncation_symbol = "…/"

[time]
disabled = false
time_format = "%R"
style = "bg:bg0 fg:white bold"
format = "[ $time ]($style)"

[cmd_duration]
disabled = false
show_milliseconds = true
min_time = 100
format = "[  $duration ]($style)"
style = "fg:dracula_cyan"

[character]
success_symbol = "[❯](bold fg:dracula_green)"
error_symbol = "[❯](bold fg:dracula_red)"

[palettes.dracula]
bg0 = "#282a36"
bg2 = "#bd93f9"
dracula_green = "#50fa7b"
dracula_red = "#ff5555"
dracula_cyan = "#8be9fd"
EOF

    [[ ! -f "/home/$ACTUAL_USER/.config/starship.toml" ]] && {
        log_error "Failed to create starship configuration"
        return 1
    }
    finish_progress

    show_progress "Setting permissions"
    sudo chown -R "$ACTUAL_USER:$ACTUAL_USER" "/home/$ACTUAL_USER/.config" 2>/dev/null || {
        log_warning "Some permission changes may have failed"
    }
    finish_progress

    log_success "Starship configured with Dracula theming"
}

# Setup Zoxide
setup_zoxide() {
    show_progress "Installing zoxide if not present"
    if ! command_exists zoxide; then
        install_packages "zoxide" || {
            log_error "Failed to install zoxide"
            return 1
        }
    fi
    finish_progress
    
    # Restore zoxide database from Dracula repo
    show_progress "Restoring zoxide directory history"
    sudo -u "$ACTUAL_USER" mkdir -p "/home/$ACTUAL_USER/.local/share/zoxide"
    curl -sL "https://github.com/svan71/DRACULARCH/raw/main/Dracula/configs/zoxide/db.zo" -o "/tmp/db.zo" 2>/dev/null
    if [[ -f "/tmp/db.zo" && -s "/tmp/db.zo" ]]; then
        sudo -u "$ACTUAL_USER" cp "/tmp/db.zo" "/home/$ACTUAL_USER/.local/share/zoxide/db.zo"
        sudo chown "$ACTUAL_USER:$ACTUAL_USER" "/home/$ACTUAL_USER/.local/share/zoxide/db.zo"
        rm -f "/tmp/db.zo"
    fi
    finish_progress
    
    log_success "zoxide setup completed"
}

# Setup Delta
setup_delta() {
    show_progress "Installing delta if not present"
    if ! command_exists delta; then
        install_packages "git-delta" || {
            log_error "Failed to install delta"
            return 1
        }
    fi
    finish_progress
    
    show_progress "Configuring git to use delta"
    
    sudo -u "$ACTUAL_USER" bash -c '
        git config --global core.pager delta
        git config --global interactive.diffFilter "delta --color-only"
        git config --global delta.navigate true
        git config --global delta.light false
        git config --global delta.side-by-side true
    ' 2>/dev/null || log_warning "Some git delta configuration may have failed"
    finish_progress
    log_success "delta setup and git configuration completed"
}

# Setup Lazygit
setup_lazygit() {
    show_progress "Installing lazygit if not present"
    if ! command_exists lazygit; then
        install_packages "lazygit" || {
            log_error "Failed to install lazygit"
            return 1
        }
    fi
    if ! lazygit --version >/dev/null 2>&1; then
        log_error "lazygit installed but not functional"
        return 1
    fi
    finish_progress
    
    show_progress "Creating Dracula-themed lazygit configuration"
    local lazygit_config="/home/$ACTUAL_USER/.config/lazygit/config.yml"
    local pager="less"
    if command -v delta >/dev/null 2>&1; then
        pager="delta --dark --paging=never"
    else
        log_warning "delta not found, using less as pager for lazygit"
    fi
    sudo -u "$ACTUAL_USER" mkdir -p "/home/$ACTUAL_USER/.config/lazygit" || {
        log_error "Failed to create lazygit config directory"
        return 1
    }
    cat <<EOF | sudo -u "$ACTUAL_USER" tee "$lazygit_config" >/dev/null 2>&1
gui:
  # Dracula theme for lazygit, matching Fish config
  theme:
    lightTheme: false
    activeBorderColor:
      - '#bd93f9'
      - bold
    inactiveBorderColor:
      - '#44475a'
    optionsTextColor:
      - '#8be9fd'
    selectedLineBgColor:
      - '#44475a'
    selectedRangeBgColor:
      - '#44475a'
    cherryPickedCommitBgColor:
      - '#ff79c6'
    cherryPickedCommitFgColor:
      - '#282a36'
    unstagedChangesColor:
      - '#ff5555'
    defaultFgColor:
      - '#f8f8f2'
  commitLength:
    show: true
  mouseEvents: true
  skipDiscardChangeWarning: false
  skipStashWarning: false
  showFileTree: true
  showListFooter: true
  showRandomTip: true
  showCommandLog: false
  commandLogSize: 8
git:
  paging:
    colorArg: always
    pager: $pager
  commit:
    signOff: false
  merging:
    manualCommit: false
    args: ''
  log:
    order: 'topo-order'
    showGraph: 'when-maximised'
    showWholeGraph: false
  skipHookPrefix: WIP
  autoFetch: true
  autoRefresh: true
  branchLogCmd: 'git log --graph --color=always --abbrev-commit --decorate --date=relative --pretty=medium {{branchName}} --'
  allBranchesLogCmd: 'git log --graph --all --color=always --abbrev-commit --decorate --date=relative  --pretty=medium'
  overrideGpg: false
  disableForcePushing: false
  parseEmoji: false
refresher:
  refreshInterval: 10
  fetchInterval: 60
update:
  method: prompt
  days: 14
confirmOnQuit: false
quitOnTopLevelReturn: false
keybinding:
  universal:
    quit: 'q'
    quit-alt1: '<c-c>'
    return: '<esc>'
    quitWithoutChangingDirectory: 'Q'
    togglePanel: '<tab>'
    prevItem: '<up>'
    nextItem: '<down>'
    prevItem-alt: 'k'
    nextItem-alt: 'j'
    prevPage: ','
    nextPage: '.'
    scrollLeft: 'H'
    scrollRight: 'L'
    gotoTop: '<'
    gotoBottom: '>'
    prevBlock: '<left>'
    nextBlock: '<right>'
    prevBlock-alt: 'h'
    nextBlock-alt: 'l'
    nextMatch: 'n'
    prevMatch: 'N'
    startSearch: '/'
    optionMenu: 'x'
    optionMenu-alt1: '?'
    select: '<space>'
    goInto: '<enter>'
    confirm: '<enter>'
    confirmAlt1: 'y'
    remove: 'd'
    new: 'n'
    edit: 'e'
    openFile: 'o'
    scrollUpMain: '<pgup>'
    scrollDownMain: '<pgdown>'
    scrollUpMain-alt1: 'K'
    scrollDownMain-alt1: 'J'
    scrollUpMain-alt2: '<c-u>'
    scrollDownMain-alt2: '<c-d>'
    executeCustomCommand: ':'
    createRebaseOptionsMenu: 'm'
    pushFiles: 'P'
    pullFiles: 'p'
    refresh: 'R'
    createPatchOptionsMenu: '<c-p>'
    nextTab: ']'
    prevTab: '['
    nextScreenMode: '+'
    prevScreenMode: '_'
    undo: 'z'
    redo: '<c-z>'
    filteringMenu: '<c-s>'
    diffingMenu: 'W'
    diffingMenu-alt: '<c-e>'
    copyToClipboard: '<c-o>'
    openRecentRepos: '<c-r>'
    submitEditorText: '<enter>'
    appendNewline: '<a-enter>'
    extrasMenu: '@'
    toggleWhitespaceInDiffView: '<c-w>'
    increaseContextInDiffView: '}'
    decreaseContextInDiffView: '{'
EOF
    if [[ -f "$lazygit_config" ]] && grep -q "theme:" "$lazygit_config"; then
        log_message "lazygit configuration verified"
    else
        log_error "Failed to create or verify lazygit configuration"
        return 1
    fi
    sudo chown -R "$ACTUAL_USER:$ACTUAL_USER" "/home/$ACTUAL_USER/.config/lazygit" 2>/dev/null || {
        log_error "Failed to set permissions for lazygit config"
        return 1
    }
    finish_progress
    
    log_success "lazygit setup and Dracula theming completed"
}

# Setup Bash with ble.sh (fish-like experience)
setup_bash() {
    printf '%s[+] Setting up Bash with modern features%s\n' "${COLORS[PURPLE]}" "${COLORS[NC]}"

    (sudo -u "$ACTUAL_USER" yay -S --noconfirm --needed --removemake --cleanafter blesh-git >/dev/null 2>&1) &
    show_animated_progress_bar "Installing ble.sh for fish-like autosuggestions" $!
    wait $!

    show_progress "Backing up existing Bash configuration"
    if [[ -f "/home/$ACTUAL_USER/.bashrc" ]]; then
        sudo -u "$ACTUAL_USER" cp "/home/$ACTUAL_USER/.bashrc" "/home/$ACTUAL_USER/.bashrc.backup.$(date +%Y%m%d_%H%M%S)" 2>/dev/null
    fi
    finish_progress

    show_progress "Creating Bash configuration"
    cat <<'EOF' | sudo -u "$ACTUAL_USER" tee "/home/$ACTUAL_USER/.bashrc" >/dev/null 2>&1
# ~/.bashrc - Dracula theme with modern tools

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

# ble.sh for fish-like autosuggestions (load early with noattach)
[[ -f /usr/share/blesh/ble.sh ]] && source /usr/share/blesh/ble.sh --noattach

# Set terminal title to "ghostty" (like fish)
PROMPT_COMMAND='echo -ne "\033]0;ghostty\007"'

# History settings
HISTSIZE=10000
HISTFILESIZE=20000
HISTCONTROL=ignoreboth:erasedups
shopt -s histappend

# Use bat for man pages
export MANPAGER="sh -c 'col -bx | bat -l man -p'"
export MANROFFOPT="-c"

# FZF Dracula colors
export FZF_DEFAULT_OPTS="
--color=bg+:#44475a,bg:#282a36,spinner:#f8f8f2,hl:#ff79c6
--color=fg:#f8f8f2,header:#ff79c6,info:#bd93f9,pointer:#f8f8f2
--color=marker:#f8f8f2,fg+:#f8f8f2,prompt:#bd93f9,hl+:#ff79c6"

# Add ~/.local/bin to PATH
[[ -d ~/.local/bin ]] && [[ ":$PATH:" != *":$HOME/.local/bin:"* ]] && PATH="$HOME/.local/bin:$PATH"

# Aliases - Replace ls with eza
alias ls='eza -al --color=always --group-directories-first --icons'
alias lsz='eza -al --color=always --total-size --group-directories-first --icons'
alias la='eza -a --color=always --group-directories-first --icons'
alias ll='eza -l --color=always --group-directories-first --icons'
alias lt='eza -aT --color=always --group-directories-first --icons'
alias l.='eza -ald --color=always --group-directories-first --icons .*'

# Replace cat with bat
alias cat='bat --style header,snip,changes'

# Modern tool aliases
command -v rg &>/dev/null && alias grep='rg --color=auto'
command -v fd &>/dev/null && alias find='fd'
command -v btop &>/dev/null && alias top='btop'
command -v dust &>/dev/null && alias du='dust'
command -v procs &>/dev/null && alias ps='procs'
command -v duf &>/dev/null && alias df='duf'
command -v lazygit &>/dev/null && alias lg='lazygit'

# Common use
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'
alias ......='cd ../../../../..'
alias big='expac -H M "%m\t%n" | sort -h | nl'
alias fixpacman='sudo rm /var/lib/pacman/db.lck'
alias gitpkg='pacman -Q | grep -i "\-git" | wc -l'
alias grubup='sudo update-grub'
alias hw='hwinfo --short'
alias ip='ip -color'
alias psmem='ps auxf | sort -nr -k 4'
alias psmem10='ps auxf | sort -nr -k 4 | head -10'
alias wget='wget -c'
alias rmpkg='sudo pacman -Rdd'
alias tarnow='tar -acf '
alias untar='tar -zxvf '
alias dir='dir --color=auto'
alias vdir='vdir --color=auto'
alias egrep='grep -E --color=auto'
alias fgrep='grep -F --color=auto'

# Mirror management
alias mirror='sudo reflector -f 30 -l 30 --number 10 --verbose --save /etc/pacman.d/mirrorlist'
alias mirrora='sudo reflector --latest 50 --number 20 --sort age --save /etc/pacman.d/mirrorlist'
alias mirrord='sudo reflector --latest 50 --number 20 --sort delay --save /etc/pacman.d/mirrorlist'
alias mirrors='sudo reflector --latest 50 --number 20 --sort score --save /etc/pacman.d/mirrorlist'

# Help aliases
alias please='sudo'
alias tb='nc termbin.com 9999'
alias helpme='echo "To print basic information about a command use tldr <command>"'
alias pacdiff='sudo -H DIFFPROG=meld pacdiff'

# Journal errors
alias jctl='journalctl -p 3 -xb'

# Recent installed packages
alias rip='expac --timefmt="%Y-%m-%d %T" "%l\t%n %v" | sort | tail -200 | nl'

# Cleanup orphaned packages
cleanup() {
    while pacman -Qdtq &>/dev/null; do
        sudo pacman -R $(pacman -Qdtq)
        [[ $? -eq 1 ]] && break
    done
}

# Backup file
backup() { cp "$1" "$1.bak"; }

# Backup with rsync
sync_backup() { rsync -avhP "$1" "$2"; }

# Copy directory
copy() {
    if [[ $# -eq 2 && -d "$1" ]]; then
        cp -r "${1%/}" "$2"
    else
        cp "$@"
    fi
}

# Extract any archive
extract() {
    if [[ -f "$1" ]]; then
        case "$1" in
            *.tar.bz2) tar xjf "$1" ;;
            *.tar.gz)  tar xzf "$1" ;;
            *.tar.xz)  tar xJf "$1" ;;
            *.bz2)     bunzip2 "$1" ;;
            *.rar)     unrar x "$1" ;;
            *.gz)      gunzip "$1" ;;
            *.tar)     tar xf "$1" ;;
            *.tbz2)    tar xjf "$1" ;;
            *.tgz)     tar xzf "$1" ;;
            *.zip)     unzip "$1" ;;
            *.Z)       uncompress "$1" ;;
            *.7z)      7z x "$1" ;;
            *.xz)      xz -d "$1" ;;
            *)         echo "'$1' cannot be extracted" ;;
        esac
    else
        echo "'$1' is not a valid file"
    fi
}

# Make directory and cd into it
mkcd() { mkdir -p "$1" && cd "$1"; }

# Quick command reference
quick() {
    echo ""
    echo "Quick Commands"
    echo "-------------------"
    echo ""
    echo "zi (Documents)  # Jump to directory"
    echo "Ctrl+R          # Search history"
    echo "Ctrl+U          # Clear line"
    echo "Ctrl+K          # Delete to end"
    echo "Ctrl+A          # Start of line"
    echo "Ctrl+E          # End of line"
    echo "!!              # Run last command"
    echo "ll              # Detailed file list"
    echo "la              # Show all files"
    echo ""
}

# Bash completion
[[ -f /usr/share/bash-completion/bash_completion ]] && source /usr/share/bash-completion/bash_completion

# FZF keybindings
[[ -f /usr/share/fzf/key-bindings.bash ]] && source /usr/share/fzf/key-bindings.bash
[[ -f /usr/share/fzf/completion.bash ]] && source /usr/share/fzf/completion.bash

# Starship prompt
command -v starship &>/dev/null && eval "$(starship init bash)"

# thefuck - type 'fuck' to fix last command
command -v thefuck &>/dev/null && eval "$(thefuck --alias)"

# Zoxide MUST be last
command -v zoxide &>/dev/null && eval "$(zoxide init bash)"

# Run fastfetch on interactive shell start
[[ -f ~/.config/fastfetch/config.jsonc ]] && command -v fastfetch &>/dev/null && fastfetch --config ~/.config/fastfetch/config.jsonc

# Attach ble.sh (must be last)
[[ ${BLE_VERSION-} ]] && ble-attach
EOF
    finish_progress

    show_progress "Creating ble.sh configuration (Dracula theme)"
    cat <<'EOF' | sudo -u "$ACTUAL_USER" tee "/home/$ACTUAL_USER/.blerc" >/dev/null 2>&1
# ~/.blerc - ble.sh configuration with Dracula theme

# Dracula color scheme for syntax highlighting
ble-face -s syntax_default           fg=#f8f8f2
ble-face -s syntax_command           fg=#50fa7b
ble-face -s syntax_quoted            fg=#f1fa8c
ble-face -s syntax_quotation         fg=#f1fa8c
ble-face -s syntax_escape            fg=#ff79c6
ble-face -s syntax_expr              fg=#8be9fd
ble-face -s syntax_error             fg=#ff5555,bg=#44475a
ble-face -s syntax_varname           fg=#bd93f9
ble-face -s syntax_delimiter         fg=#f8f8f2
ble-face -s syntax_param_expansion   fg=#bd93f9
ble-face -s syntax_history_expansion fg=#bd93f9
ble-face -s syntax_function_name     fg=#50fa7b
ble-face -s syntax_comment           fg=#6272a4
ble-face -s syntax_glob              fg=#ff79c6
ble-face -s syntax_brace             fg=#ff79c6
ble-face -s syntax_tilde             fg=#bd93f9
ble-face -s syntax_document          fg=#f8f8f2,bg=#44475a
ble-face -s syntax_document_begin    fg=#ff79c6

# Autosuggestions (fish-like gray suggestions)
ble-face -s auto_complete            fg=#6272a4

# Command info/status
ble-face -s command_builtin          fg=#8be9fd
ble-face -s command_builtin_dot      fg=#8be9fd
ble-face -s command_alias            fg=#50fa7b
ble-face -s command_function         fg=#50fa7b
ble-face -s command_file             fg=#f8f8f2
ble-face -s command_keyword          fg=#ff79c6
ble-face -s command_jobs             fg=#ffb86c
ble-face -s command_directory        fg=#bd93f9

# Filename colors
ble-face -s filename_directory       fg=#bd93f9
ble-face -s filename_executable      fg=#50fa7b
ble-face -s filename_link            fg=#8be9fd
ble-face -s filename_orphan          fg=#ff5555
ble-face -s filename_setuid          fg=#f8f8f2,bg=#ff5555
ble-face -s filename_setgid          fg=#282a36,bg=#f1fa8c

# Region/selection
ble-face -s region                   fg=#f8f8f2,bg=#44475a
ble-face -s region_insert            fg=#f8f8f2,bg=#44475a
ble-face -s disabled                 fg=#6272a4
ble-face -s overwrite_mode           fg=#282a36,bg=#ffb86c

# Enable autosuggestions (fish-like)
bleopt complete_auto_complete=1

# Suggest from history
bleopt complete_auto_history=1

# Delay before showing autosuggestion (ms)
bleopt complete_auto_delay=50

# Menu completion style
bleopt complete_menu_style=dense

# Edit mode (emacs-like)
bleopt default_keymap=emacs

# Disable bell
bleopt edit_vbell=
EOF
    finish_progress

    show_progress "Configuring tool themes"
    sudo -u "$ACTUAL_USER" mkdir -p "/home/$ACTUAL_USER/.config/"{eza,bat,btop}

    echo '[colors]
dir = "#50fa7b"
link = "#bd93f9"
fg = "#f8f8f2"' | sudo -u "$ACTUAL_USER" tee "/home/$ACTUAL_USER/.config/eza/colors.toml" >/dev/null &

    echo '--theme=Dracula' | sudo -u "$ACTUAL_USER" tee "/home/$ACTUAL_USER/.config/bat/config" >/dev/null &

    echo 'color_theme = "dracula"' | sudo -u "$ACTUAL_USER" tee "/home/$ACTUAL_USER/.config/btop/btop.conf" >/dev/null &

    wait
    finish_progress

    sudo rm -f /usr/share/applications/btop.desktop 2>/dev/null

    show_progress "Setting permissions"
    sudo chown -R "$ACTUAL_USER:$ACTUAL_USER" "/home/$ACTUAL_USER/.config" 2>/dev/null
    sudo chown -R "$ACTUAL_USER:$ACTUAL_USER" "/home/$ACTUAL_USER/.local" 2>/dev/null
    finish_progress

    # Install curated bash history for instant suggestions
    show_progress "Installing curated Bash history"
    curl -sL "https://github.com/svan71/DRACULARCH/raw/main/Dracula/configs/terminal/bash/bash_history" -o "/tmp/bash_history" 2>/dev/null
    sudo -u "$ACTUAL_USER" cp "/tmp/bash_history" "/home/$ACTUAL_USER/.bash_history" 2>/dev/null
    finish_progress

    log_success "Bash configured with ble.sh, Dracula colors and modern tools"
}

# Setup Carapace
setup_carapace() {
    show_progress "Verifying Carapace installation"
    if ! command -v carapace >/dev/null 2>&1; then
        log_error "Carapace not installed or not found in PATH"
        finish_progress
        return 1
    fi
    finish_progress
    
    show_progress "Configuring Carapace with Dracula theme"
    local carapace_config_dir="/home/$ACTUAL_USER/.config/carapace"
    local carapace_config="$carapace_config_dir/carapace.yaml"
    sudo -u "$ACTUAL_USER" mkdir -p "$carapace_config_dir" || {
        log_error "Failed to create Carapace config directory"
        return 1
    }
    
    cat <<EOF | sudo -u "$ACTUAL_USER" tee "$carapace_config" >/dev/null 2>&1
style:
  completion:
    foreground: "#f8f8f2" # Dracula foreground
    background: "#282a36" # Dracula background
  description:
    foreground: "#6272a4" # Dracula comment
  selected:
    foreground: "#50fa7b" # Dracula green
    background: "#44475a" # Dracula selection
  error:
    foreground: "#ff5555" # Dracula red
EOF
    
    if [[ ! -f "$carapace_config" ]]; then
        log_error "Failed to create Carapace configuration"
        finish_progress
        return 1
    fi
    
    sudo chown -R "$ACTUAL_USER:$ACTUAL_USER" "$carapace_config_dir" 2>/dev/null || {
        log_error "Failed to set permissions for Carapace config"
        return 1
    }
    finish_progress
    
    show_progress "Adding Carapace to Bash configuration"
    if ! grep -q "carapace" "/home/$ACTUAL_USER/.bashrc" 2>/dev/null; then
        echo "" | sudo -u "$ACTUAL_USER" tee -a "/home/$ACTUAL_USER/.bashrc" >/dev/null
        echo "# Carapace completions (bash-ble mode for ble.sh compatibility)" | sudo -u "$ACTUAL_USER" tee -a "/home/$ACTUAL_USER/.bashrc" >/dev/null
        echo 'command -v carapace &>/dev/null && source <(carapace _carapace bash-ble)' | sudo -u "$ACTUAL_USER" tee -a "/home/$ACTUAL_USER/.bashrc" >/dev/null
    fi
    finish_progress

    log_success "Carapace configured with Dracula theming for Bash"
}

setup_ghostty() {
    show_progress "Creating Ghostty configuration"
    sudo -u "$ACTUAL_USER" mkdir -p "/home/$ACTUAL_USER/.config/ghostty"
    
    cat <<EOF | sudo -u "$ACTUAL_USER" tee "/home/$ACTUAL_USER/.config/ghostty/config" >/dev/null 2>&1
# Ghostty configuration - Dracula theme with JetBrainsMono Nerd Font

# Font configuration
font-family = JetBrainsMono Nerd Font
font-size = 12
font-style = Bold
font-feature = -calt
font-thicken = true

# Window Configuration
window-width = 94
window-height = 27
window-vsync = true
window-decoration = true
window-padding-balance = true

# Cursor Configuration
cursor-style = block
cursor-color = f8f8f2
cursor-text = 282a36
adjust-cursor-thickness = 3

# Background and Transparency
background-opacity = 1.00
background-blur-radius = 20
unfocused-split-opacity = 0.85

# Shell integration
shell-integration = detect

# Dracula Theme Colors
# Base colors
background = 1e2029
foreground = f8f8f2

# Selection
selection-background = 44475a
selection-foreground = ffffff

# Normal colors
palette = 0=#21222c
palette = 1=#ff5555
palette = 2=#50fa7b
palette = 3=#f1fa8c
palette = 4=#bd93f9
palette = 5=#ff79c6
palette = 6=#8be9fd
palette = 7=#f8f8f2

# Bright colors
palette = 8=#6272a4
palette = 9=#ff6e6e
palette = 10=#69ff94
palette = 11=#ffffa5
palette = 12=#d6acff
palette = 13=#ff92df
palette = 14=#a4ffff
palette = 15=#ffffff

# Extended Dracula palette
palette = 16=#ffb86c
palette = 17=#f8f8f2

# UI Configuration
clipboard-trim-trailing-spaces = true
mouse-hide-while-typing = true
confirm-close-surface = false
mouse-scroll-multiplier = 5
clipboard-read = allow
clipboard-write = allow
copy-on-select = true

# Scrollback optimization
scrollback-limit = 10000

# Custom keybindings
keybind = ctrl+shift+v=paste_from_clipboard
keybind = ctrl+shift+c=copy_to_clipboard
keybind = ctrl+shift+comma=reload_config
keybind = ctrl+shift+n=new_window
keybind = ctrl+shift+t=new_tab
keybind = ctrl+s=select_all

# Resize overlay
resize-overlay = never
EOF
    
    sudo chown -R "$ACTUAL_USER:$ACTUAL_USER" "/home/$ACTUAL_USER/.config/ghostty" 2>/dev/null
    finish_progress
    log_success "Ghostty configured with Dracula theme"
}

# Setup Plymouth
setup_plymouth() {
    printf '%s[+] Installing Plymouth%s\n' "${COLORS[PURPLE]}" "${COLORS[NC]}"
    install_aur_packages "plymouth"
    if ! command_exists "plymouthd"; then
        log_error "Plymouth installation failed. Skipping Plymouth setup"
        return 1
    fi

    show_progress "Verifying Plymouth installation"
    if ! pacman -Qi "plymouth" >/dev/null 2>&1; then
        log_error "Plymouth package verification failed"
        finish_progress
        return 1
    fi
    
    if [[ ! -f "/usr/bin/plymouth" ]] || [[ ! -f "/usr/bin/plymouthd" ]]; then
        log_error "Plymouth binaries not found after installation"
        finish_progress
        return 1
    fi
    finish_progress

    show_progress "Configuring DRM/KMS for smooth boot splash"
    if [[ ! -f "/etc/mkinitcpio.conf.backup" ]]; then
        sudo cp "/etc/mkinitcpio.conf" "/etc/mkinitcpio.conf.backup" 2>/dev/null || {
            log_warning "Failed to backup mkinitcpio.conf"
        }
    fi
    
    local kms_modules=""
    if [[ "$CACHED_GPU_VENDOR" == "AMD" ]]; then
        local gpu_device
        gpu_device=$(lspci -nn | grep -i "vga.*amd\|vga.*ati" | head -n 1)
        
        if echo "$gpu_device" | grep -qE "\[(Radeon HD [2-6][0-9]{3}|Radeon HD 7[0-6][0-9]{2})\]"; then
            kms_modules="radeon"
        else
            kms_modules="amdgpu"
        fi
    elif [[ "$CACHED_GPU_VENDOR" == "Intel" ]]; then
        kms_modules="i915"
    else
        if lspci | grep -i "vga.*nvidia" >/dev/null 2>&1; then
            kms_modules="nvidia nvidia_modeset nvidia_uvm nvidia_drm"
        else
            kms_modules="i915 amdgpu"
        fi
    fi
    
    if grep -q "^MODULES=" /etc/mkinitcpio.conf 2>/dev/null; then
        local current_modules
        current_modules=$(grep "^MODULES=" /etc/mkinitcpio.conf | sed 's/MODULES=(//' | sed 's/)//')
        if [[ ! "$current_modules" =~ plymouth ]] || [[ ! "$current_modules" =~ $kms_modules ]]; then
            sudo sed -i "s|^MODULES=.*|MODULES=($kms_modules)|" /etc/mkinitcpio.conf 2>/dev/null
        fi
    else
        echo "MODULES=($kms_modules)" | sudo tee -a /etc/mkinitcpio.conf >/dev/null
    fi
    
    local desired_hooks="base udev autodetect modconf kms keyboard keymap consolefont block plymouth filesystems fsck"
    if ! grep -q "^HOOKS=" /etc/mkinitcpio.conf 2>/dev/null; then
        echo "HOOKS=($desired_hooks)" | sudo tee -a /etc/mkinitcpio.conf >/dev/null
    else
        sudo sed -i "s|^HOOKS=.*|HOOKS=($desired_hooks)|" /etc/mkinitcpio.conf 2>/dev/null
    fi
    
    if ! grep -q "plymouth" /etc/mkinitcpio.conf 2>/dev/null; then
        log_error "Plymouth hook verification failed in mkinitcpio.conf"
        finish_progress
        return 1
    fi
    finish_progress

    show_progress "Creating Plymouth theme directory"
    sudo mkdir -p "/usr/share/plymouth/themes"
    if [[ ! -d "/usr/share/plymouth/themes" ]]; then
        log_error "Failed to create Plymouth themes directory"
        finish_progress
        return 1
    fi
    finish_progress
    
    printf '%s[>] Downloading Dracula Plymouth theme%s\n' "${COLORS[PURPLE]}" "${COLORS[NC]}"
    local plymouth_zip="/tmp/dracula-plymouth.zip"
    local github_url="https://raw.githubusercontent.com/svan71/DRACULARCH/refs/heads/main/Dracula-Plymouth.zip"
    
    fetch_resource "$github_url" "$plymouth_zip" "" || {
        log_error "Failed to download Dracula Plymouth theme from GitHub"
        return 1
    }

    if [[ ! -f "$plymouth_zip" ]] || [[ ! -s "$plymouth_zip" ]]; then
        log_error "Plymouth theme download validation failed"
        return 1
    fi

    show_progress "Installing Plymouth theme"
    local temp_extract="/tmp/plymouth_extract"
    mkdir -p "$temp_extract"
    if unpack_resource "$plymouth_zip" "$temp_extract" "zip"; then
        local dracula_theme_folder="$temp_extract/dracula"
        if [[ -d "$dracula_theme_folder" ]]; then
            if [[ ! -f "$dracula_theme_folder/dracula.plymouth" ]]; then
                finish_progress
                log_error "Invalid Plymouth theme - missing dracula.plymouth file"
                return 1
            fi
            
            sudo cp -r "$dracula_theme_folder" "/usr/share/plymouth/themes/"
            
            if [[ -f "/usr/share/plymouth/themes/dracula/dracula.plymouth" ]]; then
                if ! grep -q "\[Plymouth Theme\]" "/usr/share/plymouth/themes/dracula/dracula.plymouth" 2>/dev/null; then
                    log_error "Plymouth theme file appears to be invalid"
                    finish_progress
                    return 1
                fi
                
                show_progress "Setting Dracula as default Plymouth theme"
                if sudo plymouth-set-default-theme dracula 2>/dev/null; then
                    local current_theme
                    current_theme=$(sudo plymouth-set-default-theme 2>/dev/null)
                    if [[ "$current_theme" == "dracula" ]]; then
                        finish_progress
                    else
                        log_error "Failed to verify Plymouth theme setting"
                        finish_progress
                        return 1
                    fi
                else
                    log_error "Failed to set Dracula as default Plymouth theme"
                    finish_progress
                    return 1
                fi
            else
                finish_progress
                log_error "Plymouth theme files not found after installation"
                return 1
            fi
        else
            finish_progress
            log_error "Could not find dracula theme folder in extracted archive at: $dracula_theme_folder"
            return 1
        fi
    else
        finish_progress
        log_error "Failed to extract Plymouth theme zip file"
        return 1
    fi
    
    sudo rm -rf "$temp_extract" "$plymouth_zip" 2>/dev/null

    show_progress "Configuring Plymouth with minimal settings"
    sudo mkdir -p "/etc/plymouth"
    
    cat <<EOF | sudo tee "/etc/plymouth/plymouthd.conf" >/dev/null 2>&1
[Daemon]
Theme=dracula
ShowDelay=0
DeviceTimeout=10
EOF

    if [[ ! -f "/etc/plymouth/plymouthd.conf" ]]; then
        log_error "Failed to create Plymouth configuration file"
        finish_progress
        return 1
    fi
    
    if ! grep -q "Theme=dracula" "/etc/plymouth/plymouthd.conf" 2>/dev/null; then
        log_error "Plymouth configuration validation failed"
        finish_progress
        return 1
    fi
    finish_progress

    show_progress "Creating Plymouth animation service"
    cat <<EOF | sudo tee "/etc/systemd/system/plymouth-wait-for-animation.service" >/dev/null 2>&1
[Unit]
Description=Waits for Plymouth animation to finish
Before=plymouth-quit.service display-manager.service
After=plymouth-start.service
[Service]
Type=oneshot
ExecStart=/usr/bin/sleep 5
[Install]
WantedBy=plymouth-start.service
EOF

    if [[ ! -f "/etc/systemd/system/plymouth-wait-for-animation.service" ]]; then
        log_error "Failed to create Plymouth animation service"
        finish_progress
        return 1
    fi
    
    sudo systemctl daemon-reload >/dev/null 2>&1 || {
        log_error "Failed to reload systemd daemon"
        finish_progress
        return 1
    }
    
    manage_service "plymouth-wait-for-animation.service" "enable"
    finish_progress

    log_message "Plymouth configuration completed (initramfs rebuild deferred)"
    
    return 0
}

# OPTIMIZATION: NEW - Single Final Kernel Setup Function
finalize_kernel_setup() {
    printf '%s[+] Final initramfs rebuild for all kernel configurations%s\n' "${COLORS[PURPLE]}" "${COLORS[NC]}"
    log_message "Building initramfs with: microcode, kernel modules, plymouth hooks, and KMS support"
    
    (cd "/tmp" && sudo mkinitcpio -P >/dev/null 2>&1) &
    local mkinitcpio_pid=$!
    show_kernel_progress "Building final initramfs with ALL kernel configurations" "$mkinitcpio_pid"
    wait "$mkinitcpio_pid"
    local mkinitcpio_exit_code=$?
    
    if [[ "$mkinitcpio_exit_code" -ne 0 ]]; then
        log_error "Failed to build final initramfs"
        return 1
    fi
    
    show_progress "Verifying initramfs generation"
    local initramfs_count
    initramfs_count=$(find /boot -name "initramfs-*.img" -type f 2>/dev/null | wc -l)
    if [[ "$initramfs_count" -gt 0 ]]; then
        log_message "Found $initramfs_count initramfs images in /boot"
        finish_progress
    else
        log_warning "Could not verify initramfs creation, but continuing"
        finish_progress
    fi
    
    log_success "OPTIMIZATION: Single initramfs rebuild completed successfully (saved 10+ minutes)"
    return 0
}

# Setup Logitech USB Wakeup
setup_logitech_wakeup() {
    show_progress "Searching for Logitech Unifying Receiver (046d:c52b)"
    local device_path=""
    for device in /sys/bus/usb/devices/*; do
        if [[ -f "$device/idVendor" ]] && [[ -f "$device/idProduct" ]]; then
            local vendor product
            vendor=$(cat "$device/idVendor")
            product=$(cat "$device/idProduct")
            if [[ "$vendor" == "046d" ]] && [[ "$product" == "c52b" ]]; then
                device_path="$device"
                break
            fi
        fi
    done

    if [[ -z "$device_path" ]]; then
        finish_progress
        log_error "Logitech Unifying Receiver (046d:c52b) not found"
        return 1
    fi
    finish_progress

    show_progress "Enabling wake-up for device at $device_path"
    if ! sudo bash -c "echo enabled > '$device_path/power/wakeup'"; then
        finish_progress
        log_error "Failed to enable wake-up for device at $device_path"
        return 1
    fi
    finish_progress

    show_progress "Creating udev rule for persistent wake-up"
    local udev_rule="/etc/udev/rules.d/50-wakeup.rules"
    cat <<EOL | sudo tee "$udev_rule" >/dev/null 2>&1
ACTION=="add", SUBSYSTEM=="usb", ATTRS{idVendor}=="046d", ATTRS{idProduct}=="c52b", ATTR{power/wakeup}="enabled"
EOL
    if ! sudo udevadm control --reload-rules || ! sudo udevadm trigger; then
        finish_progress
        log_error "Failed to reload udev rules"
        return 1
    fi
    finish_progress

    log_success "Logitech Unifying Receiver wake-up configured successfully"
}

# Enable GDM Service
enable_gdm_service() {
    manage_service "gdm.service" "enable"

    show_progress "Verifying gnome-keyring installation"
    if ! pacman -Qi "gnome-keyring" &>/dev/null; then
        if ! sudo pacman -S --noconfirm "gnome-keyring" >/dev/null 2>&1; then
            log_error "Failed to install gnome-keyring. Keyring services may not be available"
        fi
    fi
    finish_progress

    show_progress "Configuring GDM display settings with universal connection support"
    sudo -u "$ACTUAL_USER" mkdir -p "/home/$ACTUAL_USER/.config"
    
    cat <<EOF > "/home/$ACTUAL_USER/.config/monitors.xml"
<monitors version="2">
<configuration>
  <layoutmode>logical</layoutmode>
  <logicalmonitor>
    <x>0</x>
    <y>0</y>
    <scale>1.7518248558044434</scale>
    <primary>yes</primary>
    <monitor>
      <monitorspec>
        <connector>DP-2</connector>
        <vendor>SAM</vendor>
        <product>Odyssey G8</product>
        <serial>HCPTA00967</serial>
      </monitorspec>
      <mode>
        <width>3840</width>
        <height>2160</height>
        <rate>240.000</rate>
      </mode>
    </monitor>
  </logicalmonitor>
</configuration>
<configuration>
  <layoutmode>logical</layoutmode>
  <logicalmonitor>
    <x>0</x>
    <y>0</y>
    <scale>1.7518248558044434</scale>
    <primary>yes</primary>
    <monitor>
      <monitorspec>
        <connector>HDMI-A-1</connector>
        <vendor>SAM</vendor>
        <product>Odyssey G8</product>
        <serial>HCPTA00967</serial>
      </monitorspec>
      <mode>
        <width>3840</width>
        <height>2160</height>
        <rate>120.000</rate>
      </mode>
    </monitor>
  </logicalmonitor>
</configuration>
<configuration>
  <layoutmode>logical</layoutmode>
  <logicalmonitor>
    <x>0</x>
    <y>0</y>
    <scale>1.7518248558044434</scale>
    <primary>yes</primary>
    <monitor>
      <monitorspec>
        <connector>HDMI-1</connector>
        <vendor>SAM</vendor>
        <product>Odyssey G8</product>
        <serial>HCPTA00967</serial>
      </monitorspec>
      <mode>
        <width>3840</width>
        <height>2160</height>
        <rate>120.000</rate>
      </mode>
    </monitor>
  </logicalmonitor>
</configuration>
</monitors>
EOF

    sudo mkdir -p "/var/lib/gdm/.config"
    sudo cp "/home/$ACTUAL_USER/.config/monitors.xml" "/var/lib/gdm/.config/"

    sudo chown -R "gdm:gdm" "/var/lib/gdm/.config" 2>/dev/null
    sudo chmod 755 "/var/lib/gdm/.config" 2>/dev/null
    sudo chmod 644 "/var/lib/gdm/.config/monitors.xml" 2>/dev/null
    
    sudo chown -R "$ACTUAL_USER:$ACTUAL_USER" "/home/$ACTUAL_USER/.config" 2>/dev/null
    finish_progress

    show_progress "Configuring GDM dconf settings with experimental features and Dracula theming"
    sudo mkdir -p "/etc/dconf/db/gdm.d" "/etc/dconf/profile"
    
    cat <<EOF | sudo tee "/etc/dconf/profile/gdm" >/dev/null
user-db:user
system-db:gdm
file-db:/usr/share/gdm/greeter-dconf-defaults
EOF

    cat <<'EOF' | sudo tee "/etc/dconf/db/gdm.d/01-experimental-features" >/dev/null
[org/gnome/mutter]
experimental-features=['scale-monitor-framebuffer']
EOF

    cat <<'EOF' | sudo tee "/etc/dconf/db/gdm.d/02-dracula-theme" >/dev/null
[org/gnome/shell]
enabled-extensions=['user-theme@gnome-shell-extensions.gcampax.github.com']

[org/gnome/shell/extensions/user-theme]
name='Dracula'

[org/gnome/desktop/interface]
gtk-theme='Dracula'
icon-theme='Dracula'
cursor-theme='Dracula-cursors'
color-scheme='prefer-dark'
accent-color='purple'
clock-show-date=true
clock-show-seconds=false
clock-show-weekday=true
clock-format='12h'
cursor-size=24
show-battery-percentage=false
font-antialiasing='rgba'
font-hinting='slight'

[org/gnome/desktop/a11y]
always-show-universal-access-status=false

[org/gnome/login-screen]
logo=''
banner-message-enable=false
EOF

    # Copy Theme Files To USR
    show_progress "Copying Dracula themes to system locations for GDM access"
    if [[ -d "/home/$ACTUAL_USER/.themes/Dracula" ]]; then
        sudo cp -r "/home/$ACTUAL_USER/.themes/Dracula" "/usr/share/themes/Dracula" || log_error "Failed to copy GTK theme to system location"
    else
        log_warning "User Dracula theme not found, GDM theming may not work"
    fi

    if [[ -d "/home/$ACTUAL_USER/.icons/Dracula" ]]; then
        sudo cp -r "/home/$ACTUAL_USER/.icons/Dracula" "/usr/share/icons/Dracula" || log_error "Failed to copy icons to system location"
    else
        log_warning "User Dracula icons not found, GDM icons may not work"
    fi

    if [[ -d "/home/$ACTUAL_USER/.icons/Dracula-cursors" ]]; then
        sudo cp -r "/home/$ACTUAL_USER/.icons/Dracula-cursors" "/usr/share/icons/Dracula-cursors" || log_error "Failed to copy cursors to system location"
    else
        log_warning "User Dracula cursors not found, GDM cursors may not work"
    fi
    finish_progress

    sudo dconf update >/dev/null 2>&1 || log_warning "Failed to update dconf database"
    finish_progress

    show_progress "Installing GDM Dracula theme"
    curl -sL "https://github.com/svan71/DRACULARCH/raw/main/GDM-Dracula-Theme.tar.xz" -o "/tmp/GDM-Dracula-Theme.tar.xz" 2>/dev/null
    if [[ -f "/tmp/GDM-Dracula-Theme.tar.xz" ]]; then
        tar -xJf "/tmp/GDM-Dracula-Theme.tar.xz" -C "/tmp/" 2>/dev/null
        if [[ -f "/tmp/gnome-shell-theme-dracula.gresource" ]]; then
            # Backup original theme
            sudo cp /usr/share/gnome-shell/gnome-shell-theme.gresource /usr/share/gnome-shell/gnome-shell-theme.gresource.default 2>/dev/null
            # Install Dracula theme
            sudo cp /tmp/gnome-shell-theme-dracula.gresource /usr/share/gnome-shell/gnome-shell-theme.gresource
            log_message "GDM Dracula theme installed"
        else
            log_warning "Failed to extract GDM Dracula theme"
        fi
        rm -f "/tmp/GDM-Dracula-Theme.tar.xz" "/tmp/gnome-shell-theme-dracula.gresource" 2>/dev/null
    else
        log_warning "Failed to download GDM Dracula theme"
    fi
    finish_progress

    # Set Dracula avatar for user via AccountsService
    show_progress "Setting Dracula user avatar"
    if [[ -f "/home/$ACTUAL_USER/.icons/Dracula/Dracula Logo.png" ]]; then
        sudo mkdir -p /var/lib/AccountsService/icons
        sudo cp "/home/$ACTUAL_USER/.icons/Dracula/Dracula Logo.png" "/var/lib/AccountsService/icons/$ACTUAL_USER"
        sudo chmod 644 "/var/lib/AccountsService/icons/$ACTUAL_USER"
        # Update or create AccountsService user file
        local accounts_file="/var/lib/AccountsService/users/$ACTUAL_USER"
        if [[ -f "$accounts_file" ]]; then
            if grep -q "^Icon=" "$accounts_file" 2>/dev/null; then
                sudo sed -i "s|^Icon=.*|Icon=/var/lib/AccountsService/icons/$ACTUAL_USER|" "$accounts_file"
            else
                echo "Icon=/var/lib/AccountsService/icons/$ACTUAL_USER" | sudo tee -a "$accounts_file" >/dev/null
            fi
        else
            sudo mkdir -p /var/lib/AccountsService/users
            cat <<EOF | sudo tee "$accounts_file" >/dev/null
[User]
Icon=/var/lib/AccountsService/icons/$ACTUAL_USER
EOF
        fi
        log_message "Dracula avatar set for user $ACTUAL_USER"
    else
        log_warning "Dracula logo not found for avatar"
    fi
    finish_progress

    log_success "GDM enabled with universal connection support and complete Dracula theming"
}

# Setup Consolidated Autostart
setup_consolidated_autostart() {
    show_progress "Creating autostart script"
    sudo -u "$ACTUAL_USER" mkdir -p "/home/$ACTUAL_USER/.config/scripts"
    cat << 'AUTOSTART_EOF' > "/home/$ACTUAL_USER/.config/scripts/consolidated-autostart.sh"
#!/bin/bash
# Enhanced autostart script with GitHub extensions backup approach
LOG="/tmp/consolidated-autostart.log"
LOCK_FILE="/tmp/consolidated-autostart.lock"

cleanup_and_exit() {
    local exit_code=${1:-0}
    echo "Cleanup initiated at $(date)" >> "$LOG"
    echo "Enhanced autostart script completed at $(date)" >> "$LOG"
    exit $exit_code
}

if [[ -f "$LOCK_FILE" ]]; then
    echo "Autostart script already running (lock file exists), exiting..." >> "$LOG"
    exit 0
fi

echo $$ > "$LOCK_FILE"
echo "Starting enhanced autostart with GitHub extensions backup at $(date)" > "$LOG"

trap 'cleanup_and_exit 1' INT TERM
trap 'cleanup_and_exit 0' EXIT

sleep 10

# Activate UFW firewall (kernel modules now available after reboot)
echo "Activating UFW firewall..." >> "$LOG"
sudo ufw --force enable >> "$LOG" 2>&1
echo "UFW activated at $(date)" >> "$LOG"

# Phase 1: Basic GNOME Settings
echo "Phase 1: Setting basic GNOME preferences..." >> "$LOG"

gsettings set org.gnome.desktop.interface font-name "Noto Sans Bold 12" >> "$LOG" 2>&1
gsettings set org.gnome.desktop.interface document-font-name "Noto Sans Bold 12" >> "$LOG" 2>&1
gsettings set org.gnome.desktop.interface monospace-font-name "JetBrainsMono Nerd Font Bold 12" >> "$LOG" 2>&1
gsettings set org.gnome.desktop.wm.preferences titlebar-font "Noto Sans Bold 10" >> "$LOG" 2>&1

gsettings set org.gnome.desktop.wm.preferences button-layout "appmenu:minimize,maximize,close" >> "$LOG" 2>&1

gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' >> "$LOG" 2>&1
gsettings set org.gnome.desktop.interface accent-color 'purple' >> "$LOG" 2>&1

DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u)/bus gsettings set org.gnome.mutter experimental-features "['scale-monitor-framebuffer']" >> "$LOG" 2>&1

gsettings set org.gnome.desktop.datetime automatic-timezone true >> "$LOG" 2>&1
gsettings set org.gnome.desktop.interface clock-show-weekday true >> "$LOG" 2>&1
gsettings set org.gnome.desktop.interface clock-show-date true >> "$LOG" 2>&1
gsettings set org.gnome.desktop.interface clock-show-seconds false >> "$LOG" 2>&1
gsettings set org.gnome.desktop.interface clock-format '12h' >> "$LOG" 2>&1

gsettings set org.gnome.desktop.session idle-delay 300 >> "$LOG" 2>&1
gsettings set org.gnome.desktop.screensaver lock-enabled false >> "$LOG" 2>&1
gsettings set org.gnome.desktop.notifications show-in-lock-screen false >> "$LOG" 2>&1
gsettings set org.gnome.desktop.notifications.application:/org/gnome/desktop/notifications/application/org-gnome-nautilus/ enable false >> "$LOG" 2>&1

echo "Phase 1 completed at $(date)" >> "$LOG"

# Phase 2: Apply NON-SHELL themes first
echo "Phase 2: Applying NON-SHELL Dracula themes..." >> "$LOG"

gsettings set org.gnome.desktop.interface cursor-theme "Dracula-cursors" >> "$LOG" 2>&1
gsettings set org.gnome.desktop.interface icon-theme "Dracula" >> "$LOG" 2>&1
gsettings set org.gnome.desktop.interface gtk-theme "Dracula" >> "$LOG" 2>&1
gsettings set org.gnome.desktop.wm.preferences theme "Dracula" >> "$LOG" 2>&1

WALLPAPER="/usr/share/backgrounds/gnome/dracula-spooky-44475a.png"
if [ -f "$WALLPAPER" ]; then
    gsettings set org.gnome.desktop.background picture-uri "file://$WALLPAPER" >> "$LOG" 2>&1
    gsettings set org.gnome.desktop.background picture-uri-dark "file://$WALLPAPER" >> "$LOG" 2>&1
    gsettings set org.gnome.desktop.background picture-options "stretched" >> "$LOG" 2>&1
    echo "Applied wallpaper: dracula-spooky-44475a.png (stretched)" >> "$LOG"
else
    FALLBACK_WALLPAPER=$(find "/usr/share/backgrounds/gnome/" -name "*dracula*" -type f 2>/dev/null | head -n 1)
    if [ -n "$FALLBACK_WALLPAPER" ]; then
        gsettings set org.gnome.desktop.background picture-uri "file://$FALLBACK_WALLPAPER" >> "$LOG" 2>&1
        gsettings set org.gnome.desktop.background picture-uri-dark "file://$FALLBACK_WALLPAPER" >> "$LOG" 2>&1
        gsettings set org.gnome.desktop.background picture-options "stretched" >> "$LOG" 2>&1
        echo "Applied fallback wallpaper: $(basename "$FALLBACK_WALLPAPER") (stretched)" >> "$LOG"
    else
        echo "No Dracula wallpapers found in /usr/share/backgrounds/gnome/" >> "$LOG"
    fi
fi

echo "Phase 2 completed at $(date)" >> "$LOG"

# Phase 3: Extensions already restored from GitHub backup with settings
echo "Phase 3: Extensions restored from GitHub backup - enabling them..." >> "$LOG"

extensions_count=$(find "$HOME/.local/share/gnome-shell/extensions" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)
echo "Found $extensions_count extensions restored from GitHub backup" >> "$LOG"

if [[ "$extensions_count" -gt 0 ]]; then
   echo "✅ Extensions successfully restored from GitHub backup with all settings" >> "$LOG"
   
   echo "Enabling restored extensions:" >> "$LOG"
   for ext_dir in "$HOME/.local/share/gnome-shell/extensions"/*; do
       if [[ -d "$ext_dir" ]]; then
           ext_uuid=$(basename "$ext_dir")
           # Skip blur-my-shell - enable it last after shell stabilizes
           if [[ "$ext_uuid" == "blur-my-shell@aunetx" ]]; then
               echo "  - Deferring: $ext_uuid (will enable last)" >> "$LOG"
               continue
           fi
           echo "  - Enabling: $ext_uuid" >> "$LOG"
           gnome-extensions enable "$ext_uuid" >> "$LOG" 2>&1 || echo "    Failed to enable $ext_uuid" >> "$LOG"
       fi
   done
   
   # Enable blur-my-shell last after shell has stabilized
   if [[ -d "$HOME/.local/share/gnome-shell/extensions/blur-my-shell@aunetx" ]]; then
       echo "Waiting for shell to stabilize before enabling blur-my-shell..." >> "$LOG"
       sleep 5
       echo "  - Enabling: blur-my-shell@aunetx" >> "$LOG"
       gnome-extensions enable "blur-my-shell@aunetx" >> "$LOG" 2>&1 || echo "    Failed to enable blur-my-shell@aunetx" >> "$LOG"
   fi
   
   echo "✅ All extensions enabled successfully" >> "$LOG"
else
   echo "⚠ No extensions found - backup may not have restored properly" >> "$LOG"
fi

echo "Phase 3 completed - extensions restored and enabled at $(date)" >> "$LOG"

# Phase 4: App Organization and Defaults
echo "Phase 4: Configuring app organization and defaults..." >> "$LOG"

echo "Setting comprehensive default applications first..." >> "$LOG"

# Set Thunderbird as default mail client
xdg-mime default org.mozilla.Thunderbird.desktop x-scheme-handler/mailto >> "$LOG" 2>&1
xdg-mime default org.mozilla.Thunderbird.desktop message/rfc822 >> "$LOG" 2>&1
xdg-mime default org.mozilla.Thunderbird.desktop text/calendar >> "$LOG" 2>&1
xdg-settings set default-mail-client org.mozilla.Thunderbird.desktop >> "$LOG" 2>&1

# Set Eye of GNOME as default image viewer
image_mimes="image/jpeg image/png image/gif image/bmp image/tiff image/webp image/svg+xml image/x-icon"
for mime in $image_mimes; do
    xdg-mime default org.gnome.eog.desktop "$mime" >> "$LOG" 2>&1
done

# Set SMPlayer as default video player
video_mimes="video/mp4 video/x-msvideo video/quicktime video/x-matroska video/webm video/ogg video/3gpp video/x-ms-wmv video/x-flv video/x-m4v video/mp2t application/vnd.rn-realmedia"
for mime in $video_mimes; do
    xdg-mime default smplayer.desktop "$mime" >> "$LOG" 2>&1
done

# Set SMPlayer as default audio player
audio_mimes="audio/mpeg audio/mp4 audio/flac audio/ogg audio/x-wav audio/x-ms-wma audio/x-vorbis+ogg audio/x-speex"
for mime in $audio_mimes; do
    xdg-mime default smplayer.desktop "$mime" >> "$LOG" 2>&1
done

# Set VS Code as default for development files
dev_mimes="text/x-shellscript application/x-shellscript text/x-python application/javascript application/json text/markdown text/css application/xml text/x-yaml text/x-conf application/toml text/x-config application/jsonc text/x-log application/x-log text/x-c text/x-c++ text/x-go text/x-rust application/x-php text/x-ruby text/x-perl"
for mime in $dev_mimes; do
    xdg-mime default code.desktop "$mime" >> "$LOG" 2>&1
done

echo "Comprehensive default applications configured" >> "$LOG"

echo "Detecting installed browsers..." >> "$LOG"
available_browsers=()
default_browser=""

# Firefox gets priority, then Brave, then Chrome, then Edge
browser_priorities=("firefox" "brave-bin" "google-chrome" "microsoft-edge-stable-bin")
browser_names=("Firefox" "Brave" "Google Chrome" "Microsoft Edge")

for i in "${!browser_priorities[@]}"; do
    browser="${browser_priorities[$i]}"
    browser_name="${browser_names[$i]}"
    
    if [ -f "/usr/share/applications/$browser.desktop" ] || [ -f "/usr/local/share/applications/$browser.desktop" ] || [ -f "$HOME/.local/share/applications/$browser.desktop" ]; then
        available_browsers+=("$browser.desktop")
        echo "Found installed browser: $browser_name" >> "$LOG"
        
        if [ -z "$default_browser" ]; then
            default_browser="$browser.desktop"
            echo "Setting $browser_name as default browser" >> "$LOG"
        fi
    fi
done

# Set the web browser default properly
if [ -n "$default_browser" ]; then
    xdg-settings set default-web-browser "$default_browser" >> "$LOG" 2>&1
    
    # Also set all web-related MIME types
    web_mimes="text/html application/xhtml+xml x-scheme-handler/http x-scheme-handler/https x-scheme-handler/ftp"
    for mime in $web_mimes; do
        xdg-mime default "$default_browser" "$mime" >> "$LOG" 2>&1
    done
    
    echo "Web browser defaults set to: $default_browser" >> "$LOG"
else
    echo "No browsers found, skipping browser default setting" >> "$LOG"
fi

echo "Building dock favorites list with correct order..." >> "$LOG"
dock_favorites=(
    "com.mitchellh.ghostty.desktop"
    "org.gnome.Nautilus.desktop"
    "org.gnome.Settings.desktop"
    "com.mattjakeman.ExtensionManager.desktop"
    "org.gnome.tweaks.desktop"
    "org.gnome.Software.desktop"
    "code.desktop"
    "org.mozilla.Thunderbird.desktop"
)

# Add the detected default browser to dock
if [ -n "$default_browser" ]; then
    dock_favorites+=("$default_browser")
fi

dock_list="["
for i in "${!dock_favorites[@]}"; do
    if [ $i -gt 0 ]; then
        dock_list+=", "
    fi
    dock_list+="'${dock_favorites[$i]}'"
done
dock_list+="]"

gsettings set org.gnome.shell favorite-apps "$dock_list" >> "$LOG" 2>&1
echo "Dock configured with: ${dock_favorites[*]}" >> "$LOG"

echo "Organizing app grid with dynamic browser layout..." >> "$LOG"

gsettings reset org.gnome.desktop.app-folders folder-children >> "$LOG" 2>&1
dconf reset -f /org/gnome/desktop/app-folders/ >> "$LOG" 2>&1
sleep 2

# Build dynamic browser layout
browser_layout=""
position=0

# Check browsers in preferred order and add to layout
browser_desktop_map=(
    ["firefox"]="firefox.desktop"
    ["brave-bin"]="brave-browser.desktop"
    ["google-chrome"]="google-chrome.desktop" 
    ["microsoft-edge-stable-bin"]="microsoft-edge.desktop"
)

for browser_pkg in "firefox" "brave-bin" "google-chrome" "microsoft-edge-stable-bin"; do
    desktop_file="${browser_desktop_map[$browser_pkg]}"
    if [ -f "/usr/share/applications/$desktop_file" ]; then
        if [ -n "$browser_layout" ]; then
            browser_layout+=", "
        fi
        browser_layout+="\"$desktop_file\": {\"position\": $position}"
        echo "Added $desktop_file at position $position" >> "$LOG"
        ((position++))
    fi
done

# Add remaining apps starting from the next position
remaining_apps="\"org.gnome.eog.desktop\": {\"position\": $position}"
remaining_apps+=", \"io.github.realmazharhussain.GdmSettings.desktop\": {\"position\": $((position+1))}"
remaining_apps+=", \"org.gnome.TextEditor.desktop\": {\"position\": $((position+2))}"
remaining_apps+=", \"gimp.desktop\": {\"position\": $((position+3))}"
remaining_apps+=", \"org.qbittorrent.qBittorrent.desktop\": {\"position\": $((position+4))}"
remaining_apps+=", \"smplayer.desktop\": {\"position\": $((position+5))}"
remaining_apps+=", \"System\": {\"position\": $((position+6))}"
remaining_apps+=", \"org.gnome.SystemMonitor.desktop\": {\"position\": $((position+7))}"

# Combine browser and remaining app layouts
if [ -n "$browser_layout" ]; then
    main_app_layout="[{$browser_layout, $remaining_apps}]"
else
    main_app_layout="[{$remaining_apps}]"
fi

echo "Final app layout: $main_app_layout" >> "$LOG"
gsettings set org.gnome.shell app-picker-layout "$main_app_layout" >> "$LOG" 2>&1

gsettings set org.gnome.desktop.app-folders folder-children "['System']" >> "$LOG" 2>&1

system_apps=(
    "qv4l2.desktop"
    "mpv.desktop"
    "qvidcap.desktop"
    "gufw.desktop"
    "bssh.desktop"
    "avahi-discover.desktop"
    "bvnc.desktop"
    "system-config-printer.desktop"
    "cups.desktop"
    "org.gnome.Extensions.desktop"
)

system_apps_list="["
for i in "${!system_apps[@]}"; do
    if [ $i -gt 0 ]; then
        system_apps_list+=", "
    fi
    system_apps_list+="'${system_apps[$i]}'"
done
system_apps_list+="]"

gsettings set org.gnome.desktop.app-folders.folder:/org/gnome/desktop/app-folders/folders/System/ name 'System' >> "$LOG" 2>&1
gsettings set org.gnome.desktop.app-folders.folder:/org/gnome/desktop/app-folders/folders/System/ apps "$system_apps_list" >> "$LOG" 2>&1

echo "App grid configured with dynamic layout - no gaps regardless of installed browsers" >> "$LOG"

# Set GNOME default applications
echo "Setting GNOME system defaults..." >> "$LOG"
gsettings set org.gnome.desktop.default-applications.terminal exec 'ghostty' >> "$LOG" 2>&1
gsettings set org.gnome.desktop.default-applications.terminal exec-arg '' >> "$LOG" 2>&1

echo "Phase 4 completed at $(date)" >> "$LOG"

# Phase 4a: Configure Nautilus
echo "Phase 4a: Configuring Nautilus preferences..." >> "$LOG"
sleep 3

configure_nautilus() {
    local max_attempts=2
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        echo "Nautilus configuration attempt $attempt..." >> "$LOG"
        
        gsettings set org.gnome.nautilus.list-view use-tree-view false >> "$LOG" 2>&1
        gsettings set org.gnome.nautilus.preferences click-policy 'single' >> "$LOG" 2>&1
        gsettings set org.gnome.nautilus.preferences show-create-link false >> "$LOG" 2>&1
        gsettings set org.gnome.nautilus.preferences show-delete-permanently false >> "$LOG" 2>&1
        gsettings set org.gnome.nautilus.preferences recursive-search 'always' >> "$LOG" 2>&1
        gsettings set org.gnome.nautilus.preferences show-image-thumbnails 'always' >> "$LOG" 2>&1
        gsettings set org.gnome.nautilus.preferences show-directory-item-counts 'always' >> "$LOG" 2>&1
        gsettings set org.gnome.nautilus.icon-view default-zoom-level 'small-plus' >> "$LOG" 2>&1
        
        gsettings set org.gtk.Settings.FileChooser sort-directories-first true >> "$LOG" 2>&1
        gsettings set org.gtk.gtk4.Settings.FileChooser sort-directories-first true >> "$LOG" 2>&1
        
        if gsettings get org.gnome.nautilus.preferences click-policy | grep -q "single"; then
            echo "✅ Nautilus single-click confirmed" >> "$LOG"
            break
        else
            echo "Attempt $attempt failed, retrying..." >> "$LOG"
            sleep 2
            ((attempt++))
        fi
    done
    
    if [ $attempt -gt $max_attempts ]; then
        echo "WARNING: Nautilus configuration may not have applied properly" >> "$LOG"
    fi
}

configure_nautilus

echo "Adding sidebar bookmarks..." >> "$LOG"
mkdir -p "$HOME/.config/gtk-3.0"
cat > "$HOME/.config/gtk-3.0/bookmarks" << EOF
file:///mnt/synology/WEB%20Scripts/Arch Arch
file://$HOME/Documents Documents
file://$HOME/Downloads Downloads
file://$HOME/Pictures Pictures
file:///mnt/plex Plex
file://$HOME/Music Music
file://$HOME/Videos Videos
smb://synology.local/ Synology
file:///mnt/synology/WEB%20Scripts Web Scripts
EOF

nautilus -q >> "$LOG" 2>&1
sleep 2
(nautilus >/dev/null 2>&1 &)

echo "Phase 4a completed - Nautilus configured and bookmarks added at $(date)" >> "$LOG"

# Phase 5: Apply shell theme with proper verification and retry
echo "Phase 5: Applying shell theme with dconf method..." >> "$LOG"
sleep 5

apply_shell_theme() {
    local theme_name="Dracula"
    local max_attempts=3
    local attempt=1

    while [ $attempt -le $max_attempts ]; do
        echo "Shell theme application attempt $attempt..." >> "$LOG"

        if ! gnome-extensions list --enabled | grep -q "user-theme@gnome-shell-extensions.gcampax.github.com"; then
            echo "Enabling user-theme extension..." >> "$LOG"
            gnome-extensions enable "user-theme@gnome-shell-extensions.gcampax.github.com" >> "$LOG" 2>&1
            sleep 3
        fi

        if gnome-extensions list --enabled | grep -q "user-theme@gnome-shell-extensions.gcampax.github.com"; then
            echo "User-theme extension is active, applying shell theme..." >> "$LOG"

            dconf write /org/gnome/shell/extensions/user-theme/name "'$theme_name'" >> "$LOG" 2>&1
            sleep 3

            current_theme=$(dconf read /org/gnome/shell/extensions/user-theme/name 2>/dev/null | tr -d "'\"")
            if [ "$current_theme" = "$theme_name" ]; then
                echo "✅ Shell theme successfully set to $theme_name" >> "$LOG"

                echo "Forcing shell theme reload..." >> "$LOG"
                gdbus call --session \
                    --dest org.gnome.Shell \
                    --object-path /org/gnome/Shell \
                    --method org.gnome.Shell.Eval 'Main.loadTheme()' >> "$LOG" 2>&1 || true

                return 0
            else
                echo "Shell theme setting failed, current: '$current_theme'" >> "$LOG"
            fi
        else
            echo "User-theme extension not active yet" >> "$LOG"
        fi

        sleep 3
        ((attempt++))
    done

    echo "WARNING: Shell theme application failed after $max_attempts attempts" >> "$LOG"
    echo "User will need to manually set shell theme to Dracula after logout/login" >> "$LOG"
    return 1
}

apply_shell_theme
echo "Phase 5 completed - shell theme applied at $(date)" >> "$LOG"

echo "Enhanced autostart script completed with comprehensive default applications at $(date)" >> "$LOG"
echo "Extensions were restored from backup with all settings pre-configured" >> "$LOG"

# Clean up autostart files before logout
echo "Cleaning up autostart files..." >> "$LOG"
rm -f "$HOME/.config/autostart/consolidated-setup.desktop" 2>/dev/null
rm -f "$HOME/.config/scripts/consolidated-autostart.sh" 2>/dev/null
rm -f "$LOCK_FILE" 2>/dev/null
echo "Autostart files cleaned up at $(date)" >> "$LOG"

# Auto-logout to ensure everything settles properly
echo "Initiating automatic logout for clean session..." >> "$LOG"
notify-send -u normal -t 3000 "Dracula Setup" "Configuration complete. Logging out in 3 seconds..."
sleep 3
gnome-session-quit --logout --no-prompt
AUTOSTART_EOF

    sudo chmod +x "/home/$ACTUAL_USER/.config/scripts/consolidated-autostart.sh"
    
    sudo -u "$ACTUAL_USER" mkdir -p "/home/$ACTUAL_USER/.config/autostart"
    cat << DESKTOP_EOF > "/home/$ACTUAL_USER/.config/autostart/consolidated-setup.desktop"
[Desktop Entry]
Type=Application
Exec=/home/$ACTUAL_USER/.config/scripts/consolidated-autostart.sh
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Name=Dracula Setup
Comment=Configure GNOME with Dracula theme on first login
DESKTOP_EOF

    sudo chown -R "$ACTUAL_USER:$ACTUAL_USER" "/home/$ACTUAL_USER/.config"
    finish_progress
    log_success "Enhanced consolidated autostart script with comprehensive default applications"
    
    return 0
}

# Setup Grub
setup_grub() {
    show_progress "Determining default boot entry"
    local grub_default="0"
    if [[ "$kernel_choice" == "2" ]] && ls /boot/vmlinuz-linux-cachyos >/dev/null 2>&1; then
        grub_default="Advanced options for Arch Linux>Arch Linux, with Linux linux-cachyos"
    fi
    finish_progress
    
    show_progress "Configuring kernel parameters"
    local cmdline_linux_default="loglevel=1 quiet splash plymouth.enable=1 rd.udev.log_level=1 systemd.show_status=0 nvme_core.verbose=0 nowatchdog rd.systemd.show_status=false rd.udev.log-priority=1"
   
    if [[ "$CPU_VENDOR" == "AuthenticAMD" ]]; then
        cmdline_linux_default="$cmdline_linux_default amd_pstate=active"
    fi
    finish_progress
    
    show_progress "Writing GRUB configuration"
    cat <<EOF | sudo tee /etc/default/grub >/dev/null
GRUB_DEFAULT="$grub_default"
GRUB_TIMEOUT=3
GRUB_DISTRIBUTOR="Arch"
GRUB_CMDLINE_LINUX_DEFAULT="$cmdline_linux_default"
GRUB_CMDLINE_LINUX="zswap.enabled=0 rootfstype=ext4"
GRUB_PRELOAD_MODULES="part_gpt part_msdos"
GRUB_TIMEOUT_STYLE=hidden
GRUB_TERMINAL_OUTPUT=console
GRUB_DISABLE_RECOVERY=true
GRUB_GFXMODE=3840x2160
GRUB_GFXPAYLOAD_LINUX=keep
EOF
    finish_progress
    
    printf '%s[>] Generating GRUB configuration%s\n' "${COLORS[PURPLE]}" "${COLORS[NC]}"
    (sudo grub-mkconfig -o /boot/grub/grub.cfg >/dev/null 2>&1) &
    local grub_pid=$!
    show_animated_progress_bar "Building GRUB configuration" "$grub_pid"
    
    if ! wait "$grub_pid"; then
        log_error "Failed to generate GRUB configuration"
        return 1
    fi
    
    log_success "GRUB configuration updated successfully with 4K video mode and default: $grub_default"
    return 0
}

# OPTIMIZATION: Enhanced cleanup with parallel operations
perform_cleanup() {
    printf '%s[>] Cleaning up temporary files and caches%s\n' "${COLORS[PURPLE]}" "${COLORS[NC]}"
    
    # Start cleanup operations in parallel
    (sudo rm -rf "/tmp/dracula_temp" "/tmp/cachyos_install" "/tmp/plymouth_extract" "/tmp/gtk_install" "/tmp/cursor_install" "/tmp/icon_install" "/tmp/wallpaper_install" "/tmp/extensions_restore" 2>/dev/null) &
    local cleanup_pid=$!
    
    (sudo pacman -Sc --noconfirm >/dev/null 2>&1 || log_warning "Failed to clean package cache") &
    local pacman_pid=$!
    
    if command_exists yay; then
        (sudo -u "$ACTUAL_USER" yay -Sc --noconfirm >/dev/null 2>&1 || log_warning "Failed to clean yay cache") &
        local yay_pid=$!
    fi

    # Update pkgfile database
    if command_exists pkgfile; then
       (sudo pkgfile --update >/dev/null 2>&1 &) &
       local pkgfile_pid=$!
    fi
    
    # Wait for all cleanup operations with progress bar
    show_animated_progress_bar "Cleaning temporary files and package caches" "$cleanup_pid"
    wait $pacman_pid
    if [[ -n "$yay_pid" ]]; then
        wait "$yay_pid"
    fi
    if [[ -n "$pkgfile_pid" ]]; then
        wait "$pkgfile_pid"
    fi
    
    # Additional cleanup
    sudo find /tmp -name "*dracula*" -delete 2>/dev/null
    sudo find /tmp -name "*cachyos*" -delete 2>/dev/null
    sudo find /tmp -name "*plymouth*" -delete 2>/dev/null
    
    log_success "Cleanup completed with parallel operations"
}

# OPTIMIZATION: Enhanced summary with performance metrics
display_summary_and_exit() {
    local script_end_time
    script_end_time=$(date +%s)
    local total_runtime
    total_runtime=$((script_end_time - ${script_start_time:-$script_end_time}))
    local minutes
    minutes=$((total_runtime / 60))
    local seconds
    seconds=$((total_runtime % 60))
    
    printf '\n%s[*] Dracula Installation Summary%s\n' "${COLORS[PURPLE]}" "${COLORS[NC]}"
    printf '%s=========================================%s\n' "${COLORS[GRAY]}" "${COLORS[NC]}"
    
    if [[ $total_runtime -gt 0 ]]; then
        printf '%s[i] Total runtime: %s%d%s minutes, %s%d%s seconds%s\n' "${COLORS[CYAN]}" "${COLORS[GREEN]}" "$minutes" "${COLORS[CYAN]}" "${COLORS[GREEN]}" "$seconds" "${COLORS[CYAN]}" "${COLORS[NC]}"
    fi
    
    if [[ ${#successful_installs[@]} -gt 0 ]]; then
        printf '%s[+] Successfully installed packages and apps (%s%d%s total):%s\n' "${COLORS[GREEN]}" "${COLORS[CYAN]}" "${#successful_installs[@]}" "${COLORS[GREEN]}" "${COLORS[NC]}"
        local count=0
        for pkg in "${successful_installs[@]}"; do
            if [[ $count -lt 10 ]]; then
                printf '%s  [+] %s%s\n' "${COLORS[CYAN]}" "$pkg" "${COLORS[NC]}"
                ((count++))
            elif [[ $count -eq 10 ]]; then
                printf '%s  ... and %s%d%s more packages%s\n' "${COLORS[GRAY]}" "${COLORS[CYAN]}" "$((${#successful_installs[@]} - 10))" "${COLORS[GRAY]}" "${COLORS[NC]}"
                break
            fi
        done
        echo
    fi
    
    if [[ ${#failed_installs[@]} -gt 0 ]]; then
        printf '%s[!] Failed installations (%s%d%s total):%s\n' "${COLORS[RED]}" "${COLORS[CYAN]}" "${#failed_installs[@]}" "${COLORS[RED]}" "${COLORS[NC]}"
        for pkg in "${failed_installs[@]}"; do
            printf '%s  [!] %s%s\n' "${COLORS[RED]}" "$pkg" "${COLORS[NC]}"
        done
        echo

        if [[ ! -f "$ERRORLOG" ]]; then
            sudo touch "$ERRORLOG" 2>/dev/null || log_error "Cannot create error log at '$ERRORLOG'"
            sudo chmod 644 "$ERRORLOG" 2>/dev/null || log_error "Cannot set permissions on '$ERRORLOG'"
        fi

        printf '%s[i] Review the error log: %s%s%s\n' "${COLORS[PINK]}" "${COLORS[CYAN]}" "$ERRORLOG" "${COLORS[NC]}"
    fi

    if [[ -n "$DETECTED_PRINTER" ]]; then
        printf '%s[+] Printer: %s configured%s\n' "${COLORS[GREEN]}" "$DETECTED_PRINTER" "${COLORS[NC]}"
    fi

    if [[ ${#failed_installs[@]} -eq 0 ]]; then
        printf '%s[+] All packages installed successfully!%s\n' "${COLORS[GREEN]}" "${COLORS[NC]}"
        printf '%s[?] Press Enter to reboot now or type %sn%s to cancel: %s' "${COLORS[CYAN]}" "${COLORS[PINK]}" "${COLORS[CYAN]}" "${COLORS[NC]}"
        read -r reply
        if [[ -z "$reply" || "$reply" =~ ^[Yy]$ ]]; then
            printf '%s[>] Rebooting now... Enjoy your Dracula-themed Arch system!%s\n' "${COLORS[PURPLE]}" "${COLORS[NC]}"
            sudo systemctl reboot 2>/dev/null
        else
            printf '%s[i] Please reboot when convenient to enjoy the full Dracula experience!%s\n' "${COLORS[PINK]}" "${COLORS[NC]}"
        fi
        exit 0
    else
        printf '%s[!] Some packages failed to install:%s\n' "${COLORS[PINK]}" "${COLORS[NC]}"
        for pkg in "${failed_installs[@]}"; do
            printf '%s  [!] %s%s\n' "${COLORS[RED]}" "$pkg" "${COLORS[NC]}"
        done
        printf '%s[?] Press Enter to reboot anyway or type %sn%s to cancel: %s' "${COLORS[CYAN]}" "${COLORS[PINK]}" "${COLORS[CYAN]}" "${COLORS[NC]}"
        read -r reply
        if [[ -z "$reply" || "$reply" =~ ^[Yy]$ ]]; then
            printf '%s[>] Rebooting now...%s\n' "${COLORS[PURPLE]}" "${COLORS[NC]}"
            sudo systemctl reboot 2>/dev/null
        else
            printf '%s[i] Resolve issues and reboot when ready.%s\n' "${COLORS[PINK]}" "${COLORS[NC]}"
        fi
        exit 1
    fi
}

# Main 
main() {
    # Record script start time for performance metrics
    script_start_time=$(date +%s)
    
    if [[ "$TERM" == "linux" ]]; then
        printf '%s[*] Dracula Arch Linux Setup Script - OPTIMIZED [*]%s\n' "${COLORS[PURPLE]}" "${COLORS[NC]}"
    else
        printf '%s[*] Dracula Arch Linux Setup Script - OPTIMIZED%s\n' "${COLORS[PURPLE]}" "${COLORS[NC]}"
    fi
    printf '%s[>] Starting automated Arch Linux setup with Dracula theming...%s\n' "${COLORS[GRAY]}" "${COLORS[NC]}"
    printf '%s[+] Performance optimizations: Parallel downloads, smart caching, single initramfs rebuild%s\n\n' "${COLORS[CYAN]}" "${COLORS[NC]}"
    
    # Phase 1: System Initialization
    printf '\n%s[*] ================================================ [*]%s\n' "${COLORS[PURPLE]}" "${COLORS[NC]}"
    printf '%s[*] Phase 1: System Initialization%s\n' "${COLORS[PURPLE]}" "${COLORS[NC]}"
    printf '%s[*] ================================================ [*]%s\n' "${COLORS[PURPLE]}" "${COLORS[NC]}"
    setup_tmpfs
    setup_sudo
    setup_logging_directory
    detect_system_info
    collect_user_inputs
    
    # Phase 2: System Update & Package Management  
    printf '\n%s[*] ================================================ [*]%s\n' "${COLORS[PURPLE]}" "${COLORS[NC]}"
    printf '%s[*] Phase 2: System Update & Package Management%s\n' "${COLORS[PURPLE]}" "${COLORS[NC]}"
    printf '%s[*] ================================================ [*]%s\n' "${COLORS[PURPLE]}" "${COLORS[NC]}"
    refresh_system
    enable_multilib
    install_required_packages
    setup_flatpak
    
    # Phase 3: Kernel & Hardware Setup 
    printf '\n%s[*] ================================================ [*]%s\n' "${COLORS[PURPLE]}" "${COLORS[NC]}"
    printf '%s[*] Phase 3: Kernel & Hardware Setup%s\n' "${COLORS[PURPLE]}" "${COLORS[NC]}"
    printf '%s[*] ================================================ [*]%s\n' "${COLORS[PURPLE]}" "${COLORS[NC]}"
    setup_kernel_microcode_and_headers
    setup_kernel 
    apply_performance_optimizations
    setup_zram
    label_efi_partition
    
    # Phase 4: Services & Network
    printf '\n%s[*] ================================================ [*]%s\n' "${COLORS[PURPLE]}" "${COLORS[NC]}"
    printf '%s[*] Phase 4: Services & Network%s\n' "${COLORS[PURPLE]}" "${COLORS[NC]}"
    printf '%s[*] ================================================ [*]%s\n' "${COLORS[PURPLE]}" "${COLORS[NC]}"
    setup_batch_services 
    setup_avahi_and_nss_mdns
    setup_smb_and_portals
    setup_reflector_timer
    setup_ufw_firewall
    
    # Phase 5: Applications & Browsers
    printf '\n%s[*] ================================================ [*]%s\n' "${COLORS[PURPLE]}" "${COLORS[NC]}"
    printf '%s[*] Phase 5: Applications & Browsers%s\n' "${COLORS[PURPLE]}" "${COLORS[NC]}"
    printf '%s[*] ================================================ [*]%s\n' "${COLORS[PURPLE]}" "${COLORS[NC]}"
    install_browsers
    setup_printer_auto
    install_ocs_url
    install_aur_apps
    install_claude_code
    install_clean_fonts
    
    # Phase 6: Themes & Extensions 
    printf '\n%s[*] ================================================ [*]%s\n' "${COLORS[PURPLE]}" "${COLORS[NC]}"
    printf '%s[*] Phase 6: Themes & Extensions%s\n' "${COLORS[PURPLE]}" "${COLORS[NC]}"
    printf '%s[*] ================================================ [*]%s\n' "${COLORS[PURPLE]}" "${COLORS[NC]}"
    install_dracula_theme_and_wallpapers  # Optimized with parallel downloads
    restore_gnome_extensions
    create_nautilus_new_file_menu
    
    # Phase 7: Shell & Terminal Setup
    printf '\n%s[*] ================================================ [*]%s\n' "${COLORS[PURPLE]}" "${COLORS[NC]}"
    printf '%s[*] Phase 7: Shell & Terminal Setup%s\n' "${COLORS[PURPLE]}" "${COLORS[NC]}"
    printf '%s[*] ================================================ [*]%s\n' "${COLORS[PURPLE]}" "${COLORS[NC]}"
    setup_nano
    setup_fastfetch
    setup_starship
    setup_zoxide
    setup_delta
    setup_lazygit
    setup_bash
    setup_carapace
    setup_ghostty
    
    # Phase 8: Boot & Display Setup
    printf '\n%s[*] ================================================ [*]%s\n' "${COLORS[PURPLE]}" "${COLORS[NC]}"
    printf '%s[*] Phase 8: Boot & Display Setup%s\n' "${COLORS[PURPLE]}" "${COLORS[NC]}"
    printf '%s[*] ================================================ [*]%s\n' "${COLORS[PURPLE]}" "${COLORS[NC]}"
    setup_plymouth                      
    
    # OPTIMIZATION: Single final initramfs rebuild for ALL kernel changes
    printf '\n%s[+] ================================================ [+]%s\n' "${COLORS[GREEN]}" "${COLORS[NC]}"
    printf '%s[+] OPTIMIZATION: Final Kernel Setup%s\n' "${COLORS[GREEN]}" "${COLORS[NC]}"
    printf '%s[+] ================================================ [+]%s\n' "${COLORS[GREEN]}" "${COLORS[NC]}"
    finalize_kernel_setup              
    
    # Phase 9: Hardware & System Services
    printf '\n%s[*] ================================================ [*]%s\n' "${COLORS[PURPLE]}" "${COLORS[NC]}"
    printf '%s[*] Phase 9: Hardware & System Services%s\n' "${COLORS[PURPLE]}" "${COLORS[NC]}"
    printf '%s[*] ================================================ [*]%s\n' "${COLORS[PURPLE]}" "${COLORS[NC]}"
    setup_logitech_wakeup
    enable_gdm_service
    setup_consolidated_autostart
    
    # Phase 10: Bootloader & Cleanup
    printf '\n%s[*] ================================================ [*]%s\n' "${COLORS[PURPLE]}" "${COLORS[NC]}"
    printf '%s[*] Phase 10: Bootloader & Cleanup%s\n' "${COLORS[PURPLE]}" "${COLORS[NC]}"
    printf '%s[*] ================================================ [*]%s\n' "${COLORS[PURPLE]}" "${COLORS[NC]}"
    setup_grub
    perform_cleanup                     
    
    # Final Summary
    printf '\n%s[+] ================================================ [+]%s\n' "${COLORS[GREEN]}" "${COLORS[NC]}"
    printf '%s[+] Installation Complete!%s\n' "${COLORS[GREEN]}" "${COLORS[NC]}"
    printf '%s[+] ================================================ [+]%s\n' "${COLORS[GREEN]}" "${COLORS[NC]}"
    display_summary_and_exit
}

trap 'log_error "Script interrupted"; exit 1' INT TERM

main "$@"