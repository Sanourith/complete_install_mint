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
function _install_flatpak() {
  log_info "# Installing Flatpack..."

  if ! command -v flatpak &>/dev/null; then
    sudo apt install -y flatpak gnome-software-plugin-flatpak
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    log_success "Flatpak installed with Flathub"
  else
    if ! flatpak remotes | grep -q flathub; then
      flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
      log_success "Flathub added to Flatpak"
    else
      echo "       Flatpak and Flathub already installed"
    fi
  fi
}

function _install_python_suite() {
  log_info "Configuring Python environment..."
  if ! dpkg -l | grep -q "python3-venv"; then
    sudo apt install -y python3-venv
    log_success "Python venv installed"
  else
    echo "       Python venv already installed"
  fi
}

# function _install_nvidia_drivers() {
#
# }

function _blacklist_nouveau() {
  log_info "# Blacklist graphic driver 'NOUVEAU'"

  local blacklist_file="/etc/modprobe.d/blacklist-nouveau.conf"

  if [ -f "$blacklist_file" ] && grep -q "blacklist nouveau" "$blacklist_file"; then
    log_success "'Nouveau' driver is already blacklisted"
    return 0
  fi

  echo "Blacklisting 'Nouveau' driver..."
  {
    echo "blacklist nouveau"
    echo "options nouveau modeset=0"
  } | sudo tee "$blacklist_file" > /dev/null

  sudo update-initramfs -u
  log_success "'Nouveau' removed with next rebooting"
}

function _update_system() {
  log_info "# Updating system..."
  if ! sudo apt update; then
    log_error "Error updating computer... Check your internet connection"
    exit 1
  fi

  local packages=(vim curl htop tree build-essential git wget python3-pip feh)
  local to_install=()

  for package in "${packages[@]}"; do
    if ! dpkg -l | grep -q "^ii  $package "; then
      to_install+=("$package")
    fi
  done

  if [ ${#to_install[@]} -gt 0 ]; then
    log_info "Installing missing apps..."
    sudo apt install -y "${to_install[@]}"
    log_success "${to_install[@]} installed"
  else
    echo "      Standard configuration : OK"
  fi

  if apt list --upgradable 2>/dev/null | grep -q upgradable; then
    sudo apt upgrade -y
    log_success "System updated"
  else
    echo "      System is up to date"
  fi
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

_update_system
_blacklist_nouveau
#_install_nvidia_drivers
_install_python_suite
_install_flatpak
