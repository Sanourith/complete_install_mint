#!/bin/bash

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
function _install_vlc() {
  log_info "# Installing VLC MEDIA PLAYER..."

  if command -v vlc &>/dev/null; then
    echo "       VLC already installed"
    return 0
  fi

  sudo apt install -y vlc
  log_success "VLC installed"
}

function _install_discord() {
  log_info "# Installing DISCORD..."

  if command -v discord &>/dev/null; then
    echo "       Discord already installed"
    return 0
  fi

  log_info "Downloading Discord..."
  local temp_file=$(mktemp --suffix=.deb)

  if ! wget -q --show-progress "https://discord.com/api/download?platform=linux&format=deb" -O "$temp_file"; then
    log_error "Failed to download Discord"
    rm -f "$temp_file"
    return 1
  fi

  log_info "Installing Discord package..."
  if sudo dpkg -i "$temp_file" 2>/dev/null; then
    log_success "Discord installed"
  else
    log_warning "Fixing dependencies..."
    if sudo apt install -f -y; then
      log_success "Discord installed (with dependency fixes)"
    else
      log_error "Failed to install Discord"
      rm -f "$temp_file"
      return 1
    fi
  fi

  rm -f "$temp_file"
}

function _install_brave() {
  log_info "# Installing BRAVE BROWSER..."

  if command -v brave-browser &>/dev/null; then
    echo "       Brave already installed"
    return 0
  fi

  sudo mkdir -p /usr/share/keyrings

  local keyring_file="/usr/share/keyrings/brave-browser-archive-keyring.gpg"
  if [[ ! -f "$keyring_file" ]]; then
    log_info "Downloading Brave GPG key..."
    if ! sudo curl -fsSLo "$keyring_file" \
      https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg; then
      log_error "Failed to download Brave GPG key"
      return 1
    fi
  fi

  local repo_file="/etc/apt/sources.list.d/brave-browser-release.list"
  if [[ ! -f "$repo_file" ]]; then
    log_info "Adding Brave repository..."
    echo "deb [signed-by=$keyring_file] https://brave-browser-apt-release.s3.brave.com/ stable main" | \
      sudo tee "$repo_file" > /dev/null

    if ! sudo apt update; then
      log_error "Failed to update package list after adding Brave repo"
      return 1
    fi
  fi

  sudo apt install -y brave-browser
  log_success "Brave Browser installed"
}

function _install_mega() {
    local deb="megasync-xUbuntu_24.04_amd64.deb"

    wget -O "$deb" "https://mega.nz/linux/repo/xUbuntu_24.04/amd64/$deb" &&
    sudo apt install -y "./$deb"
}
}

