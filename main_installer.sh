#!/bin/bash

# ==============================================================================
# Script: main_installer.sh
# Description: This script will launch a battery of installations to
#              let your PC at his PRIME !
#              If you want to skip any script from z_resources, just add "_dsbl"
# Author: [-PSOWL-]
# ==============================================================================

set -e

# Set the current path to the script location
script=$(readlink -f "$0")
cd "$(dirname "$script")"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
RESOURCES_DIR="$SCRIPT_DIR/z_resources"

# ==============================================================================
# LOGS
# ==============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1" >&2; }
print_separator() { echo "============================================================================="; }

# ==============================================================================
# ARGS
# ==============================================================================

function _show_help() {
  echo "Usage: $0 [OPTIONS]"
  echo ""
  echo "Options:"
  echo "  -d, --debug    Enable debug mode (bash -x on each sub-script)"
  echo "  -h, --help     Show this help message"
  echo "  -s, --save     Run backup script"
  echo "  -c, --clean    Run cleanup script"
  echo ""
  echo "Disable a resource script by renaming it with '_dsbl' suffix."
  echo "Example: 3.devops_softwares_dsbl.sh"
}

DEBUG="false"
SAVE="false"
CLEAN="false"

OPTGET=$(which getopt)
OPTS=$($OPTGET -o hdsc --long debug,help,save,clean -- "$@")
eval set -- "$OPTS"

while true; do
  case "$1" in
    -d|--debug) DEBUG=true;  shift ;;
    -h|--help)  _show_help;  exit 0 ;;
    -s|--save)  SAVE=true;   shift ;;
    -c|--clean) CLEAN=true;  shift ;;
    --) shift; break ;;
    *)  log_error "Unknown option: $1"; exit 1 ;;
  esac
done

# ==============================================================================
# FUNCTIONS
# ==============================================================================

