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
    -d|--debug) DEBUG=true; set -x; shift; ;;
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

  for script in "${scripts[@]}"; do
    print_separator
    script_name=$(basename "$script")
    log_warning "Executing $script_name..."
    print_separator

    chmod +x "$script"

    if bash "$script" "$DEBUG"; then
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
        error="1"
        break
      fi
    fi
    echo ""
    if [[ "$error" == "1" ]]; then
      log_error "$script_name failed"
    fi
  done

  log_success "✅ Finished script : $success_count/${#scripts[@]}"
  if [[ "${#failed_scripts[@]}" -gt 0 ]]; then
    log_error "Failed script :"
    for script in "${failed_scripts[@]}"; do
      echo "       xx $script"
    done
    log_error "You may try to launch scripts manually..."
  else
    log_success "Everything's done, enjoy your Linux !"
  fi

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

function _update_network_driver() {
    local repo_url="https://github.com/awesometic/realtek-r8125-dkms.git"
    local workdir="/tmp/realtek-r8125-dkms"
    local target_speed=${1:-1000}

    # Détection automatique de l'interface
    local iface=$(ip -o link show | awk -F': ' '{print $2}' | grep -E '^en' | head -1)

    if [[ -z "$iface" ]]; then
        echo "ERROR: Aucune interface réseau Ethernet trouvée."
        return 1
    fi

    echo "Interface détectée : $iface"

    # Vérification du chipset Realtek
    if ! lspci | grep -i realtek | grep -i ethernet; then
        echo "WARNING: Pas de carte Realtek détectée. Ce script est inutile."
        return 1
    fi

    echo "Installation des dépendances..."
    sudo apt update -y
    sudo apt install -y dkms build-essential git ethtool linux-headers-$(uname -r)

    echo "Téléchargement du module DKMS r8125..."
    rm -rf "$workdir"
    git clone "$repo_url" "$workdir"

    echo "Installation du module..."
    cd "$workdir" || return 1
    sudo ./dkms-install.sh

    # Vérifier que le module est bien installé
    if ! modinfo r8125 &>/dev/null; then
        echo "ERROR: Échec de l'installation du module r8125"
        return 1
    fi

    echo "Suppression de l'ancien module r8169..."
    sudo modprobe -r r8169 2>/dev/null || true

    echo "Activation du nouveau module r8125..."
    sudo modprobe r8125

    echo "Blacklist de r8169..."
    echo "blacklist r8169" | sudo tee /etc/modprobe.d/blacklist-r8169.conf > /dev/null
    sudo update-initramfs -u

    echo "Redémarrage de NetworkManager..."
    sudo systemctl restart NetworkManager

    sleep 3

    echo "Vérification du driver actif..."
    sudo lshw -C network | grep driver || true

    echo "État actuel :"
    echo "   Driver: $(sudo ethtool -i $iface | grep driver)"
    echo "   Speed:  $(sudo ethtool $iface | grep Speed)"

    # Force la vitesse
    echo "Forçage de la vitesse à ${target_speed}Mb/s..."
    sudo ethtool -s $iface speed $target_speed duplex full autoneg on
    sleep 2
    echo "   Nouvelle vitesse: $(sudo ethtool $iface | grep Speed)"

    # Rendre le changement permanent via systemd
    local service_file="/etc/systemd/system/ethernet-speed.service"

    echo "Création du service systemd pour persistance..."

    sudo tee $service_file > /dev/null <<EOF
[Unit]
Description=Force Ethernet to ${target_speed}Mbps
After=network-pre.target
Before=network.target

[Service]
Type=oneshot
ExecStart=/usr/sbin/ethtool -s $iface speed $target_speed duplex full autoneg on
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable ethernet-speed.service
    sudo systemctl start ethernet-speed.service

    echo ""
    echo "Terminé. Configuration persistante créée."
    echo "La vitesse sera forcée à ${target_speed}Mb/s à chaque démarrage."
    echo "Redémarre pour finaliser l'installation."
    echo ""
    echo "Si la vitesse reste bridée, vérifie ton câble Ethernet et ton switch/routeur."
    echo ""
    echo "Usage futur:"
    echo "  _update_network_driver       # Force à 1000Mb/s par défaut"
    echo "  _update_network_driver 2500  # Force à 2500Mb/s"
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
  screens="$1"

  sed -i "s|^TOTAL_SCREENS=\"[^\"]*\"|TOTAL_SCREENS=\"$screens\"|" "$wallpaper_script"

  log_info "Adding wallpaper-changer systemd service..."
  cat > ~/.config/systemd/user/wallpaper.service <<EOF
[Unit]
Description=Automatically changes wallpapers on all screens
After=graphical.target

[Service]
Type=simple
ExecStart=$wallpaper_script
Restart=always
RestartSec=10

[Install]
WantedBy=default.target
EOF

  systemctl --user daemon-reload
  systemctl --user enable --now wallpaper.service
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

if [[ "$SAVE" == "true" ]]; then
  # TODO add script
  echo "Backup script"
elif [[ "$CLEAN" == "true" ]]; then
  # TODO add script
  echo "Clean script"
else
  echo ""
  echo "Do you want to automatize wallpaper_changing ?"
  read -p "  > How many screens do you have ? (enter a number or press any letter to cancel) > " screens

  _bashrc_update
  _check_dns
  # _update_network_driver
  _size_terminal
  _install_themes
  if ! [[ "$screens" =~ ^[0-9]+$ ]]; then
    echo "Wallpapers won't be changed automatically."
  else
    _setup_wallpapers "$screens"
  fi
  # _create_appimage_shortcut "Ankama_Launcher" "$RESOURCES_DIR/Dofus 3.0-Setup-x86_64.AppImage" "$RESOURCES_DIR/icons/wakfu.png"

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
    echo "Exiting. > You can also launch scripts manually from z_resources directory"
    exit 0
  else
    _install_scripts
  fi
fi

echo ""
log_warning "RECOMMENDED ACTIONS :"
echo "       >> INSTALL GRAPHIC DRIVER using ControlCenter"
echo "       ** Reboot your computer"
echo "       ** Configure keyboard shortcut"
echo "       ** Customize your panel & widgets"
print_separator