function _install_tor() {
  log_info "# Installing Tor browser..."
  local LANG_CODE="en-US"
  local INSTALL_DIR="${HOME}/.local/opt/tor-browser"
  local BIN_LINK="${HOME}/.local/bin/tor-browser"
  local DESKTOP_FILE="${HOME}/.local/share/applications/tor-browser.desktop"
  local TMP_DIR
  TMP_DIR="$(mktemp -d)"
  trap 'rm -rf "${TMP_DIR}"' RETURN

  for cmd in curl gpg tar; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      log_info "Installing missing dependency $cmd..."
      sudo apt install $cmd
    fi
  done

  local page
  local DOWNLOAD_URL
  page="$(curl -fsSL https://www.torproject.org/download/)"
  DOWNLOAD_URL="$(grep -oE 'href="/dist/torbrowser/[0-9.]+/tor-browser-linux-x86_64-[0-9.]+\.tar\.xz"' <<< "$page" \
    | head -n1 \
    | sed -E 's/href="(.*)"/\1/')"
  DOWNLOAD_URL="https://www.torproject.org${DOWNLOAD_URL}"

  if [[ -z "$DOWNLOAD_URL" ]]; then
    log_error "ERROR: could not find Linux download link on the page."
    return 1
  fi

  local SIG_URL="${DOWNLOAD_URL}.asc"
  local FILE_BASENAME
  FILE_BASENAME="$(basename "$DOWNLOAD_URL")"
  local LATEST_VERSION
  LATEST_VERSION="$(grep -oE '[0-9]+\.[0-9]+\.[0-9]+' <<< "$FILE_BASENAME" | head -n1)"

  log_info "Latest version found: ${LATEST_VERSION}"

  # If already installed :
  local VERSION_MARKER="${INSTALL_DIR}/.installed_version"
  if [[ -f "${VERSION_MARKER}" ]] && [[ "$(cat "${VERSION_MARKER}")" == "${LATEST_VERSION}" ]]; then
    log_info "Tor Browser ${LATEST_VERSION} already installed. Nothing to do."
    return 0
  fi

  log_info "Downloading ${FILE_BASENAME}..."
  curl -fL --progress-bar -o "${TMP_DIR}/${FILE_BASENAME}" "${DOWNLOAD_URL}"
  curl -fsSL -o "${TMP_DIR}/${FILE_BASENAME}.asc" "${SIG_URL}"

  # --- GPG key ---
  local GNUPGHOME="${TMP_DIR}/gnupg"
  mkdir -m 700 -p "${GNUPGHOME}"
  export GNUPGHOME
  log_info "Importing Tor Browser signing key..."
  if ! curl -fsSL "https://openpgpkey.torproject.org/.well-known/openpgpkey/torproject.org/hu/kounek7zrdx745qydx6p59t9mqjpuhdf" \
       | gpg --import 2>&1; then
    log_info "WKD fetch failed, falling back to keyserver..."
    gpg --keyserver keys.openpgp.org --recv-keys EF6E286DDA85EA2A4BA7DE684E2C6E8793298290
  fi

  log_info "Verifying GPG signature..."
  if ! gpg --status-fd 1 --verify "${TMP_DIR}/${FILE_BASENAME}.asc" "${TMP_DIR}/${FILE_BASENAME}" 2>/dev/null \
       | grep -q "^\[GNUPG:\] GOODSIG"; then
    log_info "ERROR: signature verification FAILED. Aborting install."
    return 1
  fi

  # Installing
  log_info "Extracting to ${INSTALL_DIR}..."
  mkdir -p "$(dirname "${INSTALL_DIR}")"
  rm -rf "${INSTALL_DIR}"
  mkdir -p "${INSTALL_DIR}"
  tar -xJf "${TMP_DIR}/${FILE_BASENAME}" -C "${TMP_DIR}"
  mv "${TMP_DIR}/tor-browser"/* "${INSTALL_DIR}/"
  echo "${LATEST_VERSION}" > "${VERSION_MARKER}"
  mkdir -p "$(dirname "${BIN_LINK}")"
  ln -sf "${INSTALL_DIR}/Browser/start-tor-browser" "${BIN_LINK}"
  chmod +x "${INSTALL_DIR}/Browser/start-tor-browser"

  mkdir -p "$(dirname "${DESKTOP_FILE}")"
  cat > "${DESKTOP_FILE}" <<EOF
[Desktop Entry]
Type=Application
Name=Tor Browser
Exec=${INSTALL_DIR}/Browser/start-tor-browser %u
Icon=${INSTALL_DIR}/Browser/browser/chrome/icons/default/default128.png
Categories=Network;WebBrowser;
Terminal=false
EOF

  log_success "Tor Browser ${LATEST_VERSION} installed successfully."
}

function _install_mullvad() {
  sudo curl -fsSLo /usr/share/keyrings/mullvad-keyring.asc https://repository.mullvad.net/deb/mullvad-keyring.asc

  echo "deb [signed-by=/usr/share/keyrings/mullvad-keyring.asc arch=$( dpkg --print-architecture )] https://repository.mullvad.net/deb/stable stable main" | sudo tee /etc/apt/sources.list.d/mullvad.list

  sudo apt update
  sudo apt install mullvad-browser
}

function _install_signal() {
  curl https://updates.signal.org/desktop/apt/keys.asc | gpg --dearmor > signal-desktop-keyring.gpg;
  cat signal-desktop-keyring.gpg | sudo tee /usr/share/keyrings/signal-desktop-keyring.gpg > /dev/null

  curl -o signal-desktop.sources https://updates.signal.org/static/desktop/apt/signal-desktop.sources;
  cat signal-desktop.sources | sudo tee /etc/apt/sources.list.d/signal-desktop.sources > /dev/null

  sudo apt update && sudo apt install signal-desktop
}

function _install_steam() {
  log_info "# Installing STEAM..."

  if command -v steam &>/dev/null; then
    echo "       Steam already installed"
    return 0
  fi

  log_info "Enabling multiverse repository..."
  sudo add-apt-repository multiverse -y

  if ! sudo apt update; then
    log_error "Failed to update package list"
    return 1
  fi

  log_info "Installing Steam (this may take a while)..."
  sudo apt install -y steam
  log_success "Steam installed"
}

function _isntall_mega() {
  wget https://mega.nz/linux/repo/xUbuntu_24.04/amd64/megasync-xUbuntu_24.04_amd64.deb && sudo apt install "$PWD/megasync-xUbuntu_24.04_amd64.deb"
}

function _install_vscode() {
  log_info "# Installing VSCODE..."

  if command -v code &>/dev/null; then
    echo "       VS Code already installed"
    return 0
  fi

  log_info "Downloading Microsoft GPG key..."
  local temp_key=$(mktemp)

  if ! wget -qO "$temp_key" https://packages.microsoft.com/keys/microsoft.asc; then
    log_error "Failed to download Microsoft GPG key"
    rm -f "$temp_key"
    return 1
  fi

  gpg --dearmor < "$temp_key" | sudo tee /etc/apt/trusted.gpg.d/packages.microsoft.gpg > /dev/null
  rm -f "$temp_key"

  log_info "Adding VS Code repository..."
  echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/trusted.gpg.d/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" \
    | sudo tee /etc/apt/sources.list.d/vscode.list > /dev/null

  if ! sudo apt update; then
    log_error "Failed to update package list after adding VS Code repo"
    return 1
  fi

  sudo apt install -y code
  log_success "VS Code installed"
}

cleanup() {
  local exit_code=$?

  if [[ $exit_code -ne 0 ]]; then
    log_error "Script finished with errors (exit code: $exit_code)"
  else
    log_success "Software installation script completed"
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

_install_vscode || log_warning "VS Code installation failed, continuing..."
_install_steam || log_warning "Steam installation failed, continuing..."
_install_brave || log_warning "Brave installation failed, continuing..."
_install_mullvad || log_warning "Mullvad installation failed, continuing..."
_install_tor || log_warning "Tor installation failed, continuing..."
_install_discord || log_warning "Discord installation failed, continuing..."
_install_vlc || log_warning "VLC installation failed, continuing..."
_install_signal || log_warning "Signal installation failed, continuing..."
_install_mega || log_warning "MEGA installation failed, continuing..."

print_separator
log_success "Software installation finished."