function _install_scripts() {
  local success_count=0
  local failed_scripts=()
  local stopped=false

  for script in "${scripts[@]}"; do
    print_separator
    local script_name
    script_name=$(basename "$script")
    log_warning "Executing $script_name..."
    print_separator

    chmod +x "$script"

    if [[ "$DEBUG" == "true" ]]; then
      bash -x "$script"
    else
      bash "$script"
    fi

    local exit_code=$?
    if [[ $exit_code -eq 0 ]]; then
      log_success "$script_name finished successfully"
      ((++success_count))
    else
      log_error "$script_name failed (exit code: $exit_code)"
      failed_scripts+=("$script_name")

      read -rp "Continue with other scripts? (y/n) " reply
      if [[ ! "$reply" =~ ^[yY]$ ]]; then
        log_warning "Installation stopped by user."
        stopped=true
        break
      fi
    fi

    print_separator
    echo ""
  done

  if [[ "$stopped" == "true" ]]; then
    log_warning "Installation interrupted: $success_count script(s) ran before stopping."
  else
    log_success "✅ Finished: $success_count/${#scripts[@]} script(s) succeeded."
  fi

  if [[ ${#failed_scripts[@]} -gt 0 ]]; then
    log_error "Failed scripts:"
    for s in "${failed_scripts[@]}"; do
      echo "       ❌ $s"
    done
    echo ""
    log_warning "You may try to run failed scripts manually from: $RESOURCES_DIR"
  else
    log_success "🎉 Everything's done, enjoy your Linux!"
  fi
  print_separator
}

function _install_themes() {
  log_info "Copying themes..."

  local themes_source="$RESOURCES_DIR/themes"
  local themes_dest="$HOME/.themes"

  if [[ ! -d "$themes_source" ]] || [[ -z "$(ls -A "$themes_source" 2>/dev/null)" ]]; then
    log_warning "No themes found in $themes_source — skipping."
    return 0
  fi

  mkdir -p "$themes_dest"

  if cp -r "$themes_source/"* "$themes_dest/"; then
    log_success "Themes copied to $themes_dest"
  else
    log_error "Failed to copy theme files."
    return 1
  fi
  echo ""
}

function _size_terminal() {
  local cols=150
  local rows=30
  log_info "Resizing terminal to ${cols}x${rows}..."

  local terminal_uid
  terminal_uid=$(gsettings get org.gnome.Terminal.ProfilesList default | tr -d "'")

  gsettings set "org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$terminal_uid/" \
    default-size-columns "$cols"
  gsettings set "org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$terminal_uid/" \
    default-size-rows "$rows"

  log_success "Terminal resized to ${cols}x${rows}"
  echo ""
}

function _check_dns() {
  log_info "Checking DNS configuration..."

  local resolv_file="/etc/resolv.conf"

  if grep -q "1.0.0.1" "$resolv_file"; then
    log_success "DNS already up-to-date — skipping."
    cat "$resolv_file"
    echo ""
    return 0
  fi

  if [[ ! -f "$resolv_file.bkp" ]]; then
    sudo cp "$resolv_file" "$resolv_file.bkp"
    log_info "Backup created: $resolv_file.bkp"
  fi

  sudo chattr -i "$resolv_file" 2>/dev/null || true
  sudo rm -f "$resolv_file"
  sudo touch "$resolv_file"

  printf "nameserver 1.0.0.1\nnameserver 1.1.1.1\nnameserver 8.8.8.8\n" \
    | sudo tee "$resolv_file" > /dev/null

  sudo chattr +i "$resolv_file"
  log_success "DNS updated and file locked (immutable)."
  cat "$resolv_file"
  echo ""
}

function _update_network_driver() {
  log_info "Checking ethernet speed..."

  if ! command -v ip &>/dev/null; then
    sudo apt-get update -qq && sudo apt-get install -y iproute2
  fi

  local iface
  iface=$(ip -br link | awk '$1 ~ /^enp|^eth/ {print $1; exit}')

  if [[ -z "$iface" ]]; then
    log_warning "No ethernet interface detected (enp*/eth*) — skipping network driver update."
    return 0
  fi

  log_info "Interface found: $iface"

  if ! command -v ethtool &>/dev/null; then
    log_warning "ethtool not found — installing..."
    sudo apt-get install -y ethtool
  fi

  local speed
  speed=$(sudo ethtool "$iface" 2>/dev/null | awk '/Speed:/{print $2}')

  if [[ -z "$speed" ]]; then
    log_warning "Could not read speed for $iface — skipping."
    return 0
  fi

  log_info "Current speed: $speed"

  if [[ "$speed" != "2500Mb/s" ]]; then
    log_info "Forcing speed from $speed → 2500Mb/s..."
    sudo ethtool -s "$iface" speed 2500 duplex full autoneg on
    sleep 1
    local new_speed
    new_speed=$(sudo ethtool "$iface" | awk '/Speed:/{print $2}')
    log_success "New speed: $new_speed"
  else
    log_success "Already at 2500Mb/s — nothing to do."
  fi

  sudo systemctl restart NetworkManager
  sleep 5

  log_info "Installing persistent speed-enforcement service..."

  sudo tee /usr/local/bin/force-ethernet-speed.sh > /dev/null <<'EOF'
#!/usr/bin/env bash
# Force Ethernet interface to 2500Mb/s (2.5 Gbps) reliably at boot

for i in $(seq 1 40); do
    iface=$(ip -br link show up 2>/dev/null | awk '$1 ~ /^enp|^eth/ && /UP/ {print $1; exit}')
    [ -n "$iface" ] && break
    sleep 0.5
done

if [ -z "$iface" ]; then
    echo "No UP ethernet interface detected (enp*/eth*) – skipping" >&2
    exit 0
fi

current_speed=$(ethtool "$iface" 2>/dev/null | awk '/Speed:/{print $2}')

if [ "$current_speed" = "2500Mb/s" ]; then
    echo "Interface $iface already at 2500Mb/s"
    exit 0
fi

echo "Interface $iface currently at $current_speed → forcing 2500Mb/s"
ethtool -s "$iface" speed 2500 duplex full autoneg on

sleep 2
conn_name=$(nmcli -t -f NAME,DEVICE connection show --active | awk -F: -v dev="$iface" '$2==dev {print $1}')
if [ -n "$conn_name" ]; then
    nmcli connection down "$conn_name" >/dev/null 2>&1
    nmcli connection up   "$conn_name" >/dev/null 2>&1
fi

echo "Speed successfully forced to 2500Mb/s on $iface"
EOF

  sudo chmod +x /usr/local/bin/force-ethernet-speed.sh

  sudo tee /etc/systemd/system/force-ethernet-speed.service > /dev/null <<'EOF'
[Unit]
Description=Force Ethernet interface to 2.5 Gbps at boot
After=network.target NetworkManager-wait-online.service
Wants=network.target NetworkManager-wait-online.service
Requires=NetworkManager-wait-online.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/local/bin/force-ethernet-speed.sh
StandardOutput=journal
StandardError=journal
TimeoutSec=60

[Install]
WantedBy=multi-user.target
EOF

  sudo systemctl daemon-reload
  sudo systemctl enable --now force-ethernet-speed.service

  log_success "Speed enforcement service installed and running."
  systemctl status force-ethernet-speed.service --no-pager -l
  echo ""
}

function _bashrc_update() {
  local bashrc="$HOME/.bashrc"

  if [[ ! -f "$bashrc.bkp" ]]; then
    cp "$bashrc" "$bashrc.bkp"
    log_info "Backup created: $bashrc.bkp"
  fi

  log_info "Updating ~/.bashrc aliases..."

  # Helper: add alias only if absent
  _add_alias() {
    local guard="$1"
    local line="$2"
    local label="$3"
    local desc="$4"
    if ! grep -qF "$guard" "$bashrc"; then
      echo "$line" >> "$bashrc"
      log_success "$label — added  ($desc)"
    else
      log_info "$label — already present  ($desc)"
    fi
  }

  _add_alias 'alias steam_games=' \
    "alias steam_games='xdg-open \"\$HOME/.steam/debian-installation/steamapps/\"'" \
    "steam_games" "open non-Steam game folders"

  _add_alias 'alias maj=' \
    $'alias maj=\'sudo apt update && sudo apt upgrade -y\'\nalias update=\'sudo apt update && sudo apt upgrade -y\'' \
    "maj / update" "system update shortcut"

  _add_alias 'alias python=' \
    "alias python=python3" \
    "python" "python → python3"

  _add_alias 'alias k=' \
    'alias k="kubectl"' \
    "k" "kubectl shortcut"

  echo ""
}

function _setup_wallpapers() {
  local wallpaper_script="${SCRIPT_DIR}/z_wallpapers-changer.sh"

  if [[ ! -f "$wallpaper_script" ]]; then
    log_warning "Wallpaper script not found: $wallpaper_script — skipping."
    return 0
  fi

  if ! command -v feh &>/dev/null; then
    log_warning "feh not found — installing..."
    sudo apt-get install -y feh || { log_error "Failed to install feh."; return 1; }
  fi

  local screens
  read -rp "How many screens do you have? (default: 1) " screens
  screens=${screens:-1}

  if ! [[ "$screens" =~ ^[0-9]+$ ]] || [[ "$screens" -lt 1 ]]; then
    log_warning "Invalid screen count '$screens' — defaulting to 1."
    screens=1
  fi

  sed -i "s|^TOTAL_SCREENS=.*|TOTAL_SCREENS=\"$screens\"|" "$wallpaper_script"
  chmod +x "$wallpaper_script"

  log_info "Creating wallpaper-changer systemd user service..."

  mkdir -p ~/.config/systemd/user

  cat > ~/.config/systemd/user/wallpaper.service <<EOF
[Unit]
Description=Automatically changes wallpapers on all screens
After=graphical.target
Wants=graphical.target

[Service]
Type=simple
ExecStart=$wallpaper_script
Restart=on-failure
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=default.target
EOF

  systemctl --user daemon-reload
  systemctl --user enable wallpaper.service
  systemctl --user start wallpaper.service

  log_success "Wallpaper service installed and started."
  log_info "Check status: systemctl --user status wallpaper.service"
  echo ""
}

# ==============================================================================
# CLEANUP TRAP
# ==============================================================================

cleanup() {
  local exit_code=$?
  # Stop the sudo keepalive background process
  if [[ -n "${SUDO_KEEPALIVE_PID:-}" ]]; then
    kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true
  fi
  if [[ $exit_code -ne 0 ]]; then
    log_error "Script exited with error (code: $exit_code)."
  fi
  print_separator
}
trap cleanup EXIT

# ==============================================================================
# MAIN
# ==============================================================================

print_separator
log_info "Starting: $SCRIPT_NAME"
log_info "Directory: $SCRIPT_DIR"
[[ "$DEBUG" == "true" ]] && { set -x; log_warning "DEBUG mode activated"; }
print_separator
echo ""

log_info "Workplace: $(pwd)"
echo ""

if [[ "$SAVE" == "true" ]]; then
  # TODO: add backup script
  log_warning "Backup script not yet implemented."
  exit 0
elif [[ "$CLEAN" == "true" ]]; then
  # TODO: add cleanup script
  log_warning "Clean script not yet implemented."
  exit 0
fi

# --- System configuration ---
_bashrc_update
_check_dns
_update_network_driver
_size_terminal
_install_themes
_setup_wallpapers

# --- Sub-scripts installation ---
log_warning "Preparing resource scripts..."
readarray -t scripts < <(find "$RESOURCES_DIR" -maxdepth 1 -name "*.sh" -type f ! -name "*_dsbl.sh" | sort)

if [[ ${#scripts[@]} -eq 0 ]]; then
  log_error "No scripts found in $RESOURCES_DIR"
  exit 1
fi

echo ""
log_info "Scripts to run:"
for s in "${scripts[@]}"; do
  echo "       >> $(basename "$s")"
done
echo ""

read -rp "Proceed with full installation? (y/n) " answer
if [[ ! "$answer" =~ ^[yY]$ ]]; then
  log_warning "Cancelled. You can run scripts manually from: $RESOURCES_DIR"
  exit 0
fi

_install_scripts

# --- Post-install reminders ---
echo ""
log_warning "RECOMMENDED ACTIONS:"
echo "       >> Install GPU driver via Control Center"
echo "       >> Reboot  —  or run: source ~/.bashrc"
echo "       >> Configure keyboard shortcuts"
echo "       >> Customise your panel & widgets"
print_separator
