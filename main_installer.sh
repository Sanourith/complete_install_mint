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
  echo "Usage: $0 [OPTIONS]"
  echo ""
  echo "Options:"
  echo "  -d, --debug    Enable debug mode"
  echo "  -h, --help     Show this help message"
  echo "  -s, --save     Run backup script"
  echo "  -c, --clean    Run cleanup script"
}

DEBUG="false"
SAVE="false"
CLEAN="false"

OPTGET=$(which getopt)
OPTS=$($OPTGET -o hdsc -l debug,help,save,clean -- "$@")

eval set -- "$OPTS"

while true; do
  case "$1" in
    -d|--debug) DEBUG=true; shift; ;;
    -h|--help) _show_help; exit 0; ;;
    -s|--save) SAVE=true; shift; ;;
    -c|--clean) CLEAN=true; shift; ;;
    --) shift; break; ;;
    *) echo "Unknown option: $1" >&2; exit 1; ;;
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
  local stopped=false

  for script in "${scripts[@]}"; do
    print_separator
    local script_name=$(basename "$script")
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
      log_error "$script_name failed (code: $exit_code)"
      failed_scripts+=("$script")

      read -p "Continue with other scripts ? (y/n) " reply
      if [[ ! "$reply" =~ ^[yY]$ ]]; then
        log_warning "Installation stopped"
        stopped=true
        break
      fi
    fi

    print_separator
    echo ""
  done

  if [[ "$stopped" == "true" ]]; then
    log_warning "Installation interrupted: $success_count script(s) executed before stopping"
  else
    log_success "✅ Finished: $success_count/${#scripts[@]} script(s) succeeded"
  fi

  if [[ ${#failed_scripts[@]} -gt 0 ]]; then
    log_error "Failed scripts:"
    for script in "${failed_scripts[@]}"; do
      echo "       ❌ $script"
    done
    echo ""
    log_warning "You may try to launch failed scripts manually from $RESOURCES_DIR"
  else
    log_success "🎉 Everything's done, enjoy your Linux!"
  fi
  print_separator
}

function _install_themes() {
  log_info "# Copying themes for free use..."

  local themes_source="$RESOURCES_DIR/themes"
  local themes_dest="$HOME/.themes"

  if [[ ! -d "$themes_source" ]] || [[ -z "$(ls -A "$themes_source" 2>/dev/null)" ]]; then
    log_warning "No themes found in $themes_source. Skipping..."
    return 0
  fi

  mkdir -p "$themes_dest"

  if cp -r "$themes_source/"* "$themes_dest/"; then
    log_success "Themes pre-installed successfully to $themes_dest"
  else
    log_error "Error copying theme files."
    return 1
  fi
  echo ""
}

function _size_terminal() {
  log_info "# Sizing terminal 120x30"
  terminal_uid=$(gsettings get org.gnome.Terminal.ProfilesList default | tr -d "'")
  gsettings set "org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$terminal_uid/" default-size-columns 150
  gsettings set "org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$terminal_uid/" default-size-rows 30
  log_success "Terminal sized to 150x30"
  echo ""
}

# function _create_appimage_shortcut() {
#   app_name="$1"
#   app_path="$2"
#   app_icon="$3"

#   log_info "# Add Ankama_Launcher to executables..."

#   if [[ -z "$app_name" || -z "$app_path" ]]; then
#     log_error "Error: missing elements -- to install app_image use :"
#     echo "    _create_appimage_shortcut <app_name> <app_path> <app_icon>"
#     return 1
#   fi

#   if [[ -n "$app_path" ]]; then
#     log_warning "$app_name AppImage is not into repository. Do you want to download it ?"
#     read -p "(y/n)" answer
#     if [[ "$answer" =~ ^[yY]$ ]]; then
#       # LIST OF APPIMAGES YOU WANT TO USE
#       if [[ "$app_name" == "Ankama_Launcher" ]]; then
#         # cd "z_resources"
#         # wget -O "Ankama_Launcher.AppImage" "https://download.ankama.com/launcher-dofus/full/linux"
#         # cd -
#       fi
#     # OTHER APP
#     else
#       log_warning "$app_name not installed"
#       return 1
#     fi
#   fi

#   local desktop_dir="$HOME/.local/share/applications"
#   mkdir -p "$desktop_dir"

#   local desktop_file="$desktop_dir/${app_name}.desktop"
#   cat > "$desktop_file" <<EOF
# [Desktop Entry]
# Name=$app_name
# Exec=env DISPLAY=:0.0 $app_path
# Icon=$app_icon
# Type=Application
# StartupNotify=true
# Terminal=false
# Categories=Game;
# EOF

#   chmod +x "$desktop_file"
#   update-desktop-database "$desktop_dir" >/dev/null 2>&1

#   log_success "App shortcut: $app_name added successfully"
# }

function _check_dns() {
  log_info "# Update DNS & make it immutable..."

  local resolv_file="/etc/resolv.conf"

  if ! grep -q "1.0.0.1" $resolv_file; then
    if [[ ! -f "$resolv_file.bkp" ]]; then
      sudo cp "$resolv_file" "$resolv_file.bkp"
      log_info "Backup created: $resolv_file.bkp"
    fi

    sudo chattr -i "$resolv_file" 2>/dev/null || true

    sudo rm $resolv_file || true
    sudo touch $resolv_file
    echo "nameserver 1.0.0.1" | sudo tee -a $resolv_file > /dev/null
    echo "nameserver 1.1.1.1" | sudo tee -a $resolv_file > /dev/null
    echo "nameserver 8.8.8.8" | sudo tee -a $resolv_file > /dev/null
    sudo chattr +i $resolv_file
    log_success "DNS updated successfully (file is now immutable)"
  else
    echo "> DNS already up-to-date."
  fi

  cat "$resolv_file"
  echo ""
}

function _update_network_driver() {
  if ! command -v ip 2>/dev/null; then
    sudo apt update
    sudo apt install -y iproute2
  fi
  iface=$(ip -br link | awk '$1 ~ /^enp|^eth/ {print $1; exit}')

  if [ -z "$iface" ]; then
      echo "❌ No ethernet connection detected (enp* or eth*)"
      echo "Won't fix ethernet without stable connection"
      return 0
  fi

  echo "Interface found : $iface"

  # --- Vérification de la vitesse actuelle ---
  speed=$(sudo ethtool "$iface" 2>/dev/null | grep "Speed:" | awk '{print $2}')

  if [ -z "$speed" ]; then
      echo "❌ Speed of $iface unknow... skipping"
      exit 1
  fi

  echo "⚙️  Speed : $speed"

  # --- Si la vitesse n'est pas 2500Mb/s, on force la bonne config ---
  if [ "$speed" != "2500Mb/s" ]; then
      echo "🚀 Changing speed from $speed to 2500Mb/s..."
      sudo ethtool -s "$iface" speed 2500 duplex full autoneg on
      sleep 1
      new_speed=$(sudo ethtool "$iface" | grep "Speed:" | awk '{print $2}')
      echo "✅ New max_speed : $new_speed"
  else
      echo "✅ Already at 2500Mb/s — Nothing to do"
  fi
  sudo systemctl restart NetworkManager
  sleep 5
  echo "---- Network updated"


  echo "Creating robust systemd service..."

# --- Robust script ---
  sudo tee /usr/local/bin/force-ethernet-speed.sh > /dev/null <<'EOF'
#!/usr/bin/env bash
# Force Ethernet interface to 2500Mb/s (2.5 Gbps) reliably at boot

# Wait up to 20 seconds for an UP ethernet interface (enp* or eth*)
for i in $(seq 1 40); do
    iface=$(ip -br link show up 2>/dev/null | awk '$1 ~ /^enp|^eth/ && /UP/ {print $1; exit}')
    [ -n "$iface" ] && break
    sleep 0.5
done

if [ -z "$iface" ]; then
    echo "No UP ethernet interface detected (enp*/eth*) – skipping" >&2
    exit 0
fi

current_speed=$(ethtool "$iface" 2>/dev/null | grep -i "Speed:" | awk '{print $2}')

if [ "$current_speed" = "2500Mb/s" ]; then
    echo "Interface $iface already at 2500Mb/s"
    exit 0
fi

echo "Interface $iface currently at $current_speed → forcing 2500Mb/s"
ethtool -s "$iface" speed 2500 duplex full autoneg on

# Gentle restart of only the affected connection (no full NetworkManager restart)
sleep 2
conn_name=$(nmcli -t -f NAME,DEVICE connection show --active | awk -F: -v dev="$iface" '$2==dev {print $1}')
if [ -n "$conn_name" ]; then
    nmcli connection down "$conn_name" >/dev/null 2>&1
    nmcli connection up   "$conn_name" >/dev/null 2>&1
fi

echo "Speed successfully forced to 2500Mb/s on $iface"
EOF

  sudo chmod +x /usr/local/bin/force-ethernet-speed.sh

# --- Robust systemd service ---
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

  # Enable and start
  sudo systemctl daemon-reload
  sudo systemctl enable --now force-ethernet-speed.service

  echo "---- Network speed enforcement service installed and running"
  systemctl status force-ethernet-speed.service --no-pager -l
}

function _bashrc_update() {
  local bashrc="$HOME/.bashrc"

  if [[ ! -f "$bashrc.bkp" ]]; then
    cp "$bashrc" "$bashrc.bkp"
    log_info "Backup created: $bashrc.bkp"
  fi

  log_info "# Adding commands to ~/.bashrc ..."

  if ! grep -q "alias steam_games=" ~/.bashrc; then
    echo "alias steam_games='xdg-open \"$HOME/.steam/debian-installation/steamapps/\"'" >> ~/.bashrc
    log_success "steam_games - added"
    echo "              >   used to open non-Steam added games folders"

  else
    echo "      ** steam_games - already in use"
    echo "              >   used to open non-Steam added games folders"
  fi

  if ! grep -q "alias maj=" ~/.bashrc; then
    echo "alias maj='sudo apt update && sudo apt upgrade -y'" >> ~/.bashrc
    echo "alias update='sudo apt update && sudo apt upgrade -y'" >> ~/.bashrc
    log_success "maj/update  - added"
    echo "              >   used to update linux"
  else
    echo "      ** maj/update  - already in use"
    echo "              >   used to update linux"
  fi

  if ! grep -q "alias python=" ~/.bashrc; then
    echo "alias python=python3" >> ~/.bashrc
    log_success "python     - added"
  else
    echo "      ** python      - already in use"
  fi

  if ! grep -q 'alias k="kubectl"' ~/.bashrc; then
    echo 'alias k="kubectl"' >> ~/.bashrc
    log_success "kubectl - k added"
  else
    echo "      ** k           - Already in use"
  fi

  echo ""
}

function _setup_wallpapers() {
  local wallpaper_script="${SCRIPT_DIR}/z_wallpapers-changer.sh"
  local screens="$1"

  if [[ ! -f "$wallpaper_script" ]]; then
    log_error "Wallpaper script not found: $wallpaper_script"
    return 1
  fi

  if ! command -v feh $> /dev/null; then
    log_warning "feh is not installed... Installing..."
    sudo apt install -y feh || {
      log_error "Failed to install feh"
      return 1
    }
  fi

  sed -i "s|^TOTAL_SCREENS=.*|TOTAL_SCREENS=\"$screens\"|" "$wallpaper_script"
  chmod +x "$wallpaper_script"

  log_info "Creating wallpaper-changer systemd service..."

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

  log_success "Wallpaper service installed and started"
  log_info "Check status with: systemctl --user status wallpaper.service"
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
[[ $DEBUG == true ]] && { set -x; log_warning "DEBUG activated"; }
print_separator

cd "$SCRIPT_DIR"
log_info "Workplace : $(pwd)"
echo ""

if [[ "$SAVE" == "true" ]]; then
  # TODO add script
  echo "Backup script"
elif [[ "$CLEAN" == "true" ]]; then
  # TODO add script
  echo "Clean script"
else
  echo ""
  # echo "Do you want to automatize wallpaper_changing ?"
  # read -p "  > How many screens do you have ? (enter a number or press any letter to cancel) > " screens

  _bashrc_update
  _check_dns
  _update_network_driver
  _size_terminal
  _install_themes
  # if ! [[ "$screens" =~ ^[0-9]+$ ]]; then
  #   echo "Wallpapers won't be changed automatically."
  # else
  #   _setup_wallpapers "$screens"
  # fi
  # _create_appimage_shortcut "Ankama_Launcher" "$RESOURCES_DIR/Dofus 3.0-Setup-x86_64.AppImage" "$RESOURCES_DIR/icons/wakfu.png"

  log_warning "# Preparing installation for scripts :"
  readarray -t scripts < <(find "$RESOURCES_DIR" -name "*.sh" -type f ! -name "*_dsbl.sh" | sort)

  if [ ${#scripts[@]} -eq 0 ]; then
    log_error "No script found into $RESOURCES_DIR"
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
    echo "Exiting. > You can also launch scripts manually from $RESOURCES_DIR"
    exit 0
  else
    _install_scripts
  fi
fi

echo ""
log_warning "RECOMMENDED ACTIONS :"
echo "       >> INSTALL GRAPHIC DRIVER using ControlCenter"
echo "       ** Reboot your computer  //  or run 'source ~/.bashrc' to apply changes"
echo "       ** Configure keyboard shortcut"
echo "       ** Customize your panel & widgets"
print_separator
