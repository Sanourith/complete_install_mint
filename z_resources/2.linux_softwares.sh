#!/bin/bash

set -e

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
fi

###################
#    FUNCTIONS    #
###################
function _install_vlc() {
  echo "VLC MEDIA PLAYER INSTALLATION"

  if command -v vlc &>/dev/null; then
    echo "      VLC already installed"
    return 0
  fi

  sudo apt install -y vlc
  log_success "VLC installed"
}

function _install_discord() {
  log_info "# Installing DISCORD..."

  if command -v discord &>/dev/null || [ -f "/usr/bin/discord" ]; then
    echo "      Discord already installed"
    return 0
  fi

  echo "Downloading Discord before installation..."
  local temp_file=$(mktemp --suffix=.deb)

  if wget -q "https://discord.com/api/download?platform=linux&format=deb" -O "$temp_file"; then
    # Installer les dépendances manquantes potentielles
    sudo apt install -f -y
    sudo dpkg -i "$temp_file" || sudo apt install -f -y
    rm -f "$temp_file"
    log_success "Discord installed"
  else
    log_error "Error downloading Discord"
    rm -f "$temp_file"
    return 1
  fi
}

function _install_brave() {
  log_info "# Installing BRAVE BROWSER..."

  if command -v brave-browser &>/dev/null; then
    echo "      Brave already installed"
    return 0
  fi

  sudo mkdir -p /usr/share/keyrings

  if [ ! -f "/usr/share/keyrings/brave-browser-archive-keyring.gpg" ]; then
    sudo curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg \
      https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg
  fi

  local repo_file="/etc/apt/sources.list.d/brave-browser-release.list"
  if [ ! -f "$repo_file" ]; then
    echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main" | \
      sudo tee "$repo_file" > /dev/null
    sudo apt update
  fi

  sudo apt install -y brave-browser
  log_success "Brave Browser installed"
}

function _install_steam() {
  log_info "# Installing STEAM..."

  if command -v steam &>/dev/null || flatpak list | grep -q com.valvesoftware.Steam; then
    echo "      Steam already installed"
    return 0
  fi

  export DEBIAN_FRONTEND=noninteractive

  echo | sudo add-apt-repository multiverse -y 2>/dev/null || true

  sudo apt update
  sudo apt install -y steam
  log_success "Steam installed"
}

function _install_vscode() {
  log_info "# Installing VSCODE..."

  if command -v code &>/dev/null || flatpak list | grep -q com.visualstudio.code; then
    echo "      VS Code already installed"
    return 0
  fi

  wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
  sudo install -o root -g root -m 644 packages.microsoft.gpg /etc/apt/trusted.gpg.d/
  echo "deb [arch=amd64,arm64,armhf] https://packages.microsoft.com/repos/vscode stable main" \
    | sudo tee /etc/apt/sources.list.d/vscode.list
  sudo apt update && sudo apt install -y code
  rm -f packages.microsoft.gpg

  log_success "VS Code installed"
}

cleanup() {
  local exit_code=$?
  if [[ $exit_code -ne 0 ]]; then
      log_error "Script finished with error. (code: $exit_code)"
  fi
  sudo apt autoremove -y
  sudo apt autoclean
  print_separator
}
trap cleanup EXIT

###################
#   MAIN SCRIPT   #
###################
print_separator
log_info "Starting script: $SCRIPT_NAME"
[[ $DEBUG == true ]] && log_warning "DEBUG activated"
print_separator

_install_vscode
_install_steam
_install_brave
_install_discord
_install_vlc
