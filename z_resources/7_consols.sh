#!/usr/bin/env bash

# ==============================================================================
# Script: 7_consols.sh
# Description: Installation des émulateurs de consoles via Flatpak
#              (Kega Fusion, PokeMMO, melonDS) + raccourci bureau
# ==============================================================================

set -e

APP_DIR="$HOME/.local/share/applications"
ICON_DIR="$HOME/.local/share/icons"

# ==============================================================================
# LOGS  (standalone — fonctionne aussi lancé depuis main_installer.sh)
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
# PREREQUISITES
# ==============================================================================

# Installe Flatpak lui-même si absent.
ensure_flatpak() {
  if ! command -v flatpak &>/dev/null; then
    log_warning "Flatpak not found — installing..."
    sudo apt-get update -qq
    sudo apt-get install -y flatpak
    log_success "Flatpak installed."
  else
    log_info "Flatpak already installed — skipping."
  fi
}

# Ajoute le dépôt Flathub si absent.
ensure_flathub() {
  if ! flatpak remotes | grep -q "^flathub"; then
    log_info "Adding Flathub repository..."
    flatpak remote-add --if-not-exists flathub \
      https://flathub.org/repo/flathub.flatpakrepo
    log_success "Flathub added."
  else
    log_info "Flathub already configured — skipping."
  fi
}

# ==============================================================================
# HELPERS
# ==============================================================================

# install_flatpak_app <app_id> <nom lisible>
# Installe une appli Flatpak uniquement si elle n'est pas déjà présente.
install_flatpak_app() {
  local app_id="$1"
  local friendly_name="$2"

  if flatpak list --app | grep -q "$app_id"; then
    log_info "${friendly_name} already installed — skipping."
  else
    log_info "Installing ${friendly_name} via Flatpak..."
    flatpak install -y flathub "$app_id"
    log_success "${friendly_name} installed."
  fi
}

# create_desktop_shortcut <app_id> <nom> <commentaire>
# Certaines apps Flatpak n'exposent pas correctement leur .desktop/icône
# dans le menu — on force un raccourci propre dans ce cas.
create_desktop_shortcut() {
  local app_id="$1"
  local name="$2"
  local comment="$3"
  local desktop_file="$APP_DIR/${app_id}.desktop"

  mkdir -p "$APP_DIR" "$ICON_DIR"

  cat > "$desktop_file" <<EOF
[Desktop Entry]
Name=${name}
Comment=${comment}
Exec=flatpak run ${app_id}
Icon=${app_id}
Terminal=false
Type=Application
Categories=Game;Emulator;
StartupNotify=true
EOF

  # Note: les .desktop ne doivent PAS être +x sur GNOME/KDE modernes
  if command -v update-desktop-database &>/dev/null; then
    update-desktop-database "$APP_DIR" 2>/dev/null || true
  fi

  log_success "Desktop shortcut created: $desktop_file"
}

# ==============================================================================
# APPS
# ==============================================================================

install_kega_fusion() {
  local app_id="com.carpeludum.KegaFusion"

  print_separator
  log_info "Kega Fusion (SEGA emulator)"
  print_separator

  install_flatpak_app "$app_id" "Kega Fusion"
  create_desktop_shortcut "$app_id" "Kega Fusion" "SEGA Emulator"
}

install_pokemmo() {
  local app_id="com.pokemmo.PokeMMO"

  print_separator
  log_info "PokeMMO"
  print_separator

  install_flatpak_app "$app_id" "PokeMMO"
}

install_melonds() {
  local app_id="net.kuribo64.melonDS"

  print_separator
  log_info "melonDS (Nintendo DS emulator)"
  print_separator

  install_flatpak_app "$app_id" "melonDS"
}

# ==============================================================================
# MAIN
# ==============================================================================

main() {
  ensure_flatpak
  ensure_flathub

  install_kega_fusion
  install_pokemmo
  install_melonds

  print_separator
  log_success "All consoles ready!"
  log_info  "  >> Find them in your app menu, or launch via 'flatpak run <app_id>'"
  print_separator
}

main "$@"
