#!/bin/bash

# ==============================================================================
# Script: vscode_setup.sh
# Description: Complete VSCode installation with extensions and configuration
# ==============================================================================

set -u

# ==============================================================================
# COLORS & LOGGING
# ==============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "\n${BLUE}================= $1 =================${NC}"
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

error() {
    echo -e "${RED}❌ $1${NC}"
}

print_separator() {
    echo "============================================================================="
}

# ==============================================================================
# GLOBAL VARIABLES
# ==============================================================================

LOGFILE="/tmp/vscode-setup.log"
INSTALLED_COUNT=0
SKIPPED_COUNT=0
FAILED_COUNT=0
CONFIG_APPLIED=0
VSCODE_INSTALLED=0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VSCODE_CONFIG_DIR="$HOME/.config/Code/User"
SETTINGS_FILE="$VSCODE_CONFIG_DIR/settings.json"

# Extensions list
EXTENSIONS=(
  "4ops.terraform"
  "bradlc.vscode-tailwindcss"
  "charliermarsh.ruff"
  "eamodio.gitlens"
  "esbenp.prettier-vscode"
  "foxundermoon.shell-format"
  "github.github-vscode-theme"
  "gruntfuggly.todo-tree"
  "hashicorp.terraform"
  "mechatroner.rainbow-csv"
  "miguelsolorio.fluent-icons"
  "ms-azuretools.vscode-containers"
  "ms-azuretools.vscode-docker"
  "ms-kubernetes-tools.vscode-kubernetes-tools"
  "ms-python.black-formatter"
  "ms-python.debugpy"
  "ms-python.flake8"
  "ms-python.python"
  "ms-python.vscode-pylance"
  "ms-python.vscode-python-envs"
  "njpwerner.autodocstring"
  "oderwat.indent-rainbow"
  "pkief.material-icon-theme"
  "redhat.vscode-yaml"
  "tamasfe.even-better-toml"
  "usernamehw.errorlens"
  "zhuangtongfa.material-theme"
)

# ==============================================================================
# HEADER & INFO FUNCTIONS
# ==============================================================================

print_header() {
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║              VSCode Complete Setup                       ║"
    echo "║      Installation + Extensions + Configuration           ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo
}

show_extensions_info() {
    echo -e "${BLUE}📋 Extensions to be installed:${NC}"
    echo

    cat << 'EOF'
🎨 THEMES & APPEARANCE:
  • Material Theme (zhuangtongfa.material-theme)
  • Material Icon Theme (pkief.material-icon-theme)
  • Fluent Icons (miguelsolorio.fluent-icons)
  • Indent Rainbow (oderwat.indent-rainbow)

🐍 PYTHON:
  • Python (ms-python.python)
  • Pylance (ms-python.vscode-pylance)
  • Black Formatter (ms-python.black-formatter)
  • Flake8 (ms-python.flake8)
  • Ruff (charliermarsh.ruff)
  • AutoDocstring (njpwerner.autodocstring)
  • Python Debugger (ms-python.debugpy)

🌐 WEB DEV:
  • Prettier (esbenp.prettier-vscode)
  • Tailwind CSS (bradlc.vscode-tailwindcss)

🔧 DEVOPS & CONTAINERS:
  • Docker (ms-azuretools.vscode-docker)
  • Dev Containers (ms-azuretools.vscode-containers)
  • Kubernetes Tools (ms-kubernetes-tools.vscode-kubernetes-tools)

📝 PRODUCTIVITY:
  • GitLens (eamodio.gitlens)
  • Todo Tree (gruntfuggly.todo-tree)
  • Error Lens (usernamehw.errorlens)
  • Shell Format (foxundermoon.shell-format)
  • Rainbow CSV (mechatroner.rainbow-csv)
  • YAML Support (redhat.vscode-yaml)
  • Better TOML (tamasfe.even-better-toml)
EOF
    echo
}

# ==============================================================================
# VSCODE DETECTION FUNCTIONS
# ==============================================================================

detect_vscode_installation() {
    # Detection methods in order of preference
    if command -v code &> /dev/null; then
        return 0  # VSCode found in PATH
    elif [ -f "/snap/bin/code" ]; then
        export PATH="/snap/bin:$PATH"
        return 0  # VSCode via snap
    elif [ -f "/usr/bin/code" ]; then
        return 0  # VSCode via apt/deb
    elif flatpak list 2>/dev/null | grep -q "com.visualstudio.code"; then
        warning "VSCode detected via Flatpak - limited CLI functionality"
        return 2  # Special code for Flatpak
    else
        return 1  # Not found
    fi
}

# ==============================================================================
# VSCODE INSTALLATION FUNCTIONS
# ==============================================================================

