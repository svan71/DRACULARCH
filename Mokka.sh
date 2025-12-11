#!/bin/bash

# Mokka.sh - Arch Linux KDE Plasma Setup Script with Catppuccin Mocha Theme
# Repository: https://github.com/svan71/DRACULARCH
# Theme configs: mokka/

# Ensure proper terminal environment
export TERM="${TERM:-xterm-256color}"
tput init 2>/dev/null || true

# Centralized Catppuccin Mocha color palette using associative array
declare -gA COLORS=(
    [MAUVE]=$'\033[1;95m'      # CBA6F7 - Bright Magenta (headers/titles)
    [SKY]=$'\033[1;96m'        # 89DCEB - Bright Cyan (prompts/info)
    [GREEN]=$'\033[1;92m'      # A6E3A1 - Bright Green (success/done)
    [PINK]=$'\033[1;91m'       # F5C2E7 - Bright Red (warnings/highlights)
    [RED]=$'\033[1;31m'        # F38BA8 - Red (errors)
    [WHITE]=$'\033[1;37m'      # CDD6F4 - Bright White (general text)
    [GRAY]=$'\033[90m'         # 6C7086 - Gray (timestamps)
    [NC]=$'\033[0m'            # Reset/No Color
)

# Ensure UTF-8 in TTY
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# Initialize global variables
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

# User choice variables
declare -g kernel_choice=""
declare -ga browser_packages=()

# GitHub repository URL
declare -g GITHUB_REPO="https://github.com/svan71/DRACULARCH"

# ============================================================================
# TTY-COMPATIBLE PROGRESS BAR FUNCTIONS
# ============================================================================

show_animated_progress_bar() {
    local message="$1"
    local pid="$2"
    local width=50
    local pos=0
    local direction=1
    
    printf '%s[>] %s%s\n' "${COLORS[MAUVE]}" "$message" "${COLORS[NC]}"
    
    while kill -0 "$pid" 2>/dev/null; do
        printf '\r%s[' "${COLORS[SKY]}"
        
        for ((i=0; i<width; i++)); do
            if [[ $i -eq $pos ]]; then
                printf '%s>%s' "${COLORS[PINK]}" "${COLORS[NC]}"
            elif [[ $i -lt $pos ]] && [[ $direction -eq 1 ]]; then
                printf '%s=%s' "${COLORS[MAUVE]}" "${COLORS[NC]}"
            elif [[ $i -gt $pos ]] && [[ $direction -eq -1 ]]; then
                printf '%s=%s' "${COLORS[MAUVE]}" "${COLORS[NC]}"
            else
                printf '%s-%s' "${COLORS[GRAY]}" "${COLORS[NC]}"
            fi
        done
        
        printf '%s] %sprocessing%s' "${COLORS[SKY]}" "${COLORS[GREEN]}" "${COLORS[NC]}"
        
        pos=$((pos + direction))
        if [[ $pos -ge $((width-1)) ]]; then
            direction=-1
        elif [[ $pos -le 0 ]]; then
            direction=1
        fi
        
        sleep 0.15
    done
    
    printf '\r%s[' "${COLORS[SKY]}"
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
    
    printf '\r%s[*] %s %s%s (%s%d%s/%s%d%s)\n' "${COLORS[SKY]}" "$operation" "$package" "${COLORS[NC]}" "${COLORS[MAUVE]}" "$current" "${COLORS[NC]}" "${COLORS[MAUVE]}" "$total" "${COLORS[NC]}"
    
    printf '%s[' "${COLORS[SKY]}"
    
    if [[ "$operation" == "Downloading" ]]; then
        printf '%s' "${COLORS[PINK]}"
        for ((i=0; i<filled; i++)); do printf '#'; done
    else
        printf '%s' "${COLORS[MAUVE]}"
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
    
    printf '%s[+] %s%s\n' "${COLORS[MAUVE]}" "$operation" "${COLORS[NC]}"
    
    local width=50
    local frame=0
    local -a chars
    chars[0]='-'
    chars[1]=$'\\'
    chars[2]='|'
    chars[3]='/'
    
    while kill -0 "$pid" 2>/dev/null; do
        printf '\r%s[' "${COLORS[SKY]}"
        
        for ((i=0; i<width; i++)); do
            if [[ $((i % 4)) -eq $((frame % 4)) ]]; then
                printf '%s#%s' "${COLORS[MAUVE]}" "${COLORS[NC]}"
            else
                printf '%s=%s' "${COLORS[GRAY]}" "${COLORS[NC]}"
            fi
        done
        
        local spinner_char="${chars[$((frame % 4))]}"
        printf '%s] %s%s processing%s' "${COLORS[SKY]}" "${COLORS[GREEN]}" "$spinner_char" "${COLORS[NC]}"
        
        frame=$((frame + 1))
        sleep 0.2
    done
    
    printf '\r%s[' "${COLORS[SKY]}"
    printf '%s' "${COLORS[GREEN]}"
    for ((i=0; i<width; i++)); do printf '='; done
    printf '%s] %scompleted%s\n' "${COLORS[NC]}" "${COLORS[GREEN]}" "${COLORS[NC]}"
}

# ============================================================================
# LOGGING FUNCTIONS
# ============================================================================

show_progress() {
    local message="$1"
    printf '%s[*] %s%s...' "${COLORS[SKY]}" "$message" "${COLORS[NC]}"
}

finish_progress() {
    printf ' %sdone%s\n' "${COLORS[GREEN]}" "${COLORS[NC]}"
}

log_message() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    printf '%s[%s]%s %s[i] %s%s\n' "${COLORS[GRAY]}" "$timestamp" "${COLORS[NC]}" "${COLORS[SKY]}" "$1" "${COLORS[NC]}" | sudo tee -a "$LOGFILE" >/dev/null
}

log_error() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    printf '%s[%s]%s %s[!] ERROR:%s %s%s\n' "${COLORS[GRAY]}" "$timestamp" "${COLORS[NC]}" "${COLORS[RED]}" "${COLORS[NC]}" "$1" "${COLORS[NC]}" | sudo tee -a "$ERRORLOG" >/dev/null
}

log_warning() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    printf '%s[%s]%s %s[!] WARNING:%s %s%s\n' "${COLORS[GRAY]}" "$timestamp" "${COLORS[NC]}" "${COLORS[PINK]}" "${COLORS[NC]}" "$1" "${COLORS[NC]}" | sudo tee -a "$LOGFILE" "$ERRORLOG" >/dev/null
}

log_success() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    printf '%s[%s]%s %s[+] SUCCESS:%s %s%s\n' "${COLORS[GRAY]}" "$timestamp" "${COLORS[NC]}" "${COLORS[GREEN]}" "${COLORS[NC]}" "$1" "${COLORS[NC]}" | sudo tee -a "$LOGFILE" >/dev/null
}

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

is_package_installed() {
    local package="$1"
    pacman -Qi "$package" &>/dev/null
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

# ============================================================================
# PACKAGE MANAGEMENT FUNCTIONS
# ============================================================================

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
    
    while [[ $attempt -le $max_retries ]]; do
        if [[ $is_driver -eq 1 ]]; then
            sudo pacman -S --noconfirm --needed --overwrite '*' "$package" >/dev/null 2>&1
        else
            sudo pacman -S --noconfirm --needed "$package" >/dev/null 2>&1
        fi
        
        # Trust pacman -Qi as the source of truth
        if pacman -Qi "$package" >/dev/null 2>&1; then
            successful_installs+=("$package")
            return 0
        fi
        
        attempt=$((attempt + 1))
        sleep 2
    done
    
    failed_installs+=("$package")
    log_error "Failed to install package '$package' after $max_retries attempts"
    return 1
}

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
    
    printf "[>] Pre-downloading packages (%d of %d needed)\n" "${#missing_packages[@]}" "${#packages[@]}"
    sudo pacman -Sw --noconfirm --needed "${missing_packages[@]}" >/dev/null 2>&1 || log_warning "Some packages failed to pre-download, proceeding anyway"
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

    printf "[*] Installing packages (%d new, %d total)\n" "${#missing_packages[@]}" "${#packages[@]}"
    
    # Try batch install first
    if sudo pacman -S --noconfirm --needed --overwrite '*' "${missing_packages[@]}" >/dev/null 2>&1; then
        successful_installs+=("${missing_packages[@]}")
        printf "[+] Batch installation completed successfully\n"
    else
        # Batch failed, fall back to individual installs
        log_warning "Batch installation failed, installing individually to identify issues"
        
        local current=0
        local total=${#missing_packages[@]}
        
        for package in "${missing_packages[@]}"; do
            current=$((current + 1))
            printf "[*] Installing %s (%d/%d)\n" "$package" "$current" "$total"
            install_package "$package"
        done
        
        printf "[+] Individual package installation completed\n"
    fi
}

