#!/usr/bin/env bash

# ==============================================================================
# Script: 7_consols.sh
# Description: Installation Kega Fusion (SEGA emulator) via Flatpak
#              + desktop shortcut
# ==============================================================================

set -e

APP_ID="com.carpeludum.KegaFusion"
APP_DIR="$HOME/.local/share/applications"
ICON_DIR="$HOME/.local/share/icons"
DESKTOP_FILE="$APP_DIR/kega-fusion.desktop"

# ==============================================================================
# LOGS  (standalone — also works when launched from main_installer.sh)
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
# MAIN
# ==============================================================================

print_separator
log_info "Installing Kega Fusion (SEGA emulator)"
print_separator
echo ""

# --- Flatpak ---
if ! command -v flatpak &>/dev/null; then
  log_warning "Flatpak not found — installing..."
  sudo apt-get update -qq
  sudo apt-get install -y flatpak
  log_success "Flatpak installed."
else
  log_info "Flatpak already installed — skipping."
fi

# --- Flathub remote ---
if ! flatpak remotes | grep -q "^flathub"; then
  log_info "Adding Flathub repository..."
  flatpak remote-add --if-not-exists flathub \
    https://flathub.org/repo/flathub.flatpakrepo
  log_success "Flathub added."
else
  log_info "Flathub already configured — skipping."
fi

# --- Kega Fusion ---
if flatpak list --app | grep -q "$APP_ID"; then
  log_info "Kega Fusion already installed — skipping."
else
  log_info "Installing Kega Fusion via Flatpak..."
  flatpak install -y flathub "$APP_ID"
  log_success "Kega Fusion installed."
fi

# --- Desktop shortcut ---
log_info "Creating desktop shortcut..."
mkdir -p "$APP_DIR" "$ICON_DIR"

cat > "$DESKTOP_FILE" <<EOF
[Desktop Entry]
Name=Kega Fusion
Comment=SEGA Emulator
Exec=flatpak run $APP_ID
Icon=$APP_ID
Terminal=false
Type=Application
Categories=Game;Emulator;
StartupNotify=true
EOF

# Note: .desktop files should NOT be +x on modern GNOME/KDE
if command -v update-desktop-database &>/dev/null; then
  update-desktop-database "$APP_DIR" 2>/dev/null || true
fi

log_success "Desktop shortcut created: $DESKTOP_FILE"

# --- Done ---
echo ""
print_separator
log_success "Kega Fusion ready!"
log_info  "  >> Find it in your app menu under 'Kega Fusion'"
log_info  "  >> Or launch manually: flatpak run $APP_ID"
print_separator
