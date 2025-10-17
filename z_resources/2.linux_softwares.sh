#!/bin/bash

# LOGS COLOR
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# LOGGING FUNCTION
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}
log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}
log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}
log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}
print_separator() {
    echo "============================================================================="
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"

DEBUG="$1"
if [[ "$DEBUG" == "true" ]]; then
  set -x
  log_warning "DEBUG mode activated"
fi

###################
#    FUNCTIONS    #
###################
function _install_vlc() {
  log_info "# Installing VLC MEDIA PLAYER..."

  if command -v vlc &>/dev/null; then
    echo "       VLC already installed"
    return 0
  fi

  sudo apt install -y vlc
  log_success "VLC installed"
}

function _install_discord() {
  log_info "# Installing DISCORD..."

  if command -v discord &>/dev/null; then
    echo "       Discord already installed"
    return 0
  fi

  log_info "Downloading Discord..."
  local temp_file=$(mktemp --suffix=.deb)

  if ! wget -q --show-progress "https://discord.com/api/download?platform=linux&format=deb" -O "$temp_file"; then
    log_error "Failed to download Discord"
    rm -f "$temp_file"
    return 1
  fi

  log_info "Installing Discord package..."
  if sudo dpkg -i "$temp_file" 2>/dev/null; then
    log_success "Discord installed"
  else
    log_warning "Fixing dependencies..."
    if sudo apt install -f -y; then
      log_success "Discord installed (with dependency fixes)"
    else
      log_error "Failed to install Discord"
      rm -f "$temp_file"
      return 1
    fi
  fi

  rm -f "$temp_file"
}

function _install_brave() {
  log_info "# Installing BRAVE BROWSER..."

  if command -v brave-browser &>/dev/null; then
    echo "       Brave already installed"
    return 0
  fi

  sudo mkdir -p /usr/share/keyrings

  local keyring_file="/usr/share/keyrings/brave-browser-archive-keyring.gpg"
  if [[ ! -f "$keyring_file" ]]; then
    log_info "Downloading Brave GPG key..."
    if ! sudo curl -fsSLo "$keyring_file" \
      https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg; then
      log_error "Failed to download Brave GPG key"
      return 1
    fi
  fi

  local repo_file="/etc/apt/sources.list.d/brave-browser-release.list"
  if [[ ! -f "$repo_file" ]]; then
    log_info "Adding Brave repository..."
    echo "deb [signed-by=$keyring_file] https://brave-browser-apt-release.s3.brave.com/ stable main" | \
      sudo tee "$repo_file" > /dev/null

    if ! sudo apt update; then
      log_error "Failed to update package list after adding Brave repo"
      return 1
    fi
  fi

  sudo apt install -y brave-browser
  log_success "Brave Browser installed"
}

function _install_steam() {
  log_info "# Installing STEAM..."

  if command -v steam &>/dev/null; then
    echo "       Steam already installed"
    return 0
  fi

  log_info "Enabling multiverse repository..."
  sudo add-apt-repository multiverse -y

  if ! sudo apt update; then
    log_error "Failed to update package list"
    return 1
  fi

  log_info "Installing Steam (this may take a while)..."
  sudo apt install -y steam
  log_success "Steam installed"
}

function _install_vscode() {
  log_info "# Installing VSCODE..."

  if command -v code &>/dev/null; then
    echo "       VS Code already installed"
    return 0
  fi

  log_info "Downloading Microsoft GPG key..."
  local temp_key=$(mktemp)

  if ! wget -qO "$temp_key" https://packages.microsoft.com/keys/microsoft.asc; then
    log_error "Failed to download Microsoft GPG key"
    rm -f "$temp_key"
    return 1
  fi

  gpg --dearmor < "$temp_key" | sudo tee /etc/apt/trusted.gpg.d/packages.microsoft.gpg > /dev/null
  rm -f "$temp_key"

  log_info "Adding VS Code repository..."
  echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/trusted.gpg.d/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" \
    | sudo tee /etc/apt/sources.list.d/vscode.list > /dev/null

  if ! sudo apt update; then
    log_error "Failed to update package list after adding VS Code repo"
    return 1
  fi

  sudo apt install -y code
  log_success "VS Code installed"
}

cleanup() {
  local exit_code=$?

  if [[ $exit_code -ne 0 ]]; then
    log_error "Script finished with errors (exit code: $exit_code)"
  else
    log_success "Software installation script completed"
  fi

  log_info "Cleaning up..."
  sudo apt autoremove -y &>/dev/null
  sudo apt autoclean &>/dev/null
  print_separator
}
trap cleanup EXIT

###################
#   MAIN SCRIPT   #
###################
print_separator
log_info "Starting script: $SCRIPT_NAME"
print_separator

_install_vscode || log_warning "VS Code installation failed, continuing..."
_install_steam || log_warning "Steam installation failed, continuing..."
_install_brave || log_warning "Brave installation failed, continuing..."
_install_discord || log_warning "Discord installation failed, continuing..."
_install_vlc || log_warning "VLC installation failed, continuing..."

print_separator
log_success "Software installation completed"