install_aur_packages() {
    local -a aur_packages=("$@")
    if [[ ${#aur_packages[@]} -eq 0 ]]; then
        return
    fi

    # Refresh AUR database
    if ! sudo -u "$ACTUAL_USER" yay -Syy --noconfirm >/dev/null 2>&1; then
        log_warning "Failed to refresh AUR database"
    fi

    local -a missing_packages=()
    for pkg in "${aur_packages[@]}"; do
        if ! is_package_installed "$pkg"; then
            missing_packages+=("$pkg")
        fi
    done

    if [[ ${#missing_packages[@]} -eq 0 ]]; then
        log_message "All AUR packages already installed"
        return
    fi

    printf "[*] Installing AUR packages (%d needed)\n" "${#missing_packages[@]}"

    # Determine install order (browsers last)
    local -a install_order=()
    local -a browser_aur=()
    
    for pkg in "${missing_packages[@]}"; do
        if [[ "$pkg" == "google-chrome" || "$pkg" == "brave-bin" || "$pkg" == "microsoft-edge-stable-bin" ]]; then
            browser_aur+=("$pkg")
        else
            install_order+=("$pkg")
        fi
    done
    install_order+=("${browser_aur[@]}")

    # Install packages with progress indicator
    local current=0
    local total=${#install_order[@]}
    
    for package in "${install_order[@]}"; do
        if [[ " ${missing_packages[*]} " =~ \ ${package}\  ]]; then
            current=$((current + 1))
            show_package_progress "Installing" "$package" "$current" "$total"
            
            sudo -u "$ACTUAL_USER" yay -S --noconfirm --needed --removemake --cleanafter "$package" >/dev/null 2>&1
            # Trust pacman -Qi as the source of truth
            if pacman -Qi "$package" >/dev/null 2>&1; then
                successful_installs+=("$package (AUR)")
            else
                failed_installs+=("$package (AUR)")
                log_error "Failed to install AUR package '$package'"
            fi
        fi
    done

    log_success "AUR package installation completed"
}

fetch_resource() {
    local url="$1"
    local output="$2"
    local type="${3:-curl}"
    
    show_progress "Downloading $(basename "$output")"
    
    if [[ "$type" == "git" ]]; then
        if timeout 300 sudo -u "$ACTUAL_USER" git clone "$url" "$output" >/dev/null 2>&1; then
            if [[ -d "$output" ]] && [[ -n "$(ls -A "$output" 2>/dev/null)" ]]; then
                finish_progress
                return 0
            fi
            sudo rm -rf "$output" 2>/dev/null
        fi
    else
        if timeout 300 curl -L \
            --connect-timeout 30 \
            --max-time 300 \
            --retry 2 \
            --retry-delay 3 \
            --fail \
            --silent \
            --show-error \
            "$url" -o "$output" 2>/dev/null; then
            
            if [[ -f "$output" ]] && [[ -s "$output" ]]; then
                case "$output" in
                    *.tar.xz)
                        if file "$output" | grep -q "XZ compressed"; then
                            finish_progress
                            return 0
                        fi
                        ;;
                    *.tar.gz)
                        if file "$output" | grep -q "gzip compressed"; then
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
            
            sudo rm -f "$output" 2>/dev/null
        fi
    fi
    
    log_error "Failed to fetch '$url'"
    finish_progress
    return 1
}

# ============================================================================
# SYSTEM INITIALIZATION
# ============================================================================

setup_tmpfs() {
    show_progress "Setting up tmpfs for /tmp"
    sudo mount -o size=4G -t tmpfs tmpfs /tmp >/dev/null 2>&1 || log_warning "Failed to mount tmpfs, using default /tmp"
    sudo chmod 1777 /tmp
    finish_progress
    trap 'sudo umount /tmp 2>/dev/null || true' EXIT
}

setup_sudo() {
    local sudo_pass
    printf "[?] Enter sudo password: "
    read -r -s sudo_pass
    echo

    if ! echo "$sudo_pass" | sudo -S true >/dev/null 2>&1; then
        printf "[!] Incorrect sudo password. Exiting.\n"
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

setup_logging_directory() {
    show_progress "Setting up logging directory"
    
    sudo -u "$ACTUAL_USER" mkdir -p "/home/$ACTUAL_USER"/{Documents,Downloads,Desktop} >/dev/null 2>&1
    sudo -u "$ACTUAL_USER" mkdir -p "/home/$ACTUAL_USER/Documents/mokka-logs" >/dev/null 2>&1
    sudo chown -R "$ACTUAL_USER:$ACTUAL_USER" "/home/$ACTUAL_USER/Documents" >/dev/null 2>&1
    sudo chmod 755 "/home/$ACTUAL_USER/Documents" "/home/$ACTUAL_USER/Documents/mokka-logs" >/dev/null 2>&1
    sudo -u "$ACTUAL_USER" touch "/home/$ACTUAL_USER/Documents/mokka-logs/arch_setup.log" "/home/$ACTUAL_USER/Documents/mokka-logs/arch_setup_errors.log" >/dev/null 2>&1
    sudo chmod 644 "/home/$ACTUAL_USER/Documents/mokka-logs/arch_setup.log" "/home/$ACTUAL_USER/Documents/mokka-logs/arch_setup_errors.log" >/dev/null 2>&1
    
    LOG_DIR="/home/$ACTUAL_USER/Documents/mokka-logs"
    LOGFILE="$LOG_DIR/arch_setup.log"        
    ERRORLOG="$LOG_DIR/arch_setup_errors.log"

    exec > >(tee -a "$LOGFILE") 2> >(tee -a "$ERRORLOG" >&2)
    
    finish_progress
    log_message "Logging configured: $LOG_DIR"
}

detect_system_info() {
    show_progress "Detecting system hardware"

    CPU_VENDOR=$(grep -m1 'vendor_id' /proc/cpuinfo | cut -f2 -d':' | tr -d ' ')
    CACHED_GPU_VENDOR=$(lspci -nn 2>/dev/null | grep -i "vga" | grep -oE "Intel|AMD" | head -n 1)
    CACHED_TOTAL_MEMORY_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')

    CACHED_EFI_PARTITION=$(findmnt -n -o SOURCE /boot/efi 2>/dev/null || findmnt -n -o SOURCE /efi 2>/dev/null || findmnt -n -o SOURCE /boot 2>/dev/null)

    log_message "System: CPU=$CPU_VENDOR, GPU=$CACHED_GPU_VENDOR, RAM=${CACHED_TOTAL_MEMORY_KB}KB, EFI=$CACHED_EFI_PARTITION"
    
    finish_progress
}

# ============================================================================
# USER INPUT COLLECTION
# ============================================================================

collect_user_inputs() {
    printf "\n[*] Kernel Configuration Options:\n"
    printf "1) Optimize existing Linux Zen Kernel (Default)\n"
    printf "2) Install Linux CachyOS Kernel and set as default\n\n"
    printf "[?] Enter your choice (1 or 2): "
    read -r kernel_choice
    
    case "$kernel_choice" in
        2)
            printf "[i] CachyOS Kernel will be installed\n"
            ;;
        *)
            kernel_choice="1"
            printf "[i] Linux Zen Kernel will be optimized\n"
            ;;
    esac

    printf "\n[*] Browser Selection:\n"
    printf "1) Google Chrome\n"
    printf "2) Firefox\n"
    printf "3) Firedragon\n"
    printf "4) Brave\n"
    printf "5) Microsoft Edge\n"
    printf "6) All of the above\n"
    printf "7) None\n\n"
    printf "[?] Enter choices as comma-separated list (e.g., 1,3): "
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
            7) printf "[i] No browsers selected\n"; return ;;
            *) printf "[!] Invalid choice: %s\n" "$choice" ;;
        esac
    done
}

# ============================================================================
# SYSTEM UPDATE & PACKAGE MANAGEMENT
# ============================================================================

refresh_system() {
    show_progress "Checking system clock synchronization"
    if ! timedatectl status 2>/dev/null | grep -q "System clock synchronized: yes"; then
        sudo timedatectl set-ntp true >/dev/null 2>&1 || log_error "Failed to synchronize system clock"
        sleep 3
    fi
    finish_progress

    show_progress "Configuring pacman for parallel downloads"
    sudo sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf 2>/dev/null
    sudo sed -i 's/^ParallelDownloads.*/ParallelDownloads = 10/' /etc/pacman.conf 2>/dev/null
    finish_progress

    show_progress "Updating package databases"
    sudo pacman -Syy --noconfirm >/dev/null 2>&1 || log_error "Failed to update package databases"
    finish_progress

    # System upgrade with animated progress
    sudo pacman -Syu --noconfirm >/dev/null 2>&1 &
    local pid=$!
    show_animated_progress_bar "Performing full system upgrade" "$pid"
    wait "$pid"
    
    log_success "System refresh completed"
}

enable_multilib() {
    show_progress "Enabling multilib repository"
    
    if grep -q "^\[multilib\]" /etc/pacman.conf; then
        log_message "Multilib already enabled"
        finish_progress
        return
    fi
    
    sudo sed -i '/^#\[multilib\]/,/^#Include/ s/^#//' /etc/pacman.conf 2>/dev/null
    
    if ! grep -q "^\[multilib\]" /etc/pacman.conf; then
        echo -e "\n[multilib]\nInclude = /etc/pacman.d/mirrorlist" | sudo tee -a /etc/pacman.conf >/dev/null
    fi
    
    sudo pacman -Syy --noconfirm >/dev/null 2>&1 || log_error "Failed to sync after enabling multilib"
    finish_progress
    log_success "Multilib repository enabled"
}

setup_aur_helper() {
    show_progress "Setting up AUR helpers"
    
    # Get total CPU cores for makepkg
    local total_cores
    total_cores=$(nproc)
    sudo sed -i "s/^#MAKEFLAGS=.*/MAKEFLAGS=\"-j$total_cores\"/" /etc/makepkg.conf
    sudo sed -i "s/^MAKEFLAGS=.*/MAKEFLAGS=\"-j$total_cores\"/" /etc/makepkg.conf
    export MAKEFLAGS="-j$total_cores"
    finish_progress

    if ! command_exists git; then
        install_packages "git" || {
            log_error "Failed to install git. AUR packages cannot be installed"
            return 1
        }
    fi
    sudo -u "$ACTUAL_USER" git config --global init.defaultBranch main

    if ! pacman -Q base-devel >/dev/null 2>&1; then
        install_packages "base-devel" || {
            log_error "Failed to install base-devel. AUR packages cannot be installed"
            return 1
        }
    fi

    # Install yay
    if ! command_exists yay; then
        local YAY_DIR="/home/$ACTUAL_USER/yay"
        show_progress "Cloning yay repository"
        fetch_resource "https://aur.archlinux.org/yay.git" "$YAY_DIR" "git" || {
            log_error "Failed to clone yay repository"
            return 1
        }
        
        show_progress "Building and installing yay"
        (cd "$YAY_DIR" && sudo -u "$ACTUAL_USER" makepkg -si --noconfirm >/dev/null 2>&1) || {
            log_error "Failed to install yay"
            sudo rm -rf "$YAY_DIR" 2>/dev/null
            return 1
        }
        sudo rm -rf "$YAY_DIR" 2>/dev/null
        log_success "yay installed successfully"
    fi

    log_success "AUR helpers configured"
}

# ============================================================================
# REQUIRED PACKAGES INSTALLATION
# ============================================================================

install_required_packages() {
    printf "[*] Installing required system packages\n"

    local -a packages=(
        # Core KDE Plasma
        "plasma-desktop" "plasma-workspace" "plasma-nm" "plasma-pa"
        "plasma-systemmonitor" "kdeplasma-addons" "sddm" "sddm-kcm"
        "xdg-desktop-portal" "xdg-desktop-portal-kde"
        "plasma-browser-integration" "plasma-disks" "plasma-firewall"
        "drkonqi" "discover" "packagekit-qt6"
        
        # KDE Applications
        "konsole" "dolphin" "kwrite" "ark" "spectacle" "gwenview" "kinfocenter"
        "partitionmanager" "kscreen" "libkscreen" "kdeconnect"
        "print-manager" "plasma-vault"
        "okular" "kcalc" "filelight" "kweather"
        
        # Theme engines
        "kvantum" "breeze" "breeze-gtk" "kde-gtk-config"
        
        # Terminal tools
        "fish" "nano" "nano-syntax-highlighting" "git"
        "eza" "bat" "btop" "zoxide" "fzf" "fd" "ripgrep"
        
        # System Utilities
        "curl" "wget" "unzip" "zip" "rsync" "dust" "lsof"
        "procs" "duf" "pkgfile" "rebuild-detector"
        
        # Applications
        "thunderbird"
        
        # Text Processing & Development
        "source-highlight" "bc" "jq" "llvm" "lld" "clang"
        
        # Fonts
        "ttf-jetbrains-mono-nerd" "ttf-liberation" "noto-fonts"
        
        # Media Applications
        "gimp" "qbittorrent" "haruna" "elisa"
        
        # Multimedia & Audio
        "alsa-utils" "ffmpeg" "gstreamer" "gst-libav" "gst-plugins-base"
        "gst-plugins-good" "gst-plugins-bad" "gst-plugins-ugly"
        "gst-plugin-pipewire" "libpipewire" "sof-firmware" "playerctl"
        "phonon-qt6-vlc" "qt6-multimedia-ffmpeg"
        
        # Thumbnail Support
        "ffmpegthumbnailer" "ffmpegthumbs" "webp-pixbuf-loader" "file"
        "kimageformats" "qt6-imageformats" 
        "kdegraphics-thumbnailers" "kdesdk-thumbnailers"
        
        # Proprietary Codecs & Media Support
        "libdvdcss" "libdvdread" "x264" "x265" "lame" "libva-utils" "libmad"
        "faad2" "libmpeg2" "twolame"
        
        # Graphics Drivers & Rendering
        "mesa" "libva-mesa-driver" "vulkan-radeon" "lib32-mesa" 
        "lib32-vulkan-radeon" "libva-intel-driver" "vulkan-intel"
        "freetype2" "fontconfig" "cairo"
        
        # Network & Connectivity
        "networkmanager" "networkmanager-qt" "network-manager-applet"
        "glib-networking" "kio-extras" "kio-fuse" "kio-admin"
        "cifs-utils" "smbclient" "samba" "avahi" "nss-mdns"
        "openssh" "wpa_supplicant" "iw" "nfs-utils"
        
        # Bluetooth
        "bluez" "bluez-utils" "bluedevil"
        
        # Package Management & System
        "flatpak" "pacman-contrib" "expac" "smartmontools" 
        "power-profiles-daemon" "powertop"
        
        # Hardware & System Info
        "udisks2" "iputils" "dosfstools"
        
        # Wayland Support
        "wl-clipboard" "xorg-server-xvfb"
        
        # SDDM Theme Dependencies
        "qt6-svg" "qt6-declarative" "qt5-quickcontrols2"
        
        # GPG and Keyring for KDE Wallet
        "gnupg" "kwallet-pam"
        
        # Kernel Packages & Build Dependencies
        "linux-zen-headers"
        "cpio" "rust" "rust-bindgen" "rust-src"
        "pahole" "elfutils"
        
        # System Security
        "iptables-nft" "nftables" "ufw" "gufw" "reflector"
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

    log_success "Required packages installation completed"
}

setup_flatpak() {
    show_progress "Setting up Flatpak"
    
    if ! is_package_installed "flatpak"; then
        install_packages "flatpak" || {
            log_error "Failed to install Flatpak"
            finish_progress
            return 1
        }
    fi
    
    # Add Flathub repository
    sudo -u "$ACTUAL_USER" flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo >/dev/null 2>&1
    
    finish_progress
    log_success "Flatpak configured with Flathub repository"
}

# ============================================================================
# END OF SECTION 1
# ============================================================================

# ============================================================================
# SECTION 2: KERNEL, PERFORMANCE, SERVICES, NETWORKING
# ============================================================================

# ============================================================================
# KERNEL & MICROCODE SETUP
# ============================================================================

setup_kernel_microcode_and_headers() {
    show_progress "Setting up CPU microcode and kernel headers"

    # Install microcode based on CPU vendor
    if [[ "$CPU_VENDOR" == "GenuineIntel" ]]; then
        install_packages "intel-ucode"
        log_message "Intel microcode installed"
    elif [[ "$CPU_VENDOR" == "AuthenticAMD" ]]; then
        install_packages "amd-ucode"
        log_message "AMD microcode installed"
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
    else
        log_warning "Unknown CPU vendor: $CPU_VENDOR - skipping microcode"
    fi

    # Ensure linux-zen-headers is installed
    if ! is_package_installed "linux-zen-headers"; then
        install_packages "linux-zen-headers"
    fi

    finish_progress
    log_success "Microcode and kernel headers configured"
}

setup_kernel() {
    if [[ "$kernel_choice" == "2" ]]; then
        setup_cachyos_kernel
    else
        optimize_zen_kernel
    fi
}

optimize_zen_kernel() {
    show_progress "Optimizing Linux Zen kernel"

    # Ensure zen kernel and headers are installed
    if ! is_package_installed "linux-zen"; then
        install_packages "linux-zen" "linux-zen-headers"
    fi

    # Configure mkinitcpio for performance
    local mkinitcpio_conf="/etc/mkinitcpio.conf"
    
    if [[ -f "$mkinitcpio_conf" ]]; then
        # Add modules for better hardware support
        if ! grep -q "amdgpu\|i915" "$mkinitcpio_conf"; then
            sudo sed -i 's/^MODULES=(/MODULES=(amdgpu i915 /' "$mkinitcpio_conf" 2>/dev/null
        fi
        
        # Use lz4 compression for faster boot
        sudo sed -i 's/^#COMPRESSION="lz4"/COMPRESSION="lz4"/' "$mkinitcpio_conf" 2>/dev/null
        sudo sed -i 's/^COMPRESSION="zstd"/COMPRESSION="lz4"/' "$mkinitcpio_conf" 2>/dev/null
    fi

    finish_progress
    log_success "Linux Zen kernel optimized"
}

setup_cachyos_kernel() {
    printf "[*] Setting up CachyOS Kernel\n"

    # Step 1: Download optimized kernel and headers from GitHub
    show_progress "Downloading Linux CachyOS Kernel and headers"
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
    finish_progress

    # Step 2: Extract packages
    show_progress "Extracting kernel packages"
    local temp_dir="/tmp/cachyos_install"
    mkdir -p "$temp_dir"
    
    if ! tar xf "/tmp/cachyos-kernel.tar.xz" -C "$temp_dir" >/dev/null 2>&1; then
        log_error "Failed to extract kernel package"
        return 1
    fi
    
    if ! tar xf "/tmp/cachyos-headers.tar.xz" -C "$temp_dir" >/dev/null 2>&1; then
        log_error "Failed to extract headers package"
        return 1
    fi
    finish_progress

    # Step 3: Install packages
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

    # Cleanup
    sudo rm -rf "$temp_dir" "/tmp/cachyos-kernel.tar.xz" "/tmp/cachyos-headers.tar.xz"

    log_success "CachyOS kernel setup completed"
}

finalize_kernel_setup() {
    # Rebuild initramfs with progress bar
    sudo mkinitcpio -P >/dev/null 2>&1 &
    local pid=$!
    show_kernel_progress "Rebuilding initramfs for all kernels" "$pid"
    wait "$pid"
    local exit_code=$?
    
    if [[ $exit_code -ne 0 ]]; then
        log_error "Failed to rebuild initramfs"
        return 1
    fi
    
    log_success "Initramfs rebuilt successfully"

    # Update GRUB if installed
    if command_exists grub-mkconfig; then
        show_progress "Updating GRUB configuration"
        sudo grub-mkconfig -o /boot/grub/grub.cfg >/dev/null 2>&1 || log_warning "Failed to update GRUB"
        finish_progress
    fi
}

# ============================================================================
# PERFORMANCE OPTIMIZATIONS
# ============================================================================

apply_performance_optimizations() {
    printf "[*] Applying system performance optimizations\n"

    # Sysctl optimizations
    show_progress "Configuring kernel parameters"
    
    local sysctl_conf="/etc/sysctl.d/99-mokka-performance.conf"
    cat <<EOF | sudo tee "$sysctl_conf" >/dev/null
# Mokka Performance Optimizations

# Virtual Memory
vm.swappiness=10
vm.vfs_cache_pressure=50
vm.dirty_ratio=10
vm.dirty_background_ratio=5

# Network Performance - Optimized for 2.5Gb
net.core.netdev_max_backlog=16384
net.core.somaxconn=8192
net.core.rmem_default=1048576
net.core.rmem_max=26214400
net.core.wmem_default=1048576
net.core.wmem_max=26214400
net.core.optmem_max=65536
net.core.netdev_budget=600
net.core.netdev_budget_usecs=6000
net.ipv4.tcp_rmem=4096 1048576 26214400
net.ipv4.tcp_wmem=4096 65536 26214400
net.ipv4.tcp_fastopen=3
net.ipv4.tcp_max_syn_backlog=8192
net.ipv4.tcp_max_tw_buckets=2000000
net.ipv4.tcp_tw_reuse=1
net.ipv4.tcp_fin_timeout=10
net.ipv4.tcp_slow_start_after_idle=0
net.ipv4.tcp_keepalive_time=60
net.ipv4.tcp_keepalive_intvl=10
net.ipv4.tcp_keepalive_probes=6
net.ipv4.tcp_mtu_probing=1
net.ipv4.tcp_syncookies=1
net.core.default_qdisc=cake
net.ipv4.tcp_congestion_control=bbr

# File System
fs.inotify.max_user_watches=524288
fs.file-max=2097152

# Kernel
kernel.nmi_watchdog=0
kernel.unprivileged_userns_clone=1
EOF

    sudo sysctl --system >/dev/null 2>&1
    finish_progress

    # I/O Scheduler optimization
    show_progress "Optimizing I/O scheduler for NVMe/SSD"
    
    local udev_rule="/etc/udev/rules.d/60-ioschedulers.rules"
    cat <<EOF | sudo tee "$udev_rule" >/dev/null
# Set scheduler for NVMe
ACTION=="add|change", KERNEL=="nvme[0-9]*", ATTR{queue/scheduler}="none"
# Set scheduler for SSD
ACTION=="add|change", KERNEL=="sd[a-z]|mmcblk[0-9]*", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="mq-deadline"
# Set scheduler for HDD
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="1", ATTR{queue/scheduler}="bfq"
EOF

    sudo udevadm control --reload-rules >/dev/null 2>&1
    sudo udevadm trigger >/dev/null 2>&1
    finish_progress

    # Journal size limit
    show_progress "Configuring systemd journal"
    sudo mkdir -p /etc/systemd/journald.conf.d
    cat <<EOF | sudo tee /etc/systemd/journald.conf.d/size.conf >/dev/null
[Journal]
SystemMaxUse=100M
EOF
    finish_progress

    # Disable core dumps (optional, saves disk space)
    show_progress "Configuring core dumps"
    echo "kernel.core_pattern=/dev/null" | sudo tee /etc/sysctl.d/50-coredump.conf >/dev/null
    finish_progress

    log_success "Performance optimizations applied"
}

setup_zram() {
    show_progress "Configuring ZRAM swap"

    # Install zram-generator
    install_packages "zram-generator"

    if is_package_installed "zram-generator"; then
        # Calculate ZRAM size (half of RAM, max 8GB)
        local ram_kb=$CACHED_TOTAL_MEMORY_KB
        local ram_mb=$((ram_kb / 1024))
        local zram_mb=$((ram_mb / 2))
        
        if [[ $zram_mb -gt 8192 ]]; then
            zram_mb=8192
        fi

        # Configure zram-generator
        sudo mkdir -p /etc/systemd/zram-generator.conf.d
        cat <<EOF | sudo tee /etc/systemd/zram-generator.conf.d/zram.conf >/dev/null
[zram0]
zram-size = ${zram_mb}M
compression-algorithm = zstd
EOF

        # Disable any existing swap and enable zram
        sudo systemctl daemon-reload
        sudo systemctl start systemd-zram-setup@zram0.service >/dev/null 2>&1

        log_success "ZRAM configured with ${zram_mb}MB"
    else
        log_error "Failed to install zram-generator"
    fi

    finish_progress
}

label_efi_partition() {
    show_progress "Labeling EFI partition"

    if [[ -z "$CACHED_EFI_PARTITION" ]]; then
        log_warning "No EFI partition found to label"
        finish_progress
        return
    fi

    # Label the partition as "Mokka Arch"
    if command_exists fatlabel; then
        sudo fatlabel "$CACHED_EFI_PARTITION" "Mokka Arch" >/dev/null 2>&1 || log_warning "Failed to label EFI partition"
    elif command_exists dosfslabel; then
        sudo dosfslabel "$CACHED_EFI_PARTITION" "Mokka Arch" >/dev/null 2>&1 || log_warning "Failed to label EFI partition"
    else
        log_warning "No FAT labeling tool found"
    fi

    finish_progress
    log_message "EFI partition labeled as 'Mokka Arch'"
}

# ============================================================================
# SERVICES SETUP
# ============================================================================

setup_batch_services() {
    printf "[*] Enabling system services\n"

    # Core services
    manage_service "NetworkManager.service" "enable --now"
    manage_service "sddm.service" "enable"
    
    # Bluetooth
    if is_package_installed "bluez"; then
        manage_service "bluetooth.service" "enable --now"
    fi
    
    # Power management
    if is_package_installed "power-profiles-daemon"; then
        manage_service "power-profiles-daemon.service" "enable --now"
    fi

    # Trim for SSDs
    manage_service "fstrim.timer" "enable --now"

    # Pkgfile updates
    if is_package_installed "pkgfile"; then
        manage_service "pkgfile-update.timer" "enable --now"
    fi

    log_success "System services enabled"
}

setup_avahi_and_nss_mdns() {
    show_progress "Configuring Avahi mDNS"
    
    manage_service "avahi-daemon.service" "enable --now"

    if systemctl is-active --quiet "avahi-daemon.service" 2>/dev/null; then
        log_message "Avahi daemon started successfully"
    else
        log_error "Avahi daemon failed to start"
        finish_progress
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

    log_success "Avahi and nss-mdns configuration completed"
}

setup_reflector_timer() {
    show_progress "Configuring weekly mirror updates"

    if ! is_package_installed "reflector"; then
        install_packages "reflector"
    fi

    # Create reflector configuration
    sudo mkdir -p /etc/xdg/reflector
    cat <<EOF | sudo tee /etc/xdg/reflector/reflector.conf >/dev/null
--save /etc/pacman.d/mirrorlist
--protocol https
--country "United States"
--latest 10
--sort rate
EOF

    manage_service "reflector.timer" "enable --now"

    finish_progress
    log_success "Reflector timer configured for weekly mirror updates"
}

setup_ufw_firewall() {
    show_progress "Configuring UFW firewall"

    if ! is_package_installed "ufw"; then
        install_packages "ufw"
    fi

    # Basic UFW configuration
    sudo ufw default deny incoming >/dev/null 2>&1
    sudo ufw default allow outgoing >/dev/null 2>&1
    
    # Allow common services
    sudo ufw allow ssh >/dev/null 2>&1
    sudo ufw allow 5353/udp >/dev/null 2>&1  # Avahi/mDNS
    sudo ufw allow from 192.168.0.0/16 to any port 631 >/dev/null 2>&1  # CUPS printing

    # Allow KDE Connect
    sudo ufw allow 1714:1764/udp >/dev/null 2>&1
    sudo ufw allow 1714:1764/tcp >/dev/null 2>&1

    # Enable UFW
    sudo ufw --force enable >/dev/null 2>&1
    manage_service "ufw.service" "enable --now"

    finish_progress
    log_success "UFW firewall configured and enabled"
}

# ============================================================================
# PRINTER SETUP
# ============================================================================

# Global to track detected printer for summary
declare -g DETECTED_PRINTER=""

setup_printer_auto() {
    printf '%s[*] Auto-detecting network printers%s\n' "${COLORS[SKY]}" "${COLORS[NC]}"

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
        show_progress "Installing Canon drivers for scanning support"
        install_aur_packages "cnijfilter2"
        finish_progress

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

# ============================================================================
# PRELOAD SETUP
# ============================================================================

# ============================================================================
# OCS-URL FOR THEME INSTALLATION
# ============================================================================

install_ocs_url() {
    show_progress "Installing ocs-url for KDE theme installation"
    
    install_aur_packages "ocs-url"
    
    if is_package_installed "ocs-url"; then
        log_success "ocs-url installed"
    else
        log_warning "Failed to install ocs-url"
    fi
    
    finish_progress
}

# ============================================================================
# END OF SECTION 2
# ============================================================================

# ============================================================================
# SECTION 3: BROWSERS, AUR APPS, FONTS, PLASMA WIDGETS/THEMES/EFFECTS
# ============================================================================

# ============================================================================
# BROWSER INSTALLATION
# ============================================================================

install_browsers() {
    if [[ ${#browser_packages[@]} -eq 0 ]]; then
        log_message "No browsers selected for installation"
        return
    fi

    printf "[*] Installing selected browsers\n"

    local -a aur_browser_packages=()
    local -a official_browser_packages=()

    for pkg in "${browser_packages[@]}"; do
        case "$pkg" in
            "google-chrome"|"microsoft-edge-stable-bin"|"brave-bin"|"firedragon-catppuccin-bin")
                aur_browser_packages+=("$pkg")
                ;;
            "firefox")
                official_browser_packages+=("$pkg")
                ;;
        esac
    done

    # Install official browsers
    if [[ ${#official_browser_packages[@]} -gt 0 ]]; then
        printf "[*] Installing official browsers\n"
        predownload_packages "${official_browser_packages[@]}"
        install_packages "${official_browser_packages[@]}"
    fi

    # Install AUR browsers
    if [[ ${#aur_browser_packages[@]} -gt 0 ]]; then
        printf "[*] Installing AUR browsers\n"
        install_aur_packages "${aur_browser_packages[@]}"
    fi

    log_success "Browser installation completed"
}

# ============================================================================
# AUR APPLICATIONS
# ============================================================================

install_aur_apps() {
    printf "[*] Installing AUR applications\n"

    # Refresh databases
    show_progress "Refreshing package databases"
    sudo pacman -Syy >/dev/null 2>&1
    sudo -u "$ACTUAL_USER" yay -Syy >/dev/null 2>&1
    finish_progress

    # Official packages
    local -a official_packages=(
        "gimp"
        "qbittorrent"
    )

    # AUR packages
    local -a aur_packages=(
        "visual-studio-code-bin"
        "carapace-bin"
        "github-cli"
        "ghostty"
        "modprobed-db"
    )

    # Install official packages
    if [[ ${#official_packages[@]} -gt 0 ]]; then
        printf "[*] Installing official applications\n"
        predownload_packages "${official_packages[@]}"
        install_packages "${official_packages[@]}"
    fi

    # Install AUR packages
    if [[ ${#aur_packages[@]} -gt 0 ]]; then
        printf "[*] Installing AUR applications\n"
        install_aur_packages "${aur_packages[@]}"
    fi

    # Enable modprobed-db service to track kernel modules over time
    if command -v modprobed-db &>/dev/null; then
        show_progress "Enabling modprobed-db service"
        sudo -u "$ACTUAL_USER" systemctl --user enable modprobed-db.service 2>/dev/null
        # Do initial store to capture currently loaded modules
        sudo -u "$ACTUAL_USER" modprobed-db store 2>/dev/null
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

    printf '%s[>] Installing Claude Code%s\n' "${COLORS[MAUVE]}" "${COLORS[NC]}"

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
      "Read(/run/user/1000/gvfs/smb-share:server=synology.local,share=external/WEB Scripts/Scripts/**)",
      "Edit(/run/user/1000/gvfs/smb-share:server=synology.local,share=external/WEB Scripts/Scripts/**)",
      "Write(/run/user/1000/gvfs/smb-share:server=synology.local,share=external/WEB Scripts/Scripts/**)",
      "Read(/run/user/1000/gvfs/smb-share:server=synology.local,share=apple/Aorus/**)",
      "Edit(/run/user/1000/gvfs/smb-share:server=synology.local,share=apple/Aorus/**)",
      "Write(/run/user/1000/gvfs/smb-share:server=synology.local,share=apple/Aorus/**)",
      "Bash(*)",
      "WebSearch",
      "WebFetch"
    ]
  }
}
EOF
        # Create notes pointer for Claude context
        printf "Notes location: /run/media/steve/ARCH_202512/notes.md\nCLAUDE.md location: /run/media/steve/ARCH_202512/CLAUDE.md\n" | sudo -u "$ACTUAL_USER" tee "/home/$ACTUAL_USER/.claude/notes.md" >/dev/null
        finish_progress
    else
        printf '%s[!] Claude Code installation failed (non-critical)%s\n' "${COLORS[PINK]}" "${COLORS[NC]}"
        log_warning "Claude Code installation failed"
    fi
}

# ============================================================================
# FONTS INSTALLATION
# ============================================================================

install_clean_fonts() {
    printf "[*] Installing fonts\n"

    # All required fonts are now in official repos (JetBrainsMono Nerd Font)
    # No AUR fonts needed

    # Configure font rendering
    show_progress "Configuring font rendering"
    local font_config="/home/$ACTUAL_USER/.config/fontconfig/fonts.conf"
    sudo -u "$ACTUAL_USER" mkdir -p "$(dirname "$font_config")"
    
    cat <<EOF | sudo -u "$ACTUAL_USER" tee "$font_config" >/dev/null
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<fontconfig>
    <!-- Enable anti-aliasing -->
    <match target="font">
        <edit name="antialias" mode="assign">
            <bool>true</bool>
        </edit>
    </match>

    <!-- Enable hinting -->
    <match target="font">
        <edit name="hinting" mode="assign">
            <bool>true</bool>
        </edit>
    </match>

    <!-- Set hint style -->
    <match target="font">
        <edit name="hintstyle" mode="assign">
            <const>hintslight</const>
        </edit>
    </match>

    <!-- Enable subpixel rendering -->
    <match target="font">
        <edit name="rgba" mode="assign">
            <const>rgb</const>
        </edit>
    </match>

    <!-- LCD filter -->
    <match target="font">
        <edit name="lcdfilter" mode="assign">
            <const>lcddefault</const>
        </edit>
    </match>

    <!-- Disable autohinter for well-hinted fonts -->
    <match target="font">
        <edit name="autohint" mode="assign">
            <bool>false</bool>
        </edit>
    </match>

    <!-- Default fonts -->
    <alias>
        <family>sans-serif</family>
        <prefer>
            <family>Noto Sans</family>
        </prefer>
    </alias>

    <alias>
        <family>monospace</family>
        <prefer>
            <family>JetBrainsMono Nerd Font</family>
        </prefer>
    </alias>
</fontconfig>
EOF

    # Update font cache
    show_progress "Updating font cache"
    sudo -u "$ACTUAL_USER" fc-cache -f >/dev/null 2>&1
    sudo fc-cache -f >/dev/null 2>&1
    finish_progress

    log_success "Fonts installed and configured"
}

# ============================================================================
# PLASMA PANEL WIDGETS (CRITICAL)
# ============================================================================

install_plasma_widgets() {
    printf "[*] Installing Plasma panel widgets (CRITICAL for panel layout)\n"

    local -a widget_packages=(
        "plasma6-applets-window-title"
        "plasma-applet-window-buttons"
        "plasma6-applets-panel-colorizer"
    )

    install_aur_packages "${widget_packages[@]}"

    # Verify installation
    local all_installed=1
    for pkg in "${widget_packages[@]}"; do
        if ! is_package_installed "$pkg"; then
            log_error "Critical widget '$pkg' failed to install - panels may not work correctly"
            all_installed=0
        fi
    done

    if [[ $all_installed -eq 1 ]]; then
        log_success "All critical panel widgets installed"
    else
        log_warning "Some panel widgets failed - panel layout may be incomplete"
    fi
}

# ============================================================================
# INSTALL TAHOE LAUNCHER
# ============================================================================

install_tahoe_launcher() {
    show_progress "Installing TahoeLauncher"

    local tahoe_dir="/usr/share/plasma/plasmoids/TahoeLauncher"
    
    if [[ -d "$tahoe_dir" ]]; then
        log_message "TahoeLauncher already installed"
        finish_progress
        return
    fi

    # Clone from GitHub as user (not root)
    local temp_dir="/tmp/TahoeLauncher"
    rm -rf "$temp_dir" 2>/dev/null
    
    if sudo -u "$ACTUAL_USER" git clone --depth 1 https://github.com/EliverLara/TahoeLauncher.git "$temp_dir" >/dev/null 2>&1; then
        # The repo contains the plasmoid at root level
        sudo mkdir -p "$tahoe_dir"
        sudo cp -r "$temp_dir"/* "$tahoe_dir/"
        sudo chmod -R 755 "$tahoe_dir"
        rm -rf "$temp_dir"
        finish_progress
        log_success "TahoeLauncher installed"
    else
        finish_progress
        log_error "Failed to clone TahoeLauncher from GitHub"
    fi
}

# ============================================================================
# INSTALL PANEL COLORIZER PRESETS
# ============================================================================

install_panel_colorizer_presets() {
    show_progress "Installing Panel Colorizer Mokka presets"

    if [[ -z "$MOKKA_CONFIG_DIR" || ! -d "$MOKKA_CONFIG_DIR" ]]; then
        log_warning "Mokka config directory not set, skipping Panel Colorizer presets"
        finish_progress
        return
    fi

    local presets_src="$MOKKA_CONFIG_DIR/panel-colorizer-presets"
    local presets_dest="/usr/share/plasma/plasmoids/luisbocanegra.panel.colorizer/contents/ui/presets"

    if [[ ! -d "$presets_src" ]]; then
        log_warning "Panel Colorizer presets not found in config"
        finish_progress
        return
    fi

    if [[ ! -d "$presets_dest" ]]; then
        log_warning "Panel Colorizer not installed, skipping presets"
        finish_progress
        return
    fi

    # Copy Mokka presets
    for preset in "Mokka Top Panel" "Mokka Carbon" "Mokka Dock"; do
        if [[ -d "$presets_src/$preset" ]]; then
            sudo cp -r "$presets_src/$preset" "$presets_dest/"
            sudo chmod -R 755 "$presets_dest/$preset"
        fi
    done

    finish_progress
    log_success "Panel Colorizer Mokka presets installed"
}

# ============================================================================
# THEME PACKAGES
# ============================================================================

install_theme_packages() {
    printf "[*] Installing theme packages\n"

    # AUR theme packages
    local -a theme_packages=(
        "catppuccin-gtk-theme-mocha"
        "catppuccin-cursors-mocha"
        "tela-circle-icon-theme-dracula"
    )

    install_aur_packages "${theme_packages[@]}"

    # Verify theme installation
    for pkg in "${theme_packages[@]}"; do
        if is_package_installed "$pkg"; then
            log_message "Theme package '$pkg' installed"
        else
            log_warning "Theme package '$pkg' may not have installed correctly"
        fi
    done

    log_success "Theme packages installation completed"
}

# ============================================================================
# KWIN EFFECTS
# ============================================================================

install_kwin_effects() {
    printf "[*] Installing KWin effects\n"

    local -a effect_packages=(
        "kwin-effects-forceblur"
        "kwin-effect-rounded-corners-git"
    )

    install_aur_packages "${effect_packages[@]}"

    # Verify installation
    for pkg in "${effect_packages[@]}"; do
        if is_package_installed "$pkg"; then
            log_message "KWin effect '$pkg' installed"
        else
            log_warning "KWin effect '$pkg' may not have installed correctly"
        fi
    done

    log_success "KWin effects installation completed"
}

# ============================================================================
# DOWNLOAD AND EXTRACT MOKKA CONFIGS FROM GITHUB
# ============================================================================

download_mokka_configs() {
    printf "[*] Downloading Mokka configuration files from GitHub\n"

    local temp_dir="/tmp/mokka-install"
    local archive_url="$GITHUB_REPO/archive/main.tar.gz"
    local archive_file="/tmp/dracularch-main.tar.gz"

    # Clean up any previous downloads
    rm -rf "$temp_dir" 2>/dev/null
    rm -f "$archive_file" 2>/dev/null
    mkdir -p "$temp_dir"

    # Download repository archive with animated progress
    curl -L --connect-timeout 30 --max-time 300 --retry 3 \
        "$archive_url" -o "$archive_file" >/dev/null 2>&1 &
    local pid=$!
    show_animated_progress_bar "Downloading configuration archive" "$pid"
    wait "$pid"
    local exit_code=$?
    
    if [[ $exit_code -ne 0 ]]; then
        log_error "Failed to download Mokka configs from GitHub"
        return 1
    fi

    # Extract archive
    show_progress "Extracting configuration files"
    if ! tar xzf "$archive_file" -C "$temp_dir" >/dev/null 2>&1; then
        log_error "Failed to extract configuration archive"
        finish_progress
        return 1
    fi
    finish_progress

    # Set extracted directory path
    MOKKA_CONFIG_DIR="$temp_dir/DRACULARCH-main/mokka"

    if [[ ! -d "$MOKKA_CONFIG_DIR" ]]; then
        log_error "Mokka config directory not found in archive"
        return 1
    fi

    log_success "Mokka configs downloaded and extracted"
}

# ============================================================================
# RESTORE PLASMA CONFIGURATIONS
# ============================================================================

restore_plasma_configs() {
    printf "[*] Restoring Plasma configuration files\n"

    if [[ -z "$MOKKA_CONFIG_DIR" || ! -d "$MOKKA_CONFIG_DIR" ]]; then
        log_error "Mokka config directory not set or not found"
        return 1
    fi

    local plasma_config_src="$MOKKA_CONFIG_DIR/configs/plasma"
    local user_config_dir="/home/$ACTUAL_USER/.config"

    # Ensure config directory exists
    sudo -u "$ACTUAL_USER" mkdir -p "$user_config_dir"

    # List of plasma config files to restore
    local -a plasma_configs=(
        # Core Plasma configs
        "plasma-org.kde.plasma.desktop-appletsrc"
        "plasmashellrc"
        "plasmarc"
        "kdeglobals"
        
        # Window Manager
        "kwinrc"
        "kwinrulesrc"
        
        # System & Session
        "kded5rc"
        "kded6rc"
        "ksmserverrc"
        "kcminputrc"
        
        # Desktop Search & Launcher
        "krunnerrc"
        "baloofilerc"
        
        # Shortcuts & Hotkeys
        "kglobalshortcutsrc"
        "khotkeysrc"
        
        # Notifications & Appearance  
        "plasmanotifyrc"
        "breezerc"
        "kscreenlockerrc"
        
        # Applications
        "konsolerc"
        "dolphinrc"
        "spectaclerc"
        "gwenviewrc"
        "okularrc"
        "arkrc"
        "kactivitymanagerdrc"
    )

    for config_file in "${plasma_configs[@]}"; do
        if [[ -f "$plasma_config_src/$config_file" ]]; then
            sudo -u "$ACTUAL_USER" cp "$plasma_config_src/$config_file" "$user_config_dir/" 2>/dev/null
        fi
    done &
    local pid=$!
    show_animated_progress_bar "Restoring ${#plasma_configs[@]} Plasma configuration files" "$pid"
    wait "$pid"

    # Restore application launcher favorites (kactivitymanagerd)
    local activities_src="$MOKKA_CONFIG_DIR/configs/activities/kactivitymanagerd"
    local activities_dest="/home/$ACTUAL_USER/.local/share/kactivitymanagerd"
    
    if [[ -d "$activities_src" ]]; then
        show_progress "Restoring application launcher favorites"
        sudo -u "$ACTUAL_USER" mkdir -p "$(dirname "$activities_dest")"
        sudo -u "$ACTUAL_USER" cp -r "$activities_src" "$activities_dest"
        finish_progress
        log_message "Application launcher favorites restored"
    else
        log_warning "Application launcher favorites not found in backup"
    fi

    # Set correct ownership
    sudo chown -R "$ACTUAL_USER:$ACTUAL_USER" "$user_config_dir"
    sudo chown -R "$ACTUAL_USER:$ACTUAL_USER" "/home/$ACTUAL_USER/.local/share"

    log_success "Plasma configuration files restored"
}

# ============================================================================
# RESTORE SYSTEM CONFIG FILES
# ============================================================================

restore_system_configs() {
    printf "[*] Restoring system configuration files\n"

    if [[ -z "$MOKKA_CONFIG_DIR" || ! -d "$MOKKA_CONFIG_DIR" ]]; then
        log_error "Mokka config directory not set"
        return 1
    fi

    # xdg-desktop-portal configuration (CRITICAL for Wayland)
    local portal_src="$MOKKA_CONFIG_DIR/configs/system/xdg-desktop-portal"
    local portal_dest="/home/$ACTUAL_USER/.config/xdg-desktop-portal"

    if [[ -d "$portal_src" ]]; then
        show_progress "Restoring xdg-desktop-portal config"
        sudo -u "$ACTUAL_USER" mkdir -p "$portal_dest"
        sudo -u "$ACTUAL_USER" cp -r "$portal_src"/* "$portal_dest/" 2>/dev/null
        finish_progress
        log_message "xdg-desktop-portal config restored"
    else
        # Create default if not in backup
        show_progress "Creating xdg-desktop-portal config"
        sudo -u "$ACTUAL_USER" mkdir -p "$portal_dest"
        cat <<EOF | sudo -u "$ACTUAL_USER" tee "$portal_dest/portals.conf" >/dev/null
[preferred]
default=kde
org.freedesktop.impl.portal.ScreenCast=kde
org.freedesktop.impl.portal.Screenshot=kde
EOF
        finish_progress
        log_message "xdg-desktop-portal config created"
    fi

    # GTK 3.0 configuration
    local gtk3_src="$MOKKA_CONFIG_DIR/configs/gtk-3.0"
    local gtk3_dest="/home/$ACTUAL_USER/.config/gtk-3.0"
    if [[ -d "$gtk3_src" ]]; then
        show_progress "Restoring GTK 3.0 config"
        sudo -u "$ACTUAL_USER" mkdir -p "$gtk3_dest"
        sudo -u "$ACTUAL_USER" cp -r "$gtk3_src"/* "$gtk3_dest/" 2>/dev/null
        finish_progress
        log_message "GTK 3.0 config restored"
    fi

    # GTK 4.0 configuration
    local gtk4_src="$MOKKA_CONFIG_DIR/configs/gtk-4.0"
    local gtk4_dest="/home/$ACTUAL_USER/.config/gtk-4.0"
    if [[ -d "$gtk4_src" ]]; then
        show_progress "Restoring GTK 4.0 config"
        sudo -u "$ACTUAL_USER" mkdir -p "$gtk4_dest"
        sudo -u "$ACTUAL_USER" cp -r "$gtk4_src"/* "$gtk4_dest/" 2>/dev/null
        finish_progress
        log_message "GTK 4.0 config restored"
    fi

    # Kvantum configuration
    local kvantum_src="$MOKKA_CONFIG_DIR/configs/kvantum/kvantum.kvconfig"
    local kvantum_dest="/home/$ACTUAL_USER/.config/Kvantum"
    if [[ -f "$kvantum_src" ]]; then
        show_progress "Restoring Kvantum theme config"
        sudo -u "$ACTUAL_USER" mkdir -p "$kvantum_dest"
        sudo -u "$ACTUAL_USER" cp "$kvantum_src" "$kvantum_dest/" 2>/dev/null
        finish_progress
        log_message "Kvantum theme config restored"
    fi

    # Icons default (cursor fallback)
    local icons_src="$MOKKA_CONFIG_DIR/configs/icons-default/index.theme"
    if [[ -f "$icons_src" ]]; then
        show_progress "Restoring default cursor theme"
        sudo -u "$ACTUAL_USER" mkdir -p "/home/$ACTUAL_USER/.icons/default"
        sudo -u "$ACTUAL_USER" cp "$icons_src" "/home/$ACTUAL_USER/.icons/default/" 2>/dev/null
        finish_progress
        log_message "Default cursor theme restored"
    else
        # Create default cursor theme pointing to Catppuccin
        show_progress "Setting default cursor theme"
        sudo -u "$ACTUAL_USER" mkdir -p "/home/$ACTUAL_USER/.icons/default"
        cat << 'EOF' | sudo -u "$ACTUAL_USER" tee "/home/$ACTUAL_USER/.icons/default/index.theme" >/dev/null
[Icon Theme]
Name=Default
Comment=Default Cursor Theme
Inherits=catppuccin-mocha-mauve-cursors
EOF
        finish_progress
        log_message "Default cursor theme set to catppuccin-mocha-mauve-cursors"
    fi

    # Dolphin toolbar layout
    local dolphin_layout_src="$MOKKA_CONFIG_DIR/configs/dolphin-layout/dolphinui.rc"
    if [[ -f "$dolphin_layout_src" ]]; then
        show_progress "Restoring Dolphin toolbar layout"
        sudo -u "$ACTUAL_USER" mkdir -p "/home/$ACTUAL_USER/.local/share/kxmlgui5/dolphin"
        sudo -u "$ACTUAL_USER" cp "$dolphin_layout_src" "/home/$ACTUAL_USER/.local/share/kxmlgui5/dolphin/" 2>/dev/null
        finish_progress
        log_message "Dolphin toolbar layout restored"
    fi

    # Dolphin state (panel visibility)
    local dolphin_state_src="$MOKKA_CONFIG_DIR/configs/state/dolphinstaterc"
    if [[ -f "$dolphin_state_src" ]]; then
        show_progress "Restoring Dolphin panel state"
        sudo -u "$ACTUAL_USER" mkdir -p "/home/$ACTUAL_USER/.local/state"
        sudo -u "$ACTUAL_USER" cp "$dolphin_state_src" "/home/$ACTUAL_USER/.local/state/" 2>/dev/null
        finish_progress
        log_message "Dolphin panel state restored"
    fi

    # Dolphin view properties (icon size, hidden files sorting)
    local dolphin_view_props_src="$MOKKA_CONFIG_DIR/configs/dolphin/view_properties"
    if [[ -d "$dolphin_view_props_src" ]]; then
        show_progress "Restoring Dolphin view properties"
        sudo -u "$ACTUAL_USER" mkdir -p "/home/$ACTUAL_USER/.local/share/dolphin/view_properties"
        sudo -u "$ACTUAL_USER" cp -r "$dolphin_view_props_src/"* "/home/$ACTUAL_USER/.local/share/dolphin/view_properties/" 2>/dev/null
        finish_progress
        log_message "Dolphin view properties restored"
    fi

    # Samba configuration for network browsing
    local smb_src="$MOKKA_CONFIG_DIR/configs/samba/smb.conf"
    if [[ -f "$smb_src" ]]; then
        show_progress "Configuring Samba for network browsing"
        sudo cp "$smb_src" /etc/samba/smb.conf
        sudo chmod 644 /etc/samba/smb.conf
        
        # Create usershare directory
        sudo mkdir -p /var/lib/samba/usershare
        sudo chmod 1770 /var/lib/samba/usershare
        sudo chown root:sambashare /var/lib/samba/usershare 2>/dev/null || sudo chown root:users /var/lib/samba/usershare
        
        # Enable nmb service for network discovery
        sudo systemctl enable nmb.service >/dev/null 2>&1
        sudo systemctl enable smb.service >/dev/null 2>&1

        finish_progress
        log_message "Samba configured for network browsing"
    fi

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
    log_message "CIFS mounts configured for Synology"

    # Update nsswitch.conf for mdns resolution
    if [[ -f /etc/nsswitch.conf ]]; then
        show_progress "Configuring mdns resolution"
        # Check if already configured
        if ! grep -q "mdns_minimal" /etc/nsswitch.conf; then
            sudo sed -i 's/^hosts:.*/hosts: mymachines mdns_minimal [NOTFOUND=return] resolve [!UNAVAIL=return] files myhostname dns/' /etc/nsswitch.conf
        fi
        finish_progress
        log_message "mdns resolution configured"
    fi

    log_success "System configuration files restored"
}

# ============================================================================
# CONFIGURE KDE WALLET
# ============================================================================

configure_kde_wallet() {
    show_progress "Configuring KDE Wallet"

    local kwalletrc="/home/$ACTUAL_USER/.config/kwalletrc"
    
    # Only create if not restored from backup
    if [[ ! -f "$kwalletrc" ]]; then
        # Simple config to skip first-use wizard
        cat <<EOF | sudo -u "$ACTUAL_USER" tee "$kwalletrc" >/dev/null
[Wallet]
First Use=false
EOF
    fi

    # Create the default wallet directory
    local wallet_dir="/home/$ACTUAL_USER/.local/share/kwalletd"
    sudo -u "$ACTUAL_USER" mkdir -p "$wallet_dir"

    # Enable PAM auto-unlock for KDE Wallet
    local sddm_pam="/etc/pam.d/sddm"
    if [[ -f "$sddm_pam" ]]; then
        if ! grep -q "pam_kwallet5.so" "$sddm_pam"; then
            # Add kwallet PAM modules (matches working Garuda config)
            sudo sed -i '1a -auth       optional    pam_kwallet5.so' "$sddm_pam"
            sudo sed -i '$a -session    optional    pam_kwallet5.so         auto_start' "$sddm_pam"
        fi
    fi

    # Set correct ownership
    sudo chown -R "$ACTUAL_USER:$ACTUAL_USER" "$wallet_dir"
    if [[ -f "$kwalletrc" ]]; then
        sudo chown "$ACTUAL_USER:$ACTUAL_USER" "$kwalletrc"
    fi

    finish_progress
    log_message "KDE Wallet configured with PAM auto-unlock"
}

# ============================================================================
# CREATE DOLPHIN BOOKMARKS (SYNOLOGY NAS)
# ============================================================================

create_dolphin_bookmarks() {
    show_progress "Restoring Dolphin bookmarks from backup"

    if [[ -z "$MOKKA_CONFIG_DIR" || ! -d "$MOKKA_CONFIG_DIR" ]]; then
        log_warning "Mokka config directory not set, skipping Dolphin bookmarks"
        finish_progress
        return 1
    fi

    local dolphin_src="$MOKKA_CONFIG_DIR/configs/dolphin"
    local places_file="/home/$ACTUAL_USER/.local/share/user-places.xbel"
    
    sudo -u "$ACTUAL_USER" mkdir -p "/home/$ACTUAL_USER/.local/share"

    # Restore user-places.xbel from backup if it exists
    if [[ -f "$dolphin_src/user-places.xbel" ]]; then
        sudo -u "$ACTUAL_USER" cp "$dolphin_src/user-places.xbel" "$places_file" 2>/dev/null
        sudo chown "$ACTUAL_USER:$ACTUAL_USER" "$places_file"
        finish_progress
        log_success "Dolphin bookmarks restored from backup"
    else
        finish_progress
        log_warning "Dolphin bookmarks not found in backup"
    fi
}

# ============================================================================
# INSTALL THEME FILES
# ============================================================================

install_theme_files() {
    printf "[*] Installing Mokka theme files\n"

    if [[ -z "$MOKKA_CONFIG_DIR" || ! -d "$MOKKA_CONFIG_DIR" ]]; then
        log_error "Mokka config directory not set"
        return 1
    fi

    local themes_src="$MOKKA_CONFIG_DIR/themes"

    # Install all themes in background with animated progress
    {
        # Install Mokka look-and-feel theme (prefer complete backup version)
        if [[ -d "$themes_src/Mokka-lookandfeel" ]]; then
            sudo mkdir -p /usr/share/plasma/look-and-feel
            sudo cp -r "$themes_src/Mokka-lookandfeel" /usr/share/plasma/look-and-feel/Mokka
            sudo chmod -R 755 /usr/share/plasma/look-and-feel/Mokka
        elif [[ -d "$themes_src/Mokka" ]]; then
            sudo mkdir -p /usr/share/plasma/look-and-feel
            sudo cp -r "$themes_src/Mokka" /usr/share/plasma/look-and-feel/
            sudo chmod -R 755 /usr/share/plasma/look-and-feel/Mokka
        fi

        # Install CatppuccinMocha-Classic window decoration
        if [[ -d "$themes_src/CatppuccinMocha-Classic" ]]; then
            sudo mkdir -p /usr/share/aurorae/themes
            sudo cp -r "$themes_src/CatppuccinMocha-Classic" /usr/share/aurorae/themes/
        fi

        # Install Kvantum theme
        if [[ -d "$themes_src/Kvantum-Mokka" ]]; then
            local kvantum_dir="/home/$ACTUAL_USER/.config/Kvantum"
            sudo -u "$ACTUAL_USER" mkdir -p "$kvantum_dir"
            sudo -u "$ACTUAL_USER" cp -r "$themes_src/Kvantum-Mokka" "$kvantum_dir/Mokka"
        fi

        # Install color schemes
        if [[ -d "$themes_src/color-schemes" ]]; then
            local color_dir="/home/$ACTUAL_USER/.local/share/color-schemes"
            sudo -u "$ACTUAL_USER" mkdir -p "$color_dir"
            sudo -u "$ACTUAL_USER" cp "$themes_src/color-schemes"/*.colors "$color_dir/" 2>/dev/null
        fi

        # Install Konsole colorscheme
        if [[ -f "$themes_src/Mokka.colorscheme" ]]; then
            sudo mkdir -p /usr/share/konsole
            sudo cp "$themes_src/Mokka.colorscheme" /usr/share/konsole/
        fi

        # Install Mokka fastfetch logo
        if [[ -f "$themes_src/mokka-fastfetch.png" ]]; then
            sudo mkdir -p /usr/share/icons/garuda
            sudo cp "$themes_src/mokka-fastfetch.png" /usr/share/icons/garuda/
        fi

        # Install Mokka Plasma desktoptheme
        if [[ -d "$themes_src/desktoptheme-Mokka" ]]; then
            sudo mkdir -p /usr/share/plasma/desktoptheme
            sudo cp -r "$themes_src/desktoptheme-Mokka" /usr/share/plasma/desktoptheme/Mokka
            sudo chmod -R 755 /usr/share/plasma/desktoptheme/Mokka
        fi

        # Install SDDM theme from backup
        if [[ -d "$themes_src/sddm-Catppuccin-Mocha-Mauve" ]]; then
            sudo mkdir -p /usr/share/sddm/themes
            sudo cp -r "$themes_src/sddm-Catppuccin-Mocha-Mauve" /usr/share/sddm/themes/Catppuccin-Mocha-Mauve
            sudo chmod -R 755 /usr/share/sddm/themes/Catppuccin-Mocha-Mauve
        fi

        # Restore custom Mokka icons (ghostty, firedragon, firefox, chrome, vscode)
        local icons_src="$MOKKA_CONFIG_DIR/icons/custom"
        local icons_dest="/usr/share/icons/Tela-circle-dracula-dark/scalable/apps"

        if [[ -d "$icons_src" ]]; then
            cp "$icons_src"/*.svg "$icons_dest/" 2>/dev/null
            
            # Update icon cache
            if command_exists gtk-update-icon-cache; then
                gtk-update-icon-cache -f "/usr/share/icons/Tela-circle-dracula-dark" 2>/dev/null || true
            fi
        fi
    } &
    local pid=$!
    show_animated_progress_bar "Installing Mokka themes and visual components" "$pid"
    wait "$pid"

    log_success "Theme files and custom icons installed"
}

# ============================================================================
# INSTALL WALLPAPERS
# ============================================================================

install_wallpapers() {
    printf "[*] Installing Mokka wallpapers\n"

    if [[ -z "$MOKKA_CONFIG_DIR" || ! -d "$MOKKA_CONFIG_DIR" ]]; then
        log_error "Mokka config directory not set"
        return 1
    fi

    local wallpapers_src="$MOKKA_CONFIG_DIR/wallpapers"
    local wallpapers_dest="/usr/share/wallpapers/garuda-mokka"

    if [[ -d "$wallpapers_src" ]]; then
        show_progress "Installing wallpapers to system directory"
        sudo mkdir -p "$wallpapers_dest"
        sudo cp "$wallpapers_src"/* "$wallpapers_dest/" 2>/dev/null
        sudo chmod 644 "$wallpapers_dest"/*
        finish_progress
        log_success "Wallpapers installed to $wallpapers_dest"
    else
        log_warning "Wallpapers directory not found in config"
    fi
}

# ============================================================================
# APPLY KVANTUM THEME
# ============================================================================

apply_kvantum_theme() {
    show_progress "Configuring Kvantum Mokka theme"

    # Write config file directly (kvantummanager needs a running session)
    local kvantum_config="/home/$ACTUAL_USER/.config/Kvantum/kvantum.kvconfig"
    sudo -u "$ACTUAL_USER" mkdir -p "/home/$ACTUAL_USER/.config/Kvantum"
    
    cat << 'EOF' | sudo -u "$ACTUAL_USER" tee "$kvantum_config" >/dev/null
[General]
theme=Mokka
EOF

    finish_progress
    log_message "Kvantum theme configured for Mokka (will apply on login)"
}

# ============================================================================
# APPLY PLASMA GLOBAL THEME
# ============================================================================

apply_plasma_theme() {
    show_progress "Configuring Plasma Mokka theme"

    # Theme will be applied via autostart script on first login
    # Both plasma-apply-lookandfeel and cursortheme require a running Plasma session
    
    finish_progress
    log_message "Plasma theme configured (will apply on first login)"
}

# ============================================================================
# SET DEFAULT WALLPAPER
# ============================================================================

set_default_wallpaper() {
    show_progress "Setting default wallpaper to Mokka-tree.jpg"

    local wallpaper_path="/usr/share/wallpapers/garuda-mokka/Mokka-tree.jpg"
    local appletsrc="/home/$ACTUAL_USER/.config/plasma-org.kde.plasma.desktop-appletsrc"

    if [[ ! -f "$wallpaper_path" ]]; then
        log_warning "Mokka-tree.jpg wallpaper not found at $wallpaper_path"
        finish_progress
        return 1
    fi

    if [[ -f "$appletsrc" ]]; then
        # Update any existing wallpaper Image= lines to use the new path
        sudo -u "$ACTUAL_USER" sed -i "s|Image=file://.*|Image=file://$wallpaper_path|g" "$appletsrc" 2>/dev/null
        sudo -u "$ACTUAL_USER" sed -i "s|Image=.*Mokka.*|Image=file://$wallpaper_path|g" "$appletsrc" 2>/dev/null
        
        # Also update any old Garuda paths
        sudo -u "$ACTUAL_USER" sed -i "s|/usr/share/wallpapers/garuda/|/usr/share/wallpapers/garuda-mokka/|g" "$appletsrc" 2>/dev/null
        
        log_message "Updated wallpaper path in plasma config"
    else
        # Create minimal wallpaper config if appletsrc doesn't exist
        log_warning "plasma-appletsrc not found, wallpaper will need to be set manually after first login"
    fi

    finish_progress
}

# ============================================================================
# CONFIGURE KWIN EFFECTS
# ============================================================================

configure_kwin_effects() {
    show_progress "Configuring KWin effects"

    local kwinrc="/home/$ACTUAL_USER/.config/kwinrc"

    # Ensure kwinrc exists
    if [[ ! -f "$kwinrc" ]]; then
        sudo -u "$ACTUAL_USER" touch "$kwinrc"
    fi

    # Enable effects in kwinrc if not already configured
    # The main configuration should come from the restored kwinrc
    # This just ensures key effects are enabled

    # Force blur
    if ! grep -q "forceblurEnabled=true" "$kwinrc" 2>/dev/null; then
        if grep -q "\[Plugins\]" "$kwinrc"; then
            sed -i '/\[Plugins\]/a forceblurEnabled=true' "$kwinrc"
        else
            echo -e "\n[Plugins]\nforceblurEnabled=true" | sudo -u "$ACTUAL_USER" tee -a "$kwinrc" >/dev/null
        fi
    fi

    # Rounded corners
    if ! grep -q "kwin4_effect_roundedcornersEnabled=true" "$kwinrc" 2>/dev/null; then
        sed -i '/\[Plugins\]/a kwin4_effect_roundedcornersEnabled=true' "$kwinrc" 2>/dev/null
    fi

    # Reconfigure KWin
    if command_exists qdbus6; then
        sudo -u "$ACTUAL_USER" qdbus6 org.kde.KWin /KWin reconfigure >/dev/null 2>&1
    fi

    finish_progress
    log_message "KWin effects configured"
}

# ============================================================================
# END OF SECTION 3
# ============================================================================

# ============================================================================
# SECTION 4: TERMINAL TOOLS SETUP
# ============================================================================

# ============================================================================
# RESTORE TERMINAL CONFIGURATIONS
# ============================================================================

restore_terminal_configs() {
    printf "[*] Restoring terminal configuration files\n"

    if [[ -z "$MOKKA_CONFIG_DIR" || ! -d "$MOKKA_CONFIG_DIR" ]]; then
        log_error "Mokka config directory not set"
        return 1
    fi

    local terminal_src="$MOKKA_CONFIG_DIR/configs/terminal"
    local user_config="/home/$ACTUAL_USER/.config"

    # Restore Fish config
    if [[ -d "$terminal_src/fish" ]]; then
        show_progress "Restoring Fish shell configuration"
        sudo -u "$ACTUAL_USER" mkdir -p "$user_config/fish"
        sudo -u "$ACTUAL_USER" cp -r "$terminal_src/fish"/* "$user_config/fish/" 2>/dev/null
        finish_progress
    fi

    # Restore Starship config
    if [[ -f "$terminal_src/starship.toml" ]]; then
        show_progress "Restoring Starship configuration"
        sudo -u "$ACTUAL_USER" cp "$terminal_src/starship.toml" "$user_config/" 2>/dev/null
        finish_progress
    fi

    # Restore Fastfetch config
    if [[ -d "$terminal_src/fastfetch" ]]; then
        show_progress "Restoring Fastfetch configuration"
        sudo -u "$ACTUAL_USER" mkdir -p "$user_config/fastfetch"
        sudo -u "$ACTUAL_USER" cp -r "$terminal_src/fastfetch"/* "$user_config/fastfetch/" 2>/dev/null
        finish_progress
    fi

    # Restore Ghostty config
    if [[ -d "$terminal_src/ghostty" ]]; then
        show_progress "Restoring Ghostty configuration"
        sudo -u "$ACTUAL_USER" mkdir -p "$user_config/ghostty"
        sudo -u "$ACTUAL_USER" cp -r "$terminal_src/ghostty"/* "$user_config/ghostty/" 2>/dev/null
        finish_progress
    fi

    # Restore bat config
    if [[ -d "$terminal_src/bat" ]]; then
        show_progress "Restoring bat configuration"
        sudo -u "$ACTUAL_USER" mkdir -p "$user_config/bat"
        sudo -u "$ACTUAL_USER" cp -r "$terminal_src/bat"/* "$user_config/bat/" 2>/dev/null
        finish_progress
    fi

    # Restore btop config
    if [[ -d "$terminal_src/btop" ]]; then
        show_progress "Restoring btop configuration"
        sudo -u "$ACTUAL_USER" mkdir -p "$user_config/btop"
        sudo -u "$ACTUAL_USER" cp -r "$terminal_src/btop"/* "$user_config/btop/" 2>/dev/null
        finish_progress
    fi

    # Restore zoxide database
    local zoxide_src="$MOKKA_CONFIG_DIR/configs/zoxide"
    if [[ -d "$zoxide_src" ]]; then
        show_progress "Restoring zoxide directory history"
        sudo -u "$ACTUAL_USER" mkdir -p "/home/$ACTUAL_USER/.local/share"
        sudo -u "$ACTUAL_USER" cp -r "$zoxide_src" "/home/$ACTUAL_USER/.local/share/" 2>/dev/null
        finish_progress
    fi

    # Set correct ownership
    sudo chown -R "$ACTUAL_USER:$ACTUAL_USER" "$user_config"
    sudo chown -R "$ACTUAL_USER:$ACTUAL_USER" "/home/$ACTUAL_USER/.local/share/zoxide"

    log_success "Terminal configurations restored"
}

# ============================================================================
# FISH SHELL SETUP
# ============================================================================

setup_fish() {
    printf "[*] Setting up Fish shell\n"

    if ! is_package_installed "fish"; then
        install_packages "fish"
    fi

    # Set Fish as default shell
    show_progress "Setting Fish as default shell"
    local fish_path
    fish_path=$(which fish)
    
    if [[ -n "$fish_path" ]]; then
        # Add fish to /etc/shells if not present
        if ! grep -q "$fish_path" /etc/shells; then
            echo "$fish_path" | sudo tee -a /etc/shells >/dev/null
        fi
        
        # Change default shell for user
        sudo chsh -s "$fish_path" "$ACTUAL_USER" >/dev/null 2>&1 || log_warning "Failed to set Fish as default shell"
        finish_progress
        log_message "Fish set as default shell for $ACTUAL_USER"
    else
        log_error "Fish shell not found"
        finish_progress
        return 1
    fi

    # Ensure Fish config directory exists
    local fish_config_dir="/home/$ACTUAL_USER/.config/fish"
    sudo -u "$ACTUAL_USER" mkdir -p "$fish_config_dir/conf.d"
    sudo -u "$ACTUAL_USER" mkdir -p "$fish_config_dir/functions"
    sudo -u "$ACTUAL_USER" mkdir -p "$fish_config_dir/completions"

    # Create base config if not restored from backup
    if [[ ! -f "$fish_config_dir/config.fish" ]]; then
        show_progress "Creating Fish base configuration"
        cat <<'EOF' | sudo -u "$ACTUAL_USER" tee "$fish_config_dir/config.fish" >/dev/null
# Fish Shell Configuration - Mokka Theme

# Disable greeting
set -g fish_greeting

# Environment variables
set -gx EDITOR nano
set -gx VISUAL nano
set -gx TERM xterm-256color
set -gx SHELL /usr/bin/fish

# XDG Base Directory
set -gx XDG_CONFIG_HOME $HOME/.config
set -gx XDG_DATA_HOME $HOME/.local/share
set -gx XDG_CACHE_HOME $HOME/.cache

# Use bat for man pages with Catppuccin theme
set -gx MANPAGER "sh -c 'col -bx | bat -l man -p'"
set -gx MANROFFOPT "-c"

# FZF Catppuccin Mocha colors
set -gx FZF_DEFAULT_OPTS "\
--color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8 \
--color=fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc \
--color=marker:#f5e0dc,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8"

# Path additions
if test -d ~/.local/bin
    if not contains -- ~/.local/bin $PATH
        fish_add_path $HOME/.local/bin
    end
end

# Initialize Starship prompt
if command -q starship
    starship init fish | source
end

# Initialize Zoxide
if command -q zoxide
    zoxide init fish | source
end

# Initialize Carapace completions
if command -q carapace
    carapace _carapace | source
end

# FZF key bindings
if test -f /usr/share/fish/vendor_functions.d/fzf_key_bindings.fish
    source /usr/share/fish/vendor_functions.d/fzf_key_bindings.fish
end

## Functions

# Fish command history with timestamps
function history
    builtin history --show-time='%F %T '
end

# Backup file
function backup --argument filename
    cp $filename $filename.bak
end

# Cleanup orphaned packages (loops until none remain)
function cleanup
    while pacman -Qdtq
        sudo pacman -R (pacman -Qdtq)
        if test $status -eq 1
            break
        end
    end
end

# Quick command reference
function quick --description 'Show quick Fish command reference'
    echo ""
    echo "🚀 Quick Commands"
    echo "───────────────────"
    echo ""
    echo "📂 zi             # Browse and select from recent directories"
    echo "📂 z <query>      # Jump to directory matching query"
    echo "⮐ Ctrl+R         # Search through command history"
    echo "🧹 Ctrl+U         # Clear entire line"
    echo "✂️ Ctrl+K         # Delete from cursor to end"
    echo "⪢ Ctrl+A         # Jump to start of line"
    echo "⪡ Ctrl+E         # Jump to end of line"
    echo "🔄 Alt+←/→        # Navigate words"
    echo "📋 ll             # Detailed file list with icons"
    echo "👁️ la             # Show all files including hidden"
    echo "🔧 lg             # Launch lazygit"
    echo ""
end

## Abbreviations (expand on use - shows actual command in history)

# File listing with eza
alias ls 'eza -al --color=always --group-directories-first --icons'
alias la 'eza -a --color=always --group-directories-first --icons'
alias ll 'eza -l --color=always --group-directories-first --icons'
alias lt 'eza -aT --color=always --group-directories-first --icons'
alias l. 'eza -ald --color=always --group-directories-first --icons .*'

# Modern tool abbreviations (only if installed)
type -q bat && abbr --add cat 'bat --style header,snip,changes'
type -q rg && abbr --add grep 'rg --color=auto'
type -q fd && abbr --add find 'fd'
type -q btop && abbr --add top 'btop'
type -q dust && abbr --add du 'dust'
type -q procs && abbr --add ps 'procs'
type -q duf && abbr --add df 'duf'
type -q delta && abbr --add diff 'delta'
type -q lazygit && abbr --add lg 'lazygit'

# Clipboard
type -q wl-copy && abbr --add copy 'wl-copy'
type -q wl-paste && abbr --add paste 'wl-paste'

# Git abbreviations
abbr --add gs 'git status'
abbr --add ga 'git add'
abbr --add gc 'git commit'
abbr --add gp 'git push'
abbr --add gl 'git log --oneline'
abbr --add gd 'git diff'

# Directory navigation
alias .. 'cd ..'
alias ... 'cd ../..'
alias .... 'cd ../../..'
alias ..... 'cd ../../../..'

# Pacman
abbr --add update 'sudo pacman -Syu'
abbr --add install 'sudo pacman -S'
abbr --add remove 'sudo pacman -Rns'
abbr --add search 'pacman -Ss'

# Useful aliases
alias fixpacman 'sudo rm /var/lib/pacman/db.lck'
alias grubup 'sudo update-grub'
alias ip 'ip -color'
alias wget 'wget -c'

# Get fastest mirrors
alias mirror 'sudo reflector -f 30 -l 30 --number 10 --verbose --save /etc/pacman.d/mirrorlist'

# Journal errors
alias jctl 'journalctl -p 3 -xb'

# Recent installed packages
type -q expac && alias rip 'expac --timefmt="%Y-%m-%d %T" "%l\t%n %v" | sort | tail -200 | nl'

# Fastfetch on terminal start
if status is-interactive && type -q fastfetch
    fastfetch
end
EOF
        finish_progress
    fi

    # Create fish_title function for better window titles
    show_progress "Creating Fish title function"
    cat <<'FISH_TITLE_EOF' | sudo -u "$ACTUAL_USER" tee "$fish_config_dir/functions/fish_title.fish" >/dev/null
function fish_title
    set -l command_name (status current-command)
    set -l current_folder (prompt_pwd)
    echo "$current_folder: $command_name — Ghostty"
end
FISH_TITLE_EOF
    finish_progress

    # Apply Catppuccin Mocha theme to Fish
    show_progress "Installing and applying Catppuccin Mocha theme to Fish"
    
    # Install fish theme if not present
    local fish_themes_dir="/home/$ACTUAL_USER/.config/fish/themes"
    sudo -u "$ACTUAL_USER" mkdir -p "$fish_themes_dir"
    
    # Check if theme was restored from backup
    if [[ ! -f "$fish_themes_dir/Catppuccin Mocha.theme" ]]; then
        # Download Catppuccin Mocha theme for Fish
        curl -sL "https://raw.githubusercontent.com/catppuccin/fish/main/themes/Catppuccin%20Mocha.theme" \
            -o "$fish_themes_dir/Catppuccin Mocha.theme" 2>/dev/null || log_warning "Failed to download Fish theme"
        sudo chown "$ACTUAL_USER:$ACTUAL_USER" "$fish_themes_dir/Catppuccin Mocha.theme"
    fi
    
    # Apply the theme by creating the fish_variables file
    if [[ -f "$fish_themes_dir/Catppuccin Mocha.theme" ]]; then
        # Source the theme file to set variables (works non-interactively)
        sudo -u "$ACTUAL_USER" fish -c '
            set -l theme_file ~/.config/fish/themes/"Catppuccin Mocha.theme"
            if test -f $theme_file
                source $theme_file
                # Save key colors to universal variables
                set -U fish_color_normal $fish_color_normal
                set -U fish_color_command $fish_color_command
                set -U fish_color_keyword $fish_color_keyword
                set -U fish_color_quote $fish_color_quote
                set -U fish_color_redirection $fish_color_redirection
                set -U fish_color_end $fish_color_end
                set -U fish_color_error $fish_color_error
                set -U fish_color_param $fish_color_param
                set -U fish_color_comment $fish_color_comment
                set -U fish_color_selection $fish_color_selection
                set -U fish_color_operator $fish_color_operator
                set -U fish_color_escape $fish_color_escape
                set -U fish_color_autosuggestion $fish_color_autosuggestion
                set -U fish_color_cancel $fish_color_cancel
                set -U fish_color_cwd $fish_color_cwd
                set -U fish_color_user $fish_color_user
                set -U fish_color_host $fish_color_host
                set -U fish_pager_color_progress $fish_pager_color_progress
                set -U fish_pager_color_prefix $fish_pager_color_prefix
                set -U fish_pager_color_completion $fish_pager_color_completion
                set -U fish_pager_color_description $fish_pager_color_description
            end
        ' 2>/dev/null
        log_message "Fish theme colors applied"
    fi
    finish_progress

    log_success "Fish shell configured"
}

# ============================================================================
# STARSHIP PROMPT SETUP
# ============================================================================

setup_starship() {
    printf "[*] Setting up Starship prompt\n"

    # Install starship if not present
    if ! is_package_installed "starship"; then
        install_aur_packages "starship"
    fi

    # Create config if not restored from backup
    local starship_config="/home/$ACTUAL_USER/.config/starship.toml"
    
    if [[ ! -f "$starship_config" ]]; then
        show_progress "Creating Starship configuration"
        cat <<'EOF' | sudo -u "$ACTUAL_USER" tee "$starship_config" >/dev/null
# Starship Configuration - Catppuccin Mocha Theme

format = """
[](#cba6f7)\
$os\
$username\
[](bg:#f38ba8 fg:#cba6f7)\
$directory\
[](fg:#f38ba8 bg:#fab387)\
$git_branch\
$git_status\
[](fg:#fab387 bg:#a6e3a1)\
$c\
$rust\
$golang\
$nodejs\
$php\
$java\
$kotlin\
$haskell\
$python\
[](fg:#a6e3a1 bg:#89dceb)\
$docker_context\
[](fg:#89dceb bg:#b4befe)\
$time\
[ ](fg:#b4befe)\
$character"""

# Disable the blank line at the start of the prompt
add_newline = false

[os]
disabled = false
style = "bg:#cba6f7 fg:#1e1e2e"

[os.symbols]
Arch = "󰣇"
Linux = "󰌽"
Macos = "󰀵"
Windows = "󰍲"

[username]
show_always = true
style_user = "bg:#cba6f7 fg:#1e1e2e"
style_root = "bg:#cba6f7 fg:#1e1e2e"
format = '[ $user ]($style)'
disabled = false

[directory]
style = "bg:#f38ba8 fg:#1e1e2e"
format = "[ $path ]($style)"
truncation_length = 3
truncation_symbol = "…/"

[directory.substitutions]
"Documents" = "󰈙 "
"Downloads" = " "
"Music" = "󰝚 "
"Pictures" = " "
"Developer" = "󰲋 "

[git_branch]
symbol = ""
style = "bg:#fab387 fg:#1e1e2e"
format = '[ $symbol $branch ]($style)'

[git_status]
style = "bg:#fab387 fg:#1e1e2e"
format = '[$all_status$ahead_behind ]($style)'

[nodejs]
symbol = ""
style = "bg:#a6e3a1 fg:#1e1e2e"
format = '[ $symbol ($version) ]($style)'

[rust]
symbol = ""
style = "bg:#a6e3a1 fg:#1e1e2e"
format = '[ $symbol ($version) ]($style)'

[golang]
symbol = ""
style = "bg:#a6e3a1 fg:#1e1e2e"
format = '[ $symbol ($version) ]($style)'

[php]
symbol = ""
style = "bg:#a6e3a1 fg:#1e1e2e"
format = '[ $symbol ($version) ]($style)'

[java]
symbol = ""
style = "bg:#a6e3a1 fg:#1e1e2e"
format = '[ $symbol ($version) ]($style)'

[kotlin]
symbol = ""
style = "bg:#a6e3a1 fg:#1e1e2e"
format = '[ $symbol ($version) ]($style)'

[haskell]
symbol = ""
style = "bg:#a6e3a1 fg:#1e1e2e"
format = '[ $symbol ($version) ]($style)'

[python]
symbol = ""
style = "bg:#a6e3a1 fg:#1e1e2e"
format = '[ $symbol ($version) ]($style)'

[docker_context]
symbol = ""
style = "bg:#89dceb fg:#1e1e2e"
format = '[ $symbol $context ]($style)'

[c]
symbol = ""
style = "bg:#a6e3a1 fg:#1e1e2e"
format = '[ $symbol ($version) ]($style)'

[time]
disabled = false
time_format = "%R"
style = "bg:#b4befe fg:#1e1e2e"
format = '[  $time ]($style)'

[character]
success_symbol = '[❯](bold #a6e3a1)'
error_symbol = '[❯](bold #f38ba8)'
EOF
        finish_progress
    fi

    log_success "Starship prompt configured"
}

# ============================================================================
# FASTFETCH SETUP
# ============================================================================

setup_fastfetch() {
    printf "[*] Setting up Fastfetch\n"

    if ! is_package_installed "fastfetch"; then
        install_packages "fastfetch"
    fi

    # Create config if not restored from backup
    local fastfetch_config="/home/$ACTUAL_USER/.config/fastfetch/config.jsonc"
    
    if [[ ! -f "$fastfetch_config" ]]; then
        show_progress "Creating Fastfetch configuration"
        sudo -u "$ACTUAL_USER" mkdir -p "/home/$ACTUAL_USER/.config/fastfetch"
        
        cat <<'EOF' | sudo -u "$ACTUAL_USER" tee "$fastfetch_config" >/dev/null
{
  "$schema": "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json",
  "logo": {
    "type": "kitty",
    "source": "/usr/share/icons/garuda/mokka-fastfetch.png",
    "width": 40
  },
  "display": {
    "separator": " "
  },
  "modules": [
    {
      "type": "title",
      "keyWidth": 10
    },
    {
      "type": "os",
      "key": " OS",
      "keyColor": "#f9e2af"
    },
    {
      "type": "kernel",
      "key": "├ Kernel",
      "keyColor": "#f9e2af"
    },
    {
      "type": "packages",
      "key": "├󰏖 Packages",
      "keyColor": "#f9e2af"
    },
    {
      "type": "shell",
      "key": "├ Shell",
      "keyColor": "#f9e2af"
    },
    {
      "type": "command",
      "key": "└ Age",
      "keyColor": "#f9e2af",
      "text": "birth_install=$(stat -c %W /); current=$(date +%s); time_progression=$((current - birth_install)); days_difference=$((time_progression / 86400)); echo $days_difference days"
    },
    "break",
    {
      "type": "de",
      "key": " DE",
      "keyColor": "#89b4fa"
    },
    {
      "type": "wm",
      "key": "├󰧨 Window Manager",
      "keyColor": "#89b4fa"
    },
    {
      "type": "lm",
      "key": "├󰧨 Login Manager",
      "keyColor": "#89b4fa"
    },
    {
      "type": "wmtheme",
      "key": "├󰉼 WM Theme",
      "keyColor": "#89b4fa"
    },
    {
      "type": "theme",
      "format": "{1}",
      "key": "├󰉼 Color Themes",
      "keyColor": "#89b4fa"
    },
    {
      "type": "icons",
      "format": "{1}",
      "key": "├󰀻 System Icons",
      "keyColor": "#89b4fa"
    },
    {
      "type": "font",
      "format": "{?1}{1} [Qt]{?}{/1}Unknown",
      "key": "├ System Fonts",
      "keyColor": "#89b4fa"
    },
    {
      "type": "terminal",
      "key": "└ Terminal",
      "keyColor": "#89b4fa"
    },
    "break",
    {
      "type": "chassis",
      "key": "󰌢 PC",
      "keyColor": "#a6e3a1"
    },
    {
      "type": "cpu",
      "key": "├󰻠 CPU",
      "keyColor": "#a6e3a1"
    },
    {
      "type": "gpu",
      "key": "├󰍛 GPU",
      "keyColor": "#a6e3a1"
    },
    {
      "type": "opengl",
      "key": "├󰍛 OpenGL",
      "keyColor": "#a6e3a1"
    },
    {
      "type": "vulkan",
      "key": "├󰍛 Vulkan",
      "keyColor": "#a6e3a1"
    },
    {
      "type": "display",
      "key": "└󰍹 Display(s)",
      "keyColor": "#a6e3a1"
    }
  ]
}
EOF
        finish_progress
    fi

    log_success "Fastfetch configured"
}

# ============================================================================
# GHOSTTY SETUP
# ============================================================================

setup_ghostty() {
    printf "[*] Setting up Ghostty terminal\n"

    if ! is_package_installed "ghostty"; then
        install_aur_packages "ghostty"
    fi

    # Create config if not restored from backup
    local ghostty_config="/home/$ACTUAL_USER/.config/ghostty/config"
    
    if [[ ! -f "$ghostty_config" ]]; then
        show_progress "Creating Ghostty configuration"
        sudo -u "$ACTUAL_USER" mkdir -p "/home/$ACTUAL_USER/.config/ghostty"
        
        cat <<'EOF' | sudo -u "$ACTUAL_USER" tee "$ghostty_config" >/dev/null
# Ghostty Configuration - Catppuccin Mocha Theme

# Font
font-family = JetBrainsMono Nerd Font
font-size = 12
font-style = Bold

# Window
window-padding-x = 10
window-padding-y = 10
window-decoration = false
gtk-titlebar = false

# Opacity and blur
background-opacity = 0.9
background-blur-radius = 20

# Cursor
cursor-style = block
cursor-style-blink = true
cursor-color = #f38ba8

# Shell
command = /usr/bin/fish

# Scrollback
scrollback-limit = 10000

# Copy/Paste
copy-on-select = true
confirm-close-surface = false

# Catppuccin Mocha Colors
background = #1e1e2e
foreground = #cdd6f4
selection-background = #585b70
selection-foreground = #cdd6f4

# Normal colors
palette = 0=#45475a
palette = 1=#f38ba8
palette = 2=#a6e3a1
palette = 3=#f9e2af
palette = 4=#89b4fa
palette = 5=#f5c2e7
palette = 6=#94e2d5
palette = 7=#bac2de

# Bright colors
palette = 8=#585b70
palette = 9=#f38ba8
palette = 10=#a6e3a1
palette = 11=#f9e2af
palette = 12=#89b4fa
palette = 13=#f5c2e7
palette = 14=#94e2d5
palette = 15=#a6adc8
EOF
        finish_progress
    fi

    log_success "Ghostty terminal configured"
}

# ============================================================================
# KONSOLE SETUP
# ============================================================================

setup_konsole() {
    printf "[*] Setting up Konsole terminal\n"

    local konsole_local="/home/$ACTUAL_USER/.local/share/konsole"
    sudo -u "$ACTUAL_USER" mkdir -p "$konsole_local"

    # Create default profile
    show_progress "Creating Konsole default profile"
    cat <<EOF | sudo -u "$ACTUAL_USER" tee "$konsole_local/Default.profile" >/dev/null
[Appearance]
ColorScheme=Mokka
Font=JetBrainsMono Nerd Font,12,-1,5,63,0,0,0,0,0,Bold

[General]
Command=/usr/bin/fish
Name=Default
Parent=FALLBACK/

[Scrolling]
HistoryMode=2
ScrollBarPosition=2

[Terminal Features]
BlinkingCursorEnabled=true
EOF
    finish_progress

    # Set default profile in konsolerc
    local konsolerc="/home/$ACTUAL_USER/.config/konsolerc"
    if [[ -f "$konsolerc" ]]; then
        show_progress "Setting Konsole default profile"
        # Update or add DefaultProfile
        if grep -q "DefaultProfile=" "$konsolerc"; then
            sed -i 's/DefaultProfile=.*/DefaultProfile=Default.profile/' "$konsolerc"
        else
            echo -e "\n[Desktop Entry]\nDefaultProfile=Default.profile" | sudo -u "$ACTUAL_USER" tee -a "$konsolerc" >/dev/null
        fi
        finish_progress
    else
        # Create konsolerc with default profile
        show_progress "Creating Konsole configuration"
        cat <<EOF | sudo -u "$ACTUAL_USER" tee "$konsolerc" >/dev/null
[Desktop Entry]
DefaultProfile=Default.profile

[MainWindow]
MenuBar=Disabled
ToolBarsMovable=Disabled
EOF
        finish_progress
    fi

    log_success "Konsole terminal configured"
}

# ============================================================================
# ZOXIDE SETUP
# ============================================================================

setup_zoxide() {
    show_progress "Setting up Zoxide"

    if ! is_package_installed "zoxide"; then
        install_packages "zoxide"
    fi

    # Zoxide is initialized in Fish config
    # Just verify it's working
    if command_exists zoxide; then
        log_message "Zoxide installed and will be initialized by Fish"
    else
        log_warning "Zoxide not found after installation"
    fi

    finish_progress
}

# ============================================================================
# CARAPACE SETUP
# ============================================================================

setup_carapace() {
    show_progress "Setting up Carapace completions"

    if ! is_package_installed "carapace-bin"; then
        install_aur_packages "carapace-bin"
    fi

    # Carapace is initialized in Fish config
    if command_exists carapace; then
        log_message "Carapace installed and will be initialized by Fish"
    else
        log_warning "Carapace not found after installation"
    fi

    finish_progress
}

# ============================================================================
# DELTA SETUP
# ============================================================================

setup_delta() {
    show_progress "Setting up Delta git diff viewer"

    if ! is_package_installed "git-delta"; then
        install_packages "git-delta"
    fi

    # Configure git to use delta
    sudo -u "$ACTUAL_USER" git config --global core.pager delta
    sudo -u "$ACTUAL_USER" git config --global interactive.diffFilter "delta --color-only"
    sudo -u "$ACTUAL_USER" git config --global delta.navigate true
    sudo -u "$ACTUAL_USER" git config --global delta.light false
    sudo -u "$ACTUAL_USER" git config --global delta.side-by-side true
    sudo -u "$ACTUAL_USER" git config --global merge.conflictstyle diff3
    sudo -u "$ACTUAL_USER" git config --global diff.colorMoved default

    finish_progress
    log_message "Delta configured as git pager"
}

# ============================================================================
# BAT SETUP
# ============================================================================

setup_bat() {
    show_progress "Setting up bat with Catppuccin Mocha theme"

    if ! is_package_installed "bat"; then
        install_packages "bat"
    fi

    # Create bat config directory
    local bat_config="/home/$ACTUAL_USER/.config/bat/config"
    sudo -u "$ACTUAL_USER" mkdir -p "/home/$ACTUAL_USER/.config/bat"

    # Configure bat with Catppuccin Mocha theme
    echo '--theme="Catppuccin Mocha"' | sudo -u "$ACTUAL_USER" tee "$bat_config" >/dev/null

    finish_progress
    log_message "Bat configured with Catppuccin Mocha theme"
}

# ============================================================================
# LAZYGIT SETUP
# ============================================================================

setup_lazygit() {
    show_progress "Setting up Lazygit"

    if ! is_package_installed "lazygit"; then
        install_packages "lazygit"
    fi

    # Create lazygit config with Catppuccin theme
    local lazygit_config="/home/$ACTUAL_USER/.config/lazygit/config.yml"
    sudo -u "$ACTUAL_USER" mkdir -p "$(dirname "$lazygit_config")"

    cat <<'EOF' | sudo -u "$ACTUAL_USER" tee "$lazygit_config" >/dev/null
gui:
  theme:
    activeBorderColor:
      - "#a6e3a1"
      - bold
    inactiveBorderColor:
      - "#a6adc8"
    optionsTextColor:
      - "#89b4fa"
    selectedLineBgColor:
      - "#313244"
    cherryPickedCommitBgColor:
      - "#45475a"
    cherryPickedCommitFgColor:
      - "#a6e3a1"
    unstagedChangesColor:
      - "#f38ba8"
    defaultFgColor:
      - "#cdd6f4"
    searchingActiveBorderColor:
      - "#f9e2af"
  nerdFontsVersion: "3"
EOF

    finish_progress
    log_message "Lazygit configured with Catppuccin theme"
}

# ============================================================================
# NANO SETUP
# ============================================================================

setup_nano() {
    show_progress "Setting up Nano editor"

    if ! is_package_installed "nano"; then
        install_packages "nano"
    fi

    # Create nano config
    local nanorc="/home/$ACTUAL_USER/.nanorc"

    cat <<'EOF' | sudo -u "$ACTUAL_USER" tee "$nanorc" >/dev/null
# Nano Configuration

# Enable line numbers
set linenumbers

# Enable mouse support
set mouse

# Smooth scrolling
set smooth

# Auto indent
set autoindent

# Tab size
set tabsize 4
set tabstospaces

# Enable syntax highlighting
include "/usr/share/nano/*.nanorc"
include "/usr/share/nano/extra/*.nanorc"
include "/usr/share/nano-syntax-highlighting/*.nanorc"

# Show cursor position
set constantshow

# Enable soft wrapping
set softwrap

# Use bold instead of reverse video
set boldtext
EOF

    finish_progress
    log_message "Nano editor configured"
}

# ============================================================================
# BTOP SETUP
# ============================================================================

setup_btop() {
    show_progress "Setting up Btop"

    if ! is_package_installed "btop"; then
        install_packages "btop"
    fi

    # Create btop config directory
    local btop_config_dir="/home/$ACTUAL_USER/.config/btop"
    sudo -u "$ACTUAL_USER" mkdir -p "$btop_config_dir/themes"

    # Download Catppuccin Mocha theme
    local theme_url="https://raw.githubusercontent.com/catppuccin/btop/main/themes/catppuccin_mocha.theme"
    if curl -sL "$theme_url" -o "/tmp/catppuccin_mocha.theme"; then
        sudo -u "$ACTUAL_USER" cp "/tmp/catppuccin_mocha.theme" "$btop_config_dir/themes/"
        rm -f "/tmp/catppuccin_mocha.theme"
        log_message "Btop Catppuccin Mocha theme installed"
    else
        log_warning "Failed to download btop theme"
    fi

    # Create btop config with Catppuccin theme
    cat <<'EOF' | sudo -u "$ACTUAL_USER" tee "$btop_config_dir/btop.conf" >/dev/null
#? Config file for btop

color_theme = "catppuccin_mocha"
theme_background = False
truecolor = True
force_tty = False
vim_keys = True
rounded_corners = True
graph_symbol = "braille"
shown_boxes = "cpu mem net proc"
update_ms = 1000
proc_sorting = "cpu lazy"
proc_reversed = False
proc_tree = False
proc_colors = True
proc_gradient = True
proc_per_core = True
proc_mem_bytes = True
proc_cpu_graphs = True
EOF

    finish_progress
    log_message "Btop configured with Catppuccin theme"

    # Remove useless desktop icon (btop is terminal-only)
    sudo rm -f /usr/share/applications/btop.desktop 2>/dev/null
}

# ============================================================================
# END OF SECTION 4
# ============================================================================

# ============================================================================
# SECTION 5: SDDM, CLEANUP, SUMMARY, MAIN FUNCTION
# ============================================================================

# ============================================================================
# SDDM CONFIGURATION
# ============================================================================

setup_sddm() {
    printf "[*] Configuring SDDM login manager\n"

    # Ensure SDDM is installed
    if ! is_package_installed "sddm"; then
        install_packages "sddm" "sddm-kcm"
    fi

    # Create SDDM config directory
    sudo mkdir -p /etc/sddm.conf.d

    # Remove any conflicting config
    sudo rm -f /etc/sddm.conf.d/kde_settings.conf 2>/dev/null

    # Check for backup SDDM configs
    local sddm_config_src="$MOKKA_CONFIG_DIR/configs/sddm"
    
    if [[ -d "$sddm_config_src" ]]; then
        show_progress "Restoring SDDM configuration from backup"
        sudo cp "$sddm_config_src"/*.conf /etc/sddm.conf.d/ 2>/dev/null
        sudo chmod 644 /etc/sddm.conf.d/*.conf
        finish_progress
        log_message "SDDM config restored from backup"
    else
        # Fallback: Create default config if no backup
        log_warning "No SDDM backup config found, creating default"
        
        # Detect display scaling
        local scale_factor="1.0"
        
        # Try to detect from existing KDE config
        local kwinoutputconfig="/home/$ACTUAL_USER/.config/kwinoutputconfig.json"
        if [[ -f "$kwinoutputconfig" ]]; then
            local detected_scale
            detected_scale=$(grep -o '"scale":[0-9.]*' "$kwinoutputconfig" 2>/dev/null | head -1 | cut -d':' -f2)
            if [[ -n "$detected_scale" && "$detected_scale" != "1" ]]; then
                scale_factor="$detected_scale"
            fi
        fi

        # Check kdeglobals for scale
        local kdeglobals="/home/$ACTUAL_USER/.config/kdeglobals"
        if [[ -f "$kdeglobals" && "$scale_factor" == "1.0" ]]; then
            local kde_scale
            kde_scale=$(grep "ScaleFactor=" "$kdeglobals" 2>/dev/null | cut -d'=' -f2)
            if [[ -n "$kde_scale" && "$kde_scale" != "1" ]]; then
                scale_factor="$kde_scale"
            fi
        fi

        # Default to 1.9 for 4K displays if nothing detected
        if [[ "$scale_factor" == "1.0" ]]; then
            local resolution
            resolution=$(xrandr 2>/dev/null | grep '\*' | head -1 | awk '{print $1}')
            if [[ "$resolution" == "3840x2160" || "$resolution" == "2560x1440" ]]; then
                scale_factor="1.9"
                log_message "Detected high-resolution display, setting scale to 1.9"
            fi
        fi

        show_progress "Creating SDDM theme configuration (scale: $scale_factor)"

        # Create SDDM theme config
        cat <<EOF | sudo tee /etc/sddm.conf.d/theme.conf >/dev/null
[Theme]
Current=Catppuccin-Mocha-Mauve
CursorTheme=catppuccin-mocha-mauve-cursors
Font=Noto Sans,11,-1,5,400,0,0,0,0,0,0,0,0,0,0,1

[General]
GreeterEnvironment=QT_SCREEN_SCALE_FACTORS=$scale_factor

[Wayland]
EnableHiDPI=true

[X11]
EnableHiDPI=true
EOF

        finish_progress
    fi

    # Replace SDDM logo with Mokka cat if theme is installed
    local sddm_theme_dir="/usr/share/sddm/themes/Catppuccin-Mocha-Mauve"
    local mokka_logo="/usr/share/icons/garuda/mokka-fastfetch.png"
    
    if [[ -d "$sddm_theme_dir" && -f "$mokka_logo" ]]; then
        show_progress "Setting Mokka logo for SDDM"
        sudo cp "$mokka_logo" "$sddm_theme_dir/assets/defaultIcon.png" 2>/dev/null || log_warning "Failed to set SDDM logo"
        finish_progress
    fi

    # Enable SDDM service
    manage_service "sddm.service" "enable"

    log_success "SDDM configured with Catppuccin-Mocha-Mauve theme"
}

# ============================================================================
# AUTOSTART CONFIGURATION
# ============================================================================

setup_autostart() {
    printf "[*] Configuring autostart applications\n"

    local autostart_dir="/home/$ACTUAL_USER/.config/autostart"
    local scripts_dir="/home/$ACTUAL_USER/.config/scripts"
    sudo -u "$ACTUAL_USER" mkdir -p "$autostart_dir"
    sudo -u "$ACTUAL_USER" mkdir -p "$scripts_dir"

    # Create comprehensive first-login setup script
    show_progress "Creating first-login setup script"
    cat << 'AUTOSTART_EOF' | sudo -u "$ACTUAL_USER" tee "$scripts_dir/mokka-first-login.sh" >/dev/null
#!/bin/bash
# Mokka first-login setup script
# Applies themes and configurations that require a running Plasma session

LOG="/tmp/mokka-first-login.log"
LOCK_FILE="/tmp/mokka-first-login.lock"

cleanup_and_exit() {
    local exit_code=${1:-0}
    echo "Cleanup initiated at $(date)" >> "$LOG"
    
    (
        sleep 10
        rm -f "$HOME/.config/autostart/mokka-first-login.desktop" 2>/dev/null
        rm -f "$HOME/.config/scripts/mokka-first-login.sh" 2>/dev/null
        rm -f "$LOCK_FILE" 2>/dev/null
        echo "Autostart files cleaned up at $(date)" >> "$LOG"
    ) &
    
    echo "Mokka first-login script completed at $(date)" >> "$LOG"
    exit $exit_code
}

# Prevent multiple instances
if [[ -f "$LOCK_FILE" ]]; then
    echo "Script already running (lock file exists), exiting..." >> "$LOG"
    exit 0
fi

echo $$ > "$LOCK_FILE"
echo "Starting Mokka first-login setup at $(date)" > "$LOG"

trap 'cleanup_and_exit 1' INT TERM
trap 'cleanup_and_exit 0' EXIT

# Wait for Plasma to fully load
sleep 8

# Phase 1: Apply Kvantum theme
echo "Phase 1: Applying Kvantum theme..." >> "$LOG"

if command -v kvantummanager &>/dev/null; then
    kvantummanager --set Mokka >> "$LOG" 2>&1
    echo "Kvantum theme set to Mokka" >> "$LOG"
else
    echo "kvantummanager not found" >> "$LOG"
fi

sleep 2

# Phase 2: Apply Plasma Look-and-Feel
echo "Phase 2: Applying Plasma Mokka look-and-feel..." >> "$LOG"

if command -v plasma-apply-lookandfeel &>/dev/null; then
    plasma-apply-lookandfeel -a Mokka >> "$LOG" 2>&1
    echo "Plasma look-and-feel set to Mokka" >> "$LOG"
elif command -v lookandfeeltool &>/dev/null; then
    lookandfeeltool -a Mokka >> "$LOG" 2>&1
    echo "Look-and-feel set to Mokka via lookandfeeltool" >> "$LOG"
else
    echo "No look-and-feel tool found" >> "$LOG"
fi

sleep 2

# Phase 3: Fix display scaling
echo "Phase 3: Fixing display scaling..." >> "$LOG"

# Remove conflicting ScreenScaleFactors from plasmashellrc
# This lets kwinoutputconfig.json handle scaling properly
if [[ -f "$HOME/.config/plasmashellrc" ]]; then
    sed -i '/^ScreenScaleFactors=/d' "$HOME/.config/plasmashellrc" >> "$LOG" 2>&1
    sed -i '/^XwaylandClientsScale=/d' "$HOME/.config/plasmashellrc" >> "$LOG" 2>&1
    echo "Removed conflicting scale factors from plasmashellrc" >> "$LOG"
fi

# Set display scale to 1.9 for 4K displays
if command -v kscreen-doctor &>/dev/null; then
    # Get primary output and set scale
    kscreen-doctor output.1.scale.1.9 >> "$LOG" 2>&1
    echo "Display scale set to 1.9 via kscreen-doctor" >> "$LOG"
fi

sleep 2

# Phase 4: Reconfigure KWin
echo "Phase 4: Reconfiguring KWin..." >> "$LOG"

if command -v qdbus6 &>/dev/null; then
    qdbus6 org.kde.KWin /KWin reconfigure >> "$LOG" 2>&1
    echo "KWin reconfigured via qdbus6" >> "$LOG"
elif command -v qdbus &>/dev/null; then
    qdbus org.kde.KWin /KWin reconfigure >> "$LOG" 2>&1
    echo "KWin reconfigured via qdbus" >> "$LOG"
fi

sleep 2

# Phase 5: Set default browser
echo "Phase 5: Setting default browser..." >> "$LOG"

for browser in google-chrome-stable firefox brave-browser firedragon microsoft-edge; do
    if [[ -f "/usr/share/applications/$browser.desktop" ]]; then
        xdg-settings set default-web-browser "$browser.desktop" >> "$LOG" 2>&1
        echo "Default browser set to: $browser" >> "$LOG"
        break
    fi
done

# Phase 6: Apply wallpaper
echo "Phase 6: Setting wallpaper..." >> "$LOG"

WALLPAPER="/usr/share/wallpapers/garuda-mokka/Mokka-tree.jpg"
if [[ -f "$WALLPAPER" ]]; then
    if command -v plasma-apply-wallpaperimage &>/dev/null; then
        plasma-apply-wallpaperimage "$WALLPAPER" >> "$LOG" 2>&1
        echo "Wallpaper applied: Mokka-tree.jpg" >> "$LOG"
    fi
fi

# Phase 7: Ensure color scheme is applied
echo "Phase 7: Applying color scheme..." >> "$LOG"

if command -v plasma-apply-colorscheme &>/dev/null; then
    plasma-apply-colorscheme Mokka >> "$LOG" 2>&1 || \
    plasma-apply-colorscheme CatppuccinMochaMauve >> "$LOG" 2>&1
    echo "Color scheme applied" >> "$LOG"
fi

sleep 2

# Phase 8: Apply cursor theme (must be last to stick)
echo "Phase 8: Applying cursor theme..." >> "$LOG"

if command -v plasma-apply-cursortheme &>/dev/null; then
    plasma-apply-cursortheme catppuccin-mocha-mauve-cursors >> "$LOG" 2>&1
    echo "Cursor theme applied: catppuccin-mocha-mauve-cursors" >> "$LOG"
else
    echo "plasma-apply-cursortheme not found" >> "$LOG"
fi

sleep 2

# Phase 9: Set Kvantum as widget style
echo "Phase 9: Setting Kvantum as widget style..." >> "$LOG"

if command -v kwriteconfig6 &>/dev/null; then
    kwriteconfig6 --file kdeglobals --group "General" --key "widgetStyle" "kvantum" >> "$LOG" 2>&1
    echo "Kvantum set as widget style" >> "$LOG"
else
    echo "kwriteconfig6 not found" >> "$LOG"
fi

sleep 1

# Phase 10: Set GTK theme via gsettings (for Firefox/GTK apps)
echo "Phase 10: Setting GTK theme via gsettings..." >> "$LOG"

if command -v gsettings &>/dev/null; then
    gsettings set org.gnome.desktop.interface gtk-theme 'catppuccin-mocha-mauve-standard+default' >> "$LOG" 2>&1
    gsettings set org.gnome.desktop.interface icon-theme 'Tela-circle-dracula-dark' >> "$LOG" 2>&1
    echo "GTK theme set via gsettings" >> "$LOG"
else
    echo "gsettings not found" >> "$LOG"
fi

sleep 1

# Phase 10.5: Fix lock screen wallpaper
echo "Phase 10.5: Setting lock screen wallpaper..." >> "$LOG"

if command -v kwriteconfig6 &>/dev/null; then
    kwriteconfig6 --file kscreenlockerrc --group Greeter --group Wallpaper --group org.kde.image --group General --key Image "/usr/share/wallpapers/garuda-mokka/Mokka-tree.jpg" >> "$LOG" 2>&1
    echo "Lock screen wallpaper set to Mokka-tree.jpg" >> "$LOG"
fi

sleep 1

# Phase 11: Set KWrite editor theme
echo "Phase 11: Setting KWrite editor theme..." >> "$LOG"

if command -v kwriteconfig6 &>/dev/null; then
    kwriteconfig6 --file kateschemerc --group "Editor" --key "Color Theme" "Catppuccin Mocha" >> "$LOG" 2>&1
    echo "KWrite theme set to Catppuccin Mocha" >> "$LOG"
else
    echo "kwriteconfig6 not found" >> "$LOG"
fi

echo "All phases completed successfully at $(date)" >> "$LOG"
AUTOSTART_EOF

    sudo chmod +x "$scripts_dir/mokka-first-login.sh"

    # Create desktop entry for autostart
    cat << DESKTOP_EOF | sudo -u "$ACTUAL_USER" tee "$autostart_dir/mokka-first-login.desktop" >/dev/null
[Desktop Entry]
Type=Application
Name=Mokka Setup
Exec=/home/$ACTUAL_USER/.config/scripts/mokka-first-login.sh
Hidden=false
NoDisplay=false
X-KDE-autostart-after=panel
X-GNOME-Autostart-enabled=true
Comment=Configure Plasma with Mokka theme on first login
DESKTOP_EOF

    finish_progress

    log_success "Autostart applications configured"
}

# ============================================================================
# SET DEFAULT APPLICATIONS
# ============================================================================

set_default_applications() {
    show_progress "Setting default applications"

    # Default video player - Haruna
    if is_package_installed "haruna"; then
        xdg-mime default org.kde.haruna.desktop video/mp4
        xdg-mime default org.kde.haruna.desktop video/x-matroska
        xdg-mime default org.kde.haruna.desktop video/webm
        xdg-mime default org.kde.haruna.desktop video/avi
        xdg-mime default org.kde.haruna.desktop video/x-msvideo
        xdg-mime default org.kde.haruna.desktop video/quicktime
        xdg-mime default org.kde.haruna.desktop video/mp2t
    fi

    # Default text/code editor - VS Code
    if is_package_installed "visual-studio-code-bin"; then
        xdg-mime default code.desktop text/plain
        xdg-mime default code.desktop text/x-python
        xdg-mime default code.desktop text/x-shellscript
        xdg-mime default code.desktop text/x-c
        xdg-mime default code.desktop text/x-c++
        xdg-mime default code.desktop application/json
        xdg-mime default code.desktop application/xml
        xdg-mime default code.desktop text/html
        xdg-mime default code.desktop text/css
        xdg-mime default code.desktop text/javascript
    fi

    finish_progress
    log_message "Default applications configured"
}

# ============================================================================
# GRUB CONFIGURATION (Basic - no theming)
# ============================================================================

setup_grub() {
    printf "[*] Configuring GRUB bootloader\n"

    if ! command_exists grub-mkconfig; then
        log_message "GRUB not installed, skipping"
        return
    fi

    # Determine default boot entry
    show_progress "Determining default boot entry"
    local grub_default="0"
    if [[ "$kernel_choice" == "2" ]] && ls /boot/vmlinuz-linux-cachyos >/dev/null 2>&1; then
        grub_default="Advanced options for Arch Linux>Arch Linux, with Linux linux-cachyos"
    fi
    finish_progress

    # Configure kernel parameters for completely silent boot/shutdown
    show_progress "Configuring kernel parameters"
    local cmdline_linux_default="loglevel=0 quiet splash plymouth.enable=1 rd.udev.log_level=0 systemd.show_status=false nvme_core.verbose=0 nowatchdog rd.systemd.show_status=false rd.udev.log_priority=0 udev.log_level=0 vt.global_cursor_default=0"
    
    # Add AMD pstate for AMD CPUs
    if [[ "$CPU_VENDOR" == "AuthenticAMD" ]]; then
        cmdline_linux_default="$cmdline_linux_default amd_pstate=active"
    fi
    finish_progress

    # Write GRUB configuration
    show_progress "Writing GRUB configuration"
    cat <<EOF | sudo tee /etc/default/grub >/dev/null
GRUB_DEFAULT="$grub_default"
GRUB_TIMEOUT=3
GRUB_DISTRIBUTOR="Arch"
GRUB_CMDLINE_LINUX_DEFAULT="$cmdline_linux_default"
GRUB_CMDLINE_LINUX="zswap.enabled=0 rootfstype=ext4"
GRUB_PRELOAD_MODULES="part_gpt part_msdos"
GRUB_TIMEOUT_STYLE=hidden
GRUB_TERMINAL_INPUT=console
GRUB_DISABLE_RECOVERY=true
GRUB_GFXMODE=auto
GRUB_GFXPAYLOAD_LINUX=keep
EOF
    finish_progress

    # Generate GRUB config
    show_progress "Generating GRUB configuration"
    if ! sudo grub-mkconfig -o /boot/grub/grub.cfg >/dev/null 2>&1; then
        log_error "Failed to generate GRUB configuration"
        finish_progress
        return 1
    fi
    finish_progress

    # Suppress shutdown broadcast messages
    show_progress "Configuring silent shutdown"
    sudo mkdir -p /etc/systemd/system/systemd-logind.service.d
    cat <<'EOF' | sudo tee /etc/systemd/system/systemd-logind.service.d/silent.conf >/dev/null
[Service]
StandardOutput=null
StandardError=null
EOF
    finish_progress

    log_success "GRUB configured with 4K video mode and default: $grub_default"
}

# ============================================================================
# CLEANUP
# ============================================================================

perform_cleanup() {
    printf "[*] Performing system cleanup\n"

    # Clean package cache
    show_progress "Cleaning package cache"
    sudo pacman -Sc --noconfirm >/dev/null 2>&1 || log_warning "Failed to clean pacman cache"
    sudo -u "$ACTUAL_USER" yay -Sc --noconfirm >/dev/null 2>&1 || log_warning "Failed to clean yay cache"
    finish_progress

    # Remove orphaned packages
    show_progress "Removing orphaned packages"
    local orphans
    orphans=$(pacman -Qdtq 2>/dev/null)
    if [[ -n "$orphans" ]]; then
        echo "$orphans" | sudo pacman -Rns --noconfirm - >/dev/null 2>&1 || log_warning "Failed to remove some orphans"
    fi
    finish_progress

    # Clean temporary files
    show_progress "Cleaning temporary files"
    rm -rf /tmp/mokka-install 2>/dev/null
    rm -f /tmp/dracularch-main.tar.gz 2>/dev/null
    finish_progress

    # Update font cache one final time
    show_progress "Final font cache update"
    sudo fc-cache -f >/dev/null 2>&1
    finish_progress

    # Update desktop database
    show_progress "Updating desktop database"
    sudo update-desktop-database >/dev/null 2>&1
    finish_progress

    # Update mime database
    show_progress "Updating MIME database"
    sudo update-mime-database /usr/share/mime >/dev/null 2>&1
    finish_progress

    log_success "System cleanup completed"
}

# ============================================================================
# SUMMARY AND EXIT
# ============================================================================

display_summary_and_exit() {
    local script_end_time
    script_end_time=$(date +%s)
    local total_runtime=$((script_end_time - script_start_time))
    local minutes
    minutes=$((total_runtime / 60))
    local seconds
    seconds=$((total_runtime % 60))

    printf '\n%s[*] Mokka Installation Summary%s\n' "${COLORS[MAUVE]}" "${COLORS[NC]}"
    printf '%s=========================================%s\n' "${COLORS[GRAY]}" "${COLORS[NC]}"

    if [[ $total_runtime -gt 0 ]]; then
        printf '%s[i] Total runtime: %s%d%s minutes, %s%d%s seconds%s\n' "${COLORS[SKY]}" "${COLORS[GREEN]}" "$minutes" "${COLORS[SKY]}" "${COLORS[GREEN]}" "$seconds" "${COLORS[SKY]}" "${COLORS[NC]}"
    fi

    if [[ ${#successful_installs[@]} -gt 0 ]]; then
        printf '%s[+] Successfully installed packages and apps (%s%d%s total):%s\n' "${COLORS[GREEN]}" "${COLORS[SKY]}" "${#successful_installs[@]}" "${COLORS[GREEN]}" "${COLORS[NC]}"
        local count=0
        for pkg in "${successful_installs[@]}"; do
            if [[ $count -lt 10 ]]; then
                printf '%s  [+] %s%s\n' "${COLORS[SKY]}" "$pkg" "${COLORS[NC]}"
                ((count++))
            elif [[ $count -eq 10 ]]; then
                printf '%s  ... and %s%d%s more packages%s\n' "${COLORS[GRAY]}" "${COLORS[SKY]}" "$((${#successful_installs[@]} - 10))" "${COLORS[GRAY]}" "${COLORS[NC]}"
                break
            fi
        done
        echo
    fi

    if [[ ${#failed_installs[@]} -gt 0 ]]; then
        printf '%s[!] Failed installations (%s%d%s total):%s\n' "${COLORS[RED]}" "${COLORS[SKY]}" "${#failed_installs[@]}" "${COLORS[RED]}" "${COLORS[NC]}"
        for pkg in "${failed_installs[@]}"; do
            printf '%s  [!] %s%s\n' "${COLORS[RED]}" "$pkg" "${COLORS[NC]}"
        done
        echo

        if [[ -f "$ERRORLOG" ]]; then
            printf '%s[i] Review the error log: %s%s%s\n' "${COLORS[PINK]}" "${COLORS[SKY]}" "$ERRORLOG" "${COLORS[NC]}"
        fi
    fi

    # Display what was configured
    printf '\n%s[*] Configuration Summary%s\n' "${COLORS[MAUVE]}" "${COLORS[NC]}"
    printf '%s=========================================%s\n' "${COLORS[GRAY]}" "${COLORS[NC]}"
    printf '%s[+] Desktop: KDE Plasma with Mokka theme%s\n' "${COLORS[GREEN]}" "${COLORS[NC]}"
    printf '%s[+] Login Manager: SDDM with Catppuccin-Mocha-Mauve%s\n' "${COLORS[GREEN]}" "${COLORS[NC]}"
    printf '%s[+] Shell: Fish with Starship prompt%s\n' "${COLORS[GREEN]}" "${COLORS[NC]}"
    printf '%s[+] Terminal: Ghostty & Konsole with Catppuccin Mocha%s\n' "${COLORS[GREEN]}" "${COLORS[NC]}"
    printf '%s[+] Icons: Tela Circle Dracula%s\n' "${COLORS[GREEN]}" "${COLORS[NC]}"
    printf '%s[+] Cursors: Catppuccin Mocha Mauve%s\n' "${COLORS[GREEN]}" "${COLORS[NC]}"
    printf '%s[+] Window Decoration: CatppuccinMocha-Classic%s\n' "${COLORS[GREEN]}" "${COLORS[NC]}"
    printf '%s[+] Wallpaper: Mokka-tree.jpg%s\n' "${COLORS[GREEN]}" "${COLORS[NC]}"
    
    if [[ "$kernel_choice" == "2" ]]; then
        printf '%s[+] Kernel: CachyOS%s\n' "${COLORS[GREEN]}" "${COLORS[NC]}"
    else
        printf '%s[+] Kernel: Linux Zen (optimized)%s\n' "${COLORS[GREEN]}" "${COLORS[NC]}"
    fi

    if [[ ${#browser_packages[@]} -gt 0 ]]; then
        printf '%s[+] Browsers: %s%s\n' "${COLORS[GREEN]}" "${browser_packages[*]}" "${COLORS[NC]}"
    fi

    if [[ -n "$DETECTED_PRINTER" ]]; then
        printf '%s[+] Printer: %s configured%s\n' "${COLORS[GREEN]}" "$DETECTED_PRINTER" "${COLORS[NC]}"
    fi

    echo

    # Reboot prompt
    if [[ ${#failed_installs[@]} -eq 0 ]]; then
        printf '%s[+] All packages installed successfully!%s\n' "${COLORS[GREEN]}" "${COLORS[NC]}"
        printf '%s[?] Press Enter to reboot now or type %sn%s to cancel: %s' "${COLORS[SKY]}" "${COLORS[PINK]}" "${COLORS[SKY]}" "${COLORS[NC]}"
        read -r reply
        if [[ -z "$reply" || "$reply" =~ ^[Yy]$ ]]; then
            printf '%s[>] Rebooting now... Enjoy your Mokka-themed Arch system!%s\n' "${COLORS[MAUVE]}" "${COLORS[NC]}"
            sudo systemctl reboot 2>/dev/null
        else
            printf '%s[i] Please reboot when convenient to enjoy the full Mokka experience!%s\n' "${COLORS[PINK]}" "${COLORS[NC]}"
        fi
        exit 0
    else
        printf '%s[!] Some packages failed to install:%s\n' "${COLORS[PINK]}" "${COLORS[NC]}"
        for pkg in "${failed_installs[@]}"; do
            printf '%s  [!] %s%s\n' "${COLORS[RED]}" "$pkg" "${COLORS[NC]}"
        done
        printf '%s[?] Press Enter to reboot anyway or type %sn%s to cancel: %s' "${COLORS[SKY]}" "${COLORS[PINK]}" "${COLORS[SKY]}" "${COLORS[NC]}"
        read -r reply
        if [[ -z "$reply" || "$reply" =~ ^[Yy]$ ]]; then
            printf '%s[>] Rebooting now...%s\n' "${COLORS[MAUVE]}" "${COLORS[NC]}"
            sudo systemctl reboot 2>/dev/null
        else
            printf '%s[i] Resolve issues and reboot when ready.%s\n' "${COLORS[PINK]}" "${COLORS[NC]}"
        fi
        exit 1
    fi
}

# ============================================================================
# MAIN FUNCTION
# ============================================================================

main() {
    # Record script start time
    script_start_time=$(date +%s)

    if [[ "$TERM" == "linux" ]]; then
        printf '%s[*] Mokka Arch Linux Setup Script - OPTIMIZED [*]%s\n' "${COLORS[MAUVE]}" "${COLORS[NC]}"
    else
        printf '%s[*] Mokka Arch Linux Setup Script - OPTIMIZED%s\n' "${COLORS[MAUVE]}" "${COLORS[NC]}"
    fi
    printf '%s[>] Starting automated Arch Linux setup with Catppuccin Mocha theming...%s\n' "${COLORS[GRAY]}" "${COLORS[NC]}"
    printf '%s[+] KDE Plasma desktop with Garuda Mokka theme%s\n\n' "${COLORS[SKY]}" "${COLORS[NC]}"

    # Phase 1: System Initialization
    printf '\n%s[*] ================================================ [*]%s\n' "${COLORS[MAUVE]}" "${COLORS[NC]}"
    printf '%s[*] Phase 1: System Initialization%s\n' "${COLORS[MAUVE]}" "${COLORS[NC]}"
    printf '%s[*] ================================================ [*]%s\n' "${COLORS[MAUVE]}" "${COLORS[NC]}"
    setup_tmpfs
    setup_sudo
    setup_logging_directory
    detect_system_info
    collect_user_inputs

    # Phase 2: System Update & Package Management
    printf '\n%s[*] ================================================ [*]%s\n' "${COLORS[MAUVE]}" "${COLORS[NC]}"
    printf '%s[*] Phase 2: System Update & Package Management%s\n' "${COLORS[MAUVE]}" "${COLORS[NC]}"
    printf '%s[*] ================================================ [*]%s\n' "${COLORS[MAUVE]}" "${COLORS[NC]}"
    refresh_system
    enable_multilib
    setup_aur_helper
    install_required_packages
    setup_flatpak

    # Phase 3: Kernel & Hardware Setup
    printf '\n%s[*] ================================================ [*]%s\n' "${COLORS[MAUVE]}" "${COLORS[NC]}"
    printf '%s[*] Phase 3: Kernel & Hardware Setup%s\n' "${COLORS[MAUVE]}" "${COLORS[NC]}"
    printf '%s[*] ================================================ [*]%s\n' "${COLORS[MAUVE]}" "${COLORS[NC]}"
    setup_kernel_microcode_and_headers
    setup_kernel
    apply_performance_optimizations
    setup_zram
    label_efi_partition

    # Phase 4: Services & Network
    printf '\n%s[*] ================================================ [*]%s\n' "${COLORS[MAUVE]}" "${COLORS[NC]}"
    printf '%s[*] Phase 4: Services & Network%s\n' "${COLORS[MAUVE]}" "${COLORS[NC]}"
    printf '%s[*] ================================================ [*]%s\n' "${COLORS[MAUVE]}" "${COLORS[NC]}"
    setup_batch_services
    setup_avahi_and_nss_mdns
    setup_reflector_timer
    setup_ufw_firewall

    # Phase 5: Applications & Browsers
    printf '\n%s[*] ================================================ [*]%s\n' "${COLORS[MAUVE]}" "${COLORS[NC]}"
    printf '%s[*] Phase 5: Applications & Browsers%s\n' "${COLORS[MAUVE]}" "${COLORS[NC]}"
    printf '%s[*] ================================================ [*]%s\n' "${COLORS[MAUVE]}" "${COLORS[NC]}"
    install_browsers
    setup_printer_auto
    install_ocs_url
    install_aur_apps
    install_claude_code
    install_clean_fonts

    # Phase 6: Plasma Widgets, Themes & Effects
    printf '\n%s[*] ================================================ [*]%s\n' "${COLORS[MAUVE]}" "${COLORS[NC]}"
    printf '%s[*] Phase 6: Plasma Widgets, Themes & Effects%s\n' "${COLORS[MAUVE]}" "${COLORS[NC]}"
    printf '%s[*] ================================================ [*]%s\n' "${COLORS[MAUVE]}" "${COLORS[NC]}"
    install_plasma_widgets
    install_tahoe_launcher
    install_theme_packages
    install_kwin_effects

    # Phase 7: Download & Restore Configs
    printf '\n%s[*] ================================================ [*]%s\n' "${COLORS[MAUVE]}" "${COLORS[NC]}"
    printf '%s[*] Phase 7: Download & Restore Configurations%s\n' "${COLORS[MAUVE]}" "${COLORS[NC]}"
    printf '%s[*] ================================================ [*]%s\n' "${COLORS[MAUVE]}" "${COLORS[NC]}"
    download_mokka_configs
    restore_plasma_configs
    restore_system_configs
    configure_kde_wallet
    create_dolphin_bookmarks
    install_theme_files
    install_wallpapers
    install_panel_colorizer_presets

    # Phase 8: Shell & Terminal Setup
    printf '\n%s[*] ================================================ [*]%s\n' "${COLORS[MAUVE]}" "${COLORS[NC]}"
    printf '%s[*] Phase 8: Shell & Terminal Setup%s\n' "${COLORS[MAUVE]}" "${COLORS[NC]}"
    printf '%s[*] ================================================ [*]%s\n' "${COLORS[MAUVE]}" "${COLORS[NC]}"
    restore_terminal_configs
    setup_nano
    setup_fish
    setup_starship
    setup_fastfetch
    setup_zoxide
    setup_carapace
    setup_delta
    setup_bat
    setup_lazygit
    setup_ghostty
    setup_konsole
    setup_btop

    # Phase 9: Apply Themes & Effects
    printf '\n%s[*] ================================================ [*]%s\n' "${COLORS[MAUVE]}" "${COLORS[NC]}"
    printf '%s[*] Phase 9: Apply Themes & Effects%s\n' "${COLORS[MAUVE]}" "${COLORS[NC]}"
    printf '%s[*] ================================================ [*]%s\n' "${COLORS[MAUVE]}" "${COLORS[NC]}"
    apply_kvantum_theme
    apply_plasma_theme
    set_default_wallpaper
    configure_kwin_effects

    # Phase 10: Final Kernel Setup
    printf '\n%s[+] ================================================ [+]%s\n' "${COLORS[GREEN]}" "${COLORS[NC]}"
    printf '%s[+] Phase 10: Final Kernel Setup%s\n' "${COLORS[GREEN]}" "${COLORS[NC]}"
    printf '%s[+] ================================================ [+]%s\n' "${COLORS[GREEN]}" "${COLORS[NC]}"
    finalize_kernel_setup

    # Phase 11: SDDM & System Services
    printf '\n%s[*] ================================================ [*]%s\n' "${COLORS[MAUVE]}" "${COLORS[NC]}"
    printf '%s[*] Phase 11: SDDM & System Services%s\n' "${COLORS[MAUVE]}" "${COLORS[NC]}"
    printf '%s[*] ================================================ [*]%s\n' "${COLORS[MAUVE]}" "${COLORS[NC]}"
    setup_sddm
    setup_autostart
    set_default_applications

    # Phase 12: Bootloader & Cleanup
    printf '\n%s[*] ================================================ [*]%s\n' "${COLORS[MAUVE]}" "${COLORS[NC]}"
    printf '%s[*] Phase 12: Bootloader & Cleanup%s\n' "${COLORS[MAUVE]}" "${COLORS[NC]}"
    printf '%s[*] ================================================ [*]%s\n' "${COLORS[MAUVE]}" "${COLORS[NC]}"
    setup_grub
    perform_cleanup

    # Final Summary
    printf '\n%s[+] ================================================ [+]%s\n' "${COLORS[GREEN]}" "${COLORS[NC]}"
    printf '%s[+] Installation Complete!%s\n' "${COLORS[GREEN]}" "${COLORS[NC]}"
    printf '%s[+] ================================================ [+]%s\n' "${COLORS[GREEN]}" "${COLORS[NC]}"
    display_summary_and_exit
}

# ============================================================================
# SCRIPT ENTRY POINT
# ============================================================================

trap 'log_error "Script interrupted"; exit 1' INT TERM

main "$@"

# ============================================================================
# END OF MOKKA.SH
# ============================================================================