install_vscode_apt() {
    echo "Installing via APT (Microsoft Repository)..."

    # Create keyrings directory if it doesn't exist
    sudo mkdir -p /usr/share/keyrings

    # Add Microsoft GPG key
    if ! [ -f "/usr/share/keyrings/packages.microsoft.gpg" ]; then
        if command -v wget >/dev/null 2>&1; then
            wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
            sudo install -o root -g root -m 644 packages.microsoft.gpg /usr/share/keyrings/
            rm packages.microsoft.gpg
        elif command -v curl >/dev/null 2>&1; then
            curl -s https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
            sudo install -o root -g root -m 644 packages.microsoft.gpg /usr/share/keyrings/
            rm packages.microsoft.gpg
        else
            error "wget or curl required to download GPG key"
            return 1
        fi
    fi

    # Add Microsoft repository
    local repo_file="/etc/apt/sources.list.d/vscode.list"
    if [ ! -f "$repo_file" ]; then
        echo "deb [arch=amd64,arm64,armhf signed-by=/usr/share/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" \
            | sudo tee "$repo_file" > /dev/null
    fi

    # Install VSCode
    if sudo apt update && sudo apt install -y code; then
        success "VSCode installed via APT"
        VSCODE_INSTALLED=1
        return 0
    else
        error "Failed to install via APT"
        return 1
    fi
}

install_vscode_snap() {
    echo "Installing via Snap..."

    if ! command -v snap >/dev/null 2>&1; then
        error "Snap is not installed on this system"
        return 1
    fi

    if sudo snap install code --classic; then
        success "VSCode installed via Snap"
        export PATH="/snap/bin:$PATH"
        VSCODE_INSTALLED=1
        return 0
    else
        error "Failed to install via Snap"
        return 1
    fi
}

install_vscode_flatpak() {
    echo "Installing via Flatpak..."

    if ! command -v flatpak >/dev/null 2>&1; then
        error "Flatpak is not installed on this system"
        return 1
    fi

    # Check if Flathub is configured
    if ! flatpak remotes | grep -q flathub; then
        echo "Configuring Flathub..."
        flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    fi

    if flatpak install -y flathub com.visualstudio.code; then
        success "VSCode installed via Flatpak"
        warning "Note: Limited CLI with Flatpak - some extensions may not auto-install"
        VSCODE_INSTALLED=1
        return 0
    else
        error "Failed to install via Flatpak"
        return 1
    fi
}

install_vscode() {
    log "VSCODE INSTALLATION"

    # Check if already installed
    local detection_result
    detection_result=$(detect_vscode_installation; echo $?)

    case $detection_result in
        0)
            success "VSCode already installed and accessible"
            return 0
            ;;
        2)
            warning "VSCode Flatpak detected but CLI limited"
            echo "Native version installation recommended..."
            ;;
        1)
            echo "VSCode not detected, starting installation..."
            ;;
    esac

    # Installation method selection
    echo -e "${YELLOW}Choose installation method:${NC}"
    echo "1) APT (Recommended - full system integration)"
    echo "2) Snap (Simple but less integrated)"
    echo "3) Flatpak (Sandboxed)"
    echo "4) Cancel"
    echo

    read -p "Your choice [1-4]: " -n 1 -r
    echo

    case $REPLY in
        1)
            install_vscode_apt
            ;;
        2)
            install_vscode_snap
            ;;
        3)
            install_vscode_flatpak
            ;;
        4)
            warning "Installation cancelled"
            return 1
            ;;
        *)
            warning "Invalid choice, using APT by default"
            install_vscode_apt
            ;;
    esac
}

# ==============================================================================
# PREREQUISITES CHECK
# ==============================================================================

check_prerequisites() {
    log "CHECKING PREREQUISITES"

    # Check sudo privileges
    if ! sudo -n true 2>/dev/null; then
        if ! sudo true; then
            error "Sudo privileges required for installation"
            return 1
        fi
    fi

    # Detect and install VSCode if necessary
    local detection_result
    detection_result=$(detect_vscode_installation; echo $?)

    case $detection_result in
        0)
            success "VSCode CLI detected and functional"
            ;;
        2)
            warning "VSCode Flatpak detected - limited CLI features"
            read -p "Install native version for better integration? (Y/n): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Nn]$ ]]; then
                if ! install_vscode; then
                    error "Failed to install VSCode"
                    return 1
                fi
            fi
            ;;
        1)
            warning "VSCode not detected"
            if ! install_vscode; then
                error "Cannot proceed without VSCode"
                return 1
            fi
            ;;
    esac

    # Display version if possible
    local version_output
    if version_output=$(timeout 5s code --version 2>/dev/null | head -n1); then
        echo -e "${BLUE}ℹ️  Version: $version_output${NC}"
    fi

    # Create config directory if it doesn't exist
    if [ ! -d "$VSCODE_CONFIG_DIR" ]; then
        if mkdir -p "$VSCODE_CONFIG_DIR"; then
            success "Configuration directory created"
        else
            error "Cannot create $VSCODE_CONFIG_DIR"
            return 1
        fi
    fi

    return 0
}

