#!/bin/bash

# ==============================================================================
# Script: main_installer.sh
# Description: This script will launch a battery of installations to
#              let your PC at his PRIME !
#              If you want to skip any script from z_resources, just add "_dsbl"
# Author: [-PSOWL-]
# ==============================================================================

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

# TODO - add help complete dash
function _show_help() {
  echo "THIS IS HELP"
}

OPTGET=$(which getopt)
OPTS=$($OPTGET -o hd -l debug,help -- "$@")

eval set -- "$OPTS"

while true; do
  case "$1" in
    -d|--debug)
      DEBUG=true
      set -x
      shift
      ;;
    -h|--help)
      _show_help
      exit 0
      ;;
    --)
        shift
        break
        ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
RESOURCES_DIR="$SCRIPT_DIR/z_resources"

###################
#    FUNCTIONS    #
###################
function _install_scripts() {
  local success_count=0
  failed_scripts=()

  for script in "${scripts[@]}"; do
    print_separator
    script_name=$(basename "$script")
    log_warning "Executing $script_name..."
    print_separator

    chmod +x "$script"

    if bash "$script"; then
      log_success "$script_name finished successfully"
      ((++success_count))
      print_separator
    else
      exit_code=$?
      log_error "$script_name failed (code: $exit_code)"
      failed_scripts+=("$script")

      read -p "Continue with other scripts ? (y/n) " reply
      if [[ ! "$reply" =~ ^[yY]$ ]]; then
        log_warning "Installation stopped"
        break
      fi
    fi
    echo ""
    log_info "Installation finished"
    log_success "✅ Finished script : $success_count/${#scripts[@]}"

    if [[ "${#failed_scripts[@]}" -gt 0 ]]; then
      log_error "Failed script :"
      for script in "${failed_scripts[@]}"; do
        echo "       xx $script"
      done
    else
      log_success "Everything went well !"
    fi
  done
}

function _install_themes() {
  log_info "# Copying themes for free use..."
  mkdir -p ~/.themes
  if cp -r "$RESOURCES_DIR/themes/"* ~/.themes/; then
    log_success "Themes pre-installed successfully."
  else
    log_error "Error copying theme files."
  fi
  echo ""
}

function _size_terminal() {
  log_info "# Sizing terminal 120x30"
  terminal_uid=$(gsettings get org.gnome.Terminal.ProfilesList default | tr -d "'")
  gsettings set "org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$terminal_uid/" default-size-columns 120
  log_success "Done"
  echo ""
}

function _check_dns() {
  log_info "# Update DNS & make it immutable..."
  if ! grep -q "1.0.0.1" /etc/resolv.conf; then
    sudo rm /etc/resolv.conf || true
    sudo touch /etc/resolv.conf
    echo "nameserver 1.0.0.1" | sudo tee -a /etc/resolv.conf > /dev/null
    echo "nameserver 1.1.1.1" | sudo tee -a /etc/resolv.conf > /dev/null
    echo "nameserver 8.8.8.8" | sudo tee -a /etc/resolv.conf > /dev/null
    sudo chattr +i /etc/resolv.conf
    log_success "DNS updated successfully"
  else
    echo "> DNS already up-to-date."
  fi

  cat /etc/resolv.conf
  echo ""
}

function _bashrc_update() {
  log_info "# Adding commands to ~/.bashrc ..."
  if ! grep -q "alias steam_games=" ~/.bashrc; then
    echo "alias steam_games='xdg-open \"$HOME/.steam/debian-installation/steamapps/\"'" >> ~/.bashrc
    log_success "steam_games - added"
    echo "              >   used to open non-Steam added games folders"

  else
    echo "      ** steam_games - already in use"
    echo "              >   used to open non-Steam added games folders"
  fi

  if ! grep -q "maj=" ~/.bashrc; then
    echo "alias maj='sudo apt update && sudo apt upgrade -y'" >> ~/.bashrc
    echo "alias update='sudo apt update && sudo apt upgrade -y'" >> ~/.bashrc
    log_success "maj/update  - added"
    echo "              >   used to update linux"
  else
    echo "      ** maj/update  - already in use"
    echo "              >   used to update linux"
  fi
  echo ""
}

cleanup() {
  local exit_code=$?
  if [[ $exit_code -ne 0 ]]; then
      log_error "Script finished with error. (code: $exit_code)"
  fi
  # ADD HERE functions to cleanup if script fails
  print_separator
}
trap cleanup EXIT


###################
#   MAIN SCRIPT   #
###################
print_separator
log_info "Starting script: $SCRIPT_NAME"
log_info "Script directory: $SCRIPT_DIR"
[[ $DEBUG == true ]] && log_warning "DEBUG activated"
print_separator

cd "$SCRIPT_DIR"
log_info "Workplace : $(pwd)"
echo ""

_bashrc_update
_check_dns
_size_terminal
_install_themes

log_warning "# Preparing installation for scripts :"
readarray -t scripts < <(find "$RESOURCES_DIR" -name "*.sh" -type f | sort)
if [ ${#scripts[@]} -eq 0 ]; then
  log_error "No script found into z_resources"
  exit 1
else
  for i in "${!scripts[@]}"; do
    script_name=$(basename "${scripts[i]}")
    echo "       >> $script_name"
  done
  echo ""
fi

read -p "Do you want to proceed with global installation ? (y/n) " answer
if [[ ! "$answer" =~ ^[yY]$ ]]; then
  echo "You can also launch scripts manually from z_resources directory"
  exit 0
else
  _install_scripts
fi

echo ""
log_warning "RECOMMENDED ACTIONS :"
echo "       ** Reboot your computer"
echo "       ** Configure keyboard shortcut"
echo "       ** Customize your panel & widgets"
print_separator
log_success "Everything's done, enjoy your Linux !"
