#!/usr/bin/env bash

# =========================================================
# Installation Kega Fusion + raccourci desktop
# Ubuntu / Linux Mint
# =========================================================

set -e

APP_ID="com.carpeludum.KegaFusion"

APP_DIR="$HOME/.local/share/applications"
ICON_DIR="$HOME/.local/share/icons"
DESKTOP_FILE="$APP_DIR/kega-fusion.desktop"

echo "========================================="
echo "Installation de Kega Fusion"
echo "========================================="
echo

# Vérifie que Flatpak est installé
if ! command -v flatpak >/dev/null 2>&1; then
    echo "Flatpak n'est pas installé."
    echo "Installation de Flatpak..."

    sudo apt update
    sudo apt install -y flatpak

    echo
    echo "Ajout du dépôt Flathub..."

    flatpak remote-add --if-not-exists flathub \
        https://flathub.org/repo/flathub.flatpakrepo
fi

echo
echo "Installation de Kega Fusion via Flatpak..."

flatpak install -y flathub "$APP_ID"

echo
echo "Création des dossiers utilisateur..."

mkdir -p "$APP_DIR"
mkdir -p "$ICON_DIR"

echo
echo "Création du raccourci desktop..."

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

chmod +x "$DESKTOP_FILE"

# Rafraîchissement du cache desktop
if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$APP_DIR" || true
fi

echo
echo "========================================="
echo "Installation terminée."
echo "========================================="
echo
echo "Tu peux maintenant :"
echo "- ouvrir le menu d'applications"
echo "- chercher 'Kega Fusion'"
echo "- l'ajouter à la barre des tâches"
echo
echo "Lancement manuel possible avec :"
echo "flatpak run $APP_ID"
echo
