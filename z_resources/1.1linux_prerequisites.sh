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
  log_warning "DEBUG mode activated"
fi

###################
#    FUNCTIONS    #
###################
function _install_flatpak() {
  log_info "# Installing Flatpak..."

  if ! command -v flatpak &>/dev/null; then
    sudo apt install -y flatpak gnome-software-plugin-flatpak
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    log_success "Flatpak installed with Flathub"
  else
    if ! flatpak remotes | grep -q "^flathub"; then
      flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
      log_success "Flathub added to Flatpak"
    else
      echo "       Flatpak and Flathub already installed"
    fi
  fi
}

function _install_python_suite() {
  log_info "# Configuring Python environment..."
  if ! dpkg -s python3-venv &>/dev/null; then
    sudo apt install -y python3-venv
    log_success "Python venv installed"
  else
    echo "       Python venv already installed"
  fi
}

function _blacklist_nouveau() {
  log_info "# Blacklisting graphic driver 'NOUVEAU'"

  local blacklist_file="/etc/modprobe.d/blacklist-nouveau.conf"

  if [[ -f "$blacklist_file" ]] && grep -q "blacklist nouveau" "$blacklist_file"; then
    echo "       'Nouveau' driver is already blacklisted"
    return 0
  fi

  log_warning "This will blacklist the open-source 'Nouveau' driver"
  log_warning "Make sure to install proprietary Nvidia drivers afterwards!"

  {
    echo "blacklist nouveau"
    echo "options nouveau modeset=0"
  } | sudo tee "$blacklist_file" > /dev/null

  sudo update-initramfs -u
  log_success "'Nouveau' will be disabled after reboot"
}

function _update_system() {
  log_info "# Updating system..."
  if ! sudo apt update; then
    log_error "Failed to update package list. Check your internet connection."
    return 1
  fi

  local packages=(vim curl htop tree build-essential git wget python3-pip feh)
  local to_install=()

  for package in "${packages[@]}"; do
    if ! dpkg -s "$package" &>/dev/null; then
      to_install+=("$package")
    fi
  done

  if [[ ${#to_install[@]} -gt 0 ]]; then
    log_info "Installing missing packages: ${to_install[*]}"
    sudo apt install -y "${to_install[@]}"
    log_success "${#to_install[@]} package(s) installed"
  else
    echo "       All standard packages are already installed"
  fi

  if apt list --upgradable 2>/dev/null | grep -q upgradable; then
    log_info "Upgrading system packages..."
    sudo apt upgrade -y
    log_success "System upgraded"
  else
    echo "       System is up to date"
  fi
}

cleanup() {
  local exit_code=$?

  if [[ $exit_code -ne 0 ]]; then
    log_error "Script finished with errors (exit code: $exit_code)"
  else
    log_success "Prerequisites script completed"
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

_update_system || log_warning "System update had issues, continuing..."
_blacklist_nouveau
_install_python_suite
_install_flatpak

print_separator
log_success "All prerequisites installed successfully"