# ==============================================================================
# EXTENSIONS MANAGEMENT
# ==============================================================================

is_extension_installed() {
    local extension_id="$1"
    timeout 10s code --list-extensions 2>/dev/null | grep -qi "^${extension_id}$"
}

install_extension() {
    local extension_id="$1"
    local extension_name=$(echo "$extension_id" | cut -d'.' -f2)

    printf "%-40s" "📦 $extension_name"

    # Check if already installed
    if is_extension_installed "$extension_id"; then
        echo -e "${YELLOW}[ALREADY INSTALLED]${NC}"
        ((SKIPPED_COUNT++))
        return 0
    fi

    # Install with timeout and error handling
    if timeout 60s code --install-extension "$extension_id" --force >> "$LOGFILE" 2>&1; then
        echo -e "${GREEN}[INSTALLED]${NC}"
        ((INSTALLED_COUNT++))
        return 0
    else
        echo -e "${RED}[FAILED]${NC}"
        echo "⚠️  Error installing $extension_id ($(date))" >> "$LOGFILE"
        ((FAILED_COUNT++))
        return 1
    fi
}

install_all_extensions() {
    log "INSTALLING EXTENSIONS"
    echo -e "${YELLOW}🚀 Installing extensions (${#EXTENSIONS[@]} total)...${NC}"
    echo

    # Create/clear log file
    echo "=== VSCode Extensions Installation Log - $(date) ===" > "$LOGFILE"

    # Check if VSCode can list extensions
    if ! timeout 10s code --list-extensions >/dev/null 2>&1; then
        error "Unable to communicate with VSCode"
        echo -e "${YELLOW}💡 Solutions:${NC}"
        echo "  • Close all VSCode instances"
        echo "  • Verify VSCode has finished initializing"
        echo "  • Restart your terminal"
        return 1
    fi

    local failed_extensions=()

    # Wait if VSCode was just installed
    if [ $VSCODE_INSTALLED -eq 1 ]; then
        echo "⏳ Waiting for VSCode initialization..."
        sleep 3
    fi

    for extension in "${EXTENSIONS[@]}"; do
        if ! install_extension "$extension"; then
            failed_extensions+=("$extension")
        fi

        # Small pause to avoid overloading the system
        sleep 0.5
    done

    if [ ${#failed_extensions[@]} -gt 0 ]; then
        echo -e "\n${YELLOW}Failed extensions (manual installation possible):${NC}"
        for ext in "${failed_extensions[@]}"; do
            echo "  • $ext"
        done
        echo -e "\n${BLUE}💡 Manual installation command:${NC}"
        echo "code --install-extension <extension-id>"
    fi
}

# ==============================================================================
# CONFIGURATION MANAGEMENT
# ==============================================================================

backup_existing_config() {
    if [ -f "$SETTINGS_FILE" ]; then
        local backup_file="${SETTINGS_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
        if cp "$SETTINGS_FILE" "$backup_file"; then
            success "Existing configuration backed up: $backup_file"
            return 0
        else
            warning "Cannot backup existing configuration"
        fi
    fi
    return 1
}

function _apply_vscode_config() {
  log "# Applying VSCode configuration..."

  local settings_dir="$HOME/.config/Code/User"
  local settings_file="$settings_dir/settings.json"
  local config_source="$SCRIPT_DIR/configs/vscode_settings.json"

  # Vérifier que le fichier source existe
  if [[ ! -f "$config_source" ]]; then
    error "Configuration file not found: $config_source"
    return 1
  fi

  # Créer le dossier de config VSCode si nécessaire
  if [[ ! -d "$settings_dir" ]]; then
    log "Creating VSCode config directory..."
    mkdir -p "$settings_dir"
  fi

  # Backup de la config existante
  if [[ -f "$settings_file" ]]; then
    local backup_file="${settings_file}.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$settings_file" "$backup_file"
    log "Existing config backed up to: ${backup_file##*/}"
  fi

  # Copier la nouvelle config
  if cp "$config_source" "$settings_file"; then
    success "VSCode configuration applied successfully"
  else
    error "Failed to apply VSCode configuration"
    return 1
  fi
}

# ==============================================================================
# FONTS INSTALLATION
# ==============================================================================

install_additional_fonts() {
    log "INSTALLING FIRA CODE FONT"

    # Check if Fira Code is already installed
    if fc-list 2>/dev/null | grep -i "fira code" > /dev/null; then
        success "Fira Code already installed"
        return 0
    fi

    echo "Installing Fira Code for ligatures..."

    # Create user fonts directory
    local fonts_dir="$HOME/.local/share/fonts"
    if ! mkdir -p "$fonts_dir"; then
        warning "Cannot create fonts directory"
        return 1
    fi

    # Download and install Fira Code
    local temp_dir
    if ! temp_dir=$(mktemp -d); then
        warning "Cannot create temporary directory"
        return 1
    fi

    cd "$temp_dir" || return 1

    if command -v wget >/dev/null 2>&1; then
        if wget -q --timeout=30 "https://github.com/tonsky/FiraCode/releases/download/6.2/Fira_Code_v6.2.zip"; then
            if command -v unzip >/dev/null 2>&1; then
                if unzip -q Fira_Code_v6.2.zip && [ -d "ttf" ]; then
                    cp ttf/*.ttf "$fonts_dir/" 2>/dev/null || true
                    if command -v fc-cache >/dev/null 2>&1; then
                        fc-cache -f -v > /dev/null 2>&1
                    fi
                    success "Fira Code installed"
                else
                    warning "Failed to extract Fira Code"
                fi
            else
                warning "unzip not available - install with: sudo apt install unzip"
            fi
        else
            warning "Failed to download Fira Code"
        fi
    else
        warning "wget not available - install with: sudo apt install wget"
    fi

    cd - > /dev/null
    rm -rf "$temp_dir"
}

# ==============================================================================
# SUMMARY DISPLAY
# ==============================================================================

print_summary() {
    echo
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║                        SUMMARY                             ║${NC}"
    echo -e "${BLUE}╠════════════════════════════════════════════════════════════╣${NC}"

    if [ $VSCODE_INSTALLED -eq 1 ]; then
        echo -e "${BLUE}║${NC} ${GREEN}📥 VSCode:                INSTALLED${NC}                       ${BLUE}║${NC}"
    fi

    printf "${BLUE}║${NC} ${GREEN}✅ Extensions installed:  %-2d${NC}                           ${BLUE}║${NC}\n" "$INSTALLED_COUNT"
    printf "${BLUE}║${NC} ${YELLOW}⏭️  Already present:      %-2d${NC}                           ${BLUE}║${NC}\n" "$SKIPPED_COUNT"
    printf "${BLUE}║${NC} ${RED}❌ Failed:               %-2d${NC}                           ${BLUE}║${NC}\n" "$FAILED_COUNT"

    if [ $CONFIG_APPLIED -eq 1 ]; then
        echo -e "${BLUE}║${NC} ${GREEN}⚙️  Configuration:        APPLIED${NC}                        ${BLUE}║${NC}"
    else
        echo -e "${BLUE}║${NC} ${RED}⚙️  Configuration:        FAILED${NC}                         ${BLUE}║${NC}"
    fi

    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"

    if [[ $FAILED_COUNT -gt 0 ]]; then
        echo
        echo -e "${RED}⚠️  Errors detected. Check the log:${NC}"
        echo -e "${YELLOW}   cat $LOGFILE${NC}"
    fi

    if [[ $INSTALLED_COUNT -gt 0 ]] || [[ $CONFIG_APPLIED -eq 1 ]] || [[ $VSCODE_INSTALLED -eq 1 ]]; then
        echo
        echo -e "${GREEN}🎉 VSCode configuration complete!${NC}"
        echo -e "\n${YELLOW}📝 Next steps:${NC}"
        echo -e "  1. ${BLUE}Restart VSCode${NC} to apply all changes"
        echo -e "  2. ${BLUE}Select theme${NC}: Ctrl+Shift+P → 'Preferences: Color Theme'"
        echo -e "  3. ${BLUE}Check icons${NC}: Ctrl+Shift+P → 'Preferences: File Icon Theme'"
        echo -e "  4. ${BLUE}Fira Code font${NC}: Ligatures should be enabled automatically"

        if [ $VSCODE_INSTALLED -eq 1 ]; then
            echo -e "  5. ${BLUE}VSCode is now installed${NC} - launch it with 'code'"
        fi
    fi
}

# ==============================================================================
# MAIN SCRIPT
# ==============================================================================

# Debug mode
DEBUG="${1:-false}"
if [[ "$DEBUG" == "true" ]]; then
    set -x
fi

print_header
show_extensions_info

# Ask for confirmation
read -p "🤔 Proceed with complete installation? (Y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Nn]$ ]]; then
    echo -e "${YELLOW}❌ Installation cancelled by user${NC}"
    exit 0
fi

if ! check_prerequisites; then
    error "Cannot continue - check prerequisites"
    exit 1
fi

install_additional_fonts

if ! install_all_extensions; then
    warning "Issues during extensions installation"
fi

if ! _apply_vscode_config; then
    warning "Issue during configuration creation"
fi

print_summary

# Clean log if no important errors
if [[ $FAILED_COUNT -eq 0 ]]; then
    rm -f "$LOGFILE"
fi
